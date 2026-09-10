extends RefCounted

## The whole-run golden.
##
## Seven scripted sessions, each played to the last step, with every field of the
## final state asserted at once. This is the single strongest test in the repo
## and the reason the simulation has no renderer in it: on a sibling game the
## genre changed three times in one day and this test came across every time,
## which is worth more than any individual assertion in the suite.
##
## **Regenerate with `test/record_golden.gd`, and read the diff before pasting
## it in.** A golden is only worth having if changing it is a decision. It has
## already earned that twice: the first recording showed a session sitting in
## `waiting` with `slip: 1.0` and a species still named, which was stale state
## leaking through a cast made straight out of a loss; and reading this one
## confirmed the panicker ends its fights with the fish at FULL stamina, which
## is exactly right - it never completes a pump, so it never tires anything.
##
## Compared with `TestHarness.FLOAT_EPS` rather than exact equality. `snappedf`
## does not round-trip through a source literal, so an exact golden over floats
## is unpassable by construction; and these are recorded on Windows and checked
## on a Linux runner, where identical IEEE arithmetic across two toolchains is
## something people assume rather than something promised.



const GOLDEN := [
	{
		"policy": "angler",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 2,
			"draws": 46,
			"fighting": 23.333000,
			"fish_distance": 4.796000,
			"fish_id": "carp",
			"fish_stamina": 0.000000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.502000,
			"total_weight": 10.878000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "human",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 2,
			"draws": 46,
			"fighting": 22.967000,
			"fish_distance": 5.119000,
			"fish_id": "carp",
			"fish_stamina": 0.026000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.631000,
			"total_weight": 10.878000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "human",
		"seconds": 60.000000,
		"seed": 4,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 4,
			"draws": 58,
			"fighting": 25.900000,
			"fish_distance": 12.609000,
			"fish_id": "perch",
			"fish_stamina": 1.000000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "nibbling",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 4.652000,
			"tug": 0.108000,
		},
	},
	{
		"policy": "blind",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 2,
			"draws": 45,
			"fighting": 23.333000,
			"fish_distance": 5.839000,
			"fish_id": "carp",
			"fish_stamina": 0.119000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.654000,
			"total_weight": 10.878000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "masher",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 10,
			"caught": 0,
			"draws": 51,
			"fighting": 0.000000,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 8,
			"lure_depth": 0.728000,
			"running": false,
			"seconds": 60.000000,
			"state": "sinking",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 0.000000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "idle_hands",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 0,
			"draws": 45,
			"fighting": 0.000000,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 4,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "waiting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 0.000000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "slowpoke",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 4,
			"caught": 0,
			"draws": 45,
			"fighting": 28.550000,
			"fish_distance": 12.902000,
			"fish_id": "bluegill",
			"fish_stamina": 0.628000,
			"lost": 2,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.233000,
			"total_weight": 0.000000,
			"tug": 0.000000,
		},
	},
]


func test_every_recorded_session_replays_exactly(t: TestHarness) -> void:
	for case in GOLDEN:
		var policy: String = case["policy"]
		var seconds: float = case["seconds"]
		var seed_value: int = case["seed"]
		var expect: Dictionary = case["expect"]
		var actual := Policies.play(policy, seconds, seed_value)
		t.dict_eq(actual, expect,
			"%s on seed %d no longer plays the session it was recorded from" % [policy, seed_value])


## The balance claims the golden numbers are worth having ONLY if they hold.
##
## A golden proves the game did not change. It says nothing about whether the
## game is any good, and a golden recorded from a broken build is a broken build
## defended by a test. These are the properties that make those numbers mean
## something, asserted separately so a failure says which one went.
func test_nobody_who_ignores_the_gauges_catches_anything(t: TestHarness) -> void:
	for policy in [Policies.IDLE_HANDS, Policies.MASHER, Policies.SLOWPOKE]:
		for seed_value in [1, 2, 3]:
			var r := Policies.play(policy, 90.0, seed_value)
			t.eq(r["caught"], 0,
				"%s catches fish on seed %d, so the minigames are decoration" % [policy, seed_value])
			t.gt(float(r["lost"]), 0.0, "%s never even loses one" % policy)


## The claim the WARNING makes, and the pair that proves it.
##
## BLIND and ANGLER are the same player - the same tap rhythm, the same reaction
## time - except that ANGLER acts on the tell and BLIND only learns about a run
## from the needle. So the gap between them is a claim about the game and not
## about the bots.
##
## This one had to be earned twice. The first version of the pair used a
## per-frame controller, which automatically stops tapping when the needle is
## high - so the run solved itself, and BLIND, ANGLER and HUMAN all scored
## identically at 100%. **A bot that reads the gauge sixty times a second is not
## a model of anyone**, and the mechanic looked free until the bots tapped on a
## rhythm like a person does.
## It had to be earned a third time, too. Measured in the STARTING REEDS both
## bots lost nothing, and the test read that as the warning being decoration. It
## was not - the reeds are deliberately gentle enough that a missed tell costs a
## beginner nothing, which is the whole point of a tutorial. The claim was being
## made in the one band where it is not supposed to hold.
##
## So it is measured on the Drowned Road, which is the first water that can take
## a fish off you, and the reeds get their own weaker claim underneath.
func test_watching_the_water_is_worth_something(t: TestHarness) -> void:
	var watched := 0
	var blind := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		watched += int(Policies.play(Policies.ANGLER, 90.0, seed_value, "road", 2)["lost"])
		blind += int(Policies.play(Policies.BLIND, 90.0, seed_value, "road", 2)["lost"])
	t.lt(float(watched), float(blind),
		"ignoring the run warning costs nothing, so the warning is decoration")
	t.gt(float(blind), 0.0, "the blind player loses nothing, so nothing was measured")


