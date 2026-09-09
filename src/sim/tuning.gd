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
const NIBBLE_TIME := 0.40         ## warning taps before the take
const BITE_WINDOW := 0.45         ## seconds to strike, and the whole tutorial
const SPOOK_TIME := 1.20          ## a wrong strike puts them off for this long

# --- the rod --------------------------------------------------------------
## The inherited cane rod. Rods differ by the WIDTH OF THE BAND and nothing
## else - not by a damage number - which is legible in ten seconds of use.
const ROD_GAIN := 1.0             ## thumb travel to rod load
const ROD_FORGIVENESS := 0.10     ## the cane is slow and soft; graphite will be 0

# --- the fight ------------------------------------------------------------
##
## THE SECOND FIGHT. The first was a threshold model - hold the tension inside a
## band - and it failed for two reasons Gideon named exactly on 2026-09-09: it
## was too easy, and his thumb covered the meter he was supposed to be reading.
##
## Both have the same root, and it is worth stating because it will come up
## again: **a threshold fight settles into ONE correct sustained input.** Once
## the player finds the thumb position that holds the needle in the band, the
## mechanic is over - there is nothing left to do but not move. The scripted
## angler landed 6.83 fish and lost zero, which was the same fact showing up in
## the probe a day before a human felt it.
##
## So the band is gone, and with it the meter. There is no HUD gauge at all now:
## the ROD's bend is the tension, the float's wake is the fish's bearing, and the
## thumb drags anywhere on the lower half of the screen. Nothing you touch is
## anything you look at.
##
## What replaces it is three fish behaviours, each wanting a different response,
## each telegraphed in the water before it starts:
##
##   HOLDING     it sits there  -> PUMP: lift, then lower to take up line
##   RUNNING     it takes off   -> GIVE: drop the rod and lose ground
##   SURFACING   it head-shakes -> HOLD STEADY at mid load, and do not move
##
## No single thumb position is right for more than a couple of seconds, because
## gaining line at all requires a rhythm rather than a value.
const LOAD_RATE := 5.2            ## how fast the rod follows the thumb
const LOAD_MAX := 1.0

## Pumping. A cycle is a lift above HIGH followed by a drop below LOW, and line
## is gained on the DOWN stroke - which is what a real pump is: you lift against
## the fish, then take up the slack you just made. Holding a steady lift gains
## nothing at all, and that single rule is what killed the first fight's exploit.
const PUMP_HIGH := 0.60           ## the lift has to clear this to count
const PUMP_LOW := 0.26            ## and then drop below this
const PUMP_GAIN := 2.35           ## metres per completed pump, at full peak
const PUMP_TIRE := 0.20           ## stamina taken per completed pump

## The risk dial the player actually holds. Gain scales with how high the lift
## went, and the line starts taking damage just above the most profitable pump -
## so a greedy pump is worth more and is genuinely close to the edge.
const STRAIN_START := 0.82        ## load above this damages the line
const STRAIN_RATE := 1.15         ## toward a break, scaled by how far over

## Runs. The fish takes line and there is nothing to do but let it: hold any real
## load during a run and the line parts quickly. Giving costs ground, which is
## the price, and the run ends on its own.
const GIVE_MAX := 0.30            ## load allowed during a run
const RUN_STRAIN := 3.40           ## damage rate when you hold on through one
const RUN_SPEED := 2.50           ## metres per second it takes back
const RUN_SURGE := 2.20           ## extra strain multiplier at the instant a run starts
const RUN_SURGE_DECAY := 0.33     ## seconds for that surge to fade

## Head-shakes at the surface. The opportunity and the trap: it tires the fish
## fastest, and it is the only time MOVING the thumb is the mistake.
const SHAKE_LO := 0.38
const SHAKE_HI := 0.64
const SHAKE_STILL := 0.85         ## thumb speed above this counts as moving
const SHAKE_SLIP := 1.05          ## toward a thrown hook
const SHAKE_TIRE := 0.62          ## stamina per second while held correctly

## Wear. Grows for the whole fight and faster under load, so playing it safe is
## also a way to lose. Without this a cautious player could take all day, and
## "take all day" is the strategy every forgiving fishing minigame collapses to.
const WEAR_RATE := 0.0215         ## per second, always
const WEAR_LOAD := 0.030          ## per second more, at full load
const SLACK_SLIP := 0.34          ## slack for a long time and it works loose

## How long each behaviour lasts, and the warning before it starts. The tell is
## the whole reason this is a game of awareness rather than reaction: a player
## watching the water drops the rod before the run begins and takes no damage.
const TELL_TIME := 0.34
const HOLD_MIN := 1.5
const HOLD_MAX := 3.4
const RUN_MIN := 1.1
const RUN_MAX := 2.3
const SHAKE_TIME := 1.5

const RECOVER_RATE := 0.26        ## strain bleeding off when the line is behaving
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


## Where the line starts taking damage, once the rod's forgiveness is in.
##
## This is the rod ladder's one lever, and it works the same way the band did:
## a softer rod lets you pump higher before the line complains, so it forgives a
## greedy pump. It does NOT make the fish weaker. Buying a rod is felt on every
## species at once, which is the property worth keeping.
static func strain_start() -> float:
	return minf(0.96, STRAIN_START + ROD_FORGIVENESS)


## Line gained by a pump that peaked at `peak`.
##
## Scales with the peak so the risk dial is real: a pump to the strain threshold
## is worth roughly three times one to the minimum, and the threshold is close
## enough above the profitable range that a greedy player will sometimes go
## through it. Below PUMP_HIGH there is no pump and no gain at all.
static func pump_gain(peak: float, haul: float) -> float:
	if peak < PUMP_HIGH:
		return 0.0
	var over := (clampf(peak, PUMP_HIGH, 1.0) - PUMP_HIGH) / maxf(0.001, 1.0 - PUMP_HIGH)
	return PUMP_GAIN * (0.34 + 0.66 * over) * haul


## True if the load is where a head-shake wants it. A narrow window, and the
## only place in the fight where holding still is the correct answer.
static func shake_ok(load: float) -> bool:
	return load >= SHAKE_LO and load <= SHAKE_HI
