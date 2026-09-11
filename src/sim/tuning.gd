class_name Tuning
extends RefCounted

## Every number that shapes how it feels, in one place, plus the arithmetic
## derived from it.
##
## Pure: nothing here reads live state. That is what lets `test/` check the
## shape of the curves - which is what a balance change accidentally breaks -
## without booting a game.

# --- the water ------------------------------------------------------------
## Reed Bay. The bed is a heightfield in the full game; at M1 it is one number,
## and the water shader will read the same value rather than sampling
## DEPTH_TEXTURE. See PIPELINE.md - that sample is corrupt on Forward Mobile
## with MSAA, and the simulation already owns the answer.
const BED_DEPTH := 4.0

# --- casting --------------------------------------------------------------
const CAST_MIN := 4.0             ## metres, a tapped cast
const CAST_MAX := 22.0            ## metres, fully charged
const CAST_CHARGE_TIME := 1.15    ## seconds of hold from min to max
const CAST_FLIGHT_SPEED := 17.0   ## m/s, so a long cast visibly takes longer
const SINK_RATE := 1.15           ## m/s the lure descends once it lands

# --- waiting for a bite ---------------------------------------------------
const BITE_CHANCE_PER_SEC := 0.55 ## while the lure is at fishing depth
const NIBBLE_TIME := 0.35         ## the rod tip taps - the fish is interested
const SPOOK_TIME := 1.20          ## a wrong strike puts them off for this long

# --- THE FIGHT, third version ---------------------------------------------
##
## Gideon, after playing the second: "it is not very intuitive to tell what you
## are supposed to do. it doesnt need to be realistic fishing mechanics. it can
## just be a fun challenging mini game feel, like tapping to keep the pressure
## on without breaking the line. or a combination of two different mini games,
## like one to hook the fish and one to reel it in. in either case, I think
## having visual on screen queues or gauges would be a good addition"
##
## Built as described, because he named the mechanism. Two minigames:
##
##   1. THE NIBBLE   watch the float. Strike on the real take, not on a tease
##   2. THE REEL     tap to keep the tension needle inside the safe band
##
## **And the gauges are back.** The second fight deleted them, which was an
## over-correction: his complaint about the FIRST fight was that his thumb
## covered the meter, and the fix for that is to move the meter off the thumb,
## not to remove it. The reel's gauge lives at the TOP of the screen and the tap
## target is the whole of it - they cannot overlap, and a tap needs no precision
## of position at all, which is what makes that split possible.

# --- 1. the nibble --------------------------------------------------------
##
## Gideon: "can you make the initial hook portion of the mini game just watching
## the rod or bobber pull down. make it look like a fish is nibbling on the bait
## and pulling on the line. try to use other games as reference for it. the first
## tap sets the hook, then it pulls up the bar to tap and reel in the fish."
##
## So the sweep bar is gone. This is the Animal Crossing shape, which is the one
## worth copying here: the fish TEASES the bait a few times - short shallow tugs
## that pop straight back - and then takes it properly, deeper and for longer.
## Strike on the take and you are on; strike on a tease and you have pulled it
## out of its mouth.
##
## It is better than the bar for exactly the reason he asked for it: the thing
## you watch is the float, in the world, doing what a float does. There is no
## abstraction to learn, and nothing on the HUD at all until a fish is hooked.
## Stardew and Zelda use one cue with no teases, which is a pure timing test; the
## teases are what turn it into a judgement.
const TEASE_MIN := 1              ## teases before the take, inclusive
const TEASE_MAX := 3
const TEASE_TIME := 0.26          ## how long one tease pulls the float under
const TEASE_DEPTH := 0.34         ## how far, relative to a real take
const TUG_GAP_MIN := 0.42         ## still water between tugs
const TUG_GAP_MAX := 0.95
const TAKE_DEPTH := 1.0
const HOOK_PERFECT := 0.45        ## fraction of the take window that is a clean set
const HOOK_PERFECT_BONUS := 0.22  ## tension the fight starts with, on a clean set

