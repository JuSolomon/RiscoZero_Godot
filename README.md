# Risco Zero

Jogo de estratégia e gestão de crises no Rio de Janeiro: você é o subprefeito e
comanda Comlurb, CET, SAMU, Defesa Civil, Guarda Municipal e Bombeiros pelo COR.
Feito em **Godot 4.6**.

## Como jogar (demo do MVP)

1. Abra o projeto no Godot 4.6 e rode (F5).
2. Escolha a subprefeitura onde começa (ou **Aleatória**).
3. **Preparação da semana** (relógio parado): veja a previsão do clima e quantas ocorrências
   esperar, faça **upgrades** nas sedes e **construa sedes**. Depois, *Iniciar semana*.
4. Ocorrências surgem no mapa e na lista à esquerda. Para atender:
   - **Pela sede:** clique numa sede, marque as viaturas, clique em
     *Enviar marcadas* e depois na ocorrência.
   - **Pelo card:** clique na ocorrência e use *Enviar viaturas* (manda as mais próximas).
5. O atendimento só começa quando a **equipe completa** (a receita do evento) está no local.
6. Clique numa viatura para **voltar para a sede** ou **redirecionar** para outra ocorrência.
   Tirar uma viatura de uma ocorrência em aberto custa popularidade.
7. No fim de cada dia sai a **manchete** do jornal. No fim da semana: arrecadação, manutenção
   e a nota de aproveitamento. Com 60 ou mais, a prefeitura oferece uma subprefeitura vizinha.

### Sedes: construir ou fazer upgrade?

- **Construir** (*Construir sede* no topo, R$ 6.000): +2 viaturas num novo ponto do mapa
  (trajetos mais curtos naquela área). Ocupa uma vaga da subprefeitura (8/10/12 conforme a
  dificuldade, máx. 2 sedes do mesmo órgão) e tem manutenção semanal.
- **Upgrade** (clique na sede), em ordem: 1 *Frota rápida* (viaturas +25% velocidade, R$ 3.000)
  → 2 *Equipe treinada* (atendimento +25% rápido, R$ 4.000) → 3 *Ampliação* (+2 viaturas, R$ 5.000).
- Os dois funcionam também durante a semana, com o jogo pausado ou com o relógio correndo.

### Controles

| Tecla | Ação |
|---|---|
| WASD | Mover a câmera |
| Q / E | Girar a câmera |
| Scroll | Zoom (de longe as viaturas viram bolinhas) |
| Esc | Cancelar a escolha de destino / fechar o menu |
| F12 | Menu de debug (pular dia / semana) |

## Onde mexer

| O quê | Onde |
|---|---|
| Números do jogo (dinheiro, custos, popularidade, nota, dificuldade) | `Config/balanceamento.tres` |
| Eventos, etiquetas e receitas | `Events/` — ver `Events/EVENTOS.md` |
| Subprefeituras (descrição, população, etiquetas) | `Subprefeituras/` — ver `Subprefeituras/LEIAME.md` |
| Mapa e aparência das nuvens | `Mapa/LEIAME.md` |
| Distância em que a viatura vira bolinha | `Scenes/Unit.tscn` → *Visualização por zoom* |
