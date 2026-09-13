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
##   IDLE_HANDS  never strikes, never cranks    - both minigames are mechanics
##   MASHER      cranks flat out, never gives   - the line has a top
##   SLOWPOKE    cranks at a fifth, never gives - the crank has a bottom
##   GIVER       gives line at every tell       - giving is not free: fish escape
##   BLIND       eases by the rod alone, late   - the warning is the game
##   ANGLER      plays it correctly             - it is winnable
##   HUMAN       ANGLER with human faults       - **the only one balance is read off**
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
const GIVER := "giver"
const BLIND := "blind"
const ANGLER := "angler"
const HUMAN := "human"

const ALL := [IDLE_HANDS, MASHER, SLOWPOKE, GIVER, BLIND, ANGLER, HUMAN]

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
## How far over the ceiling maps to full give: at the ceiling nothing is given,
## GIVE_SPAN above it the spool is free. A person eases the slide down as the
## rod comes up, and this is the slope of that.
const GIVE_SPAN := 0.15
## SLOWPOKE's whole idea of a crank.
const SLOW_CRANK := 0.2
## THE PERFECT VALVE aims just under the danger line with a tight span: it gives
## the least line that keeps the rod under the red, which is the most brake and
## the most tiring a run can be made to pay. A first cut aimed at the crank's
## ceiling with the wide span, gave the whole spool at 0.86, and escaped a
## quarter of the Old Fish - the perfect player losing to caution.
const PERFECT_VALVE := Tuning.DANGER - 0.02
const PERFECT_SPAN := 0.06
## A PERSON'S HANDS. The slide is eased against a tension felt HAND_LAG ago, and
## when the rod slams over the hand shoves the slide down hard rather than
## trimming it: a narrower span than the perfect valve, so HUMAN over-corrects
## and pays in ground where ANGLER pays nothing. A first cut lagged the felt
## tension by the whole REACTION and trimmed proportionally, and against a run
## that pins the line in a third of a second that broke eleven sturgeon in
## twelve - worse than a bot that never reads the water, which the rule at the
## top of this file forbids.
const HAND_LAG := 0.15
const HUMAN_SPAN := 0.06
## HUMAN's thumb is not a lathe: the slide is read in fifths.
const HUMAN_STEPS := 5.0

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
	apply(wants(name, s, dt, mem), s, mem)


## THE DECISION, SEPARATE FROM THE ACT. What the named policy would do this
## frame, as a verb, and the simulation is not touched to find out.
##
## `act` is `apply(wants(...))`, so the bots the suite measures and the bot that
## holds a thumb on a filmed run (`Main.bot_touch_pixels`) cannot disagree: one
## reads the verb and calls the sim, the other reads the same verb and presses
## the button that calls the sim. A filmed bot that asked by ACTING would take
## the shortcut and film it, which is the one thing the seam exists to stop.
const HOLD := "hold"            ## press the cast button and keep it down
const RELEASE := "release"      ## let the cast button go: the throw
const STRIKE := "strike"        ## one press: set the hook
const WORK := "work"            ## the reel slide: the amount is in mem["reel"], [-1, 1]
const KEEP := "keep"            ## one press: into the livewell
const PUT_BACK := "put_back"    ## one press on the other button
const NOTHING := ""

static func wants(name: String, s: Sim, dt: float, mem: Dictionary) -> String:
	match s.state:
		Sim.HOLDING:
			# G2: THE FISH IS IN YOUR HANDS AND SOMEBODY HAS TO DECIDE.
			#
			# Landing used to put it in the box on a timer; now nothing happens
			# until the player says. A bot that did not answer would sit holding
			# one fish forever, and every balance number in the repo is measured
			# through these - so "playing well" has to include this choice.
			#
			# Keep it if it fits, put it back if it does not. That is the whole
			# policy for every bot: the interesting version of this decision is
			# G1's, where a full livewell makes it a real weighing-up, and no bot
			# should pretend to be good at it before the space is scarce.
			# An object is not a decision - `keep_fish` puts it down. A fish that
			# will not fit has to go back.
			if s.fish_id == "" or s.econ.can_keep(s.fish_weight):
				return KEEP
			return PUT_BACK
		Sim.IDLE, Sim.LOST:
			return HOLD
		Sim.CHARGING:
			if s.state_time >= CHARGE_HOLD:
				return RELEASE
			return NOTHING
		Sim.NIBBLING:
			if _should_strike(name, s, mem):
				return STRIKE
			return NOTHING
		Sim.FIGHTING:
			# A DIAL, not a button. The bots are the model of a player, so when
			# the control changed they had to change with it - a bot still
			# holding a button would have measured a game nobody can play any
			# more. The amount rides in `mem` because a verb is a word and the
			# slide is a number.
			mem["reel"] = _reel_amount(name, s, dt, mem)
			return WORK
		_:
			return NOTHING


