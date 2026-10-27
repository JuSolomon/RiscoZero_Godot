# Risco Zero — Contexto do projeto para trabalho visual

> **Para quem está lendo (IA ou pessoa):** este documento descreve o estado atual do jogo
> *Risco Zero* (Godot 4.6), com foco em **tudo o que é visual**: o que existe, onde está,
> como é criado (cena `.tscn` ou código) e que cuidados tomar ao mudar. O objetivo da próxima
> etapa é **melhorar o visual**: prédios e outros detalhes no mapa, nuvens, imagens, sprites,
> ícones e menus. A lógica de jogo já funciona e **não deve ser quebrada**.
> Quando sugerir mudanças, diga **qual arquivo/nó** mexer e se é pelo **editor (Inspector)**
> ou por **código (GDScript)**.

---

## 1. O jogo em poucas linhas

- Estratégia/gestão de crises no **Rio de Janeiro real**. O jogador é subprefeito e comanda
  6 órgãos: **Comlurb, CET, SAMU, Defesa Civil, Guarda Municipal e Bombeiros**.
- O mapa é o Rio de verdade (dados oficiais do DATA.RIO): litoral, lagoas, florestas,
  **todas as ruas** e as **subprefeituras** (12 jogáveis).
- Começa numa subprefeitura; as outras ficam **cobertas por nuvens** e são reveladas
  (animação) quando anexadas.
- Ocorrências (lixo, enchente, deslizamento, protesto...) surgem no mapa. O jogador manda
  **viaturas** das **sedes** pelas ruas reais (menor rota). Viatura chega, estaciona com um
  efeito (anel + sirene) e resolve.
- Loop semanal: **Preparação** (clima, construir sedes, upgrades) → **semana em tempo real**
  (7 dias, ~5 min reais cada) → **resumo com nota** → oferta de anexar subprefeitura vizinha.
- Estilo pretendido (pitch): **2.5D**, câmera **isométrica inclinada** (não top-down), referência
  visual *Don't Starve* (sprites 2D em plano inclinado), *Frostpunk 2*, *Tropico 6*, *112 Operator*.
  Humor político leve. Tela título do pitch: "Urbanautas — Crise no Rio", arte cartoon colorida.

---

## 2. Tecnologia

- **Godot 4.6.1**, renderer **Forward+**, resolução base **1920×1080**.
- Repositório: `JuSolomon/RiscoZero_Godot`, branch de trabalho `claude/gallant-albattani-xzq3ne`
  (é compartilhado pela equipe: cuidado com conflitos em `Scenes/main.tscn`).
- Linguagem: GDScript. Textos do jogo em português.
- Cena principal: `Scenes/main.tscn`.
- Autoloads (globais): `TimeManager`, `GameTypes`, `CityStats`.

### Pastas

| Pasta | Conteúdo |
|---|---|
| `Scenes/` | `main.tscn`, `Unit.tscn` (viatura), `EventMarker.tscn` (ícone da ocorrência), `UI/EventCard.tscn`, `UI/debug_ui.tscn` |
| `Scripts/` | Lógica. Subpastas: `Mapa/`, `Dispatch/`, `Event/`, `UI/`, `Config/` |
| `Mapa/dados/` | Mapa já convertido para o jogo (`regioes.json`, `areas.json`, `ruas.json`, ~10 MB) |
| `Ferramentas/gerar_mapa.py` | Conversor DATA.RIO → `Mapa/dados/` (Python + shapely) |
| `Events/` | 40 eventos (`EventData` .tres) + `event_library.tres` |
| `Subprefeituras/` | 12 `SubprefeituraData` (.tres): nome, descrição, população, etiquetas |
| `Config/balanceamento.tres` | Todos os números do jogo |
| `3D Models/` | Kits low-poly (ver seção 9) |
| `Assets2D/` | Quase vazio (`white_block.png`) |

---

## 3. Escala e coordenadas (IMPORTANTE para colocar prédios)

- **1 unidade do Godot = 100 metros.** O mapa inteiro tem ~**716 × 372 unidades**
  (X de −354 a +362, Z de −192 a +180).
- **X = leste, Z = sul** (norte = −Z). **Y = para cima.** O chão é plano em **y = 0**
  (não há relevo: morros são só manchas verdes).
