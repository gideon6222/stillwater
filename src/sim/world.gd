class_name World
extends RefCounted

## The lake: where you can go, how deep it is there, and what year that is.
##
## **DEPTH IS TIME.** The lake does not go down, it goes back. Every metre of
## line reaches further into what the valley used to be - four metres is this
## year's weed, forty is a road tarred in 1931 and still there, eighty is
## rooftops. The fish age the way the objects do because they are the fish that
## lived here *then*.
##
## The game never says this. `depth_to_year` is never printed as a caption; the
## sounder shows a DEPTH, the objects that come up carry dates, and the player
## does the arithmetic themselves somewhere in the third hour. That is the moment
## the logbook they have already filled in changes meaning.
##
## The consequence for the code, and the reason this file is small: **the line
## upgrade IS the story progression.** There is no second ladder to balance
## against the first. Anything that adds one is working against the whole design.

## Anchors the year curve interpolates between. Not a formula, because a formula
## would be tuned by feel and then be wrong at one end; these are the dates the
## objects in `objects.gd` are dated to, so the two cannot drift apart.
const YEAR_ANCHORS := [
	[0.0, 2026.0],
	[4.0, 2011.0],
	[15.0, 1968.0],
	[40.0, 1931.0],
	[80.0, 1889.0],
	[140.0, 1841.0],
]

## The six bands, shallowest first. `max_depth` is the bed at the deepest spot
## that reaches this band; `line` is the line strength needed to fish it.
const BANDS := [
	{
		"id": "reeds",
		"name": "The Reeds",
		"min_depth": 0.0,
		"max_depth": 4.0,
		"line": 0,
	},
	{
		"id": "channel",
		"name": "The Channel",
		"min_depth": 4.0,
		"max_depth": 15.0,
		"line": 1,
	},
	{
		"id": "road",
		"name": "The Drowned Road",
		"min_depth": 15.0,
		"max_depth": 40.0,
		"line": 2,
	},
	{
		"id": "town",
		"name": "Old Town",
		"min_depth": 40.0,
		"max_depth": 80.0,
		"line": 3,
	},
	{
		"id": "quarry",
		"name": "The Quarry",
		"min_depth": 80.0,
		"max_depth": 140.0,
		"line": 4,
	},
	{
		"id": "spring",
		"name": "The Spring",
		"min_depth": 140.0,
		"max_depth": 152.0,
		"line": 5,
	},
]

## Where the boat can go. `bed` is how deep the water is there, which with the
## line you own is what decides how far back you can reach.
##
## `needs_motor` is the second axis - travelling ACROSS the lake - and it is
## deliberately cheap and short. The interesting progression is downward.
const SPOTS := [
	{
		"id": "reed_bay",
		"name": "Reed Bay",
		"shallow": 0.8,
		"bed": 4.0,
		"needs_motor": false,
		"needs_band": 0,
	},
	{
		"id": "narrows",
		"name": "The Narrows",
		"shallow": 3.5,
		"bed": 15.0,
		"needs_motor": true,
		"needs_band": 1,
	},
	{
		"id": "road",
		"name": "The Drowned Road",
		"shallow": 14.0,
		"bed": 40.0,
		"needs_motor": true,
		"needs_band": 2,
	},
	{
		"id": "steeple",
		"name": "The Steeple",
		"shallow": 38.0,
		"bed": 80.0,
		"needs_motor": true,
		"needs_band": 3,
	},
	{
		"id": "quarry",
		"name": "The Quarry Wall",
		"shallow": 78.0,
		"bed": 140.0,
		"needs_motor": true,
		"needs_band": 4,
	},
	{
		"id": "spring",
		"name": "The Spring",
		"shallow": 138.0,
		"bed": 152.0,
		"needs_motor": true,
		"needs_band": 5,
	},
]

## Parts of the day, in order. Sleeping advances one step.
const HOURS := ["dawn", "morning", "afternoon", "dusk", "night"]

