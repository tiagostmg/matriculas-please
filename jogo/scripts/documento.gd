extends TextureRect

signal ampliacao_solicitada(documento: TextureRect)
signal carimbo_solicitado(aprovado: bool)
signal area_de_trabalho_alterada

const CARIMBO_FERRAMENTA := preload("res://scripts/carimbo_ferramenta.gd")

## Identificador do documento ("rg", "vestibular", "historico", "ficha")
@export var tipo_documento: String = ""

## Escala do documento quando está na bandeja do balcão (pequeno) vs na mesa (tamanho real de leitura)
@export var escala_bandeja: Vector2 = Vector2(0.32, 0.32)
@export var escala_mesa: Vector2 = Vector2(1.0, 1.0)

var arrastando: bool = false
var bloqueado_animacao: bool = false
var offset_clique: Vector2 = Vector2.ZERO
var offset_divisoria_x := 0.0
var tamanho_base: Vector2 = Vector2(260, 340)
var na_mesa: bool = false
var deferido: bool = false
var carimbo_selecionado: Control
var arrastando_carimbo: bool = false
var animacao_alvo: Tween

@onready var carimbo: Label = $Carimbo
@onready var alvo_carimbo: Panel = $AlvoCarimbo
@onready var rotulo_alvo: Label = $AlvoCarimbo/Rotulo


func _ready() -> void:
	resized.connect(_atualizar_fonte_carimbo)


func carimbar(aprovado: bool) -> void:
	deferido = aprovado
	carimbo.text = "DEFERIDO" if aprovado else "INDEFERIDO"
	var cor := Color("#216441") if aprovado else Color("#982e31")
	var moldura := carimbo.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	moldura.border_color = cor
	carimbo.add_theme_stylebox_override("normal", moldura)
	carimbo.add_theme_color_override("font_color", cor)
	_atualizar_fonte_carimbo()
	carimbo.show()


func bloquear_interacao() -> void:
	arrastando = false
	bloqueado_animacao = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	selecionar_carimbo(null)


func selecionar_carimbo(ferramenta: Control) -> void:
	carimbo_selecionado = ferramenta
	_atualizar_alvo_carimbo()


func configurar(tex: Texture2D, tipo: String, pos_inicial: Vector2, comeca_na_mesa: bool = false) -> void:
	texture = tex
	tipo_documento = tipo
	
	if tex:
		var proporcao := float(tex.get_height()) / float(tex.get_width())
		tamanho_base = Vector2(260.0, 260.0 * proporcao)
	
	na_mesa = comeca_na_mesa
	_atualizar_tamanho(false)
	position = pos_inicial


func animar_chegada(pos_origem: Vector2, pos_destino: Vector2, atraso: float = 0.0, duracao: float = 0.35) -> void:
	bloqueado_animacao = true
	position = pos_origem
	modulate.a = 0.0
	
	var tween := create_tween()
	if atraso > 0.0:
		tween.tween_interval(atraso)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(self, "position", pos_destino, duracao).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): bloqueado_animacao = false)


func _aceita_carimbo(data: Variant) -> bool:
	return (
		tipo_documento == "ficha"
		and not bloqueado_animacao
		and not carimbo.visible
		and data is CARIMBO_FERRAMENTA
		and data.disponivel
	)


func _can_drop_data(posicao: Vector2, data: Variant) -> bool:
	return _aceita_carimbo(data) and alvo_carimbo.get_rect().has_point(posicao)


func _drop_data(posicao: Vector2, data: Variant) -> void:
	if _can_drop_data(posicao, data):
		_aplicar_carimbo(data.aprovar)


