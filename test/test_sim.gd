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
	var n := int(round(limit / step))
	for i in n:
		if s.state == want:
			return true
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)
	return s.state == want


func test_a_new_sim_starts_in_the_boat(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.eq(s.state, Sim.IDLE, "starts idle")
	t.eq(s.caught, 0, "nothing caught yet")
	t.eq(s.casts, 0, "nothing cast yet")
	t.approx(s.load, 0.0, 1e-6, "no load on the rod")


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


func test_a_cast_cannot_be_started_during_a_fight(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	s.hold_cast()
	t.eq(s.state, Sim.FIGHTING, "a stray touch mid-fight does not start a cast")


func test_striking_early_spooks_rather_than_hooks(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	s.release_cast()
	t.ok(_drive_to(s, Sim.WAITING), "the lure reaches fishing depth")
	s.strike()
	t.eq(s.state, Sim.WAITING, "a strike at nothing does not hook anything")
	t.gt(s.spook_timer, 0.0, "and puts the fish off for a moment")


func test_missing_the_window_loses_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	var step := 1.0 / 60.0
	var reached := false
	for i in int(round(40.0 / step)):
		if s.state == Sim.BITING:
			reached = true
			break
		# Cast and wait, but never strike.
		match s.state:
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				s.hold_cast()
			Sim.CHARGING:
				if s.state_time >= 0.55:
					s.release_cast()
			_:
				pass
		s.advance(step)
	t.ok(reached, "a bite happens within a reasonable time")
	_step(s, Tuning.BITE_WINDOW + 0.1)
	t.eq(s.state, Sim.LOST, "the window closes")
	t.eq(s.lost_count, 1, "and it counts as a loss")




## Every fish opens sullen, so the first thing a player ever does in a fight is
## pump. Opening on a run would teach the wrong lesson first.
func test_a_fight_opens_sullen_and_undamaged(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	t.eq(s.behaviour, Sim.B_HOLDING, "the fight opens with the fish sitting there")
	t.approx(s.strain, 0.0, 1e-6, "no strain on the line yet")
	# One simulation step runs between the hook and this assertion, so these are
	# "essentially undamaged" rather than exactly zero. Asserting an exact zero
	# here would be asserting a property of the test helper, not of the game.
	t.lt(s.slip, 0.05, "the fight opens with the hook already working loose")
	t.lt(s.wear, 0.05, "the fight opens with a worn hook")
	t.eq(s.pumps, 0, "and nothing has been pumped in")
	t.gt(s.fish_distance, 0.0, "the fish starts away from the boat")


## THE load-bearing test of the second fight.
##
## The first fight died because a single sustained thumb position landed every
## fish; a bot that found the band and stopped moving scored 6.83 and lost none.
## Gaining line now requires a lift AND a drop, so holding any constant load -
## high, low or perfect - must gain nothing at all. If this ever passes with a
## non-zero gain, the mechanic has quietly reverted to a threshold fight.
func test_a_steady_hand_gains_no_line_at_any_load(t: TestHarness) -> void:
	for held in [0.0, 0.25, 0.45, 0.62, 0.80, 1.0]:
		var s := Sim.new(1)
		if not _drive_to(s, Sim.FIGHTING):
			t.ok(false, "a fish can be hooked")
			return
		var start := s.fish_distance
		var step := 1.0 / 60.0
		for i in int(round(3.0 / step)):
			if s.state != Sim.FIGHTING:
				break
			s.set_pull(held)
			s.advance(step)
		t.eq(s.pumps, 0, "holding at %.2f completed a pump" % held)
		t.ok(s.fish_distance >= start - 0.001,
			"holding at %.2f gained line without a single pump" % held)


func test_a_full_pump_gains_line_and_tires_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var start := s.fish_distance
	var stam := s.fish_stamina
	var step := 1.0 / 60.0
	# One deliberate cycle, driven through the input seam: lift over the top,
	# then drop under the bottom.
	for i in int(round(0.8 / step)):
		if s.state != Sim.FIGHTING or s.behaviour != Sim.B_HOLDING:
			break
		s.set_pull(0.78)
		s.advance(step)
	for i in int(round(0.8 / step)):
		if s.state != Sim.FIGHTING or s.behaviour != Sim.B_HOLDING:
			break
		s.set_pull(0.0)
		s.advance(step)
	t.gt(float(s.pumps), 0.0, "a full lift and drop did not count as a pump")
	t.lt(s.fish_distance, start, "a pump gained no line")
	t.lt(s.fish_stamina, stam, "a pump did not tire the fish")


## The risk dial. A greedy pump is worth more, and the line starts complaining
## just above the profitable range - so the reward for going higher has to be
## real, or nobody would take the risk.
func test_a_higher_pump_is_worth_more(t: TestHarness) -> void:
	var small := Tuning.pump_gain(Tuning.PUMP_HIGH + 0.01, 1.0)
	var big := Tuning.pump_gain(0.95, 1.0)
	t.gt(small, 0.0, "a minimum pump gains nothing at all")
	t.gt(big, small * 1.8, "a greedy pump is barely better than a timid one")
	t.approx(Tuning.pump_gain(Tuning.PUMP_HIGH - 0.05, 1.0), 0.0, 1e-6,
		"a lift that never cleared the top still counted")


func test_holding_on_through_a_run_breaks_the_line(t: TestHarness) -> void:
	var s := _fish_in_behaviour(Sim.B_RUNNING)
	t.ok(s != null, "a run can be reached")
	if s == null:
		return
	# The helper fishes until a run, so it may have landed fish on the way.
	# Compare against what it had, not against zero.
	var before := s.caught
	var step := 1.0 / 60.0
	for i in int(round(6.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(1.0)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "holding the rod up through a run did not cost the fish")
	t.eq(s.caught, before, "the fish was landed rather than lost")


func test_giving_line_survives_a_run_but_costs_ground(t: TestHarness) -> void:
	var s := _fish_in_behaviour(Sim.B_RUNNING)
	t.ok(s != null, "a run can be reached")
	if s == null:
		return
	var start := s.fish_distance
	var step := 1.0 / 60.0
	for i in int(round(1.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(0.0)
		s.advance(step)
	t.eq(s.state, Sim.FIGHTING, "giving line through a run still lost the fish")
	t.gt(s.fish_distance, start, "a run took no ground back - it has no cost")
	t.approx(s.strain, 0.0, 1e-6, "giving line during a run still strained it")


## The warning. Acting on the tell rather than on the run is the difference
## between the two bots, and therefore the whole claim the mechanic makes.
func test_a_run_is_announced_before_it_starts(t: TestHarness) -> void:
	var s := Sim.new(3)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	var saw_tell := false
	var tell_led_the_run := false
	for i in int(round(30.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		if s.tell > 0.0 and s.next_behaviour == Sim.B_RUNNING:
			saw_tell = true
			t.eq(s.behaviour, Sim.B_HOLDING, "the tell fires after the run has already begun")
		if saw_tell and s.behaviour == Sim.B_RUNNING:
			tell_led_the_run = true
			break
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)
	t.ok(saw_tell, "no run was ever announced")
	t.ok(tell_led_the_run, "a tell fired but no run followed it")


func test_moving_the_thumb_during_a_head_shake_throws_the_hook(t: TestHarness) -> void:
	var s := _fish_in_behaviour(Sim.B_SURFACING)
	t.ok(s != null, "a head-shake can be reached")
	if s == null:
		return
	var step := 1.0 / 60.0
	var flip := 0.0
	for i in int(round(4.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		flip = 1.0 - flip
		s.set_pull(flip)
		s.advance(step)
	t.gt(s.slip, 0.4, "thrashing the thumb through a head-shake cost nothing")


func test_holding_steady_through_a_head_shake_tires_it_fastest(t: TestHarness) -> void:
	var s := _fish_in_behaviour(Sim.B_SURFACING)
	t.ok(s != null, "a head-shake can be reached")
	if s == null:
		return
	var mid := (Tuning.SHAKE_LO + Tuning.SHAKE_HI) * 0.5
	var start := s.fish_stamina
	var step := 1.0 / 60.0
	for i in int(round(1.0 / step)):
		if s.state != Sim.FIGHTING or s.behaviour != Sim.B_SURFACING:
			break
		s.set_pull(mid)
		s.advance(step)
	t.lt(s.fish_stamina, start, "holding steady through a shake did not tire it")
	t.lt(s.slip, 0.25, "holding steady through a shake was punished")


## Doing nothing has to lose too, or the winning strategy is to take all day -
## which is what every forgiving fishing minigame collapses to.
func test_dithering_loses_the_fish_to_the_hook_working_loose(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	# A load that is safe everywhere and productive nowhere: never high enough
	# to arm a pump, never slack enough to count as slack.
	for i in int(round(90.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(0.30)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "a fight can be sat out indefinitely")
	t.eq(s.caught, 0, "and it was not landed")


func test_playing_it_properly_lands_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	var landed := false
	for i in int(round(90.0 / step)):
		if s.state == Sim.HOLDING:
			landed = true
			break
		if s.state != Sim.FIGHTING:
			break
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)
	t.ok(landed, "reading the water and pumping does not bring a fish in")
	t.eq(s.caught, 1, "and it is counted")
	t.gt(s.total_weight, 0.0, "with a real weight")
	t.gt(float(s.pumps), 0.0, "it came in without a single pump")


## `doing_well` drives both the rules and the picture. If they can disagree the
## player is being told one thing and scored on another - the same guarantee the
## old gauge had, kept after the gauge itself was deleted.
func test_doing_well_agrees_with_what_the_rules_do(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	t.ok(not Sim.new(1).doing_well(), "a sim with no fish on reports doing well")
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		var expected := false
		match s.behaviour:
			Sim.B_RUNNING:
				expected = s.load <= Tuning.GIVE_MAX
			Sim.B_SURFACING:
				expected = Tuning.shake_ok(s.load)
			_:
				expected = s.load < Tuning.strain_start()
		t.eq(s.doing_well(), expected,
			"doing_well disagrees with the rules during %s" % s.behaviour)
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)


func test_danger_reports_the_worst_of_the_three(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	for i in int(round(10.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(1.0)
		s.advance(step)
		t.approx(s.danger(), maxf(s.strain, maxf(s.slip, s.wear)), 1e-6,
			"danger is not the worst of strain, slip and wear")
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
		s.set_pull(1.0)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "the line broke")
	_step(s, Tuning.HOLD_TIME)
	t.eq(s.state, Sim.IDLE, "and the player can cast again")


func test_casting_straight_out_of_a_loss_clears_the_last_fish(t: TestHarness) -> void:
	# A player who casts the instant a fish comes off never passes through IDLE,
	# so any cleanup that lives on that transition never runs. The golden caught
	# this as a session sitting in `waiting` with `slip: 1.0` and a species still
	# named - a state that should not be able to exist.
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	for i in int(round(25.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(0.0)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "the hook was thrown")
	t.gt(s.slip, 0.5, "and the slip that did it is still recorded")

	s.hold_cast()
	t.eq(s.state, Sim.CHARGING, "the player can cast again immediately")
	t.eq(s.fish_id, "", "the lost fish is cleared")
	t.approx(s.slip, 0.0, 1e-6, "and so is its slip")
	t.approx(s.strain, 0.0, 1e-6, "and its strain")


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
	var step := 1.0 / 120.0
	for i in int(round(40.0 / step)):
		Policies.act(Policies.ANGLER, s, step)
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


## Fish until the fish is doing a particular thing, then hand the sim back mid
## behaviour. Returns null if it never happened, so a test can assert the setup
## rather than quietly test nothing.
##
## Plays with the angler until the behaviour arrives, because a bot that loses
## the fish before it ever runs cannot set up a test about running.
func _fish_in_behaviour(want: String, seeds: Array = [1, 2, 3, 4, 5, 6, 7, 8]) -> Sim:
	var step := 1.0 / 60.0
	for seed_value in seeds:
		var s := Sim.new(seed_value)
		for i in int(round(200.0 / step)):
			if s.state == Sim.FIGHTING and s.behaviour == want:
				return s
			Policies.act(Policies.ANGLER, s, step)
			s.advance(step)
	return null