## Weathers, and how often each comes up. Fog is the workhorse: it costs almost
## nothing to render, removes the draw distance that would otherwise need
## managing, and is the most efficient way in the game to make a friendly lake
## stop being friendly.
const WEATHERS := [
	{"id": "clear", "weight": 4.0, "bite": 1.00},
	{"id": "overcast", "weight": 3.0, "bite": 1.15},
	{"id": "fog", "weight": 2.0, "bite": 1.05},
	{"id": "rain", "weight": 2.0, "bite": 1.25},
	{"id": "storm", "weight": 1.0, "bite": 0.80},
]


## The year at a given depth, interpolated between the anchors.
##
## Returns 0 past the last anchor - the Spring has no date, which is the point of
## it. Callers show that as "—" rather than a number.
static func depth_to_year(depth: float) -> int:
	var d := maxf(0.0, depth)
	for i in YEAR_ANCHORS.size() - 1:
		var a: Array = YEAR_ANCHORS[i]
		var b: Array = YEAR_ANCHORS[i + 1]
		# Everything read out of these nested arrays is a Variant, so every local
		# has to be annotated - `:=` cannot infer from one, and the parse error
		# names the variable rather than the lookup that caused it.
		var ad: float = a[0]
		var bd: float = b[0]
		var ay: float = a[1]
		var by: float = b[1]
		if d >= ad and d <= bd:
			var span := maxf(0.001, bd - ad)
			var t := (d - ad) / span
			return int(round(ay + (by - ay) * t))
	return 0


## The band a depth falls in. Always returns one - the deepest band clamps -
## because "no band" is not a state anything downstream can do anything with.
static func band_at(depth: float) -> Dictionary:
	for b in BANDS:
		if depth >= b["min_depth"] and depth < b["max_depth"]:
			return b
	return BANDS[BANDS.size() - 1]


static func band_index(depth: float) -> int:
	for i in BANDS.size():
		var b: Dictionary = BANDS[i]
		if depth >= b["min_depth"] and depth < b["max_depth"]:
			return i
	return BANDS.size() - 1


static func spot_by_id(id: String) -> Dictionary:
	for s in SPOTS:
		if s["id"] == id:
			return s
	return SPOTS[0]


static func spot_index(id: String) -> int:
	for i in SPOTS.size():
		if SPOTS[i]["id"] == id:
			return i
	return 0


## How deep the lure lands: **the cast decides where in the spot you fish.**
##
## Every spot shelves - shallow near the boat, deep further out - so a short cast
## drops into the near water and a full one reaches the bottom. That makes the
## cast charge a DEPTH selector, and because depth is time it is a *year*
## selector: the same bar that decides how far the lure flies decides how far
## back it lands. The player is not told that either.
##
## It also fixes something real. When the lure only ever went to the bed there
## were exactly six depths in the whole game, and a third of the species sat
## between them - in the table, in the logbook as blank pages, and uncatchable
## anywhere. A test now walks every spot at every line level and every charge,
## which is the true set of depths the game can produce.
##
## The line still caps it, and that cap is still the progression.
static func depth_for_cast(spot_id: String, line_level: int, charge: float) -> float:
	var spot := spot_by_id(spot_id)
	var shallow: float = spot["shallow"]
	var bed: float = spot["bed"]
	var want := lerpf(shallow, bed, clampf(charge, 0.0, 1.0))
	# **Never shallower than the spot's own shallowest water.** The line caps how
	# deep the lure goes, and capping alone produced nonsense at the far end: six
	# pound mono at The Spring returned four metres, in water a hundred and fifty
	# deep, and `Species.at_depth(4.0)` duly offered bluegill. A lure hanging in
	# open water over the quarry is not fishing the reeds.
	#
	# The clamp keeps the number honest; `line_reaches_water` is what stops the
	# player being there at all.
	return maxf(shallow, minf(want, Gear.line_depth(line_level)))


## Can this line fish this spot AT ALL - not "reach the bottom", reach the
## shallowest water there is. Below this there is no window to fish and the map
## has to say so, because the alternative is a boat that travels somewhere and
## then silently catches nothing.
static func line_reaches_water(spot_id: String, line_level: int) -> bool:
	return Gear.line_depth(line_level) >= float(spot_by_id(spot_id)["shallow"])


## The band of water actually fishable here, as [top, bottom]. Empty when the
## line does not reach it. This is what the map draws.
static func fishable_window(spot_id: String, line_level: int) -> Array[float]:
	if not line_reaches_water(spot_id, line_level):
		return []
	var spot := spot_by_id(spot_id)
	return [float(spot["shallow"]), reachable_depth(spot_id, line_level)]


