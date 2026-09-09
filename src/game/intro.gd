class_name Intro
extends RefCounted

## THE FIRST MORNING.
##
## Teaches look, cast, watch, strike, reel and keep - in that order, because
## that is the order they happen in - and plants the story on the last beat.
##
## **Every beat ends on a CONDITION, never on a timer**, except the two that are
## pauses on purpose. So the tutorial waits for the player rather than the player
## waiting for the tutorial, and a fast learner is never held behind a sentence
## they have already acted on. The copy disappears the moment the thing is done,
## which means the player's own action finishes the sentence.
##
## **It never blocks input.** The game underneath is the real game from the first
## second; there is no scripted fish, no rails, and nothing here can be failed.
## If a bite is missed the beat simply keeps waiting - and the reeds are the most
## forgiving water in the game precisely so this holds.
##
## Progress is one integer, saved, so it never plays twice.

## Each beat: the line, and what ends it.
##
## `hold` is seconds for the two that are deliberate pauses; every other beat has
## a `done` predicate taking the Sim and returning bool.
const BEATS := [
	{
		"say": "dawn. nothing on the water yet.",
		"hold": 2.6,
	},
	{
		"say": "drag anywhere to look around.",
		"needs": "looked",
	},
	{
		"say": "hold to cast. hold longer to reach further out.",
		"needs": "cast",
	},
	{
		"say": "now watch the float.",
		"needs": "nibbling",
	},
	{
		# The distinction the whole first minigame rests on, said once, at the
		# exact moment it is visible on the water.
		"say": "it is only mouthing the bait. wait for it to go under properly.",
		"needs": "taking",
	},
	{
		"say": "now - tap.",
		"needs": "hooked",
	},
	{
		"say": "tap to reel it in. stop tapping when it runs.",
		"needs": "landed",
	},
	{
		"say": "a bluegill. small, and yours.",
		"hold": 2.8,
	},
	{
		# The hook, and the only line in the intro that is not about fishing.
		"say": "it goes in the book. somebody has written in it before you.",
		"hold": 4.2,
	},
]

var step := 0
var _elapsed := 0.0
var _saw_look := false
var _saw_cast := false
var _saw_nibble := false
var _saw_take := false
var _saw_hook := false
var _saw_land := false


func done() -> bool:
	return step >= BEATS.size()


func line() -> String:
	if done():
		return ""
	return str(BEATS[step]["say"])


## LATCHED FROM SIGNALS, not sampled from state.
##
## The first version read `sim.state` once a frame, and the beat that waits for a
## landed fish never fired: a player who taps straight after a catch leaves
## HOLDING within a single frame, so the state the beat was watching for existed
## for about one frame in every thousand and the sampler walked straight past it.
## The bot landed twenty-five fish and the tutorial sat there waiting for one.
##
## Signals cannot be missed, which is what they are for. Only the two genuinely
## continuous things - whether the view has turned, and whether the float is
## currently under - are still sampled.
func note_look() -> void:
	_saw_look = true


func note_cast() -> void:
	_saw_cast = true


func note_nibble() -> void:
	_saw_nibble = true


func note_hooked() -> void:
	# You cannot hook a fish that never took, so this implies the beat before it.
	_saw_nibble = true
	_saw_take = true
	_saw_hook = true


func note_landed() -> void:
	_saw_land = true


## The two that really are continuous.
func note_state(state: String, taking: bool) -> void:
	if state == Sim.CHARGING or state == Sim.FLYING or state == Sim.SINKING:
		_saw_cast = true
	if taking:
		_saw_take = true


func advance(dt: float) -> void:
	if done():
		return
	_elapsed += dt
	var beat: Dictionary = BEATS[step]

	if beat.has("hold"):
		if _elapsed >= float(beat["hold"]):
			_next()
		return

	var ready := false
	match str(beat["needs"]):
		"looked": ready = _saw_look
		"cast": ready = _saw_cast
		"nibbling": ready = _saw_nibble
		"taking": ready = _saw_take
		"hooked": ready = _saw_hook
		"landed": ready = _saw_land
	if ready:
		_next()


func _next() -> void:
	step += 1
	_elapsed = 0.0


## Skip to the end. For a player who has done this before and for the "New game"
## path when the intro has already been seen once.
func finish() -> void:
	step = BEATS.size()
