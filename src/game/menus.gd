class_name Menus
extends CanvasLayer

## The three rooms that are not the water: the Shed, the Map and the Log.
##
## They are built in code from `sim` and `sim.econ` every time they open, which
## is the whole reason they are trustworthy. **A shop that caches its own prices
## is a second copy of the rules**, and the copy is the one that goes stale - so
## nothing here stores anything. `_fill_shed` reads `Gear.LINE[econ.line + 1]`
## at the moment it draws the row, and the button it wires calls the same
## `econ.buy_next` the tests do.
##
## Separate from `main.gd` because that file is the 3D scene - water, boat, rod,
## fish - and this one is a stack of lists. Putting them together would have made
## one two-thousand-line file where every change to a shelf risks the shader.
##
## Layout is anchors and containers throughout, never literal pixel positions.
## The base resolution is 1080x1920 but `stretch/aspect` is `expand`, so on the
## phone this actually renders into about 1080x2340 - anything positioned by
## arithmetic off 1920 lands in the wrong place, and a menu that is slightly
## wrong at the bottom of the screen is a menu with an unreachable button.

signal changed            ## something was bought, sold, or travelled to
signal closed

const SHED := "shed"
const MAP := "map"
const LOG := "log"
const KIT := "kit"

## Ink and paper. The lake is cold and blue-green; the rooms are the inside of a
## keeper's hut, so they are warm and dim, and they get no brighter as the game
## goes on - the water is what changes.
const INK := Color(0.93, 0.90, 0.82)
const INK_DIM := Color(0.93, 0.90, 0.82, 0.55)
const PAPER := Color(0.09, 0.10, 0.11, 0.97)
const PANEL := Color(0.14, 0.15, 0.15)
const RULE := Color(0.93, 0.90, 0.82, 0.14)
const COIN := Color(0.88, 0.76, 0.42)
const GOOD := Color(0.50, 0.80, 0.52)
const DEAD := Color(0.93, 0.90, 0.82, 0.30)
const WRONG := Color(0.78, 0.55, 0.62)

const ROW_H := 108        ## a touch target, not a line of text
const PAD := 40

var sim: Sim

## Player settings. Owned here because this is the screen that edits them, and
## pushed out to the renderer and the mixer through `changed` - neither of those
## needs to know a menu exists.
var sensitivity := 1.0
var sound_muted := false

var _root: Control
var _title: Label
var _purse: Label
var _list: VBoxContainer
var _toast: Label
var _toast_left := 0.0
var _screen := ""


## Same reason as the mixer: `setup` builds the whole UI and must not run twice.
func retarget(s: Sim) -> void:
	sim = s
	if is_open():
		refresh()


func setup(s: Sim) -> void:
	sim = s
	layer = 2
	_build()


func is_open() -> bool:
	return _screen != ""


func current() -> String:
	return _screen


func open(screen: String) -> void:
	_screen = screen
	_root.visible = true
	refresh()


func close() -> void:
	_screen = ""
	_root.visible = false
	closed.emit()


## Rebuild the open screen from scratch. Cheap - a few dozen Controls - and it
## removes the entire class of bug where a price, a count or a lock is drawn once
## and then quietly disagrees with the rules for the rest of the session.
func refresh() -> void:
	if _screen == "":
		return
	for c in _list.get_children():
		c.queue_free()
		_list.remove_child(c)
	_purse.text = "%d coin" % sim.econ.money
	match _screen:
		SHED:
			_title.text = "The Bait Shed"
			_fill_shed()
		MAP:
			_title.text = "The Lake"
			_fill_map()
		LOG:
			_title.text = "The Logbook"
			_fill_log()
		KIT:
			_title.text = "Your Kit"
			_fill_kit()


func tick(dt: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= dt
	_toast.modulate.a = clampf(_toast_left * 1.6, 0.0, 1.0)
	if _toast_left <= 0.0:
		_toast.visible = false


# --- the frame ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, and it is the point of the whole layer. The cast area underneath is
	# also full-rect, so without this a tap meant for a shelf would also cast a
	# line into water the player cannot currently see.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.name = "Menus"
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = PAPER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = PAD
	col.offset_right = -PAD
	col.offset_top = 70
	col.offset_bottom = -PAD
	col.add_theme_constant_override("separation", 18)
	_root.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	_purse = Label.new()
	_purse.add_theme_font_size_override("font_size", 40)
	_purse.add_theme_color_override("font_color", COIN)
	_purse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_purse)

	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_color", GOOD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	col.add_child(_toast)

	var back := _button("Back to the boat", true)
	back.pressed.connect(close)
	col.add_child(back)


