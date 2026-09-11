class_name Sequence
extends RefCounted

## THE CAMERA, WHEN THE PLAYER IS NOT HOLDING IT.
##
## A list of shots. Each has a position, a point to look at, a duration, an
## easing, and optionally a line of text and how far the gate should be open by
## the end of it. The rig interpolates between consecutive shots, so a sequence
## is written as the places the camera should BE rather than as a path.
##
## **The gate is the whole idea.** The game begins on the wrong side of it, and
## Continue does not start the game so much as let you through - the same walk a
## keeper of this water makes every morning. The ritual and the menu are the
## same motion, which is why the title is a place instead of a picture.
##
## Kept out of `main.gd` because a cinematic is a script, and a script is data.

## Where the boat's seat is, so a sequence can end exactly where play begins and
## the hand-over is invisible.
## WHERE THE PLAYER IS SITTING, and it was not in the boat.
##
## Gideon: "You are too far back in the boat so it doesn't look like a person is
## actually sitting in it."
##
## Measured rather than nudged: the hull is swept from z = -0.85 to z = +2.25, so
## the transom is at -0.85 and the eye was at **-1.90** - a metre and five
## centimetres BEHIND the back of the boat, floating in open water looking at the
## whole vessel. That is why it read as a camera rather than a person; it was
## outside the thing it was supposed to be inside.
##
## The new numbers come off the hull's own profile, from `scripts/probe_seat.gd`:
## at z = 0.70 the floor is 0.20 and the rim is 0.50, so a thwart sits at about
## the rim and a seated eye is roughly 0.70 m above that. Amidships, on the centre
## thwart, which is where a person actually fishes from a boat this size - the
## bow spreads away in front and the gunwales run past on both sides.
const SEAT := Vector3(0.0, 1.20, 0.70)
const SEAT_LOOK := Vector3(0.0, 0.72, 9.0)

## Standing outside the gate, which is where the title lives.
const OUTSIDE := Vector3(0.0, 1.62, -19.4)
const GATE_AT := Vector3(0.0, 1.30, -13.0)


## CONTINUE: the gate opens and you walk down to the boat.
##
## Deliberately short. It is played every single session, and a beautiful thing
## you cannot skip becomes the worst thing in the game by the fifth time - so it
## is under five seconds and a tap anywhere cuts it.
static func going_out() -> Array:
	return [
		# Two shots at gate 0.0, so the gate is SHUT for a beat before it moves.
		# With only one, the interpolation to the next shot started opening it on
		# the first frame and the player never saw a closed gate at all.
		{"at": OUTSIDE, "look": GATE_AT, "for": 0.7, "gate": 0.0, "ease": "out"},
		{"at": Vector3(0.0, 1.60, -17.6), "look": GATE_AT, "for": 1.1, "gate": 0.0, "ease": "inout"},
		{"at": Vector3(0.0, 1.58, -15.4), "look": GATE_AT, "for": 1.2, "gate": 1.0, "ease": "inout"},
		# Through the gateway and down the bank.
		{"at": Vector3(0.0, 1.52, -9.4), "look": Vector3(0.0, 0.80, 2.0), "for": 1.3, "gate": 1.0, "ease": "inout"},
		{"at": Vector3(0.0, 1.40, -4.2), "look": Vector3(0.0, 0.74, 6.0), "for": 1.1, "gate": 1.0, "ease": "inout"},
		{"at": SEAT, "look": SEAT_LOOK, "for": 1.0, "gate": 1.0, "ease": "out"},
	]


## NEW GAME: the same walk, with the reason for it.
##
## Every line is true, none of them explains anything, and the last one is the
## hook the whole game hangs on. The player is told they have been given work
## and a cottage; they are not told by whom, or what happened to the keeper
## whose book they are about to write in.
static func arriving() -> Array:
	return [
		{"at": Vector3(0.0, 1.66, -26.0), "look": GATE_AT, "for": 2.6, "gate": 0.0, "ease": "out",
			"say": "The letter said the cottage came with the work."},
		{"at": Vector3(0.0, 1.64, -22.4), "look": GATE_AT, "for": 2.6, "gate": 0.0, "ease": "inout",
			"say": "It did not say what the work was."},
		{"at": Vector3(0.55, 1.55, -18.0), "look": Vector3(0.0, 1.55, -13.0), "for": 2.8, "gate": 0.0, "ease": "inout",
			"say": "Only that the water is to be kept, and the book is to be filled."},
		{"at": Vector3(0.0, 1.58, -16.0), "look": GATE_AT, "for": 2.0, "gate": 1.0, "ease": "inout",
			"say": "The key was under the stone, where they said it would be."},
		{"at": Vector3(0.0, 1.52, -9.4), "look": Vector3(0.0, 0.80, 2.0), "for": 2.2, "gate": 1.0, "ease": "inout"},
		{"at": Vector3(0.0, 1.40, -4.2), "look": Vector3(0.0, 0.74, 6.0), "for": 1.8, "gate": 1.0, "ease": "inout",
			"say": "It is a big lake for one person."},
		{"at": SEAT, "look": SEAT_LOOK, "for": 2.0, "gate": 1.0, "ease": "out",
			"say": "Nobody said who filled the book before you."},
	]


