extends SceneTree

## Smoke test: boots the real scene and plays it.
##
##   godot --headless --script res://test/run_smoke.gd
##
## The pure tests in run_tests.gd cannot see a wiring bug - a scene that fails
## to build, a node that is never added, a HUD reading a field that no longer
## exists, a control that stopped handling its own input. Those only show up
## when something actually instantiates the game.

var _t := TestHarness.new()


func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	_t.begin("smoke > the scene loads")
	_t.ok(scene != null, "main.tscn failed to load")
	if scene == null:
		_finish()
		return

	var main = scene.instantiate()
	root.add_child(main)

	# Freeze first, then step. Two reasons, and the second is not obvious: real
	# frames run between a scene loading and a harness taking over, so without
	# this every number would move with the speed of the machine - and `_ready`
	# has not fired yet either, because add_child() during
	# SceneTree._initialize() defers it to the first processed frame. freeze()
	# boots the scene explicitly, which is why the assertions come after it.
	main.freeze(1)

	_t.begin("smoke > the scene builds its world")
	_t.ok(main.sim != null, "Sim was never created")
	_t.ok(main.get_node_or_null("Water") != null, "the water is missing from the scene")
	_t.ok(main.get_node_or_null("Boat") != null, "the boat is missing from the scene")
	_t.ok(main.get_node_or_null("Boat/Rod") != null, "the rod is missing from the boat")
	_t.ok(main.get_node_or_null("Float") != null, "the float is missing from the scene")
	_t.ok(main.get_node_or_null("Fish") != null, "the fish is missing from the scene")

	_check_a_whole_fish_can_be_caught_through_the_real_scene(main)
	_check_the_line_always_comes_back(main)
	_check_the_gauge_draws_the_rules(main)
	_check_the_controls_are_anchored(main)
	_check_the_lure_is_where_the_line_ends(main)

	_finish()


## A fish, caught end to end, through the scene and through the input seam a
## thumb uses. This is the assertion that the game is playable at all.
func _check_a_whole_fish_can_be_caught_through_the_real_scene(main) -> void:
	_t.begin("smoke > a fish can be caught through the real scene")
	main.freeze(1)
	main.play(Policies.ANGLER, 120.0)
	_t.gt(float(main.sim.caught), 0.0,
		"two minutes of correct play landed nothing - the loop is broken somewhere in the scene")
	_t.gt(main.sim.total_weight, 0.0, "a fish was counted but weighs nothing")
	_t.gt(float(main.sim.casts), 0.0, "nothing was ever cast")


## The way OUT of every state.
##
## A game built from an earlier version of this template emitted a
## level-finished signal with nothing connected to it, sat frozen with a live
## HUD, and read to the person holding the phone as a crash. Every test in that
## suite played a level and read the state at the END, which is the exact
## instant the freeze began - the suite was not weak, it was uniform.
##
## The equivalent here is a line that is out with no fish and no way back. So
## this drives THROUGH each terminal state rather than stopping at it.
func _check_the_line_always_comes_back(main) -> void:
	_t.begin("smoke > a landed fish returns the player to the boat")
	main.freeze(1)
	var reached_hold := _drive_until(main, Sim.HOLDING, 180.0)
	_t.ok(reached_hold, "no fish was ever landed to check the way out of")
	if reached_hold:
		main.advance(Tuning.HOLD_TIME + 0.5)
		_t.eq(main.sim.state, Sim.IDLE, "the hold never ends - this is the bug that shipped")
		_t.eq(main.sim.fish_id, "", "the fish is still on the line after being landed")
		# And it has to actually play on the other side.
		main.play(Policies.ANGLER, 3.0)
		_t.ok(main.sim.state != Sim.IDLE, "the next cast does not start when the frame loop runs")

	_t.begin("smoke > a lost fish returns the player to the boat")
	main.freeze(2)
	var reached_fight := _drive_until(main, Sim.FIGHTING, 180.0)
	_t.ok(reached_fight, "no fish was ever hooked to lose")
	if reached_fight:
		# Break it off deliberately, through the same seam a thumb uses.
		var step := 1.0 / 60.0
		for i in int(round(25.0 / step)):
			if main.sim.state != Sim.FIGHTING:
				break
			main.sim.set_pull(1.0)
			main.advance(step, step)
		_t.eq(main.sim.state, Sim.LOST, "holding the thumb flat out never ends the fight")
		main.advance(Tuning.HOLD_TIME + 0.5)
		_t.eq(main.sim.state, Sim.IDLE, "a lost fish leaves the player stuck")


