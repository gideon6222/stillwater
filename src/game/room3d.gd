class_name Room3D
extends Node3D

## A ROOM THAT IS AN OBJECT IN THE BOAT.
##
## Gideon: "I was wanting real physical objects and places... I want to
## physically see the book in the boat. When you click on it, it opens and zooms
## in on the pages, then you flip each page."
##
## So a room is no longer a panel that covers the screen. It is a thing lying in
## the hull, at a real position, that the camera goes to look at and that opens.
##
## **The trick that makes this affordable is a SubViewport.** The page content is
## still laid out with ordinary Controls - the same paper skin, the same ink, the
## same entries - but it is rendered into an off-screen viewport and used as the
## TEXTURE on a physical page. So the layout work is not thrown away to make the
## object real; it becomes the surface of the object.
##
## The alternative - laying out text as 3D nodes in world space - would mean
## rewriting every room and re-solving wrapping, scrolling and hit-testing in a
## space that has none of it.

## How the object is currently doing.
enum State { SHUT, OPENING, OPEN, SHUTTING }

signal opened
signal shut

## Where the camera sits to read it, and what it looks at. In BOAT space, so
## these ride the swell with everything else.
@export var read_from := Vector3(0.0, 0.95, 0.30)
@export var read_at := Vector3(0.0, 0.42, 0.62)

## Seconds to open, and to shut.
const OPEN_TIME := 0.55

var state: State = State.SHUT
var openness := 0.0          ## 0 shut, 1 open

## Which page is showing. On the OBJECT rather than on the layout helper,
## because it is the book's own state - a book you put down remembers where you
## were in it.
var page := 0

## Whether this object PRINTS anything. False for the tackle box, whose contents
## are real objects in its trays rather than a list on a quad - and a leftover
## surface there is not harmless: an empty SubViewport renders as a black slab
## across the whole inside of the box, hiding the things it is supposed to show.
var show_surface := true

var _model: Node3D

## Some models ship BOTH states - the Poly Haven notebook has an open mesh and a
## closed one in the same file. When they are named, opening the object is a
## swap between them rather than an animation nobody has to author.
var _mesh_open: MeshInstance3D
var _mesh_shut: MeshInstance3D
var _surface: MeshInstance3D
var _viewport: SubViewport
var _content: Control


## Build the object: a model, and a flat surface to print the page onto.
##
## `surface_size` is in metres and `surface_at` is where it sits relative to the
## object's own origin - a page lies just above a book's cover, the inside of a
## lid stands up behind a box.
func build(model: Node3D, surface_size: Vector2, surface_at: Transform3D,
		content: Control, pixels: Vector2i) -> void:
	_model = model
	if _model != null:
		add_child(_model)

	# The off-screen page. `update_always` because the content changes whenever
	# the game does and a page that only redraws on demand is a page that shows
	# yesterday's money.
	_viewport = SubViewport.new()
	_viewport.size = pixels
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = false
	add_child(_viewport)

	# SIZED AFTER PARENTING, and anchored to fill. Setting the size first is
	# overwritten the moment the node enters the tree, so the page content was
	# being laid out at some default width: the paper only covered part of the
	# quad and every line of text ran off both edges. The camera was in exactly
	# the right place the whole time.
	_content = content
	_viewport.add_child(_content)
	# `set_anchors_AND_OFFSETS_preset`. The plain `set_anchors_preset` sets the
	# anchors and leaves the OFFSETS where they were, so the rect stays whatever
	# it already was - which is why the paper covered only the bottom corner of
	# the page through several rounds of blaming the camera, the quad and the
	# viewport in turn.
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.custom_minimum_size = Vector2(pixels)

	_surface = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = surface_size
	_surface.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = _viewport.get_texture()
	# UNSHADED, and it matters. A page lit by the game's own sun goes to almost
	# nothing at night and in the quarry, and a logbook you cannot read after
	# dark is a logbook that stops working exactly when the game gets
	# interesting. The paper carries its own light, the way a page held up to
	# your face does.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# AND IT DOES NOT DEPTH-TEST, which is the price of a menu being geometry.
	#
	# Gideon, on the phone: "the menus clip through the physical objects." A
	# SubViewport quad is an ordinary mesh, so it intersects the floorboards, the
	# tackle box and the hull like any other - and half a page disappearing behind
	# a plank reads as a broken menu, not as a solid world.
	#
	# A panel got this for free and an object has to earn it back. The surface is
	# only visible while the thing is open and the camera is right on top of it,
	# so drawing it over everything costs nothing anywhere else and is exactly
	# what a reader expects: the page you are holding is in front of the boat.
	m.no_depth_test = true
	m.render_priority = 8
	_surface.material_override = m
	_surface.transform = surface_at
	_surface.visible = false
	add_child(_surface)
	_find_states(_model)