func _aplicar_carimbo(aprovado: bool) -> void:
	carimbo_solicitado.emit(aprovado)
	if carimbo.visible:
		carimbo.pivot_offset = carimbo.size * 0.5
		carimbo.scale = Vector2(1.10, 1.10)
		carimbo.create_tween().tween_property(carimbo, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _atualizar_alvo_carimbo() -> void:
	var mostrar := _aceita_carimbo(carimbo_selecionado) or arrastando_carimbo
	if alvo_carimbo.visible == mostrar:
		return

	alvo_carimbo.visible = mostrar
	if mostrar:
		alvo_carimbo.modulate.a = 1.0
		animacao_alvo = alvo_carimbo.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		animacao_alvo.tween_property(alvo_carimbo, "modulate:a", 0.74, 0.48)
		animacao_alvo.tween_property(alvo_carimbo, "modulate:a", 1.0, 0.48)
	elif animacao_alvo:
		animacao_alvo.kill()
		animacao_alvo = null


func _notification(o_que: int) -> void:
	if not is_node_ready():
		return
	if o_que == NOTIFICATION_DRAG_BEGIN and _aceita_carimbo(get_viewport().gui_get_drag_data()):
		arrastando_carimbo = true
		_atualizar_alvo_carimbo()
	elif o_que == NOTIFICATION_DRAG_END and arrastando_carimbo:
		arrastando_carimbo = false
		_atualizar_alvo_carimbo()


func _gui_input(event: InputEvent) -> void:
	if bloqueado_animacao:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _can_drop_data(event.position, carimbo_selecionado):
			arrastando = false
			accept_event()
			_aplicar_carimbo(carimbo_selecionado.aprovar)
			return
		if event.pressed and event.double_click:
			arrastando = false
			accept_event()
			ampliacao_solicitada.emit(self)
			return
		if event.pressed:
			arrastando = true
			move_to_front()
			offset_clique = get_global_mouse_position() - global_position
			# A referência permanece fixa durante o arraste, mesmo após redimensionar.
			offset_divisoria_x = size.x * 0.5 - offset_clique.x
		else:
			arrastando = false


func _process(_delta: float) -> void:
	if arrastando:
		_arrastar_para(get_global_mouse_position())


func _arrastar_para(mouse: Vector2) -> void:
	var tela := get_viewport_rect().size
	var limite_x_mesa := tela.x * 0.317 # Divisória entre o balcão azul e a mesa de madeira
	var limite_topo_mesa := tela.y * 0.330
	var limite_topo_balcao := tela.y * 0.665 # Base do vidro do guichê
	var limite_fundo_balcao := tela.y * 0.880 # Acima dos botões do balcão

	var agora_na_mesa := mouse.x + offset_divisoria_x >= limite_x_mesa
	var mudou_de_area := agora_na_mesa != na_mesa
	if mudou_de_area:
		na_mesa = agora_na_mesa
		_atualizar_tamanho(true)

	var nova_pos := mouse - offset_clique
	nova_pos.x = clampf(nova_pos.x, 0.0, tela.x - size.x)
	if na_mesa:
		nova_pos.y = clampf(nova_pos.y, limite_topo_mesa, tela.y - size.y)
	else:
		nova_pos.y = clampf(nova_pos.y, limite_topo_balcao, maxf(limite_topo_balcao, limite_fundo_balcao - size.y))
	global_position = nova_pos
	if mudou_de_area:
		area_de_trabalho_alterada.emit()


func _atualizar_tamanho(manter_sob_mouse: bool) -> void:
	var tela := get_viewport_rect().size
	# Escala proporcional à resolução da tela (base 1152px de largura)
	var fator_tela := clampf(tela.x / 1152.0, 0.8, 2.0)
	var escala := (escala_mesa if na_mesa else escala_bandeja) * fator_tela
	var novo_tamanho := tamanho_base * escala
	
	if manter_sob_mouse and arrastando:
		var proporcao_offset := offset_clique / size if size.x > 0 and size.y > 0 else Vector2(0.5, 0.5)
		size = novo_tamanho
		offset_clique = size * proporcao_offset
	else:
		size = novo_tamanho


func _atualizar_fonte_carimbo() -> void:
	var tamanho_fonte := maxi(1, roundi(size.x * 0.1))
	carimbo.add_theme_font_size_override("font_size", tamanho_fonte)
	rotulo_alvo.add_theme_font_size_override("font_size", mini(24, tamanho_fonte))