func _say(msg: String, good: bool = true) -> void:
	_toast.text = msg
	_toast.add_theme_color_override("font_color", GOOD if good else WRONG)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = 2.4


func _button(text: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.add_theme_font_size_override("font_size", 34)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL if enabled else Color(0.11, 0.115, 0.12)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(18)
	b.add_theme_stylebox_override("normal", normal)
	var press := normal.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.20, 0.22, 0.22)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", INK if enabled else DEAD)
	b.add_theme_color_override("font_disabled_color", DEAD)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	return b


## A shelf: what it is on the left, what it costs on the right, and the whole row
## is the button. Two labels inside one Button rather than a Button beside a
## Label, because a price that is not part of the touch target is a price the
## player taps and nothing happens.
## `enabled` says whether tapping does anything. `reading` says the row is
## CONTENT rather than a control, and the two are not the same thing - a logbook
## entry and a motor you already own are both untappable, but neither is
## *unavailable*, and drawing them in the dead grey reserved for "you cannot
## afford this" made an achievement look like a refusal. The whole logbook came
## out unreadable that way.
func _row(left: String, right: String, sub: String, enabled: bool,
		right_colour: Color = COIN, reading: bool = false) -> Button:
	var b := _button("", enabled)
	if reading:
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", INK)
	b.custom_minimum_size = Vector2(0, ROW_H if sub == "" else ROW_H + 34)

	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	b.add_child(box)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(names)

	var l := Label.new()
	l.text = left
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", INK if (enabled or reading) else DEAD)
	names.add_child(l)

	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 26)
		s.add_theme_color_override("font_color", INK_DIM if (enabled or reading) else DEAD)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(s)

	var r := Label.new()
	r.text = right
	r.add_theme_font_size_override("font_size", 34)
	r.add_theme_color_override("font_color", right_colour if (enabled or reading) else DEAD)
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(r)
	return b


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", INK_DIM)
	l.custom_minimum_size = Vector2(0, 62)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_list.add_child(l)


## An unfilled line. Deliberately still VISIBLE - an empty rule is a question,
## and a hidden row is nothing at all - but a third the height of a real entry,
## because twenty-six blanks at touch-target height is a page nobody scrolls to
## the end of.
func _blank() -> void:
	var r := ColorRect.new()
	r.color = RULE
	r.custom_minimum_size = Vector2(0, 2)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 15)
	pad.add_theme_constant_override("margin_bottom", 15)
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 260)
	pad.add_child(r)
	_list.add_child(pad)


func _note(text: String, colour: Color = INK_DIM) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)


# --- the shed -------------------------------------------------------------

