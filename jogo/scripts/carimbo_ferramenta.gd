extends Control

signal selecao_solicitada(ferramenta: Control)

@export var aprovar: bool = false

var disponivel: bool = false
var selecionado: bool = false


func _ready() -> void:
	var rotulo := get_node_or_null("Rotulo") as Label
	if rotulo:
		rotulo.text = "Aprovar" if aprovar else "Reprovar"
		definir_disponivel(disponivel)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func definir_disponivel(valor: bool) -> void:
	disponivel = valor
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if valor else Control.CURSOR_ARROW
	focus_mode = Control.FOCUS_ALL if valor else Control.FOCUS_NONE
	modulate.a = 1.0 if valor else 0.45


func definir_selecionado(valor: bool) -> void:
	selecionado = valor
	tooltip_text = "Clique no local destacado da ficha" if valor else "Clique para selecionar"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not disponivel:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
			accept_event()
			selecao_solicitada.emit(self)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		accept_event()
		selecao_solicitada.emit(self)


func _get_drag_data(_posicao: Vector2) -> Variant:
	if not disponivel:
		return null

	var previa := Control.new()
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var desenho = get_script().new()
	desenho.aprovar = aprovar
	desenho.size = Vector2(84, 66)
	desenho.position = Vector2(-42, -66)
	desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previa.add_child(desenho)
	set_drag_preview(previa)
	modulate.a = 0.35
	return self


func _notification(o_que: int) -> void:
	if o_que == NOTIFICATION_DRAG_END and disponivel:
		modulate.a = 1.0


func _draw() -> void:
	var tinta := Color("#44856a") if aprovar else Color("#a34c4c")
	var contorno := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if selecionado:
		draw_rect(contorno, Color("#443b2c"))
		draw_rect(contorno, Color("#f3c662"), false, 2.0)
	elif has_focus():
		draw_rect(contorno, Color("#879bb2"), false, 1.0)
	draw_set_transform(Vector2(floorf((size.x - 84.0) * 0.5), 2.0 if selecionado else 4.0))

	# Sombra, base de borracha e placa de metal.
	draw_rect(Rect2(7, 58, 73, 4), Color("#20232b"))
	draw_rect(Rect2(6, 44, 72, 13), Color("#282424"))
	draw_rect(Rect2(8, 53, 68, 4), tinta.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 43), Vector2(16, 34), Vector2(68, 34), Vector2(78, 43),
	]), Color("#9b9388"))
	draw_rect(Rect2(6, 43, 72, 9), tinta.darkened(0.38))
	draw_rect(Rect2(10, 44, 64, 3), Color("#bbada0"))
	draw_rect(Rect2(13, 48, 58, 4), tinta)

	# Cabo de madeira chanfrado e anel da cor da tinta.
	draw_rect(Rect2(26, 34, 32, 6), Color("#493327"))
	draw_rect(Rect2(29, 32, 26, 4), tinta)
	draw_colored_polygon(PackedVector2Array([
		Vector2(29, 32), Vector2(33, 21), Vector2(27, 16), Vector2(27, 9),
		Vector2(33, 3), Vector2(51, 3), Vector2(57, 9), Vector2(57, 16),
		Vector2(51, 21), Vector2(55, 32),
	]), Color("#754b35"))
	draw_rect(Rect2(32, 7, 19, 4), Color("#b98c63"))
	draw_rect(Rect2(28, 12, 5, 4), Color("#96694a"))
	draw_rect(Rect2(51, 13, 5, 4), Color("#533627"))
	draw_rect(Rect2(35, 20, 4, 11), Color("#a67653"))
	draw_rect(Rect2(46, 22, 5, 10), Color("#533627"))
