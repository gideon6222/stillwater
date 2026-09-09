class_name Gear
extends RefCounted

## Everything you can buy, as data.
##
## Four ladders and a boat. The one that matters is LINE, because line length is
## the only thing that decides how deep you can fish and depth is time - so
## buying 40 lb braid is not "more power", it is reaching back another forty
## years. There is deliberately no second progression to balance against it.
##
## The rule the rods follow, and the reason they are not damage numbers: **a rod
## changes the player's TOLERANCE, never the fish's strength.** So a rod purchase
## is felt on every species at once, and the player only ever has to learn one
## gauge. A fish is hard because of what it DOES.

## Line. The index is the level; `depth` is how far down it will go, and the
## year beside it is what that depth means - see `world.gd`.
const LINE := [
	{"name": "6 lb mono", "depth": 4.0, "price": 0},
	{"name": "12 lb mono", "depth": 15.0, "price": 60},
	{"name": "20 lb braid", "depth": 40.0, "price": 220},
	{"name": "40 lb braid", "depth": 80.0, "price": 700},
	{"name": "80 lb wire", "depth": 140.0, "price": 2000},
	{"name": "the old line", "depth": 152.0, "price": -1},
]

## Rods. `forgive` widens the safe band on the tension gauge; `strength` is the
## heaviest fish that can be landed at all.
const ROD := [
	{"name": "Keeper's Cane", "forgive": 0.10, "strength": 3.0, "price": 0},
	{"name": "Fibreglass", "forgive": 0.13, "strength": 8.0, "price": 120},
	{"name": "Baitcaster", "forgive": 0.16, "strength": 20.0, "price": 450},
	{"name": "Jigging Rod", "forgive": 0.19, "strength": 50.0, "price": 900},
	{"name": "The Long Rod", "forgive": 0.24, "strength": 200.0, "price": -1},
]

## Reels. `haul` multiplies how fast line comes in, so a better reel shortens
## every fight - which matters most on the deep fish, where a fight is long
## enough to be a war of attrition.
const REEL := [
	{"name": "Closed-face", "haul": 1.00, "price": 0},
	{"name": "Spinning", "haul": 1.18, "price": 200},
	{"name": "Baitcast", "haul": 1.36, "price": 600},
	{"name": "Deepwater Winch", "haul": 1.60, "price": 1800},
]

## Boat. Each is a one-off toggle rather than a ladder, because they unlock
## different things rather than more of one thing.
const MOTOR_PRICE := 500
const SOUNDER_PRICE := 1200
const LAMP_PRICE := 400
const LIVEWELL_PRICE := 180

## Bait. `reusable` never runs out but bites less often, which is the economic
## decision the bait system exists to create.
const BAIT := [
	{
		"id": "worm",
		"name": "Worms",
		"price": 2,
		"per_pack": 10,
		"reusable": false,
		"bite": 1.00,
		"favours": ["bluegill", "perch", "shiner", "sucker", "drum"],
	},
	{
		"id": "corn",
		"name": "Sweetcorn",
		"price": 1,
		"per_pack": 10,
		"reusable": false,
		"bite": 0.90,
		"favours": ["carp", "sucker", "bell_carp"],
	},
	{
		"id": "minnow",
		"name": "Minnows",
		"price": 6,
		"per_pack": 10,
		"reusable": false,
		"bite": 1.05,
		"favours": ["bass", "smallmouth", "walleye", "pike", "gar", "pale_walleye"],
	},
	{
		"id": "cut",
		"name": "Cut bait",
		"price": 8,
		"per_pack": 5,
		"reusable": false,
		"bite": 1.00,
		"favours": ["catfish", "burbot", "sturgeon", "eel", "bowfin"],
	},
	{
		"id": "spoon",
		"name": "Spoon lure",
		"price": 35,
		"per_pack": 1,
		"reusable": true,
		"bite": 0.62,
		"favours": ["bass", "smallmouth", "pike", "trout"],
	},
	{
		"id": "glow",
		"name": "Glow jig",
		"price": 90,
		"per_pack": 1,
		"reusable": true,
		"bite": 0.80,
		"favours": ["chub", "pale_walleye", "thin_perch", "trout"],
		"min_depth": 30.0,
	},
	{
		"id": "offering",
		"name": "An offering",
		"price": -1,
		"per_pack": 1,
		"reusable": false,
		"bite": 1.00,
		"favours": ["lamprey", "blindfish", "white_sturgeon", "old_fish"],
		"min_depth": 80.0,
	},
]

## How much better a bait is on a fish it favours. High enough to be the reason
## you change bait, not so high that the wrong bait catches nothing - a bait
## system that hard-gates species is a lockout wearing a choice's clothes.
const FAVOUR_BONUS := 2.6


static func line_depth(level: int) -> float:
	return LINE[clampi(level, 0, LINE.size() - 1)]["depth"]


static func line_name(level: int) -> String:
	return LINE[clampi(level, 0, LINE.size() - 1)]["name"]


static func rod_forgive(level: int) -> float:
	return ROD[clampi(level, 0, ROD.size() - 1)]["forgive"]


static func rod_strength(level: int) -> float:
	return ROD[clampi(level, 0, ROD.size() - 1)]["strength"]


static func reel_haul(level: int) -> float:
	return REEL[clampi(level, 0, REEL.size() - 1)]["haul"]


static func bait_by_id(id: String) -> Dictionary:
	for b in BAIT:
		if b["id"] == id:
			return b
	return BAIT[0]


## How much more likely this bait makes this species. Neutral is 1.0, favoured is
## FAVOUR_BONUS, and a bait below its working depth is worthless.
## Below this, ORDINARY BAIT CATCHES NOTHING. Only an offering will do, and an
## offering is found rather than sold.
##
## This is the pillar the whole economy hangs off - "money cannot buy the
## bottom" - and until now it was written in three design documents and
## implemented nowhere. Worms worked perfectly well at a hundred and forty
## metres. A rule stated everywhere and enforced nowhere is worse than no rule:
## every other decision had been balanced around it.
const OFFERING_DEPTH := 80.0
const OFFERING := "offering"


static func bait_weight(bait_id: String, species_id: String, depth: float) -> float:
	var b := bait_by_id(bait_id)
	if b.has("min_depth") and depth < float(b["min_depth"]):
		return 0.0
	# The deep takes an offering or it takes nothing. It still gives up OBJECTS,
	# which is what stops this being a dead end - see the note in `sim._wait`.
	if depth >= OFFERING_DEPTH and bait_id != OFFERING:
		return 0.0
	var favours: Array = b["favours"]
	return FAVOUR_BONUS if species_id in favours else 1.0


## Is this bait any use at this depth at all? The shed and the boat both ask, so
## the player can be told BEFORE they spend an hour finding out.
static func bait_works_at(bait_id: String, depth: float) -> bool:
	var b := bait_by_id(bait_id)
	if b.has("min_depth") and depth < float(b["min_depth"]):
		return false
	return depth < OFFERING_DEPTH or bait_id == OFFERING


## The next thing worth buying, given what is owned. Used by the shed to order
## its shelves and by the tests to assert the ladder is affordable in order.
static func price_of(kind: String, level: int) -> int:
	match kind:
		"line":
			return LINE[clampi(level, 0, LINE.size() - 1)]["price"]
		"rod":
			return ROD[clampi(level, 0, ROD.size() - 1)]["price"]
		"reel":
			return REEL[clampi(level, 0, REEL.size() - 1)]["price"]
		_:
			return -1
