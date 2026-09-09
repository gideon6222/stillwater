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


func test_the_band_never_covers_everything(t: TestHarness) -> void:
	# A rod that widens the band far enough removes the mechanic instead of
	# making it forgiving, which is the failure mode of every "just make it
	# easier" tuning pass.
	for w in [0.0, 0.26, 0.36, 0.9, 4.0]:
		var half := Tuning.band_half(w)
		t.lt(half, 0.5, "band half-width stays under half the range for width %s" % str(w))
		t.gt(Tuning.band_lo(w), 0.0, "the band has a bottom above zero for width %s" % str(w))


func test_a_wider_species_band_is_never_harder(t: TestHarness) -> void:
	var narrow := Tuning.band_half(0.26)
	var wide := Tuning.band_half(0.36)
	t.gt(wide, narrow, "a wider species band gives more room")


func test_idle_hands_cannot_reach_the_band_for_any_species(t: TestHarness) -> void:
	# The load-bearing balance claim of the whole fight, asserted directly on
	# the numbers rather than only through the bots. A fish whose resting pull
	# already sits inside the band is one that lands itself.
	for s in Species.TABLE:
		var band_w: float = s["band"]
		var lo := Tuning.band_lo(band_w)
		var resting_peak: float = s["pull"] + s["surge"]
		t.lt(resting_peak, lo + 0.12,
			"%s must not sit in the band with no thumb on the rod" % s["name"])


func test_every_species_is_reachable_and_sane(t: TestHarness) -> void:
	t.gt(float(Species.TABLE.size()), 0.0, "there is something to catch")
	for s in Species.TABLE:
		t.gt(s["weight_hi"], s["weight_lo"], "%s has a real weight range" % s["name"])
		t.gt(s["max_depth"], s["min_depth"], "%s has a real depth range" % s["name"])
		t.ok(s["min_depth"] <= Tuning.BED_DEPTH,
			"%s can be reached in water this deep" % s["name"])
		t.gt(s["period"], 0.0, "%s has a surge period" % s["name"])
		t.gt(s["stamina"], 0.0, "%s has stamina" % s["name"])
		t.gt(s["haul"], 0.0, "%s can be hauled" % s["name"])
		t.gt(s["weight"], 0.0, "%s can actually be picked" % s["name"])


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


func test_a_tired_fish_pulls_less(t: TestHarness) -> void:
	var s := Species.by_id("bass")
	t.ok(not s.is_empty(), "the bass is in the table")
	# Sampled over a whole surge cycle rather than at one instant, because the
	# sine makes a single sample say whatever the phase wants it to.
	var fresh := 0.0
	var spent := 0.0
	for i in 60:
		var period_a: float = s["period"]
		var tt := float(i) / 60.0 * period_a
		fresh += absf(Species.pull_at(s, tt, 1.0))
		spent += absf(Species.pull_at(s, tt, 0.0))
	t.gt(fresh, spent, "a fresh fish pulls harder than a spent one")


func test_pull_never_goes_negative(t: TestHarness) -> void:
	# A negative pull would mean the fish pushing toward the boat, which the
	# tension model reads as slack and would silently make surges HELP.
	for s in Species.TABLE:
		for i in 120:
			var period_b: float = s["period"]
			var tt := float(i) / 120.0 * period_b * 2.0
			for stam in [0.0, 0.5, 1.0]:
				t.ok(Species.pull_at(s, tt, stam) >= 0.0,
					"%s never pulls backwards" % s["name"])
