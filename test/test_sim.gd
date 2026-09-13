extends RefCounted

## Tests over the state machine and the fight.
##
## The thing these exist to protect is the loop being closed: every state has to
## lead somewhere, and the player must always be able to get back to a cast.
## A game built from an earlier version of this template shipped with
## `level_finished` connected to nothing, sat frozen with a live HUD, and read
## to the person holding the phone as a crash. The equivalent here is a line
## that is out with no fish and no way to wind it in.


func _step(s: Sim, seconds: float) -> void:
	var step := 1.0 / 60.0
	for i in int(round(seconds / step)):
		s.advance(step)


## Drive to a chosen state through the real input seam, or give up. Returns
## whether it got there, so a test can assert the arrival rather than hang.
func _drive_to(s: Sim, want: String, limit: float = 40.0) -> bool:
	var step := 1.0 / 60.0
	# One memory for the whole drive. A fresh dict per frame resets the bot's tap
	# rhythm and it never taps at all - see the note on Policies.act.
	var mem := {}
	var n := int(round(limit / step))
	for i in n:
		if s.state == want:
			return true
		Policies.act(Policies.ANGLER, s, step, mem)
		s.advance(step)
	return s.state == want


func test_a_new_sim_starts_in_the_boat(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.eq(s.state, Sim.IDLE, "starts idle")
	t.eq(s.caught, 0, "nothing caught yet")
	t.eq(s.casts, 0, "nothing cast yet")
	t.approx(s.tension, 0.0, 1e-6, "no tension on the line")


func test_charging_then_releasing_puts_the_lure_in_the_air(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	t.eq(s.state, Sim.CHARGING, "holding loads the rod")
	_step(s, 0.5)
	t.gt(s.charge, 0.0, "the charge builds while held")
	s.release_cast()
	t.eq(s.state, Sim.FLYING, "letting go casts")
	t.eq(s.casts, 1, "the cast is counted")
	t.gt(s.cast_distance, Tuning.CAST_MIN - 0.001, "it went at least the minimum")


func test_charge_saturates_rather_than_running_away(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	_step(s, 10.0)
	t.approx(s.charge, 1.0, 1e-6, "charge tops out at one")
	s.release_cast()
	t.approx(s.cast_distance, Tuning.CAST_MAX, 1e-3, "and casts the maximum, not further")


## The cast decides the DEPTH, and the depth is the year - so this is the test
## that the progression's one line of arithmetic works.
func test_the_cast_charge_chooses_the_depth(t: TestHarness) -> void:
	# A tapped cast lands in the near shallows.
	var shallow := Sim.new(1)
	shallow.hold_cast()
	shallow.release_cast()
	t.ok(_drive_to(shallow, Sim.WAITING, 20.0), "a short cast reaches fishing depth")
	t.approx(shallow.lure_depth, shallow.fishing_depth(), 1e-3, "it settles where the cast put it")
	t.ok(shallow.state != Sim.SINKING, "and stops sinking")

	# A full one reaches the bottom of the spot.
	var deep := Sim.new(1)
	deep.hold_cast()
	_step(deep, Tuning.CAST_CHARGE_TIME + 0.2)
	deep.release_cast()
	t.ok(_drive_to(deep, Sim.WAITING, 25.0), "a full cast reaches fishing depth")
	t.gt(deep.lure_depth, shallow.lure_depth + 0.5,
		"a full cast fishes no deeper than a tapped one - the charge decides nothing")
	t.approx(deep.lure_depth, deep.deepest_here(), 1e-3, "a full cast reaches the bed")

	# And deeper is EARLIER, which is the whole game.
	t.lt(float(deep.year_here()), float(shallow.year_here()),
		"fishing deeper does not reach further back")


## THE WAY OUT OF A DEAD CAST, through the seam a thumb actually uses.
##
## This shipped broken and the report was "I cant recast or anything". The
## simulation had `reel_in()` the whole time, the suite tested it, and it passed
## - but nothing in the renderer ever called it, and a tap while waiting only
## spooked. So the player had a line in the water, no bite, and no route back to
## the boat at all.
##
## **A way out that only the simulation knows about is not a way out.** The test
## that matters drives the call the touch handler drives, which is `tap`.
func test_tapping_a_dead_cast_winds_it_back_in(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	s.release_cast()
	t.ok(_drive_to(s, Sim.WAITING, 20.0), "the lure reaches fishing depth")

	s.tap()
	t.eq(s.state, Sim.IDLE, "a tap on a dead cast leaves the line in the water")
	t.approx(s.lure_depth, 0.0, 1e-6, "the lure did not come back up")

	# And casting again has to work immediately afterwards.
	s.hold_cast()
	t.eq(s.state, Sim.CHARGING, "the player still cannot start another cast")
	_step(s, 0.4)
	s.release_cast()
	t.eq(s.state, Sim.FLYING, "the second cast never leaves the rod")


## But a tap at a fish that IS interested costs the fish, or the nibble is not a
## decision. This is the counterpart of the test above: the SAME gesture is a
## free way out on a dead cast and a real mistake once something is on the bait,
## and which it is depends only on the state the player can see.
func test_striking_early_at_a_nibble_costs_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.NIBBLING, 40.0), "a fish gets interested")
	var before := s.lost_count
	# The very first frame of a nibble is still water, so this is a strike at
	# nothing - the earliest possible mistake.
	s.tap()
	t.eq(s.state, Sim.LOST, "striking before the take cost nothing")
	t.eq(s.lost_count, before + 1, "and it was not counted")


func test_a_cast_cannot_be_started_during_a_fight(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	s.hold_cast()
	t.eq(s.state, Sim.FIGHTING, "a stray touch mid-fight does not start a cast")



## MINIGAME 1 ------------------------------------------------------------------

func test_a_bite_starts_the_fish_teasing_the_bait(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.NIBBLING), "a bite reaches the nibble")
	t.gt(float(s.teases_left), -0.5, "the tease count was never drawn")
	t.ok(not s.taking, "the fish takes it properly with no teasing at all")
	t.approx(s.tug, 0.0, 1e-6, "the float is already under before anything has happened")


## The float has to actually MOVE, and a tease has to look different from a take.
## That difference IS the mechanic - there is no HUD element for any of it.
func test_a_tease_is_shallow_and_a_take_is_deep(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	var tease_peak := 0.0
	var take_peak := 0.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING:
			break
		if s.in_tug:
			if s.taking:
				take_peak = maxf(take_peak, s.tug)
			else:
				tease_peak = maxf(tease_peak, s.tug)
		s.advance(step)
	t.gt(tease_peak, 0.0, "a tease does not move the float at all")
	t.gt(take_peak, 0.0, "the take does not move the float at all")
	t.gt(take_peak, tease_peak * 1.6,
		"a take is only %.2f deep against a tease's %.2f - they look the same" % [take_peak, tease_peak])


## And the float has to come back UP between tugs, or it reads as sinking rather
## than as something pulling at it.
func test_the_float_recovers_between_tugs(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	var went_under := false
	var came_back := false
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING:
			break
		if s.tug > 0.2:
			went_under = true
		elif went_under and s.tug <= 0.001:
			came_back = true
			break
		s.advance(step)
	t.ok(went_under, "the float never went under")
	t.ok(came_back, "the float never came back up - it reads as sinking, not as a bite")


func test_striking_on_the_take_hooks_the_fish(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING:
			break
		if s.can_hook():
			s.tap()
			break
		s.advance(step)
	t.eq(s.state, Sim.FIGHTING, "striking on the take did not set the hook")
	t.gt(s.tension, 0.0, "the fight starts with no tension at all")


func test_striking_on_a_tease_loses_the_fish(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	var struck := false
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING:
			break
		if s.in_tug and not s.taking:
			s.tap()
			struck = true
			break
		s.advance(step)
	t.ok(struck, "no tease was ever offered to strike at")
	t.eq(s.state, Sim.LOST, "striking on a tease still hooked it")
	t.eq(s.lost_count, 1, "and it was not counted as a loss")


func test_striking_at_still_water_loses_the_fish(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING or not s.in_tug:
			break
		s.advance(step)
	t.ok(not s.in_tug, "the fish never let go between tugs")
	s.tap()
	t.eq(s.state, Sim.LOST, "striking at nothing still hooked a fish")


func test_letting_the_take_pass_loses_the_fish(t: TestHarness) -> void:
	var s := _sim_nibbling()
	t.ok(s != null, "a nibble can be reached")
	if s == null:
		return
	# Never strike. It teases, takes, and gives up.
	_step(s, 12.0)
	t.gt(float(s.lost_count), 0.0, "the take never times out")
	t.eq(s.caught, 0, "nothing was landed")


## The tease count must VARY, or a player counts tugs instead of watching the
## float - which is the one way this mechanic can quietly stop being about
## looking at anything.
func test_the_number_of_teases_varies_between_bites(t: TestHarness) -> void:
	var seen := {}
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var s := Sim.new(seed_value)
		if _drive_to(s, Sim.NIBBLING, 60.0):
			seen[s.teases_left] = true
	t.gt(float(seen.size()), 1.0, "every bite offers the same number of teases")


## Striking early in the take window is a clean set, and it is worth something
## the player FEELS rather than reads.
func test_a_clean_set_starts_the_fight_further_along(t: TestHarness) -> void:
	var early := _strike_into_take(0.1)
	var late := _strike_into_take(0.92)
	t.ok(early != null and late != null, "both an early and a late set are reachable")
	if early == null or late == null:
		return
	t.gt(early.tension, late.tension, "a clean set is worth nothing over a late one")
	t.lt(early.tension, Tuning.DANGER,
		"a clean set starts the fight with the rod already in the red, which punishes the good strike")


## MINIGAME 2 ------------------------------------------------------------------

func test_reeling_in_calm_water_never_breaks_anything(t: TestHarness) -> void:
	# THE PROMISE THE FIFTH FIGHT MAKES, driven through the real sim rather than
	# through the arithmetic in Tuning, so the two cannot drift apart.
	#
	# Gideon: "you can reel while the fish is calm and stop when it starts pulling
	# too hard." The first half of that has to be literally true - a patient
	# player holding the button in calm water must be able to do it all day.
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	var step := 1.0 / 60.0
	var peak := 0.0
	var reeled := 0.0
	s.set_reel(1.0)
	for i in int(round(30.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		# Hold the fish in calm water: this claim is about reeling, not about runs.
		s.running = false
		s.tell = 0.0
		s.phase_time = 9.0
		s.advance(step)
		peak = maxf(peak, s.tension)
		reeled += step
	t.lt(peak, Tuning.DANGER,
		"reeling in calm water reached %.2f against a danger line of %.2f" % [peak, Tuning.DANGER])
	t.ok(s.state != Sim.LOST, "reeling in calm water lost the fish")


func test_holding_raises_the_needle_and_it_falls_when_let_go(t: TestHarness) -> void:
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	# From SLACK, so the claim is about the rise rather than about where a fresh
	# hook happens to start - a hooked fish begins at SAFE_LO, which is already
	# most of the way to where reeling settles.
	s.tension = 0.05
	var before := s.tension
	s.set_reel(1.0)
	_step(s, 0.5)
	t.gt(s.tension, before, "holding REEL does not raise the tension")
	var peak := s.tension
	s.set_reel(0.0)
	_step(s, 1.2)
	t.lt(s.tension, peak, "the tension does not fall when the button is let go")

	# AND THE BUTTON MUST NOT STAY DOWN ACROSS A STATE CHANGE. A thumb can still
	# be on the glass when the fish lands or the line parts, and a `reeling` left
	# true would then be pulling on the next cast before it was made. Driven by
	# ending the fight for real rather than by calling `reel_in`, which does
	# nothing at all during a fight - the first version of this test called it and
	# was asserting against a no-op.
	s.set_reel(1.0)
	var step2 := 1.0 / 60.0
	for i in int(round(30.0 / step2)):
		if s.state != Sim.FIGHTING:
			break
		s.advance(step2)
	t.ok(s.state != Sim.FIGHTING, "holding the button forever never ends the fight")
	t.approx(s.reel_want, 0.0, 1e-6, "the fight ended with the reel slide still pushed")


## The fault that killed the FIRST fight, asserted directly: there must be no
## input the player can hold to win. Tapping is a rate, so doing nothing decays
## and doing everything overshoots.
func test_there_is_no_setting_that_wins_on_its_own(t: TestHarness) -> void:
	# Swept across the WHOLE range rather than at the two ends, which is the
	# change the hold made necessary. With a tap rate, only the extremes were
	# plausible mistakes. With a held button, every fixed duty cycle in between
	# is a setting a player could find and sit on - and one of them landing the
	# fish unaided would be the first fight returning without anyone noticing.
	# THE CLAIM HAD TO BE RESTATED WHEN THE CONTROL CHANGED, and the restatement
	# is more honest than what it replaced.
	#
	# The old version checked two tap rates, zero and thirty, and passed. Swept
	# across the whole range it would have failed: tension settles in proportion
	# to the input rate, so SOME middle rate has always parked the needle in the
	# band. That was as true of tapping as it is of holding - the test was simply
	# never asked.
	#
	# So the property that actually matters is not "no setting wins" but "no
	# setting wins WELL". A cautious fixed duty is meant to land fish slowly:
	# that is the risk dial working, since the haul scales with height in the
	# band. What must not exist is a setting that is both safe AND fast.
	# Compared against ACTIVE PLAY on the same fish rather than against a magic
	# number of seconds. A threshold typed in by hand is a second thing to tune,
	# and it drifts the moment any constant moves - the first version of this
	# used 12.0 s and started failing at 11.9 s the day the reeds were softened,
	# which says nothing about the game.
	var active := _play_fight_actively()
	t.gt(active, 0.0, "active play never landed the fish, so there is nothing to compare against")
	var landed_fast: Array[String] = []
	for i in 11:
		var duty := float(i) / 10.0
		var out := _play_fight_at_duty_timed(duty)
		if str(out["state"]) == Sim.HOLDING and float(out["seconds"]) < active * 1.25:
			landed_fast.append("%.1f in %.1fs" % [duty, float(out["seconds"])])
	t.eq(landed_fast.size(), 0,
		"a fixed duty cycle lands the fish about as fast as playing it (%.1fs): %s" % [
			active, ", ".join(landed_fast)])

	# And the two ends still fail outright, which is the original claim intact.
	t.ok(_play_fight_at_duty(0.0) != Sim.HOLDING, "never touching the button lands the fish")
	t.ok(_play_fight_at_duty(1.0) != Sim.HOLDING, "never letting go lands the fish")


func test_holding_the_needle_in_the_band_brings_the_fish_in(t: TestHarness) -> void:
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	var start := s.fish_distance
	var step := 1.0 / 60.0
	for i in int(round(3.0 / step)):
		if s.state != Sim.FIGHTING or s.running or s.tell > 0.0:
			break
		s.set_reel(1.0 if s.tension < (Tuning.SAFE_LO + Tuning.SAFE_HI) * 0.5 else 0.0)
		s.advance(step)
	t.lt(s.fish_distance, start, "keeping the needle in the band gained no line")


## THE RISK DIAL, MEASURED THROUGH THE SIM: fishing near the red wears a fish out
## faster than fishing gently. That is what makes the greedy line genuinely better
## and genuinely near the edge, rather than a maintenance task with a top speed.
func test_fishing_near_the_red_wears_a_fish_out_faster(t: TestHarness) -> void:
	var spent := {}
	for ceiling in [0.50, 0.95]:
		var s := _deep_fight()
		if s == null:
			t.ok(false, "a deep fish can be hooked")
			return
		var step := 1.0 / 60.0
		for i in int(round(12.0 / step)):
			if s.state != Sim.FIGHTING:
				break
			# Feather against this ceiling, and never reel into a run, so the only
			# thing separating the two runs is how hard the rod is worked.
			s.set_reel(1.0 if not s.running and s.tension < ceiling else 0.0)
			s.advance(step)
		spent[ceiling] = 1.0 - s.fish_stamina

	t.gt(float(spent[0.95]), float(spent[0.50]) * 1.25,
		"working the rod near the red tires a fish by %.2f against %.2f played gently - there is nothing to weigh" % [
			float(spent[0.95]), float(spent[0.50])])


func test_a_slack_line_lets_the_fish_take_line_back(t: TestHarness) -> void:
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	var step := 1.0 / 60.0
	# Let it go slack first, then measure.
	for i in int(round(3.0 / step)):
		if s.state != Sim.FIGHTING or s.tension < Tuning.SAFE_LO:
			break
		s.advance(step)
	var start := s.fish_distance
	for i in int(round(1.0 / step)):
		if s.state != Sim.FIGHTING or s.running:
			break
		s.advance(step)
	t.gt(s.fish_distance, start - 0.001, "a slack line costs no ground")


func test_holding_through_a_strong_fish_parts_the_line(t: TestHarness) -> void:
	# "then eventually snaps, if you dont stop reeling."
	#
	# Measured on a DEEP fish, and that is the design rather than a convenience:
	# `run_power` is what decides whether holding on is survivable, so a reeds
	# bluegill must forgive it and a lake trout must not. Testing this on the
	# opening fish would assert that the tutorial punishes a beginner.
	var s := _deep_fight()
	t.ok(s != null, "a deep fish can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	s.set_reel(1.0)
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		# Hold it in a run: the claim is about refusing to let go, not about
		# whether a run happened to be long enough.
		s.running = true
		s.tell = 0.0
		s.phase_time = 9.0
		s.advance(step)
	t.eq(s.state, Sim.LOST, "holding the reel through a strong fish's run costs nothing")


## A run climbs the needle with NO input, which is the whole instruction for
## what to do about it. If it ever stops doing that, the mechanic loses the one
## thing that teaches it.
func test_a_run_raises_the_tension_on_its_own(t: TestHarness) -> void:
	# Measured ACROSS the moment a run starts, not from inside one. `_sim_running`
	# hands back a sim that is ALREADY running, by which point the jolt has landed
	# and the needle is on its way back down toward the settle point - so a test
	# that steps forward from there measures the decay and reports the opposite of
	# what actually happens.
	var step := 1.0 / 60.0
	var jumped := false
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s := Sim.new(seed_value)
		var mem := {}
		for i in int(round(180.0 / step)):
			var was_running := s.running
			var before := s.tension
			Policies.act(Policies.ANGLER, s, step, mem)
			s.advance(step)
			if s.running and not was_running:
				t.gt(s.tension, before, "a run does not raise the tension by itself")
				jumped = true
				break
		if jumped:
			break
	t.ok(jumped, "no run ever started, so nothing was measured")

func test_a_run_is_announced_before_it_starts(t: TestHarness) -> void:
	# Across seeds, because a single fight can be over before the fish ever runs -
	# and a test that asserts about a run has to actually reach one.
	var step := 1.0 / 60.0
	var saw_tell := false
	var tell_led_the_run := false
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s := Sim.new(seed_value)
		var mem := {}
		for i in int(round(150.0 / step)):
			if s.tell > 0.0:
				saw_tell = true
				t.ok(not s.running, "the warning fires after the run has already begun")
			if saw_tell and s.running:
				tell_led_the_run = true
				break
			Policies.act(Policies.ANGLER, s, step, mem)
			s.advance(step)
		if tell_led_the_run:
			break
	t.ok(saw_tell, "a run was never announced")
	t.ok(tell_led_the_run, "a warning fired but no run followed it")


## ...AND THE REEDS FORGIVE IT, which is the other half of the same design. A
## beginner who has not yet learned to let go must not be punished in the tutorial
## band; `run_power` is what decides that, and this asserts the gentle end of it.
func test_a_reeds_fish_forgives_holding_through_one_run(t: TestHarness) -> void:
	var s := _sim_running()
	t.ok(s != null, "a run can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	s.set_reel(1.0)
	for i in int(round(8.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.advance(step)
	t.ok(s.state != Sim.LOST,
		"one run from an opening reeds fish parted the line - the tutorial is punishing a beginner")


func test_playing_it_properly_lands_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	var mem := {}
	var step := 1.0 / 60.0
	var landed := false
	for i in int(round(90.0 / step)):
		if s.caught > 0:
			landed = true
			break
		Policies.act(Policies.ANGLER, s, step, mem)
		s.advance(step)
	t.ok(landed, "playing both minigames correctly never lands anything")
	t.gt(s.total_weight, 0.0, "a fish was counted but weighs nothing")

## G3: BAIT IS READ IN THE MINIGAME, not in the waiting.
##
## It moved the BITE RATE and nothing else, so the right bait meant a shorter wait
## and no difference at all once something was on. The wait is the one part of
## this game the player is not watching closely, which made the whole bait economy
## invisible: you bought sweetcorn, something bit sooner, and you never saw why it
## was better.
func test_the_right_bait_is_felt_on_the_float(t: TestHarness) -> void:
	# Worms favour bluegill and do not favour carp - straight off the table, so
	# this fails if the content changes under it rather than asserting a guess.
	t.ok(Gear.favours("worm", "bluegill"), "worms no longer favour bluegill")
	t.ok(not Gear.favours("worm", "carp"), "worms now favour carp")

	var row := Species.by_id("bluegill")
	var right := Sim.new(1)
	right.econ.bait = "worm"
	right.fish_id = "bluegill"
	var wrong := Sim.new(1)
	wrong.econ.bait = "worm"
	wrong.fish_id = "carp"

	t.gt(right.take_window_now(row), float(row["take_window"]),
		"the right bait does not lengthen the take")
	t.lt(wrong.take_window_now(Species.by_id("carp")),
		float(Species.by_id("carp")["take_window"]),
		"the wrong bait does not shorten the take")

	# AND IT IS ONE NUMBER. The float's dip, the clock that runs the take and the
	# judgement of a clean set all read this - scoring against the species' raw
	# window while the float drew the adjusted one would grade the player on a
	# window they never saw.

	# ...AND THE JUDGEMENT USES IT TOO, which is the half a timer check cannot
	# see. A strike is "clean" if it lands in the first 45% of the take, so pick
	# the one moment the two windows DISAGREE about: with a bluegill's 0.85 s
	# stretched to 1.32 by worms, a strike with 0.60 s left is late (0.60 is under
	# 55% of 1.32) but would read as clean against the raw window (0.60 is over
	# 55% of 0.85). Scoring against a window the float never drew is exactly the
	# bug, and only a case the two disagree about will catch it.
	var judged := Sim.new(1)
	judged.econ.bait = "worm"
	judged.fish_id = "bluegill"
	judged.fish_weight = 0.2
	judged.cast_distance = 10.0
	judged.state = Sim.NIBBLING
	judged.taking = true
	judged.in_tug = true
	judged.takes_left = 1
	judged.tug_timer = 0.60
	judged._strike()
	t.lt(judged.tension, Tuning.SAFE_LO + 0.0001,
		"a late strike was graded clean against a window the player never saw")

	# MORE TEASES BEFORE IT COMMITS, so the right bait is a richer read rather
	# than merely an easier one.
	# THE SAME FISH AND THE SAME SEED, with the bait as the only difference.
	#
	# The first version compared a bluegill on worms against a CARP on worms and
	# asserted the first teased more. That is two species with two base tease
	# counts and two RNG draws: it compared everything except the thing it was
	# about, and it duly reported 3 against 3.
	var teasy := Sim.new(7)
	teasy.econ.bait = "worm"          ## favours bluegill
	teasy.fish_id = "bluegill"
	teasy._start_nibble()
	var plain := Sim.new(7)
	plain.econ.bait = "corn"          ## does not
	plain.fish_id = "bluegill"
	plain._start_nibble()
	t.ok(not Gear.favours("corn", "bluegill"),
		"sweetcorn now favours bluegill, so this comparison tests nothing")
	t.gt(teasy.teases_left, plain.teases_left,
		"a fish that wants what you are offering does not play with it any longer")



## G2: THE FISH IS IN YOUR HANDS UNTIL YOU DECIDE.
##
## This used to assert the opposite - that the hold ended on a timer and the fish
## went in the box on its own. That was the game making the decision, and "over
## the gunwale, weight in the hands, then keep or return" is the decision.
##
## The way OUT of the state still matters and is still asserted, because a state
## with no exit is the frozen level a sibling game shipped. There are two exits
## now and neither of them is a clock.
func test_a_landed_fish_waits_for_the_player_to_decide(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.HOLDING, 90.0), "a fish can be landed")
	_step(s, Tuning.HOLD_TIME * 3.0)
	t.eq(s.state, Sim.HOLDING,
		"the fish went in the box on a timer - the player never got to choose")
	t.ok(s.fish_id != "", "the fish left your hands without being kept or put back")

	# THE FISH THIS SEED LANDS IS A TEN KILO CARP AND THE BUCKET HOLDS SIX, which
	# is the wall G1 is about and worth asserting exactly here: "keep" is a
	# request, not a guarantee, and the moment it is refused is the moment the
	# player learns what the livewell is for.
	var before: int = s.econ.held.size()
	var too_big := s.fish_weight > s.econ.capacity()
	var went_in := s.keep_fish()
	t.eq(went_in, not too_big,
		"a %.1f kg fish and a %.1f kg box disagreed about whether it fits" % [
			s.fish_weight, s.econ.capacity()])
	t.eq(s.state, Sim.IDLE, "keeping it left the player holding it")
	t.eq(s.fish_id, "", "and the fish is cleared")
	t.eq(s.econ.held.size(), before + (0 if too_big else 1),
		"the box disagrees with what keeping it reported")

	# ...and one that DOES fit goes in.
	var s3 := Sim.new(1)
	t.ok(_drive_to(s3, Sim.HOLDING, 90.0), "a third fish can be landed")
	s3.fish_weight = 0.4
	t.ok(s3.keep_fish(), "a small fish would not go in an empty livewell")
	t.eq(s3.econ.held.size(), 1, "it was kept and is not in the box")

	# PUTTING IT BACK IS THE OTHER, and it costs the box nothing.
	var s2 := Sim.new(4)
	t.ok(_drive_to(s2, Sim.HOLDING, 90.0), "a second fish can be landed")
	var held: int = s2.econ.held.size()
	s2.return_fish()
	t.eq(s2.state, Sim.IDLE, "putting it back left the player holding it")
	t.eq(s2.econ.held.size(), held, "a fish put back still went in the livewell")
	t.eq(s2.returned, 1, "putting it back was not written down")
	# ...and it is still in the BOOK. What you caught is a fact; what you kept is
	# a choice, and the logbook records the first.
	t.gt(float(s2.logged.size()), 0.0, "a fish put back was struck from the book")

## G1: FISH AND OBJECTS COMPETE FOR THE SAME ROOM.
##
## Junk used to turn into coins the instant it broke the surface - the bottom of
## the lake was a slot machine and the boat was infinite. It is in your hands now
## like a fish, and keeping it costs space a fish could have had. With two kilos
## of room left, a bicycle wheel worth four coins and a bream worth thirty are the
## same decision, which is the whole point.
func test_a_kept_object_takes_room_a_fish_wanted(t: TestHarness) -> void:
	var s := Sim.new(1)
	# DRIVEN THROUGH THE REAL HOOK, because "nothing is paid on the way up" is a
	# claim about `_hook_object` and a hand-built HOLDING state cannot test it -
	# the first version of this check set the state directly and passed happily
	# with the payout put back in.
	var money_before: int = s.econ.money
	s.lure_depth = 3.0
	s._hook_object()
	t.eq(s.state, Sim.HOLDING, "hooking something did not put it in your hands")
	t.eq(s.fish_id, "", "an object came up as a fish")
	t.eq(s.econ.money, money_before,
		"it paid out on the way up - the bottom of the lake is still a slot machine")
	# From here on the boot is the thing in your hands, whatever came up.
	s.last_object = "boot"
	t.ok(s.keep_fish(), "a boot could not be kept")
	t.eq(s.econ.held.size(), 1, "the boot is not in the livewell")
	t.gt(s.econ.load_kg(), 0.0, "the boot weighs nothing, so it costs no room")

	# ONE ROOM, NOT TWO. The space it took is space a fish cannot have.
	var room := s.econ.space_left()
	t.lt(room, s.econ.capacity(), "the boot took no room from the fish")

	# AND IT IS WORTH SOMETHING AT THE SHED, by the piece rather than the kilo.
	var paid := s.econ.sell_all()
	t.gt(paid, 0, "the boot weighed in for nothing - junk is sold by the piece")

	# PUTTING IT BACK COSTS THE WELL NOTHING, and is not counted as a fish
	# returned: you did not catch it.
	var s2 := Sim.new(1)
	s2.state = Sim.HOLDING
	s2.fish_id = ""
	s2.last_object = "boot"
	s2.return_fish()
	t.eq(s2.econ.held.size(), 0, "a boot put back went in the livewell anyway")
	t.eq(s2.returned, 0, "putting a boot back was written down as returning a fish")


## AN OFFERING IS NOT A DECISION. It is the only bait that cannot be bought and
## the reason you went that deep, so it goes in the bait box the moment it comes
## up rather than competing with a bream for the bucket.
func test_an_offering_is_never_a_trade(t: TestHarness) -> void:
	var s := Sim.new(1)
	var before: int = int(s.econ.bait_left.get(Gear.OFFERING, 0))
	# A depth with an offering in its range. The first version of this test
	# hooked at 150 m, where no offering row reaches, so it pulled up a boot
	# every time, its assertions sat inside an `if` that was never true, and it
	# passed for a day asserting nothing. The precondition is asserted now: no
	# offering means the test FAILS as itself rather than as whatever it was
	# meant to measure.
	s.lure_depth = 125.0
	var came_up := false
	var hooks := 0
	# Driven through the real hook so this fails if the path ever changes.
	while hooks < 80 and not came_up:
		hooks += 1
		s._hook_object()
		came_up = s.last_object != "" \
			and String(Objects.by_id(s.last_object)["kind"]) == Objects.OFFERING
	t.ok(came_up, "no offering came up in %d hooks at 125 m, so nothing below was checked" % hooks)
	t.gt(int(s.econ.bait_left.get(Gear.OFFERING, 0)), before,
		"an offering came up and did not go in the bait box")
	t.eq(s.econ.held.size(), 0, "an offering took livewell room")



## NOT EVERYTHING HELD UP IS A FISH, and the state has to let an object go.
##
## `_hook_object` puts a boot or a licence plate in your hands through the same
## HOLDING state, and there is nothing to weigh and nothing to decide about it.
## The first cut of G2 returned early for an object WITHOUT leaving the state, so
## it held the game open forever: a bot pulled one up twenty-nine seconds into a
## sixty second session and did nothing for the rest of it. Every golden session
## fell from five casts to two, and it read as the fight having got slower.
func test_an_object_can_be_put_down(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.state = Sim.HOLDING
	s.fish_id = ""
	s.fish_weight = 0.0
	var held: int = s.econ.held.size()
	t.ok(s.keep_fish(), "an object could not be put down")
	t.eq(s.state, Sim.IDLE, "an object held the game open")
	t.eq(s.econ.held.size(), held, "an object went into the livewell")

	# ...and the other button does not count it as a fish returned.
	var s2 := Sim.new(1)
	s2.state = Sim.HOLDING
	s2.fish_id = ""
	s2.return_fish()
	t.eq(s2.state, Sim.IDLE, "an object held the game open")
	t.eq(s2.returned, 0, "putting an object down was written down as returning a fish")


func test_a_lost_fish_also_returns_the_player_to_the_boat(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	_break_the_line(s)
	t.eq(s.state, Sim.LOST, "the line broke")
	_step(s, Tuning.HOLD_TIME)
	t.eq(s.state, Sim.IDLE, "and the player can cast again")


func test_casting_straight_out_of_a_loss_clears_the_last_fish(t: TestHarness) -> void:
	# A player who casts the instant a fish comes off never passes through IDLE,
	# so any cleanup that lives on that transition never runs. The golden caught
	# this as a session sitting in `waiting` with damage still recorded and a
	# species still named - a state that should not be able to exist.
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	_break_the_line(s)
	t.eq(s.state, Sim.LOST, "the line never broke")

	s.hold_cast()
	t.eq(s.state, Sim.CHARGING, "the player can cast again immediately")
	t.eq(s.fish_id, "", "the lost fish is cleared")
	t.approx(s.strain, 0.0, 1e-6, "and its strain")
	t.approx(s.tension, 0.0, 1e-6, "and its tension")


func test_reeling_in_always_gets_out_of_a_dead_cast(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	s.release_cast()
	t.ok(_drive_to(s, Sim.WAITING), "the lure reaches fishing depth")
	s.reel_in()
	t.eq(s.state, Sim.IDLE, "winding in returns to the boat")
	t.approx(s.lure_depth, 0.0, 1e-6, "and the lure comes back up")


func test_the_simulation_is_frame_rate_independent(t: TestHarness) -> void:
	# The same session at 60 and at 120 must agree. The phone runs at 120 and
	# the tests run at 60, so any per-step arithmetic that should have been
	# per-second shows up here and nowhere else.
	var a := Policies.play(Policies.ANGLER, 40.0, 7)
	var s := Sim.new(7)
	var mem := {}
	var step := 1.0 / 120.0
	for i in int(round(40.0 / step)):
		Policies.act(Policies.ANGLER, s, step, mem)
		s.advance(step)
	var b := s.state_snapshot()
	t.eq(a["caught"], b["caught"], "the same number of fish at 120 fps as at 60")
	t.eq(a["casts"], b["casts"], "and the same number of casts")


func test_a_session_is_reproducible_from_its_seed(t: TestHarness) -> void:
	var a := Policies.play(Policies.ANGLER, 45.0, 3)
	var b := Policies.play(Policies.ANGLER, 45.0, 3)
	t.dict_eq(a, b, "the same seed plays the same session")


func test_different_seeds_give_different_water(t: TestHarness) -> void:
	# If they do not, the rng is not wired to the seed and every session is the
	# same one - which looks fine for a long time.
	var ids := {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var r := Policies.play(Policies.ANGLER, 45.0, seed_value)
		ids["%s/%s" % [str(r["caught"]), str(r["total_weight"])]] = true
	t.gt(float(ids.size()), 1.0, "not every seed produces an identical session")



## Fish until the fish is nibbling, and hand the sim back mid-sequence. Returns
## null if it never happened, so a test can assert its own setup rather than
## quietly test nothing.
func _sim_nibbling(seeds: Array = [1, 2, 3, 4, 5, 6]) -> Sim:
	var step := 1.0 / 60.0
	for seed_value in seeds:
		var s := Sim.new(seed_value)
		for i in int(round(90.0 / step)):
			if s.state == Sim.NIBBLING:
				return s
			match s.state:
				Sim.IDLE, Sim.HOLDING, Sim.LOST:
					s.hold_cast()
				Sim.CHARGING:
					if s.state_time >= Policies.CHARGE_HOLD:
						s.release_cast()
				_:
					pass
			s.advance(step)
	return null


## A sim mid-fight, hooked cleanly through the real input seam.
func _sim_fighting(seeds: Array = [1, 2, 3, 4, 5, 6]) -> Sim:
	var step := 1.0 / 60.0
	for seed_value in seeds:
		var s := Sim.new(seed_value)
		var mem := {}
		for i in int(round(90.0 / step)):
			if s.state == Sim.FIGHTING:
				return s
			Policies.act(Policies.ANGLER, s, step, mem)
			s.advance(step)
	return null


## A sim in the middle of a RUN, played correctly up to that point.
func _sim_running(seeds: Array = [1, 2, 3, 4, 5, 6, 7, 8]) -> Sim:
	var step := 1.0 / 60.0
	for seed_value in seeds:
		var s := Sim.new(seed_value)
		var mem := {}
		for i in int(round(180.0 / step)):
			if s.state == Sim.FIGHTING and s.running:
				return s
			Policies.act(Policies.ANGLER, s, step, mem)
			s.advance(step)
	return null


## Set the hook at a chosen distance off the centre of the zone, as a fraction of
## its half-width. Used to prove a centred set is worth more than an edge one.
## Strike at a chosen fraction into the TAKE window. Used to prove a clean set is
## worth more than a late scramble.
func _strike_into_take(into: float) -> Sim:
	var s := _sim_nibbling()
	if s == null:
		return null
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.NIBBLING:
			return null
		if s.can_hook():
			var row := Species.by_id(s.fish_id)
			var span: float = row["take_window"]
			var elapsed := span - s.tug_timer
			if elapsed >= span * clampf(into, 0.0, 0.98):
				s.tap()
				return s if s.state == Sim.FIGHTING else null
		s.advance(step)
	return null


## Play one whole fight tapping at a fixed rate, and report where it ended.
## Play a whole fight at ONE fixed duty cycle and report how it ended. 0.0 is a
## thumb that never touches the button, 1.0 is one that never leaves it.
func _play_fight_at_duty(duty: float) -> String:
	var s := _deep_fight()
	if s == null:
		return "unreachable"
	var step := 1.0 / 60.0
	var cycle := 0.9
	var phase := 0.0
	for i in int(round(60.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		phase = fmod(phase + step, cycle)
		s.set_reel(1.0 if phase < cycle * duty else 0.0)
		s.advance(step)
	return s.state


## As `_play_fight_at_duty`, but reporting how long the fight took as well, so a
## claim can be about SPEED rather than only about the outcome.
func _play_fight_at_duty_timed(duty: float) -> Dictionary:
	var s := _deep_fight()
	if s == null:
		return {"state": "unreachable", "seconds": 0.0}
	var step := 1.0 / 60.0
	var cycle := 0.9
	var phase := 0.0
	var elapsed := 0.0
	for i in int(round(60.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		phase = fmod(phase + step, cycle)
		s.set_reel(1.0 if phase < cycle * duty else 0.0)
		s.advance(step)
		elapsed += step
	return {"state": s.state, "seconds": elapsed}


## How long ACTIVE play takes to land the same fish, so "fast" can be measured
## against the game rather than against a number somebody typed.
func _play_fight_actively() -> float:
	var s := _deep_fight()
	if s == null:
		return 0.0
	var step := 1.0 / 60.0
	var mem := {}
	var elapsed := 0.0
	for i in int(round(60.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		Policies.act(Policies.ANGLER, s, step, mem)
		s.advance(step)
		elapsed += step
	return elapsed if s.state == Sim.HOLDING else 0.0


## A fight against a DEEP fish, set up directly the way `scripts/balance.gd` does.
##
## Claims about whether the fight can be beaten by a fixed setting have to be made
## in water where the fight is a fight. `_sim_fighting` hooks whatever the opening
## reeds give it, and a tutorial fish is SUPPOSED to be landable without much
## attention - measuring the "no setting wins" claim there is the same mistake
## NOTES.md already records once: measure a claim in the water the claim is about.
func _deep_fight() -> Sim:
	var s := Sim.new(1)
	var row := Species.by_id("trout")
	if row.is_empty():
		return null
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = str(row["id"])
	s.fish_weight = float(row["weight_lo"])
	s.fish_distance = Tuning.CAST_MAX
	s.fish_stamina = 1.0
	s.tension = Tuning.SAFE_LO
	s.running = false
	s.phase_time = 2.0
	s.state = Sim.FIGHTING
	s.state_time = 0.0
	return s


## Break the line the way the fifth fight breaks it: keep reeling into a run.
##
## There is no longer any way to part a line in calm water, which is the whole
## point of the new model - so every test that needs a broken line has to go
## through the one decision that can break it.
func _break_the_line(s: Sim) -> void:
	var step := 1.0 / 60.0
	# NOT REELING. Pinning the tension is enough to accrue strain, and reeling as
	# well LANDED the fish before the line ever parted - a weak fish still gains
	# ground through a run, which is the tutorial being forgiving working exactly
	# as designed and quietly making this helper assert the opposite of its name.
	for i in int(round(24.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		# Pinned at the top and held there, which is what refusing to let go of a
		# strong fish arrives at. Driven through the real strain path rather than
		# by writing LOST, so these tests still break if the snap ever stops
		# working - they are about what happens AFTER a loss, and the loss itself
		# has to be genuine or they are asserting against a state nobody reaches.
		s.running = true
		s.tell = 0.0
		s.phase_time = 9.0
		s.tension = Tuning.TENSION_MAX
		s.advance(step)
