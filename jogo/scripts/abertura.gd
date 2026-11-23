extends Control

@onready var video: VideoStreamPlayer = $Proporcao/Video


func _ready() -> void:
	video.play()
	if not video.is_playing():
		_iniciar_turno.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_iniciar_turno()


func _iniciar_turno() -> void:
	get_tree().change_scene_to_file("res://scenes/jogo.tscn")
