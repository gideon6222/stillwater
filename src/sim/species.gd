class_name Species
extends RefCounted

## What lives in the water, as data.
##
## A species is a row, not a class and not a scene. That is deliberate and it is
## the same reason the fish are drawn by a generator rather than imported as
## models: **the shape of a fish is gameplay state.** A Thin Perch is a perch
## with a wrong length; a Second Line is one more stripe. Once the wrong ones
## arrive in Act III they are rows in this table with different numbers, and
## nothing else in the game has to learn about them.
##
## Fields that decide the fight:
##
##   pull     the fish's steady drag on the line, in tension units
##   surge    how far it swings either side of that
##   period   seconds per surge cycle - low is frantic, high is heavy
##   band     the safe band's width BEFORE the rod's forgiveness is added
##   stamina  seconds of in-band pressure needed to tire it out
##   haul     metres per second gained, relative to RETRIEVE_RATE
##
## The tuning rule underneath: a fish is hard because its surge is wide and its
## period is short, never because its band is narrow. Narrowing the band is the
## ROD's job, so that buying a rod is felt on every species at once.

const TABLE := [
	{
		"id": "bluegill",
		"name": "Bluegill",
		"min_depth": 0.0,
		"max_depth": 4.0,
		"weight_lo": 0.10,
		"weight_hi": 0.40,
		"pull": 0.22,
		"surge": 0.08,
		"period": 2.1,
		"band": 0.36,
		"stamina": 0.85,
		"haul": 2.2,
		"weight": 5.0,   ## relative chance of being the one that bites
	},
	{
		"id": "perch",
		"name": "Yellow Perch",
		"min_depth": 0.6,
		"max_depth": 4.0,
		"weight_lo": 0.20,
		"weight_hi": 0.60,
		"pull": 0.26,
		"surge": 0.13,
		"period": 1.5,
		"band": 0.32,
		"stamina": 1.00,
		"haul": 1.8,
		"weight": 3.5,
	},
	{
		"id": "bass",
		"name": "Largemouth Bass",
		"min_depth": 1.2,
		"max_depth": 4.0,
		"weight_lo": 0.80,
		"weight_hi": 3.00,
		"pull": 0.34,
		"surge": 0.20,
		"period": 1.1,
		"band": 0.26,
		"stamina": 1.70,
		"haul": 1.0,
		"weight": 1.5,
	},
]


## Rows that can be hooked at this depth. Empty is a legitimate answer and the
## caller must handle it - a lure above every species' minimum catches nothing,
## which is a real thing a player can do and must not be a crash.
##
## The trap this hides is worth naming, because a test found it before a player
## did: **the lure sinks to the bed, so a species whose `max_depth` is above the
## bed of every water it lives in can never be caught at all.** The bluegill
## shipped that way for an hour - the commonest fish in the game, unreachable,
## with nothing anywhere reporting a problem. `test_tuning.gd` now asserts every
## row is reachable somewhere.
static func at_depth(depth: float) -> Array:
	var out := []
	for s in TABLE:
		if depth >= s["min_depth"] and depth <= s["max_depth"]:
			out.append(s)
	return out


## Pick one, weighted, from a unit value in [0, 1). The caller supplies the
## value from SimRng rather than drawing here, so the table stays pure and the
## draw order is visible at the call site - which is what keeps the golden from
## shifting when this function changes.
static func pick(depth: float, unit: float) -> Dictionary:
	var rows := at_depth(depth)
	if rows.is_empty():
		return {}
	var total := 0.0
	for s in rows:
		total += s["weight"]
	var t := clampf(unit, 0.0, 0.999999) * total
	for s in rows:
		t -= s["weight"]
		if t <= 0.0:
			return s
	return rows[rows.size() - 1]


## Look a row up by id. Returns an empty dictionary for an unknown id rather
## than asserting, so a save from an older build cannot hard-fail the boot.
static func by_id(id: String) -> Dictionary:
	for s in TABLE:
		if s["id"] == id:
			return s
	return {}


## The fish's pull right now: a steady drag plus a surge, eased off as it tires.
## Pure, so the tests can plot the curve without standing a fight up.
static func pull_at(s: Dictionary, t: float, stamina_left: float) -> float:
	var base: float = s["pull"]
	var surge: float = s["surge"]
	var period: float = s["period"]
	var tired := 1.0 - Tuning.TIRED_RELIEF * (1.0 - clampf(stamina_left, 0.0, 1.0))
	return (base + surge * sin(TAU * t / period)) * tired
