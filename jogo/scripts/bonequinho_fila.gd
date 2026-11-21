extends Control

## Cor da silhueta estilo Papers, Please
@export var cor_silhueta: Color = Color(0.14, 0.17, 0.24, 0.92)
@export var cor_sombra: Color = Color(0.05, 0.06, 0.09, 0.45)

var fase_passo: float = 0.0
var caminhando: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(20, 34)
	size = Vector2(20, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if caminhando:
		fase_passo += delta * 18.0
		queue_redraw()
	elif fase_passo != 0.0:
		fase_passo = 0.0
		queue_redraw()


func _draw() -> void:
	var offset_y := -absf(sin(fase_passo)) * 3.0 if caminhando else 0.0
	var balanco_perna := sin(fase_passo) * 2.5 if caminhando else 0.0
	
	# Sombra no chão
	draw_rect(Rect2(3, 30, 14, 3), cor_sombra)
	
	# Cabeça pixelada (quadradinha arredondada)
	draw_rect(Rect2(7, 3 + offset_y, 6, 2), cor_silhueta)
	draw_rect(Rect2(6, 5 + offset_y, 8, 6), cor_silhueta)
	
	# Pescoço
	draw_rect(Rect2(8, 11 + offset_y, 4, 2), cor_silhueta)
	
	# Tronco / Ombros
	draw_rect(Rect2(4, 13 + offset_y, 12, 10), cor_silhueta)
	
	# Pernas (alternam quando caminha)
	draw_rect(Rect2(5, 23 + offset_y + balanco_perna * 0.5, 4, 7), cor_silhueta)
	draw_rect(Rect2(11, 23 + offset_y - balanco_perna * 0.5, 4, 7), cor_silhueta)