## THE SHED, on the bank west of the gate. Kept here rather than in `main.gd`
## because the camera path has to agree with where the room actually is, and one
## file owning both is what stops them drifting.
const SHED_AT := Vector3(-13.0, 0.0, -14.2)
const SHED_DOOR := SHED_AT + Vector3(0.0, 1.62, -3.9)
## TWO METRES BACK FROM THE SLATE, which is arithmetic rather than taste. The
## board is 1.16 m of writing and the phone is portrait, so the visible width at
## distance d is about d * tan(37.5 deg) * 0.462 * 2. At 0.9 m that is 1.0 m and
## the left half of every line ran off the screen; at 2.0 m it is 1.42 m and the
## whole board sits inside the frame with the counter in front of it.
const SHED_STAND := SHED_AT + Vector3(0.0, 1.50, -2.05)
## Level with the middle of the chalkboard rather than tipped at the floor: you
## came here to read the prices, so that is what the view is built around.
## BETWEEN THE GOODS AND THE PRICES, because both have to be in one frame now.
## From the eye the counter sits about 27 degrees down and the top of the board
## about 14 up - a 41 degree span inside a portrait lens of about 75, so aiming
## at the middle of it holds both without a wide shot of an empty room.
const SHED_LOOK := SHED_AT + Vector3(0.0, 1.16, 0.50)


## ROWED TO THE SHED. Four seconds, and a tap cuts it like every other sequence.
##
## The path matters more than the length: it leaves the seat looking at the bank,
## crosses the water at seat height so the trip reads as a ROW rather than a
## camera cut, then rises to standing as you step out and go in through the door.
## A straight fly-through would have said "menu transition" in a way no amount of
## scenery would fix.
static func to_the_shed() -> Array:
	return [
		{"at": SEAT, "look": Vector3(-6.0, 1.0, -8.0), "for": 0.8, "gate": 1.0, "ease": "out"},
		{"at": Vector3(-4.2, 1.22, -5.2), "look": Vector3(-11.0, 1.3, -12.0), "for": 1.2,
			"gate": 1.0, "ease": "inout"},
		{"at": Vector3(-9.4, 1.30, -11.2), "look": SHED_DOOR, "for": 1.1, "gate": 1.0, "ease": "inout"},
		# Standing now, and through the door.
		{"at": SHED_DOOR + Vector3(0.0, 0.0, -1.2), "look": SHED_LOOK, "for": 1.0,
			"gate": 1.0, "ease": "inout"},
		{"at": SHED_STAND, "look": SHED_LOOK, "for": 0.9, "gate": 1.0, "ease": "out"},
	]


## AND BACK OUT. Shorter, because the trip has been seen and the way home is
## never the interesting half.
static func from_the_shed() -> Array:
	return [
		{"at": SHED_STAND, "look": SHED_LOOK, "for": 0.4, "gate": 1.0, "ease": "in"},
		{"at": SHED_DOOR + Vector3(0.0, 0.0, -1.0), "look": Vector3(-6.0, 1.0, -6.0), "for": 0.9,
			"gate": 1.0, "ease": "inout"},
		{"at": Vector3(-6.6, 1.26, -7.4), "look": Vector3(0.0, 0.9, 2.0), "for": 1.1,
			"gate": 1.0, "ease": "inout"},
		{"at": SEAT, "look": SEAT_LOOK, "for": 0.9, "gate": 1.0, "ease": "out"},
	]


## ROWING BETWEEN SPOTS. P2: "The map stops being a teleport."
##
## It was one: pick a line on the chart and the water's colour changed. The lake
## has landmarks now, which is what makes a crossing worth showing - you can see
## the place you are leaving and the place you are going to, and until P1 there
## was nothing to see either way.
##
## The shape is a LOOK BACK, then the crossing, then the new water. Shot three is
## where the spot actually changes, so the landmark you leave is up for the first
## half and the one you arrive at for the second: the swap happens while the
## camera is turned away from both, which is the only moment it can happen without
## something popping.
##
## Under five seconds and a tap cuts it, like the walk to the boat. Every sequence
## in this game is played more often than it is watched.
static func rowing() -> Array:
	return [
		# Over the shoulder at the water you are leaving.
		{"at": SEAT, "look": Vector3(-3.0, 1.10, -7.0), "for": 0.9, "gate": 1.0, "ease": "out"},
		# Round to the bow, and the oars go in.
		{"at": Vector3(0.0, 1.26, 0.40), "look": Vector3(0.0, 0.80, 9.0), "for": 1.0,
			"gate": 1.0, "ease": "inout"},
		# THE CROSSING. Low and forward, looking at nothing but water - this is the
		# shot the spot changes under.
		{"at": Vector3(0.0, 1.12, 1.10), "look": Vector3(0.0, 0.55, 12.0), "for": 1.3,
			"gate": 1.0, "ease": "inout"},
		# Up, and the new place is there.
		{"at": Vector3(0.0, 1.22, 0.90), "look": Vector3(0.0, 1.20, 16.0), "for": 1.2,
			"gate": 1.0, "ease": "inout"},
		{"at": SEAT, "look": SEAT_LOOK, "for": 0.8, "gate": 1.0, "ease": "out"},
	]


