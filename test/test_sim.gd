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


func test_hooking_starts_the_fight_inside_the_band(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	t.ok(s.in_band(), "the fight opens with the tension where it should be")
	t.approx(s.stress, 0.0, 1e-6, "no stress on the line yet")
	t.approx(s.slip, 0.0, 1e-6, "and no slip")
	t.gt(s.fish_distance, 0.0, "the fish starts away from the boat")


func test_holding_the_thumb_flat_out_breaks_the_line(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(1.0)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "the fight ends")
	t.eq(s.caught, 0, "and not with a fish")


func test_no_thumb_at_all_throws_the_hook(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	for i in int(round(20.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(0.0)
		s.advance(step)
	t.eq(s.state, Sim.LOST, "the fight ends")
	t.eq(s.caught, 0, "and not with a fish")


func test_tracking_the_band_lands_the_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0
	var landed := false
	for i in int(round(60.0 / step)):
		if s.state == Sim.HOLDING:
			landed = true
			break
		if s.state != Sim.FIGHTING:
			break
		Policies.act(Policies.ANGLER, s, step)
		s.advance(step)
	t.ok(landed, "playing it properly brings it in")
	t.eq(s.caught, 1, "and it is counted")
	t.gt(s.total_weight, 0.0, "with a real weight")


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
	t.approx(s.stress, 0.0, 1e-6, "and its stress")


func test_reeling_in_always_gets_out_of_a_dead_cast(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.hold_cast()
	s.release_cast()
	t.ok(_drive_to(s, Sim.WAITING), "the lure reaches fishing depth")
	s.reel_in()
	t.eq(s.state, Sim.IDLE, "winding in returns to the boat")
	t.approx(s.lure_depth, 0.0, 1e-6, "and the lure comes back up")


func test_the_band_the_hud_draws_is_the_band_the_rules_use(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var b := s.band()
	var w: float = Species.by_id(s.fish_id)["band"]
	t.approx(b[0], Tuning.band_lo(w), 1e-6, "the drawn bottom is the real bottom")
	t.approx(b[1], Tuning.band_hi(w), 1e-6, "the drawn top is the real top")
	# in_band() must agree with the numbers it hands the HUD, or the player is
	# told one thing and scored on another.
	t.eq(s.in_band(), s.tension >= b[0] and s.tension <= b[1],
		"in_band agrees with the band it reports")


func test_band_is_safe_to_ask_for_with_no_fish_on(t: TestHarness) -> void:
	# The HUD asks every frame, including the frames where nothing is hooked.
	var s := Sim.new(1)
	var b := s.band()
	t.eq(b.size(), 2, "a band is always two numbers")
	t.gt(b[1], b[0], "and the top is above the bottom")


func test_the_fish_tires_only_while_the_tension_is_right(t: TestHarness) -> void:
	# A fight OPENS with the tension inside the band, so a fish tires for the
	# fraction of a second it takes a slack line to fall out of it. The claim
	# worth asserting is not "no tiring ever" but "no tiring once the line is
	# actually slack" - measured after the tension has left the band, not from
	# the instant of the hook.
	var s := Sim.new(1)
	t.ok(_drive_to(s, Sim.FIGHTING), "a fish can be hooked")
	var step := 1.0 / 60.0

	# Let it go slack first.
	for i in int(round(1.0 / step)):
		if s.state != Sim.FIGHTING or not s.in_band():
			break
		s.set_pull(0.0)
		s.advance(step)
	t.ok(not s.in_band(), "a slack line leaves the band")

	var start := s.fish_stamina
	for i in int(round(1.5 / step)):
		if s.state != Sim.FIGHTING:
			break
		s.set_pull(0.0)
		s.advance(step)
	t.approx(s.fish_stamina, start, 1e-6, "a slack line does not tire a fish")


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
