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
const ROD_GAIN := 1.0             ## thumb travel to tension
const ROD_BAND_BONUS := 0.10      ## the cane is forgiving; graphite will be 0

# --- the fight ------------------------------------------------------------
## The band is FIXED and the fish's pull is what pushes tension around it, so
## staying inside means tracking the fish: give line when it surges, take it
## back when it rests. A band centred on the fish would need one constant thumb
## position and would not be a mechanic at all.
const BAND_CENTRE := 0.70
const TENSION_MAX := 1.30         ## headroom above the band, so a break is reachable
const TENSION_RATE := 4.0         ## how fast tension follows the demand
const RETRIEVE_RATE := 1.25       ## m/s gained while inside the band
const STRESS_RATE := 0.90         ## over the band, toward a snapped line
const SLIP_RATE := 0.75           ## under the band, toward a thrown hook
const RECOVER_RATE := 0.50        ## stress and slip bleeding off inside the band
const STAMINA_DRAIN := 0.34       ## per second inside the band
const TIRED_RELIEF := 0.60        ## how much of the fish's pull tiredness removes

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


## Half-width of the safe band for a species, once the rod's forgiveness is in.
## Clamped so no rod can make the band cover the whole range, which would
## remove the mechanic rather than make it easy.
static func band_half(species_band: float) -> float:
	return minf(0.42, species_band * 0.5 + ROD_BAND_BONUS)


## The bottom of the safe band. Below this the hook is working loose.
static func band_lo(species_band: float) -> float:
	return BAND_CENTRE - band_half(species_band)


## The top of the safe band. Above this the line is being damaged.
static func band_hi(species_band: float) -> float:
	return BAND_CENTRE + band_half(species_band)
