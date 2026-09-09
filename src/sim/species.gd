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
## Fields that decide the two minigames:
##
##   take_window   seconds the real take lasts - the whole of how hard a fish is
##                 to HOOK. A bluegill sits on the bait; a bass is gone again
##   teases        how many false tugs it gives before the take, on average
##   run_chance    how often it bolts instead of coming in quietly
##   stamina       how much tiring it takes before it stops running
##   haul          metres per second gained, relative to REEL_RATE
##   weight        relative chance of being the one that bites
##
## The tuning rule underneath: **a fish is hard because of what it DOES, never
## because the player's tolerances are tighter.** The safe band on the tension
## gauge is the same for every fish in the game - it belongs to the rod, so that
## buying a rod is felt on every species at once, and so the player only ever has
## to learn one gauge.
##
## Difficulty is the PRODUCT of these fields and no single one places a species.
## That caught us out once already: raising the bluegill's run chance while
## leaving another field high made the TUTORIAL fish harder than the one after
## it. `test_golden.gd` asserts the table is a monotonic ladder in written order.

const TABLE := [
	{
		"id": "bluegill",
		"name": "Bluegill",
		"min_depth": 0.0,
		"max_depth": 4.0,
		"weight_lo": 0.10,
		"weight_hi": 0.40,
		"take_window": 0.85,
		"teases": 1.2,
		"run_chance": 0.16,
		"stamina": 0.80,
		"haul": 1.35,
		"weight": 5.0,
	},
	{
		"id": "perch",
		"name": "Yellow Perch",
		"min_depth": 0.6,
		"max_depth": 4.0,
		"weight_lo": 0.20,
		"weight_hi": 0.60,
		"take_window": 0.58,
		"teases": 2.0,
		"run_chance": 0.34,
		"stamina": 1.05,
		"haul": 1.05,
		"weight": 3.5,
	},
	{
		"id": "bass",
		"name": "Largemouth Bass",
		"min_depth": 1.2,
		"max_depth": 4.0,
		"weight_lo": 0.80,
		"weight_hi": 3.00,
		"take_window": 0.40,
		"teases": 2.7,
		"run_chance": 0.55,
		"stamina": 1.70,
		"haul": 0.78,
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


## How many teases this fish gives before the take, from a unit value in [0, 1).
##
## Drawn per bite around the species' average rather than fixed, because a fixed
## count is a metronome: two bites and the player is counting tugs instead of
## watching the float, which is the whole thing the nibble exists to make them do.
static func tease_count(s: Dictionary, unit: float) -> int:
	var avg: float = s["teases"]
	var spread := 1.0
	var n := int(round(avg - spread + clampf(unit, 0.0, 0.999) * (spread * 2.0 + 1.0)))
	return clampi(n, Tuning.TEASE_MIN, Tuning.TEASE_MAX)


## How long the still water between two tugs lasts, from a unit value.
static func tug_gap(unit: float) -> float:
	return Tuning.TUG_GAP_MIN + clampf(unit, 0.0, 1.0) * (Tuning.TUG_GAP_MAX - Tuning.TUG_GAP_MIN)


## Whether the next phase of the fight is a run, from a unit value in [0, 1).
## A tired fish runs less, which is what makes the end of a fight feel different
## from the start rather than merely shorter.
static func runs_next(s: Dictionary, unit: float, stamina_left: float) -> bool:
	var tired := 1.0 - Tuning.TIRED_RELIEF * (1.0 - clampf(stamina_left, 0.0, 1.0))
	return unit < float(s["run_chance"]) * tired


static func calm_seconds(unit: float) -> float:
	return Tuning.CALM_MIN + clampf(unit, 0.0, 1.0) * (Tuning.CALM_MAX - Tuning.CALM_MIN)


static func run_seconds(unit: float, stamina_left: float) -> float:
	var base := Tuning.RUN_MIN + clampf(unit, 0.0, 1.0) * (Tuning.RUN_MAX - Tuning.RUN_MIN)
	var tired := 1.0 - Tuning.TIRED_RELIEF * (1.0 - clampf(stamina_left, 0.0, 1.0))
	return base * maxf(0.35, tired)
