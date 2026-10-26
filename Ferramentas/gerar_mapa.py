"""
Gera os dados do mapa do Rio para o jogo a partir dos arquivos do DATA.RIO.

Uso:
    pip install shapely numpy
    python Ferramentas/gerar_mapa.py <pasta_com_os_geojson> Mapa/dados

Arquivos esperados na pasta (baixados do DATA.RIO, em GeoJSON):
    *Subprefeituras*.geojson   (Limites Coordenadorias Especiais dos Bairros - Subprefeituras)
    *Munic*.geojson            (Limite do Município do Rio de Janeiro)
    *Cobertura_Vegetal*.geojson
    *Logradouros*.geojson

Coordenadas do jogo: 1 unidade = 100 m, X = leste, Z = sul (Godot), origem em ORIGEM.
"""
import glob, json, math, os, random, sys
import numpy as np
import shapely
from shapely.geometry import shape, Point, MultiPolygon, Polygon, LineString
from shapely.ops import unary_union

ORIGEM = (-43.45, -22.92)          # lon, lat do ponto (0, 0)
METROS_POR_UNIDADE = 100.0
KX = math.cos(math.radians(ORIGEM[1])) * 111320.0 / METROS_POR_UNIDADE
KZ = 110540.0 / METROS_POR_UNIDADE

TOL_REGIAO = 0.15      # simplificação dos contornos (unidades)
TOL_AREAS = 0.3        # vegetação / água
AREA_MINIMA = 2.0      # descarta manchas menores que isso (unidades²)
TOL_RUA = 0.05
ESPACO_NUVENS = 9.0

# Subprefeitura -> (id, nome exibido). "Grandes Complexos" é incorporada às regiões que a envolvem.
REGIOES = {
    "Centro e Centro Histórico": ("centro", "Centro / Histórico"),
    "Zona Sul": ("zona_sul", "Zona Sul"),
    "Tijuca": ("grande_tijuca", "Grande Tijuca"),
    "Zona Norte I": ("zona_norte_1", "Zona Norte 1"),
    "Zona Norte II": ("zona_norte_2", "Zona Norte 2"),
    "Zona Norte III": ("zona_norte_3", "Zona Norte 3"),
    "Zona Oeste I": ("zona_oeste_1", "Zona Oeste 1"),
    "Zona Oeste II": ("zona_oeste_2", "Zona Oeste 2"),
    "Zona Oeste III": ("zona_oeste_3", "Zona Oeste 3"),
    "Jacarepaguá": ("jacarepagua", "Jacarepaguá"),
    "Barra da Tijuca, Recreio e Vargens": ("barra", "Barra da Tijuca"),
    "Ilhas do Governador/Fundão/Paquetá": ("ilhas", "Ilhas"),
}
INCORPORADA = "Grandes Complexos"

# hierarquia viária -> nível (0 = mais importante)
NIVEL_RUA = {"Estrutural": 0, "Arterial primária": 1, "Arterial secundária": 2, "Coletora": 3}
TRECHOS_ESPECIAIS = {"Ponte", "Viaduto", "Túnel"}   # entram no grafo mesmo sem hierarquia

VEGETACAO = {
    "Floresta Ombrófila Densa": "floresta",
    "Reflorestamento": "floresta",
    "Vegetação arbórea não florestal": "floresta",
    "Afloramento Rochoso": "rocha",
    "Praia": "praia",
    "Corpos d’água continentais": "agua",
    "Corpos d’água costeiros": "agua",
    "Formação Pioneira com influência flúvio-lacust": "mangue",
    "Formação Pioneira com influência flúvio-marinh": "mangue",
}


def projetar(x, y):
    return ((np.asarray(x) - ORIGEM[0]) * KX, -(np.asarray(y) - ORIGEM[1]) * KZ)


def transform(geom):
    return shapely.transform(geom, lambda c: np.column_stack(projetar(c[:, 0], c[:, 1])))


def ler(pasta, padrao):
    arquivos = glob.glob(os.path.join(pasta, padrao))
    if not arquivos:
        sys.exit(f"Arquivo não encontrado: {padrao}")
    print("lendo", arquivos[0])
    return json.load(open(arquivos[0], encoding="utf-8"))["features"]


def r(v):
    return round(float(v), 2)


