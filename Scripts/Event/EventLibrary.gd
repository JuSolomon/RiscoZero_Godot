extends Resource

class_name EventLibrary

## Eventos que surgem sozinhos no mapa (os demais só aparecem por escalada)
@export var events: Array[EventData] = []

func get_random_event() -> EventData:
	if events.is_empty():
		return null
	return events[randi() % events.size()]


## Sorteia um evento que caiba numa subprefeitura com estas etiquetas
func get_random_event_for(etiquetas_regiao: Array) -> EventData:
	var possiveis := eventos_para(etiquetas_regiao)
	if possiveis.is_empty():
		return null
	return possiveis[randi() % possiveis.size()]


## Sorteio ponderado: eventos ligados ao clima do dia ficam `peso_clima` vezes mais prováveis
func get_random_event_for_clima(etiquetas_regiao: Array, clima: int, peso_clima: float) -> EventData:
	var possiveis := eventos_para(etiquetas_regiao)
	if possiveis.is_empty():
		return null
	var pesos: Array[float] = []
	var total := 0.0
	for e in possiveis:
		var p := peso_clima if clima in e.climas else 1.0
		pesos.append(p)
		total += p
	var sorteio := randf() * total
	for i in possiveis.size():
		sorteio -= pesos[i]
		if sorteio <= 0.0:
			return possiveis[i]
	return possiveis[-1]


func eventos_para(etiquetas_regiao: Array) -> Array[EventData]:
	var lista: Array[EventData] = []
	for e in events:
		if e.cabe_em(etiquetas_regiao):
			lista.append(e)
	return lista
