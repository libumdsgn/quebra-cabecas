extends TextureButton
class_name Cell

@export var id: int = 0
@export var is_empty: bool = false

var posicao: Vector2i = Vector2i.ZERO   # posição lógica (col, row)

signal clicked(cell)

func _ready() -> void:
	# conecta o clique localmente e emite o sinal com referência
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# quando clicada, avisa o board (o board se conecta a esse sinal)
	emit_signal("clicked", self)

# usado pelo Board para posicionar logicamente e visualmente a célula
func set_grid_pos(grid_pos: Vector2i, rect_pos: Vector2) -> void:
	posicao = grid_pos
	position = rect_pos

func get_grid_pos() -> Vector2i:
	return posicao
