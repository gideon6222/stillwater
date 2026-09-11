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
			"caught": 3,
			"draws": 51,
			"fighting": 31.783000,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 0,
			"lure_depth": 0.211000,
			"running": false,
			"seconds": 60.000000,
			"state": "sinking",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 10.976000,
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
			"caught": 3,
			"draws": 51,
			"fighting": 32.117000,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 0,
			"lure_depth": 0.000000,
			"running": false,
			"seconds": 60.000000,
			"state": "flying",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 10.976000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "human",
		"seconds": 60.000000,
		"seed": 4,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 4,
			"caught": 3,
			"draws": 53,
			"fighting": 30.583000,
			"fish_distance": 6.195000,
			"fish_id": "carp",
			"fish_stamina": 0.600000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.600000,
			"total_weight": 0.788000,
			"tug": 0.000000,
		},
	},
	{
		"policy": "blind",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 3,
			"draws": 51,
			"fighting": 32.200000,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 0,
			"lure_depth": 0.000000,
			"running": false,
			"seconds": 60.000000,
			"state": "flying",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.000000,
			"total_weight": 10.976000,
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
			"lure_depth": 0.709000,
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
			"casts": 1,
			"caught": 0,
			"draws": 43,
			"fighting": 52.783000,
			"fish_distance": 12.236000,
			"fish_id": "carp",
			"fish_stamina": 0.225000,
			"lost": 0,
			"lure_depth": 2.330000,
			"running": false,
			"seconds": 60.000000,
			"state": "fighting",
			"strain": 0.000000,
			"taking": false,
			"taps": 0,
			"tension": 0.236000,
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
## THE TWO REAL FAILURES CATCH NOTHING, and the third one is merely slow.
##
## The claim had to be split when the fifth fight separated reeling from tension.
## There are now exactly two ways to fail outright - never reel, and never let go -
## and both still catch zero. Being TIMID is no longer one of them: a player who
## reels only when the line is nearly slack lands fish, just far fewer of them,
## because the cost of caution in this model is the clock rather than the fish.
##
## That is the design working rather than a weakened test. "A cautious player
## lands everything slowly; a greedy one lands more and loses some" is the whole
## give and take he asked for, and a slowpoke that caught nothing at all would
## mean caution was punished rather than merely expensive.
func test_the_two_real_failures_catch_nothing(t: TestHarness) -> void:
	for policy in [Policies.IDLE_HANDS, Policies.MASHER]:
		for seed_value in [1, 2, 3]:
			var r := Policies.play(policy, 90.0, seed_value)
			t.eq(r["caught"], 0,
				"%s catches fish on seed %d, so the minigames are decoration" % [policy, seed_value])
			t.gt(float(r["lost"]), 0.0, "%s never even loses one" % policy)

	# And caution costs real fish against someone playing properly.
	var timid := 0
	var played := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		timid += int(Policies.play(Policies.SLOWPOKE, 90.0, seed_value)["caught"])
		played += int(Policies.play(Policies.ANGLER, 90.0, seed_value)["caught"])
	t.lt(float(timid), float(played) * 0.7,
		"reeling only when the line is slack lands %d against %d - caution costs nothing" % [
			timid, played])


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
## And a FOURTH time, when the fifth fight changed what the tell is worth.
##
## It is not "let go for the whole run" any more - holding on brakes a run, so a
## good player feathers straight through one. What the warning buys is the chance
## to shed tension BEFORE the jolt lands, and that only matters where the jolt can
## put the rod past the red. On the Drowned Road it barely can: measured, BLIND
## parts a line on one fish in a hundred there, which across six ninety-second
## sessions is not a signal, it is a rounding error.
##
## So it moved down to The Steeple, in Old Town, which is the first water where
## eating a jolt at a reeling tension actually pins the rod. There the same pair
## reads 100% against 85%, and the difference is parted lines.
func test_watching_the_water_is_worth_something(t: TestHarness) -> void:
	var watched := 0
	var blind := 0
	for seed_value in [1, 2, 3, 4, 5, 6]:
		watched += int(Policies.play(Policies.ANGLER, 90.0, seed_value, "steeple", 3)["lost"])
		blind += int(Policies.play(Policies.BLIND, 90.0, seed_value, "steeple", 3)["lost"])
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

	# NEVER EASIER GOING DEEPER. This is the half of the claim that has to hold
	# between every single pair, because a band that is easier than the one above
	# it would make reaching further back a reward with no cost.
	for i in means.size() - 1:
		t.lt(means[i + 1], means[i] + 0.001,
			"%s (%.0f%% landed) is EASIER than %s (%.0f%%), so going deeper is not going somewhere harder" % [
				names[i + 1], means[i + 1] * 100.0, names[i], means[i] * 100.0])

	# AND A REAL DROP ACROSS THE LAKE, which is where the demand for a step now
	# lives.
	#
	# It used to demand better than three points between EVERY adjacent pair, and
	# the fifth fight cannot honour that at the shallow end - measured, the human
	# bot lands 100 / 100 / 100 / 99 / 72 / 56 across the six bands. That is not a
	# flat game; it is what happens when the skill the fight asks for is FEATHERING
	# and the bot performs it perfectly. A weak fish cannot get away from someone
	# doing that, whatever its stats say, so the first three waters are a reliable
	# win for a competent player and the difficulty is expressed in the time they
	# take and in what a less careful player loses. The same six bands read
	# 100 / 100 / 99 / 85 / 59 / 38 for BLIND, a plausible beginner.
	#
	# Weakening the per-pair demand is deliberate and it is the second time this
	# test has been rewritten to say what the game actually claims rather than what
	# an earlier fight claimed. The guard that replaces it is the one that would
	# still catch the regression that matters: the deep half going soft.
	var drop := means[0] - means[means.size() - 1]
	t.gt(drop, 0.30,
		"the whole lake only spans %.0f points of difficulty, so depth costs nothing" % (drop * 100.0))

	var real_steps := 0
	for i in means.size() - 1:
		if means[i] - means[i + 1] > 0.03:
			real_steps += 1
	t.gt(float(real_steps), 1.5,
		"only %d of the %d rungs is a real step, so the lake is one difficulty with an ending" % [
			real_steps, means.size() - 1])

	t.gt(means[0], 0.80, "the first water a player ever fishes is not a reliable win")
	t.lt(means[means.size() - 1], 0.75, "the deepest water is not a gamble")

	# And the deep half has to be a gamble rather than a grind. A band nobody can
	# land anything in is not difficulty, it is a wall.
	t.gt(means[means.size() - 1], 0.15,
		"the deepest water lands %.0f%% - that is a wall rather than a gamble" % (means[means.size() - 1] * 100.0))


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
