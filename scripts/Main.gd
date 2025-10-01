extends Node

@onready var current_scene_holder = $CurrentScene

func _ready():
	trocar_para("res://scenes/Splash.tscn")
	
func trocar_para(caminho: String) -> void:
	#limpa
	current_scene_holder.get_children().map(func(c): c.queue_free())
	
	#instancia nova
	var scene = load(caminho).instantiate()
	current_scene_holder.add_child(scene)

	#passa a referência da Main para a cena
	if scene.has_method("set_main"):
		scene.set_main(self)
