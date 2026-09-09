class_name Save
extends RefCounted

## The save, as pure arithmetic over a Dictionary.
##
## No FileAccess in here and no nodes: this turns a `Sim` into a plain dictionary
## and back, and the game writes that dictionary to disk somewhere else. The
## round trip is therefore testable headlessly, which is the entire reason a
## player's four-hour logbook is not resting on a function nobody ever ran twice.
##
## **The boat is saved. The cast is not.** Nothing about a fight, a nibble, a
## lure in the air or a fish on the line is written down. Close the game with a
## sturgeon on and you lose the sturgeon, which is both correct - you put the
## phone down mid-fight - and the reason this file is short. A save that captured
## a live fight would have to restore a state machine mid-transition, and every
## bug in it would be a bug that only appears to players who quit at exactly the
## wrong moment, which is to say a bug nobody can reproduce.
##
## **Anything missing falls back; nothing throws.** A save is data from a build
## that no longer exists, and the correct response to a field this version does
## not recognise, or a species id that has been renamed, is to carry on. A boot
## that hard-fails on an old save is the worst bug a game can ship: the player
## loses everything AND cannot get back in.

const VERSION := 1

## Fields written for the boat. Named here rather than reflected off the object,
## because reflection would silently start saving the next `var` somebody adds to
## `Econ` - including a transient one - and silently stop when it is renamed.
const ECON_INTS := ["money", "line", "rod", "reel", "livewell"]
const ECON_BOOLS := ["has_motor", "has_sounder", "has_lamp"]


static func to_dict(sim: Sim) -> Dictionary:
	var econ := sim.econ
	var out := {
		"version": VERSION,
		"day": sim.day,
		"hour": sim.hour,
		"weather": sim.weather,
		"spot": sim.spot,
		"bait": econ.bait,
		"bait_left": econ.bait_left.duplicate(),
		"lures": Array(econ.owned_lures),
		"logged": sim.logged.duplicate(),
		"found": sim.found.keys(),
		"caught": sim.caught,
		"lost": sim.lost_count,
		"casts": sim.casts,
		"total_weight": sim.total_weight,
		# The livewell IS saved - it is the boat, not the cast. Quitting on the
		# way back to the shed with a full box and finding it empty would read as
		# a lost session rather than as a rule.
		"held": econ.held.duplicate(true),
	}
	for k in ECON_INTS:
		out[k] = econ.get(k)
	for k in ECON_BOOLS:
		out[k] = econ.get(k)
	return out


## Load into a sim. Returns false only if the data is not a save at all - a
## partial or unrecognised one still loads as far as it goes.
static func apply(sim: Sim, data: Dictionary) -> bool:
	if not data.has("version"):
		return false

	var econ := sim.econ
	econ.money = maxi(0, _int(data, "money", 0))
	econ.line = clampi(_int(data, "line", 0), 0, Gear.LINE.size() - 1)
	econ.rod = clampi(_int(data, "rod", 0), 0, Gear.ROD.size() - 1)
	econ.reel = clampi(_int(data, "reel", 0), 0, Gear.REEL.size() - 1)
	econ.livewell = clampi(_int(data, "livewell", 0), 0, Econ.CAPACITY.size() - 1)
	econ.has_motor = _bool(data, "has_motor")
	econ.has_sounder = _bool(data, "has_sounder")
	econ.has_lamp = _bool(data, "has_lamp")

	# Every id out of a save is checked against the table it belongs to, because
	# a save is data from a build that no longer exists. A renamed species must
	# come back as a missing page, never as a crash on the shed's first draw.
	econ.bait_left = {}
	var left: Dictionary = data.get("bait_left", {})
	for id in left:
		if not Gear.bait_by_id(str(id))["id"] == str(id):
			continue
		econ.bait_left[str(id)] = maxi(0, int(left[id]))
	econ.owned_lures = []
	for id in _array(data, "lures"):
		var b := Gear.bait_by_id(str(id))
		if b["id"] == str(id) and bool(b["reusable"]):
			econ.owned_lures.append(str(id))
	var bait := str(data.get("bait", "worm"))
	econ.bait = bait if econ.has_bait(bait) else "worm"

	econ.held = []
	for f in _array(data, "held"):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = f
		var id := str(row.get("id", ""))
		if Species.by_id(id).is_empty():
			continue
		# Through `keep`, so a save cannot put more in the box than the box holds
		# - including a save written by a build whose livewell was bigger.
		econ.keep(id, float(row.get("weight", 0.0)), bool(row.get("wrong", false)))

	sim.logged = {}
	var logged: Dictionary = data.get("logged", {})
	for id in logged:
		if not Species.by_id(str(id)).is_empty():
			sim.logged[str(id)] = float(logged[id])
	sim.found = {}
	for id in _array(data, "found"):
		if not Objects.by_id(str(id)).is_empty():
			sim.found[str(id)] = true

	sim.day = maxi(1, _int(data, "day", 1))
	var hour := str(data.get("hour", "dawn"))
	sim.hour = hour if hour in World.HOURS else "dawn"
	var weather := str(data.get("weather", "clear"))
	sim.weather = weather if World.weather_bite(weather) > 0.0 else "clear"

	# The spot has to be somewhere the loaded GEAR can actually fish, not just
	# somewhere that exists. A save written before a line was sold back - or by a
	# build whose lake was laid out differently - must not drop the player onto
	# water they cannot fish and cannot leave.
	var spot := str(data.get("spot", "reed_bay"))
	if World.spot_by_id(spot)["id"] != spot or not World.line_reaches_water(spot, econ.line):
		spot = "reed_bay"
	if bool(World.spot_by_id(spot)["needs_motor"]) and not econ.has_motor:
		spot = "reed_bay"
	sim.spot = spot

	sim.caught = maxi(0, _int(data, "caught", 0))
	sim.lost_count = maxi(0, _int(data, "lost", 0))
	sim.casts = maxi(0, _int(data, "casts", 0))
	sim.total_weight = maxf(0.0, float(data.get("total_weight", 0.0)))
	return true


static func _int(d: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return int(v)
	return fallback


static func _bool(d: Dictionary, key: String) -> bool:
	return bool(d.get(key, false))


static func _array(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []
