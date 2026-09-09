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



## The band has to be reachable by a thumb.
##
## The one property no bot and no screenshot would ever reveal, and the whole
## point of this version of the fight: it should feel like a fun minigame, not a
## dexterity test. A band that needs eleven taps a second is unplayable on a
## phone however good the numbers look on paper.
func test_the_band_is_tappable_at_a_human_rate(t: TestHarness) -> void:
	var lo := Tuning.taps_per_second_for(Tuning.SAFE_LO)
	var hi := Tuning.taps_per_second_for(Tuning.SAFE_HI)
	t.gt(lo, 0.8, "the bottom of the band holds itself with almost no tapping")
	t.lt(hi, 5.0, "the top of the band needs %.1f taps a second, which is a dexterity test" % hi)
	t.gt(hi, lo, "tapping faster does not raise the needle")


func test_the_safe_band_is_a_real_target(t: TestHarness) -> void:
	t.gt(Tuning.SAFE_HI, Tuning.SAFE_LO, "the band has no width")
	t.gt(Tuning.SAFE_HI - Tuning.SAFE_LO, 0.18, "the band is too narrow to hold by tapping")
	t.lt(Tuning.SAFE_HI - Tuning.SAFE_LO, 0.60, "the band covers so much that missing it takes effort")
	t.gt(Tuning.SAFE_LO, 0.0, "the band starts at slack, so doing nothing is safe")
	t.lt(Tuning.SAFE_HI, Tuning.TENSION_MAX, "there is no headroom above the band to break the line in")


## A single tap must be a visible fraction of the band and never cross it whole -
## otherwise the gauge either does not respond or cannot be controlled.
func test_one_tap_is_a_readable_step(t: TestHarness) -> void:
	var band := Tuning.SAFE_HI - Tuning.SAFE_LO
	t.gt(Tuning.TAP_KICK, band * 0.15, "a tap barely moves the needle")
	t.lt(Tuning.TAP_KICK, band, "one tap crosses the whole band, so it cannot be held inside it")


## Slack has to bleed ground away slowly rather than ending the fight, so the two
## failures stay distinguishable: too little tapping loses the fish gradually and
## visibly on the distance readout, too much parts the line.
func test_the_two_failures_are_different_speeds(t: TestHarness) -> void:
	t.gt(Tuning.REEL_RATE, Tuning.SLIP_RATE,
		"the fish takes line back faster than it can be reeled in, so nothing can be landed")
	t.gt(Tuning.SLIP_RATE, 0.0, "a slack line costs nothing")
	t.gt(Tuning.ESCAPE_MARGIN, 0.0, "there is no way to lose a fish by under-tapping")
	var seconds_to_escape := Tuning.ESCAPE_MARGIN / Tuning.SLIP_RATE
	t.gt(seconds_to_escape, 4.0, "under-tapping loses the fish in %.1fs, which reads as random" % seconds_to_escape)
	t.lt(seconds_to_escape, 30.0, "under-tapping is barely a mistake at all")


## A run must be survivable by doing nothing, and unsurvivable by tapping. That
## is the whole lesson the gauge teaches without a word of text.
func test_a_run_is_survived_by_stopping(t: TestHarness) -> void:
	# Left alone, the needle settles where the fish's pull balances the decay.
	# That has to land BELOW the band: a run you stop for is survivable and makes
	# no progress, which is the cost of it. Above the band and stopping would be
	# fatal; inside the band and stopping would still reel the fish in, so a run
	# would not be a setback at all.
	var settle := Tuning.RUN_PULL / Tuning.TAP_DECAY
	t.lt(settle, Tuning.SAFE_LO, "doing nothing through a run still reels the fish in")
	t.gt(settle, 0.0, "a run does not move the needle at all")

	# And the JOLT is what punishes still being mid-tap when it starts. Landing
	# on the band from the aim point has to clear the top, or the warning is
	# worth nothing and every run handles itself.
	var aim := (Tuning.SAFE_LO + Tuning.SAFE_HI) * 0.5
	t.gt(aim + Tuning.RUN_JOLT, Tuning.SAFE_HI,
		"a run that starts while you are tapping does not even reach the red")
	# But a player who HAS stopped must be safe. Half a second of decay from the
	# aim point, plus the jolt, has to stay under the top.
	var eased := aim * exp(-Tuning.TAP_DECAY * Tuning.TELL_TIME)
	t.lt(eased + Tuning.RUN_JOLT, Tuning.SAFE_HI + 0.02,
		"stopping when warned is still not enough to survive a run")
	t.gt(Tuning.RUN_GAIN, 0.0, "a run costs no ground")


