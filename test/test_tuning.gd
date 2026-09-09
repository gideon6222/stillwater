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
	var eased := aim * exp(-Tuning.TAP_DECAY * 0.45)
	t.lt(eased + Tuning.RUN_JOLT, Tuning.SAFE_HI + 0.02,
		"stopping when warned is still not enough to survive a run")
	t.gt(Tuning.RUN_GAIN, 0.0, "a run costs no ground")


## The warning has to be longer than a person's reaction, because this is a game
## about watching rather than reflexes. The previous fight had it at 0.34s
## against a ~0.30s reaction and the margin was invisible.
func test_the_warning_is_generous(t: TestHarness) -> void:
	t.gt(Tuning.TELL_TIME, 0.40, "the warning is shorter than a person's reaction time")
	t.lt(Tuning.TELL_TIME, 1.5, "the warning is so long the run is no longer a surprise")


## The hook bar has to be winnable and losable.
func test_the_hook_bar_is_a_real_test(t: TestHarness) -> void:
	t.gt(Tuning.HOOK_SWEEPS, 0.9, "the marker does not complete a single pass")
	t.lt(Tuning.HOOK_SWEEPS, 5.0, "there are so many passes that timing is irrelevant")
	t.gt(Tuning.HOOK_ZONE_MIN, 0.02, "the smallest zone is too small to hit deliberately")
	for s in Species.TABLE:
		var z: float = s["zone"]
		t.gt(z, Tuning.HOOK_ZONE_MIN - 0.0001, "%s's zone is below the floor" % s["name"])
		t.lt(z, 0.6, "%s's zone covers most of the bar" % s["name"])
		# Time inside the zone on one pass, in seconds. Under about a fifth of a
		# second is a reflex test rather than a timing one.
		var speed: float = s["sweep_speed"]
		var window := z / speed
		t.gt(window, 0.15, "%s gives only %.2fs in the zone" % [s["name"], window])


func test_the_hook_zone_stays_on_the_bar(t: TestHarness) -> void:
	for s in Species.TABLE:
		for i in 40:
			var z := Species.hook_zone(s, float(i) / 40.0)
			t.ok(z[0] >= -0.0001, "%s's zone starts off the left of the bar" % s["name"])
			t.ok(z[1] <= 1.0001, "%s's zone runs off the right of the bar" % s["name"])
			t.gt(z[1] - z[0], 0.0, "%s's zone has no width" % s["name"])


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
		t.ok(s["min_depth"] <= Tuning.BED_DEPTH,
			"%s can be reached in water this deep" % s["name"])
		t.gt(s["stamina"], 0.0, "%s has stamina" % s["name"])
		t.gt(s["haul"], 0.0, "%s can be pumped in" % s["name"])
		t.gt(s["sweep_speed"], 0.0, "%s has a marker that moves" % s["name"])
		t.gt(s["weight"], 0.0, "%s can actually be picked" % s["name"])
		# A fish that spends most of the fight running can never be reeled in, so
		# it is unlandable however well it is played.
		var busy: float = float(s["run_chance"])
		t.lt(busy, 0.75, "%s runs so often it can never be reeled in" % s["name"])


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


