extends SceneTree

## One fight, printed. Distance, tension, stamina and phase, twice a second.

func _init() -> void:
	var id := "gar"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		id = args[0]
	var s := Sim.new(3)
	var row := Species.by_id(id)
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = id
	s.fish_weight = row["weight_lo"]
	s.fish_distance = Tuning.CAST_MAX
	s.fish_stamina = 1.0
	s.tension = Tuning.SAFE_LO
	s.running = false
	s.phase_time = 2.0
	s.state = Sim.FIGHTING
	s.state_time = 0.0
	s.lost.connect(func(reason: String) -> void: print("LOST: ", reason))
	var step := 1.0 / 60.0
	print("%s  power %.2f haul %.2f stam %.2f  escape at %.1f m" % [
		row["name"], float(row["run_power"]), float(row["haul"]),
		float(row["stamina"]), Tuning.CAST_MAX + Tuning.ESCAPE_MARGIN])
	for j in int(round(120.0 / step)):
		if s.state != Sim.FIGHTING:
			print("ended at %.1fs" % [float(j) * step])
			break
		s.set_reel(1.0 if not s.running and s.tell <= 0.0 and s.tension < Tuning.DANGER - 0.07 else 0.0)
		s.advance(step)
		if j % 30 == 0:
			print("%5.1fs  dist %5.1f  tens %.2f  strain %.2f  stam %.2f  %s" % [
				float(j) * step, s.fish_distance, s.tension, s.strain, s.fish_stamina,
				("RUN" if s.running else ("tell" if s.tell > 0.0 else "calm"))])
	quit()
