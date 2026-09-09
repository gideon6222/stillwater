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
const ROOMS := ["shed", "map", "log"]


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
	if _until != "" and _main.sim.state != _until and not (_until in ROOMS):
		printerr("never reached state '%s' in %.1fs" % [_until, _seconds])

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
	if args.size() > 4:
		# Dread is depth, so this is "photograph it as if the line were this far
		# down" - the whole visual arc in one number.
		_main.sim.econ.line = 5
		_main.sim.spot = "spring"
		_main.sim.lure_depth = float(args[4])
		_main.sim.state = Sim.WAITING
	# `_sync` as well as `_sync_mood`, or the HUD in the photograph still says
	# whatever it said before the hour was set - and a screenshot whose caption
	# disagrees with its own picture is worse than no screenshot.
	for i in 400:
		_main._sync_mood(1.0 / 12.0)
	_main._sync()

	if _until in ROOMS:
		_main.sim.econ.money = 900
		_main.sim.econ.has_motor = true
		# Back to the boat first. `_open` refuses from anywhere else, on purpose -
		# so a screenshot that just calls it after a minute of play photographs
		# the water and looks like the room is broken.
		_main.sim.reel_in()
		_main.sim.state = Sim.IDLE
		_main.advance(1.0 / 60.0, 1.0 / 60.0)
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
