# Eventos

Cada evento é um `EventData` (`.tres`) organizado por intensidade:

- `baixa/`: crises do dia a dia (1–3 por semana no início)
- `media/`: crises que já incomodam a população
- `alta/`: crises graves; em geral só aparecem por escalada

`event_library.tres` lista os eventos que **surgem sozinhos** no mapa. Os demais
só aparecem quando um evento não é resolvido a tempo e escala.

## Cadeias de escalada

| Entrada | → Escala para | → Escala para |
|---|---|---|
| Lixo acumulado (Comlurb) | Pragas nas ruas (Comlurb) | Surto de dengue (SAMU) |
| Semáforo quebrado (CET) | Engarrafamento generalizado (CET) | Acidente com feridos (SAMU) |
| Bueiros entupidos (Comlurb) | Enchente localizada (Defesa Civil) | Grande enchente (Bombeiros) |
| Encosta instável (Defesa Civil) | Deslizamento de terra (Bombeiros) | |
| Bloco superlotado (Guarda) | Briga em bloco (Guarda) | Tumulto em massa no bloco (Guarda) |
| Manifestação marcada (Guarda) | Protesto com bloqueio de via (CET) | Confronto em protesto (Guarda) |
| Furtos na praia (Guarda) | Arrastão (Guarda) | |
| Árvore com risco de queda (Comlurb) | Árvore caída na via (Bombeiros) | |
| Foco de incêndio em vegetação (Bombeiros) | Incêndio florestal (Bombeiros) | |
| Onda de mal súbito por calor (SAMU) | | |

O último evento de cada cadeia não tem `evento_escalonado`: se o prazo vencer, ele **falha**.

## Campos

| Campo | Significado |
|---|---|
| `id` | identificador único (MAIÚSCULAS, ex.: `LIXO_ACUMULADO`) |
| `nome` / `descricao` | texto mostrado no card |
| `zona_id` | `CENTRO`, `ZONA_NORTE` ou `ZONA_SUL` |
| `required_unit_type` | órgão que resolve o evento |
| `severidade_inicial` | 1 = baixa, 2 = média, 3 = alta |
| `dias_para_escalar` | dias até escalar (ou falhar) se ninguém atender |
| `dias_para_resolver` | dias que a equipe leva no local para resolver |
| `evento_escalonado` | próximo evento da cadeia (vazio = falha) |

Lembrete: 1 dia de jogo ≈ 5 minutos reais na velocidade 1x.

## Criar um evento novo no editor

1. No FileSystem, clique com o botão direito na pasta da intensidade → **Novo → Recurso…** → `EventData`.
2. Preencha os campos no Inspector. Em `evento_escalonado`, arraste o `.tres` do próximo evento.
3. Se ele deve surgir sozinho no mapa, abra `event_library.tres` e adicione-o em `events`.