## The warning has to be longer than a person's reaction, because this is a game
## about watching rather than reflexes. The previous fight had it at 0.34s
## against a ~0.30s reaction and the margin was invisible.
func test_the_warning_is_generous(t: TestHarness) -> void:
	t.gt(Tuning.TELL_TIME, 0.40, "the warning is shorter than a person's reaction time")
	t.lt(Tuning.TELL_TIME, 1.5, "the warning is so long the run is no longer a surprise")


## The nibble has to be winnable, losable, and READABLE.
##
## The last one is the whole point of it. A tease and a take are told apart by
## how deep and how long, so both differences have to be big enough to see at
## cast range - there is no HUD element to fall back on.
func test_a_tease_and_a_take_look_different(t: TestHarness) -> void:
	t.lt(Tuning.TEASE_DEPTH, 0.6,
		"a tease pulls the float almost as far under as a real take")
	t.gt(Tuning.TAKE_DEPTH - Tuning.TEASE_DEPTH, 0.35,
		"the two depths are too close to tell apart at cast range")
	for s in Species.TABLE:
		var window: float = s["take_window"]
		t.gt(window, Tuning.TEASE_TIME * 1.4,
			"%s's take lasts %.2fs against a %.2fs tease - they read the same" % [
				s["name"], window, Tuning.TEASE_TIME])
		# And it has to be long enough to react to at all. Under about a third of
		# a second is a reflex test rather than a judgement.
		t.gt(window, 0.30, "%s gives only %.2fs to strike in" % [s["name"], window])
		t.lt(window, 2.0, "%s holds the bait so long that timing does not matter" % s["name"])


func test_the_tease_sequence_is_a_real_wait(t: TestHarness) -> void:
	t.gt(float(Tuning.TEASE_MIN), 0.5, "a fish can take the bait with no teasing at all")
	t.gt(float(Tuning.TEASE_MAX), float(Tuning.TEASE_MIN),
		"every bite offers exactly the same number of teases")
	t.lt(float(Tuning.TEASE_MAX), 6.0, "a bite takes so many teases that it is a waiting game")
	t.gt(Tuning.TUG_GAP_MIN, 0.2, "the tugs come so fast they blur into one")
	t.gt(Tuning.TUG_GAP_MAX, Tuning.TUG_GAP_MIN, "the gap between tugs never varies")


func test_the_tease_count_stays_in_range(t: TestHarness) -> void:
	for s in Species.TABLE:
		for i in 40:
			var n := Species.tease_count(s, float(i) / 40.0)
			t.ok(n >= Tuning.TEASE_MIN, "%s can offer fewer teases than the floor" % s["name"])
			t.ok(n <= Tuning.TEASE_MAX, "%s can offer more teases than the ceiling" % s["name"])


## A tired fish runs less, which is what makes the end of a fight feel different
## from the start rather than merely shorter.
func test_a_tired_fish_runs_less(t: TestHarness) -> void:
	for s in Species.TABLE:
		var fresh := 0
		var spent := 0
		for i in 400:
			var u := float(i) / 400.0
			if Species.runs_next(s, u, 1.0):
				fresh += 1
			if Species.runs_next(s, u, 0.0):
				spent += 1
		t.gt(float(fresh), float(spent) - 0.5, "%s runs as much when spent as when fresh" % s["name"])