func _fill_shed() -> void:
	var econ := sim.econ

	_heading("the livewell")
	if econ.held.is_empty():
		_note("Empty. Nothing to weigh in.")
	else:
		var worth := 0
		for f in econ.held:
			worth += Econ.value_of(f["id"], f["weight"], f["wrong"])
			var s := Species.by_id(f["id"])
			var kg := "%.2f kg" % float(f["weight"])
			_note("   %s   %s" % [s["name"], kg], WRONG if f["wrong"] else INK_DIM)
		var sell := _row("Weigh it all in", "+%d" % worth,
			"%.1f of %.1f kg" % [econ.load_kg(), econ.capacity()], true)
		sell.pressed.connect(func() -> void:
			var paid := sim.sell()
			_say("Weighed in for %d." % paid)
			refresh()
			changed.emit())
		_list.add_child(sell)

	_heading("gear")
	_ladder("line", Gear.LINE, econ.line, func(row: Dictionary) -> String:
		return "reaches %s" % SimUtil.fmt_m(float(row["depth"])))
	_ladder("rod", Gear.ROD, econ.rod, func(row: Dictionary) -> String:
		return "holds %.0f kg, and forgives more" % float(row["strength"]))
	_ladder("reel", Gear.REEL, econ.reel, func(row: Dictionary) -> String:
		return "hauls %.0f%% faster than the first one" % ((float(row["haul"]) - 1.0) * 100.0))

	var lw := econ.livewell + 1
	if lw < Econ.CAPACITY.size():
		var price: int = Econ.CAPACITY_PRICE[lw]
		var b := _row("A bigger livewell", "%d" % price,
			"%.0f kg instead of %.0f" % [Econ.CAPACITY[lw], econ.capacity()],
			econ.can_afford(price))
		b.pressed.connect(func() -> void: _buy_next("livewell"))
		_list.add_child(b)

	_heading("the boat")
	_boat_item("motor", "An outboard motor", Gear.MOTOR_PRICE,
		"takes you off this bay", econ.has_motor)
	_boat_item("sounder", "A depth sounder", Gear.SOUNDER_PRICE,
		"draws what is under the hull", econ.has_sounder)
	_boat_item("lamp", "A deck lamp", Gear.LAMP_PRICE,
		"for fishing after dark", econ.has_lamp)

	_heading("bait")
	for b in Gear.BAIT:
		var id: String = b["id"]
		if int(b["price"]) < 0 and not sim.econ.has_bait(id):
			# Offerings are found, never sold - so the shelf is empty until the
			# lake has given you one, and then it is simply there. Hiding it
			# entirely even when held would mean the player could not see the one
			# thing that unlocks the deep.
			continue
		var held := ""
		if bool(b["reusable"]):
			held = "yours" if id in econ.owned_lures else ""
		else:
			held = "%d left" % int(econ.bait_left.get(id, 0))
		var sub := "%s%s" % ["favours " + _favours(b), "" if held == "" else "   -   " + held]
		var chosen := econ.bait == id
		# Say plainly where it stops working. The player should learn the rule
		# from the shelf, not from an hour of nothing biting.
		if not Gear.bait_works_at(id, sim.deepest_here()):
			sub = "%s   -   no use in %s of water" % [sub, SimUtil.fmt_m(sim.deepest_here())]
		# The right column says what tapping WILL do, so it reads as a verb and
		# not as a price you are about to be charged twice for.
		var right := str(b["price"])
		if chosen:
			right = "on the hook"
		elif bool(b["reusable"]) and id in econ.owned_lures:
			right = "yours"
		elif econ.has_bait(id):
			right = "use"
		var row := _row(str(b["name"]), right, sub, true, GOOD if chosen else COIN)
		row.pressed.connect(func() -> void: _tap_bait(id))
		_list.add_child(row)
	_note("Tap bait you own to fish with it. Tap bait you do not to buy some.")


func _favours(b: Dictionary) -> String:
	var out: Array[String] = []
	var favours: Array = b["favours"]
	for id in favours:
		var s := Species.by_id(id)
		if not s.is_empty() and sim.logged.has(id):
			out.append(str(s["name"]))
	if out.is_empty():
		return "fish you have not met yet"
	return ", ".join(out)


## The bait row does two different things and which one depends on whether you
## own any. That is deliberate: a separate "select" and "buy" control for seven
## baits is fourteen touch targets on a phone, and the answer to "what should
## tapping this do" is always the obvious one.
func _tap_bait(id: String) -> void:
	var econ := sim.econ
	if econ.has_bait(id):
		econ.bait = id
		_say("Fishing with %s." % Gear.bait_by_id(id)["name"].to_lower())
	elif econ.buy_bait(id):
		econ.bait = id
		_say("Bought %s." % Gear.bait_by_id(id)["name"].to_lower())
	else:
		_say("Not enough for that.", false)
	refresh()
	changed.emit()


func _ladder(kind: String, table: Array, level: int, describe: Callable) -> void:
	var next := level + 1
	if next >= table.size():
		_list.add_child(_row(str(table[level]["name"]), "the best there is", "", false, GOOD, true))
		return
	var row: Dictionary = table[next]
	var price: int = row["price"]
	# -1 is not a price. The Long Rod and the old line are FOUND, and a shelf
	# that showed them at any number would be promising something for money that
	# the game will never sell.
	if price < 0:
		_list.add_child(_row(str(table[level]["name"]), "",
			"There is nothing here you can buy.", false, COIN, true))
		return
	var b2 := _row(str(row["name"]), "%d" % price, describe.call(row), sim.econ.can_afford(price))
	b2.pressed.connect(func() -> void: _buy_next(kind))
	_list.add_child(b2)


func _buy_next(kind: String) -> void:
	if sim.econ.buy_next(kind):
		_say("Bought.")
	else:
		_say("Not enough for that.", false)
	refresh()
	changed.emit()


