class_name Policies
extends RefCounted

## Scripted players.
##
## These are not test fixtures. They are **the definition of "playing well"** -
## the thing every balance number in the game is measured against - and that is
## why they live in the repo rather than in a session. On a sibling game `par`
## was once set from a policy typed into a browser console whose lookahead was
## slightly longer than the committed one; it scored 65% higher and the constant
## went in 44% too high. Nobody could have caught that by reading the number.
##
## **One policy per way of failing:**
##
##   IDLE_HANDS  strikes but never pulls - proves the fight is a mechanic
##   MASHER      holds the thumb flat out - proves there is a wrong way to pull
##   TIMID       pulls, but never enough - proves the band has a bottom
##   ANGLER      reads the gauge and tracks the band - proves it is winnable
##
## **Every policy must fail for a DIFFERENT reason.** When two of them score the
## same, one is not testing anything - and if the one that reads the gauge ever
## loses to one that ignores it, the bot is wrong before the game is. Fix the
## bot before touching a single constant, or a whole balance pass gets built on
## a measurement of the wrong thing.
##
## **The pair that proves a decision exists must differ in exactly one thing.**
## ANGLER and MASHER share every line except how `pull` is chosen, so the gap
## between their catch counts is a claim about the GAME. If they differed in how
## they cast or when they struck, it would be a claim about the bots.
##
## And they drive the sim through the same seam a thumb uses - `hold_cast`,
## `release_cast`, `strike`, `set_pull`. A helper that reaches past those is a
## second, usually worse player, and has already made eight tests on another
## game fail for reasons unrelated to what they asserted.

const IDLE_HANDS := "idle_hands"
const MASHER := "masher"
const TIMID := "timid"
const ANGLER := "angler"

const ALL := [IDLE_HANDS, MASHER, TIMID, ANGLER]

## How hard the angler corrects a tension error. Deliberately crude and a little
## sluggish: a policy with cleverness in it becomes a second thing that can
## change, and then a golden failure means "the bot got better" as often as "the
## game changed".
const CORRECTION := 2.6

## How long every bot holds the cast before letting go. Fixed rather than drawn,
## so all four fish the same water at the same distance and the only variable
## left between them is the fight.
const CHARGE_HOLD := 0.55


static func act(name: String, s: Sim, dt: float) -> void:
	# Casting and striking are identical across every policy, on purpose. See
	# the note above about what a comparison between two of them is a claim
	# about.
	match s.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			s.hold_cast()
		Sim.CHARGING:
			if s.state_time >= CHARGE_HOLD:
				s.release_cast()
		Sim.BITING:
			s.strike()
		Sim.FIGHTING:
			s.set_pull(_pull_for(name, s, dt))
		_:
			pass


static func _pull_for(name: String, s: Sim, dt: float) -> float:
	match name:
		IDLE_HANDS:
			return 0.0
		MASHER:
			return 1.0
		TIMID:
			# Enough to feel like fishing, never enough to reach the band.
			return maxf(0.0, Tuning.band_lo(0.36) - 0.18)
		ANGLER:
			# A proportional controller on the ONE number a player can actually
			# see - the tension gauge. It does not read the fish's internal
			# pull, because the player cannot either, and a bot with more
			# information than the screen carries is measuring a different game.
			var b := s.band()
			var target: float = (b[0] + b[1]) * 0.5
			var err: float = target - s.tension
			return clampf(s.pull + CORRECTION * err * dt, 0.0, 1.0)
		_:
			return 0.0


## Fish one session with one policy and hand back the final state, plus the
## readings a balance pass wants that the golden does not.
static func play(name: String, seconds: float = 60.0, seed_value: int = 1) -> Dictionary:
	var s := Sim.new(seed_value)
	var step := 1.0 / 60.0
	var n := int(round(seconds / step))
	for i in n:
		act(name, s, step)
		s.advance(step)
	var out := s.state_snapshot()
	out["seconds"] = snappedf(s.time, 0.001)
	return out
