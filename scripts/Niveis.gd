extends Control

var main_ref

func set_main(main):
	main_ref = main

func _ready():
	_set_niveis()
	_conecta_botoes_de_nveis()
	
func _set_niveis():
	for child in get_children():
		if child is Button and "BotaoNivel" in child.name:
			for board in GameState.board_setup:
				if str(child.text) != str(board["nivel"]): 
					child.disabled = true
				else:
					push_warning("Nivel Conquistado")
		else:
			push_warning("Child não é nível: ", child)
	
func _conecta_botoes_de_nveis():
	for child in get_children():
		if child is Button and "BotaoNivel" in child.name:
			child.clicked.connect(_on_botao_nivel_clicado)
		else:
			push_warning("Não conectado: ", child)

func _on_botao_nivel_clicado(botao):
	GameState.current_level = botao.text
	main_ref.trocar_para("res://scenes/componentes/Board.tscn")
