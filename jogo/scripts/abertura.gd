extends Control

const MENU := preload("res://scenes/inicio.tscn")

@onready var video: VideoStreamPlayer = $Proporcao/Video


func _ready() -> void:
	video.play()
	if not video.is_playing():
		_abrir_menu.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_abrir_menu()


func _abrir_menu() -> void:
	get_tree().change_scene_to_packed(MENU)
