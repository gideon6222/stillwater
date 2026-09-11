extends SceneTree

## WHERE THE TURNING LEAF ACTUALLY IS, against the page it is meant to cover.

var _main
var _done := false

func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	if _main._title != null:
		_main._title.skip()
	_main.sim.deepest_ever = 60.0
	_main._open_book()
	for i in 180:
		_main.advance(1.0 / 60.0, 1.0 / 60.0)

func _process(_dt: float) -> bool:
	if _done:
		# A few frames for the renderer to settle, then capture from HERE rather
		# than through shot.gd - which runs a pile of room setup between the turn
		# and the shutter and was a suspect in its own right.
		_shots -= 1
		if _shots <= 0:
			_shoot()
			return true
		return false
	_done = true
	var book = _main._book
	_main._turn_page(1)
	for i in 6:
		_main.advance(1.0 / 60.0, 1.0 / 60.0)
	var surf: Node3D = book._surface
	var front: Node3D = book._leaf_front
	var back: Node3D = book._leaf_back
	var pivot: Node3D = book._leaf
	print("angle %.1f deg  leaf.visible %s  surface.visible %s" % [
		rad_to_deg(book.leaf_angle()), pivot.visible, surf.visible])
	print("page   local-to-book %s" % surf.transform.origin)
	print("pivot  local-to-book %s" % pivot.transform.origin)
	print("front  local-to-book %s" % (pivot.transform * front.transform).origin)
	print("back   local-to-book %s" % (pivot.transform * back.transform).origin)
	print("page normal %s" % surf.transform.basis.z.normalized())
	print("front normal %s" % (pivot.transform * front.transform).basis.z.normalized())
	var fm = front.material_override
	print("front material: transparency %d priority %d cull %d tex %s" % [
		fm.transparency, fm.render_priority, fm.cull_mode,
		"yes" if fm.albedo_texture != null else "NONE"])
	print("front mesh size %s" % (front.mesh as QuadMesh).size)
	print("front in tree %s  visible_in_tree %s  parent %s" % [
		front.is_inside_tree(), front.is_visible_in_tree(), front.get_parent().name])
	print("pivot in tree %s  visible_in_tree %s  parent %s" % [
		pivot.is_inside_tree(), pivot.is_visible_in_tree(), pivot.get_parent().name])
	print("surface in tree %s  visible_in_tree %s  parent %s" % [
		surf.is_inside_tree(), surf.is_visible_in_tree(), surf.get_parent().name])
	print("book layers: surface %d front %d" % [surf.layers, front.layers])
	var cam: Camera3D = _main._cam
	print("cam cull_mask %d" % cam.cull_mask)
	# WHERE EACH ONE ACTUALLY LANDS, in camera space. `z` is the answer: negative
	# is in front of the lens, positive is behind it.
	var inv := cam.global_transform.affine_inverse()
	print("page  in cam space %s" % (inv * surf.global_transform.origin))
	print("front in cam space %s" % (inv * front.global_transform.origin))
	print("back  in cam space %s" % (inv * back.global_transform.origin))
	print("pivot in cam space %s" % (inv * pivot.global_transform.origin))
	_shots = 3
	return false


var _shots := 0

func _shoot() -> void:
	var img := root.get_texture().get_image()
	img.save_png("user://probe_leaf.png")
	print("wrote %s/probe_leaf.png  angle %.1f" % [
		OS.get_user_data_dir(), rad_to_deg(_main._book.leaf_angle())])
