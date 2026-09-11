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

## WHERE A COMPETENT PLAYER LETS OFF THE REEL.
##
## Just under the danger line, because that is where the fish tires fastest and a
## bot that sat lower would measure the game as slower and safer than it is for
## anyone trying to win. The margin is for the jolt at the start of a run: a
## player who is already at 0.78 when the fish goes has no room at all.
const REEL_CEILING := Tuning.DANGER - 0.07

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
## WHEN TO REEL, IN THE FIFTH FIGHT.
##
## The decision got much simpler when the model did, and that is the strongest
## evidence the model is better: the bots used to be duty-cycle controllers aiming
## at a point on a needle, because that is what a conflated value forces. Now the
## question is the one a player actually asks - "is the fish pulling?" - and the
## whole difference between the policies is whether they can tell, and how late.
##
## `watches` is whether it reads the TELL at all; `delay` is how long it takes to
## notice. Those two arguments are the only difference between BLIND, ANGLER and
## HUMAN, so the gaps between them are claims about the game rather than about the
## bots.
static func _should_reel(name: String, s: Sim, dt: float, mem: Dictionary) -> bool:
	match name:
		IDLE_HANDS:
			return false
		MASHER:
			# Never lets go. Parts the line on anything that fights back.
			return true
		SLOWPOKE:
			# Frightened of the rod. Reels only when the line is almost slack, so
			# it never breaks anything and never gets a fish to the boat either.
			return s.tension < Tuning.SAFE_LO * 0.55
		BLIND:
			# Feathers the rod - it can feel that much - but never reads the water,
			# so every run's jolt lands on top of whatever tension it happened to
			# be carrying. It does not release EARLY, it releases LATE, and the
			# overshoot is what it pays.
			return not _believes_bent(s, dt, mem, REACTION)
		ANGLER:
			# The same player, plus the one thing: it reads the tell and sheds
			# tension before the jolt arrives. That is the only difference between
			# these two, so the gap between them is a claim about the game.
			#
			# And it sheds only what it has to. An earlier version let go for the
			# whole of the warning, every time, and measured WORSE than BLIND -
			# obeying the tell cost it two thirds of a second of reeling per run
			# and bought it nothing. That was the bot being wrong rather than the
			# game: the warning is worth acting on only when the jolt would
			# actually put the rod over, and a perfect player knows when that is.
			return not _believes_bent(s, dt, mem, 0.0) 				and not (_believes_tell(s, dt, mem, 0.0) and _jolt_would_hurt(s, 0.0))
		HUMAN:
			# The same judgement with a person's information: no idea what this
			# particular fish's kick is worth, so it leaves a flat margin and is
			# sometimes wrong in both directions.
			return not _believes_bent(s, dt, mem, REACTION) 				and not (_believes_tell(s, dt, mem, REACTION) and _jolt_would_hurt(s, 0.06))
		_:
			return false


## Whether letting the run start from HERE would put the rod over the line.
##
## ANGLER reads the fish's actual kick, which is what "perfect information" means.
## HUMAN gets the same question with a flat guess and a margin, because a person
## knows a strong fish kicks harder without knowing the number.
static func _jolt_would_hurt(s: Sim, margin: float) -> bool:
	var row := Species.by_id(s.fish_id)
	if row.is_empty():
		return true
	var jolt := Tuning.RUN_JOLT * Tuning.jolt_scale(float(row["run_power"]))
	return s.tension + jolt + margin > Tuning.DANGER


## Whether this policy has NOTICED THE WARNING, which is a different reading from
## either the rod or the run.
##
## It latches on the tell alone rather than on `running`, because letting go for
## the whole of a run is no longer how the fight is played: holding on brakes the
## run, so a good player sheds tension during the WARNING and then feathers
## through the run itself, taking back what ground the rod will allow.
static func _believes_tell(s: Sim, dt: float, mem: Dictionary, delay: float) -> bool:
	if not mem.has("tell"):
		mem["tell"] = false
		mem["tell_lag"] = 0.0
	var truth := s.tell > 0.0
	if truth != bool(mem["tell"]):
		mem["tell_lag"] = float(mem["tell_lag"]) + dt
		if float(mem["tell_lag"]) >= delay:
			mem["tell"] = truth
			mem["tell_lag"] = 0.0
	else:
		mem["tell_lag"] = 0.0
	return bool(mem["tell"])


## What this policy BELIEVES the rod is doing, lagged the same way.
##
## Separate memory keys from `_believes_pulling` on purpose: these are two
## different readings a player takes - the water, and the rod in their hands - and
## they go wrong independently. Sharing a latch between them would have made a bot
## that misread one automatically misread the other.
static func _believes_bent(s: Sim, dt: float, mem: Dictionary, delay: float) -> bool:
	if not mem.has("bent"):
		mem["bent"] = false
		mem["bent_lag"] = 0.0
	var truth := s.tension >= REEL_CEILING
	if truth != bool(mem["bent"]):
		mem["bent_lag"] = float(mem["bent_lag"]) + dt
		if float(mem["bent_lag"]) >= delay:
			mem["bent"] = truth
			mem["bent_lag"] = 0.0
	else:
		mem["bent_lag"] = 0.0
	return bool(mem["bent"])


## What this policy BELIEVES the fish is doing, lagged by its reaction time.
##
## The lag is the whole mechanic: a player is still reeling for a moment after the
## fish starts to pull, and that moment is where the tension comes from. A bot
## that sampled the truth every frame would let go before anything ever happened
## and would measure a game with no danger in it - which is the mistake an earlier
## version of these bots made, and it showed as every policy scoring identically.
static func _believes_pulling(s: Sim, dt: float, mem: Dictionary, watches: bool,
		delay: float) -> bool:
	if not mem.has("think"):
		mem["think"] = false
		mem["lag"] = 0.0
	var truth := (s.running or s.tell > 0.0) if watches else s.running
	if truth != bool(mem["think"]):
		mem["lag"] = float(mem["lag"]) + dt
		if float(mem["lag"]) >= delay:
			mem["think"] = truth
			mem["lag"] = 0.0
	else:
		mem["lag"] = 0.0
	return bool(mem["think"])


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