# --- 2. the reel ----------------------------------------------------------
## Tapping is the whole input. Each tap kicks the needle up; it falls on its own
## between taps, so holding a rate IS the mechanic and there is no position to
## hold. That is what makes it legible on a phone: the player is doing one thing
## and can see the result of it immediately.
## Gideon: "can you make the taps move the bar in smaller increments as well?"
##
## Halved - but BOTH of them, and that is the point. Taps per second to hold a
## given tension is `TAP_DECAY * tension / TAP_KICK`, so shrinking the kick alone
## would have doubled the tapping rate to about five a second and turned a
## judgement into a dexterity test. Halving the decay with it keeps the rate at
## roughly 2.4/s and makes each tap a finer adjustment, which is what was asked
## for. `test_the_band_is_tappable_at_a_human_rate` is the guard on that.
## THE FIFTH FIGHT: REELING AND TENSION ARE DIFFERENT THINGS.
##
## Gideon: "I think we are not showing a different between reeling speed and
## tension on the line... there should be a give and take, where you can keep
## reeling but risk losing the fish, but if you get in a good rythem and wear the
## fish out, you can reel while the fish is calm and stop when it starts pulling
## too hard."
##
## He named the fault in the MODEL, and he was right. One `tension` value was the
## throttle (holding raised it), the score (progress happened inside a band) and
## the danger (a run raised it) at once, so none of the three could be read. The
## fourth fight made that value a hold instead of a tap, which was an improvement
## to the control and left the conflation exactly where it was.
##
## Three quantities now, and each one answers a different question:
##
##   fish_distance  PROGRESS.  On the meter at the top. The fight is about this.
##   tension        DANGER.    On the ROD - bend, shake, the line going red.
##   fish_stamina   THE RESOURCE that turns danger into progress.
##
## And the loop he described falls straight out of them: reeling in calm water is
## safe and gains ground; reeling while the fish runs gains almost nothing and
## takes the tension up fast; letting go gives the tension back. The fish tires
## itself by RUNNING, not by being reeled - so waiting it out is a real strategy
## that costs the only thing that is actually scarce, which is daylight.
##
## Researched against the games that separate these cleanly. Sea of Thieves keeps
## danger entirely diegetic - rod shake, and reel only when the line goes slack -
## and Fishing Planet keeps a colour-coded tension reading apart from fatigue and
## distance. The failure to avoid is Monster Hunter Wilds, where danger is inferred
## from the rod alone and players report the line parting with no legible warning:
## the rod carries it here, but the LINE going red carries it too, because a
## bending rod is a hard read on a phone at arm's length.

## Tension while the reel is held rises toward `HOLD_RISE * resist / TAP_DECAY`,
## and RESIST is the whole risk dial. See `resist()` below.
##
## BOTH OF THESE MOVED TOGETHER, x2.5, AND THAT IS THE POINT. The settle point is
## their ratio, so scaling the pair leaves every number in the ladder below
## exactly where it was designed and changes only HOW FAST tension gets there.
##
## It had to change because at 0.276/0.50 the time constant was two seconds, and
## a quantity that takes two seconds to move cannot carry a decision: measured, a
## bot with a 0.30 s reaction lag reached 0.747 against a fish whose settle was
## 0.96 and never crossed the danger line at all. Feathering was free, so the risk
## dial was a dial nobody had to turn. At 0.69/1.25 the constant is 0.8 s: holding
## against a fresh Old Town fish reaches the red in about nine tenths of a second,
## the same lag now costs about 0.09 of overshoot, and letting go drops the rod
## visibly rather than sagging.
const HOLD_RISE := 0.69            ## tension per second while REEL is held
const TAP_DECAY := 1.25            ## how fast tension falls back, per second

