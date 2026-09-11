extends SceneTree

## THE BUCKET'S ACTUAL SIZE, so the catch can be placed in it rather than near it.

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
	var well = _main._livewell_prop
	var box: AABB = _main._local_bounds(well)
	var sc: float = well.scale.x
	print("bucket local AABB pos %s size %s  scale %.2f" % [box.position, box.size, sc])
	print("  in boat space: base y %.3f  top y %.3f  width %.3f" % [
		well.position.y + box.position.y * sc,
		well.position.y + (box.position.y + box.size.y) * sc,
		minf(box.size.x, box.size.z) * sc])
	print("  a fish at scale 0.10 is %.3f m long" % (1.35 * 0.10))
	return true
