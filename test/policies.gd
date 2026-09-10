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
##   IDLE_HANDS  never taps               - both minigames are mechanics
##   MASHER      taps as fast as it can   - the band has a top
##   SLOWPOKE    taps too slowly          - the band has a bottom
##   BLIND       plays well, ignores runs - the warning is the game
##   ANGLER      plays it correctly       - it is winnable
##   HUMAN       ANGLER with human faults - **the only one balance is read off**
##
## **Every policy must fail for a DIFFERENT reason.** When two of them score the
## same, one is not testing anything - and if the one that watches the water ever
## loses to one that ignores it, the bot is wrong before the game is. Fix the bot
## before touching a single constant, or a whole balance pass gets built on a
## measurement of the wrong thing.
##
## **The pair that proves a decision exists must differ in exactly one thing.**
## BLIND and ANGLER are the same player except that ANGLER stops tapping when the
## water warns of a run. The gap between them is a claim about the GAME.
##
## And they drive the sim through the same seam a thumb uses - `hold_cast`,
## `release_cast`, `tap`. A helper that reaches past those is a second, usually
## worse player, and has already made eight tests on another game fail for
## reasons unrelated to what they asserted.

const IDLE_HANDS := "idle_hands"
const MASHER := "masher"
const SLOWPOKE := "slowpoke"
const BLIND := "blind"
const ANGLER := "angler"
const HUMAN := "human"

const ALL := [IDLE_HANDS, MASHER, SLOWPOKE, BLIND, ANGLER, HUMAN]

## HUMAN's faults, and why it is the only policy worth reading.
##
## ANGLER is a perfect-information, zero-latency controller, and a bot like that
## beats any mechanic that is fair. **So "the best bot never loses" is not
## evidence the game is too easy, and not evidence it is hard enough either. It
## is not evidence about the game at all.**
##
## That was learned expensively: the first fight's probe showed the angler at
## 6.83 caught / 0 lost, it went into NOTES.md as "the number to watch", the
## build shipped, and Gideon's first note was that it was too easy. The
## instrument was wrong, not the reading.
##
## The lag needs MEMORY, not just a delay on the input. A stateless bot corrects
## itself the instant the world changes, so a misread costs it only the warning
## window; a person keeps doing the wrong thing until they notice. The first
## version of HUMAN was stateless and scored identically to ANGLER, which was the
## same mistake wearing a different hat.
const REACTION := 0.30            ## seconds before HUMAN notices anything change
## How much deeper than a tease the float has to look before HUMAN commits. A
## person cannot read a boolean; they wait until it is obviously not a tease,
## which costs them part of the take window on every fish.
const HOOK_MARGIN := 0.16
const HOOK_WOBBLE := 0.19        ## per-cast wobble, so it sometimes dips under a tease

## How the rhythm is held and corrected. A person adjusts their tapping rate a
## few times a second, not sixty - and that lag is the entire reason a run is
## dangerous. See `_rhythm`.
const THINK_EVERY := 0.30
const GAIN := 0.55

## Where the bots aim on the tension gauge - the middle of the band, so the
## reading is about the game rather than about how close to the edge a bot was
## willing to sit.
## WHERE A COMPETENT PLAYER AIMS, and it moved up the band when greed arrived.
##
## The haul now scales with height (Tuning.greed), so the middle of the band is
## no longer the right answer - it is the timid one. A bot aiming there would
## measure the game as slower and safer than it is for anyone trying to win, and
## every balance number in the repo would inherit that. 0.80 of the way up leaves
## room for the jolt at the start of a run without giving away most of the haul.
const AIM := Tuning.SAFE_LO + (Tuning.SAFE_HI - Tuning.SAFE_LO) * 0.55
const CYCLE := 0.85               ## seconds of one hold-and-release cycle

## How long every bot holds the cast. Fixed, so all six fish the same water at
## the same distance and the only variable left is the fight.
const CHARGE_HOLD := 0.55


