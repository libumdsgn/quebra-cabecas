extends Control

@export var nivel: int = 1  # usado no nome do arquivo de save (user://save_level_X.json)

var main_ref 
var cells: Array = []                # lista de nós Cell
var empty_cell = null                # referência ao nó que tem is_empty == true

var unique_xs: Array = []            # coordenadas X únicas (colunas, em pixels)
var unique_ys: Array = []            # coordenadas Y únicas (linhas, em pixels)

var linhas: int = 0
var colunas: int = 0

const MOVE_ANIM_SECONDS := 0.16

func _ready() -> void:
	$Button.pressed.connect(_on_voltar_pressed)
	$LevelEnd/Jogar.pressed.connect(_on_jogar_pressed)
	$LevelEnd/Proximo.pressed.connect(_on_proximo_pressed)
	$LevelEnd.visible = false
	
	print("Montando Board. GameStatus.board: ", GameState.board_setup)
	print("Montando Board. GameState.current_level: ", GameState.current_level)
	var cena_tabuleiro = _define_tabuleiro()
	mapear_celulas(cena_tabuleiro)
	_print_puzzle_state_for_debug("Estado Inicial (Após Mapeamento)")
	_shuffle()
	_resetar_contagem_movimentos_shuffle()
	_print_puzzle_state_for_debug("Estado Após Shuffle")
	#_carregar_estado_salvo()

func _on_jogar_pressed():
	#recarregar a fase!
	print("Rejogar pressed!")
	
func _on_proximo_pressed():
	#levar para a proxima fase
	GameState.current_level = GameState.current_level + 1
	main_ref.trocar_para("res://scenes/componentes/Board.tscn")
	
func _resetar_contagem_movimentos_shuffle():
	GameState.reset_moves(GameState.current_level)

func _define_tabuleiro():
	# define qual tabuleiro instanciar com base no nivel atual
	var path_tabuleiro_do_nivel = GameParams.nivel_config[GameState.current_level]
	var tabuleiro_scene = load(path_tabuleiro_do_nivel)
	
	if not tabuleiro_scene:
		push_error("Erro ao carregar o tabuleiro.")
	
	var tabuleiro_instance = tabuleiro_scene.instantiate()
	add_child(tabuleiro_instance)
	return tabuleiro_instance
	
func set_main(main):
	main_ref = main
	
func _on_voltar_pressed():
	main_ref.trocar_para("res://scenes/Niveis.tscn")

func mapear_celulas(cells_container) -> void:
	# limpa variáveis
	cells.clear()
	unique_xs.clear()
	unique_ys.clear()
	empty_cell = null

	# coleta tolerância a partir do primeiro filho para agrupar colunas/linhas
	var first_child = null
	if cells_container.get_child_count() > 0:
		first_child = cells_container.get_child(0)
	var tolerance := 10
	if first_child and first_child is Control:
		tolerance = max(10, int(first_child.size.x / 2))

	# Agrupa coordenadas X e Y
	for c in cells_container.get_children():
		if not (c is Control):
			continue
		var x = int(round(c.position.x))
		var y = int(round(c.position.y))
		_add_unique_coord(unique_xs, x, tolerance)
		_add_unique_coord(unique_ys, y, tolerance)

	unique_xs.sort()
	unique_ys.sort()

	colunas = unique_xs.size()
	linhas = unique_ys.size()

	# atribui posição lógica (col, row) para cada célula
	for c in cells_container.get_children():
		if not (c is Control):
			continue
		var x = int(round(c.position.x))
		var y = int(round(c.position.y))
		var col = _find_index_for_coord(unique_xs, x, tolerance)
		var row = _find_index_for_coord(unique_ys, y, tolerance)
		if col == -1 or row == -1:
			push_error("Board.mapear_celulas: não foi possível mapear célula '%s' (pos x= %s y= %s)" % [c.name, str(x), str(y)])
			continue
		var grid_pos = Vector2i(col, row)
		# setamos a posicao lógica e posicionamento visual padronizado (garante grid alinhado)
		if c.has_method("set_grid_pos"):
			c.set_grid_pos(grid_pos, Vector2(unique_xs[col], unique_ys[row]))
		else:
			c.posicao = grid_pos
			c.rect_position = Vector2(unique_xs[col], unique_ys[row])
			

		# registra referência
		cells.append(c)

		# marca célula vazia
		if "is_empty" in c and c.is_empty:
			empty_cell = c
		# Adiciona textura da pasta correspondente aqui
		var img_index = cells.size()
		var level_path = "res://assets/images/level_%d/%d.png" % [GameState.current_level, img_index]
		
		if FileAccess.file_exists(level_path) and c.is_empty == false:
			var tex = load(level_path)
			if "texture_normal" in c:
				c.texture_normal = tex
		else:
			push_warning("Imagem não encontrada para célula %s: %s" % [c.name, level_path])
		
		# conecta o sinal 'clicked' que o Cell emite (veja Cell.gd)
		if c.has_signal("clicked"):
			# o signal 'clicked' do Cell emite a própria célula, então basta conectar o Callable
			c.clicked.connect(Callable(self, "_on_cell_clicked"))
		else:
			# fallback: conecta pressed (caso o designer não tenha anexado nosso script)
			# pressed não envia parâmetros, então bindamos a célula para que _on_cell_clicked(c) receba o nó
			if c.has_signal("pressed"):
				c.pressed.connect(Callable(self, "_on_cell_clicked").bind(c))

	# sanity checks
	if empty_cell == null:
		push_warning("Board: nenhuma célula marcada com is_empty=true. Defina a célula vazia no editor.")
	if colunas == 0 or linhas == 0:
		push_warning("Board: colunas ou linhas detectadas como 0. Verifique a disposição das células.")