## HOW HARD THE FISH ITSELF PULLS BACK AGAINST THE REEL, and this is the number
## that makes the fight a fight.
##
## Built after measuring, with `scripts/probe_loss.gd`, what the first cut of the
## fifth fight actually did: **nothing was ever lost.** Not one parted line, not
## one escape, across all twenty-six species and both bots. Every failure was the
## probe's two-minute clock running out. And a bot playing perfectly - releasing
## on the exact frame of every tell - landed 92% against a human-reaction bot's
## 93%, so the give and take was worth one point of skill.
##
## The cause was that holding the reel in calm water settled at 0.55 against a
## danger line of 0.78 FOR EVERY FISH IN THE LAKE. The correct play was therefore
## "hold the button, let go on the tell", which is one bit of information and no
## judgement at all. The risk Gideon asked for existed only during runs, which are
## telegraphed and rare, so most of the fight had no decision in it.
##
## Now a fresh fish fights the reel and a spent one does not:
##
##   resist = 1 + RESIST_GAIN * run_power^2 * stamina_left
##
## Squared, because a linear term could not separate the tutorial from the deep
## without making the tutorial tense. What it buys, as the settle tension a held
## reel reaches against a FRESH fish of each band's mean power:
##
##   The Reeds        0.63   hold it down, nothing happens. This is where the
##                           button is taught, and it has to be safe to learn on
##   The Channel      0.75   visibly bent, still safe. The warning without the bill
##   The Drowned Road 0.78   exactly the danger line: hold it and strain creeps
##   Old Town         0.96   real feathering. A held button parts the line
##   The Quarry       1.01   feather hard
##   The Spring       1.36   the Old Fish cannot be held at all while it is fresh
##
## That ladder is free: `run_power` already has to climb with depth by rule
## (`test_runs_get_stronger_with_depth`), so one species stat now pays for the
## runs AND for the resistance, and the two cannot drift apart.
##
## And because `stamina_left` multiplies it, wearing the fish out is felt in the
## CONTROL rather than read off a number: the same button that parted the line at
## the start of the fight can be held flat at the end of it. That is the sentence
## Gideon wrote - "if you get in a good rythem and wear the fish out" - expressed
## as a thing the thumb learns instead of a thing the HUD says.
const RESIST_GAIN := 0.45

## AND A CEILING ON IT, because past a point "hold it less" stops being a
## judgement and becomes a reflex test.
##
## Uncapped, the Old Fish's run_power of 1.806 gave a settle of 1.36 - the tension
## pins at the top the instant the reel is touched, so the only play is taps
## shorter than a person's reaction time. Measured: ANGLER, which is perfect and
## instant, landed 44% of them; HUMAN, which is the same player with three tenths
## of a second of lag, landed NONE and parted the line on three quarters of them.
## A gap that size between the same decision made perfectly and made by a person
## is the definition of a dexterity wall, and this game is meant to be about
## watching rather than reflexes.
##
## 1.9 caps the settle at about 1.05 - still unholdable, still the hardest thing
## in the lake, but a short press survives it. Everything up to and including the
## Quarry sits under the cap already, so this touches exactly one fish.
const RESIST_MAX := 1.9

## PRESSURE IS WHAT TIRES IT, alongside the running.
##
## Without this the player has no lever on the length of a fight: the fish tired
## itself by running and nothing else, so every fight took as long as the fish
## decided it would, and the difficulty "ladder" between bands was really just a
## ladder of fight lengths. Deep fish were not hard, they were slow.
##
## Draining stamina in proportion to TENSION is what turns the risk dial into a
## reward. Fishing at 0.95 tires a fish roughly twice as fast as fishing at 0.50,
## so the greedy line is genuinely faster and genuinely near the edge - which is
## the rule CRAFT.md has carried for a while and this game had not honoured since
## the band's greed dial went away with the band.
const TIRE_PRESSURE := 0.10


## The fish's resistance to the reel: a multiplier on `HOLD_RISE`.
##
## Pure and shared, so the settle tension the tests assert, the number the rod's
## bend is drawn from and the value the fight runs on are all one thing.
static func resist(power: float, stamina_left: float) -> float:
	return minf(RESIST_MAX, 1.0 + RESIST_GAIN * power * power * clampf(stamina_left, 0.0, 1.0))


## Where a held reel settles against a given fish. `HOLD_RISE * resist` is pushed
## against a decay proportional to the tension itself, so this is the fixed point.
static func hold_settle(power: float, stamina_left: float) -> float:
	return HOLD_RISE * resist(power, stamina_left) / TAP_DECAY

