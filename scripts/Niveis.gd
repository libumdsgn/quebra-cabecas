extends Control

var main_ref

func set_main(main):
	main_ref = main

func _ready():
	($BotaoNivel/Panel/Button).pressed.connect(_on_jogar_pressed)
	
func _on_jogar_pressed():
	main_ref.trocar_para("res://scenes/Jogo.tscn")
