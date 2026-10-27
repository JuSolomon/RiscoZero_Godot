# Eventos

Cada evento é um `EventData` (`.tres`) organizado por intensidade:

- `baixa/`: crises do dia a dia
- `media/`: crises que já incomodam a população
- `alta/`: crises graves; em geral só aparecem por escalada

`event_library.tres` lista os eventos que **surgem sozinhos** no mapa (21). Os demais
só aparecem quando um evento não é atendido a tempo e escala.

## Onde cada evento surge: etiquetas

Cada subprefeitura (`Subprefeituras/*.tres`) tem etiquetas: **Praia, Encosta, Mata,
Alagamento, Comércio, Carnaval**. Um evento com etiquetas só surge em subprefeituras que
tenham pelo menos uma delas; sem etiquetas, surge em qualquer uma.

| Etiqueta | Eventos de entrada |
|---|---|
| (qualquer região) | Lixo acumulado, Semáforo quebrado, Bueiros entupidos, Manifestação marcada, Árvore com risco de queda, Onda de mal súbito por calor, Buraco na via, Ônibus quebrado na pista, Vazamento de gás, Imóvel com risco de desabamento, Fio de alta tensão caído |
| Praia | Furtos na praia, Banhistas em risco no mar |
| Encosta | Encosta instável, Pedras rolando na pista |
| Mata | Foco de incêndio em vegetação |
| Alagamento | Rio transbordando |
| Comércio | Ambulantes bloqueando calçadas, Incêndio em loja |
| Carnaval | Bloco superlotado, Folião passando mal |

## Receita: viaturas por órgão

Cada evento tem três receitas: **Fácil, Normal e Difícil**. A dificuldade vem da população
da subprefeitura onde o evento surge (limites em `Config/balanceamento.tres`).
O atendimento só começa quando **todas** as viaturas da receita estão no local.

No Inspector, em *Receita (viaturas por órgão)*, cada receita é uma lista
"órgão → quantidade". Ex.: deslizamento Difícil = Defesa Civil 2, Bombeiros 2, SAMU 1.

## Cadeias de escalada

| Entrada | → Escala para | → Escala para |
|---|---|---|
| Lixo acumulado | Pragas nas ruas | Surto de dengue |
| Semáforo quebrado / Buraco na via / Ônibus quebrado | Engarrafamento generalizado | Acidente com feridos |
| Bueiros entupidos | Enchente localizada | Grande enchente |
| Rio transbordando | Grande enchente | |
| Encosta instável / Pedras rolando na pista | Deslizamento de terra | |
| Bloco superlotado | Briga em bloco | Tumulto em massa no bloco |
| Folião passando mal | Onda de mal súbito por calor | |
| Manifestação marcada | Protesto com bloqueio de via | Confronto em protesto |
| Furtos na praia | Arrastão | |
| Árvore com risco de queda | Árvore caída na via | |
| Foco de incêndio em vegetação | Incêndio florestal | |
| Vazamento de gás | Explosão em imóvel | |
| Imóvel com risco de desabamento | Desabamento de imóvel | |
| Fio de alta tensão caído | Incêndio na rede elétrica | |
| Ambulantes bloqueando calçadas | Confusão entre ambulantes e fiscais | |
| Incêndio em loja | Incêndio de grandes proporções | |

O último evento de cada cadeia não tem `evento_escalonado`: se o prazo vencer, ele **falha**.
Na escalada, as viaturas a caminho continuam se o novo estágio precisar do órgão delas;
as outras voltam para a sede.

## Campos

| Campo | Significado |
|---|---|
| `id` | identificador único (MAIÚSCULAS) |
| `nome` / `descricao` | texto mostrado no card |
| `etiquetas` | onde o evento pode surgir (vazio = qualquer subprefeitura) |
| `severidade_inicial` | intensidade: 1 = baixa, 2 = média, 3 = alta |
| `dias_para_escalar` | dias até escalar (ou falhar) sem a equipe completa no local |
| `dias_para_resolver` | dias que a equipe completa leva no local |
| `evento_escalonado` | próximo evento da cadeia (vazio = falha) |
| `receita_facil` / `_normal` / `_dificil` | viaturas por órgão em cada dificuldade |

Lembrete: 1 dia de jogo ≈ 5 minutos reais na velocidade 1x.

## Criar um evento novo no editor

1. No FileSystem, botão direito na pasta da intensidade → **Novo → Recurso…** → `EventData`.
2. Preencha os campos e as três receitas. Em `evento_escalonado`, arraste o próximo evento.
3. Se ele deve surgir sozinho no mapa, adicione-o em `events` no `event_library.tres`.
