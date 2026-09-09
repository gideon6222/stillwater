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
##   IDLE_HANDS  never touches the rod          - the fight is a mechanic
##   MASHER      holds it flat out              - runs will kill you
##   HAULER      pumps, but ignores the water   - the tells are the game
##   PANICKER    gives line at every sign       - cowardice loses to the clock
##   ANGLER      reads the tell and responds    - it is winnable
##
## **Every policy must fail for a DIFFERENT reason.** When two of them score the
## same, one is not testing anything - and if the one that reads the water ever
## loses to one that ignores it, the bot is wrong before the game is. Fix the bot
## before touching a single constant, or a whole balance pass gets built on a
## measurement of the wrong thing.
##
## **The pair that proves a decision exists must differ in exactly one thing.**
## HAULER and ANGLER pump identically; the only difference is that ANGLER looks
## at `tell` and `behaviour` and HAULER does not. So the gap between their catch
## counts is a claim about whether READING THE WATER matters, which is the entire
## premise of the second fight.
##
## And they drive the sim through the same seam a thumb uses - `hold_cast`,
## `release_cast`, `strike`, `set_pull`. A helper that reaches past those is a
## second, usually worse player, and has already made eight tests on another game
## fail for reasons unrelated to what they asserted.

const IDLE_HANDS := "idle_hands"
const MASHER := "masher"
const HAULER := "hauler"
const PANICKER := "panicker"
const ANGLER := "angler"
const HUMAN := "human"

const ALL := [IDLE_HANDS, MASHER, HAULER, PANICKER, ANGLER, HUMAN]

## HUMAN's reaction time, and the reason it exists.
##
## ANGLER is a perfect-information, zero-latency controller, and a bot like that
## will beat any mechanic that is fair - it lost nothing under the first fight
## and it loses nothing under this one either. **So "the best bot never loses" is
## not evidence the game is too easy, and it is not evidence it is hard enough
## either. It is not evidence about the game at all.**
##
## That is the lesson the first fight taught the expensive way: the probe showed
## the angler at 6.83 caught / 0 lost, that was read as "fine", and Gideon's
## first note was that it was too easy. The instrument was wrong.
##
## HUMAN is the honest instrument: the same reads, plus 200 ms of reaction time
## and a tell it misreads about one time in six. What IT scores is the number
## that means something.
const REACTION := 0.30
const MISREAD_IN := 6
const WOBBLE := 0.055

## Where the bots pump to. Below the strain threshold with a real margin - a bot
## that fishes at the edge would make every balance reading a measurement of how
## close to the edge the bot was willing to sit, rather than of the game.
const PUMP_TOP := 0.76
const PUMP_BOTTOM := 0.16

## How long every bot holds the cast. Fixed rather than drawn, so all five fish
## the same water at the same distance and the only variable is the fight.
const CHARGE_HOLD := 0.55


## `mem` is per-session memory, and only HUMAN uses it.
##
## It has to exist because a person who misreads a tell keeps doing the wrong
## thing until they NOTICE - and a stateless bot corrects itself the instant the
## behaviour changes, which is not a mistake anyone has ever made. Without the
## memory the human model scored identically to the perfect one and the probe
## said the fight was free, which was wrong for a reason that had nothing to do
## with the game.
static func act(name: String, s: Sim, dt: float, mem: Dictionary = {}) -> void:
	# Casting and striking are identical across every policy, on purpose.
	match s.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			s.hold_cast()
		Sim.CHARGING:
			if s.state_time >= CHARGE_HOLD:
				s.release_cast()
		Sim.BITING:
			s.strike()
		Sim.FIGHTING:
			s.set_pull(_pull_for(name, s, dt, mem))
		_:
			pass


static func _pull_for(name: String, s: Sim, dt: float, mem: Dictionary = {}) -> float:
	match name:
		IDLE_HANDS:
			return 0.0
		MASHER:
			return 1.0
		HAULER:
			# Pumps correctly and forever, and never once looks up. It will pump
			# straight through a run, which is the point of it existing.
			return _pump_cycle(s)
		PANICKER:
			# Gives line at the first sign of anything and never commits to a
			# pump. Loses nothing to runs and everything to the wear clock.
			if s.tell > 0.0 or s.behaviour != Sim.B_HOLDING:
				return 0.0
			return _pump_cycle(s) * 0.55
		ANGLER:
			return _angler(s, true, false)
		HUMAN:
			return _human(s, dt, mem)
		_:
			return 0.0


