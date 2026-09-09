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
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 4,
			"caught": 4,
			"draws": 511,
			"fish_distance": 0.000000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 0,
			"lure_depth": 0.000000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "charging",
			"strain": 0.000000,
			"total_weight": 3.062000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "human",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 5,
			"caught": 3,
			"draws": 511,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 1,
			"lure_depth": 0.939000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "sinking",
			"strain": 0.000000,
			"total_weight": 0.879000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "human",
		"seconds": 60.000000,
		"seed": 4,
		"expect": {
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 3,
			"draws": 501,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 2,
			"lure_depth": 3.507000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "sinking",
			"strain": 0.000000,
			"total_weight": 0.897000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "hauler",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 2,
			"draws": 670,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 3,
			"lure_depth": 4.000000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "waiting",
			"strain": 0.000000,
			"total_weight": 0.480000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "masher",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 8,
			"caught": 0,
			"draws": 732,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 7,
			"lure_depth": 0.000000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "flying",
			"strain": 0.000000,
			"total_weight": 0.000000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "idle_hands",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"behaviour": "holding",
			"cast_distance": 12.609000,
			"casts": 6,
			"caught": 0,
			"draws": 632,
			"fish_distance": 12.609000,
			"fish_id": "",
			"fish_stamina": 1.000000,
			"load": 0.000000,
			"lost": 5,
			"lure_depth": 4.000000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.000000,
			"state": "waiting",
			"strain": 0.000000,
			"total_weight": 0.000000,
			"wear": 0.000000,
		},
	},
	{
		"policy": "panicker",
		"seconds": 60.000000,
		"seed": 1,
		"expect": {
			"behaviour": "running",
			"cast_distance": 12.609000,
			"casts": 4,
			"caught": 0,
			"draws": 515,
			"fish_distance": 13.484000,
			"fish_id": "bluegill",
			"fish_stamina": 1.000000,
			"load": 0.016000,
			"lost": 3,
			"lure_depth": 4.000000,
			"pumps": 0,
			"seconds": 60.000000,
			"slip": 0.023000,
			"state": "fighting",
			"strain": 0.000000,
			"total_weight": 0.000000,
			"wear": 0.285000,
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
func test_only_a_player_who_reads_the_water_does_well(t: TestHarness) -> void:
	# HAULER and ANGLER pump identically. The ONLY difference is that one looks
	# at the tell, so the gap between them is a claim about the game rather than
	# about the bots - and it is the entire premise of the second fight.
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var reads := Policies.play(Policies.ANGLER, 90.0, seed_value)
		var blind := Policies.play(Policies.HAULER, 90.0, seed_value)
		t.gt(float(reads["caught"]), float(blind["caught"]) - 0.5,
			"ignoring the water beats reading it on seed %d" % seed_value)
		t.lt(float(reads["lost"]), float(blind["lost"]) + 0.5,
			"ignoring the water loses fewer fish than reading it on seed %d" % seed_value)


func test_nobody_who_ignores_the_rod_catches_anything(t: TestHarness) -> void:
	for policy in [Policies.IDLE_HANDS, Policies.MASHER, Policies.PANICKER]:
		for seed_value in [1, 2, 3]:
			var r := Policies.play(policy, 90.0, seed_value)
			t.eq(r["caught"], 0,
				"%s catches fish on seed %d, so the fight is decoration" % [policy, seed_value])
			t.gt(float(r["lost"]), 0.0, "%s never even loses one" % policy)


## THE test that answers Gideon's note.
##
## The first fight was called too easy, and the probe had said so a day earlier
## without anyone reading it that way: the best bot landed everything and lost
## nothing. **A perfect controller winning is not evidence about difficulty** -
## it is a fact about perfect controllers. HUMAN is the honest instrument, with
## reaction time, a misread rate and a thumb that wobbles, and what IT loses is
## the number that means something.
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
	t.gt(loss_rate, 0.10,
		"a plausible player loses %.0f%% of what they hook - the fight is too easy again" % (loss_rate * 100.0))
	t.lt(loss_rate, 0.45,
		"a plausible player loses %.0f%% of what they hook - the fight is unfair" % (loss_rate * 100.0))
	t.gt(float(caught), 0.0, "a plausible player cannot land anything at all")


## The species table has to be an ordered ladder, and the order has to be the
## one the table is written in.
##
## This caught a real inversion: raising the bluegill's run chance while leaving
## its `hold_speed` high made the TUTORIAL fish harder than the one after it -
## 79% landed against the perch's 88%. Difficulty here is the product of two
## fields and neither one alone tells you where a species sits.
func test_the_species_form_a_difficulty_ladder(t: TestHarness) -> void:
	var rates: Array[float] = []
	for row in Species.TABLE:
		rates.append(_win_rate(row["id"]))
	for i in rates.size() - 1:
		t.gt(rates[i], rates[i + 1] - 0.001,
			"%s is harder than %s, so the table is not in difficulty order" % [
				Species.TABLE[i]["name"], Species.TABLE[i + 1]["name"],
			])
	t.gt(rates[0], 0.80, "the first fish a player ever meets is not a reliable win")
	t.lt(rates[rates.size() - 1], 0.80, "the prize fish is not a gamble")


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
		s.behaviour = Sim.B_HOLDING
		s.behaviour_time = 2.0
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
