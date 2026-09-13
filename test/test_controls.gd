extends RefCounted

## THE CONTROLS GATE, for the reel slide. Push up, crank; push down, give;
## let go, hold - asserted through the REAL handler, not assumed.
##
## The studio has shipped inverted controls in five games with the rule written
## down each time; the template's version of this file says why nothing else
## catches it: every bot drives the sim by calling the seam directly, and a
## contact sheet of a fish coming in looks the same whether the thumb went up
## or down. So this file drives `_slide_input` with real InputEventScreenTouch
## and InputEventScreenDrag events, steps `_sync_slide`, and reads what the SIM
## was asked for - the whole path from glass to `Sim.reel_want`, with the sign
## and the proportion asserted rather than restated.
##
## Off-tree, like the template's: `accept_event()` is a silent no-op outside a
## tree, so the handler is reachable and only the dispatch is not.

const STEP := 1.0 / 60.0


func _game():
	var scene: PackedScene = load("res://src/game/main.tscn")
	var main = scene.instantiate()
	main.freeze(1)
	return main


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 1
	e.position = at
	e.pressed = pressed
	return e


func _drag(from: Vector2, to: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 1
	e.position = to
	e.relative = to - from
	return e


## A fight, set up directly, so the slide has a sim to talk to.
func _fighting(main) -> void:
	main.sim.state = Sim.FIGHTING
	main.sim.fish_id = "bluegill"
	main.sim.fish_distance = 8.0
	main.sim.cast_distance = 10.0
	main.sim.fish_stamina = 1.0
	main.sim.tension = Tuning.SAFE_LO


func test_pushing_the_slide_up_cranks_and_down_gives(t: TestHarness) -> void:
	var main = _game()
	_fighting(main)
	var land := Vector2(900.0, 2000.0)
	main._slide_input(_touch(land, true))
	main._slide_input(_drag(land, land + Vector2(0.0, -main.SLIDE_UP)))
	main._sync_slide(STEP)
	t.gt(main.sim.reel_want, 0.9,
		"a full push UP asked the reel for %.2f - up is not crank, or the travel is wrong" % main.sim.reel_want)
	main._slide_input(_drag(land, land + Vector2(0.0, main.SLIDE_DOWN)))
	main._sync_slide(STEP)
	t.lt(main.sim.reel_want, -0.9,
		"a full pull DOWN asked the reel for %.2f - down is not give" % main.sim.reel_want)
	main.free()


func test_the_slide_is_proportional_with_a_fine_low_end(t: TestHarness) -> void:
	# The whole reason the button became a slide: half a push is less than a
	# full one, and the low end is finer than linear.
	var main = _game()
	_fighting(main)
	var land := Vector2(900.0, 2000.0)
	main._slide_input(_touch(land, true))
	var asks: Array[float] = []
	for frac in [0.25, 0.5, 0.75, 1.0]:
		main._slide_input(_drag(land, land + Vector2(0.0, -main.SLIDE_UP * frac)))
		main._sync_slide(STEP)
		asks.append(main.sim.reel_want)
	for i in range(1, asks.size()):
		t.gt(asks[i], asks[i - 1],
			"pushing further (%.0f%%) asked for %.2f, no more than %.2f - the slide is not progressive" % [
				[0.25, 0.5, 0.75, 1.0][i] * 100.0, asks[i], asks[i - 1]])
	t.lt(asks[1], 0.5,
		"half a push asks for %.2f of the crank - the low end is linear or worse, so nothing is fine" % asks[1])
	# And a resting thumb is not an instruction.
	main._slide_input(_drag(land, land + Vector2(0.0, -main.SLIDE_UP * main.SLIDE_DEAD * 0.5)))
	main._sync_slide(STEP)
	t.approx(main.sim.reel_want, 0.0, 1e-6,
		"a thumb resting inside the dead zone asked for %.3f" % main.sim.reel_want)
	main.free()


func test_letting_go_holds_and_the_knob_springs_home_without_a_step(t: TestHarness) -> void:
	var main = _game()
	_fighting(main)
	var land := Vector2(900.0, 2000.0)
	main._slide_input(_touch(land, true))
	main._slide_input(_drag(land, land + Vector2(0.0, -main.SLIDE_UP)))
	main._sync_slide(STEP)
	t.gt(main.sim.reel_want, 0.9, "the push did not take")
	main._slide_input(_touch(land + Vector2(0.0, -main.SLIDE_UP), false))
	main._sync_slide(STEP)
	t.approx(main.sim.reel_want, 0.0, 1e-6,
		"letting go left the reel asking for %.2f - the slide does not spring home to HOLD" % main.sim.reel_want)
	# The knob comes home on the spring: no single-frame jump in its speed, and
	# home within a reaction time.
	var worst := 0.0
	var prev_v := 0.0
	var prev_p: float = main._slide_pos
	var frames := 0
	while absf(main._slide_pos) > 0.01 and frames < 60:
		main._sync_slide(STEP)
		var v: float = (main._slide_pos - prev_p) / STEP
		if frames > 0:
			worst = maxf(worst, absf(v - prev_v))
		prev_v = v
		prev_p = main._slide_pos
		frames += 1
	t.lt(float(frames), 30.0, "the knob took %d frames to come home - a slow lever, not a spring" % frames)
	t.lt(worst, main.SLIDE_ACCEL_MAX * STEP * 1.5,
		"the knob's speed stepped by %.1f in one frame on the way home - a snap, not a spring" % worst)
	main.free()


func test_the_bot_asks_for_the_pixel_the_handler_needs(t: TestHarness) -> void:
	# The round trip, as a property: the offset `slide_offset_for` gives for an
	# amount, pushed through the real handler, asks the sim for that amount.
	# A test that restated the curve would pass with it wrong in both places.
	var main = _game()
	_fighting(main)
	var land := Vector2(900.0, 2000.0)
	main._slide_input(_touch(land, true))
	for amount in [0.3, 0.7, 1.0, -0.4, -1.0]:
		var off: float = main.slide_offset_for(amount)
		main._slide_input(_drag(land, land + Vector2(0.0, -off)))
		main._sync_slide(STEP)
		t.approx(main.sim.reel_want, amount, 0.02,
			"the bot's pixel for %.2f produced %.3f through the handler - the inversion and the curve disagree" % [
				amount, main.sim.reel_want])
	main.free()