## Which shot the water changes under. Named rather than typed at the call site,
## because the sequence and the swap have to agree and they live in different
## files - the whole trick is that it happens while the camera faces open water.
const ROWING_SWAP := 2


## PUTTING YOUR HEAD DOWN. P5: "The hour change becomes a transition rather than
## a number."
##
## It was a row in a list that said "You wake at dusk." and swapped the sky
## between one frame and the next - which is the same fault the chart had and the
## fight had: a thing happening TO the player, reported afterwards.
##
## You lie back along the thwart and look at the sky. That is the whole shot,
## because the sky is the thing that changes, and the light moving across it while
## you watch is the transition - there is nothing else to show and nothing else
## needed. Then you sit up somewhere else in the day.
##
## Longer than the crossing, and deliberately: this is the one sequence that is a
## REST. It still cuts on a tap.
static func sleeping() -> Array:
	return [
		{"at": SEAT, "look": Vector3(0.0, 0.70, 6.0), "for": 0.8, "gate": 1.0, "ease": "in"},
		# Lying back. The look point goes up and behind, so the horizon slides off
		# the bottom of the frame and there is only sky.
		{"at": Vector3(0.0, 0.92, 0.40), "look": Vector3(0.0, 7.0, 2.6), "for": 1.5,
			"gate": 1.0, "ease": "inout"},
		# THE HOUR TURNS HERE, with nothing in shot but the sky it turns.
		{"at": Vector3(0.0, 0.86, 0.30), "look": Vector3(0.0, 9.0, 1.6), "for": 2.2,
			"gate": 1.0, "ease": "inout"},
		{"at": Vector3(0.0, 0.94, 0.45), "look": Vector3(0.0, 5.0, 4.0), "for": 1.2,
			"gate": 1.0, "ease": "inout"},
		{"at": SEAT, "look": SEAT_LOOK, "for": 0.9, "gate": 1.0, "ease": "out"},
	]


## Which shot the hour turns under. The same arrangement as the crossing, and for
## the same reason: the change has to happen where it can be SEEN rather than
## where it would pop.
const SLEEP_SWAP := 2


var shots: Array = []
var index := 0
var elapsed := 0.0
var running := false


func start(list: Array) -> void:
	shots = list
	index = 0
	elapsed = 0.0
	running = shots.size() > 1


func done() -> bool:
	return not running


## Everything the renderer needs this frame: where the camera is, where it
## looks, how open the gate is, and what if anything is being said.
func advance(dt: float) -> Dictionary:
	if not running:
		return {}
	elapsed += dt
	var here: Dictionary = shots[index]
	var span: float = maxf(0.001, float(here["for"]))
	if elapsed >= span:
		elapsed -= span
		index += 1
		if index >= shots.size() - 1:
			# The last entry is the resting pose, not a shot to play through.
			running = false
			var last: Dictionary = shots[shots.size() - 1]
			return {
				"at": last["at"], "look": last["look"],
				"gate": float(last.get("gate", 1.0)), "say": "",
			}
		here = shots[index]

	var next: Dictionary = shots[index + 1]
	var t := clampf(elapsed / maxf(0.001, float(here["for"])), 0.0, 1.0)
	t = _ease(t, str(here.get("ease", "inout")))
	return {
		"at": (here["at"] as Vector3).lerp(next["at"], t),
		"look": (here["look"] as Vector3).lerp(next["look"], t),
		"gate": lerpf(float(here.get("gate", 0.0)), float(next.get("gate", 0.0)), t),
		"say": str(here.get("say", "")),
	}


## Skip to the end, for a player who has seen it. The sequence must always be
## skippable: a thing you cannot cut becomes the worst part of the game by the
## fifth time you sit through it.
func skip() -> Dictionary:
	running = false
	if shots.is_empty():
		return {}
	var last: Dictionary = shots[shots.size() - 1]
	return {"at": last["at"], "look": last["look"], "gate": 1.0, "say": ""}


static func _ease(t: float, kind: String) -> float:
	match kind:
		"out":
			return 1.0 - pow(1.0 - t, 3.0)
		"in":
			return t * t * t
		_:
			# Smoothstep. A camera that starts and stops abruptly reads as a
			# cut even when it is a move.
			return t * t * (3.0 - 2.0 * t)
