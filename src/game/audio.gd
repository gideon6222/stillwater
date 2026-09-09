class_name Audio
extends Node

## The mixer. Everything it plays comes from `scripts/make_audio.gd`.
##
## **The music arc is a crossfade, not a playlist.** Four beds run continuously
## from the first second of the game to the last, all in D minor pentatonic and
## all sixteen seconds long, and the only thing that ever changes is how loud
## each one is. Nothing cuts, nothing starts, nothing announces itself - the
## player goes deeper and the bells quietly stop being there.
##
## That is the whole reason it works. A game that switches to Creepy Track 2 at
## forty metres has told the player it is trying to frighten them, and being told
## is the end of it. A mix that moves by a decibel a metre is something they only
## notice by realising they stopped enjoying the sound of the lake at some point
## they cannot place.
##
## `dread` is that one number, and it is DEPTH - the same quantity the whole game
## is built on. Not a story flag, not an act counter: how far down the line
## currently is. Which means the arc runs backwards too. Go and fish the reeds
## after the quarry and the bells come back, and finding out they still exist is
## a stranger feeling than losing them was.

## The beds, as a level at the surface and a level at the bottom. Every bed is
## `lerp(at0, at1, dread ^ curve)`, and that is the whole mixer. An earlier
## version had per-bed ramp windows with special cases for the two that fade
## out, and it was three branches of arithmetic saying what this table says by
## being read.
##
## The four overlap deliberately: there is no depth at which only one thing is
## playing, so nothing ever sounds like it has been switched.
const BEDS := [
	# Always present, and quietly gives up the room to what is under it.
	{"id": "bed_calm", "at0": 1.00, "at1": 0.55, "curve": 1.0, "db": -14.0},
	# THE ONE THAT LEAVES. Most of the first hour, and gone by Old Town. Its
	# absence is the loudest thing in the score, and nothing replaces it.
	{"id": "bed_bells", "at0": 1.00, "at1": 0.00, "curve": 0.65, "db": -17.0},
	{"id": "bed_deep", "at0": 0.00, "at1": 1.00, "curve": 1.0, "db": -13.0},
	# Silent through the whole of Act I. The exponent is what keeps it there: a
	# third of the way down it is still at four per cent.
	{"id": "bed_under", "at0": 0.00, "at1": 1.00, "curve": 2.6, "db": -11.0},
]

## The lake itself. Water is always there; wind answers the weather; the deep
## rumble answers depth and is inaudible on a phone speaker until it is not.
const AMBIENCE := ["amb_water", "amb_wind", "amb_deep"]

const SFX_VOICES := 8

## Every metre from here down is dread 1.0. Not the deepest water in the game -
## the arc has to be complete before the Spring rather than arriving with it, or
## the last band is the only one that sounds like anything.
const DREAD_FULL := 110.0

## How fast the mix follows the water. Slow on purpose: about eight seconds to
## cross, so a single deep cast from a shallow spot does not swing the whole
## soundtrack and back.
const FOLLOW := 0.14

var sim: Sim

var _beds: Array[AudioStreamPlayer] = []
var _amb: Array[AudioStreamPlayer] = []
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _drag: AudioStreamPlayer
var _cache: Dictionary = {}

var _dread := 0.0            ## smoothed, 0 at the surface, 1 in the quarry
var _in_room := 0.0          ## smoothed, 1 while a menu is open
var _muted := false
var _want_playing := false
var _playing := false


## Point the mixer at a different Sim WITHOUT rebuilding it.
##
## `setup` is not idempotent and must never be called twice: it appends to
## `_beds` and `_amb`, so a second call grew them past the tables they index and
## the mix crashed on `BEDS[4]`. Starting a new game needs the sim swapped, not
## nineteen fresh AudioStreamPlayers - the beds are mid-loop and the title is
## fading out over them.
func retarget(s: Sim) -> void:
	sim = s
	_connect(s)


func setup(s: Sim) -> void:
	sim = s
	for row in BEDS:
		_beds.append(_looping(str(row["id"]), float(row["db"])))
	for id in AMBIENCE:
		_amb.append(_looping(id, -18.0))
	_drag = _looping("drag", -60.0)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

	_connect(s)


## Everything the mixer listens to. Split out so `retarget` can re-run it against
## a new Sim; the old connections die with the Sim they were made on.
func _connect(sim: Sim) -> void:
	sim.cast_landed.connect(func(_d: float) -> void: play("splash"))
	sim.nibble.connect(func() -> void: play("nibble", -3.0))
	sim.hooked.connect(func(_id: String, perfect: bool) -> void:
		play("hook", 0.0 if perfect else -4.0))
	sim.tapped.connect(_on_tapped)
	sim.run_started.connect(func() -> void: play("tug", 2.0))
	sim.landed.connect(func(_id: String, _w: float) -> void: play("land"))
	sim.object_found.connect(func(_id: String) -> void: play("clunk"))
	sim.lost.connect(_on_lost)


## Muting has to survive everything, so it is checked at the two places sound
## actually leaves - not by pausing the node, which would also stop the fades and
## leave the mix wherever it was when the player muted.
func set_muted(on: bool) -> void:
	_muted = on


func muted() -> bool:
	return _muted


