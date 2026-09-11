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
	for nm in ["Shed_counter", "Shed_shelf", "Shed_rack"]:
		var n: Node3D = _main._shed.get_node_or_null(nm)
		if n == null:
			print("  %s: missing" % nm)
			continue
		var b2: AABB = _main._local_bounds(n)
		var sc: float = n.scale.x
		print("  %s at %s scale %.2f -> top y %.3f, width %.3f, depth %.3f" % [
			nm, n.position, sc,
			n.position.y + (b2.position.y + b2.size.y) * sc,
			b2.size.x * sc, b2.size.z * sc])
	return true
