extends SceneTree

## WHERE EVERYTHING ACTUALLY IS, and whether its parts agree with each other.
##
## Gideon, from a screenshot: "it looks like the book is on the ground but the
## pages are in the air on the left. there are also planks and sticks sticking up
## on the right."
##
## A Room3D is a MODEL and a SURFACE, and nothing makes them stay together except
## both being children of the same node - so a surface transform written in the
## wrong basis, or a model whose origin is not where its mesh is, separates them
## silently and each half still renders perfectly. This prints the gap.

const Policies := preload("res://test/policies.gd")

var _main
var _done := false
var _mode := "boat"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = String(args[0])
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	if _main._title != null:
		_main._title.skip()
	_main.sim.deepest_ever = 60.0
	for i in 120:
		_main.advance(1.0 / 60.0, 1.0 / 60.0)
	if _mode == "book":
		_main._open_book()
		for i in 180:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
	elif _mode == "chart":
		_main._open_chart()
		for i in 120:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)


func _process(_dt: float) -> bool:
	if _done:
		return true
	_done = true
	var cam: Camera3D = _main._cam
	print("--- %s ---" % _mode)

	_room("logbook", _main._book)
	_room("chart", _main._chart)
	_room("tacklebox", _main._tacklebox)
	if _main._shed_board != null:
		_room("shed board", _main._shed_board)

	print("")
	print("%-14s %-26s %-26s %s" % ["thing", "aim point (screen)", "its mesh (screen)", "gap"])
	for t in _main._things:
		var id := String(t["id"])
		var aim: Vector3 = t["at"]
		var world_aim: Vector3 = _main._boat_pose * aim
		var centre := _mesh_centre(id)
		var gap := "-"
		if centre != Vector3.INF:
			gap = "%.3f m" % world_aim.distance_to(centre)
		print("%-14s %-26s %-26s %s" % [
			id, _where(cam, world_aim), _where(cam, centre), gap])
	return true


## A Room3D's two halves, and how far apart they are.
func _room(label: String, r) -> void:
	if r == null:
		print("%-12s MISSING" % label)
		return
	var model: Node3D = r.get_node_or_null("Model")
	var surface: Node3D = r.get_node_or_null("Page")
	var mw := Vector3.INF
	var sw := Vector3.INF
	if model != null:
		mw = _world_of(model)
	if surface != null:
		sw = _world_of(surface)
	var gap := "-"
	if mw != Vector3.INF and sw != Vector3.INF:
		gap = "%.3f m" % mw.distance_to(sw)
	print("%-12s model %-24s page %-24s apart %s  surface_on %s" % [
		label, _fmt(mw), _fmt(sw), gap,
		str(surface.visible) if surface != null else "-"])


func _mesh_centre(id: String) -> Vector3:
	var names: Array = _main.AIM_NODE.get(id, [])
	var total := Vector3.ZERO
	var n := 0
	for want in names:
		var node: Node3D = _find(_main._boat, String(want))
		if node == null:
			continue
		var box: AABB = _main._local_bounds(node)
		if box.size == Vector3.ZERO:
			continue
		total += _world_of(node) + (_world_xform(node).basis * (box.position + box.size * 0.5))
		n += 1
	if n == 0:
		return Vector3.INF
	return total / float(n)


func _find(from: Node, want: String) -> Node3D:
	if want.find("/") >= 0:
		var at: Node = from
		for part in want.split("/"):
			if at == null:
				return null
			at = at.get_node_or_null(String(part))
			if at == null:
				at = _find(from, String(part))
		return at as Node3D
	var stack: Array = [from]
	while not stack.is_empty():
		var n = stack.pop_back()
		if String(n.name) == want:
			return n as Node3D
		for c in n.get_children():
			stack.append(c)
	return null


func _world_xform(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node3D = node
	while n != null and n != _main:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


func _world_of(node: Node3D) -> Vector3:
	return _world_xform(node).origin


func _fmt(v: Vector3) -> String:
	if v == Vector3.INF:
		return "-"
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


## Screen position as a fraction of a 1080x2338 frame. Outside 0..1 is off.
func _where(cam: Camera3D, p: Vector3) -> String:
	if p == Vector3.INF:
		return "-"
	var local := cam.global_transform.affine_inverse() * p
	if local.z >= -0.0001:
		return "BEHIND"
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	var f := Vector2(
		0.5 + ((local.x / -local.z) / (half * (1080.0 / 2338.0))) * 0.5,
		0.5 - ((local.y / -local.z) / half) * 0.5)
	var mark := "" if (f.x >= 0.0 and f.x <= 1.0 and f.y >= 0.0 and f.y <= 1.0) else " OFF"
	return "(%.2f, %.2f)%s" % [f.x, f.y, mark]