- Conversão de longitude/latitude para o jogo:

  ```
  x = (lon + 43.45) * 1025.31
  z = -(lat + 22.92) * 1105.4
  ```

- Coordenadas aproximadas de marcos (para posicionar monumentos/prédios-ícone):

  | Marco | x | z |
  |---|---|---|
  | Cristo Redentor | 246 | 35 |
  | Pão de Açúcar | 301 | 32 |
  | Maracanã | 225 | −9 |
  | Copacabana (meio da praia) | 275 | 56 |
  | Lagoa Rodrigo de Freitas | 246 | 59 |
  | Centro (Candelária) | 280 | −21 |
  | Aeroporto Santos Dumont | 294 | −11 |
  | Aeroporto do Galeão | 204 | −123 |
  | Pedra da Gávea | 169 | 86 |
  | Barra da Tijuca | 87 | 89 |
  | Madureira | 113 | −52 |
  | Campo Grande | −112 | −18 |

- Centro aproximado de cada região jogável (campo `miolo` em `Mapa/dados/regioes.json`):

  | id | Nome | x | z | Área |
  |---|---|---|---|---|
  | centro | Centro / Histórico | 271 | −11 | 34 km² |
  | zona_sul | Zona Sul | 263 | 47 | 44 km² |
  | grande_tijuca | Grande Tijuca | 198 | 30 | 55 km² |
  | zona_norte_1 | Zona Norte 1 | 180 | −84 | 51 km² |
  | zona_norte_2 | Zona Norte 2 | 173 | −26 | 31 km² |
  | zona_norte_3 | Zona Norte 3 | 113 | −69 | 79 km² |
  | zona_oeste_1 | Zona Oeste 1 | −5 | −51 | 125 km² |
  | zona_oeste_2 | Zona Oeste 2 | −119 | −35 | 130 km² |
  | zona_oeste_3 | Zona Oeste 3 | −174 | 51 | 316 km² |
  | jacarepagua | Jacarepaguá | 76 | 10 | 120 km² |
  | barra | Barra da Tijuca | 52 | 93 | 173 km² |
  | ilhas | Ilhas | 236 | −127 | 43 km² |

- **Alturas usadas hoje** (para não "afundar" nada):

  | Camada | y |
  |---|---|
  | Mar | −0.05 |
  | Terra (município) | 0.00 |
  | Mangue / floresta / rocha / praia / água (lagoas) | 0.010 – 0.016 |
  | Ruas locais (linhas) | 0.02 |
  | Ruas principais (faixas) | 0.022 – 0.03 |
  | Limites das regiões | 0.03 |
  | Névoa das regiões bloqueadas | 2.0 |
  | Nuvens | ~4 (±0.8) |
  | Marcador de ocorrência | 3 acima da rua |
  | Nomes das regiões (texto 3D) | 10 |

- Tamanho das coisas hoje: viatura ~2,5 unidades (o modelo Kenney na escala 2.5 — é "exagerado"
  de propósito, para ser visível). Largura das ruas principais: 0,22 a 0,55 unidade.
  **Prédios em escala real seriam minúsculos**: um prédio de 30 m = 0,3 unidade. Prédios
  precisarão de escala estilizada (bem maiores que o real) ou aparecer só com zoom.

---

## 4. Árvore da cena principal (`Scenes/main.tscn`)

