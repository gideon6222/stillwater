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
	_check_looking_around_never_casts_by_accident(main)
	_check_everything_in_the_boat_can_be_looked_at_and_used(main)
	_check_nothing_interactable_is_invisible(main)
	_check_the_title_leads_into_the_game(main)
	_check_the_first_morning_teaches_and_ends(main)
	_check_a_wrong_fish_is_drawn_wrong(main)
	_check_the_walk_to_the_boat_always_arrives(main)
	_check_every_room_looks_like_the_thing_it_is(main)

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
	_t.ok(main._line.visible, "the line is not visible during a fight")


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


## LOOKING AROUND NEVER CASTS BY ACCIDENT.
##
## One finger carries three verbs here - drag looks, still-hold casts, tap taps -
## and the whole scheme rests on a drag never being mistaken for a cast. If it
## can be, the player cannot look at their own boat without throwing a line into
## it, which is exactly the sort of thing reported as "clunky".
func _check_looking_around_never_casts_by_accident(main) -> void:
	_t.begin("smoke > a look never becomes a cast")
	main.freeze(1)
	main.sim.state = Sim.IDLE

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(300, 900)
	main._on_cast_input(press)

	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(-40, 0)
	for i in 6:
		main._on_cast_input(drag)

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(60, 900)
	main._on_cast_input(release)
	for i in 30:
		main.advance(1.0 / 60.0)

	_t.eq(main.sim.state, Sim.IDLE, "dragging to look threw a cast")
	_t.ok(absf(main._look_yaw) > 0.01, "dragging did not turn the view at all")

	# And a still hold still casts.
	main.freeze(1)
	main._look_yaw = 0.0
	main._on_cast_input(press)
	for i in 30:
		main.advance(1.0 / 60.0)
	_t.eq(main.sim.state, Sim.CHARGING, "a still hold does not load a cast")
	main._on_cast_input(release)
	_t.ok(main.sim.state != Sim.CHARGING, "letting go does not release the cast")


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
			main._look_pitch = lerpf(-main.LOOK_PITCH_LIMIT, main.LOOK_PITCH_LIMIT,
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
		_t.ok(not main._hud_is_down(), "the HUD never comes back after the walk")

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
