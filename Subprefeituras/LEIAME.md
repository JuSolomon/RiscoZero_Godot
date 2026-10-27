# Subprefeituras

Um `SubprefeituraData` por região jogável. O nome do arquivo (e o campo `id`) deve ser
o mesmo id usado no mapa (`Mapa/dados/regioes.json`).

| Campo | Para que serve |
|---|---|
| `nome` / `descricao` | Menu inicial e proposta de anexação |
| `populacao` | Define a dificuldade dos eventos da região (Fácil / Normal / Difícil) |
| `etiquetas` | Quais eventos podem surgir na região (ver `Events/EVENTOS.md`) |

Limites de população em `Config/balanceamento.tres`: Normal a partir de 400 mil,
Difícil a partir de 700 mil habitantes.

**As populações são estimativas aproximadas** e devem ser revisadas com os dados do Censo 2022.

| Região | População (estim.) | Dificuldade | Etiquetas |
|---|---|---|---|
| Centro / Histórico | 300 mil | Fácil | Comércio, Carnaval, Encosta |
| Ilhas | 230 mil | Fácil | Praia, Comércio, Alagamento |
| Grande Tijuca | 380 mil | Fácil | Encosta, Mata, Alagamento, Comércio, Carnaval |
| Barra da Tijuca | 400 mil | Normal | Praia, Alagamento, Mata, Comércio |
| Zona Norte 2 | 420 mil | Normal | Comércio, Carnaval, Encosta |
| Zona Oeste 3 | 520 mil | Normal | Praia, Mata, Alagamento |
| Zona Norte 1 | 600 mil | Normal | Comércio, Carnaval, Encosta, Alagamento |
| Zona Oeste 2 | 600 mil | Normal | Comércio, Mata, Alagamento |
| Jacarepaguá | 600 mil | Normal | Encosta, Mata, Alagamento, Comércio |
| Zona Sul | 640 mil | Normal | Todas |
| Zona Oeste 1 | 700 mil | Difícil | Comércio, Encosta, Mata, Alagamento |
| Zona Norte 3 | 1 milhão | Difícil | Comércio, Carnaval, Alagamento |
