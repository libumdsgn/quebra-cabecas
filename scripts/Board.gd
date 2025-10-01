extends Control

@export var nivel: int = 1  # usado no nome do arquivo de save (user://save_level_X.json)

@onready var cells_container = $Cells

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
	# main entry: mapeia as células, tenta carregar estado salvo e finaliza setup
	mapear_celulas()
	_carregar_estado_salvo()
	
func set_main(main):
	main_ref = main
	
func _on_voltar_pressed():
	main_ref.trocar_para("res://scenes/Niveis.tscn")

func mapear_celulas() -> void:
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

		# conecta o sinal 'clicked' que o Cell emite (veja Cell.gd)
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

func _swap_with_empty(cell) -> void:
	# troca posicoes lógicas e anima troca visual
	var pos_cell = cell.posicao
	var pos_empty = empty_cell.posicao

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
	
