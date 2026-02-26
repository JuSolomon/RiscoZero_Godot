extends Resource

class_name EventLibrary

@export var events: Array[EventData] = []

func get_random_event() -> EventData:
	if events.is_empty():
		return null
	return events [randi() % events.size()]
	
func get_random_event_for_unit(unit_type: int) -> EventData:
	var filtered: Array [EventData] = []
	for e in events:
		if e.required_unit_type == unit_type:
			filtered.append(e)
	if filtered.is_empty():
		return null
	return filtered[randi() % filtered.size()]
	 