func test_phase_lengths_are_playable(t: TestHarness) -> void:
	for u in [0.0, 0.5, 1.0]:
		var calm := Species.calm_seconds(u)
		t.gt(calm, Tuning.TELL_TIME * 1.5, "a calm phase is barely longer than its own warning")
		t.lt(calm, 10.0, "the fish sits still long enough to be boring")
		var run := Species.run_seconds(u, 1.0)
		t.gt(run, 0.5, "a run is over before it can be reacted to")
		t.lt(run, 5.0, "a run takes back more than the fight can recover")
		t.lt(Species.run_seconds(u, 0.0), run + 0.0001, "runs get longer as the fish tires")

func test_every_species_is_reachable_and_sane(t: TestHarness) -> void:
	t.gt(float(Species.TABLE.size()), 0.0, "there is something to catch")
	for s in Species.TABLE:
		t.gt(s["weight_hi"], s["weight_lo"], "%s has a real weight range" % s["name"])
		t.gt(s["max_depth"], s["min_depth"], "%s has a real depth range" % s["name"])
		t.gt(s["stamina"], 0.0, "%s has stamina" % s["name"])
		t.gt(s["haul"], 0.0, "%s can be reeled in" % s["name"])
		t.gt(s["take_window"], 0.0, "%s never actually takes the bait" % s["name"])
		t.gt(s["teases"], 0.0, "%s never teases at all" % s["name"])
		t.gt(s["weight"], 0.0, "%s can actually be picked" % s["name"])
		t.gt(s["value"], -1.0, "%s has no price" % s["name"])
		# A fish that spends most of the fight running can never be reeled in, so
		# it is unlandable however well it is played.
		var busy: float = float(s["run_chance"])
		t.lt(busy, 0.75, "%s runs so often it can never be reeled in" % s["name"])


## EVERY SPECIES MUST BE CATCHABLE SOMEWHERE.
##
## The lure fishes at ONE depth - the shallower of the lake bed where you are and
## what your line will stand - so a row whose range never contains a reachable
## depth is unreachable everywhere. It is in the table, it is a blank page in the
## logbook, and no amount of play will ever fill it in.
##
## This has already caught a real one: the bluegill shipped with `max_depth` 2.4
## in 4 m of water - the commonest fish in the game, uncatchable, with nothing
## reporting a fault because every subsystem was working perfectly. The check now
## walks every spot at every line level, which is the real set of depths the game
## can produce.
func test_every_species_is_reachable_somewhere(t: TestHarness) -> void:
	var depths := World.all_reachable_depths()

	for s in Species.TABLE:
		var min_d: float = s["min_depth"]
		var max_d: float = s["max_depth"]
		var reachable := false
		for d in depths:
			if d >= min_d and d <= max_d:
				reachable = true
				break
		t.ok(reachable,
			"%s (%.0f-%.0fm) sits between the depths the game can actually fish" % [
				s["name"], min_d, max_d])


## And every OBJECT too, for the same reason - an object that can never be found
## is a story beat that never fires.
func test_every_object_is_reachable_somewhere(t: TestHarness) -> void:
	var depths := World.all_reachable_depths()

	for o in Objects.TABLE:
		var min_d: float = o["min"]
		var max_d: float = o["max"]
		var reachable := false
		for d in depths:
			if d >= min_d and d <= max_d:
				reachable = true
				break
		t.ok(reachable, "%s can never be found at any reachable depth" % o["name"])


## Every SPOT must have something in it, or a place on the map is an empty room.
func test_every_spot_holds_something_at_every_line(t: TestHarness) -> void:
	for spot in World.SPOTS:
		var reach := World.reachable_depth(spot["id"], Gear.LINE.size() - 1)
		var rows := Species.at_depth(reach)
		t.gt(float(rows.size()), 0.0,
			"%s has nothing living at %.0fm" % [spot["name"], reach])


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