## `mem` is per-session memory, and **every caller stepping a session must supply
## one that persists across the whole of it.**
##
## This is a trap and it has already sprung. The default `{}` is evaluated per
## call, so a caller that omits the argument hands the bot a fresh empty memory
## sixty times a second: the tap rhythm re-initialises every frame, the interval
## timer never reaches its gap, and **the bot silently never taps at all.** Six
## tests and most of the smoke suite failed at once with "correct play landed
## nothing", which reads as a broken game rather than a broken caller.
##
## The default stays only so the memoryless policies remain callable in
## isolation. If you are stepping a session, hold a dict.
static func act(name: String, s: Sim, dt: float, mem: Dictionary = {}) -> void:
	match s.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			s.hold_cast()
		Sim.CHARGING:
			if s.state_time >= CHARGE_HOLD:
				s.release_cast()
		Sim.NIBBLING:
			if _should_strike(name, s, mem):
				s.tap()
		Sim.FIGHTING:
			# HOLD, rather than tap. The bots are the model of a player, so when
			# the control changed they had to change with it - a bot still
			# tapping would have measured a game nobody can play any more.
			s.set_reeling(_should_reel(name, s, dt, mem))
		_:
			pass


## MINIGAME 1: strike on the take, not on a tease.
##
## What separates the bots here is whether they can tell the two apart, which is
## the whole skill the nibble tests.
static func _should_strike(name: String, s: Sim, mem: Dictionary) -> bool:
	match name:
		IDLE_HANDS:
			return false
		MASHER:
			# Strikes at the first movement it sees, which is almost always a
			# tease. This is the mistake the mechanic exists to punish.
			return s.tug > 0.05
		HUMAN:
			# Reads the DEPTH rather than knowing the flag, which is what a person
			# does: a tease is shallow, a take is deep. It waits until the float
			# is convincingly under, which costs part of the take window on every
			# fish - and on a fish whose window is short that is a real risk.
			#
			# The threshold wobbles per cast, and that wobble matters: without it
			# the model never once struck early, and the probe reported minigame 1
			# as free. **Jumping the gun is the obvious human error here**, and a
			# model that cannot make the obvious error is not measuring the thing.
			# When the wobble runs low the threshold falls under a tease's depth
			# and it strikes at one, exactly as a person does.
			# Reads the float's depth RIGHT NOW, not a decaying memory of how deep
			# it has been. The first version kept a peak that bled off over a few
			# frames, which meant it could fire during the still water AFTER a tease
			# - striking at nothing, over and over, for a 50% loss rate that was an
			# artefact of the model rather than a fact about the game.
			var wobble := (SimUtil.hash2(s.casts, 313) - 0.5) * 2.0 * HOOK_WOBBLE
			return s.tug > Tuning.TEASE_DEPTH + HOOK_MARGIN + wobble
		_:
			# Perfect information: strikes the instant the take begins.
			return s.can_hook()


## MINIGAME 2. Tap to hold the needle at AIM, and - for everyone but BLIND -
## stop tapping when the water says a run is coming.
static func _should_reel(name: String, s: Sim, dt: float, mem: Dictionary) -> bool:
	match name:
		IDLE_HANDS:
			return false
		MASHER:
			# Holds the button down and never lets go. Breaks the line, every
			# time, which is the same failure it always had for the same reason.
			return true
		SLOWPOKE:
			# Reels far too timidly - lets go the moment there is any tension at
			# all. Never breaks anything; loses every fish to the line going
			# slack and the fish taking line back.
			return s.tension < Tuning.SAFE_LO * 0.55
		BLIND:
			# Plays the gauge well and never looks at the water, so it learns
			# about a run from the NEEDLE - a reaction time after it has already
			# started, and after the jolt has already landed. Same reaction as
			# HUMAN; the only difference between them is the warning.
			return _rhythm(s, dt, mem, false, REACTION)
		ANGLER:
			return _rhythm(s, dt, mem, true)
		HUMAN:
			return _rhythm(s, dt, mem, true, REACTION)
		_:
			return false


