class_name Econ
extends RefCounted

## Money, what you own, and what is in the livewell.
##
## Pure state plus the arithmetic over it. No nodes, no signals - the shed reads
## this and draws shelves from it, and the two cannot disagree because there is
## only one of them.
##
## **A weight cap is what turns "which of these is worth more" into a decision.**
## Without one the livewell is a shopping list; with one, every fish you keep is
## one you are choosing over another, and the carp that pays 14 is competing with
## the two perch it displaces.

var money: int = 0

# --- gear, as indices into the ladders in gear.gd -------------------------
var line: int = 0
var rod: int = 0
var reel: int = 0
var livewell: int = 0        ## 0 = the bucket, each level adds capacity
var has_motor: bool = false
var has_sounder: bool = false
var has_lamp: bool = false

# --- bait ----------------------------------------------------------------
var bait: String = "worm"
var bait_left: Dictionary = {"worm": 10}   ## id -> count; reusable baits are not in here
var owned_lures: Array[String] = []

# --- the livewell ---------------------------------------------------------
## Each entry is {id, weight, wrong}. Kept flat so the golden can assert it.
var held: Array[Dictionary] = []

## What the livewell holds, in kilos, before it is full. The bucket is small on
## purpose: the first upgrade a player wants is usually somewhere to put things.
const CAPACITY := [6.0, 16.0, 34.0]
const CAPACITY_PRICE := [0, 180, 520]


func reset() -> void:
	money = 0
	line = 0
	rod = 0
	reel = 0
	livewell = 0
	has_motor = false
	has_sounder = false
	has_lamp = false
	bait = "worm"
	bait_left = {"worm": 10}
	owned_lures = []
	held = []


func capacity() -> float:
	return CAPACITY[clampi(livewell, 0, CAPACITY.size() - 1)]


func load_kg() -> float:
	var total := 0.0
	for f in held:
		total += float(f["weight"])
	return total


func space_left() -> float:
	return maxf(0.0, capacity() - load_kg())


## Can this fish go in the box at all?
##
## A fish heavier than the whole livewell can never be kept, which is a real and
## legible wall rather than a bug - the answer is a bigger box, and the shed says
## so. Anything that would merely overflow is refused too, so the cap is a cap.
func can_keep(weight: float) -> bool:
	return weight <= capacity() and weight <= space_left() + 0.0001


## G1: AN OBJECT IN THE WELL, competing with the fish for the same room.
##
## Stored in the same list, because the whole point is that they are the same
## room - two lists would be two capacities and the decision would evaporate. The
## `object` flag is what the shed reads to pay for it: junk is sold by the piece
## at a fixed price, not by the kilo like a fish.
func keep_object(id: String, weight: float, value: int) -> bool:
	if not can_keep(weight):
		return false
	held.append({
		"id": id, "weight": snappedf(weight, 0.001), "wrong": false,
		"object": true, "value": value,
	})
	return true


func keep(id: String, weight: float, wrong: bool) -> bool:
	if not can_keep(weight):
		return false
	held.append({"id": id, "weight": snappedf(weight, 0.001), "wrong": wrong})
	return true


## What one fish is worth. Value is per fish, plus a bonus for size that is
## generous enough to make a big one exciting and shallow enough that ten small
## ones still beat one big one - the loop has to pay while you are learning.
##
## A WRONG fish is worth more, and that is the story's economy: the deeper you
## go the stranger and the more valuable, so the thing pulling you down is also
## the thing paying for the line that gets you there.
static func value_of(id: String, weight: float, wrong: bool) -> int:
	var s := Species.by_id(id)
	if s.is_empty():
		return 0
	var base: float = float(s["value"])
	var lo: float = s["weight_lo"]
	var hi: float = maxf(lo + 0.001, float(s["weight_hi"]))
	var size := clampf((weight - lo) / (hi - lo), 0.0, 1.0)
	var out := base * (0.75 + 0.65 * size)
	if wrong:
		out *= 1.5
	return int(round(out))


