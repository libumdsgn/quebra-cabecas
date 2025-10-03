extends Node

var board_setup = [
	{"nivel": 1, "ordem":[], "total_moves": 0}, 
]

var current_level : int = 1

func reset_hard():
	board_setup = [
	{"nivel": 1, "ordem":[], "total_moves": 0}, 
]
func restart_lvl(lvl:int):
	for level in board_setup:
		if level.nivel == lvl:
			level.ordem = []
			level.total_moves = 0
			
func reset_moves(lvl):
	GameState.board_setup[GameState.current_level-1].total_moves = 0

func _atualiza_movs(moves: int, level: int):
	print("_atualiza -> level: ", level)

	GameState.board_setup[level].total_moves = moves
