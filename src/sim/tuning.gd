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
## THE FOURTH FIGHT: THE ROD IS REELED BY HOLDING A BUTTON.
##
## Gideon: "there is no dedicated button to fill the bar. I want a button instead
## of just tapping the screen."
##
## `HOLD_RISE` replaces the tap's instant kick. The arithmetic is the same shape -
## something pushes tension up, decay pulls it down - but the input is now one
## control with one resting state instead of a rate the player has to guess at.
##
## THE EQUILIBRIUM MUST SIT ABOVE THE BAND, and getting that wrong the first time
## is worth recording because it silently undid the whole fight.
##
## A held button rises at `HOLD_RISE` and decays at `TAP_DECAY * tension`, so
## holding forever settles at `HOLD_RISE / TAP_DECAY`. The first attempt derived
## HOLD_RISE from the old tap rate (0.058 x 2.4/s = 0.139), which put that settle
## point at **0.60 - inside the safe band**. Holding the button down therefore
## parked the needle in the green and reeled the fish in with no further input:
## exactly the "one correct sustained input" that killed the FIRST fight, arrived
## at from the opposite direction. Measured, it showed as `blind` and `angler`
## posting identical scores, which is the invariant that every policy must fail
## for a different reason doing its job.
##
## So the settle point is now 1.10 - above `TENSION_MAX`, so a held button always
## ends in a snapped line - and both numbers were raised together to keep the
## CYCLE quick: about 1.4 s to cross the band with the thumb down and 1.1 s to
## fall back with it up, against 3.7 s and 2.7 s at the old decay. `RUN_PULL`
## moved with `TAP_DECAY` because a run left alone settles at their ratio, which
## NOTES.md says must stay just under the band.
##
## The property that must survive is the one that killed the FIRST fight: no
## sustained input may win. Held forever the line parts; released forever the fish
## takes line and goes. There is no setting to find, only a duty cycle to
## modulate - and `test_there_is_no_setting_that_wins_on_its_own` still says so.
const HOLD_RISE := 0.418          ## tension per second while REEL is held
const TAP_KICK := 0.058           ## how far one tap moves the needle
const TAP_DECAY := 0.38           ## how fast it falls back, per second
const SAFE_LO := 0.42             ## bottom of the green band
const SAFE_HI := 0.78             ## top of it
const TENSION_MAX := 1.0

## GREED IS THE RISK DIAL, and this is what makes the fight risk/reward rather
## than a maintenance task.
##
## The band used to be pass or fail: anywhere inside it hauled at one rate, so the
## correct play was the middle and there was nothing to weigh. Now the haul scales
## from `BAND_GREED_LO` at the bottom of the band to `BAND_GREED_HI` at the top -
## so the fastest water to fish in is the inch below the strain zone.
##
## A cautious player lands everything, slowly. A greedy one lands more per minute
## and snaps some lines. In deep water, where the clock is the resource that is
## actually scarce, that is a real choice with a real cost. CRAFT.md has had "give
## the player a risk dial they hold themselves, and the greedy option is genuinely
## better and genuinely near the edge" for a while; this game had not honoured it.
const BAND_GREED_LO := 0.62       ## haul multiplier at the bottom of the band
const BAND_GREED_HI := 1.62       ## ...and at the top, one step from the strain
const REEL_RATE := 1.55           ## m/s gained while the needle is in the band
const SLIP_RATE := 0.62           ## m/s the fish takes back while below the band
const STRAIN_RATE := 5.0         ## toward a snapped line, while above the band
const STRAIN_RECOVER := 0.40      ## strain bleeding off once you stop

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
const RUN_JOLT := 0.33            ## tension added the moment a run begins
const RUN_PULL := 0.149           ## tension per second it adds while it lasts
const RUN_GAIN := 1.05            ## m/s it takes back during one
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
const ESCAPE_MARGIN := 6.0

const TIRE_RATE := 0.30           ## stamina per second while being reeled
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


## True if the tension is where it should be. One function, used by the rules
## AND by the gauge that draws the band, so what the player sees and what the
## game scores cannot drift apart.
static func in_band(tension: float) -> bool:
	return tension >= SAFE_LO and tension <= SAFE_HI


## How many taps per second it takes to hold the needle at a given level.
##
## Not used by the game - it exists so the tests can assert the mechanic is
## PHYSICALLY TAPPABLE. A band that needs eleven taps a second is unplayable on
## a phone however good it looks in a diagram, and that is not something a
## screenshot or a bot would ever reveal.
static func taps_per_second_for(tension: float) -> float:
	return (TAP_DECAY * tension) / TAP_KICK


## How fast the lure sinks, scaled so a deep drop does not become a wait.
##
## At 140 m a constant 1.15 m/s is two minutes of watching a line go down, which
## is not atmosphere, it is a loading screen. The rate rises with the target so
## the descent is always a handful of seconds - and it stays SLOWEST in the reeds,
## where the player is learning and the sink is the only beat between casting and
## fishing.
static func sink_speed(target_depth: float) -> float:
	return 1.0 + maxf(0.0, target_depth - 4.0) * 0.42


## How hard the haul pulls, given where in the band the needle is sitting.
##
## Linear between the two ends, and clamped, so a needle outside the band is not
## asked about - the caller has already decided that case. Pure, so the test can
## assert the shape of the dial without running a fight.
static func greed(t: float) -> float:
	var k := clampf((t - SAFE_LO) / maxf(0.001, SAFE_HI - SAFE_LO), 0.0, 1.0)
	return lerpf(BAND_GREED_LO, BAND_GREED_HI, k)


## How long the thumb spends DOWN to cross the band, and UP to fall back across
## it. Together they are one cycle of the fight, and the pair is what decides
## whether it reads as a rhythm or as a chore.
##
## Closed form rather than simulated: tension approaches `HOLD_RISE / TAP_DECAY`
## from below while held and decays exponentially while released, so both legs
## are logarithms. Pure, so a test can assert the FEEL of the fight without
## running one.
static func hold_seconds_across_band() -> float:
	var eq := HOLD_RISE / TAP_DECAY
	return -log((SAFE_HI - eq) / (SAFE_LO - eq)) / TAP_DECAY


static func release_seconds_across_band() -> float:
	return log(SAFE_HI / SAFE_LO) / TAP_DECAY
