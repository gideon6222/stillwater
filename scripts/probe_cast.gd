extends SceneTree

## THE CAST'S MOTION, AS NUMBERS. Samples the rod butt's pitch every frame
## through a charge, a throw and the settle, and reports the largest jump in
## angular velocity between consecutive frames at each state boundary - which is
## what "the movement has felt odd" is when it is measured: a rod that changes
## speed in one frame reads as a mechanism, not an arm.
##
##   godot --headless --path . --script res://scripts/probe_cast.gd -- [charge_seconds]
func _initialize() -> void:
	var hold := 0.55
	for a in OS.get_cmdline_user_args():
		hold = float(a)
	var main = load("res://src/game/main.tscn").instantiate()
	main.freeze(1)
	var dt := 1.0 / 60.0
	var butt: Node3D = main._rod
	var angles: Array[float] = []
	var states: Array[String] = []
	main.sim.hold_cast()
	var t := 0.0
	while t < hold:
		main.advance(dt, dt)
		angles.append(butt.rotation_degrees.x)
		states.append(main.sim.state)
		t += dt
	main.sim.release_cast()
	var n := 0
	while n < 240 and main.sim.state != Sim.NIBBLING and main.sim.state != Sim.WAITING and main.sim.state != Sim.LOST:
		main.advance(dt, dt)
		angles.append(butt.rotation_degrees.x)
		states.append(main.sim.state)
		n += 1
	var vel: Array[float] = []
	for i in angles.size():
		vel.append(0.0 if i == 0 else (angles[i] - angles[i - 1]) / dt)
	print("frames %d  charge %.2f s  min pitch %.1f  max pitch %.1f" % [
		angles.size(), hold, angles.min(), angles.max()])
	var worst := 0.0
	var worst_at := 0
	for i in range(1, vel.size()):
		var jump := absf(vel[i] - vel[i - 1])
		if states[i] != states[i - 1] or jump > worst * 0.5:
			pass
		if jump > worst:
			worst = jump
			worst_at = i
	print("largest velocity jump %.0f deg/s in one frame at frame %d (%s -> %s), pitch %.1f" % [
		worst, worst_at, states[worst_at - 1], states[worst_at], angles[worst_at]])
	for i in range(1, states.size()):
		if states[i] != states[i - 1]:
			var j := absf(vel[i] - vel[i - 1])
			print("  boundary %s -> %s at frame %d: pitch %.1f, vel %.0f -> %.0f deg/s (jump %.0f)" % [
				states[i - 1], states[i], i, angles[i], vel[i - 1], vel[i], j])
	var peak := 0.0
	for v in vel:
		peak = maxf(peak, absf(v))
	print("peak angular speed %.0f deg/s" % peak)
	main.free()
	quit(0)
