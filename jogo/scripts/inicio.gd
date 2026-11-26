extends Control

@onready var popup_opcoes: ColorRect = $PopupOpcoes
@onready var slider_volume: HSlider = $PopupOpcoes/Painel/Margin/VBox/HBoxVolume/SliderVolume
@onready var label_volume_valor: Label = $PopupOpcoes/Painel/Margin/VBox/HBoxVolume/LabelValor
@onready var check_tela_cheia: CheckButton = $PopupOpcoes/Painel/Margin/VBox/HBoxTelaCheia/CheckTelaCheia
@onready var sons = $SonsDoMenu

var saindo_do_menu := false


func _ready() -> void:
	popup_opcoes.visible = false
	
	# Inicializa o volume atual do bus Master
	var bus_idx := AudioServer.get_bus_index("Master")
	var current_db := AudioServer.get_bus_volume_db(bus_idx)
	slider_volume.value = db_to_linear(current_db) * 100.0
	_atualizar_texto_volume(slider_volume.value)
	
	# Inicializa estado de tela cheia
	var mode := DisplayServer.window_get_mode()
	check_tela_cheia.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	for botao: BaseButton in [
		$Botoes/BtnIniciar,
		$Botoes/BtnOpcoes,
		$Botoes/BtnSair,
		$PopupOpcoes/Painel/Margin/VBox/BtnFecharOpcoes,
		check_tela_cheia,
	]:
		botao.mouse_entered.connect(_tocar_chiado)
	check_tela_cheia.pressed.connect(_tocar_carimbo)


func _tocar_chiado() -> void:
	if not saindo_do_menu:
		sons.tocar(&"microfone")


func _tocar_carimbo() -> void:
	if not saindo_do_menu:
		sons.tocar(&"carimbo")


func _on_btn_iniciar_pressed() -> void:
	_sair_apos_carimbo(get_tree().change_scene_to_file.bind("res://scenes/abertura.tscn"))


func _on_btn_opcoes_pressed() -> void:
	if saindo_do_menu:
		return
	_tocar_carimbo()
	popup_opcoes.visible = true


func _on_btn_fechar_opcoes_pressed() -> void:
	_tocar_carimbo()
	popup_opcoes.visible = false


func _on_btn_sair_pressed() -> void:
	_sair_apos_carimbo(_encerrar_jogo)


func _encerrar_jogo() -> void:
	# Dá tempo ao servidor de áudio de liberar a reprodução antes de encerrar.
	get_tree().create_timer(0.05).timeout.connect(get_tree().quit)


func _sair_apos_carimbo(acao: Callable) -> void:
	if saindo_do_menu:
		return
	saindo_do_menu = true
	var carimbo: Tween = sons.tocar(&"carimbo")
	carimbo.finished.connect(func(): acao.call_deferred(), CONNECT_ONE_SHOT)


func _on_slider_volume_value_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	_atualizar_texto_volume(value)


func _atualizar_texto_volume(value: float) -> void:
	label_volume_valor.text = str(int(round(value))) + "%"


func _on_check_tela_cheia_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
