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

## Aparência das nuvens

As nuvens são criadas quando o jogo roda (não aparecem no editor). Para mudar,
selecione o nó **MapaRio** em `Scenes/main.tscn` e use o grupo **Nuvens** do Inspector:

| Campo | O que faz |
|---|---|
| Malha Nuvem | Forma de cada nuvem. Vazio = esfera. Aceita QuadMesh, modelos `.glb` etc. |
| Material Nuvem | Material das nuvens. Vazio = branco na *Cor Nuvem* (grupo Cores) |
| Altura Nuvens / Tamanho Nuvem / Variação Tamanho | Posição e tamanho |
| Achatamento | 1 = redonda; menor = mais achatada |
| Opacidade Névoa | A camada que esconde o chão das regiões bloqueadas |
| Revelação › Duração / Subida / Espalhamento | Animação quando a região é liberada |

### Nuvens desenhadas em 2D (estilo do pitch)

1. Salve o desenho em PNG com fundo transparente, por exemplo `Assets2D/Nuvens/nuvem.png`.
2. **Malha Nuvem** → *New QuadMesh* (deixe o tamanho 1 × 1).
3. **Material Nuvem** → *New StandardMaterial3D* e configure:
   - Albedo › Texture: o PNG
   - Transparency › Transparency: *Alpha*
   - Shading › Shading Mode: *Unshaded*
   - Billboard › Mode: *Enabled*, com **Keep Scale** ligado
4. **Achatamento** = 1 (a proporção já vem do desenho).
5. Rode o jogo (F5).

A quantidade de nuvens vem dos dados: `ESPACO_NUVENS` em `Ferramentas/gerar_mapa.py`
(menor = mais nuvens), depois é preciso regerar o mapa.
