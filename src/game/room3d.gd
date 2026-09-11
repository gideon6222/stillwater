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

## HOW LONG A PAGE TAKES TO TURN.
##
## Gideon: "the pages dont flip, they just change instantly". They did - the code
## set a `_page_turn` flag that nothing ever read, so the texture was swapped
## between one frame and the next and the book might as well have been a list.
##
## 0.34 s is the middle of the 0.3-0.4 s the plan asks for, and it is chosen
## against the READ rather than against paper: shorter and the eye does not
## register that a leaf moved at all, longer and turning three pages to find
## something becomes a wait. Real paper is faster than either and looks wrong.
const TURN_TIME := 0.34

## The colour of the back of a leaf. Matched to the page's own paper so the two
## read as the same sheet seen from two sides.
const PAPER := Color(0.93, 0.91, 0.86)

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

## THE TURNING LEAF. See `begin_turn`.
var _leaf: Node3D = null           ## the pivot, sitting on the spine
var _leaf_rest := Transform3D.IDENTITY   ## where the pivot sits with nothing turning
var _leaf_front: MeshInstance3D    ## the page you were reading, turning away
var _leaf_back: MeshInstance3D     ## the one underneath it, coming up
var _leaf_size := Vector2.ZERO
var _turn := 0.0                   ## 1 at the start of a turn, 0 when it is over
var _turn_dir := 1.0
var _turn_rang := false            ## has the paper flapped yet this turn
signal page_flapped                ## fired as the leaf passes vertical


## Build the object: a model, and a flat surface to print the page onto.
##
## `surface_size` is in metres and `surface_at` is where it sits relative to the
## object's own origin - a page lies just above a book's cover, the inside of a
## lid stands up behind a box.
func build(model: Node3D, surface_size: Vector2, surface_at: Transform3D,
		content: Control, pixels: Vector2i) -> void:
	_model = model
	if _model != null:
		# NAMED, so a caller can ask for the object's own bounds without picking
		# up whatever else has been parented to it. The tackle box's contents hang
		# off the box, and a hit box built from the whole subtree was half a metre
		# across for a 40 cm toolbox.
		_model.name = "Model"
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
	_surface.name = "Page"
	add_child(_surface)

	# THE LEAF, hinged on the spine.
	#
	# Two quads back to back on one pivot, because a turning page shows a
	# different thing on each side and a single double-sided quad would show the
	# outgoing page mirrored for the whole second half of the sweep - which reads
	# as a rendering fault rather than as paper.
	#
	# The pivot sits on the LEFT edge of the surface, which is where a book's
	# spine is, and turns about the page's own up axis. Both quads are offset half
	# a width along the pivot so they hang off it like a real leaf rather than
	# being impaled through the middle.
	_leaf_size = surface_size
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	# THE SIGN IS MEASURED, NOT REASONED. `surface_at` lays the page flat, and that
	# basis flips local X - so the "obvious" -w/2 put the spine on the RIGHT edge
	# and the sweep swung the leaf DOWN through the floor of the boat, where it
	# was invisible while every number about it looked correct. `probe_leaf.gd`
	# prints the pivot and the leaf against the page; the spine has to sit at a
	# SMALLER book-space x than the page's centre, and the turning leaf has to
	# rise to a LARGER y.
	_leaf_rest = surface_at * Transform3D(Basis.IDENTITY,
		Vector3(surface_size.x * 0.5, 0.0, 0.0))
	_leaf.transform = _leaf_rest
	_leaf.visible = false
	add_child(_leaf)

	# The front face carries no texture: it is the blank reverse of the leaf being
	# lifted, and it is the side the reader watches for the first half of the
	# sweep. PAPER rather than white, so it sits against the page beneath it
	# rather than glowing off it.
	_leaf_front = _leaf_quad(surface_size, 0.0)
	(_leaf_front.material_override as StandardMaterial3D).albedo_color = PAPER
	_leaf.add_child(_leaf_front)
	_leaf_back = _leaf_quad(surface_size, 180.0)
	# The back of the leaf carries the LIVE page - the one being turned to - so
	# as the leaf passes vertical the new page swings up into view on it. The
	# front carries a still of the page being left behind; see `begin_turn`.
	var bm := _leaf_back.material_override as StandardMaterial3D
	bm.albedo_texture = _viewport.get_texture()
	_leaf.add_child(_leaf_back)

	_find_states(_model)


## One side of the leaf: a quad hung off the spine, printed on one face.
func _leaf_quad(size: Vector2, yaw: float) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	q.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The same two settings the page itself needs, and for the same reason: a leaf
	# that depth-tests disappears into the boat halfway through its sweep.
	m.no_depth_test = true
	# ALPHA-SORTED SO THE PRIORITY ACTUALLY APPLIES.
	#
	# `render_priority` orders TRANSPARENT materials only - opaque geometry is
	# sorted by depth and ignores it entirely. With depth testing off on both the
	# page and the leaf, that left the draw order undefined, and the page won: the
	# leaf was present, visible, correctly angled, correctly textured, and drawn
	# underneath the thing it was supposed to be turning over. The turn worked
	# perfectly and could not be seen.
	#
	# The alpha stays at 1. This costs a sort for two quads that are only on
	# screen for a third of a second.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 9          ## above the page it is turning over
	m.cull_mode = BaseMaterial3D.CULL_BACK
	q.material_override = m
	q.rotation_degrees = Vector3(0, yaw, 0)
	# Hung off the pivot rather than centred on it.
	# BOTH FACES HANG THE SAME WAY off the hinge. They are back to back, so they
	# share an offset and differ only in which way they face - giving them
	# opposite offsets put one on each side of the spine, so the page the reader
	# was on swung down through the boat while the new one swung up behind them.
	q.position = Vector3(size.x * -0.5, 0.0, 0.0)
	q.name = "LeafFace"
	return q


