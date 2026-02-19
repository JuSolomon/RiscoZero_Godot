extends CanvasLayer

# Ajuste o nome do Singleton/Autoload conforme o seu projeto
# Vou assumir que se chama "TimeManager" baseado na conversa anterior
@onready var time_system = TimeManager 

@onready var container: Control = $DebugPanel

func _ready() -> void:
	# Conecta os botões
	$DebugPanel/PanelContainer/VBoxContainer/SkipDay.pressed.connect(_on_pular_dia_pressed)
	$DebugPanel/PanelContainer/VBoxContainer/SkipWeek.pressed.connect(_on_pular_semana_pressed)
	
	# Começa escondido (opcional)
	container.visible = false

func _input(event: InputEvent) -> void:
	# Único atalho: abrir/fechar o menu
	if event.is_action_pressed("toggle_debug"): # Crie essa ação no InputMap ou use ui_cancel
		container.visible = not container.visible

# --- AÇÕES DOS BOTÕES ---

func _on_pular_dia_pressed() -> void:
	print("Debug: Avançando 1 dia...")
	time_system._start_new_day() 
	# Dica: Se o jogo travar processando, adicione um await get_tree().process_frame aqui

func _on_pular_semana_pressed() -> void:
	print("Debug: Avançando 7 dias...")
	time_system._advance_week()
