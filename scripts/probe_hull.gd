extends SceneTree
func _init() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var m = scene.instantiate()
	root.add_child(m)
	m.freeze(1)
	var boat = m.get_node_or_null("Boat")
	print("boat: ", boat)
	if boat:
		for c in boat.get_children():
			var mi := c as MeshInstance3D
			var extra := ""
			if mi and mi.mesh:
				extra = " verts=%d aabb=%s" % [mi.mesh.get_surface_count(), str(mi.mesh.get_aabb())]
			print("  ", c.name, " ", c.get_class(), extra)
	quit()
