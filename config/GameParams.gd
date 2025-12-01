extends Node

var tipo_boards = {
	"DEFAULT": "res://boards/cells_2x2.tscn",
	"3X2": "res://boards/cells_3x2.tscn",
	"3X4": "res://boards/cells_3x4.tscn",
	"4X5": "res://boards/cells_4x5.tscn",
}

var nivel_config ={
	1: tipo_boards["DEFAULT"],
	2: tipo_boards["DEFAULT"],
	3: tipo_boards["3X2"],
	4: tipo_boards["3X2"],
	5: tipo_boards["3X2"],
	6: tipo_boards["3X4"],
	7: tipo_boards["3X4"],
	8: tipo_boards["3X4"],
	9: tipo_boards["4X5"],
	10: tipo_boards["4X5"],
	11: tipo_boards["4X5"],
	12: tipo_boards["4X5"],
	13: tipo_boards["4X5"],
	14: tipo_boards["4X5"],
	15: tipo_boards["4X5"],
	16: tipo_boards["4X5"],
	17: tipo_boards["4X5"],
	18: tipo_boards["4X5"],
	19: tipo_boards["4X5"],
	20: tipo_boards["4X5"],
}