## Tapping on a RHYTHM rather than as a per-frame controller.
##
## This is the correction that made the probe mean anything. A bot that re-reads
## the gauge every frame and taps only when the needle is below the aim point
## **automatically stops tapping during a run**, because a run pushes the needle
## up - so the run solved itself and every policy scored identically at 100%.
## No amount of tuning the run would have shown up, because the fault was that
## the model of a player was wrong: nobody taps by sampling sixty times a second.
##
## A person settles into a rate and corrects it every few tenths of a second. So
## these hold a tap interval, adjust it on a slow cadence, and are therefore
## still tapping for a moment after something changes - which is what makes a
## run a threat and the warning worth watching.
##
## `watches` is whether it acts on the tell at all, and `delay` is how long it
## takes to notice. Those two arguments are the ONLY difference between BLIND,
## ANGLER and HUMAN, so the gaps between them are claims about the game.
static func _rhythm(s: Sim, dt: float, mem: Dictionary, watches: bool, delay: float = 0.0) -> bool:
	if not mem.has("duty"):
		# The duty that HOLDS the aim point, from the sim's own arithmetic:
		# tension settles at `duty * HOLD_RISE / TAP_DECAY`, so the duty needed
		# for a tension is that ratio inverted. Derived rather than guessed, so a
		# change to either constant moves the bot with the game.
		mem["duty"] = clampf(AIM / (Tuning.HOLD_RISE / Tuning.TAP_DECAY), 0.0, 1.0)
		mem["since"] = 0.0
		mem["think"] = 0.0
		mem["hold"] = false
		mem["lag"] = 0.0

	# What it believes the fish is doing, lagged by `delay`.
	var alarmed := (s.running or s.tell > 0.0) if watches else s.running
	if alarmed != bool(mem["hold"]):
		mem["lag"] = float(mem["lag"]) + dt
		if float(mem["lag"]) >= delay:
			mem["hold"] = alarmed
			mem["lag"] = 0.0
	else:
		mem["lag"] = 0.0

	# Correct the duty every so often rather than every frame. This is the part
	# that makes a run dangerous: the bot is still holding the button for a moment
	# after the fish starts pulling, exactly as a person would be.
	mem["think"] = float(mem["think"]) + dt
	if float(mem["think"]) >= THINK_EVERY:
		mem["think"] = 0.0
		var err := AIM - s.tension
		mem["duty"] = clampf(float(mem["duty"]) + err * GAIN, 0.0, 1.0)

	if bool(mem["hold"]):
		return false

	# A DUTY CYCLE, which is what a tap rhythm becomes when the control is a
	# hold. The bot still commits to a rate and corrects it on a slow cadence -
	# that is the part that matters, and the reason the run stays a threat - but
	# it now expresses that rate as "button down for this fraction of each
	# cycle" rather than "one instant press every `gap` seconds".
	#
	# Aiming HIGH in the band on purpose. The haul now scales with height (see
	# Tuning.greed), so a player who parks in the middle is leaving half the
	# fight on the table, and a bot that did so would measure the game as slower
	# and safer than it is for anyone actually trying to win.
	mem["since"] = float(mem["since"]) + dt
	if float(mem["since"]) >= CYCLE:
		mem["since"] = float(mem["since"]) - CYCLE
	return float(mem["since"]) < CYCLE * float(mem["duty"])


## Fish one session with one policy and hand back the final state, plus the
## readings a balance pass wants that the golden does not.
## `spot` and `line` decide WHERE the session is fished, and they matter more than
## they look. Every claim in the suite used to be measured in the starting reeds
## because that was the only water `play` could reach, so a claim about the fight
## was really a claim about five tutorial fish - which is how "ignoring the run
## warning costs you" came to be asserted in the one band where it does not.
static func play(name: String, seconds: float = 60.0, seed_value: int = 1,
		spot: String = "reed_bay", line: int = 0) -> Dictionary:
	var s := Sim.new(seed_value)
	s.econ.line = line
	s.econ.has_motor = true
	s.spot = spot
	var mem := {}
	var step := 1.0 / 60.0
	var n := int(round(seconds / step))
	var fighting := 0.0
	for i in n:
		act(name, s, step, mem)
		s.advance(step)
		if s.state == Sim.FIGHTING:
			fighting += step
	var out := s.state_snapshot()
	out["seconds"] = snappedf(s.time, 0.001)
	# How long the rod was bent. A run that costs no fish still costs THIS, which
	# is the only thing a missed tell takes off a player in the tutorial - and a
	# cost you cannot measure is a cost you cannot assert.
	out["fighting"] = snappedf(fighting, 0.001)
	return out