def triangulos(geom):
    """Lista plana [x0,z0, x1,z1, x2,z2, ...] dos triângulos que preenchem o polígono (com buracos)."""
    out = []
    for poly in getattr(geom, "geoms", [geom]):
        if poly.is_empty or poly.geom_type != "Polygon":
            continue
        for t in shapely.constrained_delaunay_triangles(poly).geoms:
            c = list(t.exterior.coords)[:3]
            # sentido horário visto de cima (Godot: Y para cima, Z para o sul) -> face para cima
            (ax, az), (bx, bz), (cx, cz) = c
            if (bx - ax) * (cz - az) - (bz - az) * (cx - ax) > 0:
                c = [c[0], c[2], c[1]]
            for x, z in c:
                out += [r(x), r(z)]
    return out


def poligonos_validos(geom):
    return [p for p in getattr(geom, "geoms", [geom]) if p.geom_type == "Polygon" and not p.is_empty]


def contornos(geom):
    out = []
    for p in poligonos_validos(geom):
        out.append([r(v) for xy in p.exterior.coords for v in xy])
    return out


def main(pasta, saida):
    os.makedirs(saida, exist_ok=True)
    random.seed(42)
    np.random.seed(42)

    # ---------------- Regiões ----------------
    brutas = {}
    for f in ler(pasta, "*Subprefeituras*.geojson"):
        brutas[f["properties"]["subprefeitura"]] = transform(shape(f["geometry"])).buffer(0)

    regioes = {nome: brutas[nome] for nome in REGIOES}
    # cada pedaço dos Grandes Complexos vai para a região com quem divide mais borda
    for pedaco in poligonos_validos(brutas[INCORPORADA]):
        borda = pedaco.buffer(0.05)
        dono = max(regioes, key=lambda n: regioes[n].intersection(borda).area)
        regioes[dono] = unary_union([regioes[dono], pedaco])
    regioes = {n: g.buffer(0.01).buffer(-0.01) for n, g in regioes.items()}

    lista = []
    for nome, geom in regioes.items():
        rid, exibido = REGIOES[nome]
        simples = geom.simplify(TOL_REGIAO, preserve_topology=True)
        vizinhas = [REGIOES[o][0] for o, g in regioes.items()
                    if o != nome and geom.buffer(0.3).intersects(g)]
        if not vizinhas:
            # região ligada só por pontes (Ilhas): vizinhas = as duas mais próximas
            perto = sorted((g.distance(geom), o) for o, g in regioes.items() if o != nome)[:2]
            vizinhas = [REGIOES[o][0] for _, o in perto]
        centro = geom.representative_point()
        maior = max(poligonos_validos(geom), key=lambda p: p.area)
        area_nuvem = geom.buffer(ESPACO_NUVENS * 0.3)
        shapely.prepare(area_nuvem)
        minx, minz, maxx, maxz = geom.bounds
        gx, gz = np.meshgrid(np.arange(minx, maxx + ESPACO_NUVENS, ESPACO_NUVENS),
                             np.arange(minz, maxz + ESPACO_NUVENS, ESPACO_NUVENS * 0.85))
        gx = gx.ravel() + np.random.uniform(-0.4, 0.4, gx.size) * ESPACO_NUVENS
        gz = gz.ravel() + np.random.uniform(-0.4, 0.4, gz.size) * ESPACO_NUVENS
        dentro = shapely.contains_xy(area_nuvem, gx, gz)
        pts = list(zip(gx[dentro], gz[dentro]))
        # garante pelo menos uma nuvem em cada pedaço que ficou sem nenhuma
        for p in poligonos_validos(geom):
            if p.area > 0.5 and not shapely.contains_xy(p.buffer(ESPACO_NUVENS * 0.5), *np.array(pts or [(1e9, 1e9)]).T).any():
                c = p.representative_point()
                pts.append((c.x, c.y))
        nuvens = [r(v) for xy in pts for v in xy]
        lista.append({
            "id": rid,
            "nome": exibido,
            "nome_oficial": nome,
            "area_km2": round(geom.area * (METROS_POR_UNIDADE ** 2) / 1e6, 1),
            "centro": [r(centro.x), r(centro.y)],
            "miolo": [r(maior.representative_point().x), r(maior.representative_point().y)],
            "limites": [r(v) for v in geom.bounds],
            "vizinhas": sorted(vizinhas),
            "triangulos": triangulos(simples),
            "contornos": contornos(simples),
            "nuvens": nuvens,
        })
        print(f"  {rid:14s} vizinhas={vizinhas} nuvens={len(nuvens)//2}")
    json.dump({"regioes": lista}, open(os.path.join(saida, "regioes.json"), "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))

    # ---------------- Terra, água e vegetação ----------------
    municipio = unary_union([transform(shape(f["geometry"])).buffer(0)
                             for f in ler(pasta, "*Munic*.geojson")])
    camadas = {"terra": [municipio.simplify(TOL_REGIAO, preserve_topology=True)]}
    for f in ler(pasta, "*Cobertura_Vegetal*.geojson"):
        tipo = VEGETACAO.get(f["properties"]["classe"])
        if tipo:
            camadas.setdefault(tipo, []).append(transform(shape(f["geometry"])).buffer(0))
    areas = {}
    for tipo, geoms in camadas.items():
        g = unary_union(geoms).simplify(TOL_AREAS, preserve_topology=True)
        g = MultiPolygon([p for p in poligonos_validos(g) if p.area >= AREA_MINIMA or tipo == "terra"])
        areas[tipo] = triangulos(g)
        print(f"  {tipo:8s} triângulos={len(areas[tipo]) // 6}")
    json.dump(areas, open(os.path.join(saida, "areas.json"), "w", encoding="utf-8"), separators=(",", ":"))

    # ---------------- Ruas ----------------
    # Grafo: nós = pontas dos trechos (cruzamentos); cada aresta guarda o desenho da rua.
    nos, indice = [], {}
    def no(x, z):
        k = (round(float(x), 1), round(float(z), 1))   # pontas a menos de ~10 m viram o mesmo cruzamento
        if k not in indice:
            indice[k] = len(nos)
            nos.append((r(x), r(z)))
        return indice[k]

    trechos = []   # (a, b, nivel, [x,z,...] do desenho completo)
    for f in ler(pasta, "*Logradouros*.geojson"):
        p, g = f["properties"], f["geometry"]
        if not g:
            continue
        nivel = NIVEL_RUA.get(p.get("hierarquia"))
        if nivel is None:
            nivel = 2 if p.get("tipo_trecho") in TRECHOS_ESPECIAIS else 4
        partes = g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]
        for coords in partes:
            if len(coords) < 2:
                continue
            xs, zs = projetar([c[0] for c in coords], [c[1] for c in coords])
            linha = list(LineString(np.column_stack([xs, zs])).simplify(TOL_RUA).coords)
            a, b = no(*linha[0]), no(*linha[-1])
            if a != b:
                trechos.append((a, b, nivel, [r(v) for xy in linha for v in xy]))

    # componentes conectados: só o maior entra na rede das viaturas
    pai = list(range(len(nos)))
    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i
    for a, b, _, _ in trechos:
        pai[raiz(a)] = raiz(b)
    contagem = {}
    for i in range(len(nos)):
        contagem[raiz(i)] = contagem.get(raiz(i), 0) + 1
    principal = max(contagem, key=contagem.get)

    novo = {}
    for i in range(len(nos)):
        if raiz(i) == principal:
            novo[i] = len(novo)
    nos_ok = [None] * len(novo)
    for i, j in novo.items():
        nos_ok[j] = nos[i]
    xs = np.array([n[0] for n in nos_ok]); zs = np.array([n[1] for n in nos_ok])
    regiao_do_no = np.full(len(nos_ok), -1)
    for i, g in enumerate(regioes.values()):
        dentro = shapely.contains_xy(g, xs, zs)
        regiao_do_no[dentro & (regiao_do_no == -1)] = i

    arestas, desenho, soltas = [], [], [[] for _ in range(5)]
    for a, b, nivel, linha in trechos:
        if a in novo:
            # [a, b, nivel, início no array de desenho, quantidade de pontos]
            arestas += [novo[a], novo[b], nivel, len(desenho) // 2, len(linha) // 2]
            desenho += linha
        else:
            soltas[nivel].append(linha)
    print(f"  ruas: {len(nos_ok)} cruzamentos, {len(arestas)//5} trechos na rede; "
          f"{sum(len(x) for x in soltas)} trechos desconectados (só desenho)")

    json.dump({
        "regioes": [REGIOES[n][0] for n in regioes],
        "nos": [v for n in nos_ok for v in n],
        "regiao_do_no": regiao_do_no.tolist(),
        "arestas": arestas,
        "desenho": desenho,
        "soltas": soltas,
    }, open(os.path.join(saida, "ruas.json"), "w"), separators=(",", ":"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
