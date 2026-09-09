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


func test_the_lure_sinks_to_the_bed_and_stops(t: TestHarness) -> void:
	# Read the depth the moment sinking finishes, not after an arbitrary wait.
	# A fish can take the lure a second later and the whole cast can be over,
	# which resets the depth - so a test that waits twenty seconds is asserting
	# about a different cast than the one it set up.
	var s := Sim.new(1)
	s.hold_cast()
	s.release_cast()
	t.ok(_drive_to(s, Sim.WAITING, 20.0), "the lure reaches fishing depth")
	t.approx(s.lure_depth, Tuning.BED_DEPTH, 1e-3, "it settles on the bottom")
	t.ok(s.state != Sim.SINKING, "and stops sinking")


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


## But a tap at a fish that IS interested still costs something, or the hook
## minigame is not a decision.
func test_tapping_at_a_nibble_still_spooks(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.NIBBLING, 40.0), "a fish gets interested")
	s.tap()
	t.eq(s.state, Sim.WAITING, "striking early did not put the fish off")
	t.gt(s.spook_timer, 0.0, "and there is no cost to doing it")


func test_a_cast_cannot_be_started_during_a_fight(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	s.hold_cast()
	t.eq(s.state, Sim.FIGHTING, "a stray touch mid-fight does not start a cast")



## MINIGAME 1 ------------------------------------------------------------------

func test_a_bite_opens_the_hook_bar_with_a_fresh_zone(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.HOOKING), "a bite reaches the hook bar")
	t.gt(s.zone_hi, s.zone_lo, "the green zone has a width")
	t.ok(s.zone_lo >= 0.0 and s.zone_hi <= 1.0, "the zone is on the bar")
	t.approx(s.sweep, 0.0, 0.05, "the marker starts at one end")
	t.gt(s.sweeps_left, 0.0, "there is time to hit it")


## The zone must MOVE between bites, or the bar becomes a metronome the player
## learns in two casts and never looks at again.
func test_the_hook_zone_moves_between_bites(t: TestHarness) -> void:
	var seen := {}
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s := Sim.new(seed_value)
		if _drive_to(s, Sim.HOOKING, 60.0):
			seen[snappedf(s.zone_lo, 0.01)] = true
	t.gt(float(seen.size()), 2.0, "the green zone lands in the same place every time")


