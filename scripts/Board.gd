extends Control

const DEBUG := true

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
	
	if DEBUG:
		print("\n[READY] Iniciando Board. current_level:", GameState.current_level)
	var cena_tabuleiro = _define_tabuleiro()
	mapear_celulas(cena_tabuleiro)
	if DEBUG:
		_print_map_summary("Após mapear_celulas")

	var carregado = _carregar_estado_salvo()
	if not carregado:
		_shuffle()
		_resetar_contagem_movimentos_shuffle()
	if DEBUG:
		_print_map_summary("Após possível _carregar_estado_salvo / _shuffle")

func _on_jogar_pressed():
	print("Rejogar pressed!")
	
func _on_proximo_pressed():
	GameState.current_level = GameState.current_level + 1
	main_ref.trocar_para("res://scenes/componentes/Board.tscn")
	
func _resetar_contagem_movimentos_shuffle():
	GameState.reset_moves(GameState.current_level)

func _define_tabuleiro():
	var path_tabuleiro_do_nivel = GameParams.nivel_config[GameState.current_level]
	var tabuleiro_scene = load(path_tabuleiro_do_nivel)
	if not tabuleiro_scene:
		push_error("Erro ao carregar o tabuleiro.")
	var tabuleiro_instance = tabuleiro_scene.instantiate()
	add_child(tabuleiro_instance)
	if DEBUG:
		print("[_define_tabuleiro] instancia tabuleiro de:", path_tabuleiro_do_nivel, " filhos:", tabuleiro_instance.get_child_count())
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

	if DEBUG:
		print("\n[mapear_celulas] children count:", cells_container.get_child_count())

	# coleta tolerância a partir do primeiro filho para agrupar colunas/linhas
	var first_child = null
	if cells_container.get_child_count() > 0:
		first_child = cells_container.get_child(0)
	var tolerance := 10
	if first_child and first_child is Control:
		tolerance = max(10, int(first_child.size.x / 2))
	if DEBUG:
		print("[mapear_celulas] tolerance:", tolerance)

	# Agrupa coordenadas X e Y (baseado em position atual dos filhos)
	for c in cells_container.get_children():
		if not (c is Control):
			continue
		var x = int(round(c.position.x))
		var y = int(round(c.position.y))
		if DEBUG:
			print("   child:", c.name, " raw pos:", c.position, " rounded:", Vector2(x, y))
		_add_unique_coord(unique_xs, x, tolerance)
		_add_unique_coord(unique_ys, y, tolerance)

	unique_xs.sort()
	unique_ys.sort()

	colunas = unique_xs.size()
	linhas = unique_ys.size()

	if DEBUG:
		print("[mapear_celulas] unique_xs:", unique_xs, " unique_ys:", unique_ys, " colunas:", colunas, " linhas:", linhas)

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

		if DEBUG:
			print("   mapping ->", c.name, "rounded pos:", Vector2(x, y), "-> grid pos:", grid_pos)

		# setamos a posicao lógica e posicionamento visual padronizado (garante grid alinhado)
		if c.has_method("set_grid_pos"):
			c.set_grid_pos(grid_pos, Vector2(unique_xs[col], unique_ys[row]))
			if DEBUG:
				print("      Usou set_grid_pos para", c.name)
		else:
			c.posicao = grid_pos
			c.rect_position = Vector2(unique_xs[col], unique_ys[row])
			if DEBUG:
				print("      set posicao e rect_position para", c.name, "posicao:", c.posicao, "rect_position:", c.rect_position)
			
		# registra referência
		cells.append(c)

		# marca célula vazia
		if "is_empty" in c and c.is_empty:
			empty_cell = c
			if DEBUG:
				print("      Encontrada empty_cell:", c.name)

		# Adiciona textura da pasta correspondente aqui (comportamento original)
		var img_index = cells.size()
		var level_path = "res://assets/images/level_%d/%d.png" % [GameState.current_level, img_index]
		
		if FileAccess.file_exists(level_path) and c.is_empty == false:
			var tex = load(level_path)
			if "texture_normal" in c:
				c.texture_normal = tex
			if DEBUG:
				print("      Atribuiu textura automática:", level_path, "para", c.name)
		else:
			if DEBUG:
				print("      (warn) Imagem não encontrada ou célula vazia:", level_path, " para ", c.name)
		
		# conecta o sinal 'clicked' que o Cell emite (veja Cell.gd)
		if c.has_signal("clicked"):
			c.clicked.connect(Callable(self, "_on_cell_clicked"))
		else:
			if c.has_signal("pressed"):
				c.pressed.connect(Callable(self, "_on_cell_clicked").bind(c))

	# sanity checks
	if empty_cell == null:
		push_warning("Board: nenhuma célula marcada com is_empty=true. Defina a célula vazia no editor.")
	if colunas == 0 or linhas == 0:
		push_warning("Board: colunas ou linhas detectadas como 0. Verifique a disposição das células.")

	# resumo final do mapeamento
	if DEBUG:
		_print_cells_summary("mapear_celulas - resumo final")

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
	if DEBUG:
		print("\n[_on_cell_clicked] clicada:", cell.name, " id:", cell.id, " pos:", cell.posicao)
	if cell == empty_cell:
		if DEBUG:
			print("  _on_cell_clicked: clicou na empty_cell -> ignorando")
		return
	if not _is_neighbor(cell, empty_cell):
		if DEBUG:
			print("  _on_cell_clicked: não é vizinha da empty_cell -> ignorando")
		return
	_swap_with_empty(cell)
	_salvar_estado()
	if _is_solved():
		_on_victory()