## A pump, driven off the sim's own pump state rather than a private timer.
##
## Reading `_pump_armed` would be reaching past the seam, so this infers the
## stroke from `load` the same way a player infers it from the rod: over the top
## means come down, under the bottom means go up.
static func _pump_cycle(s: Sim) -> float:
	if s.load >= PUMP_TOP:
		return 0.0
	if s.load <= PUMP_BOTTOM:
		return 1.0
	# Mid-stroke: keep going the way the rod is already going.
	return 1.0 if s.pull > 0.5 else 0.0


## The one that reads the water.
##
## Three responses to three behaviours, and it acts on the TELL rather than on
## the behaviour - which is the difference between this and HAULER, and the whole
## claim the mechanic makes.
##
## `reacted` is whether the tell has been visible long enough to act on, and
## `misread` swaps the two announced behaviours. Both are always false for the
## ANGLER and sometimes true for HUMAN, which is the only difference between the
## perfect player and the plausible one.
static func _angler(s: Sim, reacted: bool, misread: bool) -> float:
	var mid := (Tuning.SHAKE_LO + Tuning.SHAKE_HI) * 0.5

	# What the water is announcing, if anything is being acted on yet.
	var coming := ""
	if s.tell > 0.0 and reacted:
		coming = s.next_behaviour
		if misread:
			coming = Sim.B_SURFACING if coming == Sim.B_RUNNING else Sim.B_RUNNING

	# A run is here, or is coming. Drop the rod.
	if s.behaviour == Sim.B_RUNNING or coming == Sim.B_RUNNING:
		return 0.0

	# Head-shake. Hold at the middle of the window and do not move.
	if s.behaviour == Sim.B_SURFACING or coming == Sim.B_SURFACING:
		return mid

	return _pump_cycle(s)


## A plausible person rather than a perfect controller.
##
## Believes something about what the fish is doing, and that belief LAGS reality
## by REACTION seconds and is sometimes wrong. The lag is the whole point: a
## stateless bot snaps to the truth the instant the behaviour changes, which
## means a misread costs it only the tell window and nothing after. A person
## keeps doing the wrong thing until the rod tells them otherwise.
static func _human(s: Sim, dt: float, mem: Dictionary) -> float:
	var truth := s.behaviour
	# A tell that has been up long enough to act on IS the truth, as far as
	# someone watching the water is concerned - that is what a tell is for.
	if s.tell > 0.0 and Tuning.TELL_TIME - s.tell >= REACTION:
		truth = s.next_behaviour

	if not mem.has("seen"):
		mem["seen"] = truth
		mem["lag"] = 0.0
		mem["wrong"] = false

	if truth != mem["seen"]:
		mem["lag"] = float(mem["lag"]) + dt
		if float(mem["lag"]) >= REACTION:
			# Notice it, and decide here whether this one is read correctly.
			# Keyed on the fight's own progress so it is deterministic and the
			# golden still holds.
			var roll := SimUtil.hash2(s.pumps + s.casts * 13, int(s.fight_time * 2.0) + 41)
			mem["wrong"] = roll < 1.0 / float(MISREAD_IN)
			mem["seen"] = truth
			mem["lag"] = 0.0
	else:
		mem["lag"] = 0.0

	var believed: String = mem["seen"]
	if bool(mem["wrong"]):
		if believed == Sim.B_RUNNING:
			believed = Sim.B_SURFACING
		elif believed == Sim.B_SURFACING:
			believed = Sim.B_RUNNING

	var want := 0.0
	var mid := (Tuning.SHAKE_LO + Tuning.SHAKE_HI) * 0.5
	match believed:
		Sim.B_RUNNING:
			want = 0.0
		Sim.B_SURFACING:
			want = mid
		_:
			want = _pump_cycle(s)

	# A thumb does not hold a number. Small, but it is the imperfection that
	# bites during a head-shake, where holding STILL is the requirement.
	return clampf(want + sin(s.time * 9.0) * WOBBLE, 0.0, 1.0)


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
