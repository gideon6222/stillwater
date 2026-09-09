extends SceneTree

## A balance probe, not a test. **Nothing here can fail.**
##
##   godot --headless --path . --script res://test/run_probe.gd
##
## It fishes every policy over several seeds and prints the readings a tuning
## pass needs. That is a different job from a test: a test says whether the game
## still does what it did, and this says what the game currently IS.
##
## Two reasons it is worth having from the first commit.
##
## **A single session is not a calibration.** On one game here four scripted
## policies swung 25% level to level on layout luck alone, and a `par` set from
## the first one put the best policy on three stars there and two everywhere
## else - none of which was visible in the first set of numbers, which looked
## clean and well separated. Take the mean over five or six.
##
## **The table it prints should be a description of the game.** If every policy
## fails for a different, legible reason, the columns tell you what the game
## rewards. If two of them score the same, one of them is not testing anything -
## and that is the single most useful signal this file produces.

const SEEDS := [1, 2, 3, 4, 5, 6]
const SESSION := 90.0


func _initialize() -> void:
	print("")
	print("  %-11s %6s %7s %6s %6s %8s" % ["policy", "seed", "caught", "lost", "casts", "weight"])
	print("  %s" % "-".repeat(52))

	for name in Policies.ALL:
		var caught := 0
		var lost := 0
		var casts := 0
		var weight := 0.0
		for seed_value in SEEDS:
			var r := Policies.play(name, SESSION, seed_value)
			caught += int(r["caught"])
			lost += int(r["lost"])
			casts += int(r["casts"])
			weight += float(r["total_weight"])
			print("  %-11s %6d %7d %6d %6d %8.2f" % [
				name, seed_value, r["caught"], r["lost"], r["casts"], r["total_weight"],
			])
		var n := float(SEEDS.size())
		print("  %-11s %6s %7.2f %6.2f %6.2f %8.2f" % [
			name, "MEAN", caught / n, lost / n, casts / n, weight / n])
		print("")

	_fight_lengths()
	quit(0)


## How long each species takes to land when played properly. This is the number
## that decides whether a fight is a moment or a chore, and it is not visible
## anywhere in the tuning file - it falls out of haul, stamina and the band
## together.
func _fight_lengths() -> void:
	print("  %-18s %9s %8s %8s" % ["species", "seconds", "haul", "band"])
	print("  %s" % "-".repeat(46))
	for row in Species.TABLE:
		print("  %-18s %9.1f %8.2f %8.2f" % [
			row["name"], _time_to_land(row["id"]), row["haul"], Tuning.band_half(row["band"]) * 2.0,
		])
	print("")


## Fight one species from a full-distance cast with the angler, and report how
## long it took. Returns -1 if it could not be landed at all, which is a real
## answer and a much louder one than a large number.
func _time_to_land(id: String) -> float:
	var s := Sim.new(1)
	var step := 1.0 / 60.0
	# Set the fight up directly rather than fishing for the right species. This
	# is a probe, so reaching past the input seam is acceptable here and only
	# here; the policies never do it.
	var row := Species.by_id(id)
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = id
	s.fish_weight = row["weight_lo"]
	s.fish_distance = Tuning.CAST_MAX
	s.fish_stamina = 1.0
	s.tension = Tuning.BAND_CENTRE
	s.state = Sim.FIGHTING
	s.state_time = 0.0
	var elapsed := 0.0
	for i in int(round(120.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)
		elapsed += step
	return elapsed if s.state == Sim.HOLDING else -1.0
