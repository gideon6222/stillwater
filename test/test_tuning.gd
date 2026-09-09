extends RefCounted

## Tests over the tuning curves and the species table.
##
## These check the SHAPE of the numbers rather than their values, because the
## values are meant to be changed. A test that pins a constant makes tuning
## painful and catches nothing; a test that pins the relationship between two
## constants catches the change that breaks the game.


func test_cast_distance_spans_the_advertised_range(t: TestHarness) -> void:
	t.approx(Tuning.cast_distance(0.0), Tuning.CAST_MIN, 1e-6, "a tap casts the minimum")
	t.approx(Tuning.cast_distance(1.0), Tuning.CAST_MAX, 1e-6, "a full charge casts the maximum")
	t.gt(Tuning.CAST_MAX, Tuning.CAST_MIN, "a full cast must go further than a tap")

	# Monotonic, so more hold is never less distance. A non-monotonic charge
	# curve is unlearnable however good the numbers look at the ends.
	var prev := -1.0
	for i in 21:
		var d := Tuning.cast_distance(float(i) / 20.0)
		t.gt(d, prev, "cast distance rises with charge at %d%%" % (i * 5))
		prev = d


func test_cast_distance_is_clamped_outside_the_unit_range(t: TestHarness) -> void:
	t.approx(Tuning.cast_distance(-1.0), Tuning.CAST_MIN, 1e-6, "negative charge clamps to the minimum")
	t.approx(Tuning.cast_distance(9.0), Tuning.CAST_MAX, 1e-6, "over-charge clamps to the maximum")


func test_flight_time_is_a_playable_length(t: TestHarness) -> void:
	var short_cast := Tuning.cast_flight_seconds(0.0)
	var long_cast := Tuning.cast_flight_seconds(1.0)
	t.gt(long_cast, short_cast, "a longer cast takes longer to land")
	t.gt(short_cast, 0.1, "even a tap has visible flight time")
	t.lt(long_cast, 2.0, "the longest cast must not feel like waiting")


## The pump window has to be a real gap, or the mechanic collapses back into a
## threshold fight where any wobble around one position counts as pumping.
func test_the_pump_window_is_a_real_stroke(t: TestHarness) -> void:
	t.gt(Tuning.PUMP_HIGH - Tuning.PUMP_LOW, 0.25,
		"the lift and the drop are so close together that a twitch is a pump")
	t.gt(Tuning.PUMP_LOW, 0.0, "the drop goes all the way to slack, which is a different mistake")
	t.lt(Tuning.PUMP_HIGH, Tuning.strain_start(),
		"a pump cannot be completed without damaging the line")


## The risk dial. The most profitable pump has to sit just BELOW the point where
## the line starts complaining - close enough that a greedy player crosses it.
func test_the_profitable_pump_is_near_the_edge(t: TestHarness) -> void:
	var edge := Tuning.strain_start()
	t.lt(edge, 1.0, "the line never complains, so there is no risk at all")
	t.gt(edge, Tuning.PUMP_HIGH + 0.10, "the edge is so close to the pump that every pump is a gamble")
	t.gt(Tuning.pump_gain(edge - 0.01, 1.0), Tuning.pump_gain(Tuning.PUMP_HIGH, 1.0) * 1.8,
		"pumping near the edge is not worth the risk of crossing it")


## A rod makes the line more forgiving; it never makes the fish weaker. That is
## what keeps a rod purchase felt on every species at once.
func test_rod_forgiveness_only_widens_the_safe_range(t: TestHarness) -> void:
	t.gt(Tuning.strain_start(), Tuning.STRAIN_START - 0.0001,
		"the rod makes the line LESS tolerant than the base figure")
	t.lt(Tuning.strain_start(), 1.0, "a rod can make the line unbreakable")


## Every one of the three behaviours needs a different response, or two of them
## are the same behaviour wearing different names.
func test_the_three_responses_are_genuinely_different(t: TestHarness) -> void:
	var shake_mid := (Tuning.SHAKE_LO + Tuning.SHAKE_HI) * 0.5
	t.gt(shake_mid, Tuning.GIVE_MAX,
		"holding steady for a shake is the same load as giving line for a run")
	t.lt(shake_mid, Tuning.PUMP_HIGH,
		"holding steady for a shake is indistinguishable from the top of a pump")
	t.lt(Tuning.GIVE_MAX, Tuning.PUMP_HIGH,
		"you can pump straight through a run without ever exceeding the give limit")
	t.gt(Tuning.SHAKE_HI - Tuning.SHAKE_LO, 0.10, "the shake window is too tight to hit at all")
	t.lt(Tuning.SHAKE_HI - Tuning.SHAKE_LO, 0.45, "the shake window is so wide it is not a window")


## Doing nothing must lose. Without a clock the winning strategy is to take all
## day, which is what every forgiving fishing minigame collapses to.
func test_the_wear_clock_makes_dithering_lose(t: TestHarness) -> void:
	t.gt(Tuning.WEAR_RATE, 0.0, "the hook never works loose, so a fight can be sat out")
	var slowest := 1.0 / Tuning.WEAR_RATE
	t.lt(slowest, 90.0, "a fight can last %.0f seconds with no pressure at all" % slowest)
	t.gt(slowest, 30.0, "the wear clock alone ends a fight before it can be won")