## The gauge must draw the numbers the rules use, not its own copy of them.
##
## Any time a control shows a thing the simulation also uses, a copy is a second
## source of truth that will drift - usually within one session. Coreward's shop
## solved the same problem by reparenting the real ship instead of building a
## preview of it.
func _check_the_gauge_draws_the_rules(main) -> void:
	_t.begin("smoke > the gauge draws the same band the rules use")
	main.freeze(1)
	if not _drive_until(main, Sim.FIGHTING, 180.0):
		_t.ok(false, "no fish was hooked to check the gauge against")
		return
	var b: Array = main.sim.band()
	var w: float = Species.by_id(main.sim.fish_id)["band"]
	_t.approx(b[0], Tuning.band_lo(w), 1e-6, "the band the HUD is handed is not the real one")
	_t.approx(b[1], Tuning.band_hi(w), 1e-6, "the band the HUD is handed is not the real one")
	_t.eq(main.sim.in_band(), main.sim.tension >= b[0] and main.sim.tension <= b[1],
		"in_band disagrees with the band it reports")


## The controls must be ANCHORED to the viewport, never placed at a literal
## coordinate.
##
## A structural assertion rather than a behavioural one, because the bug it
## guards against is invisible at the size the tests run. The project stretches
## with `aspect = "expand"`, which keeps the base WIDTH and extends the HEIGHT -
## so on a 19.5:9 phone the canvas is about 1080x2340 while the base is
## 1080x1920. Controls laid out against the literal 1920 drew hundreds of pixels
## above where they belonged, and the report was "the icons are about half an
## inch too high".
##
## **A headless run uses the base size, where the wrong layout and the right one
## are identical** - so no screenshot or coordinate check taken here could ever
## catch it. What CAN be checked is the property that makes it impossible.
func _check_the_controls_are_anchored(main) -> void:
	_t.begin("smoke > the controls are anchored, not placed")
	var g: Control = main._gauge
	_t.eq(g.anchor_bottom, 1.0,
		"the gauge is not anchored to the bottom of the viewport - it will drift on a tall screen")
	_t.eq(g.anchor_top, 1.0,
		"the gauge is anchored to the TOP, so its distance from the bottom follows the aspect ratio")
	_t.eq(g.anchor_right, 1.0, "the gauge is not anchored to the right edge")
	_t.lt(g.offset_bottom, 0.0,
		"the gauge is offset downward from its anchor and will sit off the bottom of the screen")
	_t.lt(g.offset_right, 0.0, "the gauge is offset off the right edge of the screen")
	_t.ok(g.gui_input.get_connections().size() > 0,
		"the gauge does not handle its own input, so its hit box is a second source of truth")
	_t.eq(g.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the gauge does not consume its own touches, so one gesture drives two things")

	var cast_area: Control = main._cast_area
	_t.eq(cast_area.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the cast area does not consume its touches")
	_t.ok(cast_area.gui_input.get_connections().size() > 0,
		"the cast area does not handle its own input")
	# Child order is what makes the gauge win inside its own rectangle. If the
	# cast area is drawn later it swallows every touch and the fight becomes
	# unplayable, which no coordinate check would show.
	_t.lt(float(cast_area.get_index()), float(g.get_index()),
		"the cast area sits above the gauge and will swallow the fight's touches")


## The float and the end of the line must be the same point.
##
## They are computed from one function for exactly this reason, and the check is
## here because "the line ends somewhere the float is not" is the sort of thing
## that looks fine in a still and wrong in motion.
func _check_the_lure_is_where_the_line_ends(main) -> void:
	_t.begin("smoke > the line ends at the float")
	main.freeze(1)
	if not _drive_until(main, Sim.FIGHTING, 180.0):
		_t.ok(false, "no fish was hooked to check the line against")
		return
	var lure: Vector3 = main._lure_position()
	_t.approx(main._float.position.distance_to(lure), 0.0, 1e-4,
		"the float is not at the lure position the line was drawn to")
	_t.ok(main._float.visible, "the float is not visible during a fight")
	_t.ok(main._line.visible, "the line is not visible during a fight")


## Play, through the real input seam, until a state is reached or time runs out.
func _drive_until(main, want: String, limit: float) -> bool:
	var step := 1.0 / 60.0
	for i in int(round(limit / step)):
		if main.sim.state == want:
			return true
		Policies.act(Policies.ANGLER, main.sim, step)
		main.advance(step, step)
	return main.sim.state == want


func _finish() -> void:
	print("")
	if _t.failures.is_empty():
		print("  smoke: %d assertions, all passing" % _t.checks)
		quit(0)
		return
	for f in _t.failures:
		print("  FAIL  %s" % f)
	print("")
	print("  smoke: %d assertions, %d FAILED" % [_t.checks, _t.failures.size()])
	quit(1)
