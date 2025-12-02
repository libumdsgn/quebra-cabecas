extends Control

const DEBUG := false

var main_ref

func set_main(main):
	main_ref = main

func _ready():
	var setup_salvo = _get_setup_salvo()
	_set_niveis(setup_salvo)
	_conecta_botoes_de_nveis()


func _get_setup_salvo() -> Array:
	var niveis_salvos: Array = []
	var dir = DirAccess.open("user://")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Verifica se segue o padrão: save_level_X.json
			if file_name.begins_with("save_level_") and file_name.ends_with(".json"):
				var num_str = file_name.get_slice("_", 2) # Pega a parte X de save_level_X.json
				num_str = num_str.replace(".json", "")
				var num = int(num_str)
				niveis_salvos.append(num)
			file_name = dir.get_next()
		dir.list_dir_end()

	if DEBUG:
		print("📂 Níveis salvos encontrados: ", niveis_salvos)

	return niveis_salvos


func _set_niveis(setup_salvo: Array):
	for child in get_children():
		if child is Button and "BotaoNivel" in child.name:
			var nivel_btn = int(child.text)

			# Nível 1 deve SEMPRE estar habilitado
			if nivel_btn == 1:
				child.disabled = false
				child.button_pressed = false
				continue

			# Se o nível tiver um arquivo salvo, habilita o botão
			if nivel_btn in setup_salvo:
				child.disabled = false
				child.button_pressed = true
				if DEBUG:
					push_warning("✅ Nível desbloqueado: %d" % nivel_btn)
			else:
				child.disabled = true
				child.button_pressed = false
		else:
			if DEBUG:
				push_warning("Child não é botão de nível: ", child)
	
func _conecta_botoes_de_nveis():
	for child in get_children():
		if child is Button and "BotaoNivel" in child.name:
			child.clicked.connect(_on_botao_nivel_clicado)
		else:
			push_warning("Não conectado: ", child)

func _on_botao_nivel_clicado(botao):
	GameState.current_level = botao.text
	main_ref.trocar_para("res://scenes/componentes/Board.tscn")
