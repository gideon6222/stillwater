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
##   run_power     how hard that bolt pulls, as a multiple of the run constants.
##                 SEPARATE FROM run_chance on purpose - see below
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
## **Frequency teaches, power punishes, and they must not be the same number.**
## They were, once: `run_power` did not exist and every run in the game pulled
## identically hard, so the only way to make a fish harder was to make it run
## more often. Balancing the reeds to be winnable therefore balanced the runs OUT
## of them, and a player could finish the tutorial without ever meeting the
## mechanic the entire fight is built on. The test that caught it was the one
## asserting a blind player loses fish: blind and watchful both scored zero,
## because there was nothing to watch.
##
## So the reeds now run CONSTANTLY at a third of the strength - the mechanic is
## taught in the first five minutes at almost no cost - and the deep runs less
## often for very much more. Depth raises the stakes, never the tempo.
##
## `run_power` has a hard ceiling that is arithmetic, not taste. A run left alone
## settles at `RUN_PULL * power / TAP_DECAY`; at power 2.0 that is 0.78, exactly
## the top of the safe band, and the fish is unlosable-by-playing-well. Nothing
## in this table may exceed 1.75, and `test_tuning.gd` asserts it.
##
## Difficulty is the PRODUCT of these fields and no single one places a species.
## That caught us out once already: raising the bluegill's run chance while
## leaving another field high made the TUTORIAL fish harder than the one after
## it. `test_golden.gd` asserts the ladder - by BAND, not by row, because the
## order inside a band is content and a band is entitled to an easy fish.
##
## Fields the LOGBOOK and the shed use:
##
##   value         what the shed pays per fish, before the weight bonus
##   wrong         this one is not right, and the logbook says so in its own hand
##   hour          only bites at these times of day, empty means any
##   band          which depth band it belongs to, for the logbook's ordering

