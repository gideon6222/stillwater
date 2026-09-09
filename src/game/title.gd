class_name TitleScreen
extends CanvasLayer

## The first thing on launch.
##
## **Not a separate scene.** The real boat is booted and running underneath —
## the water is moving, the sky is whatever hour the save left, the reeds are
## there — and this is a layer over it. So the title is a photograph of the game
## rather than a picture of one, and the first frame the player ever sees is
## already alive. It also means there is no load between here and playing.
##
## `Continue` is the default and sits on top, because a returning player is the
## common case and should not have to read past the option that would delete
## their game.

signal start_new
signal start_continue
signal open_settings

const INK := Color(0.94, 0.91, 0.84)
const INK_DIM := Color(0.94, 0.91, 0.84, 0.58)
const WARM := Color(0.88, 0.72, 0.40)

var _root: Control
var _continue: Button
var _fade := 1.0
var _dismissing := false


func setup(has_save: bool) -> void:
	layer = 3
	_build()
	# Greyed rather than hidden. A missing button is a question ("was there a
	# save?"); a greyed one is an answer.
	_continue.disabled = not has_save
	_continue.add_theme_color_override("font_color", INK if has_save else INK_DIM)


func is_up() -> bool:
	return _root != null and _root.visible


## Fade the layer out rather than switching it off, so the game does not begin
## on a cut. Called every frame while dismissing.
func tick(dt: float) -> void:
	if not _dismissing:
		return
	_fade = maxf(0.0, _fade - dt * 2.2)
	_root.modulate.a = _fade
	if _fade <= 0.0:
		_root.visible = false
		_dismissing = false


func dismiss() -> void:
	_dismissing = true


## Gone this instant, with no fade. For the headless harness, which wants the
## game and not the front door.
func skip() -> void:
	_dismissing = false
	_fade = 0.0
	if _root != null:
		_root.modulate.a = 0.0
		_root.visible = false


## Put it back up. Only the screenshot tool asks for this - `freeze` skips the
## title, so photographing it needs a way to undo that.
func show_again() -> void:
	_dismissing = false
	_fade = 1.0
	if _root != null:
		_root.modulate.a = 1.0
		_root.visible = true


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP, so nothing behind the title can be cast into or dragged.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.name = "Title"
	add_child(_root)

	# A wash rather than a curtain: the lake stays visible through it, darkened
	# enough for the type to hold.
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.03, 0.05, 0.06, 0.52)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	var name_label := Label.new()
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 300
	name_label.offset_bottom = 460
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = "STILLWATER"
	name_label.add_theme_font_size_override("font_size", 96)
	name_label.add_theme_color_override("font_color", INK)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	name_label.add_theme_constant_override("outline_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(name_label)

	var under := Label.new()
	under.set_anchors_preset(Control.PRESET_TOP_WIDE)
	under.offset_top = 470
	under.offset_bottom = 540
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The whole premise, in six words, and it reads as a fishing game's tagline
	# until some hours later.
	under.text = "the lake does not go down"
	under.add_theme_font_size_override("font_size", 34)
	under.add_theme_color_override("font_color", INK_DIM)
	under.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	under.add_theme_constant_override("outline_size", 8)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(under)

	# The buttons live in the bottom third, in the thumb zone, and Continue is
	# the warm one - the same warm-verb / cool-navigation split the HUD uses.
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	col.offset_left = 150
	col.offset_right = -150
	col.offset_top = -760
	col.offset_bottom = -280
	col.add_theme_constant_override("separation", 26)
	_root.add_child(col)

	_continue = _button("Continue", true)
	_continue.pressed.connect(func() -> void: start_continue.emit())
	col.add_child(_continue)

	var fresh := _button("New game", false)
	fresh.pressed.connect(func() -> void: start_new.emit())
	col.add_child(fresh)

	var settings := _button("Settings", false)
	settings.pressed.connect(func() -> void: open_settings.emit())
	col.add_child(settings)


func _button(text: String, warm: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 132)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.115, 0.075, 0.88) if warm else Color(0.05, 0.09, 0.10, 0.80)
	box.border_color = WARM if warm else Color(0.93, 0.90, 0.82, 0.26)
	box.set_border_width_all(3 if warm else 2)
	box.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("disabled", box)
	var press := box.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.34, 0.25, 0.14, 0.94) if warm else Color(0.16, 0.24, 0.25, 0.92)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", INK_DIM)
	return b
