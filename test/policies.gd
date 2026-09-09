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
const HOOK_ERROR := 0.085         ## how far off centre HUMAN aims on the hook bar

## How the rhythm is held and corrected. A person adjusts their tapping rate a
## few times a second, not sixty - and that lag is the entire reason a run is
## dangerous. See `_rhythm`.
const THINK_EVERY := 0.30
const GAIN := 0.55

## Where the bots aim on the tension gauge - the middle of the band, so the
## reading is about the game rather than about how close to the edge a bot was
## willing to sit.
const AIM := (Tuning.SAFE_LO + Tuning.SAFE_HI) * 0.5

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
		Sim.HOOKING:
			if _should_set_hook(name, s, mem):
				s.tap()
		Sim.FIGHTING:
			if _should_tap(name, s, dt, mem):
				s.tap()
		_:
			pass


## MINIGAME 1. Everyone who tries at all aims at the middle of the green zone;
## what differs is whether they aim at all.
static func _should_set_hook(name: String, s: Sim, mem: Dictionary) -> bool:
	match name:
		IDLE_HANDS:
			return false
		MASHER:
			# Taps the instant the bar appears, wherever the marker happens to
			# be. Sometimes lucky, mostly not.
			return true
		HUMAN:
			# Aims at the middle and is a little off, so a narrow zone is a real
			# risk rather than a formality.
			var mid := (s.zone_lo + s.zone_hi) * 0.5
			var off := HOOK_ERROR * (1.0 if SimUtil.hash2(s.casts, 17) > 0.5 else -1.0)
			return absf(s.sweep - (mid + off)) < 0.02
		_:
			return s.sweep_in_zone()


## MINIGAME 2. Tap to hold the needle at AIM, and - for everyone but BLIND -
## stop tapping when the water says a run is coming.
static func _should_tap(name: String, s: Sim, dt: float, mem: Dictionary) -> bool:
	match name:
		IDLE_HANDS:
			return false
		MASHER:
			return true
		SLOWPOKE:
			# Taps at about half the rate the band needs. Never breaks anything;
			# loses every fish to the line going slack and the fish taking it.
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
	if not mem.has("gap"):
		mem["gap"] = 1.0 / maxf(0.5, Tuning.taps_per_second_for(AIM))
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

	# Correct the rate every so often rather than every frame.
	mem["think"] = float(mem["think"]) + dt
	if float(mem["think"]) >= THINK_EVERY:
		mem["think"] = 0.0
		var err := AIM - s.tension
		var gap: float = float(mem["gap"]) - err * GAIN
		mem["gap"] = clampf(gap, 0.16, 2.5)

	if bool(mem["hold"]):
		return false

	mem["since"] = float(mem["since"]) + dt
	if float(mem["since"]) < float(mem["gap"]):
		return false
	mem["since"] = 0.0
	return true


## Fish one session with one policy and hand back the final state, plus the
## readings a balance pass wants that the golden does not.
static func play(name: String, seconds: float = 60.0, seed_value: int = 1) -> Dictionary:
	var s := Sim.new(seed_value)
	var mem := {}
	var step := 1.0 / 60.0
	var n := int(round(seconds / step))
	for i in n:
		act(name, s, step, mem)
		s.advance(step)
	var out := s.state_snapshot()
	out["seconds"] = snappedf(s.time, 0.001)
	return out
