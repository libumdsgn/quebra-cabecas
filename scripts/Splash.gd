extends Control

var main_ref

func set_main(main):
	main_ref = main

func _ready():
	$StartButton.pressed.connect(_on_iniciar_pressed)
	
func _on_iniciar_pressed():
	main_ref.trocar_para("res://scenes/Niveis.tscn")
