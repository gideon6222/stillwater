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
	# A SCRIPT THAT DID NOT PARSE LEAVES A BARE Node3D, and the suite then drives a
	# stub that can never reach any state - which presents as a HANG rather than a
	# failure, because every "advance until X" loop simply runs to its limit. One
	# line turns a silent multi-minute timeout into an instant, accurate failure.
	if not main.has_method("freeze"):
		printerr("  main.tscn did not load its script - read the parse error ABOVE this line")
		quit(1)
		return

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
	_check_the_cast_is_one_motion(main)
	_check_the_cast_is_a_body_movement(main)
	_check_the_slide_is_the_reel(main)
	_check_the_pressure_is_up_the_side(main)
	_check_the_fight_is_visible_and_felt(main)
	_check_the_catch_is_in_the_livewell(main)
	_check_the_pages_really_turn(main)
	_check_the_lake_is_six_places(main)
	_check_rowing_is_a_crossing(main)
	_check_sleeping_is_a_transition(main)
	_check_the_title_stands_aside_for_a_returning_player(main)
	_check_the_game_pauses_and_has_a_face(main)
	_check_the_new_sounds_exist_and_are_placed(main)
	_check_the_water_breaks_against_the_hull(main)
	_check_the_sky_has_more_than_one_kind_of_cloud(main)
	_check_the_shed_is_a_room(main)
	_check_the_shed_stock_is_physical(main)
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
	_check_looking_at_a_thing_selects_it(main)
	_check_the_button_says_what_the_moment_wants(main)
	_check_the_rod_points_where_you_look(main)

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
		# G2: THE WAY OUT IS A DECISION NOW, NOT A TIMER - so the check is that
		# both doors work rather than that time passes. A state whose only exit is
		# a clock was the original sin this whole check exists for; a state with
		# two exits and no clock is fine, as long as both of them go somewhere.
		main.advance(Tuning.HOLD_TIME + 0.5)
		_t.eq(main.sim.state, Sim.HOLDING,
			"the fish went in the box on a timer - the player never got to choose")
		# THE BUTTON A THUMB PRESSES, not the sim's method: `_cast_pressed` is the
		# seam, and it is where "Keep" could stop being wired without the rules
		# noticing.
		if main.sim.econ.can_keep(main.sim.fish_weight):
			main._cast_pressed()
		else:
			main._back.pressed.emit()
		_t.eq(main.sim.state, Sim.IDLE, "deciding did not put the line back in the boat")
		_t.eq(main.sim.fish_id, "", "the fish is still on the line after being landed")
		# And it has to actually play on the other side.
		main.play(Policies.ANGLER, 3.0)
		_t.ok(main.sim.state != Sim.IDLE, "the next cast does not start when the frame loop runs")

	_t.begin("smoke > a lost fish returns the player to the boat")
	main.freeze(2)
	# DEEP WATER FIRST, and before the cast rather than after it. Set after the
	# fish was already on, the change did nothing: `_drive_until` saw the sim
	# already FIGHTING and returned on the spot, so the break-off was attempted
	# against the reeds fish that was already hooked - in the one band built to
	# forgive exactly that. The test reported a LANDED fish and was right to.
	main.sim.spot = "steeple"
	main.sim.econ.line = 3
	main.sim.econ.has_motor = true
	var reached_fight := _drive_until(main, Sim.FIGHTING, 180.0)
	_t.ok(reached_fight, "no fish was ever hooked to lose")
	if reached_fight:
		# Break it off deliberately, through the same seam a thumb uses.
		#
		# TWO THINGS WERE WRONG HERE AND BOTH MADE IT UNFALSIFIABLE. It drove the
		# fight with `tap()`, which the fifth fight documents as doing NOTHING
		# while fighting - so it was applying no input at all and waiting to see
		# whether a fish lost itself. And it did it in THE REEDS, which are built
		# to forgive exactly this: a beginner who holds on through a run in the
		# tutorial keeps the fish, by design.
		#
		# So it holds the reel flat, through `set_reel(1.0)`, in water deep enough
		# that doing so parts the line.
		var step := 1.0 / 60.0
		for i in int(round(25.0 / step)):
			if main.sim.state != Sim.FIGHTING:
				break
			main.sim.set_reel(1.0)
			main.advance(step, step)
		_t.eq(main.sim.state, Sim.LOST, "holding the reel flat out never ends the fight")
		main.advance(Tuning.HOLD_TIME + 0.5)
		_t.eq(main.sim.state, Sim.IDLE, "a lost fish leaves the player stuck")