## What a running fish adds while you keep reeling into it. This is the give and
## take, and the number is measured rather than chosen: at 1.25 it crossed DANGER
## in 0.20 s, which is faster than anyone can react to and therefore reads as the
## game cheating. Scaled with HOLD_RISE and TAP_DECAY, x2.5, because it is a rise
## pushed against the same decay: leaving it behind would have quietly made runs
## weaker than they were the moment the pair moved.
##
## Reeling into a run from a power-1.0 fish pins the tension at the top, so the
## line parts SNAP_SECONDS later unless the thumb comes off. That is exactly the
## promise - "you can keep reeling but risk losing the fish" - and it is a second
## and a bit of warning, not an instant.
##
## SCALED BY run_power SQUARED, the same shape `resist` uses, and for the same
## reason: linear, it made the TUTORIAL part a line. A reeds fish held right
## through one of its runs pinned the tension and broke off in 1.2 s, which is the
## first water teaching a beginner that the reel button is a trap. Squared, a
## reeds run settles at 0.87 - the rod reddens and shakes and holds - while a
## Channel fish still pins in about a second. The first water forgives and nothing
## after it does, which is the shape a tutorial is supposed to have.
const PULL_RISE := 1.05            ## tension per second, scaled by run_power squared

## Where the rod reads as over-bent: the line reddens, the heavy haptic fires, and
## strain starts accruing. Named rather than derived, because it is the one number
## the whole feel of the fight hangs on.
const DANGER := 0.78

## From "dangerously bent" to a parted line, at full overshoot. 1.2 seconds, which
## the research puts at the forgiving end on purpose - a snap has to be a decision
## the player made, never a surprise.
const SNAP_SECONDS := 1.2

## Where a hooked fish starts, and where a "slack" line sits. The band the fourth
## fight was built around is gone with its needle - there is nothing to hold the
## needle inside of any more - but this is still the tension a fresh hook begins
## at, so it keeps its name and its value.
const SAFE_LO := 0.42

## Kept as an alias for DANGER. Several assertions and the greed dial were written
## against SAFE_HI, and pointing it at the one real number means there is still
## only one place to move the danger line.
const SAFE_HI := DANGER

const TENSION_MAX := 1.0

const REEL_RATE := 1.55           ## m/s gained while reeling in calm water

## HOLDING ON SLOWS THE RUN ITSELF. This is the gamble, and it had to stop being
## an additive reel term to become one.
##
## It was `REEL_INTO_RUN := 0.25`, a quarter of the normal haul applied while the
## fish ran - about 0.24 m/s against a strong fish taking 5.2. Measured on a
## Longnose Gar, holding on through a full run bought back a third of a metre out
## of twelve. So "keep reeling and risk it" was never a real option: the correct
## play was always to let go, and the fight had one strategy and no dial.
##
## As a brake on the run instead, holding on cuts the ground the fish takes by
## more than half. Now the sentence works in both directions: let go and the fish
## takes line but the rod is safe; hold on and you keep it close while the tension
## pins at the top and the line has SNAP_SECONDS left. That is the give and take.
const RUN_HOLD := 0.40            ## fraction of a run's gain cancelled by holding on
## STRAIN BLEEDS OFF SLOWLY, and that is what makes "eventually" true.
##
## At 0.40 a second, three seconds of calm wiped every bit of damage a run had
## done, so a player who over-bent the rod on every single run paid nothing across
## a whole fight - measured, a blind 80% duty cycle landed a lake trout about as
## fast as attentive play. At 0.12 the damage accumulates, so repeatedly holding
## on through runs parts the line eventually even if no single run does it. That
## is the sentence he actually wrote: "then eventually snaps, if you dont stop
## reeling."
const STRAIN_RECOVER := 0.025

## Runs. The needle climbs ON ITS OWN, so the correct answer is to STOP TAPPING -
## which is legible on a gauge in a way that no amount of instruction would be.
## The player sees the needle rising without their input and understands.
## The JOLT is what makes the warning load-bearing. A run adds this to the needle
## the instant it starts, so what decides the outcome is whether the player had
## ALREADY stopped tapping - not how fast they can react afterwards. Without it a
## rate-controller simply corrects its way out of every run and nothing about the
## fight is a decision.
## Both of these are coupled to TAP_DECAY and had to move with it. The settle
## point of a run left alone is RUN_PULL / TAP_DECAY, so halving the decay put it
## at 0.78 - the top of the band - and made a run unsurvivable however it was
## played. The tests caught it immediately, which is what they are for.
## THE KICK YOU FEEL WHEN IT GOES, and deliberately not enough to hurt on its own.
##
## At 0.33 the jolt alone carried tension past DANGER for any decent fish, so a
## player who let go the instant the rod moved still took damage - which
## contradicts the promise the whole fifth fight is built on. It is the thing the
## small haptic is matched to now: you feel the fish go, and what happens next is
## entirely your decision. 0.12 keeps even the strongest fish's kick just under
## the danger line from a normal reeling tension.
const RUN_JOLT := 0.22

