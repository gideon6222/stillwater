extends SceneTree

## WHAT EACH BOT DOES WITH THE DIAL, on one deep fish, so the sixth fight's bots
## can be set from numbers rather than from what a controller "should" do.
##
##   godot --headless --path . --script res://scripts/probe_dial.gd -- [species_id] [seeds]
##
## Per policy over N seeds: outcome counts, mean fight length, mean peak tension,
## mean peak strain, mean metres GIVEN (line paid out on purpose), mean metres
## the fish TOOK in runs, and the share of the fight spent over the danger line.
## The last three are what separate a bot that reads the water from one that
## reads the rod: the water-reader should take less strain for the same ground.

const Policies := preload("res://test/policies.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var species := "old_fish"
	var seeds := 12
	if args.size() > 0:
		species = String(args[0])
	if args.size() > 1:
		seeds = int(args[1])
	var row := Species.by_id(species)
	if row.is_empty():
		print("no species '%s'" % species)
		quit(1)
		return
	print("%s  power %.2f  haul %.2f  stam %.2f  crank settle fresh %.2f  run settle held %.2f  danger %.2f" % [
		row["name"], float(row["run_power"]), float(row["haul"]), float(row["stamina"]),
		Tuning.crank_settle(float(row["run_power"]), 1.0, 1.0),
		(Tuning.HOLD_RISE * Tuning.resist(float(row["run_power"]), 1.0)
			+ Tuning.PULL_RISE * float(row["run_power"]) * float(row["run_power"])) / Tuning.TAP_DECAY,
		Tuning.DANGER])
	print("%-9s %-28s %6s %6s %6s %7s %7s %6s" % [
		"policy", "outcomes", "secs", "peakT", "strain", "given", "taken", "over%"])
	for policy in [Policies.GIVER, Policies.BLIND, Policies.ANGLER, Policies.HUMAN]:
		var outcomes := {}
		var secs := 0.0
		var peak_t := 0.0
		var peak_s := 0.0
		var given := 0.0
		var taken := 0.0
		var over := 0.0
		for seed_value in seeds:
			var r := _fight(policy, row, seed_value + 1)
			var o: String = r["outcome"]
			outcomes[o] = int(outcomes.get(o, 0)) + 1
			secs += r["secs"]
			peak_t += r["peak_t"]
			peak_s += r["peak_s"]
			given += r["given"]
			taken += r["taken"]
			over += r["over"]
		var n := float(seeds)
		var parts: Array[String] = []
		for k in outcomes.keys():
			parts.append("%s %d" % [k, outcomes[k]])
		print("%-9s %-28s %6.1f %6.2f %6.2f %7.1f %7.1f %5.0f%%" % [
			policy, ", ".join(parts), secs / n, peak_t / n, peak_s / n, given / n, taken / n,
			100.0 * over / n])
	quit(0)


func _fight(policy: String, row: Dictionary, seed_value: int) -> Dictionary:
	var s := Sim.new(seed_value)
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = str(row["id"])
	s.fish_weight = float(row["weight_lo"])
	s.fish_distance = Tuning.CAST_MAX
	s.fish_stamina = 1.0
	s.tension = Tuning.SAFE_LO
	s.running = false
	s.tell = 0.0
	s.phase_time = 4.0
	s.state = Sim.FIGHTING
	var why := {"o": ""}
	s.lost.connect(func(reason: String) -> void:
		why["o"] = "broke" if reason == Sim.BROKE else "escaped")
	var step := 1.0 / 60.0
	var mem := {}
	var secs := 0.0
	var peak_t := 0.0
	var peak_s := 0.0
	var given := 0.0
	var taken := 0.0
	var over := 0.0
	var last_d: float = s.fish_distance
	for i in int(round(180.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		Policies.act(policy, s, step, mem)
		s.advance(step)
		secs += step
		peak_t = maxf(peak_t, s.tension)
		peak_s = maxf(peak_s, s.strain)
		if s.tension > Tuning.DANGER:
			over += step
		if s.reel < 0.0:
			given += Tuning.GIVE_RATE * -s.reel * step
		if s.running and s.fish_distance > last_d:
			taken += s.fish_distance - last_d
		last_d = s.fish_distance
	var outcome: String = "landed" if s.state == Sim.HOLDING else String(why["o"])
	if outcome == "":
		outcome = "clock"
	return {"outcome": outcome, "secs": secs, "peak_t": peak_t, "peak_s": peak_s,
		"given": given, "taken": taken, "over": over / maxf(0.01, secs)}
