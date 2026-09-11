extends SceneTree

## WHERE THE ROD ACTUALLY IS ON SCREEN during a fight.
##
## The rod carries three of the things the fifth fight is supposed to say - the
## bend, the shake and the line going red - so a rod that is off the edge of a
## portrait phone says none of them. A screenshot at the wrong aspect hid this:
## at roughly square the butt was just in shot, and at the phone's 19.5:9 the
## whole rod was outside the frame.

const Policies := preload("res://test/policies.gd")


var _main
var _done := false


func _initialize() -> void:
	var main = load("res://src/game/main.tscn").instantiate()
	root.add_child(main)
	main.freeze()
	var t := 0.0
	while t < 180.0 and main.sim.state != Sim.FIGHTING:
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		Policies.act(Policies.HUMAN, main.sim, 1.0 / 60.0, _mem)
		t += 1.0 / 60.0
	if main.sim.state != Sim.FIGHTING:
		print("never hooked one")
		quit()
		return
	_main = main


## REPORTED FROM `_process`, not from `_initialize`. `unproject_position` and
## `global_position` both need the node to be inside the tree AND the tree to have
## processed a frame; called a moment too early they return an identity transform
## and every point comes back as BEHIND, which reads as a damning result and is
## actually no measurement at all.
func _process(_dt: float) -> bool:
	if _done or _main == null:
		return true
	_done = true
	for i in 5:
		for j in 60:
			Policies.act(Policies.HUMAN, _main.sim, 1.0 / 60.0, _mem)
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
		_report(_main, float(i))
	return true


var _mem := {}


func _report(main, tag: float) -> void:
	var cam: Camera3D = main._cam
	var butt: Node3D = main._rod_chain[0]
	var reel: Node3D = main._reel_crank
	var tip: Vector3 = main._rod_tip
	var size := Vector2(1080, 2338)
	print("t+%.0fs  butt %s  reel %s  tip %s" % [
		tag, _where(cam, butt.global_position, size),
		_where(cam, reel.global_position, size) if reel != null else "-",
		_where(cam, tip, size)])


## Screen position as a FRACTION of the viewport, so it is readable without
## knowing the resolution. Anything outside 0..1 is off the edge.
func _where(cam: Camera3D, p: Vector3, size: Vector2) -> String:
	if cam.is_position_behind(p):
		return "BEHIND"
	var s := cam.unproject_position(p)
	var vp := cam.get_viewport().get_visible_rect().size
	var f := Vector2(s.x / vp.x, s.y / vp.y)
	var mark := "" if (f.x >= 0.0 and f.x <= 1.0 and f.y >= 0.0 and f.y <= 1.0) else "  OFF"
	return "(%.2f, %.2f)%s" % [f.x, f.y, mark]
