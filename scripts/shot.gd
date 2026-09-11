extends SceneTree

## Take a screenshot of the real game at a chosen moment.
##
##   godot --path . --resolution 460x996 --script res://scripts/shot.gd -- 14.0
##
## **NOT headless**: this needs a real rendering context, which is the whole
## point. Every other check in this repo runs without a GPU and can therefore
## tell you the numbers are right and nothing at all about whether the picture
## is. This is the only tool here that can answer "does it look wrong".
##
## Three things about it are load bearing.
##
## **Use the PHONE's aspect ratio, not the project's base one.** The project is
## 1080x1920 and the phone is about 19.5:9, and with `stretch/aspect = "expand"`
## the canvas the game actually renders into is roughly 1080x2340. A screenshot
## at 540x960 is a screenshot of a layout the phone never sees - and a HUD bug
## that put controls hundreds of pixels off shipped precisely because every
## check was taken at the base size, where the wrong layout and the right one
## are identical. 460x996 is the phone.
##
## **Freeze before advancing**, or how far the run has got depends on how long
## the window took to open. Going through the same seam the tests use means the
## same second of the same level is captured every time, which is what makes two
## screenshots taken a week apart comparable at all.
##
## **Play it, do not watch it.** A passive run is a picture of the game not
## being played, and the drawing paths that only fire on an impact never run.

## A second argument names a STATE to stop at, which matters more than it sounds.
##
##   godot --path . --resolution 460x996 --script res://scripts/shot.gd -- 60 hooking
##
## Capturing "at 24.5 seconds" means guessing which moment of the game that is,
## and the moments worth photographing are the short ones - the hook bar is up
## for about three seconds a cast. Both HUD gauges shipped invisible partly
## because the one screenshot taken of them happened to land mid-fight, which is
## the single state in which that bug does not show.
var _main
var _frames := 0
var _seconds := 12.0
var _until := ""
var _tag := ""

## Second-argument values that name a ROOM rather than a fishing state.
const ROOMS := ["shed", "map", "log", "kit", "boat", "title", "gate", "arrive", "book", "box",
	"well"]