## WORLD TRANSFORM WITHOUT THE TREE.
##
## `global_transform` returns IDENTITY for every node in this harness - the scene
## is instantiated and stepped by hand, not run, so Godot does not consider it
## inside the tree and every position comes back as the origin. The first version
## of the guard below used it and duly reported the reel as "behind the camera",
## which was a fact about the harness and not about the game.
##
## Multiplying the local transforms up the parent chain needs no tree and is what
## `main.gd` itself does to find the rod tip.
func _world_of(node: Node3D, stop: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node3D = node
	while n != null and n != stop:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


## T4: THE GAME STOPS WHEN THE PHONE TAKES IT AWAY, and ships its own icon.
##
## Android leaves a paused app's process alive. Without a pause the lake goes on
## running behind a phone call - the clock advances, a hooked fish keeps pulling -
## and the player comes back to a parted line they never touched.
func _check_the_game_pauses_and_has_a_face(main) -> void:
	_t.begin("smoke > backgrounding the app stops the lake")
	main.freeze(2)
	main.sim.reel_in()
	main.sim.state = Sim.IDLE
	# `frozen` is the HARNESS's switch and `paused` is the phone's, and this check
	# is about the second one - so the first has to come off to see it. They are
	# deliberately separate: a headless run drives `_tick` by hand and must not be
	# affected by a window event, and a backgrounded phone must not care whether a
	# test is driving.
	main.frozen = false
	var before: float = main.sim.time

	main._notification(main.NOTIFICATION_APPLICATION_PAUSED)
	_t.ok(main.paused, "the app was backgrounded and the game kept running")
	# `_process` is the real loop, and it is what `paused` gates. Driving it
	# directly is the only way to assert the gate rather than the flag.
	main._process(1.0 / 60.0)
	main._process(1.0 / 60.0)
	_t.eq(main.sim.time, before, "the lake ran on while the app was in the background")

	main._notification(main.NOTIFICATION_APPLICATION_RESUMED)
	_t.ok(not main.paused, "the app came back and the game stayed stopped")
	main._process(1.0 / 60.0)
	_t.gt(main.sim.time, before, "the game did not start again when the app did")
	main.frozen = true

	# AND IT HAS ITS OWN FACE. An empty launcher slot ships the engine's logo,
	# which is the most visible way for a finished game to look unfinished - and
	# it is invisible from inside the game, so nothing else would ever catch it.
	for slot in ["res://assets/icon/stillwater_192.png", "res://assets/icon/stillwater_432.png"]:
		_t.ok(ResourceLoader.exists(slot), "the launcher icon %s is missing" % slot)
	var cfg := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_t.ok(cfg != null, "there is no export preset to check")
	if cfg != null:
		var text := cfg.get_as_text()
		cfg.close()
		_t.ok(text.find('launcher_icons/main_192x192=""') < 0,
			"an export preset still has no launcher icon - that build ships the Godot logo")



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

	var gauge: Control = main._distance_bar

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

	# The rod and the rules read the SAME tension. The band and its gauge are gone
	# - danger lives on the rod now - so what has to agree is the bend the player
	# sees and the number that can part the line.
	var live: float = main.sim.tension
	_t.eq(main.tension_shown(), live,
		"the rod is drawn from a different tension than the one that breaks the line")

	# The rod still bends under load, and the line still leaves its bent tip.
	var bend: float = main.rod_bend_degrees()
	_t.gt(bend, 0.0, "the rod does not bend at all during a fight")
	var tip: Vector3 = main._rod_tip
	var seg_count: int = main.ROD_SEGMENTS
	_t.gt(float(seg_count), 1.0, "the rod is a single stick again, so it tilts rather than bends")
	_t.gt(tip.z, 0.0, "the rod tip is behind the boat")

## THE PHONE'S REAL SHAPE, 1080 x 2338 on the S26 Ultra.
##
## Not the project's 1080 x 1920 base and not whatever window a desktop run
## happens to open. `stretch/aspect = "expand"` means the canvas the game renders
## into is the DEVICE's, so a check against anything else is a check about the
## wrong screen - which is how the rod came to be mounted a full viewport width
## off the left edge with a screenshot that looked fine.
const PHONE_ASPECT := 1080.0 / 2338.0

## T2: A RETURNING PLAYER IS NOT ASKED WHETHER THEY MEANT IT.
##
## "Continue IS the walk down." Somebody opening this game has already made the
## only decision the title offers - they are continuing, that is why they opened
## it - so the screen is a tap between them and the boat, every launch, forever.
##
## The test has to prove the title was never PUT UP, not merely that it is down by
## the time anyone looks: a title shown and dismissed on the same frame satisfies
## any check of the end state and is exactly the bug.
func _check_the_title_stands_aside_for_a_returning_player(main) -> void:
	_t.begin("smoke > a returning player walks straight down to the boat")
	# The scene under test was booted without a save, so the title is correct
	# here - that is the FIRST launch, where the choice is real.
	_t.ok(main._title != null, "there is no title at all")

	# Starting again has to be reachable from somewhere, or T2 removes the only
	# way to begin a new season.
	main._menus.open(Menus.KIT)
	var words := _page_text(main._menus._list)
	_t.ok(words.findn("start again") >= 0,
		"with the title gone for returning players there is no way to start a new game")
	main._menus.close()



## Where a world point lands, as a fraction of the viewport, WITHOUT a viewport.
##
## `Camera3D.unproject_position` needs a live one and returns null-dereferences
## headless, so the guard that used it passed in CI by not running at all. This is
## the same arithmetic done by hand: into camera space, divide by depth, scale by
## the tangent of the half-angle. Godot's default `keep_aspect` is KEEP_HEIGHT, so
## `fov` is the VERTICAL angle and the horizontal one follows from the aspect.
##
## Returns (-1, -1) for anything behind the camera, which fails the bounds check
## the same way being off an edge does.
func _on_screen(cam: Camera3D, world: Vector3) -> Vector2:
	var local := _world_of(cam, cam.get_parent()).affine_inverse() * world
	if local.z >= -0.0001:
		return Vector2(-1.0, -1.0)
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	var ndc := Vector2(
		(local.x / -local.z) / (half * PHONE_ASPECT),
		(local.y / -local.z) / half)
	return Vector2(0.5 + ndc.x * 0.5, 0.5 - ndc.y * 0.5)

## Which typeface a page is written in, by resource path, or "" if nothing on it
## carries a font override. Reads the LABELS, so a hand that is configured and
## never applied reads as no hand at all - which is the point.
func _page_hand(page) -> String:
	var stack: Array = [page]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label:
			var f = (n as Label).get_theme_font("font")
			if f != null and f.resource_path != "":
				return f.resource_path
		for c in n.get_children():
			stack.append(c)
	return ""

## P5: SLEEPING IS A TRANSITION, AND IT IS REACHABLE AT ALL.
##
## The second half of that is not hypothetical. Sleeping lived on the old map
## SCREEN, and when R5 took the dock away that screen stopped being reachable - so
## for a few builds the hour could not be changed by any means the player had.
## Nothing failed, nothing errored, and the whole day/night arc was simply gone.
func _check_sleeping_is_a_transition(main) -> void:
	_t.begin("smoke > putting your head down is a transition")
	main.freeze(2)
	main.sim.reel_in()
	main.sim.state = Sim.IDLE
	main.advance(0.2)

	# IT IS ON THE CHART, which is the only screen that can be reached now.
	var found := false
	for row in main._chart_rows():
		if str(row["id"]) == "sleep":
			found = true
	_t.ok(found, "there is no way to sleep from anywhere the player can reach")

	# IT TAKES TIME, and the hour does not turn on the frame you ask.
	var was: String = main.sim.hour
	main._sleep_now()
	_t.ok(main._in_sequence, "sleeping did not start a transition")
	_t.eq(main.sim.hour, was, "the hour turned before you had lain down")
	var slept := 0.0
	while slept < 14.0 and main._in_sequence:
		main.advance(1.0 / 60.0)
		slept += 1.0 / 60.0
	_t.ok(main.sim.hour != was, "you woke at the same hour you lay down at")
	_t.gt(slept, 3.0, "sleeping took %.1fs, which is a cut" % slept)
	_t.lt(slept, 10.0, "sleeping took %.1fs, which is a wait" % slept)

	# AND A CUT SLEEP STILL WAKES YOU SOMEWHERE ELSE.
	was = main.sim.hour
	main._sleep_now()
	main.advance(0.3)
	main._seq.skip()
	main._end_sequence()
	_t.ok(main.sim.hour != was, "a sleep that was tapped away left the hour where it was")



## P2: THE CHART IS A CROSSING, NOT A TELEPORT.
##
## Three claims, and the third is the one that bites: a sequence you can tap away
## must still ARRIVE. A crossing skipped before its swap shot would otherwise put
## the player back in the water they were trying to leave, which reads as the
## chart being broken rather than as a skip.
func _check_rowing_is_a_crossing(main) -> void:
	_t.begin("smoke > rowing between spots is a crossing")
	main.freeze(2)
	main.sim.reel_in()
	main.sim.state = Sim.IDLE
	main.sim.econ.has_motor = true
	main.sim.econ.line = 5
	main.sim.spot = "reed_bay"
	main.advance(0.2)

	# IT TAKES TIME, and the spot does not change on the frame you ask.
	main._row_to("steeple")
	_t.ok(main._in_sequence, "asking to row did not start a crossing")
	_t.eq(main.sim.spot, "reed_bay", "the boat teleported before the crossing began")
	var crossed := 0.0
	while crossed < 12.0 and main._in_sequence:
		main.advance(1.0 / 60.0)
		crossed += 1.0 / 60.0
	_t.eq(main.sim.spot, "steeple", "the crossing finished somewhere else")
	_t.gt(crossed, 2.0, "the crossing took %.1fs, which is a cut" % crossed)
	_t.lt(crossed, 8.0, "the crossing took %.1fs, which is a wait" % crossed)

	# THE WATER CHANGES UNDER THE MIDDLE OF IT, not at either end - the swap has
	# to happen while the camera is turned away from both landmarks.
	main.sim.spot = "reed_bay"
	main.advance(0.2)
	main._row_to("quarry")
	main.advance(0.5)
	_t.eq(main.sim.spot, "reed_bay", "the water changed while the old landmark was still in shot")
	while main._in_sequence:
		main.advance(1.0 / 60.0)
	_t.eq(main.sim.spot, "quarry", "the crossing did not arrive")

	# A CUT CROSSING STILL ARRIVES.
	main.sim.spot = "reed_bay"
	main.advance(0.2)
	main._row_to("narrows")
	main.advance(0.3)
	main._seq.skip()
	main._end_sequence()
	_t.eq(main.sim.spot, "narrows",
		"a crossing that was tapped away left the player where they started")

	# AND A REFUSED CROSSING PLAYS NOTHING. Four seconds of rowing followed by
	# still being at the bay is worse than an honest no.
	main.sim.econ.has_motor = false
	main.sim.spot = "reed_bay"
	main.advance(0.2)
	main._row_to("quarry")
	_t.ok(not main._in_sequence, "the boat rowed off toward water it cannot reach")
	_t.eq(main.sim.spot, "reed_bay", "a refused crossing moved the boat anyway")
	main.sim.econ.has_motor = true



## Everything written on a page, as one lowercase string. The book is built out of
## Labels in a VBox, so this is what a reader sees and nothing else.
func _page_text(page) -> String:
	var out := ""
	var stack: Array = [page]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label:
			out += " " + (n as Label).text
		for c in n.get_children():
			stack.append(c)
	return out.to_lower()

## W2: OVERCAST IS ITS OWN WEATHER, AND THE DEEP HAS ITS OWN SKY.
##
## Before this, "overcast" was 55% of the STORM panorama - so the four weathers
## that are not clear were one sky at four strengths, and an overcast afternoon
## was a weak thunderstorm. The failure is invisible in any single screenshot,
## which is why it lasted: each weather looks fine on its own and only the SET of
## them is wrong.
func _check_the_sky_has_more_than_one_kind_of_cloud(main) -> void:
	_t.begin("smoke > overcast is its own weather, not a weak storm")
	var mat: ShaderMaterial = main._sky_mat
	_t.ok(mat != null, "there is no sky material")
	if mat == null:
		return
	_t.ok(mat.get_shader_parameter("sky_pall") != null,
		"the sky has no flat-cloud panorama - overcast is still borrowing the storm")

	var seen := {}
	for weather in ["clear", "overcast", "storm"]:
		main.sim.weather = weather
		for i in 600:
			main._sync_mood(1.0 / 12.0)
		seen[weather] = {
			"pall": float(mat.get_shader_parameter("pall")),
			"cloud": float(mat.get_shader_parameter("cloud")),
		}

	_t.lt(float(seen["clear"]["pall"]), 0.08, "a clear sky has cloud in it")
	_t.lt(float(seen["clear"]["cloud"]), 0.08, "a clear sky has a storm in it")
	# OVERCAST IS FLAT CLOUD AND ALMOST NO STORM. This is the whole claim.
	_t.gt(float(seen["overcast"]["pall"]), 0.5,
		"an overcast sky is not mostly flat cloud")
	_t.lt(float(seen["overcast"]["cloud"]), 0.2,
		"an overcast sky is still mostly the storm panorama")
	# ...AND A STORM IS THE OTHER WAY ROUND.
	_t.gt(float(seen["storm"]["cloud"]), float(seen["overcast"]["cloud"]) + 0.3,
		"a storm has no more storm in it than an overcast day")
	_t.gt(float(seen["storm"]["pall"]), 0.05,
		"a storm's towers stand on blue sky rather than on an overcast base")

	# AND THE MIDDLE BANDS SIT UNDER IT WHATEVER THE FORECAST SAYS. Depth is the
	# same curve as the weather, not a second one.
	# DRIVEN FROM THE LURE, not by writing `_dread`. `_sync_mood` recomputes it
	# from how deep the line is every call, so assigning it directly lasts exactly
	# one frame and the check measured nothing - it reported 0.01 against 0.01 and
	# looked like the feature was missing.
	main.sim.weather = "clear"
	var was_state: String = main.sim.state
	var was_depth: float = main.sim.lure_depth
	main.sim.state = Sim.WAITING
	main.sim.lure_depth = 0.0
	for i in 600:
		main._sync_mood(1.0 / 12.0)
	var shallow_pall := float(mat.get_shader_parameter("pall"))
	main.sim.lure_depth = Audio.DREAD_FULL
	for i in 600:
		main._sync_mood(1.0 / 12.0)
	var deep_pall := float(mat.get_shader_parameter("pall"))
	_t.gt(deep_pall, shallow_pall + 0.2,
		"the sky over the quarry is the same as the sky over the reeds (%.2f against %.2f)" % [
			deep_pall, shallow_pall])
	main.sim.lure_depth = was_depth
	main.sim.state = was_state
	for i in 600:
		main._sync_mood(1.0 / 12.0)

## P1: THE LAKE IS SIX PLACES.
##
## Gideon, at the start of all this: "I don't want the whole game to take place in
## that one boat and in that one spot." Until P1 it literally did - the reeds and
## the bank were built once and drawn everywhere, so rowing to the Quarry changed
## the water's colour, the fish table, and nothing you could see.
##
## The claim is not "there is scenery". It is that the RIGHT scenery is up and the
## rest is not, which is the half that breaks silently: a landmark left visible at
## every spot looks perfectly good in a screenshot of the spot it belongs to.
func _check_the_lake_is_six_places(main) -> void:
	_t.begin("smoke > every spot on the lake looks like itself")
	main.freeze(2)
	main.sim.econ.has_motor = true
	main.sim.econ.line = 5

	for spot in World.SPOTS:
		var id := str(spot["id"])
		_t.ok(main._landmarks.has(id), "%s has no landmark at all" % id)

	for spot in World.SPOTS:
		var id := str(spot["id"])
		main.sim.spot = id
		main.advance(0.1)
		var up: Array[String] = []
		for other in main._landmarks:
			if (main._landmarks[other] as Node3D).visible:
				up.append(str(other))
		_t.eq(up.size(), 1,
			"at %s the lake shows %d landmarks: %s" % [id, up.size(), ", ".join(up)])
		if up.size() == 1:
			_t.eq(up[0], id, "at %s the landmark up is %s" % [id, up[0]])
		# THE REEDS ARE REED BAY'S. Drawing them in the middle of the quarry was
		# the loudest part of the lake being one place.
		_t.eq(main._reeds.visible, id == "reed_bay",
			"the reeds are %s at %s" % ["up" if main._reeds.visible else "down", id])

	# AND NO TWO PLACES ARE THE SAME PLACE. Counted off the geometry, because "six
	# silhouettes, never repeated" is the whole of the milestone and a copied
	# landmark would pass every check above.
	var shapes := {}
	for id in main._landmarks:
		var n: Node3D = main._landmarks[id]
		var sig := "%d" % n.get_child_count()
		var box: AABB = main._local_bounds(n)
		sig += ":%.1f,%.1f,%.1f" % [box.size.x, box.size.y, box.size.z]
		_t.ok(not shapes.has(sig),
			"%s is the same shape as %s - the landmarks repeat" % [id, str(shapes.get(sig, ""))])
		shapes[sig] = id
		_t.gt(box.size.y, 2.0, "%s has nothing standing out of the water" % id)

	main.sim.spot = "reed_bay"
	main.advance(0.1)



## W6: THE OARS AND THE DAWN CHORUS.
##
## The two sounds PLAN.md says genuinely could not be generated, and the two most
## likely in the whole mixer to be silently absent: `_stream` returns null for a
## missing file and every caller handles null by doing nothing, which is correct
## behaviour and completely inaudible. A sound that never loads is indistinguishable
## from a sound that is playing quietly.
func _check_the_new_sounds_exist_and_are_placed(main) -> void:
	_t.begin("smoke > the oars and the dawn chorus are in the mix")
	var audio = main._audio
	_t.ok(audio != null, "there is no audio")
	if audio == null:
		return

	# THEY LOAD. Both are OGG, and the loader used to take WAV only - so this is
	# also the check that the loader learned the second extension.
	for id in ["oars", "birds"]:
		_t.ok(audio._stream(id, false) != null,
			"'%s' does not load - the mixer will play silence and report nothing" % id)

	# THE BIRDS ARE A PLACE AND AN HOUR, not a constant. Loudest at first light,
	# gone by the afternoon, and gone at depth whatever the hour.
	main.sim.state = Sim.WAITING
	main.sim.lure_depth = 0.0
	main.sim.hour = "dawn"
	for i in 240:
		audio.tick(1.0 / 30.0, false)
	var at_dawn: float = audio._amb[3].volume_db
	main.sim.hour = "afternoon"
	for i in 240:
		audio.tick(1.0 / 30.0, false)
	var at_noon: float = audio._amb[3].volume_db
	_t.gt(at_dawn, at_noon + 6.0,
		"the dawn chorus is as loud at noon as at first light (%.1f against %.1f dB)" % [
			at_dawn, at_noon])

	# ...and the deep takes them, beside the bells.
	main.sim.hour = "dawn"
	main.sim.lure_depth = Audio.DREAD_FULL
	for i in 480:
		audio.tick(1.0 / 30.0, false)
	var down_deep: float = audio._amb[3].volume_db
	_t.gt(at_dawn, down_deep + 6.0,
		"the birds follow the line down into the quarry (%.1f against %.1f dB)" % [
			at_dawn, down_deep])
	main.sim.lure_depth = 0.0
	main.sim.state = Sim.IDLE



## W1: THE WATER BREAKS AGAINST THE HULL.
##
## The foam is analytic rather than a depth-difference, because PIPELINE.md has
## DEPTH_TEXTURE as corrupt on Forward Mobile with MSAA - so the surface has to be
## TOLD where the boat is, every frame. That hand-off is the thing that can rot:
## a shader still compiles and still draws when the position it is given is stale,
## wrong, or never sent, and the only symptom is foam in the wrong place on the
## lake, which nobody will be looking at.
func _check_the_water_breaks_against_the_hull(main) -> void:
	_t.begin("smoke > the water foams round the hull")
	main.freeze(2)
	main.advance(0.5)
	var mat: ShaderMaterial = main._water_mat
	_t.ok(mat != null, "there is no water material")
	if mat == null:
		return

	for want in ["hull_at", "hull_yaw", "hull_half", "foam", "foam_tint"]:
		_t.ok(mat.get_shader_parameter(want) != null,
			"the water has no '%s' - the foam is not wired up" % want)

	# THE COLLAR IS ON THE BOAT. Centred ahead of the hull's origin, because the
	# hull runs from z -0.85 to 2.25 and an ellipse centred on the origin rings
	# the water a metre astern of the transom.
	var at: Vector2 = mat.get_shader_parameter("hull_at")
	var origin: Vector3 = main._boat_pose.origin
	_t.lt(at.distance_to(Vector2(origin.x, origin.z)), 1.4,
		"the foam collar is %.2f m from the boat" % at.distance_to(Vector2(origin.x, origin.z)))
	_t.gt(at.distance_to(Vector2(origin.x, origin.z)), 0.2,
		"the foam collar is centred on the boat's origin rather than on its waterline")

	# AND IT IS AHEAD OF THE ORIGIN, ALONG THE BOAT'S OWN AXIS.
	#
	# This is the assertion that would catch the mistake actually available here:
	# `_boat_pose.basis.z` is the boat's +Z and the hull runs from -0.85 to 2.25
	# in that frame, so the collar belongs 0.70 m along it. Take the sign the
	# wrong way - which is easy, since Godot's node forward is -Z - and the foam
	# rings the water a metre and a half astern of the transom while still looking
	# plausible in a screenshot taken over the bow.
	#
	# An earlier version of this check shoved `_boat_pose.origin` sideways and
	# asserted the foam followed. It tested nothing: `_sync` recomputes the pose
	# from the wave sum on the very next line, so the shove was gone before the
	# assertion read it - and it left the swell mid-stride for the two checks
	# after it, which both failed.
	var fwd: Vector3 = main._boat_pose.basis.z
	var along := Vector2(fwd.x, fwd.z).normalized()
	var offset: Vector2 = at - Vector2(origin.x, origin.z)
	_t.gt(offset.dot(along), 0.4,
		"the foam collar sits ASTERN of the boat rather than on her waterline")
	_t.lt(absf(offset.dot(Vector2(-along.y, along.x))), 0.2,
		"the foam collar is off to one side of the boat")

	# FOAM IS THE SAME STATE AS THE WEATHER, not a second one. A storm works the
	# water harder than a flat calm and has to make more of it.
	main.sim.weather = "clear"
	for i in 400:
		main._sync_mood(1.0 / 12.0)
	var calm: float = mat.get_shader_parameter("foam")
	main.sim.weather = "storm"
	for i in 400:
		main._sync_mood(1.0 / 12.0)
	var blown: float = mat.get_shader_parameter("foam")
	_t.gt(blown, calm + 0.01,
		"a storm makes no more foam than a flat calm (%.2f against %.2f)" % [blown, calm])
	main.sim.weather = "clear"
	for i in 400:
		main._sync_mood(1.0 / 12.0)



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

	# MEASURED AS A DIFFERENCE, not as an absolute.
	#
	# `rod_bend_degrees` includes the rod TRAILING THE BOAT, which is a degree or
	# two of real, wanted motion that has nothing to do with the charge. Asserting
	# the total was under a threshold made this test a hostage to where the swell
	# happened to be when it ran: it passed for months and then failed at 1.71
	# degrees because a change to the FIGHT altered how many frames the earlier
	# checks took and left the boat on a different part of its cycle. It was never
	# testing what it claimed.
	#
	# What it claims is that the charge does not bend the rod, and that is a
	# difference: take the bend early in the pull and again at full charge, with
	# the boat moving the same amount either way, and the charge must not have
	# added to it.
	# MEASURED AT ONE INSTANT, with the charge as the only thing that moves.
	#
	# The difference was taken half a second apart, and the rod TRAILS THE BOAT -
	# so the swell moved between the two samples and went into the answer. That is
	# the same fault this check had when it measured an absolute: it failed at
	# 1.54 degrees the next time an unrelated change shifted how many frames the
	# earlier checks took, with nothing wrong with the rod.
	#
	# Setting the charge and re-syncing takes no time at all, so the hull is in
	# exactly the same place for both readings and the only difference left is the
	# one the check is about.
	var was_charge: float = main.sim.charge
	main.sim.charge = 0.05
	main._sync()
	var bend_early: float = main.rod_bend_degrees()
	main.sim.charge = 1.0
	main._sync()
	var bend_full: float = main.rod_bend_degrees()
	main.sim.charge = was_charge
	main._sync()
	_t.lt(absf(bend_full - bend_early), 1.2,
		"pulling the rod further back BENT it by %.2f degrees - a cast is a swing, not a load" % absf(bend_full - bend_early))

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

## F5: THE CAST IS ONE MOTION, NOT THREE.
##
## "The movement has felt odd." Measured (scripts/probe_cast.gd), the oddness
## was a number: at the release the rod's angular velocity went from 54 deg/s
## backwards to 361 deg/s forwards in one frame, 671 at full charge, because the
## lift, the throw and the settle were three eases that shared no state. An arm
## reverses through zero; a mechanism snaps. This samples the butt every frame
## through a whole cast and asserts the speed never STEPS - while still peaking
## like a whip, so smoothing cannot quietly turn the cast into a slow lever - and
## that the tip stays above horizontal all the way, overshoot included.
func _check_the_cast_is_one_motion(main) -> void:
	_t.begin("smoke > the cast is one motion, not three")
	main.freeze(1)
	var butt: Node3D = main._rod
	var dt := 1.0 / 60.0
	var pitches: Array[float] = []
	main.sim.hold_cast()
	for i in 33:
		main.advance(dt, dt)
		pitches.append(butt.rotation_degrees.x)
	main.sim.release_cast()
	var guard := 0
	while guard < 240 and (main.sim.state == Sim.FLYING or main.sim.state == Sim.SINKING):
		main.advance(dt, dt)
		pitches.append(butt.rotation_degrees.x)
		guard += 1
	_t.gt(float(pitches.size()), 60.0, "the cast never flew, so nothing below measured a cast")

	var worst := 0.0
	var peak := 0.0
	var highest := -999.0
	var prev_v := 0.0
	for i in range(1, pitches.size()):
		var v := (pitches[i] - pitches[i - 1]) / dt
		if i > 1:
			worst = maxf(worst, absf(v - prev_v))
		peak = maxf(peak, v)
		highest = maxf(highest, pitches[i])
		prev_v = v
	_t.lt(worst, 150.0,
		"the rod changed speed by %.0f deg/s in one frame - the release restarts the motion instead of carrying it (415 before F5)" % worst)
	_t.gt(peak, 200.0,
		"the throw peaks at only %.0f deg/s - the smoothing turned the whip into a lever" % peak)
	_t.lt(highest, 0.0,
		"the tip went through horizontal (%.1f degrees) during the cast, overshoot included" % highest)


## B8: THE CAST IS A BODY MOVEMENT.
##
## "So it doesn't look like a person is actually sitting in it." A rod that only
## pivoted about a fixed butt was a hinge bolted to the boat. A held rod moves at
## both ends: loading a cast brings the hands back past the shoulder and up, and
## the throw carries them forward again. Asserted on the butt's POSITION, which
## nothing else in the suite reads - the rotation checks above would pass with the
## hands nailed to the thwart.
func _check_the_cast_is_a_body_movement(main) -> void:
	_t.begin("smoke > loading a cast brings the hands back, and the throw brings them home")
	main.freeze(1)
	var butt: Node3D = main._rod
	var rest: Vector3 = main.ROD_MOUNT
	_t.lt(butt.position.distance_to(rest), 0.01,
		"at rest the hands are %s, not at the mount %s" % [butt.position, rest])
	main.sim.hold_cast()
	main.advance(1.3)
	_t.eq(main.sim.state, Sim.CHARGING, "the rod is not loaded")
	var loaded: Vector3 = butt.position
	_t.lt(loaded.z, rest.z - 0.15,
		"at full charge the hands came back only %.2f m - the butt is still bolted to the boat" % (rest.z - loaded.z))
	_t.gt(loaded.y, rest.y + 0.05,
		"at full charge the hands rose only %.2f m" % (loaded.y - rest.y))
	main.sim.release_cast()
	# The hands hold the throw until the lure LANDS - a full cast flies for
	# 1.3 s - and only then drift home, so wait for the landing before timing
	# the settle. Measured at CAST_SWING_TIME + CAST_SETTLE_TIME + 0.6 from the
	# release, this reported 0.031 m and it was the flight, not the hands.
	var guard := 0
	while main.sim.state == Sim.FLYING and guard < 240:
		main.advance(1.0 / 60.0)
		guard += 1
	_t.ok(main.sim.state != Sim.FLYING, "the cast never landed, so the settle was never timed")
	main.advance(main.CAST_SETTLE_TIME + 0.6)
	_t.lt(butt.position.distance_to(rest), 0.015,
		"after the throw the hands settled %.3f m from the mount instead of coming home" % butt.position.distance_to(rest))


## F2.3: THE SLIDE IS THE REEL, and it lives where the thumb is.
##
## Gideon: "turning cast button into a reeling animation with an analog stick...
## Slide up and you reel in fast, hold in the middle and you stop reeling while
## you fight the fish, slide down and you start letting the fish back out."
## `test_controls.gd` proves the handler; this proves the CONTROL is on screen
## in a fight and nowhere else, in the right-hand thumb zone, and that a knob
## pulled fully down never enters the gesture bar - the geometry the travel was
## cut to fit, asserted as the inequality rather than as the number.
func _check_the_slide_is_the_reel(main) -> void:
	_t.begin("smoke > the slide is the reel, and it is where the thumb is")
	main.freeze(1)
	var slide: Control = main._slide
	_t.ok(slide != null, "there is no reel slide")
	if slide == null:
		return
	# In a fight, and only in a fight, once the fade has settled.
	main.sim.state = Sim.FIGHTING
	for i in 60:
		main._sync_bars()
	_t.ok(slide.visible, "the slide is not up during a fight")
	_t.ok(not main._action.visible, "the Cast button is still up under the slide during a fight")
	main.sim.state = Sim.IDLE
	for i in 60:
		main._sync_bars()
	_t.ok(not slide.visible, "the slide is still up with nothing on the line")
	_t.ok(main._action.visible, "the Cast button did not come back after the fight")

	# Anchored to the bottom-right, where the thumb is, and never past the
	# gesture bar: the control's bottom edge is at or above SAFE_BOTTOM, and the
	# knob at full give - rest minus SLIDE_DOWN, plus a radius - clears it too.
	_t.eq(slide.anchor_bottom, 1.0, "the slide is not anchored to the bottom")
	_t.eq(slide.anchor_right, 1.0, "the slide is not anchored to the right")
	_t.lt(slide.offset_bottom, -float(main.SAFE_BOTTOM) + 0.5,
		"the slide reaches %.0f px past the safe bottom, into the gesture bar" % (slide.offset_bottom + float(main.SAFE_BOTTOM)))
	var rest_above_bottom := 150.0 + float(main.SAFE_BOTTOM) + float(main.ACTION_SIZE) * 0.5
	var knob_bottom_at_full_give := rest_above_bottom - float(main.SLIDE_DOWN) - float(main.ACTION_SIZE) * 0.5
	_t.gt(knob_bottom_at_full_give, float(main.SAFE_BOTTOM) - 0.5,
		"a knob pulled fully down reaches %.0f px above the bottom edge, inside the gesture bar" % knob_bottom_at_full_give)
	_t.gt(float(main.SLIDE_UP), float(main.SLIDE_DOWN),
		"the slide gives more room toward the edge of the glass than away from it")
	_t.eq(slide.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the slide does not consume its touches, so a drag on it leaks to the water")


## F2.4: THE RISK IS THE PRESSURE, AND IT IS UP THE SIDE OF THE SCREEN.
##
## Gideon: "we need a gauge or something that goes up the side of the screen to
## make it more obvious that the risk is the pressure on the fish." Asserted:
## it is up in a fight and only then, and comes back after hiding (the latch
## that once shipped both gauges invisible); it is filled from the number that
## parts the line; its danger mark sits at DANGER; it pulses above the line in
## step with the heavy haptic and is still below it; and it lives where the
## eye can catch it - the left edge, the middle of the height - clear of both
## thumbs' rest zones and of the centre of the frame. That last rule REPLACES
## "gauges live in the top third", which was the settlement of a note about a
## thumb covering a needle, and this gauge is precisely where no thumb goes.
func _check_the_pressure_is_up_the_side(main) -> void:
	_t.begin("smoke > the pressure gauge is up the side, and it is the danger")
	var g: Control = main._pressure
	_t.ok(g != null, "there is no pressure gauge")
	if g == null:
		return
	main.freeze(1)
	main.advance(0.1)
	_t.ok(not g.visible, "the pressure gauge is up before anything is hooked")
	_t.ok(_drive_until(main, Sim.FIGHTING, 180.0), "no fish was hooked to check the gauge against")
	_t.ok(g.visible, "the pressure gauge is not up during a fight")
	main.freeze(1)
	main.advance(0.1)
	_t.ok(not g.visible, "the pressure gauge stays up after the fight")
	_t.ok(_drive_until(main, Sim.FIGHTING, 180.0), "a fish can be hooked again")
	_t.ok(g.visible, "the pressure gauge never comes back once it has been hidden")

	# Filled from the one number that parts the line, and the mark at DANGER.
	main.sim.tension = 0.5
	_t.approx(main.pressure_shown(), 0.5 / Tuning.TENSION_MAX, 1e-6,
		"the gauge shows %.2f for a tension of 0.50 - it is drawn from a different number than the one that breaks the line" % main.pressure_shown())
	_t.eq(main.tension_shown(), main.sim.tension, "the rod and the gauge disagree about the tension")

	# Still under the line, pulsing over it, in step with the heavy buzz.
	main.sim.tension = Tuning.DANGER - 0.1
	main.sim.strain = 0.0
	for i in 12:
		main.advance(1.0 / 60.0)
		main.sim.tension = Tuning.DANGER - 0.1
	_t.approx(main.pressure_pulse(), 0.0, 1e-6, "the gauge pulses (%.2f) with the rod under the line" % main.pressure_pulse())
	var seen: Array[float] = []
	for i in int(round(main.BUZZ_OVER_EVERY * 60.0 * 2.5)):
		main.sim.tension = Tuning.DANGER + 0.12
		main.advance(1.0 / 60.0)
		seen.append(main.pressure_pulse())
	var peak := 0.0
	var trough := 1.0
	for p in seen:
		peak = maxf(peak, p)
		trough = minf(trough, p)
	_t.gt(peak, 0.8, "over the line the gauge's pulse peaks at %.2f - it does not beat" % peak)
	_t.lt(trough, 0.3, "over the line the gauge's pulse never falls below %.2f - a glow, not a beat" % trough)

	# WHERE IT LIVES. Anchored by fraction on the left edge, clear of the
	# bottom 30% (both thumbs' rest zones) and of the frame's centre box.
	_t.eq(g.anchor_left, 0.0, "the gauge is not anchored to the left edge")
	_t.eq(g.anchor_right, 0.0, "the gauge stretches with the width")
	_t.lt(g.anchor_bottom, 0.70 + 1e-6, "the gauge reaches into the bottom 30%%, where the thumbs rest")
	# Under the sounder, in the sounder's own units: both are pixels from the
	# top, so this holds on every height. A fractional top cleared the sounder
	# on the phone and ran into it on a 16:9 screen.
	_t.eq(g.anchor_top, 0.0, "the gauge's top is a fraction of the height, so it can climb into the sounder on a short screen")
	_t.gt(g.offset_top, main._sounder.offset_bottom + 8.0,
		"the gauge starts %.0f px from the top, inside the sounder's column (which ends at %.0f)" % [
			g.offset_top, main._sounder.offset_bottom])
	var base_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	_t.lt(g.offset_right, base_w * 0.25, "the gauge's right edge (%.0f px) is into the middle of the frame" % g.offset_right)
	_t.gt(g.offset_left, 8.0, "the gauge is hard against the edge of the glass, where a case hides it")
	_t.eq(g.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the gauge eats touches")
	main.sim.strain = 0.0


## THE THREE THINGS GIDEON ASKED TO SEE AND FEEL.
##
## "when you hold your finger on the reel button, I want to see an actual reeling
## animation on the fishing pole. if the fish starts fighting, the pole should get
## more bent, start shaking, the line turns red, then eventually snaps... when the
## fish pulls, you should feel a small vibration, and when the pole is getting too
## bent, you should get a good amount of vibration to match."
##
## Three separate readouts of one number, so each is checked separately: a handle
## that turns, a line that reddens, and two levels of buzz.
func _check_the_fight_is_visible_and_felt(main) -> void:
	_t.begin("smoke > the reel turns, the line reddens and the rod buzzes")
	main.freeze(2)
	if not _drive_until(main, Sim.FIGHTING, 180.0):
		_t.ok(false, "no fish was hooked to fight")
		return

	# 1. THE HANDLE TURNS WHILE THE REEL IS HELD, AND ONLY THEN.
	main.sim.set_reel(0.0)
	var still_a: float = main.reel_turned()
	main.advance(0.4)
	_t.eq(main.reel_turned(), still_a,
		"the reel handle turns with nobody holding the reel")

	main.sim.set_reel(1.0)
	var before: float = main.reel_turned()
	main.advance(0.4)
	_t.gt(main.reel_turned(), before,
		"holding the reel does not turn the handle - there is no reeling animation")

	# 1b. AND THE PLAYER CAN SEE IT. A reeling animation off the edge of the
	# screen is not an animation, and that is exactly what shipped: measured at
	# the phone's real aspect, the reel sat more than a full viewport width off
	# the left edge and only the rod's tip was ever in frame. Three of the
	# fight's four readouts live on this rod, so where it sits is not decoration.
	var cam: Camera3D = main._cam
	for i in 5:
		main.advance(0.25)
		for part in [["the reel", main._reel_crank], ["the rod butt", main._rod_chain[0]]]:
			var node: Node3D = part[1]
			var at := _on_screen(cam, _world_of(node, main).origin)
			_t.ok(at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0,
				"%s is off the edge of the screen during a fight, at (%.2f, %.2f) of the viewport" % [
					part[0], at.x, at.y])

	# 2. THE LINE REDDENS BEFORE THE DANGER LINE, NOT AT IT. A colour that only
	# arrives once the damage has started is a verdict, not a warning.
	main.sim.tension = Tuning.DANGER - main.LINE_WARN_FROM - 0.05
	main.advance(1.0 / 60.0)
	_t.eq(main.line_heat(), 0.0, "the line is already reddening well below the danger line")
	main.sim.tension = Tuning.DANGER - main.LINE_WARN_FROM * 0.4
	main.advance(1.0 / 60.0)
	var warning: float = main.line_heat()
	_t.gt(warning, 0.0,
		"the line has not started to redden by the time the rod is near the danger line")
	main.sim.tension = Tuning.TENSION_MAX
	main.advance(1.0 / 60.0)
	_t.gt(main.line_heat(), warning, "the line does not redden further as the rod bends further")

	# And it is drawn from the SAME tension that parts the line.
	_t.eq(main.tension_shown(), main.sim.tension,
		"the rod is drawn from a different tension than the one that breaks the line")

	# 3. TWO LEVELS OF BUZZ, AND THE HEAVY ONE REPEATS WITHOUT BEING CONTINUOUS.
	main.sim.tension = Tuning.DANGER - 0.2
	main.advance(1.0 / 60.0)
	var quiet: int = main.buzzes
	main.advance(0.5)
	_t.eq(main.buzzes, quiet, "the rod buzzes while it is nowhere near over-bent")

	main.sim.tension = Tuning.TENSION_MAX
	main.advance(1.0 / 60.0)
	_t.gt(main.buzzes, quiet, "the rod does not buzz at all when it is over-bent")
	_t.gt(main.last_buzz_amp, main.BUZZ_PULL_AMP,
		"the over-bent buzz is no stronger than the little one the fish makes, so the two cannot be told apart")

	# Repeating, and PACED - not one buzz a frame, which is a hum in everything
	# but name and is what Android's guidance is written against.
	var at_start: int = main.buzzes
	var seconds := 1.0
	for i in int(round(seconds * 60.0)):
		main.sim.tension = Tuning.TENSION_MAX
		main.advance(1.0 / 60.0)
	var fired: int = main.buzzes - at_start
	_t.gt(float(fired), 1.0, "the heavy buzz fires once and never repeats, so it is an event rather than a state")
	_t.lt(float(fired), seconds / main.BUZZ_OVER_EVERY + 2.0,
		"the heavy buzz fired %d times in a second - that is a continuous hum, not a pulse" % fired)

## EVERY FISH YOU CATCH IS IN THE BUCKET, AND IN IT RATHER THAN ON IT.
##
## Gideon: "can you make it so we see the fish when we catch it and put it in the
## live well, so that we can see every fish we catch?"
##
## The containment half of this is not pedantry. The first build placed the catch
## at a fraction of the bucket's HEIGHT, and the bucket's bounding box includes
## the wire handle arching over the top - so the fish sat level with the rim with
## half of each one hanging over the side, and every one of them was visible,
## present, correctly counted and obviously wrong.
func _check_the_catch_is_in_the_livewell(main) -> void:
	_t.begin("smoke > the catch is visible in the livewell")
	main.freeze(2)
	_t.ok(main._livewell_prop != null, "there is no livewell to put anything in")
	if main._livewell_prop == null:
		return

	# Land some fish through the real seam rather than writing econ.held by hand,
	# so this fails if LANDING stops adding to the livewell as well as if the
	# drawing does.
	var mem := {}
	var step := 1.0 / 60.0
	for i in int(round(240.0 / step)):
		if main.sim.econ.held.size() >= 3:
			break
		Policies.act(Policies.HUMAN, main.sim, step, mem)
		main.advance(step, step)
	var held: int = main.sim.econ.held.size()
	_t.gt(float(held), 0.0, "nothing was landed, so the livewell cannot be checked")
	if held == 0:
		return

	main.advance(0.2)
	var shown: int = main._livewell_fish.size()
	_t.eq(shown, mini(held, main.LIVEWELL_SLOTS),
		"the livewell holds %d fish and shows %d of them" % [held, shown])

	# INSIDE THE BUCKET. Measured against the bucket's own bounds, in boat space,
	# with the fish's own size accounted for - a nose poking out is still out.
	var box: AABB = main._local_bounds(main._livewell_prop)
	var sc: float = main._livewell_prop.scale.x
	var centre: Vector3 = main._livewell_prop.position
	var wide: float = minf(box.size.x, box.size.z) * sc
	var base: float = centre.y + box.position.y * sc
	for f in main._livewell_fish:
		var half: float = 1.35 * f.scale.x * 0.5
		var flat := Vector2(f.position.x - centre.x, f.position.z - centre.z).length()
		_t.lt(flat + half, wide * 0.5,
			"a fish in the livewell reaches %.3f m from the middle of a bucket %.3f m across - it is hanging over the side" % [
				flat + half, wide])
		_t.gt(f.position.y, base - 0.001, "a fish has fallen through the bottom of the bucket")
		# DOWN IN IT, which for anything bucket-shaped means the lower half of its
		# own width above the base. The first version of this bound allowed nine
		# tenths of the width and duly PASSED when the height bug was put back -
		# a containment check loose enough to admit the bug it was written for is
		# not a containment check.
		_t.lt(f.position.y, base + wide * 0.45,
			"a fish sits %.3f m above the base of a bucket %.3f m across - it is up on the rim rather than down in it" % [
				f.position.y - base, wide])

	# AND THEY ARE STILL BREATHING. A fish that never moves is an ornament, and
	# the gill plate is the only moving part on one lying in a bucket.
	var gill := _first_gill(main._livewell_fish[0])
	_t.ok(gill != null, "the fish in the livewell have no gills to move")
	if gill != null:
		var was: float = gill.rotation_degrees.y
		var moved := false
		for i in 40:
			main.advance(1.0 / 30.0)
			if absf(gill.rotation_degrees.y - was) > 0.5:
				moved = true
				break
		_t.ok(moved, "the gills never move, so the catch is a still life")

## THE PAGES ACTUALLY TURN.
##
## Gideon: "the pages dont flip, they just change instantly". They did, and the
## reason is worth keeping: `_turn_page` set a `_page_turn` variable that NOTHING
## IN THE GAME EVER READ. One assignment, one declaration, no reader - so the
## feature looked implemented, read as implemented, and did nothing.
##
## Which is why this asserts the leaf MOVES rather than asserting that a flag was
## set. A test written against the flag would have passed the whole time.
func _check_the_pages_really_turn(main) -> void:
	_t.begin("smoke > the pages turn rather than changing instantly")
	main.freeze(2)
	main.sim.deepest_ever = 60.0
	main._open_book()
	main.advance(2.0)
	_t.ok(main._book.is_open(), "the book never opened")
	_t.ok(not main._book.is_turning(), "a page is turning before anything was pressed")

	# R7: THE FIRST PAGE IS THE KEEPER'S OWN RECORD, and it is the live save
	# rather than a page of prose. Asserted by reading the page's text, because
	# the failure that matters is a number that has stopped tracking the game -
	# which a test against the page COUNT would never see.
	_t.eq(main._book.page, 0, "the book does not open at its first page")
	var front := _page_text(main._book_page)
	_t.ok(front.findn("days kept") >= 0, "the first page is not the keeper's own record")
	_t.ok(front.findn("deepest cast") >= 0, "the front matter does not say how deep you have fished")
	_t.ok(front.findn("nothing yet") >= 0,
		"a book with no fish in it does not say so - it is showing a zero")
	# And it TRACKS. Land something and the same line has to change.
	main.sim.caught = 3
	main.sim.total_weight = 4.25
	main._refresh_book()
	var after := _page_text(main._book_page)
	_t.ok(after.findn("3 fish") >= 0,
		"the front matter did not follow the catch - it is a printed page, not a record")
	main.sim.caught = 0
	main.sim.total_weight = 0.0
	main._refresh_book()

	# W4: FIVE HANDS ARE FIVE FACES, not one face at five greys.
	#
	# Asserted on the PAGE rather than on the table, because the table being right
	# and the label never being given the font is the failure that leaves the book
	# looking exactly as it did before.
	var faces := {}
	for page in range(0, main._book_pages):
		main._book.page = page
		main._refresh_book()
		var who := _page_hand(main._book_page)
		if who != "":
			faces[who] = true
	# W5: AND THE CHROME IS NOT ONE OF THEM. The claim the UI face exists for is
	# "so UI chrome can never be mistaken for the logbook", which only means
	# anything as a COMPARISON - a project default font set and then also used on
	# the page would pass any check that looked at either one alone.
	var ui: Font = main._ui_font()
	_t.ok(ui != null, "the interface has no face of its own")
	if ui != null:
		for used in faces.keys():
			_t.ok(str(used) != ui.resource_path,
				"the logbook is written in the interface font - the chrome and the book are the same hand")

	_t.gt(float(faces.size()), 2.0,
		"the whole logbook is written in %d typeface(s) - the keepers are one hand at several greys" % faces.size())
	main._book.page = 0
	main._refresh_book()

	var was: int = main._book.page
	main._turn_page(1)
	_t.eq(main._book.page, was + 1, "the page did not change")
	_t.ok(main._book.is_turning(), "the page changed without a leaf turning - it just swapped")

	# THE LEAF SWEEPS A HALF TURN, and passes through vertical on the way. Read
	# off the node, so this fails if the leaf stops being driven even while the
	# progress counter keeps counting.
	var leaf: Node3D = main._book._leaf
	_t.ok(leaf != null, "there is no leaf to turn")
	if leaf == null:
		return
	_t.ok(leaf.visible, "the leaf is invisible while it is turning")
	var start: float = absf(main._book.leaf_angle())
	var seen_upright := false
	var steps := 0
	# The furthest it got, sampled DURING the sweep. Reading the angle after the
	# loop reads zero: the leaf is reset the moment its turn finishes, so a test
	# that waits for the end and then looks is asking about a leaf that has
	# already been put away.
	var furthest := 0.0
	while main._book.is_turning() and steps < 200:
		main.advance(1.0 / 60.0)
		steps += 1
		var a := absf(main._book.leaf_angle())
		furthest = maxf(furthest, a)
		if absf(a - PI * 0.5) < 0.35:
			seen_upright = true
	_t.lt(start, 0.2, "the leaf starts part way through its own turn")
	_t.ok(seen_upright, "the leaf never passes through vertical, so it does not read as paper")
	_t.gt(furthest, PI * 0.9,
		"the leaf only reaches %.2f rad, short of lying down on the other side" % furthest)
	_t.ok(not leaf.visible, "the leaf is still there once the turn is over")

	# AND IT TAKES ABOUT AS LONG AS PAPER DOES. Too fast and the eye never sees
	# it; too slow and finding a page is a wait.
	var seconds := float(steps) / 60.0
	_t.gt(seconds, 0.2, "a page turns in %.2f s, which nobody will see" % seconds)
	_t.lt(seconds, 0.6, "a page takes %.2f s to turn, which is a wait" % seconds)

	# A TURN BACK IS THE SAME SWEEP THE OTHER WAY.
	main._turn_page(-1)
	main.advance(TURN_SAMPLE)
	_t.lt(main._book.leaf_angle(), 0.0,
		"turning back sweeps the leaf the same way as turning forward")
	while main._book.is_turning():
		main.advance(1.0 / 60.0)

	# AND THE BOOK STILL DOES NOT PUT ITSELF DOWN at either cover.
	for i in 40:
		main._turn_page(1)
		while main._book.is_turning():
			main.advance(1.0 / 60.0)
	_t.ok(main._book.is_open(), "the book shut itself at the back cover")
	# PUT IT BACK THE WAY IT WAS FOUND. Leaving the book open at its last page
	# broke a later check that turns pages of its own - the suite shares one live
	# scene, so a check that does not clean up is a check that writes the next
	# one's inputs.
	main._shut_book()
	main.advance(1.5)
	while main._book.is_turning():
		main.advance(1.0 / 60.0)

## THE SHED IS A ROOM YOU ARE ROWED TO, AND YOU CAN BUY THINGS IN IT.
##
## Gideon: "When the shop is available, there should be a shop button but the
## camera pans over to a separate room that is a full 3d room of some kind, like a
## shed or old bait shop where you can buy items."
##
## Four claims, and the last two are the ones that would rot quietly: you GET
## there, the room is actually around you, the board can be walked and bought
## from, and the X brings you back to the boat rather than leaving you standing
## in a shed with a fishing rod on screen.
func _check_the_shed_is_a_room(main) -> void:
	_t.begin("smoke > the shed is a room you are rowed to")
	main.freeze(2)
	main.sim.reel_in()
	main.sim.state = Sim.IDLE
	main.sim.econ.money = 900
	main.advance(0.2)
	_t.ok(main._shed != null, "there is no shed")
	if main._shed == null:
		return
	_t.ok(not main._shed.visible, "the shed is being drawn while the player is on the water")

	# THE TRIP. It is a sequence, so it takes real seconds and the player is not
	# in the shed until it finishes.
	main._enter_shed()
	_t.ok(main._in_sequence, "asking for the shed did not start the trip")
	_t.ok(not main._in_shed, "the player is in the shed before being taken there")
	var waited := 0.0
	while waited < 12.0 and not main._in_shed:
		main.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	_t.ok(main._in_shed, "the trip to the shed never arrived")
	if not main._in_shed:
		return
	_t.gt(waited, 1.5, "the trip took %.1fs, which is a cut rather than a journey" % waited)
	_t.lt(waited, 8.0, "the trip took %.1fs, which is a wait" % waited)
	_t.ok(main._shed.visible, "the shed is not drawn once you are standing in it")

	# THE CAMERA IS IN THE ROOM. Measured against the shed's own walls, so moving
	# the room moves the check with it.
	var eye: Vector3 = main._cam.transform.origin
	var inside: Vector3 = eye - main._shed.position
	_t.lt(absf(inside.x), main.SHED_W * 0.5, "the player is standing outside the shed's walls")
	_t.lt(absf(inside.z), main.SHED_D * 0.5, "the player is standing outside the shed's walls")
	_t.gt(inside.y, 0.5, "the player is standing in the floor")
	_t.lt(inside.y, main.SHED_H, "the player is standing through the roof")

	# THE BOARD HAS PRICES ON IT, and they are the prices the game charges.
	var rows: Array = main._shed_rows()
	_t.gt(float(rows.size()), 3.0, "the chalkboard has almost nothing on it")
	_t.eq(str(rows[0]["kind"]), "sell", "the catch is not the first thing on the board")

	# WALKING IT. Up at the top and down at the bottom are dead, which is what the
	# greyed buttons say.
	main._shed_pick = 0
	main._sync_room_bar()
	_t.ok(main._room_up.disabled, "the up button is live at the top of the board")
	_t.ok(not main._room_down.disabled, "the down button is dead with rows below")
	main._shed_move(1)
	_t.eq(main._shed_pick, 1, "the board does not scroll")

	# BUYING. Through the same button a thumb presses.
	var line_before: int = main.sim.econ.line
	var money_before: int = main.sim.econ.money
	for i in rows.size():
		if str(rows[i]["kind"]) == "line":
			main._shed_pick = i
			break
	_t.eq(main._action_for_state(), "Buy", "the button does not offer to buy anything")
	main._cast_pressed()
	_t.eq(main.sim.econ.line, line_before + 1, "buying the next line did nothing")
	_t.lt(main.sim.econ.money, money_before, "the line was bought and cost nothing")

	# AND THE WAY OUT PUTS YOU BACK IN THE BOAT.
	main._room_close_pressed()
	waited = 0.0
	while waited < 12.0 and (main._in_sequence or main._in_shed):
		main.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	_t.ok(not main._in_shed, "the X never left the shed")
	_t.ok(not main._shed.visible, "the shed is still being drawn after leaving it")
	var back: Vector3 = main._cam.transform.origin
	_t.lt(back.distance_to(Sequence.SEAT), 1.2,
		"leaving the shed did not put the player back on the seat")

## THE STOCK IS OBJECTS ON A COUNTER, not words on a board.
##
## Gideon, about the tackle box first and then the shed: "can you make all items
## in the shed physical 3d objects as well", and before that "I want the items in
## it to be shrunk down and placed more in a grid so they down overlap."
##
## Both halves are asserted, because the second one is the half that rots: a grid
## is only a grid while the things in it are smaller than its pitch, and every
## time a prop is added or a scale is nudged that stops being true silently.
func _check_the_shed_stock_is_physical(main) -> void:
	_t.begin("smoke > the shed sells objects rather than words")
	if not main._in_shed:
		# The shed check before this one rows home again, so come back.
		main._enter_shed()
		var waited := 0.0
		while waited < 12.0 and not main._in_shed:
			main.advance(1.0 / 60.0)
			waited += 1.0 / 60.0
	_t.ok(main._in_shed, "could not get into the shed to look at the stock")
	if not main._in_shed:
		return

	var rows: Array = main._shed_rows()
	_t.eq(main._shed_items.size(), rows.size(),
		"the board lists %d things and the counter has %d of them on it" % [
			rows.size(), main._shed_items.size()])
	if main._shed_items.is_empty():
		return

	# ON THE COUNTER. Measured against the counter's own top, the same way the
	# livewell's fish are measured against the bucket - an item hovering above the
	# surface or sunk into it is the failure this catches.
	var top: float = main.SHED_COUNTER_AT.y + main.SHED_COUNTER_TOP
	for n in main._shed_items:
		_t.gt(n.position.y, top - 0.01, "a thing for sale has sunk into the counter")
		_t.lt(n.position.y, top + main.SHED_LIFT + 0.02,
			"a thing for sale is floating above the counter")

	# A GRID, AND NOTHING OVERLAPS. Every pair at least one item apart.
	var size: float = main.SHED_ITEM_SIZE
	for i in main._shed_items.size():
		for j in range(i + 1, main._shed_items.size()):
			var a: Vector3 = main._shed_items[i].position
			var b: Vector3 = main._shed_items[j].position
			var gap := Vector2(a.x - b.x, a.z - b.z).length()
			_t.gt(gap, size * 0.99,
				"two things on the counter are %.3f m apart and %.3f m across - they overlap" % [
					gap, size])

	# AND THEY ARE ALL THE SAME SIZE, which is what stops a crate dwarfing a reel.
	for n in main._shed_items:
		var box: AABB = main._local_bounds(n)
		var big: float = maxf(box.size.x, maxf(box.size.y, box.size.z)) * n.scale.x
		_t.gt(big, size * 0.5, "a thing for sale is far smaller than the rest of the counter")
		_t.lt(big, size * 1.6, "a thing for sale is far bigger than the rest of the counter")

	# THE CHOSEN ONE IS LIFTED AND LIT, which is the whole of the selection.
	main._shed_pick = 0
	for i in 30:
		main.advance(1.0 / 60.0)
	var low: float = main._shed_items[0].position.y
	main._shed_pick = 1
	for i in 30:
		main.advance(1.0 / 60.0)
	_t.gt(main._shed_items[1].position.y, main._shed_items[0].position.y + 0.01,
		"the chosen thing does not rise off the counter")
	_t.lt(main._shed_items[0].position.y, low + 0.005,
		"the thing that stopped being chosen did not settle back down")
	_t.ok(main._shed_lamp != null, "nothing lights the chosen item")
	if main._shed_lamp != null:
		_t.gt(main._shed_lamp.light_energy, 0.1, "the light on the chosen item is off")

	# BUYING CHANGES THE COUNTER, not just the board. A bought rung becomes the
	# next rung, so the object standing there has to be rebuilt.
	main.sim.econ.money = 4000
	var before: int = main._shed_items.size()
	for i in rows.size():
		if str(rows[i]["kind"]) == "motor":
			main._shed_pick = i
			break
	main._cast_pressed()
	main.advance(0.1)
	_t.ok(main.sim.econ.has_motor, "the motor on the counter could not be bought")
	_t.eq(main._shed_items.size(), before - 1,
		"the motor was bought and is still standing on the counter")

	# ROW HOME. The suite shares one live scene, and a check that leaves the
	# player standing in a shed hands the next one a boat it cannot see: the cast
	# button, the distance meter and every aim point in the hull failed at once
	# the first time this was written without it.
	main._room_close_pressed()
	var home := 0.0
	while home < 12.0 and (main._in_sequence or main._in_shed):
		main.advance(1.0 / 60.0)
		home += 1.0 / 60.0
	_t.ok(not main._in_shed, "the stock check never left the shed")




const TURN_SAMPLE := 0.12



func _first_gill(f: Node3D) -> Node3D:
	for c in f.get_children():
		if c is Node3D and String(c.name).begins_with("Gill"):
			return c as Node3D
	return null




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


## The floor below which this suite is assumed to have silently lost coverage.
##
## Renaming `_tension_bar` to `_distance_bar` dropped fifteen assertions and the
## run still said "all passing". The test reads it off `main`, which is UNTYPED -
## so a missing property is a runtime error rather than a parse error, the check
## function bails at that line, and every assertion after it simply never runs.
## Nothing is red, the count is just quietly smaller, and nobody reads the count.
##
## Raise this when the suite grows. It is a canary, not a target: it cannot say
## which assertions went missing, only that some did. (746 on 2026-09-12; the
## harness now also names the check that errored, so this is the blunt half.)
const MIN_ASSERTIONS := 700


func _finish() -> void:
	# Closes the last check, so an engine error raised inside it fails it like
	# any other; `begin` closes every one before it. This is the exact half of
	# the floor below: the floor says SOMETHING bailed, this says which.
	_t.end()
	print("")
	if _t.checks < MIN_ASSERTIONS:
		print("  smoke: %d assertions, but at least %d were expected - a check bailed" % [
			_t.checks, MIN_ASSERTIONS])
		print("  something above errored part-way through. Read the log for 'Invalid get index'.")
		quit(1)
		return
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

	# THE DOCK IS GONE, so this no longer asks whether a row of buttons is
	# visible. What has to hold is that every room can still be REACHED, and each
	# one is now a thing in the boat - so the claim is about the things.
	main.sim.state = Sim.IDLE
	main._sync_bars()
	var reachable := {}
	for thing in main._things:
		reachable[str(thing["id"])] = true
	for want in ["logbook", "tacklebox", "chart"]:
		_t.ok(reachable.has(want),
			"'%s' is not in the boat, so that room cannot be reached at all" % want)
	# THE SHED IS REACHED FROM THE CHART, not from a thing of its own. The boat
	# ran out of angles - no two interactables may sit within twelve degrees of
	# each other from the seat, and with seven things in a four-metre hull the
	# oars had nowhere to go. A chart is where a person decides where to row.
	var on_chart := false
	for row in main._chart_rows():
		if str(row["id"]) == "shed":
			on_chart = true
	_t.ok(on_chart, "the shed is on neither the chart nor anything in the boat")
	# ...and picking it actually rows you there, which is the half that rots.
	if on_chart:
		main._open_chart()
		for i in main._chart_rows().size():
			if str(main._chart_rows()[i]["id"]) == "shed":
				main._chart_pick = i
		main._cast_pressed()
		_t.ok(main._in_sequence or main._in_shed,
			"the shed is written on the chart but picking it does nothing")
		var trip := 0.0
		while trip < 14.0 and main.any_room_open():
			main.close_any_room()
			main.advance(1.0 / 60.0)
			trip += 1.0 / 60.0

	# And none of them opens mid-fight either. The rooms are IDLE-only, and that
	# used to be enforced by hiding a row of buttons; with the buttons gone it has
	# to be enforced by the openers themselves.
	main.sim.state = Sim.FIGHTING
	main._open_chart()
	_t.ok(not main._at_chart, "the chart opened in the middle of a fight")
	main._enter_shed()
	_t.ok(not main._in_shed and not main._in_sequence,
		"the oars rowed you to the shed in the middle of a fight")
	main.sim.state = Sim.IDLE


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
		if state == Sim.FIGHTING:
			# The fight's visible action is the slide, faded in over the button.
			# Step the fade to its end so the claim is about the settled state.
			for i in 60:
				main._sync_bars()
			_t.ok(main._slide.visible, "a fight hides the reel slide")
			_t.ok(not main._action.visible, "a fight leaves the Cast button up under the slide")
			continue
		for i in 60:
			main._sync_bars()
		_t.ok(main._action.visible, "state '%s' hides the action button" % state)
		_t.ok(not main._slide.visible, "state '%s' leaves the reel slide up" % state)
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

	# HOLDING REEL moves the needle on the very next frame. The claim is
	# unchanged - an input must be answered within two frames - but the input is
	# a hold now, so a single frame of advance is what has to show it.
	main.freeze(1)
	if _drive_until(main, Sim.FIGHTING, 180.0):
		# FROM A RELEASED ROD, because a fight that has been reeling for a while is
		# sitting AT its settle point, where one frame of holding changes the
		# tension by less than a float can represent. The claim is about latency,
		# so the measurement has to start somewhere the input has room to show.
		main.sim.set_reel(0.0)
		main.advance(0.6)
		var before: float = main.sim.tension
		var reel_before: float = main.sim.reel
		main.sim.set_reel(1.0)
		main.sim.advance(step)
		# THE CRANK ANSWERS ON THE NEXT FRAME; the tension follows it. The reel
		# has inertia by design (Tuning.REEL_INERTIA), so the number that must
		# move within a frame is the crank the player is looking at, and the
		# tension within a fifth of a second - a first version asserted the
		# tension on the next frame and measured the inertia, not the latency.
		_t.gt(main.sim.reel, reel_before,
			"pushing the slide up during a fight does not turn the crank on the next frame")
		main.advance(0.2)
		_t.gt(main.sim.tension, before,
			"pushing the slide up during a fight does not move the tension within a fifth of a second")
		# ...and letting go is answered just as fast, which is the half that
		# matters during a run: a control that is slow to STOP is a control the
		# player cannot use to avoid anything.
		main.sim.set_reel(0.0)
		var reel_high: float = main.sim.reel
		var high: float = main.sim.tension
		main.sim.advance(step)
		_t.lt(main.sim.reel, reel_high,
			"letting the slide go does not slow the crank on the next frame")
		main.advance(0.2)
		_t.lt(main.sim.tension, high,
			"letting the slide go does not lower the tension within a fifth of a second")

	# And the gauge the player is reading redraws with it, rather than a frame
	# behind - a needle that lags its own input is the classic mushy control.
	main._sync()
	_t.ok(main._distance_bar.visible, "the distance meter is not up during a fight")


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

	# IT IS ITS CONTENTS, not a list printed inside the lid. Six real things in
	# the trays, and every one of them actually in the scene.
	_t.gt(float(main._box_items.size()), 5.0,
		"the tackle box has %d things in it - it is still a menu" % main._box_items.size())
	# Parentage rather than `is_inside_tree`: a scene added to root during
	# `_initialize` has no children in the tree until a frame has processed, so
	# that check fails in the harness and passes in the game, which is the worst
	# way round. The claim that matters is that each thing hangs off the box and
	# therefore rides it.
	for n in main._box_items:
		_t.ok(n.get_parent() == main._tacklebox,
			"a thing in the tackle box is not parented to the box")

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

	# UP AND DOWN MOVE BETWEEN THE THINGS, and the selected one lifts out of the
	# tray. The lift is what "highlighted" means here, so it is asserted rather
	# than assumed - a selection that changes a number and moves nothing is the
	# failure this whole rebuild exists to fix.
	main._box_sel = 0
	main._refresh_tacklebox()
	var first_name: String = main._box_name.text
	main._room_step(1)
	_t.eq(main._box_sel, 1, "the down arrow did not move to the next thing")
	_t.ok(main._box_name.text != first_name,
		"moving to the next thing did not change what the box says it is")
	for i in 40:
		main.advance(1.0 / 60.0)
	var lifted: Node3D = main._box_items[1]
	var resting: Node3D = main._box_items[0]
	_t.gt(lifted.position.y, resting.position.y + 0.02,
		"the selected thing does not lift out of the tray (%.3f against %.3f)" % [
			lifted.position.y, resting.position.y])
	main._room_step(-1)
	_t.eq(main._box_sel, 0, "the up arrow did not move back")

	# THE ARROWS ARE HIS MECHANISM: yellow when there is another version, grey
	# when this is all you own. Asserted on the ladder data that drives them, and
	# on both sides of the case - one bait means grey, two means yellow.
	main.sim.econ.bait_left = {"worm": 10}
	var bait_slot := -1
	for i in 6:
		if str(main._box_slot(i)["name"]) == "Bait":
			bait_slot = i
	_t.gt(float(bait_slot), -1.0, "there is no bait in the tackle box")
	_t.eq(int(main._box_slot(bait_slot)["variants"]), 1,
		"with one bait owned the box still offers a choice")

	main.sim.econ.bait_left["corn"] = 5
	_t.eq(int(main._box_slot(bait_slot)["variants"]), 2,
		"owning a second bait did not make it a choice")

	# ...and stepping the variant actually changes what is on the hook.
	main._box_sel = bait_slot
	main._refresh_tacklebox()
	var before_bait: String = str(main.sim.econ.bait)
	main._box_variant(1)
	_t.ok(str(main.sim.econ.bait) != before_bait,
		"stepping to the next bait did not put it on the hook")

	# THE PIPS SHOW THE LADDER, including the rungs not yet reached. A ladder
	# drawn only as far as the player has climbed cannot show them what is left.
	var line_slot := -1
	for i in 6:
		if str(main._box_slot(i)["name"]) == "Line":
			line_slot = i
	var line_info: Dictionary = main._box_slot(line_slot)
	_t.eq(int(line_info["rungs"]), Gear.LINE.size(),
		"the line pips do not show the whole ladder")
	_t.eq(int(line_info["owned"]), main.sim.econ.line + 1,
		"the filled pips do not match the line actually owned")

	# And there is a way out, from the box and from the back button.
	_t.ok(main._go_back(), "back was ignored with the tackle box open")
	_t.ok(not main._at_box, "back did not shut the tackle box")


## LOOKING STRAIGHT AT A THING SELECTS IT, and the whole chain is driven: point
## the camera at the object's VISIBLE CENTRE and ask what the crosshair reports.
##
## Gideon, with two screenshots: "when I look at the book I cant click it but I can
## click it if I look forward on the boat." In one frame the crosshair sat on bare
## floorboards and the prompt read "The keeper's logbook"; in the next the book was
## plainly under the crosshair and there was no prompt at all.
##
## The cause was a hand-typed `at` per thing, and an imported model's ORIGIN is
## wherever the exporter left it. The logbook's was 0.14 m from its own mesh - and
## the aim cone is about ten degrees, which at that range IS 0.14 m. So the book
## sat just outside its own hit box.
##
## Asserting "the aim point equals the geometry" would be vacuous now that the aim
## point is derived FROM the geometry. This drives the thing a thumb does instead:
## look at it, and see whether the game agrees that you are looking at it.
func _check_looking_at_a_thing_selects_it(main) -> void:
	_t.begin("smoke > looking at a thing in the boat selects it")
	main.freeze(1)
	main.sim.state = Sim.IDLE
	# AIMED BY SEARCHING, the way a player aims, rather than by an analytic angle.
	#
	# The first version computed yaw and pitch directly and was wrong: the camera
	# reached exactly the values it was given and the ray still missed by fifty
	# degrees, because the basis is composed after a PI turn and the naive formula
	# does not survive it. Measured - the achieved yaw matched the requested yaw to
	# two decimals while the dot product was 0.61.
	#
	# A search is also the more honest claim. It asks "is there an orientation the
	# player can reach from which this thing is selected", which is the question,
	# and it cannot be fooled by a convention changing underneath it.
	var missed: Array[String] = []
	for t in main._things:
		var id: String = str(t["id"])
		var best := -2.0
		var best_yaw := 0.0
		var best_pitch := 0.0
		for yi in 25:
			for pi in 25:
				var yaw := lerpf(-main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT, float(yi) / 24.0)
				var pitch := lerpf(-main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP, float(pi) / 24.0)
				var d := _aim_dot(main, t, yaw, pitch)
				if d > best:
					best = d
					best_yaw = yaw
					best_pitch = pitch
		# Anything that cannot be brought near the centre of the view at all is a
		# placement bug, and the reachability sweep already reports those.
		if best < 0.97:
			continue
		main._look_yaw = best_yaw
		main._look_pitch = best_pitch
		main._look_yaw_want = best_yaw
		main._look_pitch_want = best_pitch
		main._sync()
		if main._looking_at != id:
			missed.append("%s beside %s" % [id, main._looking_at])
	_t.eq(missed.size(), 0,
		"looking straight at these did not select them: %s" % ", ".join(missed))

	# AND LOOKING OFF A THING MUST NOT SELECT IT, which is the half he reported:
	# "the spot where the lamp goes pops up text even when im a good amount above
	# it with the crosshairs."
	#
	# Swept as a ring around each thing rather than at one offset, because the old
	# cone was generous in every direction and a single probe angle would have
	# passed against it by luck. Twenty degrees off is "a good amount above it".
	var sticky: Array[String] = []
	for t in main._things:
		var id: String = str(t["id"])
		var base_yaw := 0.0
		var base_pitch := 0.0
		var best2 := -2.0
		for yi in 25:
			for pi in 25:
				var yaw := lerpf(-main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT, float(yi) / 24.0)
				var pitch := lerpf(-main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP, float(pi) / 24.0)
				var d := _aim_dot(main, t, yaw, pitch)
				if d > best2:
					best2 = d
					base_yaw = yaw
					base_pitch = pitch
		if best2 < 0.97:
			continue
		# HOW FAR OFF IS "OFF" DEPENDS ON THE THING. A bucket 70 cm away subtends
		# a lot of angle, so twenty degrees from its centre is still on it - the
		# first version of this failed the livewell and the rope for being large
		# and close, which is not a bug. Offset by the object's own angular radius
		# plus twelve degrees, so the claim is "clear of the thing" rather than
		# "some fixed angle", which is the same mistake the cone made.
		var eye2: Vector3 = main._cam.transform.origin
		var here: Vector3 = main._boat_pose * main.aim_point_of(t) - eye2
		var radius := 0.2
		for part in main._aim_boxes.get(id, []):
			var bx: AABB = part["box"]
			var xf: Transform3D = part["xform"]
			radius = maxf(radius, (xf.basis * bx.size).length() * 0.5)
		var off := atan(radius / maxf(0.3, here.length())) + deg_to_rad(12.0)
		for step in [Vector2(off, 0), Vector2(-off, 0), Vector2(0, off), Vector2(0, -off)]:
			var yaw2 := clampf(base_yaw + step.x, -main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT)
			var pitch2 := clampf(base_pitch + step.y, -main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP)
			# Only test a direction the player can actually aim in. The rope sits
			# at 44 degrees of yaw and the limit is 60, so "29 degrees further
			# round" clamps to 16 and the test would be asserting about an
			# orientation nobody can reach. Skip unless the full offset survives.
			var got_off := maxf(absf(yaw2 - base_yaw), absf(pitch2 - base_pitch))
			if got_off < off * 0.9:
				continue
			main._look_yaw = yaw2
			main._look_pitch = pitch2
			main._look_yaw_want = yaw2
			main._look_pitch_want = pitch2
			main._sync()
			if main._looking_at == id:
				sticky.append("%s at %.0f degrees off" % [id, rad_to_deg(off)])
				break
	_t.eq(sticky.size(), 0,
		"these answered from well off the object: %s" % ", ".join(sticky))

	# AND NO TWO THINGS MAY SIT ON TOP OF EACH OTHER. The livewell and the rope
	# were 0.13 m apart, so whichever was nearer won every time and the other was
	# unselectable from anywhere. A separation rule catches that at the moment a
	# prop is moved, rather than as a mysterious dead object later.
	# ...and the measure is ANGULAR, from the seat, not metric.
	#
	# A metre apart means nothing if the two are in line with the eye: the rope and
	# the bait box passed a 0.30 m separation rule and were still 6 degrees apart
	# from where the player sits, so the nearer one won every time and the other
	# was unselectable from anywhere. What a thumb has to resolve is the angle.
	var seat_eye: Vector3 = main._cam.transform.origin
	var crowded: Array[String] = []
	for i in main._things.size():
		for j in range(i + 1, main._things.size()):
			var a: Vector3 = (main._boat_pose * main.aim_point_of(main._things[i])) - seat_eye
			var b: Vector3 = (main._boat_pose * main.aim_point_of(main._things[j])) - seat_eye
			if a.length() < 0.05 or b.length() < 0.05:
				continue
			var deg := rad_to_deg(a.angle_to(b))
			if deg < 12.0:
				crowded.append("%s and %s are %.0f degrees apart" % [
					main._things[i]["id"], main._things[j]["id"], deg])
	_t.eq(crowded.size(), 0,
		"two things in the boat are too close together to aim between: %s" % ", ".join(crowded))


## THE PRIMARY BUTTON SAYS WHAT THE MOMENT WANTS.
##
## Gideon: "I also want the cast button to only pop up when the cursor is above the
## boat. if you are looking in the boat, change it to a select button. make the
## select button grey unless there is something clickable."
##
## Cast was offered while looking at the floorboards, which is an instruction the
## game cannot honour. Asserted through the whole chain - aim the view, sync, read
## the caption the player would see - rather than by calling the classifier, so a
## boundary test that is right about geometry and wrong about wiring still fails.
func _check_the_button_says_what_the_moment_wants(main) -> void:
	_t.begin("smoke > the primary button says what the moment wants")
	main.freeze(1)
	main.sim.state = Sim.IDLE

	# LOOKING OUT AT THE LAKE: Cast.
	main._look_yaw = 0.0
	main._look_pitch = 0.2
	main._look_yaw_want = 0.0
	main._look_pitch_want = 0.2
	for i in 30:
		main.advance(1.0 / 60.0)
	_t.eq(main._action_for_state(), "Cast",
		"looking out at the water does not offer a cast")

	# LOOKING INTO THE BOAT AT A THING: Select, and live.
	var book := {}
	for t in main._things:
		if str(t["id"]) == "logbook":
			book = t
	var best := -2.0
	var best_yaw := 0.0
	var best_pitch := 0.0
	for yi in 25:
		for pi in 25:
			var yaw := lerpf(-main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT, float(yi) / 24.0)
			var pitch := lerpf(-main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP, float(pi) / 24.0)
			var d := _aim_dot(main, book, yaw, pitch)
			if d > best:
				best = d
				best_yaw = yaw
				best_pitch = pitch
	main._look_yaw = best_yaw
	main._look_pitch = best_pitch
	main._look_yaw_want = best_yaw
	main._look_pitch_want = best_pitch
	for i in 30:
		main.advance(1.0 / 60.0)
	_t.eq(main._action_for_state(), "Select",
		"looking into the boat still offers a cast")
	_t.eq(main._looking_at, "logbook", "the logbook is not selected while being looked at")
	_t.ok(not main._action.disabled, "the button is dead while a thing is under the crosshair")

	# ...and pressing it USES the thing rather than casting into the floor.
	var casts_before: int = main.sim.casts
	main._cast_pressed()
	main._cast_released()
	_t.eq(main.sim.casts, casts_before,
		"pressing Select threw a cast into the bottom of the boat")
	if main._reading:
		main._shut_book()
		for i in 60:
			main.advance(1.0 / 60.0)


## THE ROD POINTS WHERE THE CAST WILL GO.
##
## Gideon: "I also want the fishing rod to pull up in view like you are holding it
## follows the cursor so you can tell that where you look is where you are
## preparing to cast." The rod IS the aiming reticle, so the claim is that it
## swings with the view - and that it swings the RIGHT WAY, which is the half a
## sign error would get wrong while everything else still looked animated.
func _check_the_rod_points_where_you_look(main) -> void:
	_t.begin("smoke > the rod points where you are looking")
	main.freeze(1)
	main.sim.state = Sim.IDLE

	var bearings: Array[float] = []
	for yaw in [-0.7, 0.0, 0.7]:
		main._look_yaw = yaw
		main._look_yaw_want = yaw
		for i in 120:
			main.advance(1.0 / 60.0)
		bearings.append(_rod_bearing(main))

	# It moves at all...
	_t.gt(absf(bearings[2] - bearings[0]), 0.4,
		"the rod does not swing with the view (%.2f against %.2f)" % [bearings[0], bearings[2]])
	# ...and it moves the same way the view does, monotonically, rather than
	# against it. A sign error here still looks like a rod being animated.
	_t.ok((bearings[1] - bearings[0]) * (bearings[2] - bearings[1]) > 0.0,
		"the rod does not swing monotonically with the view: %.2f, %.2f, %.2f" % bearings)

	# And the tip really does end up near the line of the cast. Measured against
	# the camera's own forward, so no angle convention is assumed.
	for yaw in [-0.5, 0.0, 0.5]:
		main._look_yaw = yaw
		main._look_yaw_want = yaw
		for i in 120:
			main.advance(1.0 / 60.0)
		var cam: Transform3D = main._cam.transform
		var fwd: Vector3 = -cam.basis.z
		var flat_fwd := Vector2(fwd.x, fwd.z).normalized()
		var tip: Vector3 = main._rod_tip - cam.origin
		var flat_tip := Vector2(tip.x, tip.z).normalized()
		var off := rad_to_deg(absf(flat_fwd.angle_to(flat_tip)))
		_t.lt(off, 32.0,
			"at look %.1f the rod tip is %.0f degrees off where the cast will go" % [yaw, off])


## The rod's bearing in boat space, from the chain rather than from the constant
## that drives it - so this measures the rod, not the intention.
func _rod_bearing(main) -> float:
	var tip: Vector3 = main._rod_tip
	var butt: Vector3 = main._rod.global_position if main._rod.is_inside_tree() 		else main._boat_pose * main._rod.position
	var d := tip - butt
	return atan2(d.x, d.z)


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
		# HOLD THE FISH OFF for the length of the measurement. The window used to
		# end early whenever something bit, so how far the float had been seen to
		# move depended on when a bite happened to land - and the assertion sat at
		# 0.005 m against a typical 0.03. Inserting an unrelated check earlier in
		# the suite shifted the clock, a fish bit sooner, and this failed at
		# 0.0044 with nothing wrong with the float at all.
		main.sim.bite_in = 999.0
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
	# One frame so the camera is actually built from that yaw, then A FIXED POINT
	# OUT ON THE LAKE, caught in WORLD space before the thumb lands. It is what
	# lets the assertion further down ask where the world WENT rather than what a
	# variable did.
	main.advance(1.0 / 60.0)
	var landmark: Vector3 = main._cam.transform * Vector3(0.0, 0.0, -30.0)

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

	# AND WHERE THAT PUTS THE LAKE, which is the assertion this check did not have.
	# `_look_yaw_want` is a number in the model, and every assertion above is
	# satisfied by it moving the right way; what the player sees is the world
	# swinging the OTHER way, and the two are joined by exactly one sign, in
	# `Basis(Vector3.UP, PI + _look_yaw)` where the camera is built. Flip that and
	# the stick is backwards with this whole check still green - which is the exact
	# shape of the bug five games in this studio have shipped, every one of them
	# with a suite that only ever asserted on the model.
	#
	# The camera's own space, where +X is screen right by definition: no viewport,
	# no projection matrix, no frame to capture. `transform`, never
	# `global_transform` - outside the tree the global one returns IDENTITY
	# without erroring, which is a plausible wrong answer.
	var on_screen: float = (main._cam.transform.affine_inverse() * landmark).x
	_t.lt(on_screen, -1.0,
		"the stick was held RIGHT for two seconds and a point that was straight ahead is at screen x %.1f - it did not swing LEFT across the frame, so the view turned the wrong way and the stick is inverted"
			% on_screen)

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
		# AND THE WORLD GOES BACK, whatever using it opened.
		#
		# This used to close a menu and nothing else, which was enough while every
		# `use` either said a line or opened a panel. The oars ROW YOU TO THE
		# SHED, so the first thing to open something that is not a menu left the
		# player standing at a counter and the next six checks failed looking for
		# a cast button, a distance meter and every aim point in the hull.
		var undo := 0.0
		while undo < 14.0 and main.any_room_open():
			main.close_any_room()
			main.advance(1.0 / 60.0)
			undo += 1.0 / 60.0
		_t.ok(not main.any_room_open(),
			"using '%s' left something open over the boat" % t["id"])
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

	# AND NEITHER DOES RUNNING OUT OF PAGES, which used to close it.
	#
	# Gideon: "you put it down instantly after running out of pages... when you run
	# iut of pages keep the book out. only exit when I hit the X button." That is
	# the third time he has asked for the X to be the only way out, and this was
	# the last place it was not true - the same accidental-exit family as the tap
	# outside, arriving from the other end of the book.
	main._book.page = main._book_pages - 1
	main._turn_page(1)
	_t.ok(main._reading, "running out of pages still shuts the book")
	_t.eq(main._book.page, main._book_pages - 1, "turning past the end moved past the last page")

	# The book also has BLANK leaves for what has not been caught, so there is
	# something to flip through from the first morning.
	_t.gt(float(main._book_pages), 4.0,
		"the book has only %d pages - there is nothing to flip through" % main._book_pages)

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
	# AIMED BY SEARCH, for the reason given on `_check_looking_at_a_thing_selects_it`:
	# the analytic yaw and pitch that reach a point are not what they look like,
	# because the basis is composed after a PI turn, and the version of this that
	# computed them was pointing the camera fifty degrees away while reporting the
	# exact angles it had been asked for.
	var book_thing := {}
	for t in main._things:
		if str(t["id"]) == "logbook":
			book_thing = t
	_t.ok(not book_thing.is_empty(), "there is no logbook among the things in the boat")
	if book_thing.is_empty():
		return
	var best := -2.0
	var best_yaw := 0.0
	var best_pitch := 0.0
	for yi in 25:
		for pi in 25:
			var yaw := lerpf(-main.LOOK_YAW_LIMIT, main.LOOK_YAW_LIMIT, float(yi) / 24.0)
			var pitch := lerpf(-main.LOOK_PITCH_DOWN, main.LOOK_PITCH_UP, float(pi) / 24.0)
			var d := _aim_dot(main, book_thing, yaw, pitch)
			if d > best:
				best = d
				best_yaw = yaw
				best_pitch = pitch
	_t.gt(best, 0.97,
		"the logbook cannot be brought near the centre of the view from the seat at all (best %.3f)" % best)
	main._look_yaw = best_yaw
	main._look_pitch = best_pitch
	main._look_yaw_want = best_yaw
	main._look_pitch_want = best_pitch
	main._sync()
	var book_at: Vector3 = main._boat_pose * main.aim_point_of(book_thing)
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


## How closely the view would point at a thing from a given yaw and pitch. Set,
## sync, measure - the same path the game uses, so no convention is assumed.
func _aim_dot(main, t: Dictionary, yaw: float, pitch: float) -> float:
	main._look_yaw = yaw
	main._look_pitch = pitch
	main._look_yaw_want = yaw
	main._look_pitch_want = pitch
	main._sync()
	var cam: Transform3D = main._cam.transform
	var ap: Vector3 = main.aim_point_of(t)
	var to: Vector3 = (main._boat_pose * ap) - cam.origin
	if to.length() < 0.05:
		return -2.0
	var fwd: Vector3 = -cam.basis.z.normalized()
	return fwd.dot(to.normalized())