func _boat_item(kind: String, name: String, price: int, sub: String, owned: bool) -> void:
	if owned:
		# NOT the disabled styling. Owned and unaffordable were both drawn dead
		# grey, so the motor you have just bought looked exactly like the sounder
		# you cannot - the shed said "fitted" in the visual language of "no".
		_list.add_child(_row(name, "fitted", sub, false, GOOD, true))
		return
	var b := _row(name, "%d" % price, sub, sim.econ.can_afford(price))
	b.pressed.connect(func() -> void:
		if sim.econ.buy_boat(kind):
			_say("Fitted.")
		else:
			_say("Not enough for that.", false)
		refresh()
		changed.emit())
	_list.add_child(b)


# --- the map --------------------------------------------------------------

func _fill_map() -> void:
	_note("Day %d, %s. %s." % [sim.day, sim.hour, str(sim.weather).capitalize()])
	_heading("where to fish")
	for s in World.SPOTS:
		var id: String = s["id"]
		var here := sim.spot == id
		var blocked := sim.spot_blocked(id)
		var reach := World.reachable_depth(id, sim.econ.line)
		# **The map shows metres and never years.** It is the whole conceit that
		# the player joins those up themselves, from the dates on what comes up.
		# What the map has to answer is "what can I fish there", and the first
		# version answered "the bed is 152 m down - your line will not reach the
		# bottom (you can still fish the first 4.0 m)" for five spots at once.
		# Every word of that was true and the whole sentence was noise: with the
		# starting line the answer for all five is simply NO.
		var window := World.fishable_window(id, sim.econ.line)
		var sub := ""
		if window.is_empty():
			sub = "%s of water. Your line reaches %s." % [
				SimUtil.fmt_m(float(s["bed"])), SimUtil.fmt_m(Gear.line_depth(sim.econ.line))]
		elif reach >= float(s["bed"]) - 0.01:
			sub = "all of it, %s down to the bed" % SimUtil.fmt_m(window[1])
		else:
			sub = "the top %s of %s" % [
				SimUtil.fmt_m(window[1]), SimUtil.fmt_m(float(s["bed"]))]
		if bool(s["needs_motor"]) and not sim.econ.has_motor:
			sub = "%s - %s" % [sub, blocked]
		var can_go := not (bool(s["needs_motor"]) and not sim.econ.has_motor) 			and not window.is_empty()
		var b := _row(("* " if here else "") + str(s["name"]),
			"here" if here else ("go" if can_go else ""),
			sub, can_go and not here, GOOD)
		b.pressed.connect(func() -> void:
			if sim.travel_to(id):
				_say("Under way to %s." % s["name"])
				refresh()
				changed.emit()
			else:
				_say("You cannot get there yet.", false))
		_list.add_child(b)

	_heading("the hours")
	var rest := _row("Put your head down", World.next_hour(sim.hour),
		"different water bites at different hours", true, GOOD)
	rest.pressed.connect(func() -> void:
		sim.sleep()
		_say("You wake at %s." % sim.hour)
		refresh()
		changed.emit())
	_list.add_child(rest)


# --- the log --------------------------------------------------------------

## The collection, and the place the story actually lands.
##
## Species are listed by BAND with the ones you have not met shown as blank
## rules rather than hidden, because an empty line you can see is a question and
## a hidden one is nothing at all. The objects carry their dates, and the dates
## are the reveal - the game never says what they mean.
## THE BOOK COMES FIRST, above the catch.
##
## The logbook is the story, and the species records are what the player is
## adding to it. Putting the fish first would make the book a fishing tally with
## some text underneath; putting the hands first makes the tally the fifth entry
## in something much older, which is what it is.
func _fill_book() -> void:
	var met := Keepers.hands_met(sim.deepest_ever)
	_note("%d of %d hands. The last one is yours." % [met, Keepers.total_hands()])

	var entries := Keepers.unlocked(sim.deepest_ever)
	if entries.is_empty():
		_note("The pages before yours are still shut.", INK_DIM)
	var hand := ""
	for e in entries:
		var who: String = e["hand"]
		if who != hand:
			hand = who
			_heading("%s, %d" % [who, int(e["year"])])
		var l := Label.new()
		l.text = str(e["text"])
		l.add_theme_font_size_override("font_size", 28)
		# Each hand a shade different, and the older it is the more it has faded.
		# Handwriting, without needing a font per keeper.
		var age := clampf((float(e["at"]) - 1.0) / 140.0, 0.0, 1.0)
		l.add_theme_color_override("font_color", INK.lerp(INK_DIM, age * 0.75))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)

	var next_at := -1.0
	for e in Keepers.ENTRIES:
		var at: float = e["at"]
		if at > sim.deepest_ever + 0.001:
			next_at = at
			break
	if next_at > 0.0:
		# The one honest instruction the book ever gives, and it is still not an
		# objective - it is a depth, and the player already knows what depth is.
		_note("The next page is shut. Your line has been %s down." %
			SimUtil.fmt_m(sim.deepest_ever), INK_DIM)