## THE LADDER LIVES HERE, because this is the term `run_power` multiplies.
##
## Ground lost during a run is `RUN_GAIN * run_power * seconds`, and run_power is
## the one species stat that climbs with depth by rule, so raising this number
## makes deep water harder faster than it makes shallow water harder. That is the
## only honest way to steepen the band ladder: the alternative, scaling run_power
## per band to chase a catch rate, breaks the thing run_power is FOR and was
## caught by `test_runs_get_stronger_with_depth` within a minute of trying it.
##
## Measured across the six bands, mean landed with the `human` bot:
##
##   3.4    100  99  88  65  31  4     the Channel is not a step up from the Reeds
##   3.9    100  93  76  56  26  4     every rung a real step
##   4.4    100  81  61  42  23  4     the Channel starts losing fish to beginners
##
## 3.9 is the first value where every band is meaningfully harder than the one
## above it. At 3.9 a strong deep fish takes back about nine metres in one run,
## which is a shock on the distance meter and is meant to be.
const RUN_GAIN := 3.9             ## m/s it takes back during one
## How much of a species' `run_power` reaches the opening jolt. The sustained
## pull takes all of it; the spike takes a little over half, which is what turns
## run_power from a pass/fail switch into a dial. See the note in `sim.gd`.
static func jolt_scale(power: float) -> float:
	# COMPRESSED HARDER SINCE THE FIGHT BECAME A HOLD. At 0.55 + 0.45p a reeds
	# fish still landed 70% of the full jolt, which was enough to break a
	# beginner who had not yet learned to let go - measured, the reeds took five
	# fish off `blind` across six seeds, in the band whose whole job is to charge
	# for a missed tell in TIME rather than in fish. At 0.25 + 0.75p a weak fish
	# lands half the jolt and a strong one lands more than before, which widens
	# the ladder from both ends at once.
	return 0.18 + 0.82 * power


const RUN_MIN := 1.2
const RUN_MAX := 2.4
const TELL_TIME := 0.65           ## warning before a run - just over a reaction time

const CALM_MIN := 2.2             ## seconds of ordinary reeling between runs
const CALM_MAX := 4.6

## Losing. The fish reaching this far past where it was hooked means it has
## found cover or taken all the line - a legible, thematic way to lose that is
## not "a bar filled up".
##
## SIX METRES WAS ONE RUN. A traced Longnose Gar fight ended at 4.2 seconds: the
## fish's first run moved it from 22 m to 28 m and it was gone, with the player's
## only decision - hold on or let go - worth a third of a metre. That is a coin
## flip wearing a mechanic's clothes, and it was the single biggest reason deep
## water scored badly.
##
## At fourteen, one maximum-length run from a strong fish very nearly escapes if
## you let it go and does not if you hold on. The margin is the fight.
const ESCAPE_MARGIN := 18.0

const TIRE_RATE := 0.20           ## stamina per second while being reeled
const TIRED_RELIEF := 0.60        ## how much of the fish's fight tiredness removes

# --- landing --------------------------------------------------------------
const LAND_DISTANCE := 0.35       ## metres from the boat, near enough to net
const HOLD_TIME := 2.4            ## seconds the fish is held up and looked at


## Cast distance for a charge in [0, 1]. Linear on purpose: a curve here makes
## the thumb-to-distance relationship something the player has to learn twice,
## once for the arc and once for the charge.
static func cast_distance(charge: float) -> float:
	return CAST_MIN + clampf(charge, 0.0, 1.0) * (CAST_MAX - CAST_MIN)


## How long a cast takes to reach the water. Used by the tests to assert the
## flight is a sane length rather than to drive anything.
static func cast_flight_seconds(charge: float) -> float:
	return cast_distance(charge) / CAST_FLIGHT_SPEED


static func sink_speed(target_depth: float) -> float:
	return 1.0 + maxf(0.0, target_depth - 4.0) * 0.42
