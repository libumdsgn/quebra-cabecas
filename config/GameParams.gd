extends Node

var tipo_boards = {
	"DEFAULT": "res://boards/cells_2x2.tscn",
	"3X2": "res://boards/cells_3x2.tscn",
	"3X4": "res://boards/cells_3x4.tscn",
	"4X5": "res://boards/cells_4x5.tscn",
}

var nivel_config ={
	1: tipo_boards["DEFAULT"],
	2: tipo_boards["3X2"],
	3: tipo_boards["3X2"],
	4: tipo_boards["3X2"],
	5: tipo_boards["3X2"],
	7: tipo_boards["3X2"],
	8: tipo_boards["3X2"],
	9: tipo_boards["3X2"],
	10: tipo_boards["3X4"],
	11: tipo_boards["3X4"],
	12: tipo_boards["3X4"],
	13: tipo_boards["3X4"],
	14: tipo_boards["3X4"],
	15: tipo_boards["4X5"],
	16: tipo_boards["4X5"],
	17: tipo_boards["4X5"],
	18: tipo_boards["4X5"],
	19: tipo_boards["4X5"],
	20: tipo_boards["4X5"],
}
