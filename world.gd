extends Node3D

@onready var camera = $Camera3D

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000.0
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if result:
			var my_id = multiplayer.get_unique_id()
			var my_player = get_node_or_null("Players/" + str(my_id))
			if my_player:
				my_player.set_target_position(result.position)
