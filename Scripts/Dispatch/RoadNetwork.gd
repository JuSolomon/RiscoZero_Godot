extends Node3D
class_name RoadNetwork
##
# RoadNetwork
# Grafo de ruas usado pelas viaturas para achar a menor rota (A*).
#
# As ruas podem vir de:
#   - nós Path3D filhos (desenhados no editor), ou
#   - add_polyline() (ex.: importador das ruas do OpenStreetMap).
# Pontos que caem na mesma célula de `distancia_juncao` viram o mesmo cruzamento.
##

@export var distancia_juncao: float = 0.05

var _astar := AStar3D.new()

# célula (Vector3i) -> id do ponto no AStar, para achar cruzamentos sem busca O(n)
var _celulas: Dictionary = {}


func _ready() -> void:
	for c in get_children():
		if c is Path3D and c.curve:
			var pontos := PackedVector3Array()
			for p in c.curve.tessellate():
				pontos.append(c.global_transform * p)
			add_polyline(pontos)


# -------------------------------------------------
#  CONSTRUÇÃO DO GRAFO
# -------------------------------------------------

## Adiciona uma rua (sequência de pontos em coordenadas globais), mão dupla.
func add_polyline(pontos: PackedVector3Array) -> void:
	var anterior := -1
	for p in pontos:
		var id := _ponto(p)
		if anterior != -1 and anterior != id:
			_astar.connect_points(anterior, id)
		anterior = id


func _ponto(p: Vector3) -> int:
	var celula := Vector3i((p / distancia_juncao).round())
	if _celulas.has(celula):
		return _celulas[celula]

	var id := _astar.get_available_point_id()
	_astar.add_point(id, p)
	_celulas[celula] = id
	return id


# -------------------------------------------------
#  CONSULTA
# -------------------------------------------------

func tem_ruas() -> bool:
	return _astar.get_point_count() > 0


## Menor rota de `de` até `para`: entra na rua mais próxima, segue o grafo
## e sai da rua no ponto mais próximo do destino.
func get_route(de: Vector3, para: Vector3) -> PackedVector3Array:
	var rota := PackedVector3Array()
	if tem_ruas():
		var a := _astar.get_closest_point(de)
		var b := _astar.get_closest_point(para)
		rota = _astar.get_point_path(a, b)
	rota.append(para)
	return rota
