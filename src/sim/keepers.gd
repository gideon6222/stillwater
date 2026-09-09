class_name Keepers
extends RefCounted

## THE FIVE HANDS.
##
## The logbook in the cabin is not yours. Four people kept this water before you
## and all four wrote in the same book, and the entries unlock by **the deepest
## you have ever cast** - which is to say, by how far back you have looked.
##
## That is the whole reason this file exists rather than a quest flag: depth is
## time, and the story is already keyed to depth. The player does not complete
## objectives to earn story. They go deeper, and deeper is older, and the older
## hands are the ones further down the book.
##
## **The order they are read in is the reverse of the order they were written.**
## Ruth is four metres down and 1994; Samuel is a hundred and forty and 1871.
## So the player meets the most recent keeper first and works backwards toward
## the one who was here before the water was, which is the same shape as every
## other arc in this game.
##
## Nothing here is ever explained. The entries do not build to a revelation
## delivered in a paragraph; they simply stop being about fish.

## `hand` is which keeper. `at` is the depth that unlocks it. `text` is the
## entry, and `year` is what they dated it - which the player can compare with
## the dates on what they are pulling up.
const ENTRIES := [
	# --- Ruth Alder, the keeper before you ---------------------------------
	{"hand": "Ruth Alder", "year": 1994, "at": 1.0,
		"text": "Bream in the reeds again. Nine of them before the sun was properly up. "
			+ "Good water, this. Easy water."},
	{"hand": "Ruth Alder", "year": 1994, "at": 3.5,
		"text": "The book was here when I came. Three hands in it already and none of "
			+ "them finished. I have started on the fourth page from the back and I do "
			+ "not intend to think about that."},
	{"hand": "Ruth Alder", "year": 1995, "at": 9.0,
		"text": "Asked in the village which year the valley went under. Got 1931 from "
			+ "one and 1949 from another and a long look from the third. It is not the "
			+ "sort of thing a place forgets."},
	{"hand": "Ruth Alder", "year": 1996, "at": 14.0,
		"text": "I am not writing down what came up today. If somebody reads this after "
			+ "me: do not fish past the second shelf. That is all I will put."},

	# --- Peter Vance -------------------------------------------------------
	{"hand": "Peter Vance", "year": 1958, "at": 17.0,
		"text": "Cold morning, flat water. Took the boat out over what the map calls the "
			+ "old road. You can see it from above on a still day. It goes down and it "
			+ "does not come back up anywhere."},
	{"hand": "Peter Vance", "year": 1959, "at": 26.0,
		"text": "Hooked a suitcase. Children's clothes in it, folded. Folded. I have put "
			+ "it back in the water, which I know was wrong, and I would do it again."},
	{"hand": "Peter Vance", "year": 1961, "at": 36.0,
		"text": "The council say the reservoir is eighty feet at the deepest. I have four "
			+ "hundred feet of line on the reel and I have not found the bottom of the "
			+ "quarry end. I have stopped telling them."},

	# --- Edith Moss, who was here when it filled ---------------------------
	{"hand": "Edith Moss", "year": 1931, "at": 42.0,
		"text": "They gave us until the fourteenth. Most went in the first week. I have "
			+ "taken the keeper's cottage above the waterline because somebody has to "
			+ "watch it and because I could not go far."},
	{"hand": "Edith Moss", "year": 1933, "at": 55.0,
		"text": "Rowed over the town today. Clear enough to see the steeple. It is a "
			+ "strange thing to be above your own street. I put my hand in the water and "
			+ "could not say why."},
	{"hand": "Edith Moss", "year": 1938, "at": 68.0,
		"text": "The fish here are wrong now and I will not pretend otherwise. Too long "
			+ "in the body. Eyes with nothing behind them. I keep the good ones and I "
			+ "put the others back and I do not look at them while I do it."},
	{"hand": "Edith Moss", "year": 1949, "at": 78.0,
		"text": "Eighteen years and the water has never once gone down. Not in the "
			+ "drought. Not in the drought, and I want that written somewhere."},

	# --- Samuel Crake, before the water ------------------------------------
	{"hand": "Samuel Crake", "year": 1871, "at": 86.0,
		"text": "Wages, and the count of men. Quarry pays well and the stone is good. "
			+ "There is a spring at the bottom of the cut that they will not work near "
			+ "and I have stopped asking why."},
	{"hand": "Samuel Crake", "year": 1878, "at": 104.0,
		"text": "We have gone below the old workings. Below them. There are tools down "
			+ "there and none of them are ours, and the stone around them was cut by "
			+ "somebody who did not have iron."},
	{"hand": "Samuel Crake", "year": 1888, "at": 122.0,
		"text": "The spring does not run out. Men have gone down to cap it four times "
			+ "and it is not that they failed. It is that they came back up and could "
			+ "not tell me what they had done."},
	{"hand": "Samuel Crake", "year": 1889, "at": 138.0,
		"text": "I am the fifth keeper of this book and I have found the four before me "
			+ "and none of them are in the ground. I will leave it in the cottage. "
			+ "Somebody will keep this water. Somebody always has."},
]

## What the player's own hand is called in the book.
const YOURS := "Your hand"


## Everything unlocked at a given depth, in book order.
static func unlocked(deepest: float) -> Array:
	var out := []
	for e in ENTRIES:
		if deepest >= float(e["at"]) - 0.001:
			out.append(e)
	return out


## The keepers, in the order the book has them - which is the order the player
## meets them, most recent first.
static func hands() -> Array[String]:
	var out: Array[String] = []
	for e in ENTRIES:
		var h: String = e["hand"]
		if not (h in out):
			out.append(h)
	return out


## How many of the five the player has met. The fifth is always themselves, and
## it counts from the first entry they unlock - the book is theirs the moment
## they write in it.
static func hands_met(deepest: float) -> int:
	var seen: Array[String] = []
	for e in unlocked(deepest):
		var h: String = e["hand"]
		if not (h in seen):
			seen.append(h)
	return seen.size() + 1


static func total_hands() -> int:
	return hands().size() + 1
