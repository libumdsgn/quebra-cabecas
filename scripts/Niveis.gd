extends Control

var main_ref

func set_main(main):
	main_ref = main

func _ready():
	_conecta_botoes_de_nveis()
	
func _conecta_botoes_de_nveis():
	for child in get_children():
		if child is Button and "BotaoNivel" in child.name:
			child.clicked.connect(_on_botao_nivel_clicado)
			print("Conectando Botão: ", child)
		else:
			push_warning("Não conectado: ", child)

func _on_botao_nivel_clicado(botao):
	# aqui você sabe qual botão foi clicado
	print("Botão clicado:", botao.name)
	main_ref.trocar_para("res://scenes/componentes/Board.tscn")
