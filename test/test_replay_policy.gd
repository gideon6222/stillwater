extends RefCounted

## THE FILMED-RUN GATE. A bot that holds a thumb, asserted rather than assumed.
##
## `scripts/replay_player.gd policy=<name>` asks `Main` where the thumb should
## be and pushes real touches at the viewport. That seam can go inert - a renamed
## method, a policy that never asks for anything, a lift that never comes so the
## second press is swallowed - and the only symptom is a film of a game nobody
## appears to be playing, which is indistinguishable from a film of a game that
## ignores its own button. **The check passes because nothing happened** is the
## fault this studio keeps paying for, so this drives the whole loop through the
## seam and asserts a fish came out of it.
##
## Everything here is arithmetic on a scene that is never added to a tree, so it
## runs in the pure suite. The driver's half (turning edges into touch events) is
## reproduced in `_thumb` below, minus the viewport: a finite point goes DOWN on
## whichever button holds it, INF lifts, and the press goes through the button's
## own signal so the wiring from button to handler is in the loop.

const SPAN := 1080.0
const SIZE := Vector2(1080.0, 2340.0)
const STEP := 1.0 / 60.0


func _game():
	var scene: PackedScene = load("res://src/game/main.tscn")
	var main = scene.instantiate()
	# `freeze()` boots the world explicitly. `_ready` has not fired, so without it
	# `sim` is null and every read below is a non-fatal error that silently deletes
	# the rest of the check.
	main.freeze(1)
	return main


## What replay_player.gd does with the answer. `held` is the driver's memory of
## its own thumb, and it also counts what happened so a test can read it.
func _thumb(main, at: Vector2, held: Dictionary) -> void:
	var down: bool = at.is_finite()
	var was: bool = bool(held.get("down", false))
	if down and was and at.distance_to(held["at"]) > 1.0:
		# Moved to another control: lift now, press next frame.
		down = false
	if down == was:
		return
	held["down"] = down
	if down:
		held["at"] = at
		held["presses"] = int(held.get("presses", 0)) + 1
		if main._action.get_global_rect().has_point(at):
			held["on"] = "action"
			main._action.button_down.emit()
		elif main._back.get_global_rect().has_point(at):
			held["on"] = "back"
		else:
			held["on"] = "nowhere"
			held["misses"] = int(held.get("misses", 0)) + 1
	else:
		if held.get("on", "") == "action":
			main._action.button_up.emit()
		elif held.get("on", "") == "back":
			main._back.pressed.emit()


## A session through the seam, up to `seconds` or until the first fish is in
## the box - a whole renderer tick per frame is not cheap, and the claim is that
## a fish comes out, not how many. Returns what the driver saw.
func _run(main, policy: String, seconds: float) -> Dictionary:
	var mem := {}
	var held := {}
	var moved := 0
	var drags := 0
	for i in int(round(seconds / STEP)):
		if main.sim.caught > 0 and not bool(held.get("down", false)):
			break
		if not main.bot_can_drive():
			main.advance(STEP)
			continue
		var before: int = main.sim.state_snapshot().hash()
		var drag: Vector2 = main.bot_drag_pixels(policy, mem, SPAN)
		var at: Vector2 = main.bot_touch_pixels(policy, mem, SIZE)
		if main.sim.state_snapshot().hash() != before:
			moved += 1
		if drag.length() > 0.0001:
			drags += 1
		_thumb(main, at, held)
		main.advance(STEP)
	held["moved"] = moved
	held["drags"] = drags
	return held


func test_the_game_exposes_the_bot_seam(t: TestHarness) -> void:
	# Named on its own, because every other check in this file reads as "the bot
	# wanted nothing" when a method is simply not there any more.
	var main = _game()
	t.ok(main.has_method("bot_drag_pixels"),
		"Main no longer implements bot_drag_pixels(policy, mem, span), so `policy=` films a game nobody is playing")
	t.ok(main.has_method("bot_touch_pixels"),
		"Main no longer implements bot_touch_pixels(policy, mem, size) - this game is played by pressing, so without it the bot cannot cast")
	t.ok(main.has_method("bot_can_drive"),
		"Main no longer implements bot_can_drive(), so a bot will press through a cinematic and cut it")
	t.ok(main._title != null and main._title.has_method("entry_button"),
		"the title no longer names its entry button, so the bot cannot cross the front door like a player")
	main.free()


func test_the_seam_lands_a_fish_through_the_real_buttons(t: TestHarness) -> void:
	# The one that matters. `play()` proves the sim can be fished; this proves the
	# BUTTONS can, with every press going button -> signal -> handler -> sim, and
	# every decision read off the same policy the balance is measured with.
	var main = _game()
	var saw := _run(main, Policies.ANGLER, 150.0)
	t.gt(float(main.sim.casts), 0.0, "the bot never cast - the cast button is not where bot_touch_pixels thinks it is")
	t.gt(float(main.sim.caught), 0.0,
		"150 s of correct play through the buttons landed nothing (%d casts, %d presses) - the strike or the reel is not reaching the sim through the button" % [main.sim.casts, int(saw.get("presses", 0))])
	t.eq(int(saw.get("misses", 0)), 0,
		"%d presses landed on neither button - the point the bot asks for is not on a control" % int(saw.get("misses", 0)))
	t.gt(float(saw.get("presses", 0)), 3.0,
		"only %d presses in 150 s - the thumb is not lifting between a strike and the reel" % int(saw.get("presses", 0)))
	# The restore is the whole point of the seam. Asked by acting, the bot would
	# take the shortcut AND film it.
	t.eq(int(saw["moved"]), 0, "asking the bot moved the simulation on %d frames - bot_touch_pixels is acting, not reading" % int(saw["moved"]))
	# Nobody in this game's policies looks around, so a drag is the seam
	# inventing input.
	t.eq(int(saw["drags"]), 0, "bot_drag_pixels asked for a drag on %d frames - no policy here looks around" % int(saw["drags"]))
	main.free()


