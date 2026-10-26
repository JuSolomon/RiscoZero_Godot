# Mapa do Rio

Os arquivos em `Mapa/dados/` são gerados a partir dos dados oficiais do **DATA.RIO**
por `Ferramentas/gerar_mapa.py`. O jogo lê esses JSON ao abrir (`Scripts/Mapa/MapaRio.gd`).

| Arquivo | Conteúdo |
|---|---|
| `regioes.json` | As 12 regiões jogáveis: contorno, vizinhas, centro, nuvens |
| `areas.json` | Terra, floresta, mangue, rocha, praia e água (lagoas) |
| `ruas.json` | Rede de ruas (cruzamentos + trechos) usada pelas viaturas e desenhada no mapa |

Coordenadas do jogo: **1 unidade = 100 m**, X = leste, Z = sul, origem em (-43,45; -22,92).

## Fontes (DATA.RIO, formato GeoJSON)

- Limites Coordenadorias Especiais dos Bairros - Subprefeituras
- Limite do Município do Rio de Janeiro
- Cobertura Vegetal e Uso da Terra 2016
- Logradouros

## Regerar

```bash
pip install shapely numpy
python Ferramentas/gerar_mapa.py <pasta_com_os_geojson> Mapa/dados
```

## Decisões

- **Grandes Complexos** não é uma região jogável no MVP: são 83 áreas pequenas dentro
  da Zona Norte e do Centro. Cada uma foi incorporada à subprefeitura que a envolve.
- **Ilhas** não encosta em nenhuma região (só pontes); as vizinhas dela são as duas mais próximas
  (Zona Norte 1 e Centro).
- **Ruas**: entram todas as vias que se conectam à rede principal (82% dos trechos).
  Trechos isolados (ex.: Paquetá, que não tem ligação por terra) são só desenhados.
