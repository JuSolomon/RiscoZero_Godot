extends Resource
class_name SubprefeituraData
##
# Dados de jogo de uma subprefeitura. Um arquivo por região em res://Subprefeituras/,
# com o mesmo id usado no mapa (Mapa/dados/regioes.json).
##

@export var id: String
@export var nome: String
@export_multiline var descricao: String

## Estimativa de habitantes (define a dificuldade dos eventos da região)
@export var populacao: int = 400000

## Características da região: decidem quais eventos podem surgir nela
@export var etiquetas: Array[GameTypes.Etiqueta] = []


## Fácil / Normal / Difícil pela população (limites em Config/balanceamento.tres)
func dificuldade(config: BalanceConfig) -> int:
	if populacao >= config.populacao_dificil:
		return GameTypes.Dificuldade.DIFICIL
	if populacao >= config.populacao_normal:
		return GameTypes.Dificuldade.NORMAL
	return GameTypes.Dificuldade.FACIL