## A HINGED PART, for a model that has a lid rather than two whole states.
##
## The notebook ships an open mesh and a closed one, so opening it is a swap. A
## toolbox ships one body and one LID, which is the commoner shape and the more
## useful one - the lid can be caught halfway, and the same mechanism will open a
## shed door later.
##
## The pivot is in the PART's own local space, and is the hinge line rather than
## the part's origin: a lid turns about its back edge, not about its middle.
## Rotating about the origin swings the lid through the box.
var _hinge: Node3D
var _hinge_rest := Transform3D.IDENTITY
var _hinge_pivot := Vector3.ZERO
var _hinge_axis := Vector3.RIGHT
var _hinge_degrees := 0.0


func set_hinge(part: Node3D, pivot_local: Vector3, axis: Vector3, degrees: float) -> void:
	_hinge = part
	if part == null:
		return
	_hinge_rest = part.transform
	_hinge_pivot = pivot_local
	_hinge_axis = axis.normalized()
	_hinge_degrees = degrees


## Find a child by name anywhere under the model, so a caller can name the lid
## without knowing how the exporter nested it.
func find_part(name_part: String) -> Node3D:
	return _find_named(_model, name_part)


func _find_named(node: Node, want: String) -> Node3D:
	if node == null:
		return null
	for c in node.get_children():
		if str(c.name).findn(want) >= 0 and c is Node3D:
			return c as Node3D
		var deeper := _find_named(c, want)
		if deeper != null:
			return deeper
	return null