| Nó | Tipo | Papel visual |
|---|---|---|
| `HUD` | CanvasLayer + `Scripts/UI/HUD.gd` | Barra do topo (data, hora, velocidade, caixa/popularidade/clima) e o card da ocorrência |
| `HUD/EventCard` | instância de `Scenes/UI/EventCard.tscn` | Card da ocorrência (direita da tela) |
| `HUD/Panel` | Panel | Barra do topo: `TimeLabel`, `ClockLabel`, `DayCycle`, `pause_button`, `speed1..3` |
| `HUD/Panel/EventCard` | Panel | **Sobra antiga, não usada** (pode ser removida) |
| `LightingManager` + `Sol` | Node + DirectionalLight3D | Ciclo dia/noite do sol (`lighting_manager.gd`) |
| `WorldEnvironment` | WorldEnvironment | Céu procedural, tonemap, glow |
| `SkyManager` | Node (`sky_manager.gd`) | Cor/energia da luz ambiente no ciclo dia/noite |
| `Camera3D` | Camera3D + `Scripts/Camera25D.gd` | Câmera 2.5D |
| `MapaRio` | Node3D + `Scripts/Mapa/MapaRio.gd` | **Desenha o mapa inteiro em tempo de execução** |
| `RoadNetwork` | Node3D | Grafo de ruas (lógica, não desenha) |
| `RegionManager` | Node | Regiões desbloqueadas / nuvens / sedes iniciais |
| `SedeManager` | Node | Construção e upgrade de sedes |
| `EventManager` | Node3D | Cria as ocorrências (marcadores) |
| `DispatchManager` | Node | Cria e move as viaturas |
| `GameManager` | Node | Fluxo do jogo (menu → preparação → semana → resumo → oferta → fim) |
| `Tela` | CanvasLayer (`TelaMVP.gd`) | Telas centrais: menu inicial, resumo, oferta, fim |
| `PainelDespacho` | CanvasLayer | Menu da sede / menu da viatura (canto inferior esquerdo) |
| `ListaOcorrencias` | CanvasLayer | Lista de ocorrências (canto superior esquerdo) + alerta no topo |
| `ConstrucaoUI` | CanvasLayer | Botão "Construir sede" (topo) + painel (canto inferior direito) + prévia no mapa |
| `PainelPreparacao` | CanvasLayer | Preparação da semana (direita) |
| `ManchetesUI` | CanvasLayer | Manchete de jornal no fim do dia (embaixo, centro) |
| `DebugUI` | instância | F12: pular dia/semana |

Nós criados **em tempo de execução** (não aparecem no editor): `Sedes/` (as sedes), as
viaturas (`Unit`), os marcadores de ocorrência, as nuvens, e todas as malhas do mapa.

---

## 5. Como o mapa é desenhado (`Scripts/Mapa/MapaRio.gd`)

**Atenção:** o mapa é **gerado por código quando o jogo roda** (lê os JSON de `Mapa/dados/`).
Por isso **no editor a cena aparece vazia** — só se vê o mapa rodando (F5/F6).
Para ver no editor seria preciso transformar o script em `@tool` ou "assar" as malhas em recursos.

Camadas (todas `MeshInstance3D` com `ArrayMesh` gerado, material `StandardMaterial3D` simples,
sem textura, `cull_mode` desligado):

1. **Mar**: `PlaneMesh` 3000×3000, cor `cor_mar`.
2. **Terra**: polígono do município, cor `cor_terra`.
3. **Mangue, Floresta, Rocha, Praia, Água (lagoas)**: polígonos de "Cobertura Vegetal e Uso da Terra 2016".
4. **Ruas**: uma malha de faixas (vias principais, largura por hierarquia) + uma malha de linhas
   finas (ruas locais). Cores por vértice (`cores_ruas`), larguras em `larguras_ruas`
   (5 níveis: estrutural, arterial 1ª, arterial 2ª, coletora, local).
5. **Limites** das regiões: faixas escuras (`cor_limite`).
6. **Nomes das regiões**: `Label3D` (billboard, `fixed_size`, sem teste de profundidade).
7. **Cobertura das regiões bloqueadas** (`cobrir(id)`): uma **névoa** (o formato da região,
   branco translúcido) + **nuvens** (`MultiMeshInstance3D` de esferas achatadas).
   `revelar(id)` anima: nuvens sobem, se espalham e encolhem; névoa some.

### O que já dá para mudar pelo Inspector (nó `MapaRio`)

- **Cores**: mar, terra, floresta, mangue, rocha, praia, água, limite, nuvem, cores e larguras das ruas.
- **Nuvens**: `malha_nuvem` (qualquer Mesh — ex.: `QuadMesh` com material Billboard + PNG),
  `material_nuvem`, altura, tamanho, variação, achatamento, opacidade da névoa,
  duração/subida/espalhamento da animação de revelação.
  Passo a passo das nuvens em PNG: `Mapa/LEIAME.md`.

### Dados disponíveis para posicionar coisas

- `Mapa/dados/regioes.json`: por região → `triangulos` (preenchimento), `contornos`,
  `miolo`/`centro`, `limites` (retângulo), `vizinhas`, `nuvens` (pontos), `area_km2`.