## AND THE TUTORIAL MAY NOT TEACH THE PLAYER TO IGNORE IT.
##
## The reeds must not take fish off a beginner for missing a tell - but if
## missing it is entirely free, the player spends the first hour learning that
## the warning means nothing, and the Channel then punishes a habit this game
## taught them. So in the reeds the tell buys TIME rather than fish: the watchful
## player lands more in the same ninety seconds, and loses none either way.
func test_the_reeds_charge_for_a_missed_tell_in_time_not_fish(t: TestHarness) -> void:
	var watched := 0.0
	var blind := 0.0
	var blind_lost := 0
	var watched_caught := 0
	var blind_caught := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var a := Policies.play(Policies.ANGLER, 90.0, seed_value)
		watched += float(a["fighting"])
		watched_caught += int(a["caught"])
		var b := Policies.play(Policies.BLIND, 90.0, seed_value)
		blind += float(b["fighting"])
		blind_lost += int(b["lost"])
		blind_caught += int(b["caught"])
	# THE TWO HALVES ARE MEASURED IN DIFFERENT WATER, which is what NOTES.md has
	# always said and what this test had stopped doing.
	#
	# In the REEDS the claim is forgiveness: a beginner who has not yet learned to
	# let go must not be punished in fish. That is the whole job of the tutorial
	# band, and `jolt_scale` compressing a weak fish's jolt is the mechanism.
	t.eq(blind_lost, 0,
		"the reeds take %d fish off a beginner for missing a tell they are still learning" % blind_lost)

	# On the DROWNED ROAD the claim is the opposite one, and it is the reason the
	# reeds are allowed to be gentle: ignoring the tell has to cost something
	# somewhere, or the tell is decoration everywhere.
	#
	# Measured in fish rather than in seconds, and that changed when the fight
	# became a hold. Letting go on the tell now decays the needle to about 0.47
	# and the jolt lands it near the TOP of the band - where the greed dial hauls
	# hardest - so reacting correctly is not merely safe, it is briefly faster,
	# and "who spent longer fighting" stopped separating the bots at all: 218.8 s
	# against 216.7 s, one per cent on six seeds, well inside the noise NOTES.md
	# warns about.
	var deep_watch := 0
	var deep_blind := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		deep_watch += int(Policies.play(Policies.ANGLER, 120.0, seed_value, "road", 3)["caught"])
		deep_blind += int(Policies.play(Policies.BLIND, 120.0, seed_value, "road", 3)["caught"])
	t.lt(deep_blind, deep_watch,
		"on the Drowned Road a beginner who ignores the tell lands just as much (%d vs %d), so the tell is decoration" % [
			deep_blind, deep_watch])


## THE test that answers Gideon's note about the first fight.
##
## "A perfect controller wins" is a fact about perfect controllers. HUMAN has a
## reaction time, a sloppy aim on the hook bar and a tapping rhythm it corrects
## a few times a second, and what IT loses is the number that means anything.
func test_a_plausible_player_loses_real_fish(t: TestHarness) -> void:
	var caught := 0
	var lost := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var r := Policies.play(Policies.HUMAN, 90.0, seed_value)
		caught += int(r["caught"])
		lost += int(r["lost"])
	var hooked := caught + lost
	t.gt(float(hooked), 0.0, "the human never hooked anything")
	var loss_rate := float(lost) / float(hooked)
	t.gt(loss_rate, 0.05,
		"a plausible player loses %.0f%% of what they hook - the fight is too easy" % (loss_rate * 100.0))
	t.lt(loss_rate, 0.45,
		"a plausible player loses %.0f%% of what they hook - the fight is unfair" % (loss_rate * 100.0))
	t.gt(float(caught), 0.0, "a plausible player cannot land anything at all")


## THE BANDS FORM A LADDER, and that is the claim worth asserting.
##
## The first version compared all twenty-six species in a straight line, which
## was never the right shape: the table is grouped by DEPTH BAND and the order
## inside a band is content, not difficulty - a band needs an easy filler fish as
## much as it needs a prize.
##
## What has to hold is that **going deeper is going somewhere harder**, band by
## band, because that is the promise the whole progression makes. Depth is time
## and time is the story, so a band that is easier than the one above it would
## make reaching further back a reward with no cost.
func test_the_bands_form_a_difficulty_ladder(t: TestHarness) -> void:
	var means: Array[float] = []
	var names: Array[String] = []
	for band in World.BANDS:
		var total := 0.0
		var n := 0
		for row in Species.TABLE:
			if row["band"] != band["id"]:
				continue
			total += _win_rate(row["id"])
			n += 1
		if n == 0:
			continue
		means.append(total / float(n))
		names.append(band["name"])

	t.gt(float(means.size()), 2.0, "there are not enough bands to be a ladder")

	# A real STEP, not merely non-decreasing. The measurement is a sample - fixed
	# seeds, so it is deterministic rather than flaky, but a one-point gap would
	# still be a ladder only by accident, and the next content change would flip
	# it without meaning to.
	for i in means.size() - 1:
		t.gt(means[i] - means[i + 1], 0.03,
			"%s (%.0f%% landed) is not meaningfully easier than %s (%.0f%%)" % [
				names[i], means[i] * 100.0, names[i + 1], means[i + 1] * 100.0])

	t.gt(means[0], 0.80, "the first water a player ever fishes is not a reliable win")
	t.lt(means[means.size() - 1], 0.75, "the deepest water is not a gamble")


## Land rate for one species with the human, from a worst-case full-length cast.
## Reaches past the input seam to set the fight up, which is acceptable in a
## measurement and never in a policy.
func _win_rate(id: String) -> float:
	var won := 0
	var tries := 16
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