func _looping(id: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(id, true)
	p.volume_db = db
	add_child(p)
	return p


## Loading sets `loop_mode` on the resource itself rather than editing nineteen
## `.import` files. The cache matters: the same AudioStreamWAV must not be loaded
## twice, or the two copies drift apart in loop settings and one of them clicks.
func _stream(id: String, loop: bool) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := "res://assets/audio/%s.wav" % id
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	_cache[id] = s
	return s


## Start everything that loops.
##
## **Deferred to the tree, not called at build time.** `AudioStreamPlayer.play`
## on a node that is not yet inside the SceneTree is an error per player per
## call, and the scene is built from `_ensure_booted`, which runs before the
## first frame precisely so a headless harness can drive it. So the request is
## remembered and honoured on entry, which also means the headless tests can
## build the whole mixer and assert its levels without nineteen streams actually
## running.
func start() -> void:
	_want_playing = true


## `_ready`, NOT `_enter_tree`, and the difference is the whole fix.
##
## A node added during `SceneTree._initialize` reports `is_inside_tree()` as true
## immediately, so guarding on that looked right and still produced eight
## "Playback can only happen when a node is inside the scene tree" errors on
## every headless run - one per looping player. The flag is set before the tree
## is actually running. `_ready` is deferred to the first PROCESSED frame, which
## is the thing playback really requires, and it is the same seam the rest of
## this scene already uses for exactly this reason.
##
## It also gives the headless tests what they want for free: they never process a
## frame, so nothing ever plays, and the mixer is still fully built and its levels
## still assertable.
func _ready() -> void:
	if _want_playing:
		_start_now()


func _start_now() -> void:
	if _playing:
		return
	_playing = true
	for p in _beds:
		if p.stream != null:
			p.play()
	for p in _amb:
		if p.stream != null:
			p.play()
	if _drag != null and _drag.stream != null:
		_drag.play()


func play(id: String, db: float = 0.0) -> void:
	if _muted:
		return
	var s := _stream(id, false)
	if s == null:
		return
	if not is_inside_tree():
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.stream = s
	p.pitch_scale = 1.0
	p.volume_db = db - 6.0
	p.play()


func _on_tapped() -> void:
	# The reel click is pitched by how hard the rod is loaded, which costs one
	# line and is most of what makes the fight feel like a mechanism. Tapping
	# into the red is audibly straining before the gauge says so.
	if sim.state != Sim.FIGHTING:
		return
	if _muted:
		return
	var s := _stream("reel", false)
	if s == null or not is_inside_tree():
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.stream = s
	p.pitch_scale = 0.86 + 0.5 * clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0)
	p.volume_db = -13.0
	p.play()


func _on_lost(reason: String) -> void:
	play("snap" if reason == Sim.BROKE else "clunk", -4.0)


## The mix, once a frame.
##
## Everything here is a target and a follow, never a set - see FOLLOW. The one
## exception is the drag, which has to arrive with the run rather than eight
## seconds after it.
func tick(dt: float, in_room: bool) -> void:
	if sim == null or _beds.is_empty():
		return

	var want := clampf(sim.lure_depth / DREAD_FULL, 0.0, 1.0)
	# The boat is never entirely at ease once you have been down. Half the dread
	# of the deepest cast this session stays in the mix with the line in, which
	# is why coming back to the reeds sounds like the reeds and not like the
	# first morning.
	if sim.state == Sim.IDLE or sim.state == Sim.CHARGING:
		want = clampf(sim.deepest_here() / DREAD_FULL, 0.0, 1.0) * 0.5
	_dread = lerpf(_dread, want, 1.0 - exp(-FOLLOW * 8.0 * dt))
	_in_room = lerpf(_in_room, 1.0 if in_room else 0.0, 1.0 - exp(-9.0 * dt))

	var master := -80.0 if _muted else 0.0

	for i in _beds.size():
		var row: Dictionary = BEDS[i]
		var k := pow(_dread, float(row["curve"]))
		var level := lerpf(float(row["at0"]), float(row["at1"]), k)
		# The rooms are indoors: the music stays, the lake does not.
		_beds[i].volume_db = master + float(row["db"]) + _db(level)

	# Water is the constant. Wind follows the weather. The deep follows the line.
	var rough := 1.0
	match sim.weather:
		"storm": rough = 2.4
		"rain": rough = 1.6
		"fog": rough = 0.55
		"overcast": rough = 1.0
		_: rough = 0.85
	_amb[0].volume_db = master - 17.0 + _db(1.0 - 0.75 * _in_room)
	_amb[1].volume_db = master - 24.0 + _db(rough * (1.0 - 0.9 * _in_room))
	_amb[2].volume_db = master - 20.0 + _db(_dread * (1.0 - 0.9 * _in_room))

	# The drag is the only sound tied to a single instant of the rules, so it is
	# set rather than followed - a run that has started must be audible NOW.
	var running := sim.state == Sim.FIGHTING and sim.running and not in_room
	_drag.volume_db = master + (-14.0 if running else -80.0)
	if running:
		_drag.pitch_scale = 0.80 + 0.55 * clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0)


## A linear level as decibels, floored so a fade-out actually reaches silence
## rather than approaching it forever.
static func _db(level: float) -> float:
	if level <= 0.0008:
		return -80.0
	return 20.0 * (log(clampf(level, 0.0, 1.0)) / log(10.0))


## What the mix is doing, for the tests. The arc is the one part of the audio
## that is a design claim rather than a taste, so it is the part that is checked.
func mix_snapshot() -> Dictionary:
	var out := {"dread": snappedf(_dread, 0.001)}
	for i in _beds.size():
		out[str(BEDS[i]["id"])] = snappedf(_beds[i].volume_db, 0.01)
	out["drag"] = snappedf(_drag.volume_db, 0.01)
	return out