- `Mapa/dados/areas.json`: triângulos de `terra`, `floresta`, `mangue`, `rocha`, `praia`, `agua`.
- `Mapa/dados/ruas.json`: 88 mil cruzamentos (`nos`), trechos (`arestas` + `desenho`),
  `regiao_do_no` (a região de cada cruzamento).
- **Não exportado ainda (mas disponível nos arquivos originais do DATA.RIO, fora do repo):**
  - a classe **"Áreas Urbanas"** da Cobertura Vegetal (556 km² de mancha urbana) — seria a
    melhor máscara para espalhar prédios;
  - os **167 bairros** (Limite de Bairros).
  Para usar, é preciso acrescentar a camada no `Ferramentas/gerar_mapa.py` e rodar de novo
  com os GeoJSON originais (o dono do projeto tem os arquivos).

---

## 6. Objetos 3D do jogo

### Sedes (`Scripts/Dispatch/UnitBase.gd`, criadas por código)
- Visual atual: **cilindro colorido** (cor do órgão) + `Label3D` "Sede X" (tamanho fixo na tela).
- Área de clique: `Area3D` esfera raio 2.5 (nó "Clique") → abre o menu da sede.
- Nível de upgrade (0–3) em `base.nivel` (poderia mudar o visual conforme o nível).
- Posição: sempre num cruzamento de rua, y = 0.

### Viaturas (`Scenes/Unit.tscn` + `Scenes/Unit.gd`)
- Modelo 3D Kenney por órgão (constante `MODELOS` no `Unit.gd`):

  | Órgão | Modelo |
  |---|---|
  | Comlurb | `3D Models/Veículos/Carros/garbage-truck.fbx` |
  | CET | `.../suv.fbx` |
  | SAMU | `.../ambulance.fbx` |
  | Defesa Civil | `.../truck.fbx` |
  | Guarda Municipal | `.../police.fbx` |
  | Bombeiros | `.../firetruck.fbx` |

- Cores por órgão: constante `CORES` no `Unit.gd`
  (Comlurb laranja, CET amarelo, SAMU vermelho, Defesa Civil laranja-escuro, GM azul, Bombeiros vermelho-escuro).
- `escala_modelo` = 2.5. Os carros Kenney apontam para **+Z**.
- Nós esperados pelo código: `Modelo` (o carro é instanciado aqui), `Efeito/Anel` (toro girando),
  `Efeito/Sirene` (OmniLight vermelho/azul), `Efeito/Rotulo` (nome do órgão). O efeito só aparece
  com a viatura **estacionada** no local.
- **De longe vira uma bolinha** na cor do órgão (`Sprite3D` com textura de gradiente gerada no
  código). Distância de troca: `distancia_troca_bolinha` (70), tamanho: `tamanho_bolinha`.
- Na sede a viatura fica **invisível**.

### Marcador de ocorrência (`Scenes/EventMarker.tscn`)
- `Area3D` + `Sprite3D` (billboard, `fixed_size`, `no_depth_test`) com **`icon.svg` do Godot
  (placeholder!)** + colisão esfera raio 2.5.
- O script (`Scripts/Event/event_maker.gd`) precisa de `event_id` e do sinal `clicked`.
- Ideia natural: ícone por órgão ou por intensidade (baixa amarelo, média laranja, alta vermelho);
  o evento tem `evento_base.severidade_inicial` (1–3) e `receita`.

### Prévia de construção (`Scripts/UI/ConstrucaoUI.gd`)
- Cilindro translúcido verde/vermelho + `Label3D` com o motivo.

---

## 7. Câmera e luz

- **Câmera** (`Scripts/Camera25D.gd`): orbita um ponto de foco; começa olhando para o **norte**;
  WASD move, Q/E gira em passos de 45°, scroll dá zoom (×1.15 por passo).
  Distância 6 a 400. **Inclinação depende do zoom**: perto = −35° (mais deitada), longe = −70°.
  Tem `voar_para(ponto, distancia, duracao)` e limites por região.
- **Sol** (`lighting_manager.gd`): gira ao longo do dia; energia de 0.35 (noite) a 1.0 (dia). Sombras ligadas.
- **Ambiente** (`sky_manager.gd`): cor/energia ambiente noite (0.25,0.28,0.45 / 0.55) ↔ dia.
- `WorldEnvironment`: céu `ProceduralSkyMaterial`, tonemap Filmic, glow ligado.
- A semana começa às 07:00; 1 dia ≈ 5 min reais (velocidade 1x).

