class_name Objects
extends RefCounted

## What comes up that is not a fish.
##
## **This is how the story is told.** There are no cutscenes and one speaking
## character, who is a radio. Everything else the player learns about Stillwater
## arrives on the end of a line, dated, from a depth - and because depth is time,
## the dates are the reveal. A licence plate from 1994 at fifteen metres and a
## road sign from 1931 at forty are the same sentence said twice.
##
## Three kinds, and the difference matters:
##
##   junk       sells for pocket money. Texture, and a reason the deep pays
##   story      cannot be sold. Goes in the logbook and carries a line of text
##   offering   cannot be sold either, and is the ONLY bait that works below 80 m
##
## **Money cannot buy the bottom.** The 80 lb wire is purchasable; the offering
## that has to be on the hook below eighty metres is not. So the deep is rationed
## by attention rather than by grinding, and a player who ignores the story caps
## out at forty metres with a full wallet. That is the "what happens if they
## ignore this?" test passing: the answer is not "they score less", it is "they
## cannot continue".

## WHAT A THING WEIGHS, in kilos, when it is in the boat with you.
##
## G1: "The livewell becomes a space you pack, where fish and objects compete for
## the same room." Junk used to convert to coins the instant it broke the surface
## - which meant the bottom of the lake was a slot machine and the boat was
## infinite. A boot is a boot: it sits in the well and it is in the way.
##
## Per KIND rather than per object, because the point is the CHOICE and not an
## inventory sim. A story piece is heavy enough to hurt and is the one thing you
## cannot sell; junk is light enough that taking it is usually right and
## occasionally not.
const WEIGHT := {
	"junk": 0.8,
	"story": 2.2,
	"offering": 0.4,
}


static func weight_of(kind: String) -> float:
	return float(WEIGHT.get(kind, 0.8))


const JUNK := "junk"
const STORY := "story"
const OFFERING := "offering"

