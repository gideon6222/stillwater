extends SceneTree

## Measure the boat's motion, and the camera's, in degrees. Pure arithmetic -
## _sync_boat_pose reads _wave_offset and a clock, so no viewport is needed.
##
##   godot --headless --path . --script res://scripts/probe_motion.gd -- 30
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 else 30.0
	var main = load("res://src/game/main.tscn").instantiate()
	root.add_child(main)
	main.freeze(1)
	var dt := 1.0 / 60.0
	var pitch: Array[float] = []
	var roll: Array[float] = []
	var heave: Array[float] = []
	var cpitch: Array[float] = []
	var croll: Array[float] = []
	var cheave: Array[float] = []
	var n := int(secs / dt)
	for i in n:
		main._tick(dt)
		pitch.append(rad_to_deg(main._boat_pitch))
		roll.append(rad_to_deg(main._boat_roll))
		heave.append(main._boat_heave)
		cpitch.append(rad_to_deg(main._cam_pitch))
		croll.append(rad_to_deg(main._cam_roll))
		cheave.append(main._cam_heave)
	_report("boat pitch (deg)", pitch, dt)
	_report("boat roll  (deg)", roll, dt)
	_report("boat heave (m)  ", heave, dt)
	print("")
	_report("CAM  pitch (deg)", cpitch, dt)
	_report("CAM  roll  (deg)", croll, dt)
	_report("CAM  heave (m)  ", cheave, dt)
	quit(0)


## Peak-to-peak, RMS, and the dominant rate: how many times a second the signal
## crosses its own mean, halved, which is the frequency you actually feel.
func _report(label: String, v: Array[float], dt: float) -> void:
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for x in v:
		lo = minf(lo, x)
		hi = maxf(hi, x)
		sum += x
	var mean := sum / float(v.size())
	var sq := 0.0
	var crossings := 0
	for i in range(1, v.size()):
		sq += (v[i] - mean) * (v[i] - mean)
		if (v[i - 1] - mean) < 0.0 and (v[i] - mean) >= 0.0:
			crossings += 1
	var rms := sqrt(sq / float(v.size()))
	var hz := float(crossings) / (float(v.size()) * dt)
	# Peak angular RATE, which is what a person feels as sway.
	var rate := 0.0
	for i in range(1, v.size()):
		rate = maxf(rate, absf(v[i] - v[i - 1]) / dt)
	print("%s  peak-to-peak %6.2f   rms %5.2f   %4.2f Hz   peak rate %6.2f /s" % [
		label, hi - lo, rms, hz, rate])