---

## 8. Interface (UI)

Quase toda a UI nova é **montada por código** (tema padrão do Godot, sem arte).
Para personalizar, o caminho é um **Theme** global (`.tres`) aplicado nos CanvasLayers/Controls,
ou converter as telas em `.tscn` editáveis.

| Tela | Onde | Feita em | Observações |
|---|---|---|---|
| Barra do topo | `HUD` em `main.tscn` | cena + `HUD.gd` | Botões de pausa/velocidade usam **ícone do Godot (placeholder)**; `DayCycle` é um `TextureProgressBar` (aparece como retângulo preto) |
| Texto Caixa/Popularidade/Clima | `HUD.gd` | código | `Label` em (1165, 9) |
| Card da ocorrência | `Scenes/UI/EventCard.tscn` | cena | Nós usados pelo código: `TitleLabel`, `BodyLabel`, `Tags`, `Valores`, `Avisos`, `EnviarButton`, `CloseButton` (este usa o ícone do Godot) |
| Menu inicial / resumo / oferta / fim | `Scripts/UI/TelaMVP.gd` | código | Painel central com título, texto (BBCode) e grade de botões. **Não existe tela título com arte ainda** |
| Menu da sede / da viatura | `Scripts/UI/PainelDespacho.gd` | código | Canto inferior esquerdo |
| Lista de ocorrências + alerta | `Scripts/UI/ListaOcorrencias.gd` | código | Cores por intensidade |
| Construir sede | `Scripts/UI/ConstrucaoUI.gd` | código | Botão no topo (x 520) + painel inferior direito |
| Preparação da semana | `Scripts/UI/PainelPreparacao.gd` | código | Painel à direita |
| Manchete do dia | `Scripts/UI/ManchetesUI.gd` | código | "O Diário Carioca", fundo papel (StyleBoxFlat) |
| Debug | `Scenes/UI/debug_ui.tscn` | cena | F12 |

**Nomes de nós que o código procura (não renomear sem ajustar o script):**
`HUD`: `TimeLabel`, `ClockLabel`, `DayCycle`, `TickBar`, `pause_button`, `speed1`, `speed2`, `speed3`, `EventCard`.
`EventCard.tscn`: `Tags`, `Valores` (3 Labels cada), `TitleLabel`, `BodyLabel`, `Avisos`, `EnviarButton`, `CloseButton`.
`Unit.tscn`: `Modelo`, `Efeito/Anel`, `Efeito/Sirene`, `Efeito/Rotulo`.
`EventMarker.tscn`: `Sprite3D`.

---

## 9. Assets disponíveis (`3D Models/`, kits low-poly da Kenney, .fbx + `Textures/colormap.png`)

| Pasta | Qtd | Conteúdo |
|---|---|---|
| `Predios/Arranhaceu/` | 25 | `building-a … t`, chaminés, caixa d'água |
| `Predios/Comercial/` | 41 | `building-a … n`, `building-skyscraper-a … e`, `low-detail-building-*` (versões leves!), toldos, guarda-sóis |
| `Predios/Suburbio/` | 40 | `building-type-a … u` (casas), árvores, cercas, caminhos |
| `Chão/` | 72 | Peças de rua, pontes, postes, placas, cones (modulares, pensadas para grade) |
| `Veículos/Carros/` | 45 | Carros, caminhões, ambulância, polícia, bombeiros, lixo, táxi, peças |
| `Veículos/Barcos/` | 46 | Barcos e navios |
| `Veículos/Trem/` | 103 | Trens e trilhos |
| `Pessoal/` | 26 | Personagens e acessórios |

Os modelos estão em escala Kenney (~1–2 unidades de largura = 100–200 m no nosso mapa).
**Há arquivos lixo** do Windows em algumas pastas (`*.import~RF*.TMP`) que podem ser apagados.

---

## 10. Placeholders e pontos fracos visuais (lista para atacar)

