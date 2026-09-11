extends SceneTree

## The chalkboard's slate, so the price list can be put ON it.

var _main
var _done := false

func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()

func _process(_dt: float) -> bool:
	if _done:
		return true
	_done = true
	var b = _main._shed_board
	var model: Node3D = b.get_node_or_null("Model")
	if model == null:
		print("no model")
		return true
	var box: AABB = _main._local_bounds(model)
	print("chalkboard AABB pos %s size %s" % [box.position, box.size])
	print("  slate face would sit at y %.2f..%.2f, z front %.3f" % [
		box.position.y, box.position.y + box.size.y, box.position.z])
	return true
