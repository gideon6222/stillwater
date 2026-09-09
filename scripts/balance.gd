extends SceneTree

## Prints the land rate for every species, grouped by band, so balance is a
## table you read rather than a number you guess at. Not a test - the test
## asserts the shape, this shows the numbers that make the shape.

const Policies := preload("res://test/policies.gd")


func _win_rate(id: String, tries: int) -> float:
	var won := 0
	for i in tries:
		var s := Sim.new(i + 1)
		var mem := {}
		var step := 1.0 / 60.0
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
		for j in int(round(120.0 / step)):
			if s.state != Sim.FIGHTING:
				break
			Policies.act(Policies.HUMAN, s, step, mem)
			s.advance(step)
		if s.state == Sim.HOLDING:
			won += 1
	return float(won) / float(tries)


func _init() -> void:
	var tries := 24
	for band in World.BANDS:
		var total := 0.0
		var n := 0
		var lines: Array[String] = []
		for row in Species.TABLE:
			if row["band"] != band["id"]:
				continue
			var r := _win_rate(row["id"], tries)
			total += r
			n += 1
			lines.append("    %-18s %3.0f%%  stam %.2f  haul %.2f  run %.2f  win %.2f" % [
				row["name"], r * 100.0, float(row["stamina"]), float(row["haul"]),
				float(row["run_chance"]), float(row["take_window"])])
		if n == 0:
			continue
		print("%-16s  mean %3.0f%%" % [band["name"], total / float(n) * 100.0])
		for l in lines:
			print(l)
	quit()
