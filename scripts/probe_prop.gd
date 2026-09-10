extends SceneTree

## Print a prop's mesh names and bounds, in metres.
##
##   godot --headless --script res://scripts/probe_prop.gd -- toolbox
##
## Every placement number in this game is derived from a model's real size
## rather than guessed at, and this is where the real size comes from. Guessing
## cost four rounds on the logbook's page alone.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id := String(args[0]) if args.size() > 0 else "toolbox"
	var main = load("res://src/game/main.tscn").instantiate()
	root.add_child(main)
	main.freeze()
	var n = main._prop(id)
	if n == null:
		print("no prop '%s'" % id)
		quit(0)
		return
	root.add_child(n)
	var stack: Array = [n]
	while not stack.is_empty():
		var node = stack.pop_back()
		var mi := node as MeshInstance3D
		if mi != null:
			var b := mi.get_aabb()
			print("%-34s pos=%s size=%.3f x %.3f x %.3f  from %s" % [
				mi.name, mi.position, b.size.x, b.size.y, b.size.z, b.position])
		for c in node.get_children():
			stack.append(c)
	quit(0)
