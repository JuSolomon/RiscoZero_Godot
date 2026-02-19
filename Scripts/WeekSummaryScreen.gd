extends CanvasLayer

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var stats_label: RichTextLabel = $Panel/VBoxContainer/StatsLabel
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
	# Verificação de segurança: O CityStats existe?
	if not CityStats:
		return "[center][color=red]ERRO: CityStats não encontrado como Autoload![/color][/center]"

	var txt = "[center]"
	
	# --- RELATÓRIO DA SEMANA ANTERIOR ---
	txt += "[b][font_size=24]RELATÓRIO SEMANAL[/font_size][/b]\n"
	
	# Usando str() para garantir que números virem texto sem quebrar o código
	txt += "Mortes: [color=red]%s[/color]\n" % str(CityStats.last_week_deaths)
	txt += "Gastos: [color=orange]-$%s[/color]\n" % str(CityStats.last_week_expenses)
	
	var cor_pop = "green" if CityStats.last_week_pop_delta >= 0 else "red"
	txt += "Popularidade: [color=%s]%+.1f%%[/color]\n" % [cor_pop, CityStats.last_week_pop_delta]
	
	# --- PREVISÕES ---
	txt += "\n[font_size=24][b]PRÓXIMA SEMANA[/b][/font_size]\n"
	txt += "Clima: [b]%s[/b]\n" % str(CityStats.forecast_weather)
	
	# Formata a lista de eventos
	if CityStats.forecast_events.size() > 0:
		txt += "Eventos: %s" % ", ".join(CityStats.forecast_events)
	else:
		txt += "Nenhum evento previsto."
	
	txt += "[/center]"
	return txt
