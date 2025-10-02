extends Button

signal clicked(Button)

func _ready():
	self.pressed.connect(_on_pressed)

func _on_pressed():
	emit_signal("clicked", self)
	print("I was pressed: ", self)
