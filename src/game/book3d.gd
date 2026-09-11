class_name Book3D
extends RefCounted

## THE LOGBOOK, AS AN OBJECT.
##
## A notebook lying on the thwart. Look at it, press Use, and the camera comes
## down over it while the cover opens; the entries are printed on the page and
## you turn them one at a time.
##
## **The page is paginated, not scrolled.** That is the whole difference between
## a menu and a book, and it is not decoration: a book tells you how much there
## is by how thick it is and where you are by which page you are on. A scroll
## bar tells you neither. It also means the keeper's entries arrive a spread at
## a time, in the order they were written, which is how anybody actually reads a
## journal they have found.

## How much fits on one page before it turns. Measured in entries rather than in
## pixels, because an entry is the unit the book is written in.
## Two, not three. Three entries laid out to 695 px on a 566 px page, so the
## last one ran off the bottom - and a page you cannot finish reading is worse
## than one more page turn.
const PER_PAGE := 2

var page := 0
var pages := 1


## Lay out one spread into `into`, and report how many pages there are.
##
## Everything here is ordinary Control work - the same paper skin, the same ink -
## because it is rendered into a SubViewport and used as the texture ON the page.
## The layout is not thrown away to make the object real; it becomes its surface.
static func fill(into: VBoxContainer, sim: Sim, page_index: int,
		ink: Color, ink_dim: Color, rule: Color) -> int:
	for c in into.get_children():
		into.remove_child(c)
		c.queue_free()

	var entries := Keepers.unlocked(sim.deepest_ever)
	# The species records are the FIFTH hand, so they are the last pages of the
	# book rather than a separate list underneath it.
	# EVERY SPECIES, not only the ones caught. An unlogged row is a BLANK line on
	# a real page rather than a page that does not exist.
	#
	# Gideon: "I want it to be full of pages that I can flip through even if theh
	# are blank." He is right, and it is more on-theme than what was here: this is
	# a book the player is filling in, so the gaps are the content. A logbook that
	# only has pages for what you already caught cannot show you what you have not.
	var records := []
	for row in Species.TABLE:
		records.append(row)

	var sheets: Array = []
	var i := 0
	while i < entries.size():
		sheets.append({"kind": "hand", "items": entries.slice(i, i + PER_PAGE)})
		i += PER_PAGE
	if records.size() > 0:
		var j := 0
		while j < records.size():
			sheets.append({"kind": "catch", "items": records.slice(j, j + 6)})
			j += 6
	if sheets.is_empty():
		sheets.append({"kind": "empty", "items": []})

	var n := sheets.size()
	var here: Dictionary = sheets[clampi(page_index, 0, n - 1)]

	match str(here["kind"]):
		"empty":
			_head(into, "The keeper's book", ink_dim, rule)
			_body(into, "The pages before yours are still shut. They open as you "
				+ "fish deeper.", ink_dim)
		"hand":
			var hand := ""
			for e in here["items"]:
				var who: String = e["hand"]
				if who != hand:
					hand = who
					_head(into, "%s, %d" % [who, int(e["year"])], ink_dim, rule)
				# The older the hand, the further it has faded into the paper.
				var age := clampf((float(e["at"]) - 1.0) / 140.0, 0.0, 1.0)
				_body(into, str(e["text"]), ink.lerp(ink_dim, age * 0.8))
		"catch":
			_head(into, "What you have had out", ink_dim, rule)
			for row in here["items"]:
				var id := str(row["id"])
				if not sim.logged.has(id):
					# A RULED LINE WITH NOTHING ON IT. Not the species name greyed
					# out - that would tell the player what is down there, and the
					# whole game is built on not telling them. An empty line says
					# "there is something here you have not had" and no more.
					_body(into, "   .  .  .", ink_dim.lerp(rule, 0.45))
					continue
				var best: float = sim.logged[id]
				var line := "%s   -   %.2f kg" % [str(row["name"]), best]
				var col := ink
				if bool(row.get("wrong", false)):
					col = ink.lerp(Color(0.42, 0.18, 0.18), 0.55)
				_body(into, line, col)
				if row.has("note"):
					_body(into, "   " + str(row["note"]), ink_dim)

	# The page number, bottom right, the way a book has one.
	var foot := Label.new()
	foot.text = "%d / %d" % [clampi(page_index, 0, n - 1) + 1, n]
	foot.add_theme_font_size_override("font_size", 26)
	foot.add_theme_color_override("font_color", ink_dim)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	into.add_child(foot)
	return n


static func _head(into: VBoxContainer, text: String, col: Color, rule: Color) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", col)
	l.custom_minimum_size = Vector2(0, 56)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	into.add_child(l)
	var r := ColorRect.new()
	r.color = rule
	r.custom_minimum_size = Vector2(0, 2)
	into.add_child(r)


static func _body(into: VBoxContainer, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(l)