func test_a_bot_that_never_strikes_lands_nothing_through_the_seam(t: TestHarness) -> void:
	# The negative control for the test above. If the game landed fish on its
	# own, "the seam lands a fish" would be true of a seam that does nothing.
	var main = _game()
	var saw := _run(main, Policies.IDLE_HANDS, 45.0)
	t.gt(float(main.sim.casts), 0.0, "idle hands still cast, and cast nothing")
	t.gt(float(saw.get("presses", 0)), 0.0, "idle hands never pressed the button, so it never cast")
	t.eq(main.sim.caught, 0,
		"a bot that never strikes landed %d fish through the seam - the buttons are landing fish the policy did not ask for" % main.sim.caught)
	main.free()


func test_a_loaded_rod_stays_under_the_thumb_until_the_throw(t: TestHarness) -> void:
	# The round trip for the cast, as a property: the bot asks for the button,
	# the press goes through it, the rod loads, and the bot keeps asking for the
	# same point until the policy is ready to throw - then asks for nothing, and
	# the lift IS the throw.
	var main = _game()
	var mem := {}
	var held := {}
	var at: Vector2 = main.bot_touch_pixels(Policies.ANGLER, mem, SIZE)
	t.ok(at.is_finite(), "in the boat with nothing cast the bot does not reach for the cast button")
	t.ok(main._action.get_global_rect().has_point(at),
		"the bot's cast press at %s is not on the cast button %s" % [at, main._action.get_global_rect()])
	_thumb(main, at, held)
	main.advance(STEP)
	t.eq(main.sim.state, Sim.CHARGING, "pressing where the bot asked did not load the rod")
	var frames_held := 0
	while main.sim.state == Sim.CHARGING and frames_held < 600:
		var again: Vector2 = main.bot_touch_pixels(Policies.ANGLER, mem, SIZE)
		if not again.is_finite():
			break
		t.lt(again.distance_to(at), 1.0, "the thumb wandered off the button while the rod was loading")
		_thumb(main, again, held)
		main.advance(STEP)
		frames_held += 1
	t.gt(float(frames_held), Policies.CHARGE_HOLD * 60.0 * 0.8,
		"the bot let go after %d frames, before the policy's %.2f s hold" % [frames_held, Policies.CHARGE_HOLD])
	t.eq(main.sim.state, Sim.CHARGING, "the rod unloaded on its own before the bot let go")
	_thumb(main, Vector2.INF, held)
	main.advance(STEP)
	t.ok(main.sim.state != Sim.CHARGING and main.sim.casts == 1,
		"lifting the thumb did not throw the cast - state %s, %d casts" % [main.sim.state, main.sim.casts])
	main.free()


func test_the_front_door_is_crossed_like_a_player(t: TestHarness) -> void:
	# A filmed run starts at the title. The bot presses the title's own entry
	# button once - never a bypass - and its next answer is the lift.
	var main = _game()
	main._title.show_again()
	var mem := {}
	var at: Vector2 = main.bot_touch_pixels(Policies.ANGLER, mem, SIZE)
	t.ok(at.is_finite(), "with the title up the bot asks for nothing, so no filmed run can ever start")
	# The centre, not `has_point`: a container's children have no size until a
	# tree lays them out, and off-tree the rect is a point. What matters is that
	# the bot reached for the title's button and not the cast button under it.
	var door: Rect2 = main._title.entry_button().get_global_rect()
	t.lt(at.distance_to(door.get_center()), 1.0,
		"the bot's press at %s is not on the title's entry button %s" % [at, door])
	t.gt(at.distance_to(main._action.get_global_rect().get_center()), 1.0,
		"with the title up the bot reaches past it for the cast button")
	var lift: Vector2 = main.bot_touch_pixels(Policies.ANGLER, mem, SIZE)
	t.ok(not lift.is_finite(), "the press on the title never lifts, so the button never fires")
	main._title.skip()
	main.free()


func test_the_bot_is_refused_where_a_thumb_would_do_harm(t: TestHarness) -> void:
	# Pressing through a sequence cuts it; pressing inside a room buys things.
	# Neither fails anything on its own, which is why they are refused here.
	var main = _game()
	t.ok(main.bot_can_drive(), "a freshly booted game refuses to let a bot drive, so no filmed policy run can ever start")
	main._in_sequence = true
	t.ok(not main.bot_can_drive(), "the bot may drive through a sequence, and its first press would cut it")
	main._in_sequence = false
	main.paused = true
	t.ok(not main.bot_can_drive(), "the bot may drive while the app is backgrounded")
	main.paused = false
	main._reading = true
	t.ok(not main.bot_can_drive(), "the bot may drive with the logbook open, where the button is not a cast")
	main._reading = false
	t.ok(main.bot_can_drive(), "the refusals do not clear")
	main.free()