- [ ] **Prédios**: o mapa não tem nenhum prédio. Hoje é um "mapa de papel" plano.
- [ ] **Monumentos/marcos** (Cristo, Pão de Açúcar, Maracanã...) — inexistentes.
- [ ] **Relevo**: morros são manchas verdes planas.
- [ ] **Ícone das ocorrências**: `icon.svg` do Godot.
- [ ] **Botões de velocidade/pausa e fechar card**: ícone do Godot.
- [ ] **`DayCycle`** do topo aparece como retângulo preto.
- [ ] **Sedes**: cilindro colorido; poderiam ser prédios (e mudar com o nível de upgrade).
- [ ] **Nuvens**: esferas brancas; o estilo do pitch pede nuvens desenhadas (2D/billboard).
- [ ] **Tela título** (Iniciar/Créditos/Sair) com arte do pitch — não existe; o jogo abre direto no menu de subprefeituras.
- [ ] **UI** sem tema: painéis cinza padrão do Godot, fonte padrão.
- [ ] **Mar e terra** com cores chapadas, sem textura nem ondas.
- [ ] Sobra antiga `HUD/Panel/EventCard` (não usada).

---

## 11. Cuidados técnicos para quem for mexer

1. **O mapa é enorme** (≈ 716 × 372 unidades, 88 mil cruzamentos). Para colocar milhares de
   prédios/árvores, use **MultiMeshInstance3D** (uma por modelo), nunca um nó por prédio.
   Prefira os `low-detail-building-*`. Considere mostrar prédios **só nas regiões
   desbloqueadas** ou **só com zoom de perto** (visibility range / LOD do Godot).
2. **Não colocar colisão** nos prédios: o clique em sedes, viaturas e ocorrências usa `Area3D`
   (picking por raio). Malhas sem colisão não atrapalham. A prévia de construção calcula o ponto
   no chão pela interseção com o plano y = 0 e prende no cruzamento mais próximo.
3. **Prédios não podem ficar em cima das ruas**: o ideal é espalhar dentro de quarteirões —
   por exemplo, na mancha "Áreas Urbanas" (precisa exportar; ver seção 5) e afastado das ruas
   do `ruas.json`.
4. **As nuvens cobrem regiões bloqueadas** com névoa em y = 2 e nuvens em y ≈ 4.
   Prédios muito altos podem "furar" as nuvens; ou ficam baixos, ou são escondidos nas regiões
   cobertas (o `MapaRio` tem `cobrir(id)` / `descobrir(id)` / `revelar(id)`, e o
   `RegionManager.desbloqueadas` lista as regiões liberadas; o sinal
   `MapaRio.revelacao_terminada(id)` avisa o fim da animação).
5. Textos e ícones flutuantes usam **`fixed_size`** (tamanho constante na tela). Prédios 3D
   não podem usar isso — escolha uma escala que funcione entre os zooms 6 e 400.
6. **Luz dia/noite** muda tudo: teste de dia (07:00–17:00) e de noite.
7. Tudo que o código cria pode ter parâmetros expostos no Inspector com `@export`
   (como já feito no `MapaRio`). Prefira isso a valores fixos no código, para a equipe ajustar.
8. A cena `main.tscn` é editada por várias pessoas: alterações pequenas e frequentes, e
   *pull* antes de mexer.
9. Rodar: abrir no Godot 4.6, F5. Escolher uma subprefeitura → tela de preparação →
   *Iniciar semana*. Câmera: WASD, Q/E, scroll. F12 = debug.

---

## 12. Ideias de abordagem para prédios (ponto de partida)

- **A. Marcos à mão**: modelos/sprites especiais para Cristo, Pão de Açúcar, Maracanã,
  Copacabana, aeroportos, nas coordenadas da seção 3. Rápido e dá identidade.
- **B. Espalhamento procedural**: um script (ex.: `Scripts/Mapa/Cidade.gd`) que, para cada região,
  gera pontos dentro da área urbana, longe das ruas, e preenche `MultiMesh` com prédios Kenney
  sorteados. Densidade/altura por região (Centro e Zona Sul: arranha-céus; Zona Oeste: casas
  do `Suburbio`). Pode ser pré-calculado no Python (`gerar_mapa.py`) e salvo num JSON.
- **C. Estilo 2.5D do pitch**: prédios como **sprites 2D** (`Sprite3D` billboard ou `QuadMesh`
  em MultiMesh com material Billboard), desenhados pela equipe.
- **D. Sedes com cara de sede**: trocar o cilindro por um prédio pequeno com o logo/cor do
  órgão, variando com o nível de upgrade (`base.nivel`).
