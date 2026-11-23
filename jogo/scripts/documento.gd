extends TextureRect

signal ampliacao_solicitada(documento: TextureRect)

## Identificador do documento ("rg", "vestibular", "historico", "ficha")
@export var tipo_documento: String = ""

## Escala do documento quando está na bandeja do balcão (pequeno) vs na mesa (tamanho real de leitura)
@export var escala_bandeja: Vector2 = Vector2(0.32, 0.32)
@export var escala_mesa: Vector2 = Vector2(1.0, 1.0)

var arrastando: bool = false
var bloqueado_animacao: bool = false
var offset_clique: Vector2 = Vector2.ZERO
var tamanho_base: Vector2 = Vector2(260, 340)
var na_mesa: bool = false
var deferido: bool = false

@onready var carimbo: Label = $Carimbo


func _ready() -> void:
	resized.connect(_atualizar_fonte_carimbo)


func carimbar(aprovado: bool) -> void:
	deferido = aprovado
	carimbo.text = "DEFERIDO" if aprovado else "INDEFERIDO"
	var cor := Color("#216441") if aprovado else Color("#982e31")
	carimbo.add_theme_color_override("font_color", cor)
	_atualizar_fonte_carimbo()
	carimbo.show()


func bloquear_interacao() -> void:
	arrastando = false
	bloqueado_animacao = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


func _gui_input(event: InputEvent) -> void:
	if bloqueado_animacao:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			arrastando = false
			accept_event()
			ampliacao_solicitada.emit(self)
			return
		if event.pressed:
			arrastando = true
			move_to_front()
			offset_clique = get_global_mouse_position() - global_position
		else:
			arrastando = false


func _process(_delta: float) -> void:
	if arrastando:
		var tela := get_viewport_rect().size
		var limite_x_mesa := tela.x * 0.317 # Divisória entre o balcão azul e a mesa de madeira
		var limite_topo_mesa := tela.y * 0.330 # Topo da mesa de madeira (não deixa subir para a rua)
		var limite_topo_balcao := tela.y * 0.665 # Base do vidro do guichê (só permite ficar no balcão abaixo do vidro)
		var limite_fundo_balcao := tela.y * 0.880 # Acima dos botões do balcão
		
		var nova_pos := get_global_mouse_position() - offset_clique
		
		# Verifica se está na zona da mesa (direita) ou do balcão (esquerda)
		var centro_x := nova_pos.x + (size.x * 0.5)
		var agora_na_mesa := centro_x >= limite_x_mesa
		if agora_na_mesa != na_mesa:
			na_mesa = agora_na_mesa
			_atualizar_tamanho(true)
			nova_pos = get_global_mouse_position() - offset_clique
		
		nova_pos.x = clampf(nova_pos.x, 0.0, tela.x - size.x)
		
		if na_mesa:
			# Na mesa de madeira: pode ocupar toda a altura da mesa (do topo da mesa até o fim da tela)
			nova_pos.y = clampf(nova_pos.y, limite_topo_mesa, tela.y - size.y)
		else:
			# Na esquerda (balcão): NUNCA pode subir para o vidro da janela, só fica na bancada abaixo do vidro
			nova_pos.y = clampf(nova_pos.y, limite_topo_balcao, maxf(limite_topo_balcao, limite_fundo_balcao - size.y))
		
		global_position = nova_pos


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
	carimbo.add_theme_font_size_override("font_size", maxi(1, roundi(size.x * 0.1)))