## The verb, done to the sim through the same seam a thumb uses.
static func apply(verb: String, s: Sim, mem: Dictionary = {}) -> void:
	match verb:
		HOLD:
			s.hold_cast()
		RELEASE:
			s.release_cast()
		STRIKE:
			s.tap()
		WORK:
			s.set_reel(float(mem.get("reel", 0.0)))
		KEEP:
			s.keep_fish()
		PUT_BACK:
			s.return_fish()
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
## HOW HARD TO WORK THE REEL, IN THE SIXTH FIGHT. In [-1, 1]: crank, hold, give.
##
## The question a player asks is still "is the fish pulling?", and the answer is
## now a position rather than a bit: in calm water, crank as fast as the rod will
## stand; while it pulls, HOLD - the held line brakes the run and tires the fish
## - and give exactly what keeps the rod under the line, no more, because every
## metre given is a metre to win back. The whole difference between BLIND, ANGLER
## and HUMAN is whether they read the water and how late; GIVER is the bot that
## takes the safe end of the slide every time, and it exists so that "giving is
## not free" is measured rather than hoped.
static func _reel_amount(name: String, s: Sim, dt: float, mem: Dictionary) -> float:
	match name:
		IDLE_HANDS:
			return 0.0
		MASHER:
			# Flat out, always. Parts the line on anything that fights back.
			return 1.0
		SLOWPOKE:
			# Frightened of the rod. A fifth of a crank and never more, so it never
			# breaks anything and a deep fish walks it back out.
			return SLOW_CRANK
		GIVER:
			# The safe end of the slide at every tell and through every run, and
			# the feathered crank in between - so the ONLY thing wrong with it is
			# that it gives everything the moment the water moves. It loses fish
			# to the escape margin, which is the failure the down direction has
			# to have. (Cranking flat out between runs made it break lines in
			# calm water, which is MASHER's failure wearing a different hat.)
			if s.tell > 0.0 or s.running:
				return -1.0
			return _crank_for(s, REEL_CEILING)
		BLIND:
			# Feathers by the rod alone - it can feel that much - but never reads
			# the water, so a run's kick lands on whatever it was carrying and it
			# eases the slide down LATE, once the rod is already over. The
			# overshoot is what it pays. (A first cut held instead of easing,
			# and a held line in this fight relieves nothing: BLIND then broke
			# reeds fish over five runs, which is a claim about the bot, not the
			# tutorial.)
			if _believes_bent(s, dt, mem, REACTION):
				return -clampf((s.tension - REEL_CEILING) / GIVE_SPAN, 0.0, 1.0)
			return _crank_for(s, REEL_CEILING)
		ANGLER:
			return _work(s, dt, mem, 0.0, false, PERFECT_VALVE, PERFECT_SPAN, 0.0)
		HUMAN:
			# The same judgement with a person's information: a reaction lag on
			# what it reads, hands that feel the rod a moment late and shove
			# rather than trim, and a thumb that reads the slide in fifths.
			return _work(s, dt, mem, REACTION, true, REEL_CEILING, HUMAN_SPAN, HAND_LAG)
		_:
			return 0.0


## The competent player's answer, with perfect or human information.
static func _work(s: Sim, dt: float, mem: Dictionary, delay: float, coarse: bool,
		valve_at: float, valve_span: float, hand_lag: float) -> float:
	var out := 0.0
	var tell := _believes_tell(s, dt, mem, delay)
	var pulling := _believes_pulling(s, dt, mem, true, delay)
	# THE HAND ON THE SLIDE READS A FELT TENSION, NOT THE NUMBER. A person eases
	# the slide against what the rod was doing a moment ago, so the valve lags
	# too, not only the decision to stop cranking - and that lag is where the
	# overshoot comes from. With the valve reading the live tension, HUMAN tied
	# ANGLER to the fish (strain 0.14 against 0.10), which is a bot with perfect
	# hands wearing a slow head.
	var felt: float = s.tension
	if hand_lag > 0.0:
		if not mem.has("felt"):
			mem["felt"] = s.tension
		mem["felt"] = float(mem["felt"]) + (s.tension - float(mem["felt"])) * (1.0 - exp(-dt / hand_lag))
		felt = float(mem["felt"])
	if pulling or tell:
		# The fish is going, or about to. HOLD: a held line brakes the run and
		# tires the fish, and the crank's tension decays off it while the fish
		# winds up, so the kick lands on a slack line instead of a loaded one.
		# That is what reading the water buys, and it costs no ground - a first
		# cut GAVE line through the warning and paid out a metre per tell for a
		# fish that was not yet pulling, then escaped more than a bot that never
		# read the water at all. Give only what keeps the rod under the line.
		var over := felt - valve_at
		if over > 0.0:
			out = -clampf(over / valve_span, 0.0, 1.0)
	else:
		out = _crank_for(s, REEL_CEILING)
	if coarse:
		out = round(out * HUMAN_STEPS) / HUMAN_STEPS
	return out


## The fastest crank whose settle point stays under the ceiling. A spent fish
## settles low, so this is flat out; a fresh deep one has to be worked slowly.
static func _crank_for(s: Sim, ceiling: float) -> float:
	var row := Species.by_id(s.fish_id)
	if row.is_empty():
		return 1.0
	var full := Tuning.crank_settle(float(row["run_power"]), s.fish_stamina, 1.0)
	if full <= 0.0001:
		return 1.0
	return clampf(ceiling / full, 0.0, 1.0)


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
