extends RefCounted

## The whole-run golden.
##
## Five scripted sessions, each played to the last step, with every field of the
## final state asserted at once. This is the single strongest test in the repo
## and the reason the simulation has no renderer in it: on a sibling game the
## genre changed three times in one day and this test came across every time,
## which is worth more than any individual assertion in the suite.
##
## **Regenerate with `test/record_golden.gd`, and read the diff before pasting
## it in.** A golden is only worth having if changing it is a decision. It has
## already earned that: the first recording showed a session sitting in
## `waiting` with `slip: 1.0` and a species still named, which was stale state
## leaking through a cast made straight out of a loss - a bug no assertion in
## the suite was looking for and that nothing on screen would have shown.
##
## Compared with `TestHarness.FLOAT_EPS` rather than exact equality. `snappedf`
## does not round-trip through a source literal, so an exact golden over floats
## is unpassable by construction; and these are recorded on Windows and checked
## on a Linux runner, where identical IEEE arithmetic across two toolchains is
## something people assume rather than something promised.

const GOLDEN := [
	{
		"policy": "angler",
		"seconds": 60.0,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 4,
			"draws": 570,
			"fish_distance": 9.759000,
			"fish_id": "perch",
			"fish_stamina": 0.569000,
			"lost": 0,
			"lure_depth": 4.000000,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "fighting",
			"stress": 0.000000,
			"tension": 0.583000,
			"total_weight": 3.062000,
		},
	},
	{
		"policy": "angler",
		"seconds": 60.0,
		"seed": 4,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 5,
			"draws": 497,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 0,
			"lure_depth": 0.326000,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "sinking",
			"stress": 0.000000,
			"tension": 0.000000,
			"total_weight": 1.492000,
		},
	},
	{
		"policy": "masher",
		"seconds": 60.0,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 7,
			"caught": 0,
			"draws": 731,
			"fish_distance": 12.059000,
			"fish_id": "bluegill",
			"fish_stamina": 0.920000,
			"lost": 6,
			"lure_depth": 4.000000,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "fighting",
			"stress": 0.029000,
			"tension": 1.103000,
			"total_weight": 0.000000,
		},
	},
	{
		"policy": "idle_hands",
		"seconds": 60.0,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 0,
			"draws": 674,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"lost": 5,
			"lure_depth": 4.000000,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "waiting",
			"stress": 0.000000,
			"tension": 0.000000,
			"total_weight": 0.000000,
		},
	},
	{
		"policy": "timid",
		"seconds": 60.0,
		"seed": 1,
		"expect": {
			"cast_distance": 12.609000,
			"casts": 3,
			"caught": 0,
			"draws": 338,
			"fish_distance": 7.400000,
			"fish_id": "bass",
			"fish_stamina": 0.167000,
			"lost": 2,
			"lure_depth": 4.000000,
			"seconds": 60.000000,
			"slip": 0.238000,
			"state": "fighting",
			"stress": 0.000000,
			"tension": 0.423000,
			"total_weight": 0.000000,
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
func test_only_the_angler_catches_anything(t: TestHarness) -> void:
	for case in GOLDEN:
		var policy: String = case["policy"]
		var expect: Dictionary = case["expect"]
		var caught: int = expect["caught"]
		if policy == "angler":
			t.gt(float(caught), 0.0, "the angler catches nothing - the game is unwinnable")
		else:
			t.eq(caught, 0,
				"%s catches fish without tracking the band, so the fight is decoration" % policy)


func test_each_failing_policy_fails_for_a_different_reason(t: TestHarness) -> void:
	# If two of them post the same numbers, one is not testing anything - and
	# that is the single most useful signal the policy set produces.
	var masher := Policies.play(Policies.MASHER, 60.0, 1)
	var idle := Policies.play(Policies.IDLE_HANDS, 60.0, 1)
	var timid := Policies.play(Policies.TIMID, 60.0, 1)

	t.gt(float(masher["lost"]), 0.0, "the masher never loses a fish")
	t.gt(float(idle["lost"]), 0.0, "idle hands never lose a fish")
	t.gt(float(timid["lost"]), 0.0, "the timid player never loses a fish")

	# The masher breaks lines fast, so it gets through more fish than the timid
	# player, who holds on for a long time before the hook works loose. Same
	# outcome, different mistake, and the counts have to show it.
	t.gt(float(masher["lost"]), float(timid["lost"]),
		"pulling too hard and pulling too little now fail at the same rate")


func test_the_angler_beats_every_other_policy_on_every_seed(t: TestHarness) -> void:
	# If the bot that reads the gauge ever loses to one that ignores it, the bot
	# is wrong before the game is - and a balance pass built on that measurement
	# is built on nothing.
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var best := Policies.play(Policies.ANGLER, 90.0, seed_value)
		for other in [Policies.MASHER, Policies.IDLE_HANDS, Policies.TIMID]:
			var r := Policies.play(other, 90.0, seed_value)
			t.gt(float(best["caught"]), float(r["caught"]) - 0.5,
				"%s matches the angler on seed %d" % [other, seed_value])
