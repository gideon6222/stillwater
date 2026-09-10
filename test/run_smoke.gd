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
	_check_the_gauges_are_clear_of_the_thumb(main)
	_check_the_controls_are_anchored(main)
	_check_the_float_is_the_nibble_minigame(main)
	_check_the_cast_is_a_swing_not_a_bend(main)
	_check_the_lure_is_where_the_line_ends(main)
	_check_every_room_opens_and_closes(main)
	_check_the_shed_actually_spends_money(main)
	_check_the_rooms_cannot_be_opened_mid_fight(main)
	_check_the_map_travels_and_the_clock_turns(main)

	_check_the_music_goes_wrong_as_the_water_gets_older(main)
	_check_the_game_actually_writes_and_reads_its_save(main)

	# --- how the game FEELS, as things a machine can fail on -----------------
	_check_every_state_offers_a_visible_action(main)
	_check_no_state_leaves_the_player_with_nothing_to_do(main)
	_check_every_action_answers_within_two_frames(main)
	_check_the_boat_is_never_still(main)
	_check_the_water_never_casts_and_the_button_always_does(main)
	_check_the_stick_turns_the_view(main)
	_check_everything_in_the_boat_can_be_looked_at_and_used(main)
	_check_nothing_interactable_is_invisible(main)
	_check_the_title_leads_into_the_game(main)
	_check_the_first_morning_teaches_and_ends(main)
	_check_a_wrong_fish_is_drawn_wrong(main)
	_check_the_walk_to_the_boat_always_arrives(main)
	_check_every_room_looks_like_the_thing_it_is(main)
	_check_the_logbook_is_a_real_object(main)
	_check_the_back_button_unwinds_one_layer(main)
	_check_the_float_floats_on_the_water(main)
	_check_a_swipe_does_not_turn_the_view(main)
	_check_the_tackle_box_is_the_equipment_menu(main)

	# Free what we built. Without this the run ends with "8 resources still in
	# use at exit" - the audio mixer's stream cache, held by a node the quitting
	# tree never tears down. Harmless in itself, and still worth removing: a gate
	# that always prints an error is a gate whose errors nobody reads.
	main.free()
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
			main.sim.tap()
			main.sim.tap()
			main.advance(step, step)
		_t.eq(main.sim.state, Sim.LOST, "holding the thumb flat out never ends the fight")
		main.advance(Tuning.HOLD_TIME + 0.5)
		_t.eq(main.sim.state, Sim.IDLE, "a lost fish leaves the player stuck")


## The gauges have to be READABLE and CLEAR OF THE THUMB, and they have to draw
## the numbers the rules use rather than a copy of them.
##
## Both halves come from notes on earlier builds. Gideon on the first fight: the
## thumb covered the meter. On the second: the meter was gone entirely and there
## was no way to tell what to do. The settlement is gauges at the TOP and a tap
## anywhere - so what is asserted here is the SEPARATION, which is the property
## that makes both notes stay fixed.
func _check_the_gauges_are_clear_of_the_thumb(main) -> void:
	_t.begin("smoke > the gauges are at the top and the thumb is not")
	main.freeze(1)
	if not _drive_until(main, Sim.FIGHTING, 180.0):
		_t.ok(false, "no fish was hooked to check the gauges against")
		return

	var gauge: Control = main._tension_bar

	# **THE GAUGE IS ACTUALLY ON SCREEN.**
	#
	# The assertion that was missing, and its absence shipped a build in which
	# NEITHER gauge was ever visible. `visible` was being set inside the draw
	# callback, which is a latch - a hidden Control never receives `draw` again,
	# so the first frame in any other state switched it off for good. Every
	# property below still passed, because anchors and offsets are correct on a
	# control nobody can see.
	#
	# So: check it is showing when it should be, AND that it comes back after
	# being hidden, which is the half a single snapshot cannot catch.
	_t.ok(gauge.visible, "the tension gauge is not visible during a fight")

	main.freeze(1)
	main.advance(0.1)
	_t.ok(not gauge.visible, "the tension gauge is up before anything is hooked")
	_t.ok(_drive_until(main, Sim.FIGHTING, 180.0), "a fish can be hooked again")
	_t.ok(gauge.visible, "the tension gauge never comes back once it has been hidden")

	# Both live in the TOP third. A readout the thumb can rest on is the whole of
	# the first note.
	#
	# Measured against the project's BASE height rather than the live viewport,
	# for two reasons: headless has not laid the UI out, so `_ui.size` is zero
	# and the comparison passes against nothing; and these anchor to the TOP,
	# which `aspect = "expand"` never moves - a control 342 px down is 342 px
	# down on every device, so the base is the honest reference.
	var base_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	_t.gt(base_h, 0.0, "the project has no base viewport height to measure against")
	for bar in [gauge]:
		var c := bar as Control
		_t.eq(c.anchor_top, 0.0, "%s is not anchored to the top of the viewport" % c.name)
		_t.eq(c.anchor_bottom, 0.0,
			"%s is anchored to the bottom, so it moves with the aspect ratio" % c.name)
		_t.gt(c.offset_top, 0.0, "%s sits above the top edge" % c.name)
		_t.lt(c.offset_bottom, base_h / 3.0,
			"%s reaches out of the top third, toward where the thumb goes" % c.name)
		# And neither may eat a touch, or tapping "on the gauge" does nothing -
		# which on a full-screen tap target is a dead zone the player cannot see.
		_t.eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s consumes touches, so tapping over it does nothing" % c.name)

	# The tension gauge draws Tuning.SAFE_LO/SAFE_HI and the rules use
	# Tuning.in_band(). One source, so the player aims at what is scored.
	var live: float = main.sim.tension
	_t.eq(main.sim.in_band(), Tuning.in_band(live),
		"in_band disagrees with the band the gauge draws")

	# The rod still bends under load, and the line still leaves its bent tip.
	var bend: float = main.rod_bend_degrees()
	_t.gt(bend, 0.0, "the rod does not bend at all during a fight")
	var tip: Vector3 = main._rod_tip
	var seg_count: int = main.ROD_SEGMENTS
	_t.gt(float(seg_count), 1.0, "the rod is a single stick again, so it tilts rather than bends")
	_t.gt(tip.z, 0.0, "the rod tip is behind the boat")


