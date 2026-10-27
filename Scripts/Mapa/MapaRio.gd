extends Node3D
class_name MapaRio
##
# MapaRio
# Monta o mapa do Rio a partir dos dados gerados por Ferramentas/gerar_mapa.py:
#   mar, terra, vegetação, água, ruas, limites e nomes das subprefeituras,
#   e a cobertura de nuvens das regiões ainda bloqueadas.
# Coordenadas: 1 unidade = 100 m, X = leste, Z = sul.
##

signal revelacao_terminada(regiao_id: String)

const ARQ_REGIOES := "res://Mapa/dados/regioes.json"
const ARQ_AREAS := "res://Mapa/dados/areas.json"
const ARQ_RUAS := "res://Mapa/dados/ruas.json"

@export var road_network: RoadNetwork

@export_group("Cores")
@export var cor_mar: Color = Color(0.36, 0.62, 0.78)
@export var cor_terra: Color = Color(0.93, 0.89, 0.80)
@export var cor_floresta: Color = Color(0.45, 0.65, 0.38)
@export var cor_mangue: Color = Color(0.55, 0.68, 0.48)
@export var cor_rocha: Color = Color(0.68, 0.66, 0.62)
@export var cor_praia: Color = Color(0.98, 0.90, 0.66)
@export var cor_agua: Color = Color(0.42, 0.68, 0.84)
@export var cor_limite: Color = Color(0.35, 0.35, 0.45)
@export var cor_nuvem: Color = Color(0.97, 0.97, 1.0)

## Cor e largura (em unidades) de cada nível de rua: estrutural, arterial 1ª, arterial 2ª, coletora, local
@export var cores_ruas: Array[Color] = [Color(1.0, 0.78, 0.35), Color(1.0, 0.86, 0.55), Color(1, 1, 1), Color(1, 1, 1), Color(0.82, 0.80, 0.76)]
@export var larguras_ruas: Array[float] = [0.55, 0.42, 0.32, 0.22, 0.0]

@export_group("Nuvens")
## Forma de cada nuvem. Vazio = esfera. Para nuvens desenhadas em 2D use um QuadMesh
## com um material de Billboard (ver Mapa/LEIAME.md)
@export var malha_nuvem: Mesh
## Material das nuvens. Vazio = branco na Cor Nuvem
@export var material_nuvem: Material
@export var altura_nuvens: float = 4.0
@export var tamanho_nuvem: float = 7.0
## Variação aleatória do tamanho (0.3 = de 70% a 130%)
@export_range(0.0, 1.0) var variacao_tamanho: float = 0.3
## Altura da nuvem em relação à largura (1 = redonda; use 1 com QuadMesh/Billboard)
@export_range(0.05, 1.0) var achatamento: float = 0.45
## Opacidade da névoa que cobre o chão das regiões bloqueadas (0 = sem névoa)
@export_range(0.0, 1.0) var opacidade_nevoa: float = 0.93

@export_subgroup("Revelação")
@export var duracao_revelacao: float = 3.5
## Quanto as nuvens sobem ao sumir
@export var subida_revelacao: float = 25.0
## Quanto as nuvens se afastam do centro da região ao sumir
@export var espalhamento_revelacao: float = 0.6

# id -> dados da região (Dictionary vindo do JSON)
var regioes: Dictionary = {}
# id -> Node3D com a cobertura (névoa + nuvens)
var _coberturas: Dictionary = {}


func _ready() -> void:
	_criar_mar()
	_carregar_areas()
	_carregar_regioes()
	_carregar_ruas()


# -------------------------------------------------
#  API PÚBLICA
# -------------------------------------------------

func ids_regioes() -> Array:
	return regioes.keys()


func get_regiao(id: String) -> Dictionary:
	return regioes.get(id, {})


func centro_regiao(id: String) -> Vector3:
	var c: Array = regioes[id]["miolo"]
	return Vector3(c[0], 0.0, c[1])


## Retângulo da região no chão (x, z, largura, altura)
func limites_regiao(id: String) -> Rect2:
	var l: Array = regioes[id]["limites"]
	return Rect2(l[0], l[1], l[2] - l[0], l[3] - l[1])