## START A PAGE TURNING. `dir` is +1 forward, -1 back.
##
## THE FACE THAT LIFTS TOWARD THE READER IS BLANK PAPER, and that is not a
## shortcut - it is what a page turn looks like. Lift a page off a book and what
## comes up at you is the REVERSE of the leaf you were reading, not its front.
##
## The first version tried to be cleverer: it photographed the page with
## `_viewport.get_texture().get_image()` before refreshing the content, so the
## leaf would carry the words you had just been reading. The readback comes out
## solid black. A SubViewport's texture is not finished at the point a script can
## ask for it, so what arrives is a frame that has not been drawn - and the leaf
## rendered perfectly as a black rectangle sweeping over the book. Chasing that
## through `get_image` would have bought a worse-looking page turn than the
## correct one.
func begin_turn(dir: float) -> void:
	_turn = 1.0
	_turn_dir = signf(dir) if dir != 0.0 else 1.0
	_turn_rang = false
	# BACK TO FLAT, and visible from this frame rather than from the next one.
	# The leaf kept the angle it finished the last turn at, so the second page a
	# reader turned started already lying face down on the other side and swung
	# back through the book. And a leaf that only appears on the next `advance`
	# means the first frame of every turn shows the new page with nothing over it.
	if _leaf != null:
		_leaf.transform = _leaf_rest
		_leaf.visible = _surface != null and _surface.visible


func is_turning() -> bool:
	return _turn > 0.0


## How far through the current turn, 0 to 1. Read by the tests, and by nothing
## else - the leaf positions itself.
func turn_progress() -> float:
	return 1.0 - _turn


## How far the leaf has actually swung, in radians, read off the NODE rather than
## off the counter that drives it. The tests ask this, so a leaf that stops being
## moved fails them even while the turn timer keeps counting down.
func leaf_angle() -> float:
	if _leaf == null:
		return 0.0
	return (_leaf_rest.basis.inverse() * _leaf.transform.basis).get_euler().y


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
	_advance_turn(dt)


## THE LEAF SWEEPS, AND THE LIGHT CATCHES IT.
##
## Eased at both ends rather than linear: a page is lifted, falls over and
## settles, and a leaf turning at one rate reads as a slide transition.
func _advance_turn(dt: float) -> void:
	if _leaf == null:
		return
	if _turn <= 0.0:
		_leaf.visible = false
		return
	_turn = maxf(0.0, _turn - dt / TURN_TIME)
	if _turn <= 0.0:
		# DOWN ON THE SAME FRAME IT FINISHES. Leaving it for the next call left
		# the leaf lying over the page for a frame after the turn was over, which
		# is a flash of the previous page every single time.
		_leaf.visible = false
		_leaf.transform = _leaf_rest
		return
	var k := turn_progress()
	var eased := k * k * (3.0 - 2.0 * k)
	_leaf.visible = _surface != null and _surface.visible
	# Forward turns sweep the leaf up off the right-hand page and over to the
	# left; a turn BACK is the same sweep run the other way.
	#
	# COMPOSED ONTO THE REST TRANSFORM, never assigned through `rotation.y`.
	# `rotation` is the Euler decomposition of the whole basis, so writing one
	# component REBUILDS the basis from (0, y, 0) and throws away the orientation
	# that laid the page flat in the first place. The leaf stood bolt upright in
	# the middle of the boat, twice the size of the book, and the arithmetic for
	# the sweep was correct the whole time.
	var spin := Transform3D(Basis(Vector3.UP, deg_to_rad(180.0 * eased) * _turn_dir),
		Vector3.ZERO)
	_leaf.transform = _leaf_rest * spin

	# THE FLAP LANDS ON VERTICAL, not at the start. That is when a real page is
	# doing the thing that makes the sound, and a sound that arrives before the
	# motion reads as belonging to the button instead of to the paper.
	if not _turn_rang and eased >= 0.5:
		_turn_rang = true
		page_flapped.emit()

	# THE LEAF GOES DARK AS IT LIFTS, and this is what makes the turn visible at
	# all rather than merely correct.
	#
	# It brightened, at first, on the plan's "light catching the paper". Measured
	# against the actual picture that was useless: the page surface is UNSHADED so
	# it is already near white, a leaf 30% brighter than white is white, and the
	# whole animation was a cream page passing over an identical cream page with
	# no edge between them. The geometry was right, the texture was right, and
	# five screenshots in a row looked like nothing was happening.
	#
	# Darkening is both legible and honest: a page lifting off a book turns its
	# face away from the sky, and the underside coming up is in shadow. It gives
	# the sweep a hard edge against the bright page underneath, which is the thing
	# the eye actually tracks.
	var shade := lerpf(1.0, 0.52, sin(eased * PI))
	var fm := _leaf_front.material_override as StandardMaterial3D
	if fm != null:
		fm.albedo_color = Color(PAPER.r * shade, PAPER.g * shade, PAPER.b * shade, 1.0)
	var bm := _leaf_back.material_override as StandardMaterial3D
	if bm != null:
		bm.albedo_color = Color(shade, shade, shade, 1.0)


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