## `turn` is deliberately NOT in ROOMS. Everything in that list gets the
## room-opening block near the shutter - reel in, back to IDLE, two advances -
## which was quietly resetting a page turn between setting it up and
## photographing it. Three separate real bugs were chased before the tool turned
## out to be one of them.
const MID_ACTION := ["turn", "inshed", "hull"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seconds = float(args[0])
	if args.size() > 1:
		_until = String(args[1])
	if args.size() > 2:
		_tag = "_".join(PackedStringArray(args.slice(2)))

	var scene: PackedScene = load("res://src/game/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	_main.freeze()
	# Past the title, and past the intro. Both are worth photographing on their
	# own - `-- 2 title` does that - but every other shot wants the game.
	if _until == "box":
		# Open the tackle box and let the lid and the camera settle over it.
		if _main._title != null:
			_main._title.skip()
		_main._open_tacklebox()
		var xt := 0.0
		while xt < 2.0:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			xt += 1.0 / 60.0
	elif _until == "book":
		# Open the logbook and let the camera settle on the page.
		if _main._title != null:
			_main._title.skip()
		_main.sim.deepest_ever = 60.0
		_main._open_book()
		var bt := 0.0
		while bt < 3.0:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			bt += 1.0 / 60.0
		if _seconds > 3.0:
			# `-- 5 book` photographs page two.
			#
			# This used to tap a fixed screen point, and it broke silently the day
			# the book started being HELD rather than read on the floor: the page
			# moved, the ray missed it, and a miss shuts the book - so every
			# screenshot of "the logbook" came back as an empty boat with no
			# error anywhere. Ask for the page turn directly. A tool that reaches
			# a state through screen coordinates breaks whenever the picture
			# changes, which is exactly when the tool is needed.
			_main._turn_page(1)
			for i in 30:
				_main.advance(1.0 / 60.0, 1.0 / 60.0)
	elif _until == "hull":
		# OVER THE SIDE, at the waterline. The foam collar round the hull is the
		# whole of W1 and it is invisible from the seat looking forward, because
		# the gunwale is between the eye and the water it breaks against. A
		# feature you cannot photograph is a feature nobody will see.
		if _main._title != null:
			_main._title.skip()
		for i in 90:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
		var eye: Vector3 = Sequence.SEAT
		var at := Vector3(-2.40, 0.0, 2.10)
		var to := at - eye
		_main._look_yaw_want = clampf(atan2(to.x, to.z),
			-_main.LOOK_YAW_LIMIT, _main.LOOK_YAW_LIMIT)
		_main._look_pitch_want = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
			-_main.LOOK_PITCH_DOWN, _main.LOOK_PITCH_UP)
		for i in 90:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
	elif _until == "inshed":
		# STANDING AT THE COUNTER. The trip there is a sequence, so this plays it
		# out rather than teleporting - which also means the shot proves the
		# sequence arrives where it says it does.
		if _main._title != null:
			_main._title.skip()
		_main.sim.econ.money = 900
		_main._enter_shed()
		var st := 0.0
		while st < 12.0 and not _main._in_shed:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			st += 1.0 / 60.0
		# The first argument doubles as WHICH ROW is picked, so the lit-and-lifted
		# item can be photographed rather than taken on trust.
		_main._shed_pick = int(_seconds)
		_main._refresh_shed_board()
		for i in 60:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
		print("in shed: %s  after %.1fs  picked %d of %d" % [
			_main._in_shed, st, _main._shed_pick, _main._shed_items.size()])
	elif _until == "turn":
		# MID-TURN. A page turn lasts a third of a second, so the only way to
		# photograph the leaf is to stop the clock inside it - and the leaf is the
		# whole of R6. `-- 0.5 turn` is halfway over, which is where it is upright
		# and catching the light.
		if _main._title != null:
			_main._title.skip()
		_main.sim.deepest_ever = 60.0
		_main._open_book()
		var ot := 0.0
		while ot < 3.0:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			ot += 1.0 / 60.0
		_main._turn_page(1)
		var tt := 0.0
		while tt < _seconds * 0.34:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			tt += 1.0 / 60.0
		print("leaf: visible %s  angle %.1f deg  turning %s  front tex %s" % [
			_main._book._leaf.visible, rad_to_deg(_main._book.leaf_angle()),
			_main._book.is_turning(),
			"yes" if (_main._book._leaf_front.material_override as StandardMaterial3D).albedo_texture != null else "NONE"])
	elif _until == "gate" or _until == "arrive":
		# Photograph a sequence part-way through: `-- 2.0 gate` is two seconds
		# into the walk down to the boat.
		if _main._title != null:
			_main._title.skip()
		_main._play_sequence(Sequence.going_out() if _until == "gate" else Sequence.arriving())
		# `advance` already ticks the sequence - calling `_sync_sequence` here too
		# ran it at double speed and the walk was over before the shutter opened.
		var t := 0.0
		while t < _seconds and _main._in_sequence:
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
			t += 1.0 / 60.0
	elif _until == "title":
		if _main._title != null:
			_main._title.show_again()
			_main._sync()
	else:
		if _main._title != null:
			_main._on_continue()
			for i in 120:
				_main.advance(1.0 / 60.0, 1.0 / 60.0)
		if _main._intro != null:
			_main._intro.finish()

	# One memory for the whole run - see the note on Policies.act. A fresh dict
	# per frame silently stops the bot tapping at all, and the screenshot would
	# then be of a game nobody is playing.
	var step := 1.0 / 60.0
	var mem := {}
	for i in int(round(_seconds / step)):
		if _until != "" and _main.sim.state == _until:
			break
		Policies.act(Policies.HUMAN, _main.sim, step, mem)
		_main.advance(step, step)
	if _until != "" and _main.sim.state != _until and not (_until in ROOMS) \
			and not (_until in MID_ACTION):
		printerr("never reached state '%s' in %.1fs" % [_until, _seconds])

	if _until == "well":
		# LOOK INTO THE BUCKET. The livewell is down and to the left of a seated
		# angler, so a forward-facing screenshot never shows the catch at all -
		# which is exactly how "every fish you catch is visible" could be built,
		# photographed, and still be wrong.
		#
		# Aimed by geometry rather than by a typed yaw: the head turns to where
		# the prop actually is, so moving the bucket moves the shot with it.
		var well = _main._livewell_prop
		if well == null:
			printerr("there is no livewell prop to photograph")
		else:
			var eye: Vector3 = Sequence.SEAT
			var to: Vector3 = well.position - eye
			_main._look_yaw_want = clampf(atan2(to.x, to.z),
				-_main.LOOK_YAW_LIMIT, _main.LOOK_YAW_LIMIT)
			_main._look_pitch_want = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
				-_main.LOOK_PITCH_DOWN, _main.LOOK_PITCH_UP)
			# Let the head actually get there - the look is eased, so setting the
			# want and photographing the same frame photographs the old view.
			for i in 90:
				_main.advance(1.0 / 60.0, 1.0 / 60.0)
		print("livewell holds %d fish" % _main.sim.econ.held.size())

	# A ROOM instead of a state. The shed, the map and the log are built in code
	# from live data, so the only way to find out that a price runs off the edge
	# or a shelf is unreadable is to photograph one with money in the purse and
	# fish in the box - which is what these two lines set up.
	# A third argument sets the HOUR and the fourth the WEATHER, so the twenty-five
	# combinations of the mood arc can each be photographed. They are also the
	# only way to see night: the clock only advances when the player sleeps.
	if args.size() > 2:
		_main.sim.hour = String(args[2])
	if args.size() > 3:
		_main.sim.weather = String(args[3])
	# The sounder is the most expensive thing in the shed, so a screenshot of the
	# game without it is a screenshot of two thirds of the HUD.
	_main.sim.econ.has_sounder = true
	if args.size() > 4:
		# Dread is depth, so this is "photograph it as if the line were this far
		# down" - the whole visual arc in one number.
		_main.sim.econ.line = 5
		_main.sim.spot = String(args[5]) if args.size() > 5 else "spring"
		_main.sim.lure_depth = float(args[4])
		_main.sim.state = Sim.WAITING
	# `_sync` as well as `_sync_mood`, or the HUD in the photograph still says
	# whatever it said before the hour was set - and a screenshot whose caption
	# disagrees with its own picture is worse than no screenshot.
	for i in 400:
		_main._sync_mood(1.0 / 12.0)
	_main._sync()

	# DIAGNOSTIC: a fifth user argument names a node to HIDE before the shutter.
	# "is that white hairline a gap onto the water, or a highlight on the rail"
	# is one screenshot with the water off and one with it on, and no amount of
	# reading the geometry answers it as fast.
	var hide := OS.get_environment("SHOT_HIDE")
	if hide != "":
		var stack: Array = [_main]
		while not stack.is_empty():
			var n = stack.pop_back()
			if str(n.name).findn(hide) >= 0 and n is Node3D:
				(n as Node3D).visible = false
				print("hid ", n.name)
			for c in n.get_children():
				stack.append(c)

	if _until in ROOMS and not (_until in MID_ACTION):
		_main.sim.econ.money = 900
		_main.sim.econ.has_motor = true
		# Deep enough that the book has something in it - a screenshot of an
		# empty logbook says nothing about the logbook.
		_main.sim.deepest_ever = maxf(_main.sim.deepest_ever, 60.0)
		# Back to the boat first. `_open` refuses from anywhere else, on purpose -
		# so a screenshot that just calls it after a minute of play photographs
		# the water and looks like the room is broken.
		_main.sim.reel_in()
		_main.sim.state = Sim.IDLE
		_main.advance(1.0 / 60.0, 1.0 / 60.0)
		# "boat" means: back to the boat, nothing open. The one state a bot never
		# sits in for long, and therefore the one the HUD is hardest to look at.
		# "boat", "title", "gate" and "arrive" are not rooms - they are places to
		# stand. Only the real rooms get opened.
		if _until in ["shed", "map", "log", "kit"]:
			_main._open(_until)
		_main.advance(1.0 / 60.0, 1.0 / 60.0)


func _process(_delta: float) -> bool:
	# A few frames, so the sky, the shadow map and the MultiMesh buffers have
	# actually been drawn once. Capturing on frame one gives a grey rectangle.
	_frames += 1
	if _frames < 5:
		return false
	var img := root.get_texture().get_image()
	var name := "shot" if _until == "" else "shot_" + _until
	if _tag != "":
		name = "shot_" + _tag
	img.save_png("user://%s.png" % name)
	print("wrote %s/%s.png at t=%.1fs" % [OS.get_user_data_dir(), name, _seconds])
	quit(0)
	return true