func cobrir(id: String) -> void:
	if _coberturas.has(id):
		return
	var dados: Dictionary = regioes[id]
	var cobertura := Node3D.new()
	cobertura.name = "Cobertura_" + id
	add_child(cobertura)

	# névoa: o próprio formato da região, esconde o que está embaixo
	var nevoa := MeshInstance3D.new()
	nevoa.name = "Nevoa"
	nevoa.mesh = _malha(dados["triangulos"], altura_nuvens * 0.5)
	nevoa.material_override = _material(Color(cor_nuvem, opacidade_nevoa), true)
	nevoa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cobertura.add_child(nevoa)

	# nuvens: esferas achatadas espalhadas pela região
	var pontos: Array = dados["nuvens"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if malha_nuvem:
		mm.mesh = malha_nuvem
	else:
		var esfera := SphereMesh.new()
		esfera.radial_segments = 12
		esfera.rings = 6
		mm.mesh = esfera
	mm.instance_count = pontos.size() / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var bases: Array[Transform3D] = []
	for i in mm.instance_count:
		var s := tamanho_nuvem * rng.randf_range(1.0 - variacao_tamanho, 1.0 + variacao_tamanho)
		var t := Transform3D(Basis.from_scale(Vector3(s, s * achatamento, s)),
			Vector3(pontos[i * 2], altura_nuvens + rng.randf_range(-0.8, 0.8), pontos[i * 2 + 1]))
		mm.set_instance_transform(i, t)
		bases.append(t)
	var nuvens := MultiMeshInstance3D.new()
	nuvens.name = "Nuvens"
	nuvens.multimesh = mm
	nuvens.material_override = material_nuvem if material_nuvem else _material(cor_nuvem, false)
	nuvens.set_meta("bases", bases)
	cobertura.add_child(nuvens)

	_coberturas[id] = cobertura


## Tira a cobertura na hora (sem animação)
func descobrir(id: String) -> void:
	if _coberturas.has(id):
		_coberturas[id].queue_free()
		_coberturas.erase(id)


## Animação: as nuvens sobem e se espalham, a névoa some
func revelar(id: String) -> void:
	if not _coberturas.has(id):
		revelacao_terminada.emit(id)
		return
	var cobertura: Node3D = _coberturas[id]
	var centro := centro_regiao(id)
	var tween := create_tween()
	tween.tween_method(_animar_revelacao.bind(cobertura, centro), 0.0, 1.0, duracao_revelacao) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		descobrir(id)
		revelacao_terminada.emit(id))


func _animar_revelacao(t: float, cobertura: Node3D, centro: Vector3) -> void:
	var nevoa: MeshInstance3D = cobertura.get_node("Nevoa")
	var mat: StandardMaterial3D = nevoa.material_override
	mat.albedo_color.a = opacidade_nevoa * clampf(1.0 - t * 1.6, 0.0, 1.0)

	var nuvens: MultiMeshInstance3D = cobertura.get_node("Nuvens")
	var bases: Array = nuvens.get_meta("bases")
	var mm := nuvens.multimesh
	for i in mm.instance_count:
		var b: Transform3D = bases[i]
		var fora := b.origin - centro
		fora.y = 0.0
		var origem := b.origin + fora * t * espalhamento_revelacao + Vector3.UP * t * subida_revelacao
		var escala := 1.0 - t * 0.85
		mm.set_instance_transform(i, Transform3D(b.basis.scaled(Vector3.ONE * escala), origem))


# -------------------------------------------------
#  CONSTRUÇÃO
# -------------------------------------------------

func _ler_json(caminho: String) -> Variant:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		push_error("MapaRio: não achei " + caminho + ". Rode Ferramentas/gerar_mapa.py.")
		return null
	return JSON.parse_string(arquivo.get_as_text())


func _criar_mar() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(3000, 3000)
	var mar := MeshInstance3D.new()
	mar.name = "Mar"
	mar.mesh = plano
	mar.position.y = -0.05
	mar.material_override = _material(cor_mar, false)
	add_child(mar)