## Bait is the targeting system, so it has to actually move the odds - and it
## must never reduce a species to zero, because a bait that hard-gates is a
## lockout wearing a choice's clothes.
func test_bait_shifts_the_odds_without_locking_anything_out(t: TestHarness) -> void:
	var worms := 0
	var minnows := 0
	for i in 600:
		var u := float(i) / 600.0
		if Species.pick(3.0, u, "", "worm")["id"] == "bass":
			worms += 1
		if Species.pick(3.0, u, "", "minnow")["id"] == "bass":
			minnows += 1
	t.gt(float(minnows), float(worms), "minnows do not bring up more bass than worms")
	t.gt(float(worms), 0.0, "worms lock the bass out entirely")


## Time of day has to gate something, or the clock is decoration.
func test_some_fish_only_bite_at_certain_hours(t: TestHarness) -> void:
	var gated := 0
	for s in Species.TABLE:
		if s.has("hour"):
			gated += 1
			var hours: Array = s["hour"]
			t.gt(float(hours.size()), 0.0, "%s has an empty hour list" % s["name"])
	t.gt(float(gated), 0.0, "nothing in the lake cares what time it is")

	# And the gate has to bite: a night fish must be absent by day.
	var day_rows := Species.at_depth(12.0, "morning")
	var night_rows := Species.at_depth(12.0, "night")
	t.gt(float(night_rows.size()), float(day_rows.size()),
		"the same fish are available at midnight as at noon")


## No fish may make a run that playing well cannot survive.
##
## This is arithmetic, not taste. Tension left alone settles at
## `RUN_PULL * run_power / TAP_DECAY`. Once that settle point reaches SAFE_HI the
## needle parks above the safe band on its own, and the fish is lost no matter
## what the player does - the run stops being a thing you handle and becomes a
## coin the game flips. The ceiling is where the settle point still leaves usable
## room below SAFE_HI.
func test_no_run_is_unsurvivable(t: TestHarness) -> void:
	var ceiling := Tuning.SAFE_HI * Tuning.TAP_DECAY / Tuning.RUN_PULL
	for row in Species.TABLE:
		var power: float = row["run_power"]
		t.lt(power, ceiling,
			"%s runs at %.2f, and anything at or past %.2f parks the needle above the safe band by itself" % [
				row["name"], power, ceiling])
		var settle := Tuning.RUN_PULL * power / Tuning.TAP_DECAY
		t.lt(settle, Tuning.SAFE_HI - 0.06,
			"%s settles at %.2f, which leaves no room under the break point" % [row["name"], settle])


## THE TUTORIAL HAS TO TEACH THE RUN.
##
## The reeds are where a player learns what the needle means, and they can only
## learn it from a fish that runs. This shipped broken once in the other
## direction: run frequency and run strength were the same number, so making the
## first water winnable made its fish stop running, and a player could finish the
## whole tutorial without ever seeing the mechanic the fight is built on.
##
## The pair of assertions is the point - OFTEN and GENTLY, not one or the other.
func test_the_first_water_teaches_the_run(t: TestHarness) -> void:
	for row in Species.TABLE:
		if row["band"] != "reeds":
			continue
		t.gt(float(row["run_chance"]), 0.30,
			"%s hardly ever runs, so the tutorial does not teach the run" % row["name"])
		t.lt(float(row["run_power"]), 0.80,
			"%s runs hard enough to punish a player still learning what a run is" % row["name"])


## Every band's runs are stronger than the one above it. The frequency is free to
## go up or down - what has to climb with depth is the STAKES.
func test_runs_get_stronger_with_depth(t: TestHarness) -> void:
	var last := 0.0
	var last_name := ""
	for band in World.BANDS:
		var total := 0.0
		var n := 0
		for row in Species.TABLE:
			if row["band"] == band["id"]:
				total += float(row["run_power"])
				n += 1
		if n == 0:
			continue
		var mean := total / float(n)
		if last_name != "":
			t.gt(mean, last,
				"runs in %s (%.2f) are no stronger than in %s (%.2f)" % [
					band["name"], mean, last_name, last])
		last = mean
		last_name = band["name"]