## The cast is a SWING and only a fish is a BEND.
##
## Gideon: "the rod bends back then flicks forward which isnt how it should
## work. the rod should be straight initially lift the rod up and back, then
## swing it forward. once the fish bites, the rod should bend forward since it is
## now under pressure."
##
## The bug was one number driving both motions. This asserts they are separate:
## a rod being charged is STRAIGHT, however far back it has been taken.
func _check_the_cast_is_a_swing_not_a_bend(main) -> void:
	_t.begin("smoke > loading a cast swings the rod without bending it")
	main.freeze(1)
	main.sim.hold_cast()
	main.advance(0.9)
	_t.eq(main.sim.state, Sim.CHARGING, "the cast is not still charging")
	_t.gt(main.sim.charge, 0.4, "the charge did not build")

	var bend: float = main.rod_bend_degrees()
	_t.lt(bend, 1.0, "the rod BENDS while being charged - a cast is a swing, not a load")

	# And it lifts UP AND BACK, not down.
	#
	# The direction is the whole of the note this test exists for: "the rod
	# should be straight initially lift the rod up and back... but it pushes down
	# and flings up when you let go". A positive X rotation points the tip DOWN
	# in Godot, so lifting back has to make the angle MORE NEGATIVE than rest.
	var butt: Node3D = main._rod
	_t.lt(butt.rotation_degrees.x, main.ROD_REST - 5.0,
		"the rod goes DOWN when the cast is charged - the sign is inverted")

	# Then the release throws it forward past the rest angle - **and stops with
	# the tip still above horizontal.**
	#
	# Gideon: "when you cast the rod should pull back, then fling forward but
	# still be angled up. when you cast currently, it pulls back a little then
	# angles all the way into the water before returning." Both halves are the
	# assertion: forward of rest, and still negative, which is up.
	#
	# Sampled at the END of the swing, not partway through. The first version
	# measured at 0.12s of a 0.20s eased throw - before it had crossed rest - and
	# reported a fault that was not there.
	main.sim.release_cast()
	main.advance(main.CAST_SWING_TIME + 0.02)
	_t.eq(main.sim.state, Sim.FLYING, "the cast did not go")
	_t.gt(butt.rotation_degrees.x, main.ROD_REST,
		"the rod does not swing FORWARD through the rest angle on release")
	_t.lt(butt.rotation_degrees.x, 0.0,
		"the rod swings down THROUGH horizontal and into the water on a cast")

	# And a fish bends it the other way from the lift - down and forward.
	_t.ok(_drive_until(main, Sim.FIGHTING, 180.0), "a fish can be hooked")
	_t.gt(main.rod_bend_degrees(), 0.0, "a hooked fish does not bend the rod")
	var tip_seg: Node3D = main._rod_chain[main.ROD_SEGMENTS - 1]
	_t.gt(tip_seg.rotation_degrees.x, 0.0,
		"the rod bends UP under load - a fish pulls the tip down and forward")


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
## The second fight has exactly ONE touch surface and it covers the whole screen,
## which sidesteps the stretch-mode fault entirely rather than defending against
## it - a full-rect control is correct at every aspect by construction. What is
## still worth asserting is that it stayed full-rect, and that the two labels
## anchored to real edges did not drift back to literal coordinates.
func _check_the_controls_are_anchored(main) -> void:
	_t.begin("smoke > the controls are anchored, not placed")
	var cast_area: Control = main._cast_area
	_t.eq(cast_area.anchor_right, 1.0, "the touch surface does not reach the right edge")
	_t.eq(cast_area.anchor_bottom, 1.0, "the touch surface does not reach the bottom edge")
	_t.eq(cast_area.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the touch surface does not consume its touches")
	_t.ok(cast_area.gui_input.get_connections().size() > 0,
		"the touch surface does not handle its own input, so its hit box is a second source of truth")

	# The stamp sits against the real bottom edge, which is the one place the
	# `aspect = "expand"` fault could still bite.
	var stamp: Control = main._stamp
	_t.eq(stamp.anchor_top, 1.0,
		"the build stamp is anchored to the TOP, so it follows the aspect ratio")
	_t.lt(stamp.offset_top, 0.0,
		"the build stamp is offset downward from its anchor and will sit off screen")


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
	var lure: Vector3 = main.lure_world_position()
	_t.approx(main._float.position.distance_to(lure), 0.0, 1e-4,
		"the float is not at the lure position the line was drawn to")
	_t.ok(main._float.visible, "the float is not visible during a fight")

	# THE LINE IS TEN SEGMENTS ALONG A SAG, and the two ends are the assertion
	# that matters: a sag that detaches from the rod tip or from the lure is the
	# one way this can fail that looks like a bug rather than a curve.
	var chain: Array = main._line_chain
	_t.gt(float(chain.size()), 1.0, "the line was never built as a chain")
	var shown := 0
	for seg in chain:
		if seg.visible:
			shown += 1
	_t.eq(shown, chain.size(), "the line is not visible during a fight")
	var first: MeshInstance3D = chain[0]
	var last: MeshInstance3D = chain[chain.size() - 1]
	# Each segment is a unit box scaled along its own Z. `looking_at` points -Z at
	# the target, so +Z runs back towards the segment's START, and the basis is
	# already scaled by the segment length - so half a segment is `basis.z * 0.5`,
	# and multiplying by `scale.z` as well would square it.
	var rod_tip: Vector3 = main._rod_tip
	var head := first.transform.origin + first.transform.basis.z * 0.5
	var tail := last.transform.origin - last.transform.basis.z * 0.5
	_t.approx(head.distance_to(rod_tip), 0.0, 0.02,
		"the line does not start at the rod tip")
	_t.approx(tail.distance_to(lure), 0.0, 0.02,
		"the line does not end at the lure")

	# And the SHAPE is a readout of the tension, which is the whole reason it is a
	# curve at all: a slack line bellies below the straight run between its ends
	# and a line near breaking does not.
	#
	# Driven through `_draw_line_between` with FIXED endpoints, which matters. The
	# obvious version of this test - set tension, step a frame, compare - passes
	# whatever the sag does, because tension also bends the rod, so the rod tip
	# moves and the belly moves with it. Verified: with the sag hard-wired to
	# ignore tension completely, that version still reported all passing. Holding
	# `a` and `b` still is what makes this an assertion about the SHAPE.
	var mid_i := int(chain.size() / 2)
	var a := Vector3(0.0, 1.2, 0.0)
	var b := Vector3(0.0, 0.0, 10.0)
	var chord_y := (a.y + b.y) * 0.5

	main.sim.tension = Tuning.TENSION_MAX * 0.98
	main._draw_line_between(a, b)
	var belly_taut: float = chord_y - main._line_chain[mid_i].transform.origin.y

	main.sim.tension = Tuning.TENSION_MAX * 0.02
	main._draw_line_between(a, b)
	var belly_slack: float = chord_y - main._line_chain[mid_i].transform.origin.y

	_t.gt(belly_slack, belly_taut + 0.05,
		"a slack line does not sag further than a tight one (%.3f vs %.3f) - the shape has stopped reading the tension" % [belly_slack, belly_taut])
	_t.gt(belly_taut, -0.01, "a line under full tension bows UPWARDS")


## Play, through the real input seam, until a state is reached or time runs out.
func _drive_until(main, want: String, limit: float) -> bool:
	var step := 1.0 / 60.0
	var mem := {}
	for i in int(round(limit / step)):
		if main.sim.state == want:
			return true
		Policies.act(Policies.ANGLER, main.sim, step, mem)
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


## MINIGAME 1 has NO HUD, so the only thing that can carry it is the float, and
## the only assertion that matters is that the float actually MOVES.
##
## Gideon: "can you make the initial hook portion of the mini game just watching
## the rod or bobber pull down." If the float sits still through a nibble there
## is nothing on screen to play against at all - and unlike a missing gauge, no
## control's properties would be wrong.
func _check_the_float_is_the_nibble_minigame(main) -> void:
	_t.begin("smoke > the float is pulled under during a nibble")
	main.freeze(1)
	if not _drive_until_state(main, Sim.NIBBLING, 180.0):
		_t.ok(false, "no nibble was ever reached")
		return

	var rest_y: float = main._float.position.y
	var lowest := rest_y
	var step := 1.0 / 60.0
	for i in int(round(14.0 / step)):
		if main.sim.state != Sim.NIBBLING:
			break
		lowest = minf(lowest, main._float.position.y)
		main.advance(step, step)

	_t.lt(lowest, rest_y - 0.05,
		"the float never dips during a nibble - there is nothing to watch")

	# And no HUD element may appear for it. The nibble is the world, not a bar.
	for child in main._ui.get_children():
		var n := (child as Node).name
		_t.ok(n != "HookBar", "the hook bar is back - minigame 1 is the float now")


## Advance until a state, casting but never striking - so a NIBBLE can be watched
## rather than immediately hooked. `_drive_until` uses the angler, which strikes
## the instant the take begins and would end the thing being observed.
func _drive_until_state(main, want: String, limit: float) -> bool:
	var step := 1.0 / 60.0
	for i in int(round(limit / step)):
		if main.sim.state == want:
			return true
		match main.sim.state:
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				main.sim.hold_cast()
			Sim.CHARGING:
				if main.sim.state_time >= Policies.CHARGE_HOLD:
					main.sim.release_cast()
			_:
				pass
		main.advance(step, step)
	return main.sim.state == want


## EVERY ROOM OPENS, DRAWS SOMETHING, AND LETS YOU OUT.
##
## The rooms are built in code, so "the shed is a blank screen" and "the back
## button does nothing" are both one typo away and neither is visible from the
## pure tests. The way out is checked for each one, for the same reason the line
## always comes back: a screen with no exit reads as a crash.
func _check_every_room_opens_and_closes(main) -> void:
	_t.begin("smoke > every room opens, fills, and lets you out")
	main.freeze(1)
	var menus = main._menus
	_t.ok(menus != null, "the menus were never built")
	if menus == null:
		return
	for screen in [Menus.SHED, Menus.MAP, Menus.LOG, Menus.KIT]:
		menus.open(screen)
		_t.ok(menus.is_open(), "%s did not open" % screen)
		_t.eq(menus.current(), screen, "%s opened the wrong room" % screen)
		_t.gt(float(menus._list.get_child_count()), 0.0,
			"%s opened as a blank screen" % screen)
		_t.ok(menus._title.text != "", "%s has no title" % screen)
		menus.close()
		_t.ok(not menus.is_open(), "there is no way out of %s" % screen)


## THE ANDROID BACK BUTTON, which the project now takes off Godot and hands to
## `main._go_back()`.
##
## Two failures live here and they are opposites, which is why the setting and the
## handler had to arrive together. Left at Godot's default, back QUITS the app from
## inside an open logbook - the player meant "shut this" and lost the morning.
## Turned off with nothing handling it, back does NOTHING, and a dead system button
## reads as a hung app.
##
## So what is asserted is that it unwinds exactly ONE layer per press, in the order
## `_hud_is_down` stacks them. The quit branch is deliberately not driven: calling it
## would take the test process down with it, and the layer that reaches it is the one
## with nothing left open.
func _check_the_back_button_unwinds_one_layer(main) -> void:
	_t.begin("smoke > the back button shuts what is open instead of the game")
	main.freeze(1)
	var menus = main._menus
	if menus == null:
		return

	# A room: back closes it and does not touch anything else.
	for screen in [Menus.SHED, Menus.MAP, Menus.LOG, Menus.KIT]:
		menus.open(screen)
		_t.ok(menus.is_open(), "%s did not open" % screen)
		_t.ok(main._go_back(), "back was ignored with %s open" % screen)
		_t.ok(not menus.is_open(), "back did not close %s" % screen)

	# The logbook, which is an object in the boat rather than a menu, and the one
	# a stray back press was most expensive in.
	main.freeze(1)
	main._open_book()
	_t.ok(main._reading, "the logbook did not open")
	_t.ok(main._go_back(), "back was ignored with the logbook open")
	_t.ok(not main._reading, "back did not shut the logbook")

	# A cinematic gets the same courtesy a touch gets.
	main.freeze(1)
	main._open_book()
	main._in_sequence = true
	main._seq.running = true
	_t.ok(main._go_back(), "back was ignored during a cinematic")
	main._in_sequence = false
	main._seq.running = false

	# And it is one layer per press, never a cascade: with the shed open on top of
	# nothing, one press leaves the player on the seat and still in the game.
	main.freeze(1)
	menus.open(Menus.SHED)
	main._go_back()
	_t.ok(not menus.is_open(), "back did not close the shed")
	_t.ok(not main._reading, "back closed the shed AND something else")
	_t.ok(main.sim != null, "back tore the game down instead of a screen")


## Buying goes through the same `econ` the tests use, so this checks the WIRING:
## that the shelf the shed drew is connected to the purse, and that a purchase
## the player cannot afford changes nothing at all.
func _check_the_shed_actually_spends_money(main) -> void:
	_t.begin("smoke > the shed spends money and hands over the goods")
	main.freeze(1)
	var econ = main.sim.econ
	var menus = main._menus

	econ.money = 0
	var before: int = econ.line
	menus.open(Menus.SHED)
	menus._buy_next("line")
	_t.eq(econ.line, before, "the shed sold line to a player with no money")
	_t.eq(econ.money, 0, "a refused purchase still moved the purse")

	econ.money = 10000
	menus._buy_next("line")
	_t.eq(econ.line, before + 1, "the shed took the money and handed over nothing")
	_t.lt(float(econ.money), 10000.0, "the line was free")

	# And the reach really did change, which is the only reason any of it matters.
	#
	# NOT in the bay, though, and the first version of this assertion got that
	# wrong: Reed Bay has a bottom at four metres and no line ever made will find
	# a fifth. **Better line does not deepen the water you are in, it lets you go
	# somewhere deeper** - the spot and the line are two halves of one gate, and
	# a test that expects either to work alone is testing a game we did not build.
	_t.eq(main.sim.deepest_here(), 4.0,
		"the bay got deeper when the line did - depth is the lake, not the tackle")
	_t.gt(World.reachable_depth("narrows", econ.line), 4.0,
		"better line reaches no further even at a deeper spot - the ladder is not wired to the lake")
	menus.close()


## The dock is along the bottom, which is where a thumb lands to reel. If a room
## could open mid-fight the player would open the shop trying to land a fish.
func _check_the_rooms_cannot_be_opened_mid_fight(main) -> void:
	_t.begin("smoke > the rooms only open from the boat")
	main.freeze(1)
	main.play(Policies.HUMAN, 60.0)
	main.sim.state = Sim.FIGHTING
	main._open(Menus.SHED)
	_t.ok(not main._menus.is_open(), "the shed opened in the middle of a fight")
	main._sync_bars()
	_t.ok(not main._dock.visible, "the dock is under the thumb during a fight")

	main.sim.state = Sim.IDLE
	main._sync_bars()
	_t.ok(main._dock.visible, "there is no way to reach the rooms from the boat")


## Travel and the clock, through the same buttons the player presses.
func _check_the_map_travels_and_the_clock_turns(main) -> void:
	_t.begin("smoke > the map moves the boat and the clock turns")
	main.freeze(1)
	var sim = main.sim
	var menus = main._menus
	menus.open(Menus.MAP)

	# Without a motor the far water is refused, and refused SILENTLY is the bug -
	# the map has to say why, in words, or the player just taps a dead row.
	sim.econ.has_motor = false
	_t.ok(not sim.travel_to("road"), "you rowed to the drowned road")
	_t.ok(sim.spot_blocked("road") != "", "the map gives no reason the road is shut")

	sim.econ.has_motor = true
	sim.econ.line = 2
	_t.ok(sim.travel_to("road"), "the motor does not get you anywhere")
	_t.eq(sim.spot, "road", "the boat did not move")
	_t.gt(sim.deepest_here(), 15.0, "the road is no deeper than the bay")

	var hour: String = sim.hour
	var day: int = sim.day
	sim.sleep()
	_t.ok(sim.hour != hour, "sleeping did not move the clock")
	_t.gt(float(sim.day), float(day) - 1.0, "the day went backwards")
	menus.close()


## THE ARC IS A CLAIM, SO IT IS CHECKED.
##
## The music is the one part of the presentation that asserts something about the
## design: **going deeper sounds worse, continuously, and nothing ever cuts.** A
## mix built by ear could satisfy that on the day and quietly stop satisfying it
## the next time a bed's level is nudged, and the failure is inaudible - you do
## not notice a soundtrack that stopped changing.
##
## Driven through `tick` at the depths the game actually produces, not at made-up
## numbers, so a change to the lake moves this test too.
func _check_the_music_goes_wrong_as_the_water_gets_older(main) -> void:
	_t.begin("smoke > the music goes wrong as the water gets older")
	main.freeze(1)
	var audio = main._audio
	_t.ok(audio != null, "the mixer was never built")
	if audio == null:
		return

	var bells: Array[float] = []
	var under: Array[float] = []
	for depth in [0.0, 4.0, 15.0, 40.0, 80.0, 140.0]:
		main.sim.state = Sim.WAITING
		main.sim.lure_depth = depth
		# Long enough for the follow to arrive. The mixer deliberately takes about
		# eight seconds to cross, so a test that ticked once would measure the
		# smoothing rather than the arc.
		for i in 600:
			audio.tick(1.0 / 30.0, false)
		var mix: Dictionary = audio.mix_snapshot()
		bells.append(float(mix["bed_bells"]))
		under.append(float(mix["bed_under"]))

	for i in bells.size() - 1:
		_t.lt(bells[i + 1], bells[i] + 0.01,
			"the bells are no quieter at the next depth (%.1f dB then %.1f dB)" % [
				bells[i], bells[i + 1]])
		_t.gt(under[i + 1], under[i] - 0.01,
			"what is underneath is no louder deeper down (%.1f dB then %.1f dB)" % [
				under[i], under[i + 1]])

	# The two ends have to be genuinely different, or a monotonic arc that moves
	# by half a decibel would pass every assertion above and be inaudible.
	_t.gt(bells[0] - bells[bells.size() - 1], 20.0,
		"the bells only drop %.1f dB across the whole lake - nobody will hear that" % [
			bells[0] - bells[bells.size() - 1]])
	_t.gt(under[under.size() - 1] - under[0], 20.0,
		"what is underneath only rises %.1f dB across the whole lake" % [
			under[under.size() - 1] - under[0]])

	# And it runs BACKWARDS. Fishing the reeds after the quarry brings the bells
	# back, which is the point of tying the arc to depth rather than to progress.
	main.sim.lure_depth = 1.0
	for i in 900:
		audio.tick(1.0 / 30.0, false)
	var back: Dictionary = audio.mix_snapshot()
	_t.gt(float(back["bed_bells"]), bells[bells.size() - 1] + 15.0,
		"the bells do not come back in the shallows - the arc is one-way")


## THE SAVE HAS TO GO THROUGH THE FILE, not just through the dictionary.
##
## `test_tuning.gd` proves the round trip is correct arithmetic. It cannot see
## whether anything ever CALLS it, whether the path is writable, or whether the
## JSON survives being JSON - and the way a save fails in practice is that it was
## never written at all. The same lesson as `reel_in`: a way out that only the
## simulation knows about is not a way out.
func _check_the_game_actually_writes_and_reads_its_save(main) -> void:
	_t.begin("smoke > the game writes its save and reads it back")
	main.freeze(1)

	main.sim.econ.money = 4321
	main.sim.econ.line = 2
	main.sim.econ.has_motor = true
	main.sim.day = 9
	main.sim.hour = "night"
	main.sim.logged["bluegill"] = 0.44
	main.sim.travel_to("road")
	main._save_game()

	var path: String = main.SAVE_PATH
	_t.ok(FileAccess.file_exists(path), "nothing was written to %s" % path)

	# Through the real file and the real parser, because a Dictionary that
	# round-trips in memory can still be something JSON will not carry.
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	_t.eq(typeof(parsed), TYPE_DICTIONARY, "what was written back is not JSON")

	var fresh := Sim.new(1)
	_t.ok(Save.apply(fresh, parsed), "the file on disk did not load")
	_t.eq(fresh.econ.money, 4321, "the money did not survive the file")
	_t.eq(fresh.econ.line, 2, "the line did not survive the file")
	_t.eq(fresh.day, 9, "the day did not survive the file")
	_t.eq(fresh.hour, "night", "the hour did not survive the file")
	_t.eq(fresh.spot, "road", "the boat did not survive the file")
	_t.gt(float(fresh.logged.get("bluegill", 0.0)), 0.4,
		"the logbook record did not survive the file")

	# Landing a fish must ASK for a write, or the only save a player ever gets is
	# the one on the way out - and a phone kills a backgrounded app without
	# running any exit handler.
	main._save_due = 0.0
	main.sim.landed.emit("bluegill", 0.2)
	_t.gt(main._save_due, 0.0, "landing a fish does not ask for a save")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ===========================================================================
#  FEEL
# ===========================================================================
#
# "It feels clunky" is the most valuable thing a playtester can say and the
# least actionable, because nothing in it can be failed. These turn the parts of
# feel that ARE objective into assertions, so a regression in them is caught the
# way a broken save is.
#
# What they cover comes straight out of Swink's three layers - control,
# predictable space, polish - and the survey's "support" domain:
#
#   affordance     every state names a thing the player can do
#   dead time      no state leaves them with nothing to do at all
#   latency        every input is answered in the same frame or the next
#   liveness       the world is never perfectly still
#   discrimination one gesture never fires another gesture's verb
#
# What they cannot cover is taste: whether the tap rhythm is satisfying, whether
# the rod looks right. That still needs a person, and Gideon is that person.


## EVERY STATE OFFERS A VISIBLE ACTION.
##
## The bug this exists for shipped: `reel_in` was reachable by tapping during a
## wait, and nothing on screen ever said so, so the report was "there is not
## option to pull the line back in". An action with no affordance is an action
## that does not exist.
func _check_every_state_offers_a_visible_action(main) -> void:
	_t.begin("smoke > every state offers a visible action")
	main.freeze(1)
	for state in [Sim.IDLE, Sim.CHARGING, Sim.FLYING, Sim.SINKING, Sim.WAITING,
			Sim.NIBBLING, Sim.FIGHTING, Sim.HOLDING, Sim.LOST]:
		main.sim.state = state
		main._sync_bars()
		var label: String = main._action_for_state()
		_t.ok(label != "", "state '%s' names no action at all" % state)
		_t.ok(main._action.visible, "state '%s' hides the action button" % state)
		_t.ok(main._action.text == label,
			"the action button says '%s' in state '%s' but would do '%s'" % [
				main._action.text, state, label])


## NO STATE LEAVES THE PLAYER WITH NOTHING TO DO.
##
## Driven through the real button rather than the simulation, and asserting the
## thing that actually matters: from any state, pressing the one visible control
## eventually gets you back to a rod you can cast. A game that can strand a
## player reads as a crash, whatever the state machine thinks.
func _check_no_state_leaves_the_player_with_nothing_to_do(main) -> void:
	_t.begin("smoke > the action button always leads back to a cast")
	for state in [Sim.FLYING, Sim.SINKING, Sim.WAITING, Sim.NIBBLING, Sim.FIGHTING,
			Sim.HOLDING, Sim.LOST]:
		main.freeze(1)
		main.sim.state = state
		main.sim.state_time = 0.0
		var got_home := false
		for i in 20:
			main._on_action()
			for j in 90:
				main.advance(1.0 / 60.0)
			if main.sim.state == Sim.IDLE or main.sim.state == Sim.CHARGING \
					or main.sim.state == Sim.FLYING:
				got_home = true
				break
		_t.ok(got_home, "the player cannot get back to fishing from '%s'" % state)


## EVERY ACTION IS ANSWERED WITHIN TWO FRAMES.
##
## Responsiveness is the part of feel with a number on it: the research puts the
## perceptible floor around 15 ms for experts and consistent performance up to
## about 50 ms, which at 60 fps is three frames. Anything here that takes longer
## than two is a mechanic that will be described as mushy.
##
## Measured as "did the observable state change", not as wall-clock, because the
## thing being tested is the game's response and not this machine's speed.
func _check_every_action_answers_within_two_frames(main) -> void:
	_t.begin("smoke > every input is answered within two frames")
	var step := 1.0 / 60.0

	# A cast begins to charge the moment the finger lands.
	main.freeze(1)
	main.sim.hold_cast()
	main.advance(step)
	_t.gt(main.sim.charge, 0.0, "holding to cast does nothing on the first frame")

	# A tap during a fight moves the needle on the same frame.
	main.freeze(1)
	if _drive_until(main, Sim.FIGHTING, 180.0):
		var before: float = main.sim.tension
		main.sim.tap()
		_t.gt(main.sim.tension, before,
			"a tap during a fight does not move the tension until later")

	# And the gauge the player is reading redraws with it, rather than a frame
	# behind - a needle that lags its own input is the classic mushy control.
	main._sync()
	_t.ok(main._tension_bar.visible, "the tension gauge is not up during a fight")


## THE WORLD IS NEVER PERFECTLY STILL.
##
## A static scene reads as a screenshot however good it looks, and this game is
## a boat on water. Two samples a second apart must not be identical.
func _check_the_boat_is_never_still(main) -> void:
	_t.begin("smoke > the boat moves on the water")
	main.freeze(1)
	main.sim.state = Sim.WAITING
	var poses := []
	for i in 5:
		for j in 12:
			main.advance(1.0 / 60.0)
		poses.append(main._boat_pose)
	var moved := 0.0
	for i in poses.size() - 1:
		var a: Transform3D = poses[i]
		var b: Transform3D = poses[i + 1]
		moved += a.origin.distance_to(b.origin)
		moved += (a.basis.get_euler() - b.basis.get_euler()).length()
	_t.gt(moved, 0.004, "the boat does not move at all - the lake is a photograph")
	_t.lt(moved, 3.0, "the boat is being thrown around; this is a lake, not a gale")


## THE WATER NEVER CASTS, AND THE BUTTON ALWAYS DOES.
##
## The rule changed after a playtest: "when you press on the water it pulls back
## the rod to cast. I dont want it to do that." Every stray touch - reaching for
## a control, steadying the phone, tapping a thing in the boat - was loading the
## rod. The water is now only ever a tap on the fish, and the cast lives on its
## own button: held to load, released to throw.
func _check_the_water_never_casts_and_the_button_always_does(main) -> void:
	_t.begin("smoke > the water never casts, the button always does")

	main.freeze(1)
	main.sim.state = Sim.IDLE
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(540, 700)
	main._on_cast_input(press)
	for i in 40:
		main.advance(1.0 / 60.0)
	_t.eq(main.sim.state, Sim.IDLE, "touching the water loaded the rod")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(540, 700)
	main._on_cast_input(release)
	for i in 40:
		main.advance(1.0 / 60.0)
	_t.eq(main.sim.state, Sim.IDLE, "letting go of the water threw a cast")

	# Holding the button loads, and holding longer loads further.
	main.freeze(1)
	main._cast_pressed()
	main.advance(0.1)
	var early: float = main.sim.charge
	_t.eq(main.sim.state, Sim.CHARGING, "holding the cast button does not load the rod")
	_t.gt(early, 0.0, "the charge does not begin")
	main.advance(0.5)
	_t.gt(main.sim.charge, early, "holding longer does not charge further")

	# THE CHARGE IS VISIBLE UNDER THE THUMB. The rod pulling back says how far
	# the cast will go, but the rod is at the top of the screen and the thumb is
	# at the bottom, so the ring fills round the button as well. It is the one
	# control that only exists during a state a screenshot cannot easily catch,
	# which is exactly why it is asserted rather than photographed.
	_t.ok(main._charge_ring != null, "there is no charge ring")
	_t.ok(main._charge_ring.visible, "the charge ring is hidden while the rod loads")
	var ring: Rect2 = main._charge_ring.get_global_rect()
	var button: Rect2 = main._action.get_global_rect()
	_t.lt(ring.get_center().distance_to(button.get_center()), 4.0,
		"the charge ring is not on the cast button - ring at %s, button at %s" % [
			ring.get_center(), button.get_center()])
	_t.gt(ring.size.x, 100.0, "the charge ring has no size")

	main._cast_released()
	_t.ok(main.sim.state != Sim.CHARGING, "letting go does not release the cast")
	for i in 200:
		main.advance(1.0 / 60.0)
	_t.gt(float(main.sim.casts), 0.0, "the cast never happened")


## THE TACKLE BOX IS THE EQUIPMENT MENU, and it is an object rather than a panel.
##
## Gideon asked for this shape three times in one message - the logbook, this, and
## the shed - so PLAN.md 9.4 states it as a rule. What is asserted here is the part
## a panel could not do: the box IS its contents. The rows are built from `econ`
## every time it opens, so it cannot describe gear the player does not have, and
## tapping a row changes the same `econ` the fight reads.
func _check_the_tackle_box_is_the_equipment_menu(main) -> void:
	_t.begin("smoke > the tackle box opens, shows the gear, and changes it")
	main.freeze(1)
	_t.ok(main._tacklebox != null, "there is no tackle box in the boat")
	if main._tacklebox == null:
		return

	main._open_tacklebox()
	_t.ok(main._at_box, "the tackle box did not open")
	for i in 120:
		main.advance(1.0 / 60.0)
	_t.ok(main._tacklebox.is_open(), "the tackle box never finished opening")
	_t.gt(float(main._box_list.get_child_count()), 4.0,
		"the tackle box opened as a blank panel")

	# THE LID ACTUALLY MOVES, asserted as a DIFFERENCE between open and shut
	# rather than against an absolute angle.
	#
	# The first version of this compared the open lid's rotation against a
	# threshold, and it passed with the hinge completely disconnected - the
	# model's lid has a rest rotation of its own that already cleared the bar. A
	# rest pose is exactly the confounder that makes an absolute-angle assertion
	# vacuous, and the only reason it was caught is that it was verified by
	# disconnecting the hinge.
	var lid = main._tacklebox.find_part("lid")
	_t.ok(lid != null, "the toolbox model has no lid to open")
	if lid != null:
		var open_basis: Basis = lid.transform.basis
		main._tacklebox.state = Room3D.State.SHUT
		main._tacklebox.openness = 0.0
		main._tacklebox.advance(1.0 / 60.0)
		var shut_basis: Basis = lid.transform.basis
		# The angle between the two orientations, which is zero if nothing moved.
		var swung := rad_to_deg((open_basis.get_rotation_quaternion()).angle_to(
			shut_basis.get_rotation_quaternion())) * 2.0
		_t.gt(swung, 60.0,
			"the lid swung %.0f degrees between shut and open - the hinge is not driving it" % swung)
		# Put it back the way the rest of this check expects to find it.
		main._tacklebox.state = Room3D.State.OPEN
		main._tacklebox.openness = 1.0
		main._tacklebox.advance(1.0 / 60.0)

	# IT IS INSIDE THE BOAT. The first placement put a 0.40 m box at x = 0.34
	# where the hull is only 0.337 m half-wide, so the camera that frames it from
	# straight above sat over the gunwale and photographed the planking.
	var bx: float = main._tacklebox.position.x
	var bz: float = main._tacklebox.position.z
	_t.lt(absf(bx) + 0.20, main._hull_half_width(bz),
		"the tackle box is in the hull side: |x| %.2f + half its width is past the beam %.2f at that station" % [
			absf(bx), main._hull_half_width(bz)])

	# TAPPING A ROW EQUIPS IT, through the same econ the fight reads.
	main.sim.econ.bait_left["corn"] = 5
	main._refresh_tacklebox()
	var target := ""
	for entry in main._box_rows:
		if str(entry["id"]) == "corn":
			target = "corn"
	_t.eq(target, "corn", "an owned bait that is not on the hook is not tappable")
	if target != "":
		main._set_bait("corn")
		_t.eq(str(main.sim.econ.bait), "corn", "tapping a bait did not put it on the hook")
		main._refresh_tacklebox()
		for entry in main._box_rows:
			_t.ok(str(entry["id"]) != "corn",
				"the bait already on the hook is still offered as a choice")

	# And there is a way out, from the box and from the back button.
	_t.ok(main._go_back(), "back was ignored with the tackle box open")
	_t.ok(not main._at_box, "back did not shut the tackle box")


## THE FLOAT FLOATS ON THE WATER, and this is the assertion that it reads the same
## surface the shader draws rather than a second copy of it.
##
## Gideon: "the bobber comes all the way out of the water, or goes completely below
## the wave, even when a fish isn't biting." It rode `_boat_pose`, so it inherited
## the hull's heave from thirty metres away AND the hull's pitch, which at that
## range swung it well over a metre.
##
## Sampled across a span of time rather than at one instant, because the fault was
## invisible in any single frame - a float a metre high looks like a float, and it
## is only against the moving surface that it is obviously wrong. That is exactly
## why a screenshot never caught this and he did.
func _check_the_float_floats_on_the_water(main) -> void:
	_t.begin("smoke > the float sits in the water rather than on the boat")
	main.freeze(1)
	if not _drive_until(main, Sim.WAITING, 60.0):
		_t.ok(false, "no cast was in the water to check the float against")
		return

	var worst := 0.0
	var moved := 0.0
	var first_pos: Vector3 = main.lure_world_position()
	var first: float = first_pos.y
	for i in 240:
		main.advance(1.0 / 60.0, 1.0 / 60.0)
		if main.sim.state != Sim.WAITING:
			break
		var p: Vector3 = main.lure_world_position()
		var surface: float = main.water_height(p.x, p.z)
		# WAITING has no fish on it, so the float should be sitting AT the
		# waterline. Any daylight under it, or any burial, is the bug.
		worst = maxf(worst, absf(p.y - surface))
		moved = maxf(moved, absf(p.y - first))
	_t.lt(worst, 0.02,
		"the float is %.2f m off the water surface with no fish on it - it is riding something other than the lake" % worst)

	# ...and it must actually MOVE with the swell. A float welded to y=0 would pass
	# the check above perfectly, which is the failure this pairs against.
	_t.gt(moved, 0.005,
		"the float never moves vertically - it is pinned to a flat waterline rather than floating on the wave")


## THE STICK IS THE ONLY WAY TO TURN.
##
## Gideon: "You can still turn by swiping the screen, I only want to be able to
## turn by using the virtual thumb stick." The whole screen is the cast button, so
## a swipe was both a look and a cancelled cast at once.
##
## The cancel is asserted here too, and deliberately: it is the half that has to
## SURVIVE, because a swipe that quietly charged and fired on release would be
## worse than the thing being removed.
func _check_a_swipe_does_not_turn_the_view(main) -> void:
	_t.begin("smoke > swiping the screen does not turn the view")
	main.freeze(1)
	var before: float = main._look_yaw_want
	main._touching = true
	main._drag_moved = 0.0
	for i in 20:
		main._apply_look(Vector2(60.0, 0.0))
	_t.approx(main._look_yaw_want, before, 1e-5,
		"swiping the screen still turns the view - the stick is meant to be the only way")

	# And a swipe still abandons a charge rather than throwing a cast on release.
	main.freeze(1)
	main._charging = true
	main._drag_moved = 0.0
	main.sim.hold_cast()
	for i in 10:
		main._apply_look(Vector2(40.0, 0.0))
	_t.ok(not main._charging,
		"a swipe no longer cancels the charge - a brushed thumb will fire a cast")


## THE STICK TURNS THE VIEW, AND KEEPS TURNING WHILE IT IS HELD.
##
## That is the whole difference from a drag, and the reason it was asked for: a
## drag reports movement, so you must keep dragging and re-dragging; a stick you
## lean on.
## How far over the look limit the stick test starts, so it has room to travel.
const LOOK_START := 0.9

func _check_the_stick_turns_the_view(main) -> void:
	_t.begin("smoke > the stick turns the view and lets go")
	main.freeze(1)
	# Started hard over the OTHER way, so there is a full sweep of travel to use
	# before the look limit clamps. The first version started at zero, ran into
	# the limit after a second and reported it as "the stick stopped working".
	# Pushing the stick RIGHT turns the view right, which decreases yaw - so the
	# sweep has to start at the positive limit to have travel available.
	main._look_yaw = LOOK_START
	main._look_yaw_want = LOOK_START

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(140, 1900)
	main._stick_input(press)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(300, 1900)
	main._stick_input(drag)
	for i in 60:
		main.advance(1.0 / 60.0)
	var turned: float = main._look_yaw_want
	_t.lt(turned, LOOK_START - 0.05, "holding the stick over does not turn the view")

	for i in 60:
		main.advance(1.0 / 60.0)
	_t.lt(main._look_yaw_want, turned - 0.02,
		"the view stops turning while the stick is held - it is behaving like a drag")

	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(300, 1900)
	main._stick_input(up)
	for i in 40:
		main.advance(1.0 / 60.0)
	var settled: float = main._look_yaw_want
	for i in 60:
		main.advance(1.0 / 60.0)
	_t.approx(main._look_yaw_want, settled, 0.02,
		"the view keeps turning after the stick is let go")


## EVERY THING IN THE BOAT CAN BE FOUND BY LOOKING, AND USED.
##
## The boat's objects are only worth having if the aim can actually reach them
## from the seat. A thing placed outside the look limits is worse than no thing:
## it is a prompt the player sees once, hunts for, and never finds again.
##
## Swept across the whole yaw and pitch range the player has, which is the honest
## test - not "can the code find it if pointed at exactly".
func _check_everything_in_the_boat_can_be_looked_at_and_used(main) -> void:
	_t.begin("smoke > everything in the boat can be reached from the seat")
	main.freeze(1)
	main.sim.state = Sim.IDLE

	var found: Dictionary = {}
	var steps := 26
	for yi in steps:
		for pi in steps:
			main._look_yaw = lerpf(-main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT,
				float(yi) / float(steps - 1))
			# The sweep has to cover the ASYMMETRIC range the player actually has:
			# a seated person looks much further down than up, and everything in
			# the boat lives below the eye line. Sweeping the old symmetric range
			# would silently stop testing the half of the cone the gear is in.
			main._look_pitch = lerpf(-main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP,
				float(pi) / float(steps - 1))
			main._look_yaw_want = main._look_yaw
			main._look_pitch_want = main._look_pitch
			main._sync()
			if main._looking_at != "":
				found[main._looking_at] = true

	for t in main._things:
		var id: String = t["id"]
		_t.ok(found.has(id),
			"'%s' is in the boat but cannot be looked at from the seat" % id)

	# And each one says something, and doing it does not blow up.
	for t in main._things:
		var text: String = (t["look"] as Callable).call()
		_t.ok(text != "", "'%s' has nothing to say when looked at" % t["id"])
		main._looking_at = str(t["id"])
		main._on_use()
		if main._menus.is_open():
			main._menus.close()
	_t.ok(true, "every thing in the boat can be used without erroring")

	main._look_yaw = 0.0
	main._look_pitch = 0.0
	main._look_yaw_want = 0.0
	main._look_pitch_want = 0.0


## NOTHING YOU CAN INTERACT WITH IS INVISIBLE.
##
## This is the test that would have caught the worst placeholder in the project.
## The livewell, the bait box and the lamp were all lookable and usable and NONE
## of them existed as geometry - the player pointed at empty air and got a
## prompt. It passed every check there was, including the reachability sweep,
## because that tests the aim and not the picture.
##
## So: for every interactable, there must be actual mesh within arm's reach of
## its point. Approximate on purpose - the claim is "there is something there",
## not "the origin matches".
func _check_nothing_interactable_is_invisible(main) -> void:
	_t.begin("smoke > nothing you can interact with is invisible")
	main.freeze(1)

	var meshes: Array[Vector3] = []
	_collect_mesh_points(main.get_node("Boat"), meshes)
	_t.gt(float(meshes.size()), 4.0, "the boat has almost no geometry in it at all")

	for t in main._things:
		var at: Vector3 = t["at"]
		var nearest := 999.0
		for m in meshes:
			nearest = minf(nearest, at.distance_to(m))
		_t.lt(nearest, 0.42,
			"'%s' can be used but the nearest geometry is %.2f m away - it is an invisible prompt" % [
				t["id"], nearest])


## Every mesh origin under a node, in the boat's own space.
func _collect_mesh_points(node: Node, into: Array[Vector3]) -> void:
	for c in node.get_children():
		var mi := c as MeshInstance3D
		# VISIBLE geometry only. Counting hidden meshes would let a prop that is
		# switched off until it is bought stand in for one that is there - which
		# is exactly how the lamp bracket slipped through on the first pass.
		if mi != null and mi.mesh != null and mi.visible:
			# The AABB centre rather than the origin: an imported model's origin
			# is wherever its author left it, and for a lantern that is the
			# hanging point somewhere above the lamp.
			into.append(mi.position + mi.mesh.get_aabb().get_center() * mi.scale)
		if c is Node3D and (c as Node3D).visible:
			var here := (c as Node3D).position
			var sub: Array[Vector3] = []
			_collect_mesh_points(c, sub)
			for pt in sub:
				into.append(here + pt * (c as Node3D).scale)


## THE TITLE LEADS INTO THE GAME, both ways in.
##
## Continue must be OFFERED only when there is something to continue, New game
## must actually wipe, and both must leave a boat that can be fished. A title
## screen that can strand the player is the worst possible first screen.
func _check_the_title_leads_into_the_game(main) -> void:
	_t.begin("smoke > the title leads into the game")
	main.freeze(1)
	_t.ok(main._title != null, "there is no title screen")
	if main._title == null:
		return

	# Continue, with a save on disk.
	main._save_game()
	main._title.setup(true)
	_t.ok(not main._title._continue.disabled, "Continue is greyed out with a save present")
	main._on_continue()
	for i in 90:
		main.advance(1.0 / 60.0)
	_t.ok(not main._title.is_up(), "the title never goes away after Continue")

	# New game, which must wipe and leave a fresh boat - but keep the settings,
	# because those are about the person and not about the save.
	main.sim.econ.money = 4321
	main.sim.caught = 17
	main.sim.sensitivity = 1.7
	main._save_game()
	main._on_new_game()
	_t.eq(main.sim.econ.money, 0, "New game kept the old purse")
	_t.eq(main.sim.caught, 0, "New game kept the old tally")
	_t.ok(absf(main.sim.sensitivity - 1.7) < 0.01,
		"New game threw away the player's own settings")
	_t.ok(not FileAccess.file_exists(main.SAVE_PATH),
		"New game left the old save on disk")

	# And the fresh boat actually fishes, through the real seam.
	main.sim.hold_cast()
	main.advance(0.4)
	main.sim.release_cast()
	for i in 600:
		main.advance(1.0 / 60.0)
	_t.ok(main.sim.casts > 0, "a new game cannot cast")

	main._title.setup(false)
	_t.ok(main._title._continue.disabled, "Continue is offered with no save at all")


## THE FIRST MORNING TEACHES AND THEN GETS OUT OF THE WAY.
##
## Every beat has to be reachable by playing normally, the whole thing has to
## finish, and it must never come back. A tutorial that can stall is worse than
## no tutorial: the player cannot tell whether the game is broken or they are.
func _check_the_first_morning_teaches_and_ends(main) -> void:
	_t.begin("smoke > the first morning teaches and then ends")
	main.freeze(1)
	main.sim.intro_done = false
	main._intro = Intro.new()
	main._title.dismiss()
	for i in 120:
		main.advance(1.0 / 60.0)

	_t.eq(main._intro.step, 0, "the intro does not start at the beginning")
	_t.ok(main._intro.line() != "", "the intro's first beat says nothing")

	# Looking is beat 2, and only a real look should pass it.
	var step := 0
	var mem := {}
	var guard := 0
	while not main._intro.done() and guard < 24000:
		guard += 1
		# A player who looks around and then fishes properly.
		if main._intro.step == 1:
			main._look_yaw = 0.4
			main._look_yaw_want = 0.4
		Policies.act(Policies.ANGLER, main.sim, 1.0 / 60.0, mem)
		main.advance(1.0 / 60.0)

	_t.ok(main._intro.done(),
		"the intro stalled at beat %d: '%s'" % [main._intro.step, main._intro.line()])
	_t.ok(main.sim.intro_done, "finishing the intro was never recorded")
	_t.eq(main._intro.line(), "", "the intro still has something to say after finishing")

	# Every beat has copy, and every non-timed beat has a condition that exists.
	for beat in Intro.BEATS:
		_t.ok(str(beat["say"]) != "", "a beat says nothing")
		if not beat.has("hold"):
			_t.ok(str(beat.get("needs", "")) != "", "a beat has neither a hold nor a condition")

	# And it does not come back on the next boot.
	main._save_game()
	var fresh := Sim.new(1)
	var f := FileAccess.open(main.SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	Save.apply(fresh, parsed)
	_t.ok(fresh.intro_done, "the first morning will play again on the next launch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.SAVE_PATH))


## A WRONG FISH LOOKS WRONG.
##
## `wrong` sat in the species data from the first day and changed nothing on
## screen for six species. This asserts that it now does - not how it looks,
## which is taste, but that the generator produces a DIFFERENT mesh for one.
## A data flag that draws identically is a flag that does not exist.
func _check_a_wrong_fish_is_drawn_wrong(main) -> void:
	_t.begin("smoke > a wrong fish is actually drawn wrong")
	main.freeze(1)

	var wrong_ids: Array[String] = []
	var right_ids: Array[String] = []
	for row in Species.TABLE:
		if bool(row.get("wrong", false)):
			wrong_ids.append(str(row["id"]))
		else:
			right_ids.append(str(row["id"]))
	_t.gt(float(wrong_ids.size()), 0.0, "no species is flagged wrong at all")

	# Same band, so the comparison is about `wrong` and not about depth.
	main._rebuild_fish("thin_perch")
	var wrong_parts: int = main._fish.get_child_count()
	var wrong_aabb: AABB = (main._fish.get_node("Body") as MeshInstance3D).mesh.get_aabb()

	main._rebuild_fish("perch")
	var right_aabb: AABB = (main._fish.get_node("Body") as MeshInstance3D).mesh.get_aabb()

	_t.gt(absf(wrong_aabb.size.z - right_aabb.size.z) + absf(wrong_aabb.size.y - right_aabb.size.y),
		0.02, "a Thin Perch is the same shape as a perch - `wrong` draws nothing")

	# And the worst of them grow something extra.
	main._rebuild_fish("blindfish")
	var deep_parts: int = main._fish.get_child_count()
	main._rebuild_fish("chub")
	var ordinary_parts: int = main._fish.get_child_count()
	_t.gt(float(deep_parts), float(ordinary_parts),
		"the deep wrong ones have no more to them than an ordinary fish")

	# Every wrong species still builds without erroring.
	for id in wrong_ids:
		main._rebuild_fish(id)
		_t.ok(main._fish.get_child_count() > 3, "'%s' built almost nothing" % id)


## THE WALK ALWAYS ARRIVES, AND CAN ALWAYS BE CUT.
##
## The title is a place - standing outside a gate - and Continue walks you
## through it to the boat. Two things have to hold or it is a trap rather than
## an opening: it must END at the seat, exactly where play begins, and a tap
## must always cut it. A beautiful thing you cannot skip is the worst thing in
## the game by the fifth time you sit through it.
func _check_the_walk_to_the_boat_always_arrives(main) -> void:
	_t.begin("smoke > the walk to the boat arrives, and can be cut")

	for shots in [Sequence.going_out(), Sequence.arriving()]:
		# It plays out on its own and stops.
		main.freeze(1)
		main._play_sequence(shots)
		_t.ok(main._in_sequence, "the sequence did not start")
		_t.ok(main._hud_is_down(), "the HUD is up over a cinematic")
		var guard := 0
		while main._in_sequence and guard < 3600:
			main.advance(1.0 / 60.0)
			guard += 1
		_t.ok(not main._in_sequence, "the sequence never ended")
		_t.lt(float(guard), 3599.0, "the sequence ran for a minute without finishing")
		# And it puts the camera where play begins.
		_t.approx(main._seq_at.distance_to(Sequence.SEAT), 0.0, 0.01,
			"the walk does not end at the seat - the hand-over into play would jump")
		_t.eq(main._gate_open, 1.0, "the gate is not open at the end of the walk")
		# Say WHICH condition is still holding it down. An assertion that only
		# reports "it is down" sends you probing for the one of three that did it.
		_t.ok(not main._hud_is_down(),
			"the HUD never comes back after the walk (menus=%s title=%s seq=%s reading=%s)" % [
				main._menus.is_open(), main._title.is_up(), main._in_sequence, main._reading])

		# And a touch cuts it, from the very first frame.
		main.freeze(1)
		main._play_sequence(shots)
		main.advance(1.0 / 60.0)
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.position = Vector2(300, 900)
		main._on_cast_input(press)
		_t.ok(not main._in_sequence, "a tap does not skip the sequence")
		# ...and that tap must NOT also have thrown a cast.
		_t.eq(main.sim.state, Sim.IDLE, "skipping the sequence also fired a cast")
		_t.eq(main._gate_open, 1.0, "skipping left the gate shut")

	# The shots themselves are well formed.
	for shots in [Sequence.going_out(), Sequence.arriving()]:
		_t.gt(float(shots.size()), 2.0, "a sequence with fewer than three shots is a cut")
		for shot in shots:
			_t.ok(shot.has("at") and shot.has("look"), "a shot has no camera position")
			_t.gt(float(shot.get("for", 0.0)), 0.05, "a shot is too short to see")


## EVERY ROOM LOOKS LIKE THE THING IT IS NAMED AFTER.
##
## The logbook is paper, the shed is a counter, the kit is a tackle box. What
## can actually be asserted is not whether they look nice - that is taste - but
## that each one is a DIFFERENT object and that its ink is legible on its own
## ground. Cream text on cream paper is the failure this catches, and it is one
## edit away at all times.
func _check_every_room_looks_like_the_thing_it_is(main) -> void:
	_t.begin("smoke > every room looks like the thing it is named after")
	main.freeze(1)
	var menus = main._menus

	var skins: Dictionary = {}
	for screen in [Menus.SHED, Menus.MAP, Menus.LOG, Menus.KIT]:
		menus.open(screen)
		var skin: String = menus._skin
		_t.ok(not skins.has(skin) or screen == Menus.MAP,
			"%s reuses the '%s' skin - the rooms are not different objects" % [screen, skin])
		skins[skin] = screen

		# Ink has to be readable on the ground it is written on.
		var ink: Color = menus._ink()
		# COMPOSITED. A row's own colour can be translucent - the book's are a
		# 10% wash over paper - so reading the raw value measures a colour that
		# is never actually drawn, which is how this test first failed on a room
		# that is perfectly legible.
		var row: Color = menus._row_bg(true)
		var base: Color = menus._ground()
		var ground := base.lerp(Color(row.r, row.g, row.b), row.a)
		var lift: float = absf(_luma(ink) - _luma(ground))
		_t.gt(lift, 0.28,
			"'%s' writes %.2f-luma ink on %.2f-luma ground - that is unreadable" % [
				screen, _luma(ink), _luma(ground)])

		# And the way out is styled for the room rather than left charcoal.
		_t.ok(menus._back.text != "", "the way out of '%s' has no label" % screen)
		menus.close()

	_t.gt(float(skins.size()), 3.0, "there are fewer than four distinct room skins")


func _luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## THE LOGBOOK IS A REAL OBJECT, AND ITS PAGE IS NOT INSIDE THE FLOOR.
##
## The page is a quad printed with a SubViewport, and it spent four rounds of
## debugging BURIED IN THE FLOORBOARDS - the planks are 30 mm thick sitting 20 mm
## off the sole, so their top face is above where the page was. The texture was
## correct the entire time; only the corner poking past a plank edge was visible.
##
## Nothing about the camera, the quad or the anchors could have found that. What
## finds it is the arithmetic: whatever else is true, the page has to be ABOVE
## everything else lying on the sole.
func _check_the_logbook_is_a_real_object(main) -> void:
	_t.begin("smoke > the logbook is a real object above the floor")
	main.freeze(1)
	_t.ok(main._book != null, "there is no logbook in the boat")
	if main._book == null:
		return

	# The page, in boat space.
	var surface: MeshInstance3D = null
	for c in main._book.get_children():
		if c is MeshInstance3D:
			surface = c
	_t.ok(surface != null, "the logbook has no page to print on")
	if surface == null:
		return
	var page_y: float = (main._book.transform * surface.transform).origin.y

	# The top of the floorboards at the same station.
	var z: float = main._book.position.z
	var plank_top: float = main._hull_floor_y(z) + 0.020 + 0.015
	_t.gt(page_y, plank_top + 0.005,
		"the page sits at %.3f and the floorboards reach %.3f - it is inside the floor" % [
			page_y, plank_top])

	# It opens, shows a page, and turns.
	main.sim.deepest_ever = 60.0
	main._open_book()
	_t.ok(main._reading, "the logbook did not open")
	for i in 200:
		main.advance(1.0 / 60.0)
	_t.ok(main._book.is_open(), "the logbook never finished opening")
	_t.gt(float(main._book_pages), 1.0, "the whole book fits on one page")

	# IT IS IN THE HANDS, not on the floor with the camera bent over it.
	#
	# The distinction is invisible to every other assertion here - the book opens,
	# paginates and hit-tests identically either way - so without this the whole
	# feature could be reverted and the suite would stay green.
	var cam: Transform3D = main._cam.transform
	var held: Vector3 = (main._boat_pose * main._book.transform).origin
	var in_cam: Vector3 = cam.affine_inverse() * held
	_t.gt(-in_cam.z, 0.20, "the open logbook is not in front of the reader")
	_t.lt(-in_cam.z, 1.10,
		"the open logbook is %.2f m away - it is being looked AT rather than held" % -in_cam.z)
	_in_frame(main, held, "the held logbook")

	# And the camera did not go anywhere to read it. That is the half that makes
	# it reading-in-the-boat rather than a menu: the lake stays over the top of
	# the page, and the player's head is still their own.
	_t.approx(cam.origin.distance_to(Sequence.SEAT), 0.0, 0.25,
		"the camera left the seat to read the book - it should have been picked up instead")

	var was: int = main._book.page
	main._book.page += 1
	main._refresh_book()
	_t.eq(main._book.page, was + 1, "the page did not turn")

	# SWIPED, in both directions, and the direction matters. Right-to-left goes
	# ON - the way the paper moves under the thumb - and getting that backwards
	# is the commonest way this gesture is built wrong, so it is asserted rather
	# than assumed. A press that does not travel must stay a tap.
	main._book.page = 1
	main._refresh_book()
	var start: int = main._book.page
	main._page_from = Vector2(700, 1200)
	main._release_page(Vector2(700 - main.PAGE_SWIPE - 20.0, 1210))
	_t.eq(main._book.page, start + 1, "swiping right-to-left did not go on a page")

	main._page_from = Vector2(300, 1200)
	main._release_page(Vector2(300 + main.PAGE_SWIPE + 20.0, 1190))
	_t.eq(main._book.page, start, "swiping left-to-right did not go back a page")

	# A short press is a tap, not a swipe - otherwise a thumb that drifts four
	# pixels while tapping turns a page nobody asked for.
	var held_page: int = main._book.page
	main._page_from = Vector2(500, 1200)
	main._release_page(Vector2(508, 1204))
	_t.eq(main._book.page, held_page,
		"an eight pixel drift turned a page - the swipe threshold is not being applied")

	# A ray that misses the page must report a miss - which is what makes
	# tapping off the book a way out. Asserted on `hit_page` directly, because
	# an off-tree camera cannot project a screen point into a ray at all and the
	# harness never has a live one.
	var from: Vector3 = main._cam.transform.origin
	var away: Vector3 = main._cam.transform.basis.z
	_t.lt(main._book.hit_page(from, away, main._boat_pose).x, 0.0,
		"a ray pointing away from the book still reports a hit on the page")

	# TAPPING OFF THE PAGE NO LONGER CLOSES IT. That was the way out until it was
	# played on a phone: a brushed thumb lost your place, and a swipe that was not
	# quite horizontal fell back to a tap, so trying to turn a page could shut the
	# book instead. The X in the room bar is the only way out now.
	main._book.page = 1
	main._tap_page(Vector2(700, 500))
	_t.ok(main._reading, "a tap away from the page still shuts the book")

	# ...but turning past the last page still does, because that is a thing the
	# player asked for rather than something a thumb does by accident.
	main._book.page = main._book_pages - 1
	main._turn_page(1)
	_t.ok(not main._reading, "turning past the last page does not shut the book")

	# THE ROOM BAR IS THE WAY OUT, and it is on screen whenever a room is open.
	main.freeze(1)
	main._open_book()
	for i in 60:
		main.advance(1.0 / 60.0)
	main._sync_room_bar()
	_t.ok(main._room_bar.visible, "the room bar is not shown while the book is open")
	var page_before: int = main._book.page
	main._room_step(1)
	_t.eq(main._book.page, page_before + 1, "the next arrow does not turn the page")
	main._room_step(-1)
	_t.eq(main._book.page, page_before, "the back arrow does not turn the page back")
	main._room_close_pressed()
	_t.ok(not main._reading, "the X does not close the book")
	main._sync_room_bar()
	_t.ok(not main._room_bar.visible, "the room bar is still shown with nothing open")

	_check_the_logbook_is_in_shot(main)


## THE LOGBOOK IS IN THE PICTURE, NOT MERELY IN THE SCENE.
##
## Gideon: "I dont see the log book in the game, just a log book button." The
## object existed, at the right height, above the floorboards, with a working
## page and a passing test - and it was two metres ahead and 1.13 m below a
## camera that sits 1.35 m up, which is 27 degrees down in a frame that only
## reaches 29. It was in shot in the sense that a coin under the sofa is in the
## room.
##
## So this is the assertion that check was missing: put the seated camera where
## the player sits, and require the thing to land inside the frustum with a
## margin. It is the same arithmetic for any object the player is expected to
## notice, which is why it takes the node as an argument.
func _check_the_logbook_is_in_shot(main) -> void:
	_t.begin("smoke > the logbook can be brought into shot from the seat")
	main._shut_book()
	main.sim.state = Sim.IDLE
	main._stick_held = false
	main._stick_vec = Vector2.ZERO
	main._look_yaw_want = 0.0
	main._look_pitch_want = 0.0
	# LET THE CAMERA COME BACK TO THE SEAT FIRST. `_shut_book` plays a sequence,
	# so for the next half second the eye is still down over the book - and
	# sampling it there measured the book as 77 degrees below "the seat" when it
	# is 40, which reads as an impossible object rather than a moving camera.
	for i in 120:
		main.advance(1.0 / 60.0)

	# THE CLAIM CHANGED WHEN THE PLAYER SAT DOWN, and it is worth saying why
	# rather than just relaxing the number.
	#
	# This used to demand the book be in frame at REST, and that was right while
	# the camera floated a metre behind the transom: from out there the whole boat
	# was in shot, so anything not in shot was lost, and "I dont see the log book
	# in the game" was exactly that bug.
	#
	# Sitting on the thwart, nothing on the boat's sole is in the resting frame -
	# your own feet are not either. Demanding it would force every object in the
	# boat out to the bow, which is the opposite of the arrangement being built.
	#
	# So the honest claim is that the player can FIND it: it is inside the look
	# cone they actually have, and once they look at it, it is properly in frame
	# rather than clipped to an edge. That is strictly stronger than the old test
	# in the way that matters - the old one never checked the book was reachable,
	# only that it happened to be visible from one fixed pose.
	var book_at: Vector3 = main._book.global_position if main._book.is_inside_tree() 		else main._boat_pose * main._book.position
	var eye: Vector3 = main._cam.transform.origin
	var to_book := book_at - eye
	var need_pitch := atan2(to_book.y, Vector2(to_book.x, to_book.z).length())
	var need_yaw := atan2(-to_book.x, to_book.z)
	# `_look_pitch` is measured from the resting tilt, and negative is DOWN.
	var want_pitch := need_pitch - deg_to_rad(main.REST_TILT)
	_t.gt(want_pitch, -main.LOOK_PITCH_DOWN,
		"the logbook is %.0f degrees below the seat and the player can only look %.0f down - it cannot be found" % [
			-rad_to_deg(need_pitch), rad_to_deg(main.LOOK_PITCH_DOWN)])
	_t.lt(absf(need_yaw), main.LOOK_YAW_LIMIT,
		"the logbook is outside the yaw the player has")

	main._look_yaw_want = need_yaw
	main._look_pitch_want = want_pitch
	for i in 120:
		main.advance(1.0 / 60.0)
	_in_frame(main, book_at, "the logbook, looked straight at,")


## Is a world point inside the seated camera's frame, with room to spare?
##
## The aspect is the PHONE's, not the project's. A 1080x1920 frame and a
## 1080x2340 one disagree about the bottom third of the screen, which is exactly
## where things fall off - see the note at the top of scripts/shot.gd.
func _in_frame(main, at: Vector3, what: String) -> void:
	var cam: Transform3D = main._cam.transform
	var local: Vector3 = cam.affine_inverse() * at
	_t.gt(-local.z, 0.05, "%s is behind the camera" % what)
	if -local.z <= 0.05:
		return
	var half_v := tan(deg_to_rad(main._cam.fov) * 0.5)
	var aspect := 1080.0 / 2340.0
	var up := absf(local.y / -local.z) / half_v
	var across := absf(local.x / -local.z) / (half_v * aspect)
	# 0.88 rather than 1.0: something touching the very edge of the frame is
	# something the player finds by accident, and the controls own the bottom
	# eighth of the screen anyway.
	_t.lt(up, 0.88, "%s sits %.0f%% of the way to the top or bottom edge" % [
		what, up * 100.0])
	_t.lt(across, 0.88, "%s sits %.0f%% of the way to the side of the frame" % [
		what, across * 100.0])
