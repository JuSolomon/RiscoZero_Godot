extends Resource

class_name EventData

@export var id: String
@export var nome: String
@export_multiline var descricao: String

@export var zona_id: GameTypes.ZonaType #ex: centro, zona norte, etc

@export var dias_para_resolver: int = 3
@export var dias_para_escalar: int = 2

@export var evento_escalonado: EventData

@export var severidade_inicial: int = 1

@export var required_unit_type: int = 0 #Usa GameTypes.UnitType
