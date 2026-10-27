# Risco Zero

Jogo de estratégia e gestão de crises no Rio de Janeiro: você é o subprefeito e
comanda Comlurb, CET, SAMU, Defesa Civil, Guarda Municipal e Bombeiros pelo COR.
Feito em **Godot 4.6**.

## Como jogar (demo do MVP)

1. Abra o projeto no Godot 4.6 e rode (F5).
2. Escolha a subprefeitura onde começa (ou **Aleatória**).
3. Ocorrências surgem no mapa e na lista à esquerda. Para atender:
   - **Pela sede:** clique numa sede, marque as viaturas, clique em
     *Enviar marcadas* e depois na ocorrência.
   - **Pelo card:** clique na ocorrência e use *Enviar viaturas* (manda as mais próximas).
4. O atendimento só começa quando a **equipe completa** (a receita do evento) está no local.
5. Clique numa viatura para **voltar para a sede** ou **redirecionar** para outra ocorrência.
   Tirar uma viatura de uma ocorrência em aberto custa popularidade.
6. Ao fim da semana vem a nota de aproveitamento. Com 60 ou mais, a prefeitura oferece uma
   subprefeitura vizinha.

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
