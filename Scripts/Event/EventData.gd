extends Resource

class_name EventData

@export var id: String
@export var nome: String
@export_multiline var descricao: String

## O evento só surge em subprefeituras com pelo menos uma destas etiquetas (vazio = qualquer uma)
@export var etiquetas: Array[GameTypes.Etiqueta] = []

## Climas em que o evento fica mais provável (ex.: enchente na chuva)
@export var climas: Array[GameTypes.Clima] = []

## Dias que a equipe completa leva no local para resolver
@export var dias_para_resolver: int = 3
## Dias até o evento escalar (ou falhar) se a equipe completa não estiver no local
@export var dias_para_escalar: int = 2

@export var evento_escalonado: EventData

## Intensidade: 1 = baixa, 2 = média, 3 = alta
@export var severidade_inicial: int = 1

@export_group("Receita (viaturas por órgão)")
@export var receita_facil: Dictionary[GameTypes.UnitType, int] = {}
@export var receita_normal: Dictionary[GameTypes.UnitType, int] = {}
@export var receita_dificil: Dictionary[GameTypes.UnitType, int] = {}


## Viaturas necessárias (órgão -> quantidade) na dificuldade dada
func receita(dificuldade: int) -> Dictionary:
	match dificuldade:
		GameTypes.Dificuldade.FACIL:
			return receita_facil
		GameTypes.Dificuldade.DIFICIL:
			return receita_dificil
	return receita_normal


## Pode surgir numa subprefeitura com estas etiquetas?
func cabe_em(etiquetas_regiao: Array) -> bool:
	if etiquetas.is_empty():
		return true
	for e in etiquetas:
		if e in etiquetas_regiao:
			return true
	return false