func _is_neighbor(a, b) -> bool:
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
	if DEBUG:
		print("\n[_swap_with_empty] PRE swap -> cell:", cell.name, "id:", cell.id, "pos:", cell.posicao, " empty:", empty_cell.name, "id:", empty_cell.id, "pos:", empty_cell.posicao)

	var pos_cell = cell.posicao
	var pos_empty = empty_cell.posicao
	_count_move()
	# atualiza campos lógicos
	cell.posicao = pos_empty
	empty_cell.posicao = pos_cell

	if DEBUG:
		print("[_swap_with_empty] POSITIONS LÓGICAS ATUALIZADAS -> cell:", cell.name, "pos:", cell.posicao, " empty:", empty_cell.name, "pos:", empty_cell.posicao)

	# calcula posições visuais alvo (a grade mapeada em unique_xs/unique_ys)
	var target_cell_rect = _grid_to_rect_pos(cell.posicao)
	var target_empty_rect = _grid_to_rect_pos(empty_cell.posicao)

	# anima com tween
	var tw = create_tween()
	tw.tween_property(cell, "position", target_cell_rect, MOVE_ANIM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(empty_cell, "position", target_empty_rect, MOVE_ANIM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if DEBUG:
		print("[_swap_with_empty] Tween iniciado -> target_cell_rect:", target_cell_rect, " target_empty_rect:", target_empty_rect)

func _grid_to_rect_pos(grid_pos: Vector2i) -> Vector2:
	var col = grid_pos.x
	var row = grid_pos.y
	if col < 0 or col >= unique_xs.size() or row < 0 or row >= unique_ys.size():
		return Vector2.ZERO
	return Vector2(unique_xs[col], unique_ys[row])

func _is_solved() -> bool:
	if colunas <= 0:
		if DEBUG:
			print("[_is_solved] colunas <= 0, retornando false")
		return false

	var all_correct = true
	var total_cells = cells.size()
	var correct_count = 0

	if DEBUG:
		print("\n=== [_is_solved] Verificando estado do puzzle ===")
	for c in cells:
		var id_int = int(c.id)
		var target = _id_para_posicao_final(id_int)
		var pos_atual = c.posicao
		var is_correct = pos_atual == target

		var status_text = "❌"
		if is_correct:
			status_text = "✅"
			correct_count += 1
		else:
			all_correct = false

		if DEBUG:
			print("  - Célula ID: %s | pos atual: %s | pos alvo: %s | %s" %
				[str(id_int), str(pos_atual), str(target), status_text])

	if DEBUG:
		print("Resumo: %d de %d células estão na posição correta." % [correct_count, total_cells])
		if all_correct:
			print("Resultado final: RESOLVIDO ✅")
		else:
			print("Resultado final: NÃO RESOLVIDO ❌")
		print("=== fim [_is_solved] ===\n")

	return all_correct

func _id_para_posicao_final(id: int) -> Vector2i:
	var idx = id - 1
	var row = idx / colunas
	var col = idx % colunas
	return Vector2i(col, row)

func _on_victory() -> void:
	print("Puzzle resolvido! (nível %d)" % GameState.current_level)
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
	if DEBUG:
		print("\n🔹 Salvando estado (nível %d)" % GameState.current_level)

	var data := {
		"linhas": linhas,
		"colunas": colunas,
		"cells": []
	}

	for c in cells:
		data["cells"].append({
			"id": int(c.id),
			"pos": [int(c.posicao.x), int(c.posicao.y)],
			"is_empty": bool(c.is_empty),
			"texture_path": c.texture_normal.resource_path if c.texture_normal and c.texture_normal.resource_path else ""
		})
		if DEBUG:
			print("   Salvando -> ID:%d pos:%s is_empty:%s texture:%s" % [
				c.id, str(c.posicao), str(c.is_empty),
				(c.texture_normal.resource_path if c.texture_normal else "<no-texture>")
			])

	var path = "user://save_level_%d.json" % GameState.current_level
	var file = FileAccess.open(path, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	else:
		push_error("Erro ao salvar estado em %s" % path)

func _carregar_estado_salvo() -> bool:
	if DEBUG:
		print("\n🔸 Carregando estado salvo...")

	var path = "user://save_level_%d.json" % GameState.current_level
	if not FileAccess.file_exists(path):
		push_warning("Nenhum estado salvo encontrado para o nível atual: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.ModeFlags.READ)
	if file == null:
		push_error("Falha ao abrir arquivo de save: %s" % path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var saved_data = JSON.parse_string(json_text)

	# A verificação de erro agora é checar se o resultado é 'null'.
	if saved_data == null:
		push_error("Erro ao ler ou interpretar o arquivo JSON.")
		return false

	# Agora, podemos verificar se o dado é realmente um dicionário.
	if typeof(saved_data) != TYPE_DICTIONARY:
		push_error("Erro: O dado lido do JSON não é um dicionário.")
		return false

	if typeof(saved_data) != TYPE_DICTIONARY:
		push_error("Erro: JSON lido não é um dicionário")
		return false

	var saved_cells: Array = saved_data["cells"]

	for saved_cell_data in saved_cells:
		var cell_id = int(saved_cell_data.get("id", -1))
		var cell = null
		# procura célula pelo ID
		for c in cells:
			if int(c.id) == cell_id:
				cell = c
				break
		if cell == null:
			push_warning("Célula com ID %d não encontrada na cena." % cell_id)
			continue

		# Atualiza estado
		var pos_array = saved_cell_data.get("pos", [0,0])
		cell.posicao = Vector2i(pos_array[0], pos_array[1])
		cell.position = _grid_to_rect_pos(cell.posicao)

		var was_empty = cell.is_empty
		cell.is_empty = bool(saved_cell_data.get("is_empty", false))
		if cell.is_empty:
			cell.texture_normal = null
			empty_cell = cell
		else:
			var tex_path = saved_cell_data.get("texture_path", "")
			if tex_path != "" and FileAccess.file_exists(tex_path):
				var tex = load(tex_path)
				if tex:
					cell.texture_normal = tex
				else:
					push_warning("Erro ao carregar textura: %s" % tex_path)
			# caso não exista textura salva, mantém a atual

		if DEBUG:
			print("   Carregado -> ID:%d pos:%s is_empty:%s texture:%s (was_empty=%s)" % [
				cell.id, str(cell.posicao), str(cell.is_empty),
				(cell.texture_normal.resource_path if cell.texture_normal else "<no-texture>"),
				str(was_empty)
			])

	# Garante referência à empty_cell
	if empty_cell == null:
		for c in cells:
			if c.is_empty:
				empty_cell = c
				break
	if empty_cell == null:
		push_error("Nenhuma célula marcada como vazia após carregar save!")

	if DEBUG:
		_print_cells_summary("Após _carregar_estado_salvo")
		_print_puzzle_state_for_debug("Após _carregar_estado_salvo")

	print("Estado carregado com sucesso de %s" % path)
	return true
	
func _shuffle(movimentos: int = 100) -> void:
	if empty_cell == null or cells.size() == 0:
		push_warning("Não é possível embaralhar: célula vazia ou células não definidas.")
		return

	_reset_to_solved_state()

	var last_moved_cell = null

	for i in range(movimentos):
		var neighbors = []
		for c in cells:
			if _is_neighbor(c, empty_cell):
				if last_moved_cell != null and c == last_moved_cell:
					continue
				neighbors.append(c)
		
		if neighbors.size() == 0:
			continue
		
		var cell_to_move = neighbors[randi() % neighbors.size()]
		_swap_with_empty(cell_to_move)
		last_moved_cell = cell_to_move

	if not _is_solvable_state():
		var non_empty_cells = []
		for c in cells:
			if not c.is_empty:
				non_empty_cells.append(c)
		if non_empty_cells.size() >= 2:
			var cell1 = non_empty_cells[0]
			var cell2 = non_empty_cells[1]
			var temp_pos = cell1.posicao
			cell1.posicao = cell2.posicao
			cell2.posicao = temp_pos
			cell1.rect_position = _grid_to_rect_pos(cell1.posicao)
			cell2.rect_position = _grid_to_rect_pos(cell2.posicao)
		else:
			push_warning("Não foi possível garantir a solubilidade: menos de duas células não vazias para trocar.")

	if _is_solved():
		var neighbors = []
		for c in cells:
			if _is_neighbor(c, empty_cell):
				neighbors.append(c)
		if neighbors.size() > 0:
			var cell_to_move = neighbors[randi() % neighbors.size()]
			_swap_with_empty(cell_to_move)


func _reset_to_solved_state() -> void:
	var current_cell_positions = {}
	for c in cells:
		current_cell_positions[c] = c.posicao

	var solved_positions = {}
	var empty_cell_target_pos = Vector2i(colunas - 1, linhas - 1)

	for c in cells:
		if c.is_empty:
			solved_positions[c] = empty_cell_target_pos
		else:
			solved_positions[c] = _id_para_posicao_final(int(c.id))

	for c in cells:
		c.posicao = solved_positions[c]
		c.position = _grid_to_rect_pos(c.posicao)
		if c.is_empty:
			empty_cell = c

	if not _is_solved():
		push_warning("O estado inicial resolvido não foi configurado corretamente após _reset_to_solved_state.")

func _get_inversion_count() -> int:
	var inversion_count = 0
	var tile_values = []
	for c in cells:
		if not c.is_empty:
			tile_values.append(int(c.id))

	for i in range(tile_values.size()):
		for j in range(i + 1, tile_values.size()):
			if tile_values[i] > tile_values[j]:
				inversion_count += 1
	return inversion_count

func _get_empty_cell_row_from_bottom() -> int:
	if empty_cell == null:
		return -1
	return linhas - empty_cell.posicao.y

func _is_solvable_state() -> bool:
	var inversion_count = _get_inversion_count()
	var grid_width = colunas
	var empty_row_from_bottom = _get_empty_cell_row_from_bottom()

	if grid_width % 2 == 1:
		return inversion_count % 2 == 0
	else:
		if empty_row_from_bottom % 2 == 1:
			return inversion_count % 2 == 0
		else:
			return inversion_count % 2 == 1

func _print_puzzle_state_for_debug(step_name: String) -> void:
	if DEBUG:
		print("\n[DEBUG_GRID] Step:", step_name)
	var grid_display = []
	for r in range(linhas):
		grid_display.append([])
		for c in range(colunas):
			grid_display[r].append("  ")

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
	if DEBUG:
		print("[DEBUG_GRID] inversions:", inv_count, " empty_row_from_bottom:", empty_row, " solvable:", solvable, " solved:", solved)

# Funções auxiliares de debug (resumo)
func _print_cells_summary(prefix: String) -> void:
	if not DEBUG:
		return
	print("\n[CELLS_SUMMARY] %s" % prefix)
	for c in cells:
		print("   name:%s id:%s pos:%s is_empty:%s texture:%s" % [
			c.name,
			c.id,
			str(c.posicao),
			str(c.is_empty),
			(c.texture_normal.resource_path if c.texture_normal and c.texture_normal.resource_path else "<no-texture>")
		])

func _print_map_summary(prefix: String) -> void:
	if not DEBUG:
		return
	print("\n[MAP_SUMMARY] %s -> colunas:%s linhas:%s unique_xs:%s unique_ys:%s total_cells:%s" % [
		prefix, colunas, linhas, str(unique_xs), str(unique_ys), cells.size()
	])
	_print_cells_summary(prefix)