func _fill_log() -> void:
	_fill_book()
	_heading("what you have caught")
	# `sim.logged` maps species id -> the HEAVIEST one landed, so this is a record
	# book and not a tally. Two things follow, and the second one shipped wrong:
	# presence is `has`, never `> 0`, because `int(0.14)` is zero and a bluegill
	# would have stayed off its own page for the whole game.
	var kept := 0
	for s in Species.TABLE:
		if sim.logged.has(s["id"]):
			kept += 1
	_note("%d of %d in the water, %d of %d off the bottom." % [
		kept, Species.TABLE.size(), sim.found.size(), Objects.TABLE.size()])

	for band in World.BANDS:
		var rows := []
		for s in Species.TABLE:
			if s["band"] == band["id"]:
				rows.append(s)
		if rows.is_empty():
			continue
		_heading(str(band["name"]))
		for s in rows:
			if not sim.logged.has(s["id"]):
				_blank()
				continue
			var best: float = sim.logged[s["id"]]
			var sub := str(s["note"]) if s.has("note") else ""
			_list.add_child(_row(str(s["name"]), "%.2f kg" % best, sub, false,
				WRONG if bool(s.get("wrong", false)) else COIN, true))

	_heading("off the bottom")
	var any := false
	for o in Objects.TABLE:
		if not sim.found.has(o["id"]):
			continue
		any = true
		var year := ""
		if o.has("year"):
			year = str(int(o["year"]))
		_list.add_child(_row(str(o["name"]), year, str(o.get("note", "")), false, COIN, true))
	if not any:
		_note("Nothing yet but water.")


# --- the kit ----------------------------------------------------------------

## Settings, and the reason they are a ROOM rather than a gear icon.
##
## Every study of touch look-controls says the same thing: sensitivity has to be
## adjustable, because it is the one control value where preference genuinely
## differs and no default is right for everyone. Gideon's note on the first
## build with a look control was "the turning is really fast" - the default was
## four times too quick, and a player without this screen would simply have put
## the game down.
##
## It sits with the shed and the logbook because opening a menu should always
## mean the same gesture. A gear in a corner is a second navigation language for
## one screen.
func _fill_kit() -> void:
	_heading("looking around")
	_note("How far the view turns when you drag. Lower is slower and steadier.")
	var speeds := [
		["Slow", 0.6], ["Steady", 0.85], ["Normal", 1.0], ["Quick", 1.3], ["Fast", 1.7],
	]
	for row in speeds:
		var name: String = row[0]
		var value: float = row[1]
		var chosen: bool = absf(sensitivity - value) < 0.01
		var b := _row(name, "set" if not chosen else "yours",
			"", not chosen, GOOD if chosen else COIN, chosen)
		b.pressed.connect(func() -> void:
			sensitivity = value
			_say("Turning set to %s." % name.to_lower())
			refresh()
			changed.emit())
		_list.add_child(b)

	_heading("sound")
	var muted: bool = sound_muted
	var mb := _row("Sound", "off" if muted else "on",
		"the lake, the reel, and whatever is under it", true,
		WRONG if muted else GOOD)
	mb.pressed.connect(func() -> void:
		sound_muted = not sound_muted
		_say("Sound off." if sound_muted else "Sound on.")
		refresh()
		changed.emit())
	_list.add_child(mb)

	_heading("the boat")
	_note("Day %d, %s. %s." % [sim.day, sim.hour, str(sim.weather).capitalize()])
	_note("%s, in %s of water." % [
		str(World.spot_by_id(sim.spot)["name"]), SimUtil.fmt_m(sim.deepest_here())])
	_note("Line: %s.   Rod: %s.   Reel: %s." % [
		Gear.line_name(sim.econ.line),
		str(Gear.ROD[sim.econ.rod]["name"]),
		str(Gear.REEL[sim.econ.reel]["name"])])
	_note("%d cast, %d landed, %d lost." % [sim.casts, sim.caught, sim.lost_count])