## Look for a pair of meshes named "<thing>" and "<thing>_closed".
func _find_states(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi != null:
			if str(mi.name).ends_with("_closed"):
				_mesh_shut = mi
			elif _mesh_open == null:
				_mesh_open = mi
		_find_states(c)


## Open it. The camera move is the caller's job - this is only the object.
func open() -> void:
	if state == State.OPEN or state == State.OPENING:
		return
	state = State.OPENING


func close() -> void:
	if state == State.SHUT or state == State.SHUTTING:
		return
	state = State.SHUTTING


func is_open() -> bool:
	return state == State.OPEN


func advance(dt: float) -> void:
	match state:
		State.OPENING:
			openness = minf(1.0, openness + dt / OPEN_TIME)
			if openness >= 1.0:
				state = State.OPEN
				opened.emit()
		State.SHUTTING:
			openness = maxf(0.0, openness - dt / OPEN_TIME)
			if openness <= 0.0:
				state = State.SHUT
				shut.emit()
	# The page only exists once the thing is properly open. A texture floating
	# over a shut book is the single most obvious way to break the illusion.
	# The model's own two states, if it has them. Halfway through the open is
	# where the swap reads best - by then the camera is already moving.
	if _mesh_open != null and _mesh_shut != null:
		_mesh_open.visible = openness > 0.5
		_mesh_shut.visible = openness <= 0.5
	# A hinged lid, turned about its hinge LINE rather than its own origin. Eased
	# so it falls open and settles instead of sweeping at one rate - a lid is on
	# a spring or it is on gravity, and neither is linear.
	if _hinge != null:
		var k := openness * openness * (3.0 - 2.0 * openness)
		var b := Basis(_hinge_axis, deg_to_rad(_hinge_degrees * k))
		var about_pivot := Transform3D(b, _hinge_pivot - b * _hinge_pivot)
		_hinge.transform = about_pivot * _hinge_rest
	if _surface != null:
		_surface.visible = show_surface and openness > 0.55
		var m := _surface.material_override as StandardMaterial3D
		if m != null:
			m.albedo_color = Color(1, 1, 1, 1) * clampf((openness - 0.55) / 0.45, 0.0, 1.0)


## Where the camera should sit to read this, in world space.
##
## **The distance is COMPUTED, not typed.** Hand-tuned read poses were wrong
## three times running - a 33 cm page in a portrait frame is only visible at all
## past about 80 cm, and the arithmetic for that is two lines while the guessing
## was open-ended. Given the camera's own fov and aspect, this backs off exactly
## far enough to fit the surface with a margin, and looks straight down the
## page's normal at its centre.
##
## It also means the framing survives someone resizing the page, moving the
## object, or changing the field of view - none of which a typed offset does.
func frame_pose(boat: Transform3D, fov_deg: float, aspect: float, margin := 1.06) -> Array:
	if _surface == null:
		return [boat * (transform * read_from), boat * (transform * read_at)]
	var quad := _surface.mesh as QuadMesh
	var half_fov := deg_to_rad(fov_deg) * 0.5
	# Godot's fov is VERTICAL, so the horizontal half-angle is scaled by aspect.
	var need_v := (quad.size.y * margin * 0.5) / tan(half_fov)
	var need_h := (quad.size.x * margin * 0.5) / (tan(half_fov) * aspect)
	var dist := maxf(need_v, need_h)

	var page := transform * _surface.transform
	var centre := page.origin
	var normal := page.basis.z.normalized()
	# A little off square, so it reads as a book being looked at rather than a
	# document being scanned.
	var eye := centre + normal * dist + Vector3(0.0, 0.0, -dist * 0.22)
	# THE UP VECTOR IS THE PAGE'S OWN, not the boat's and not the world's.
	#
	# The book is deliberately not square to the hull - a book somebody put down
	# never is - and with the camera levelled against the boat that fourteen
	# degrees came out as fourteen degrees of tilted TEXT filling the screen,
	# which is unreadable and looks like a bug rather than like a detail. A
	# person leaning over a book turns their head to the page; so does this.
	return [boat * eye, boat * centre, (boat.basis * page.basis.y).normalized()]


func read_pose(boat: Transform3D) -> Array:
	return [boat * (transform * read_from), boat * (transform * read_at)]


## Turn a tap on the surface into a position on the page, or return -1,-1 if the
## ray misses. The caller supplies a world ray; this reports where it lands in
## the content's own pixels, so the Control tree can be asked what is there.
func hit_page(from: Vector3, dir: Vector3, boat: Transform3D) -> Vector2:
	if _surface == null or not _surface.visible:
		return Vector2(-1, -1)
	var plane_xform := boat * transform * _surface.transform
	var normal := plane_xform.basis.z.normalized()
	var origin := plane_xform.origin
	var denom := normal.dot(dir)
	if absf(denom) < 0.0001:
		return Vector2(-1, -1)
	var t := normal.dot(origin - from) / denom
	if t < 0.0:
		return Vector2(-1, -1)
	var hit := from + dir * t
	var local := plane_xform.affine_inverse() * hit
	var quad := _surface.mesh as QuadMesh
	var half := quad.size * 0.5
	if absf(local.x) > half.x or absf(local.y) > half.y:
		return Vector2(-1, -1)
	# Quad UVs run left to right and TOP to bottom, so y flips.
	return Vector2(
		(local.x + half.x) / quad.size.x * float(_viewport.size.x),
		(half.y - local.y) / quad.size.y * float(_viewport.size.y))