const TABLE := [
	# --- The Reeds ----------------------------------------------------------
	{"id": "boot", "name": "A boot", "kind": JUNK, "min": 0.0, "max": 6.0, "value": 1,
		"note": "Left one. Size nine."},
	{"id": "bottle", "name": "A bottle", "kind": JUNK, "min": 0.0, "max": 6.0, "value": 1,
		"note": "Still capped. Nothing in it."},
	{"id": "sunglasses", "name": "Sunglasses", "kind": JUNK, "min": 0.0, "max": 6.0, "value": 3,
		"note": "One lens. Somebody had a bad afternoon."},
	{"id": "bike_wheel", "name": "A bicycle wheel", "kind": JUNK, "min": 1.0, "max": 8.0, "value": 4,
		"note": "No bicycle."},
	{"id": "phone", "name": "A phone", "kind": STORY, "min": 1.0, "max": 6.0, "value": 0,
		"note": "Dead, and then it charges. The photographs are of this lake.",
		"year": 2019},

	# --- The Channel --------------------------------------------------------
	{"id": "cans", "name": "Beer cans", "kind": JUNK, "min": 4.0, "max": 15.0, "value": 1,
		"note": "A whole evening of them, still in the ring."},
	{"id": "lawn_chair", "name": "A lawn chair", "kind": JUNK, "min": 4.0, "max": 15.0, "value": 5,
		"note": "Aluminium. Somebody sat out here."},
	{"id": "tackle_box", "name": "A tackle box", "kind": JUNK, "min": 5.0, "max": 15.0, "value": 12,
		"note": "Somebody else's, and there is bait in it."},
	{"id": "cassette", "name": "A cassette player", "kind": STORY, "min": 6.0, "max": 15.0, "value": 0,
		"note": "It plays. A man reading the weather, and then a long silence.",
		"year": 1994},
	{"id": "plate", "name": "A licence plate", "kind": STORY, "min": 8.0, "max": 15.0, "value": 0,
		"note": "1994. The county is one that does not exist.",
		"year": 1994},

	# --- The Drowned Road ---------------------------------------------------
	{"id": "hubcap", "name": "A hubcap", "kind": JUNK, "min": 15.0, "max": 40.0, "value": 6},
	{"id": "oil_can", "name": "An oil can", "kind": JUNK, "min": 15.0, "max": 40.0, "value": 5},
	{"id": "car_door", "name": "A car door", "kind": JUNK, "min": 18.0, "max": 40.0, "value": 20,
		"note": "The window still winds."},
	{"id": "road_sign", "name": "A road sign", "kind": STORY, "min": 20.0, "max": 40.0, "value": 0,
		"note": "STILLWATER 2. The chart in the cabin is a chart of a lake.",
		"year": 1958},
	{"id": "suitcase", "name": "A suitcase", "kind": STORY, "min": 25.0, "max": 40.0, "value": 0,
		"note": "Children's clothes, folded. Packed by somebody who expected to arrive.",
		"year": 1949},
	{"id": "watch", "name": "A wristwatch", "kind": OFFERING, "min": 28.0, "max": 40.0, "value": 0,
		"note": "Still running. It has been down there longer than it has hands for.",
		"year": 1946},

	# --- Old Town -----------------------------------------------------------
	{"id": "window", "name": "A window frame", "kind": JUNK, "min": 40.0, "max": 80.0, "value": 14,
		"note": "The glass is intact. That is the part that is wrong."},
	{"id": "kettle", "name": "A kettle", "kind": JUNK, "min": 40.0, "max": 80.0, "value": 8},
	{"id": "fence_post", "name": "A fence post", "kind": JUNK, "min": 40.0, "max": 80.0, "value": 6},
	{"id": "mailbox", "name": "A mailbox", "kind": STORY, "min": 45.0, "max": 80.0, "value": 0,
		"note": "The letters are readable. They are about the compensation, and the date everyone had to be out by.",
		"year": 1931},
	{"id": "school_desk", "name": "A school desk", "kind": STORY, "min": 50.0, "max": 80.0, "value": 0,
		"note": "A name cut into the lid. It is the name on the cabin's logbook.",
		"year": 1929},
	{"id": "bell", "name": "A piece of the church bell", "kind": OFFERING, "min": 55.0, "max": 80.0, "value": 0,
		"note": "Bronze, and the fracture is fresh.",
		"year": 1931},
	{"id": "doll", "name": "A doll", "kind": OFFERING, "min": 60.0, "max": 80.0, "value": 0,
		"note": "Nothing has been in the water eighty years and looked like this.",
		"year": 1927},

	# --- The Quarry ---------------------------------------------------------
	{"id": "tools", "name": "Quarry tools", "kind": JUNK, "min": 80.0, "max": 140.0, "value": 25},
	{"id": "sacking", "name": "Sacking", "kind": JUNK, "min": 80.0, "max": 140.0, "value": 4},
	{"id": "rope", "name": "A rope", "kind": STORY, "min": 85.0, "max": 140.0, "value": 0,
		"note": "You keep hauling. There is no other end to it.",
		"year": 1888},
	{"id": "ledger", "name": "A ledger", "kind": STORY, "min": 95.0, "max": 140.0, "value": 0,
		"note": "Wages, in five hands. The last column is keepers, and there are five of those too.",
		"year": 1871},
	{"id": "bones", "name": "Bones", "kind": STORY, "min": 100.0, "max": 140.0, "value": 0,
		"note": "Animal. Then, further down, not animal.",
		"year": 1858},
	{"id": "carved_stone", "name": "A carved stone", "kind": OFFERING, "min": 110.0, "max": 140.0, "value": 0,
		"note": "Older than the quarry that cut around it.",
		"year": 1841},
]

## How often a bite is an object rather than a fish, by depth.
##
## It CLIMBS with depth, and that is the design: the deep pays in story rather
## than in fish, so the thing pulling the player down is also the thing that
## explains why they are going. In the reeds it is an occasional boot; in the
## quarry more than a third of what comes up is a piece of the town.
static func chance_at(depth: float) -> float:
	if depth < 4.0:
		return 0.06
	if depth < 15.0:
		return 0.10
	if depth < 40.0:
		return 0.16
	if depth < 80.0:
		return 0.24
	return 0.34


static func at_depth(depth: float) -> Array:
	var out := []
	for o in TABLE:
		if depth >= o["min"] and depth <= o["max"]:
			out.append(o)
	return out


## Pick one, from a unit value. Story items and offerings are rarer than junk,
## because a discovery you can plan around is a resource rather than a surprise.
static func pick(depth: float, unit: float) -> Dictionary:
	var rows := at_depth(depth)
	if rows.is_empty():
		return {}
	var weights: Array[float] = []
	var total := 0.0
	for o in rows:
		var w := 1.0
		if o["kind"] == STORY:
			w = 0.45
		elif o["kind"] == OFFERING:
			w = 0.30
		weights.append(w)
		total += w
	var t := clampf(unit, 0.0, 0.999999) * total
	for i in rows.size():
		t -= weights[i]
		if t <= 0.0:
			return rows[i]
	return rows[rows.size() - 1]


static func by_id(id: String) -> Dictionary:
	for o in TABLE:
		if o["id"] == id:
			return o
	return {}


## Every offering in the game. Finite by construction, which is what stops money
## buying the bottom - see the note at the top.
static func offerings() -> Array:
	var out := []
	for o in TABLE:
		if o["kind"] == OFFERING:
			out.append(o)
	return out
