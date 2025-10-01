extends Control

var main_ref

func set_main(main):
	main_ref = main
	
func _ready():
	$Button.pressed.connect(_on_voltar_pressed)
	
func _on_voltar_pressed():
	main_ref.trocar_para("res://scenes/Niveis.tscn")
