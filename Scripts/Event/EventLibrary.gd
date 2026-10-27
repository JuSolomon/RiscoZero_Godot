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


func eventos_para(etiquetas_regiao: Array) -> Array[EventData]:
	var lista: Array[EventData] = []
	for e in events:
		if e.cabe_em(etiquetas_regiao):
			lista.append(e)
	return lista