func test_tapping_in_the_zone_hooks_the_fish(t: TestHarness) -> void:
	var s := _sim_at_hook_bar()
	t.ok(s != null, "the hook bar can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	for i in int(round(6.0 / step)):
		if s.state != Sim.HOOKING:
			break
		if s.sweep_in_zone():
			s.tap()
			break
		s.advance(step)
	t.eq(s.state, Sim.FIGHTING, "tapping inside the green zone did not set the hook")
	t.gt(s.tension, 0.0, "the fight starts with no tension at all")


func test_tapping_outside_the_zone_loses_the_fish(t: TestHarness) -> void:
	var s := _sim_at_hook_bar()
	t.ok(s != null, "the hook bar can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	# Wait until the marker is definitely outside, then tap.
	for i in int(round(6.0 / step)):
		if not s.sweep_in_zone():
			break
		s.advance(step)
	t.ok(not s.sweep_in_zone(), "the marker never left the zone")
	s.tap()
	t.eq(s.state, Sim.LOST, "tapping outside the zone still hooked it")
	t.eq(s.lost_count, 1, "and it was not counted as a loss")


func test_never_tapping_loses_the_fish_when_the_sweeps_run_out(t: TestHarness) -> void:
	var s := _sim_at_hook_bar()
	t.ok(s != null, "the hook bar can be reached")
	if s == null:
		return
	# Just past two sweeps of the slowest fish, and no further: LOST returns to
	# IDLE on its own after a moment, so waiting too long asserts about the wrong
	# state entirely.
	_step(s, 4.0)
	t.gt(float(s.lost_count), 0.0, "the bar never times out")
	t.eq(s.caught, 0, "nothing was landed")


## Dead centre is worth something the player FEELS rather than reads: the fight
## opens with the needle already inside the band.
func test_a_centred_set_starts_the_fight_further_along(t: TestHarness) -> void:
	var centred := _hook_at_offset(0.0)
	var edge := _hook_at_offset(0.95)
	t.ok(centred != null and edge != null, "both a centred and an edge set are reachable")
	if centred == null or edge == null:
		return
	t.gt(centred.tension, edge.tension, "a centred set is worth nothing over an edge one")
	t.ok(Tuning.in_band(centred.tension), "a centred set does not start inside the band")


## MINIGAME 2 ------------------------------------------------------------------

func test_the_band_is_physically_tappable(t: TestHarness) -> void:
	# The one property no bot and no screenshot would ever reveal. A band that
	# needs eleven taps a second is unplayable on a phone however good the
	# numbers look, and the whole point of this version was that it should feel
	# like a fun minigame rather than a dexterity test.
	var lo := Tuning.taps_per_second_for(Tuning.SAFE_LO)
	var hi := Tuning.taps_per_second_for(Tuning.SAFE_HI)
	t.gt(lo, 0.8, "holding the bottom of the band needs almost no tapping at all")
	t.lt(hi, 5.0, "holding the top of the band needs %.1f taps a second" % hi)
	t.gt(hi, lo, "tapping faster does not raise the needle")


func test_tapping_raises_the_needle_and_it_falls_on_its_own(t: TestHarness) -> void:
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	var before := s.tension
	s.tap()
	t.gt(s.tension, before, "a tap does not raise the tension")
	t.eq(s.taps, 1, "the tap was not counted")
	var peak := s.tension
	_step(s, 1.2)
	t.lt(s.tension, peak, "the tension does not fall between taps")


## The fault that killed the FIRST fight, asserted directly: there must be no
## input the player can hold to win. Tapping is a rate, so doing nothing decays
## and doing everything overshoots.
func test_there_is_no_setting_that_wins_on_its_own(t: TestHarness) -> void:
	var idle := _play_fight_with_taps(0.0)
	var frantic := _play_fight_with_taps(30.0)
	t.ok(idle != Sim.HOLDING, "never tapping lands the fish")
	t.ok(frantic != Sim.HOLDING, "tapping as fast as possible lands the fish")


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
		if s.tension < (Tuning.SAFE_LO + Tuning.SAFE_HI) * 0.5:
			s.tap()
		s.advance(step)
	t.lt(s.fish_distance, start, "keeping the needle in the band gained no line")


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


func test_the_line_parts_if_the_needle_is_pinned_at_the_top(t: TestHarness) -> void:
	var s := _sim_fighting()
	t.ok(s != null, "a fish can be hooked")
	if s == null:
		return
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.tap()
		s.tap()
		s.advance(step)
	t.eq(s.state, Sim.LOST, "the line never parts however hard it is tapped")


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


func test_tapping_through_a_run_is_what_breaks_the_line(t: TestHarness) -> void:
	var s := _sim_running()
	t.ok(s != null, "a run can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	for i in int(round(8.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.tap()
		s.advance(step)
	t.eq(s.state, Sim.LOST, "tapping through a run costs nothing")


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


func test_in_band_agrees_with_the_tuning_the_gauge_draws(t: TestHarness) -> void:
	# The gauge draws Tuning.SAFE_LO/SAFE_HI and the rules use in_band(). If they
	# can disagree the player is aiming at one thing and being scored on another.
	var s := Sim.new(1)
	for i in 40:
		s.tension = float(i) / 40.0
		t.eq(s.in_band(), Tuning.in_band(s.tension), "in_band disagrees with the drawn band")
func test_a_landed_fish_returns_the_player_to_the_boat(t: TestHarness) -> void:
	# The way OUT of the state. This is the assertion that would have caught
	# the frozen level on a sibling game.
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.HOLDING, 90.0), "a fish can be landed")
	_step(s, Tuning.HOLD_TIME + 0.2)
	t.eq(s.state, Sim.IDLE, "the hold ends and the line is back in the boat")
	t.eq(s.fish_id, "", "and the fish is cleared")


func test_a_lost_fish_also_returns_the_player_to_the_boat(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.tap()
		s.tap()
		s.advance(step)
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
	var step := 1.0 / 60.0
	for i in int(round(30.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.tap()
		s.tap()
		s.advance(step)
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



## Fish until the hook bar is up, and hand the sim back with it still showing.
## Returns null if it never happened, so a test can assert its own setup rather
## than quietly test nothing.
func _sim_at_hook_bar(seeds: Array = [1, 2, 3, 4, 5, 6]) -> Sim:
	var step := 1.0 / 60.0
	for seed_value in seeds:
		var s := Sim.new(seed_value)
		for i in int(round(90.0 / step)):
			if s.state == Sim.HOOKING:
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
func _hook_at_offset(off: float) -> Sim:
	var s := _sim_at_hook_bar()
	if s == null:
		return null
	var mid := (s.zone_lo + s.zone_hi) * 0.5
	var half := (s.zone_hi - s.zone_lo) * 0.5
	var want := mid + half * clampf(off, -0.99, 0.99)
	var step := 1.0 / 60.0
	for i in int(round(8.0 / step)):
		if s.state != Sim.HOOKING:
			return null
		if absf(s.sweep - want) < 0.012:
			s.tap()
			return s if s.state == Sim.FIGHTING else null
		s.advance(step)
	return null


## Play one whole fight tapping at a fixed rate, and report where it ended.
func _play_fight_with_taps(rate: float) -> String:
	var s := _sim_fighting()
	if s == null:
		return "unreachable"
	var step := 1.0 / 60.0
	var due := 0.0
	for i in int(round(60.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		due += rate * step
		while due >= 1.0:
			s.tap()
			due -= 1.0
		s.advance(step)
	return s.state