func test_every_species_is_reachable_and_sane(t: TestHarness) -> void:
	t.gt(float(Species.TABLE.size()), 0.0, "there is something to catch")
	for s in Species.TABLE:
		t.gt(s["weight_hi"], s["weight_lo"], "%s has a real weight range" % s["name"])
		t.gt(s["max_depth"], s["min_depth"], "%s has a real depth range" % s["name"])
		t.ok(s["min_depth"] <= Tuning.BED_DEPTH,
			"%s can be reached in water this deep" % s["name"])
		t.gt(s["stamina"], 0.0, "%s has stamina" % s["name"])
		t.gt(s["haul"], 0.0, "%s can be pumped in" % s["name"])
		t.gt(s["hold_speed"], 0.0, "%s has sullen phases to pump during" % s["name"])
		t.gt(s["weight"], 0.0, "%s can actually be picked" % s["name"])
		# A fish that always runs or always shakes can never be pumped in, so it
		# is unlandable however well it is played. The clock still runs.
		var busy: float = float(s["run_chance"]) + float(s["shake_chance"])
		t.lt(busy, 0.92, "%s is interrupting so often it can never be pumped in" % s["name"])


## Every species must be catchable somewhere.
##
## The lure sinks to the bed and fishes there, so a row whose depth range sits
## entirely ABOVE the bed is unreachable - it is in the table, it is in the
## logbook as a blank page, and no amount of play will ever fill it in. The
## bluegill shipped exactly that way: `max_depth` 2.4 in 4 m of water, the
## commonest fish in the game, uncatchable, and nothing reported anything wrong
## because every subsystem was working perfectly.
func test_every_species_is_reachable_at_a_real_fishing_depth(t: TestHarness) -> void:
	for s in Species.TABLE:
		var min_d: float = s["min_depth"]
		var max_d: float = s["max_depth"]
		t.ok(min_d <= Tuning.BED_DEPTH and max_d >= Tuning.BED_DEPTH,
			"%s cannot be caught at the bed, which is the only depth the lure fishes" % s["name"])


func test_something_lives_at_the_bottom(t: TestHarness) -> void:
	# The lure sinks to BED_DEPTH and fishes there. If nothing overlaps that
	# depth the game silently never produces a bite, which is the worst kind of
	# content bug: everything works and nothing happens.
	var rows := Species.at_depth(Tuning.BED_DEPTH)
	t.gt(float(rows.size()), 0.0, "at least one species lives at the bed")


func test_pick_is_stable_and_covers_the_table(t: TestHarness) -> void:
	var seen := {}
	for i in 200:
		var u := float(i) / 200.0
		var s := Species.pick(Tuning.BED_DEPTH, u)
		t.ok(not s.is_empty(), "pick always returns a row at the bed")
		seen[s["id"]] = true
	var expected := Species.at_depth(Tuning.BED_DEPTH).size()
	t.eq(seen.size(), expected, "every species at that depth can be picked")


func test_pick_is_weighted_toward_the_common_fish(t: TestHarness) -> void:
	var counts := {}
	for i in 1000:
		var s := Species.pick(Tuning.BED_DEPTH, float(i) / 1000.0)
		counts[s["id"]] = counts.get(s["id"], 0) + 1
	# Bluegill carries the highest weight of anything at the bed, so it must be
	# the most common. If a rebalance inverts this the early game changes
	# character with nothing else to say so.
	t.gt(float(counts.get("bluegill", 0)), float(counts.get("bass", 0)),
		"the common fish is more common than the prize")


## A tired fish runs and shakes less. That is the shape of a fight, and it is
## what makes the end of one feel different from the start rather than shorter.
func test_a_tired_fish_interrupts_less(t: TestHarness) -> void:
	for s in Species.TABLE:
		var fresh := 0
		var spent := 0
		for i in 400:
			var u := float(i) / 400.0
			if Species.next_behaviour(s, u, 1.0) != Sim.B_HOLDING:
				fresh += 1
			if Species.next_behaviour(s, u, 0.0) != Sim.B_HOLDING:
				spent += 1
		t.gt(float(fresh), float(spent) - 0.5,
			"%s interrupts as much when spent as when fresh" % s["name"])


## Every species must produce all three behaviours, or a fish exists that the
## player can never learn the full mechanic on.
func test_every_species_can_do_all_three_things(t: TestHarness) -> void:
	for s in Species.TABLE:
		var seen := {}
		for i in 400:
			seen[Species.next_behaviour(s, float(i) / 400.0, 1.0)] = true
		t.ok(seen.has(Sim.B_HOLDING), "%s never sits still to be pumped" % s["name"])
		t.ok(seen.has(Sim.B_RUNNING), "%s never runs" % s["name"])
		t.ok(seen.has(Sim.B_SURFACING), "%s never head-shakes" % s["name"])


func test_behaviour_lengths_are_playable(t: TestHarness) -> void:
	for s in Species.TABLE:
		for u in [0.0, 0.5, 1.0]:
			var hold := Species.hold_seconds(s, u)
			t.gt(hold, Tuning.TELL_TIME * 2.0,
				"%s's sullen phase is shorter than its own warning" % s["name"])
			t.lt(hold, 12.0, "%s sits still long enough to be boring" % s["name"])
			var run := Species.run_seconds(s, u, 1.0)
			t.gt(run, 0.3, "%s's run is over before it can be reacted to" % s["name"])
			t.lt(run, 6.0, "%s's run takes back more than any pump can recover" % s["name"])
			t.lt(Species.run_seconds(s, u, 0.0), run + 0.0001,
				"%s's runs get longer as it tires" % s["name"])
