extends Node3D
class_name RoadNetwork
##
# RoadNetwork
# Grafo de ruas usado pelas viaturas para achar a menor rota (A*).
#
# As ruas podem vir de:
#   - carregar(): rede de ruas do mapa (Mapa/dados/ruas.json, gerado do DATA.RIO), ou
#   - nós Path3D filhos (desenhados no editor), ou add_polyline().
# Pontos que caem na mesma célula de `distancia_juncao` viram o mesmo cruzamento.
##

@export var distancia_juncao: float = 0.05

var _astar := AStar3D.new()

# célula (Vector3i) -> id do ponto no AStar, para achar cruzamentos sem busca O(n)
var _celulas: Dictionary = {}

# chave do trecho (a, b) -> desenho da rua entre os dois cruzamentos, de a para b
var _desenhos: Dictionary = {}

# id da região -> PackedInt32Array com os cruzamentos dentro dela
var nos_por_regiao: Dictionary = {}

# cruzamento -> índice em _nomes_regioes (-1 = fora das regiões)
var _regiao_do_no := PackedInt32Array()
var _nomes_regioes: Array = []


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

## Carrega a rede gerada por Ferramentas/gerar_mapa.py (já parseada do JSON)
func carregar(dados: Dictionary) -> void:
	var nos: Array = dados["nos"]
	var total := nos.size() / 2
	_astar.reserve_space(total)
	for i in total:
		_astar.add_point(i, Vector3(nos[i * 2], 0.0, nos[i * 2 + 1]))

	var desenho: Array = dados["desenho"]
	var arestas: Array = dados["arestas"]
	for i in range(0, arestas.size(), 5):
		var a: int = arestas[i]
		var b: int = arestas[i + 1]
		var pontos := PackedVector3Array()
		for j in range(arestas[i + 3], arestas[i + 3] + arestas[i + 4]):
			pontos.append(Vector3(desenho[j * 2], 0.0, desenho[j * 2 + 1]))
		# dois trechos ligando os mesmos cruzamentos: fica o mais curto
		var chave := _chave(a, b)
		if _desenhos.has(chave) and _comprimento(_desenhos[chave]) <= _comprimento(pontos):
			continue
		_astar.connect_points(a, b)
		_desenhos[chave] = pontos if a < b else _invertido(pontos)

	var nomes: Array = dados["regioes"]
	var listas := {}
	for nome in nomes:
		listas[nome] = PackedInt32Array()
	var regiao_do_no: Array = dados["regiao_do_no"]
	_regiao_do_no = PackedInt32Array(regiao_do_no)
	_nomes_regioes = nomes
	for i in regiao_do_no.size():
		if regiao_do_no[i] >= 0:
			listas[nomes[regiao_do_no[i]]].append(i)
	nos_por_regiao = listas
	print("RoadNetwork: %d cruzamentos, %d trechos" % [total, _desenhos.size()])


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
## (pelo desenho real de cada rua) e sai no ponto mais próximo do destino.
func get_route(de: Vector3, para: Vector3) -> PackedVector3Array:
	var rota := PackedVector3Array()
	if tem_ruas():
		var ids := _astar.get_id_path(_astar.get_closest_point(de), _astar.get_closest_point(para))
		if ids.size() > 0:
			rota.append(_astar.get_point_position(ids[0]))
		for i in range(1, ids.size()):
			var chave := _chave(ids[i - 1], ids[i])
			if _desenhos.has(chave):
				var trecho: PackedVector3Array = _desenhos[chave]
				if ids[i - 1] > ids[i]:
					trecho = _invertido(trecho)
				rota.append_array(trecho.slice(1))
			else:
				rota.append(_astar.get_point_position(ids[i]))
	rota.append(para)
	return rota


## Posição de um cruzamento sorteado dentro das regiões dadas
func ponto_aleatorio(ids_regioes: Array) -> Vector3:
	var candidatos := PackedInt32Array()
	for id in ids_regioes:
		candidatos.append_array(nos_por_regiao.get(id, PackedInt32Array()))
	if candidatos.is_empty():
		return Vector3.INF
	return _astar.get_point_position(candidatos[randi() % candidatos.size()])


## Cruzamento mais próximo de um ponto (qualquer região)
func ponto_mais_proximo(alvo: Vector3) -> Vector3:
	if not tem_ruas():
		return alvo
	return _astar.get_point_position(_astar.get_closest_point(alvo))


## Subprefeitura do cruzamento mais próximo ("" se fora das regiões)
func regiao_perto_de(alvo: Vector3) -> String:
	if not tem_ruas() or _regiao_do_no.is_empty():
		return ""
	var no := _astar.get_closest_point(alvo)
	if no < 0 or no >= _regiao_do_no.size() or _regiao_do_no[no] < 0:
		return ""
	return _nomes_regioes[_regiao_do_no[no]]


## Cruzamento da região mais próximo de um ponto
func ponto_na_regiao_perto_de(id_regiao: String, alvo: Vector3) -> Vector3:
	var melhor := Vector3.INF
	for i in nos_por_regiao.get(id_regiao, PackedInt32Array()):
		var p := _astar.get_point_position(i)
		if p.distance_squared_to(alvo) < melhor.distance_squared_to(alvo):
			melhor = p
	return melhor


func _chave(a: int, b: int) -> int:
	return mini(a, b) * 1000003 + maxi(a, b)


func _comprimento(pontos: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += pontos[i - 1].distance_to(pontos[i])
	return total


func _invertido(pontos: PackedVector3Array) -> PackedVector3Array:
	var r := pontos.duplicate()
	r.reverse()
	return r