## The deepest this spot goes with this line - what the map shows, and what the
## progression is measured in.
static func reachable_depth(spot_id: String, line_level: int) -> float:
	return depth_for_cast(spot_id, line_level, 1.0)


## Every depth the game can actually produce. Used by the tests to assert that
## nothing in any content table is stranded between two reachable values.
static func all_reachable_depths(steps: int = 24) -> Array[float]:
	var out: Array[float] = []
	for spot in SPOTS:
		for level in Gear.LINE.size():
			for i in steps + 1:
				out.append(depth_for_cast(spot["id"], level, float(i) / float(steps)))
	return out


## Weighted weather pick from a unit value. The caller supplies the draw.
static func pick_weather(unit: float) -> String:
	var total := 0.0
	for w in WEATHERS:
		total += w["weight"]
	var t := clampf(unit, 0.0, 0.999999) * total
	for w in WEATHERS:
		t -= w["weight"]
		if t <= 0.0:
			return w["id"]
	return "clear"


static func weather_bite(id: String) -> float:
	for w in WEATHERS:
		if w["id"] == id:
			return w["bite"]
	return 1.0


static func next_hour(hour: String) -> String:
	var i := HOURS.find(hour)
	if i < 0:
		return HOURS[0]
	return HOURS[(i + 1) % HOURS.size()]


static func is_night(hour: String) -> bool:
	return hour == "night" or hour == "dusk"


## WHAT THE SOUNDER DRAWS, and it is the best storytelling instrument in the game.
##
## Each spot has a bottom silhouette: a list of `[across, height]` points, where
## `across` runs 0 to 1 left to right and `height` is metres ABOVE the bed. The
## renderer scales it into the trace.
##
## The reason this is content and not noise: **the player reads the bottom before
## they can reach it.** Buy the sounder at Old Town and the trace shows rooftops
## and one tall spike forty metres below anything your line will touch. Nobody
## says what it is. The dates on what comes up say it later, and the shape was
## on screen for hours first.
##
## It is also why the sounder is the most expensive thing in the shed and buys no
## fishing advantage whatsoever. It buys knowing.
const BOTTOMS := {
	"reed_bay": [[0.0, 0.0], [0.18, 0.5], [0.3, 0.2], [0.52, 0.7], [0.66, 0.3], [0.85, 0.6], [1.0, 0.1]],
	"narrows": [[0.0, 1.4], [0.2, 0.4], [0.42, 0.1], [0.6, 0.2], [0.78, 0.9], [1.0, 2.1]],
	# The road. Flat, level, and unmistakably not natural - a straight line across
	# a lake bed is the whole reveal, and it arrives without a word.
	"road": [[0.0, 0.3], [0.22, 0.5], [0.30, 1.6], [0.34, 1.7], [0.70, 1.7], [0.74, 1.6],
		[0.82, 0.5], [1.0, 0.4]],
	# Old Town: rooftops, and the steeple.
	"steeple": [[0.0, 0.2], [0.10, 0.2], [0.12, 2.4], [0.20, 2.4], [0.22, 0.3],
		[0.30, 0.3], [0.32, 3.1], [0.40, 3.1], [0.42, 0.2],
		[0.52, 0.2], [0.545, 11.0], [0.57, 0.2],
		[0.66, 0.2], [0.68, 2.8], [0.78, 2.8], [0.80, 0.3], [1.0, 0.2]],
	"quarry": [[0.0, 9.0], [0.08, 8.6], [0.12, 3.0], [0.2, 2.8], [0.26, 0.4],
		[0.62, 0.2], [0.70, 3.4], [0.76, 3.2], [0.82, 8.2], [0.9, 8.8], [1.0, 9.4]],
	# The Spring. The bed does not come back. Whatever the sounder is bouncing off
	# down there is not the bottom, and it is not in the same place twice.
	"spring": [[0.0, 0.0], [1.0, 0.0]],
}


static func bottom_of(spot_id: String) -> Array:
	return BOTTOMS.get(spot_id, BOTTOMS["reed_bay"])
