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
##   run_chance    how often it bolts instead of sitting there
##   shake_chance  how often it comes up head-shaking instead of bolting
##   hold_speed    how BUSY it is. Sullen phases are divided by this, so a HIGH
##                 value means short calm windows, more behaviour changes per
##                 second, and therefore more runs to survive per fight. It is a
##                 difficulty knob in its own right, and it caught us out: with
##                 the bluegill's run chance raised AND `hold_speed` left at
##                 1.35, the tutorial fish came out HARDER than the one after
##                 it - 79% landed against the perch's 88%. Difficulty here is
##                 the product of two fields, not either one alone
##   stamina       how much tiring it takes before it gives up
##   haul          metres per completed pump, relative to PUMP_GAIN
##   weight        relative chance of being the one that bites
##
## The tuning rule underneath: **a fish is hard because of what it DOES and how
## often, never because its tolerances are tighter.** Tolerances belong to the
## rod, so that buying a rod is felt on every species at once. A bass is hard
## because it runs nearly half the time and shakes when it does not; a bluegill
## is easy because it mostly just sits there and can be pumped in.

const TABLE := [
	{
		"id": "bluegill",
		"name": "Bluegill",
		"min_depth": 0.0,
		"max_depth": 4.0,
		"weight_lo": 0.10,
		"weight_hi": 0.40,
		"run_chance": 0.20,
		"shake_chance": 0.14,
		"hold_speed": 0.95,
		"stamina": 0.85,
		"haul": 1.30,
		"weight": 5.0,   ## relative chance of being the one that bites
	},
	{
		"id": "perch",
		"name": "Yellow Perch",
		"min_depth": 0.6,
		"max_depth": 4.0,
		"weight_lo": 0.20,
		"weight_hi": 0.60,
		"run_chance": 0.34,
		"shake_chance": 0.24,
		"hold_speed": 1.05,
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
		"run_chance": 0.46,
		"shake_chance": 0.40,
		"hold_speed": 0.82,
		"stamina": 1.75,
		"haul": 0.80,
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


## Which behaviour comes next, from a unit value in [0, 1).
##
## A tired fish runs and shakes less - that is the whole shape of a fight, and it
## is what makes the end of one feel different from the start rather than just
## shorter. Pure, and the caller supplies the draw, so the table stays free of
## the rng and the draw order stays visible at the call site.
static func next_behaviour(s: Dictionary, unit: float, stamina_left: float) -> String:
	var tired := 1.0 - Tuning.TIRED_RELIEF * (1.0 - clampf(stamina_left, 0.0, 1.0))
	var run: float = float(s["run_chance"]) * tired
	var shake: float = float(s["shake_chance"]) * tired
	if unit < run:
		return "running"
	if unit < run + shake:
		return "surfacing"
	return "holding"


## How long a sullen phase lasts, from a unit value in [0, 1).
##
## Scaled by `hold_speed`, so a slow heavy fish gives you LONGER windows to pump
## in and is still harder overall, because the wear clock runs the whole time.
static func hold_seconds(s: Dictionary, unit: float) -> float:
	var span := Tuning.HOLD_MAX - Tuning.HOLD_MIN
	var base := Tuning.HOLD_MIN + clampf(unit, 0.0, 1.0) * span
	return base / maxf(0.2, float(s["hold_speed"]))


## How long a run lasts, from a unit value in [0, 1). Tiredness shortens it,
## for the same reason it makes runs rarer.
static func run_seconds(s: Dictionary, unit: float, stamina_left: float) -> float:
	var span := Tuning.RUN_MAX - Tuning.RUN_MIN
	var base := Tuning.RUN_MIN + clampf(unit, 0.0, 1.0) * span
	var tired := 1.0 - Tuning.TIRED_RELIEF * (1.0 - clampf(stamina_left, 0.0, 1.0))
	return base * maxf(0.35, tired)
