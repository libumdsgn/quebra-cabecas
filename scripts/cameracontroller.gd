extends Camera2D

var dragging = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.is_pressed()
	elif event is InputEventMouseMotion and dragging:
		# Move the camera in the opposite direction of mouse movement
		position.x -= event.relative.x

func _process(_delta):
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if position.x <= 0:
			var tween = create_tween()
			tween.tween_property(self, "position", Vector2(10,0), 0.5)
			
		if position.x >= 1450.0:
			var tween = create_tween()
			tween.tween_property(self,"position", Vector2(1300,0.0),0.5)
