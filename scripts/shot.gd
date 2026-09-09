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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seconds = float(args[0])
	if args.size() > 1:
		_until = String(args[1])

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
	if _until != "" and _main.sim.state != _until:
		printerr("never reached state '%s' in %.1fs" % [_until, _seconds])


func _process(_delta: float) -> bool:
	# A few frames, so the sky, the shadow map and the MultiMesh buffers have
	# actually been drawn once. Capturing on frame one gives a grey rectangle.
	_frames += 1
	if _frames < 5:
		return false
	var img := root.get_texture().get_image()
	img.save_png("user://shot.png")
	print("wrote %s/shot.png at t=%.1fs" % [OS.get_user_data_dir(), _seconds])
	quit(0)
	return true