## Sell everything and empty the box. Returns what it paid, so the shed can say
## it out loud rather than the player watching a number change.
func sell_all() -> int:
	var total := 0
	for f in held:
		# G1: JUNK IS SOLD BY THE PIECE, a fish by the kilo. `value_of` reads the
		# species table, and a boot is not in it - without this branch every
		# object in the well weighed in as an unknown species worth nothing, which
		# is a silent zero rather than the four coins a bicycle wheel is worth.
		if bool(f.get("object", false)):
			total += int(f.get("value", 0))
		else:
			total += value_of(f["id"], f["weight"], f["wrong"])
	money += total
	held = []
	return total


# --- buying ---------------------------------------------------------------

func can_afford(price: int) -> bool:
	return price >= 0 and money >= price


## Buy the next rung of a ladder. Returns false and changes nothing if it cannot
## be afforded or there is no next rung - a shop that half-completes a purchase
## is the worst bug this file can have.
func buy_next(kind: String) -> bool:
	match kind:
		"line":
			return _buy_rung(Gear.LINE, func(): return line, func(v): line = v)
		"rod":
			return _buy_rung(Gear.ROD, func(): return rod, func(v): rod = v)
		"reel":
			return _buy_rung(Gear.REEL, func(): return reel, func(v): reel = v)
		"livewell":
			var next := livewell + 1
			if next >= CAPACITY.size():
				return false
			var price: int = CAPACITY_PRICE[next]
			if not can_afford(price):
				return false
			money -= price
			livewell = next
			return true
		_:
			return false


func _buy_rung(ladder: Array, getter: Callable, setter: Callable) -> bool:
	var cur: int = getter.call()
	var next := cur + 1
	if next >= ladder.size():
		return false
	var price: int = ladder[next]["price"]
	# A price of -1 means it is not for sale at any amount - the Long Rod and the
	# old line are FOUND. Money cannot buy the bottom of the lake.
	if price < 0 or not can_afford(price):
		return false
	money -= price
	setter.call(next)
	return true


func buy_boat(kind: String) -> bool:
	match kind:
		"motor":
			if has_motor or not can_afford(Gear.MOTOR_PRICE):
				return false
			money -= Gear.MOTOR_PRICE
			has_motor = true
			return true
		"sounder":
			if has_sounder or not can_afford(Gear.SOUNDER_PRICE):
				return false
			money -= Gear.SOUNDER_PRICE
			has_sounder = true
			return true
		"lamp":
			if has_lamp or not can_afford(Gear.LAMP_PRICE):
				return false
			money -= Gear.LAMP_PRICE
			has_lamp = true
			return true
		_:
			return false


func buy_bait(id: String) -> bool:
	var b := Gear.bait_by_id(id)
	var price: int = b["price"]
	if price < 0 or not can_afford(price):
		return false
	money -= price
	if b["reusable"]:
		if not (id in owned_lures):
			owned_lures.append(id)
	else:
		bait_left[id] = int(bait_left.get(id, 0)) + int(b["per_pack"])
	return true


## Is there any of this bait to fish with? A reusable lure never runs out, which
## is the whole trade it offers against a lower bite rate.
func has_bait(id: String) -> bool:
	var b := Gear.bait_by_id(id)
	if b["reusable"]:
		return id in owned_lures
	return int(bait_left.get(id, 0)) > 0


## Spend one. Reusable lures are not consumed, and running out silently falls
## back to worms rather than to nothing - a player with an empty box should be
## fishing badly, not stuck.
func spend_bait() -> void:
	var b := Gear.bait_by_id(bait)
	if b["reusable"]:
		return
	var left := int(bait_left.get(bait, 0)) - 1
	bait_left[bait] = maxi(0, left)
	if left <= 0 and not has_bait(bait):
		bait = "worm" if has_bait("worm") else bait


func snapshot() -> Dictionary:
	return {
		"money": money,
		"line": line,
		"rod": rod,
		"reel": reel,
		"livewell": livewell,
		"motor": has_motor,
		"sounder": has_sounder,
		"lamp": has_lamp,
		"bait": bait,
		"held": held.size(),
		"held_kg": snappedf(load_kg(), 0.001),
	}