func _add_unique_coord(array_ref: Array, value: int, tol: int) -> void:
	for v in array_ref:
		if abs(v - value) <= tol:
			return
	array_ref.append(value)

func _find_index_for_coord(array_ref: Array, value: int, tol: int) -> int:
	for i in range(array_ref.size()):
		if abs(array_ref[i] - value) <= tol:
			return i
	return -1

# quando uma célula é clicada (Cell emite 'clicked' com self)
func _on_cell_clicked(cell) -> void:
	if cell == empty_cell:
		return
	if not _is_neighbor(cell, empty_cell):
		return
	_swap_with_empty(cell)
	_salvar_estado()
	if _is_solved():
		_on_victory()

func _is_neighbor(a, b) -> bool:
	# a e b têm .posicao: Vector2i(col, row)
	var diff = b.posicao - a.posicao
	if abs(diff.x) == 1 and diff.y == 0:
		return true
	if abs(diff.y) == 1 and diff.x == 0:
		return true
	return false

func _count_move():
	var lvl = GameState.current_level - 1
	var moves_this_lvl = GameState.get_moves(lvl)
	var actual_game = GameState.board_setup[lvl]
	actual_game.total_moves = moves_this_lvl + 1
	
	GameState._atualiza_movs(actual_game.total_moves, lvl)
	