func _carregar_areas() -> void:
	var areas: Dictionary = _ler_json(ARQ_AREAS)
	if areas == null:
		return
	var camadas := [
		["terra", cor_terra, 0.0], ["mangue", cor_mangue, 0.010], ["floresta", cor_floresta, 0.012],
		["rocha", cor_rocha, 0.014], ["praia", cor_praia, 0.014], ["agua", cor_agua, 0.016],
	]
	for c in camadas:
		if not areas.has(c[0]):
			continue
		var mi := MeshInstance3D.new()
		mi.name = c[0].capitalize()
		mi.mesh = _malha(areas[c[0]], c[2])
		mi.material_override = _material(c[1], false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _carregar_regioes() -> void:
	var dados: Dictionary = _ler_json(ARQ_REGIOES)
	if dados == null:
		return
	var limites := SurfaceTool.new()
	limites.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in dados["regioes"]:
		regioes[r["id"]] = r
		for anel in r["contornos"]:
			_fita(limites, anel, 0.35, 0.03, cor_limite, true)

		var nome := Label3D.new()
		nome.name = "Nome_" + r["id"]
		nome.text = r["nome"]
		nome.font_size = 96
		nome.pixel_size = 0.0006
		nome.fixed_size = true
		nome.outline_size = 18
		nome.modulate = Color(0.15, 0.2, 0.35)
		nome.outline_modulate = Color(1, 1, 1, 0.85)
		nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nome.no_depth_test = true
		nome.position = Vector3(r["miolo"][0], altura_nuvens + 6.0, r["miolo"][1])
		add_child(nome)

	var mi := MeshInstance3D.new()
	mi.name = "Limites"
	mi.mesh = limites.commit()
	mi.material_override = _material(Color.WHITE, false, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _carregar_ruas() -> void:
	var dados: Dictionary = _ler_json(ARQ_RUAS)
	if dados == null:
		return
	if road_network:
		road_network.carregar(dados)

	var fitas := SurfaceTool.new()
	fitas.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas := SurfaceTool.new()
	linhas.begin(Mesh.PRIMITIVE_LINES)

	var desenho: Array = dados["desenho"]
	var arestas: Array = dados["arestas"]
	for i in range(0, arestas.size(), 5):
		var nivel: int = arestas[i + 2]
		var pontos := desenho.slice(arestas[i + 3] * 2, (arestas[i + 3] + arestas[i + 4]) * 2)
		_desenhar_rua(fitas, linhas, pontos, nivel)
	var soltas: Array = dados["soltas"]
	for nivel in soltas.size():
		for pontos in soltas[nivel]:
			_desenhar_rua(fitas, linhas, pontos, nivel)

	for par in [["Ruas", fitas, Mesh.PRIMITIVE_TRIANGLES], ["RuasLocais", linhas, Mesh.PRIMITIVE_LINES]]:
		var mi := MeshInstance3D.new()
		mi.name = par[0]
		mi.mesh = par[1].commit()
		mi.material_override = _material(Color.WHITE, false, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _desenhar_rua(fitas: SurfaceTool, linhas: SurfaceTool, pontos: Array, nivel: int) -> void:
	var largura: float = larguras_ruas[nivel]
	if largura > 0.0:
		_fita(fitas, pontos, largura, 0.022 + (4 - nivel) * 0.002, cores_ruas[nivel], false)
		return
	linhas.set_color(cores_ruas[nivel])
	linhas.set_normal(Vector3.UP)
	for j in range(0, pontos.size() - 2, 2):
		linhas.add_vertex(Vector3(pontos[j], 0.02, pontos[j + 1]))
		linhas.add_vertex(Vector3(pontos[j + 2], 0.02, pontos[j + 3]))


## Faixa de largura fixa ao longo de uma linha (x,z,x,z...): ruas e limites
func _fita(st: SurfaceTool, pontos: Array, largura: float, y: float, cor: Color, fechada: bool) -> void:
	st.set_color(cor)
	st.set_normal(Vector3.UP)
	var n := pontos.size() / 2
	var ultimo := n if fechada else n - 1
	for j in ultimo:
		var a := Vector3(pontos[j * 2], y, pontos[j * 2 + 1])
		var k := (j + 1) % n
		var b := Vector3(pontos[k * 2], y, pontos[k * 2 + 1])
		var d := b - a
		if d.length_squared() < 0.000001:
			continue
		var lado := Vector3(-d.z, 0.0, d.x).normalized() * largura * 0.5
		st.add_vertex(a - lado); st.add_vertex(b - lado); st.add_vertex(b + lado)
		st.add_vertex(a - lado); st.add_vertex(b + lado); st.add_vertex(a + lado)


func _malha(tri: Array, y: float) -> ArrayMesh:
	var v := PackedVector3Array()
	v.resize(tri.size() / 2)
	for i in v.size():
		v[i] = Vector3(tri[i * 2], y, tri[i * 2 + 1])
	var n := PackedVector3Array()
	n.resize(v.size())
	n.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var malha := ArrayMesh.new()
	if v.size() > 0:
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


func _material(cor: Color, transparente: bool, cor_por_vertice: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = cor_por_vertice
	if transparente:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
