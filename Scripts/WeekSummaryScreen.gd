extends CanvasLayer

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var confirm_button: Button = $Panel/VBoxContainer/ConfirmButton
@onready var background: ColorRect = $Background
@onready var panel: PanelContainer = $Panel

func _ready() -> void:
	# Garante que a tela comece invisível
	hide()
	
	# Conecta o botão
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Conecta ao sinal do TimeManager (assumindo que ele é um Autoload/Singleton)
	if TimeManager:
		TimeManager.week_ended.connect(_on_week_ended)

func _on_week_ended(week_in_year: int, year_in_term: int, term_index: int) -> void:
	# 1. Atualiza os Textos
	title_label.text = "Fim da Semana %d - Ano %d" % [week_in_year, year_in_term]
	
	# Aqui você puxaria os dados do seu EconomyManager ou CityManager
	stats_label.text = _gerar_texto_resumo()
	
	# 2. Mostra a tela
	show()
	
	# 3. PAUSA TOTAL (Opcional, mas recomendado)
	# Isso para animações, shaders e impede cliques no mapa da cidade
	get_tree().paused = true

func _on_confirm_pressed() -> void:
	# 1. Esconde a tela
	hide()
	
	# 2. Despausa o jogo
	get_tree().paused = false
	
	# 3. Manda o TimeManager avançar de verdade
	TimeManager.start_next_week()

# Função auxiliar para formatar o texto (Personalize com seus dados reais)
func _gerar_texto_resumo() -> String:
	# Exemplo de como formatar. Substitua pelos seus Singletons reais.
	# var saldo = EconomyManager.get_balance()
	# var pop = CityManager.get_population()
	
	# Valores fictícios para teste:
	var saldo_anterior = 5000
	var lucro_semana = 1200
	var novos_habitantes = 45
	
	var texto = ""
	texto += "Receita Fiscal: +$%d\n" % lucro_semana
	texto += "Custos de Manutenção: -$%d\n" % 300
	texto += "----------------\n"
	texto += "Saldo Atual: $%d\n\n" % (saldo_anterior + lucro_semana - 300)
	texto += "Crescimento Populacional: +%d cidadãos" % novos_habitantes
	
	return texto