func _swap_with_empty(cell) -> void:
	# troca posicoes lógicas e anima troca visual
	var pos_cell = cell.posicao
	var pos_empty = empty_cell.posicao
	_count_move()
	# atualiza campos lógicos
	cell.posicao = pos_empty
	empty_cell.posicao = pos_cell

	# calcula posições visuais alvo (a grade mapeada em unique_xs/unique_ys)
	var target_cell_rect = _grid_to_rect_pos(cell.posicao)
	var target_empty_rect = _grid_to_rect_pos(empty_cell.posicao)

	# anima com tween
	var tw = create_tween()
	tw.tween_property(cell, "position", target_cell_rect, MOVE_ANIM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(empty_cell, "position", target_empty_rect, MOVE_ANIM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _grid_to_rect_pos(grid_pos: Vector2i) -> Vector2:
	# col -> unique_xs[col], row -> unique_ys[row]
	var col = grid_pos.x
	var row = grid_pos.y
	if col < 0 or col >= unique_xs.size() or row < 0 or row >= unique_ys.size():
		return Vector2.ZERO
	return Vector2(unique_xs[col], unique_ys[row])

func _is_solved() -> bool:
	# verifica se cada célula está em sua posição final (id -> pos final)
	if colunas <= 0:
		return false
	for c in cells:
		# assumimos id de 1..N, e a célula vazia preferencialmente tem id == N
		var target = _id_para_posicao_final(int(c.id))
		if c.posicao != target:
			return false
	return true

func _id_para_posicao_final(id: int) -> Vector2i:
	# índice base 0
	var idx = id - 1
	# divisão inteira: usamos // para garantir inteiro
	var row = idx / colunas
	var col = idx % colunas
	return Vector2i(col, row)

func _on_victory() -> void:
	# placeholder: comportamento quando o puzzle é resolvido
	print("Puzzle resolvido! (nível %d)" % nivel)
	# aqui você pode notificar o GameManager, tocar som, abrir tela de vitória, etc.
	_desbloquear_nivel()
	_mostra_placar()
	$LevelEnd.visible = true
	move_child($LevelEnd, get_child_count() - 1)

func _mostra_placar():
	var lvl = GameState.current_level - 1
	$LevelEnd/Panel/movimentos.text = str(GameState.get_moves(lvl)).pad_zeros(4)

func _desbloquear_nivel():
	var next_lvl = GameState.current_level + 1
	var next_lvl_ja_liberado = false
	for board_lvl in GameState.board_setup:
		if board_lvl["nivel"] == next_lvl:
			next_lvl_ja_liberado = true
	
	if not next_lvl_ja_liberado:
		var new_lvl = {
			"nivel": next_lvl, 
			"ordem":[],
			"total_moves": 0,
		}
		GameState.board_setup.append(new_lvl)


# -------------------------
# Salvamento automático (user://)
# -------------------------
func _salvar_estado() -> void:
	var data := {
		"linhas": linhas,
		"colunas": colunas,
		"cells": []
	}
	for c in cells:
		data["cells"].append({
			"id": int(c.id),
			"pos": [int(c.posicao.x), int(c.posicao.y)],
			"is_empty": bool(c.is_empty)
		})
	var path = "user://save_level_%d.json" % nivel
	var file = FileAccess.open(path, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		#print("Board salvo em: %s" % path)
	else:
		push_error("Erro ao salvar estado em %s" % path)

func _carregar_estado_salvo() -> void:
	pass
func _shuffle(movimentos: int = 100) -> void:
	if empty_cell == null or cells.size() == 0:
		push_warning("Não é possível embaralhar: célula vazia ou células não definidas.")
		return

	# Garante que o puzzle comece em um estado resolvido
	_reset_to_solved_state()

	var last_moved_cell = null  # Para evitar mover a mesma célula de volta imediatamente

	# Realiza um número de movimentos aleatórios válidos
	for i in range(movimentos):
		var neighbors = []
		for c in cells:
			if _is_neighbor(c, empty_cell):
				# Evita mover a célula que acabou de ser movida para o espaço vazio
				if last_moved_cell != null and c == last_moved_cell:
					continue
				neighbors.append(c)
		
		if neighbors.size() == 0:
			continue
		
		var cell_to_move = neighbors[randi() % neighbors.size()]
		_swap_with_empty(cell_to_move)
		# A célula que era vazia agora contém o tile movido, então ela é a 'last_moved_cell' para o próximo loop
		last_moved_cell = cell_to_move

	# Após o embaralhamento, verifica a solubilidade e ajusta se necessário
	# Se o estado não for solúvel, realiza uma troca de duas peças (não vazias) para alterar a paridade
	# Isso garante que o puzzle se torne solúvel sem alterar a posição da célula vazia
	if not _is_solvable_state():
		var non_empty_cells = []
		for c in cells:
			if not c.is_empty:
				non_empty_cells.append(c)
		
		# Precisa de pelo menos duas peças não vazias para trocar
		if non_empty_cells.size() >= 2:
			var cell1 = non_empty_cells[0]
			var cell2 = non_empty_cells[1]
			
			# Troca as posições lógicas de cell1 e cell2
			var temp_pos = cell1.posicao
			cell1.posicao = cell2.posicao
			cell2.posicao = temp_pos
			
			# Atualiza as posições visuais (sem animação, pois é um ajuste pós-embaralhamento)
			cell1.rect_position = _grid_to_rect_pos(cell1.posicao)
			cell2.rect_position = _grid_to_rect_pos(cell2.posicao)
		else:
			push_warning("Não foi possível garantir a solubilidade: menos de duas células não vazias para trocar.")

	# Garante que o puzzle não esteja resolvido após o embaralhamento (e possível ajuste de paridade)
	if _is_solved():
		# Se ainda estiver resolvido, faz um movimento extra para garantir que não esteja
		var neighbors = []
		for c in cells:
			if _is_neighbor(c, empty_cell):
				neighbors.append(c)
		
		if neighbors.size() > 0:
			var cell_to_move = neighbors[randi() % neighbors.size()]
			_swap_with_empty(cell_to_move)


func _reset_to_solved_state() -> void:
	# Primeiro, coloca todas as células em suas posições finais baseadas no ID.
	# A célula vazia (com is_empty = true) deve ir para a última posição.

	var current_cell_positions = {}
	for c in cells:
		current_cell_positions[c] = c.posicao

	var solved_positions = {}
	var empty_cell_target_pos = Vector2i(colunas - 1, linhas - 1)

	for c in cells:
		if c.is_empty:
			solved_positions[c] = empty_cell_target_pos
		else:
			# As células não vazias devem ir para suas posições finais baseadas no ID
			solved_positions[c] = _id_para_posicao_final(int(c.id))

	# Aplica as novas posições lógicas e visuais
	for c in cells:
		c.posicao = solved_positions[c]
		c.position = _grid_to_rect_pos(c.posicao)
		if c.is_empty:
			empty_cell = c # Garante que empty_cell esteja corretamente referenciado

	# Verifica se o estado está realmente resolvido após o reset
	if not _is_solved():
		push_warning("O estado inicial resolvido não foi configurado corretamente após _reset_to_solved_state.")


func _get_inversion_count() -> int:
	var inversion_count = 0
	var tile_values = []
	# Coleta os IDs das células, ignorando a célula vazia
	for c in cells:
		if not c.is_empty:
			tile_values.append(int(c.id))

	for i in range(tile_values.size()):
		for j in range(i + 1, tile_values.size()):
			if tile_values[i] > tile_values[j]:
				inversion_count += 1
	return inversion_count

func _get_empty_cell_row_from_bottom() -> int:
	# Retorna a linha da célula vazia contando de baixo para cima (1-indexado)
	# Se a célula vazia estiver na última linha (row = linhas - 1), retorna 1
	# Se estiver na penúltima (row = linhas - 2), retorna 2, e assim por diante.
	if empty_cell == null:
		return -1 # Erro ou estado inválido
	return linhas - empty_cell.posicao.y

func _is_solvable_state() -> bool:
	var inversion_count = _get_inversion_count()
	var grid_width = colunas
	var empty_row_from_bottom = _get_empty_cell_row_from_bottom()

	if grid_width % 2 == 1: # Largura ímpar (ex: 3x3, 5x5)
		return inversion_count % 2 == 0
	else: # Largura par (ex: 4x4)
		if empty_row_from_bottom % 2 == 1: # Linha da célula vazia ímpar (de baixo para cima)
			return inversion_count % 2 == 0
		else: # Linha da célula vazia par (de baixo para cima)
			return inversion_count % 2 == 1



func _print_puzzle_state_for_debug(step_name: String) -> void:
	var grid_display = []
	for r in range(linhas):
		grid_display.append([])
		for c in range(colunas):
			grid_display[r].append("  ") # Placeholder

	for c in cells:
		var col = c.posicao.x
		var row = c.posicao.y
		if c.is_empty:
			grid_display[row][col] = "EE"
		else:
			grid_display[row][col] = str(int(c.id)).pad_zeros(2)

	for r in range(linhas):
		print(grid_display[r])

	var inv_count = _get_inversion_count()
	var empty_row = _get_empty_cell_row_from_bottom()
	var solvable = _is_solvable_state()
	var solved = _is_solved()