const TABLE := [
	# --- The Reeds, 0-4 m, 2026 back to 2011 --------------------------------
	{
		"id": "bluegill",
		"name": "Bluegill",
		"band": "reeds",
		"min_depth": 0.0,
		"max_depth": 4.0,
		"weight_lo": 0.10,
		"weight_hi": 0.40,
		"value": 3,
		"take_window": 0.85,
		"teases": 1.2,
		"run_chance": 0.42,
		"run_power": 0.52,
		"stamina": 0.80,
		"haul": 1.35,
		"weight": 5.0,
	},
	{
		"id": "shiner",
		"name": "Golden Shiner",
		"band": "reeds",
		"min_depth": 0.0,
		"max_depth": 3.0,
		"weight_lo": 0.02,
		"weight_hi": 0.10,
		"value": 1,
		"take_window": 0.95,
		"teases": 1.0,
		"run_chance": 0.38,
		"run_power": 0.46,
		"stamina": 0.55,
		"haul": 1.60,
		"weight": 2.5,
	},
	{
		"id": "perch",
		"name": "Yellow Perch",
		"band": "reeds",
		"min_depth": 0.6,
		"max_depth": 4.0,
		"weight_lo": 0.20,
		"weight_hi": 0.60,
		"value": 5,
		"take_window": 0.58,
		"teases": 2.0,
		"run_chance": 0.45,
		"run_power": 0.65,
		"stamina": 1.05,
		"haul": 1.05,
		"weight": 3.5,
	},
	{
		"id": "bass",
		"name": "Largemouth Bass",
		"band": "reeds",
		"min_depth": 1.2,
		"max_depth": 5.0,
		"weight_lo": 0.80,
		"weight_hi": 3.00,
		"value": 18,
		"take_window": 0.40,
		"teases": 2.7,
		"run_chance": 0.55,
		"run_power": 0.74,
		"stamina": 1.70,
		"haul": 0.78,
		"weight": 1.5,
	},
	{
		"id": "carp",
		"name": "Common Carp",
		"band": "reeds",
		"min_depth": 2.0,
		"max_depth": 8.0,
		"weight_lo": 3.00,
		"weight_hi": 12.00,
		"value": 14,
		"take_window": 0.70,
		"teases": 2.2,
		"run_chance": 0.34,
		"run_power": 0.72,
		"stamina": 2.40,
		"haul": 0.62,
		"weight": 1.2,
	},

	# --- The Channel, 4-15 m, 2011 back to 1968 -----------------------------
	{
		"id": "smallmouth",
		"name": "Smallmouth Bass",
		"band": "channel",
		"min_depth": 4.0,
		"max_depth": 12.0,
		"weight_lo": 0.70,
		"weight_hi": 2.50,
		"value": 20,
		"take_window": 0.42,
		"teases": 2.4,
		"run_chance": 0.52,
		"run_power": 0.82,
		"stamina": 1.55,
		"haul": 0.86,
		"weight": 2.6,
	},
	{
		"id": "sucker",
		"name": "White Sucker",
		"band": "channel",
		"min_depth": 4.0,
		"max_depth": 14.0,
		"weight_lo": 0.50,
		"weight_hi": 2.00,
		"value": 6,
		"take_window": 0.90,
		"teases": 1.4,
		"run_chance": 0.30,
		"run_power": 0.62,
		"stamina": 1.10,
		"haul": 1.15,
		"weight": 3.2,
	},
	{
		"id": "walleye",
		"name": "Walleye",
		"band": "channel",
		"min_depth": 6.0,
		"max_depth": 15.0,
		"weight_lo": 1.00,
		"weight_hi": 4.00,
		"value": 30,
		"take_window": 0.48,
		"teases": 2.3,
		"run_chance": 0.44,
		"run_power": 0.78,
		"stamina": 1.60,
		"haul": 0.90,
		"weight": 2.2,
		"hour": ["dusk", "night"],
	},
	{
		"id": "pike",
		"name": "Northern Pike",
		"band": "channel",
		"min_depth": 4.0,
		"max_depth": 15.0,
		"weight_lo": 2.00,
		"weight_hi": 9.00,
		"value": 35,
		"take_window": 0.38,
		"teases": 2.8,
		"run_chance": 0.58,
		"run_power": 0.86,
		"stamina": 2.10,
		"haul": 0.70,
		"weight": 1.6,
	},
	{
		"id": "catfish",
		"name": "Channel Catfish",
		"band": "channel",
		"min_depth": 8.0,
		"max_depth": 15.0,
		"weight_lo": 2.00,
		"weight_hi": 8.00,
		"value": 22,
		"take_window": 0.62,
		"teases": 1.8,
		"run_chance": 0.40,
		"run_power": 0.76,
		"stamina": 2.30,
		"haul": 0.66,
		"weight": 1.8,
		"hour": ["dusk", "night"],
	},
	{
		"id": "drum",
		"name": "Freshwater Drum",
		"band": "channel",
		"min_depth": 8.0,
		"max_depth": 15.0,
		"weight_lo": 1.00,
		"weight_hi": 5.00,
		"value": 12,
		"take_window": 0.66,
		"teases": 1.9,
		"run_chance": 0.38,
		"run_power": 0.72,
		"stamina": 1.50,
		"haul": 0.92,
		"weight": 2.0,
	},

	# --- The Drowned Road, 15-40 m, 1968 back to 1931 -----------------------
	{
		"id": "bowfin",
		"name": "Bowfin",
		"band": "road",
		"min_depth": 15.0,
		"max_depth": 26.0,
		"weight_lo": 1.50,
		"weight_hi": 5.00,
		"value": 18,
		"take_window": 0.55,
		"teases": 1.6,
		"run_chance": 0.46,
		"run_power": 0.95,
		"stamina": 1.75,
		"haul": 0.84,
		"weight": 2.4,
	},
	{
		"id": "burbot",
		"name": "Burbot",
		"band": "road",
		"min_depth": 18.0,
		"max_depth": 36.0,
		"weight_lo": 1.00,
		"weight_hi": 5.00,
		"value": 28,
		"take_window": 0.60,
		"teases": 2.1,
		"run_chance": 0.36,
		"run_power": 0.88,
		"stamina": 1.80,
		"haul": 0.80,
		"weight": 2.0,
		"hour": ["night"],
	},
	{
		"id": "eel",
		"name": "American Eel",
		"band": "road",
		"min_depth": 20.0,
		"max_depth": 40.0,
		"weight_lo": 0.50,
		"weight_hi": 3.00,
		"value": 40,
		"take_window": 0.42,
		"teases": 3.0,
		"run_chance": 0.60,
		"run_power": 1.00,
		"stamina": 1.60,
		"haul": 0.74,
		"weight": 1.7,
	},
	{
		"id": "trout",
		"name": "Lake Trout",
		"band": "road",
		"min_depth": 22.0,
		"max_depth": 40.0,
		"weight_lo": 3.00,
		"weight_hi": 14.00,
		"value": 60,
		"take_window": 0.44,
		"teases": 2.5,
		"run_chance": 0.52,
		"run_power": 0.96,
		"stamina": 2.60,
		"haul": 0.64,
		"weight": 1.5,
	},
	{
		"id": "sturgeon",
		"name": "Lake Sturgeon",
		"band": "road",
		"min_depth": 30.0,
		"max_depth": 40.0,
		"weight_lo": 10.00,
		"weight_hi": 45.00,
		"value": 150,
		"take_window": 0.50,
		"teases": 2.2,
		"run_chance": 0.40,
		"run_power": 1.00,
		"stamina": 4.20,
		"haul": 0.44,
		"weight": 0.7,
	},

	# --- Old Town, 40-80 m, 1931 back to 1889 -------------------------------
	{
		"id": "chub",
		"name": "Silver Chub",
		"band": "town",
		"min_depth": 40.0,
		"max_depth": 55.0,
		"weight_lo": 0.08,
		"weight_hi": 0.14,
		"value": 2,
		"take_window": 0.80,
		"teases": 1.3,
		"run_chance": 0.34,
		"run_power": 1.22,
		"stamina": 0.70,
		"haul": 1.40,
		"weight": 3.0,
		"note": "They come up in twenties. All exactly the same length.",
	},
	{
		"id": "pale_walleye",
		"name": "Pale Walleye",
		"band": "town",
		"min_depth": 40.0,
		"max_depth": 65.0,
		"weight_lo": 2.00,
		"weight_hi": 6.00,
		"value": 45,
		"take_window": 0.46,
		"teases": 2.4,
		"run_chance": 0.48,
		"run_power": 1.30,
		"stamina": 1.90,
		"haul": 0.82,
		"weight": 2.0,
		"wrong": true,
		"note": "No pigment at all. The eyes still work.",
	},
	{
		"id": "thin_perch",
		"name": "Thin Perch",
		"band": "town",
		"min_depth": 45.0,
		"max_depth": 70.0,
		"weight_lo": 0.30,
		"weight_hi": 0.90,
		"value": 30,
		"take_window": 0.52,
		"teases": 2.6,
		"run_chance": 0.44,
		"run_power": 1.26,
		"stamina": 1.20,
		"haul": 1.00,
		"weight": 2.2,
		"wrong": true,
		"note": "Too long for the depth it came from.",
	},
	{
		"id": "gar",
		"name": "Longnose Gar",
		"band": "town",
		"min_depth": 50.0,
		"max_depth": 75.0,
		"weight_lo": 3.00,
		"weight_hi": 11.00,
		"value": 70,
		"take_window": 0.40,
		"teases": 3.0,
		"run_chance": 0.60,
		"run_power": 1.34,
		"stamina": 2.40,
		"haul": 0.62,
		"weight": 1.3,
		"wrong": true,
		"note": "Wrong latitude by nine hundred miles.",
	},
	{
		"id": "bell_carp",
		"name": "Bell Carp",
		"band": "town",
		"min_depth": 55.0,
		"max_depth": 80.0,
		"weight_lo": 8.00,
		"weight_hi": 20.00,
		"value": 90,
		"take_window": 0.56,
		"teases": 2.0,
		"run_chance": 0.38,
		"run_power": 1.26,
		"stamina": 3.40,
		"haul": 0.50,
		"weight": 1.0,
		"wrong": true,
		"note": "Only near the steeple. Deaf on one side.",
	},

	# --- The Quarry, 80-140 m, 1889 back to 1841 ----------------------------
	{
		"id": "lamprey",
		"name": "Sea Lamprey Mass",
		"band": "quarry",
		"min_depth": 80.0,
		"max_depth": 100.0,
		"weight_lo": 2.00,
		"weight_hi": 6.00,
		"value": 50,
		"take_window": 0.60,
		"teases": 1.5,
		"run_chance": 0.44,
		"run_power": 1.38,
		"stamina": 1.60,
		"haul": 0.90,
		"weight": 2.4,
		"note": "A knot of them, still attached to something.",
	},
	{
		"id": "blindfish",
		"name": "Blindfish",
		"band": "quarry",
		"min_depth": 85.0,
		"max_depth": 120.0,
		"weight_lo": 1.00,
		"weight_hi": 3.00,
		"value": 120,
		"take_window": 0.42,
		"teases": 2.6,
		"run_chance": 0.50,
		"run_power": 1.40,
		"stamina": 1.80,
		"haul": 0.78,
		"weight": 1.8,
		"wrong": true,
		"note": "No eyes. Not blind eyes - no sockets.",
	},
	{
		"id": "paddlefish",
		"name": "Paddlefish",
		"band": "quarry",
		"min_depth": 90.0,
		"max_depth": 130.0,
		"weight_lo": 15.00,
		"weight_hi": 40.00,
		"value": 200,
		"take_window": 0.44,
		"teases": 2.3,
		"run_chance": 0.42,
		"run_power": 1.32,
		"stamina": 4.60,
		"haul": 0.42,
		"weight": 1.0,
		"note": "A filter feeder. It should not be possible to hook one.",
	},
	{
		"id": "white_sturgeon",
		"name": "White Sturgeon",
		"band": "quarry",
		"min_depth": 100.0,
		"max_depth": 140.0,
		"weight_lo": 40.00,
		"weight_hi": 120.00,
		"value": 400,
		"take_window": 0.46,
		"teases": 2.4,
		"run_chance": 0.38,
		"run_power": 1.36,
		"stamina": 6.50,
		"haul": 0.30,
		"weight": 0.6,
	},

	# --- The Spring, 140 m +, no date ---------------------------------------
	{
		"id": "old_fish",
		"name": "The Old Fish",
		"band": "spring",
		"min_depth": 130.0,
		"max_depth": 152.0,
		"weight_lo": 25.00,
		"weight_hi": 60.00,
		"value": 0,
		"take_window": 0.55,
		"teases": 3.0,
		"run_chance": 0.26,
		"run_power": 1.48,
		"stamina": 5.50,
		"haul": 0.36,
		"weight": 1.0,
		"wrong": true,
		"note": "Lobe-finned. Extinct for sixty-six million years.",
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
static func at_depth(depth: float, hour: String = "") -> Array:
	var out := []
	for s in TABLE:
		if depth < s["min_depth"] or depth > s["max_depth"]:
			continue
		if hour != "" and s.has("hour") and not (hour in s["hour"]):
			continue
		out.append(s)
	return out


## Pick one, weighted, from a unit value in [0, 1).
##
## The caller supplies the value from SimRng rather than drawing here, so the
## table stays pure and the draw order is visible at the call site - which is
## what keeps the golden from shifting when this function changes.
##
## BAIT is the targeting system, and it multiplies the weights rather than
## filtering the list. A bait that hard-gates species is a lockout wearing a
## choice's clothes: the wrong bait should mean the wrong fish keep coming, not
## that nothing does.
static func pick(depth: float, unit: float, hour: String = "", bait: String = "worm") -> Dictionary:
	var rows := at_depth(depth, hour)
	if rows.is_empty():
		return {}
	var weights: Array[float] = []
	var total := 0.0
	for s in rows:
		var w: float = float(s["weight"]) * Gear.bait_weight(bait, s["id"], depth)
		weights.append(w)
		total += w
	if total <= 0.0:
		return {}
	var t := clampf(unit, 0.0, 0.999999) * total
	for i in rows.size():
		t -= weights[i]
		if t <= 0.0:
			return rows[i]
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
