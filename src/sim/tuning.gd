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
##   1. THE HOOK   a marker sweeps a bar; tap while it is in the green zone
##   2. THE REEL   tap to keep the tension needle inside the safe band
##
## **And the gauges are back.** The second fight deleted them, which was an
## over-correction: his complaint about the FIRST fight was that his thumb
## covered the meter, and the fix for that is to move the meter off the thumb,
## not to remove it. Readouts live at the TOP of the screen now and the tap
## target is the whole bottom - so they cannot overlap, and a tap needs no
## precision of position at all, which is what makes that split possible.

# --- 1. the hook ----------------------------------------------------------
const HOOK_SWEEPS := 2.0          ## full passes before it loses interest
const HOOK_ZONE_MIN := 0.10       ## the green zone never gets smaller than this
const HOOK_PERFECT := 0.35        ## fraction of the zone that counts as dead centre
const HOOK_PERFECT_BONUS := 0.22  ## tension the fight starts with, on a perfect set

# --- 2. the reel ----------------------------------------------------------
## Tapping is the whole input. Each tap kicks the needle up; it falls on its own
## between taps, so holding a rate IS the mechanic and there is no position to
## hold. That is what makes it legible on a phone: the player is doing one thing
## and can see the result of it immediately.
const TAP_KICK := 0.115           ## how far one tap moves the needle
const TAP_DECAY := 0.46           ## how fast it falls back, per second
const SAFE_LO := 0.42             ## bottom of the green band
const SAFE_HI := 0.78             ## top of it
const TENSION_MAX := 1.0

const REEL_RATE := 1.55           ## m/s gained while the needle is in the band
const SLIP_RATE := 0.62           ## m/s the fish takes back while below the band
const STRAIN_RATE := 4.40         ## toward a snapped line, while above the band
const STRAIN_RECOVER := 0.40      ## strain bleeding off once you stop

## Runs. The needle climbs ON ITS OWN, so the correct answer is to STOP TAPPING -
## which is legible on a gauge in a way that no amount of instruction would be.
## The player sees the needle rising without their input and understands.
## The JOLT is what makes the warning load-bearing. A run adds this to the needle
## the instant it starts, so what decides the outcome is whether the player had
## ALREADY stopped tapping - not how fast they can react afterwards. Without it a
## rate-controller simply corrects its way out of every run and nothing about the
## fight is a decision.
const RUN_JOLT := 0.30            ## tension added the moment a run begins
const RUN_PULL := 0.18            ## tension per second it adds while it lasts
const RUN_GAIN := 1.05            ## m/s it takes back during one
const RUN_MIN := 1.2
const RUN_MAX := 2.4
const TELL_TIME := 0.45           ## warning before a run - just over a reaction time

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
