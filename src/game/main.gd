extends Node3D

## The shell. Reads `Sim` and draws it; never decides anything.
##
## The scene file next to this is four lines on purpose - one node with this
## script. Everything visible is built here in code rather than laid out in the
## editor, for two reasons:
##
## 1. A procedural game's world is built at runtime anyway, so an editor layout
##    would be a second source of truth that has to agree with the first.
## 2. It keeps the whole project reviewable as text. A scene tree assembled by
##    clicking is invisible in a diff and cannot be written by anything that
##    does not have the editor open.

## How long a landed fish or a lost one stays on screen before the line is back
## in the boat. Read off the sim rather than duplicated, so the picture and the
## rules cannot disagree about when the moment ends.

var sim: Sim

var _cam: Camera3D
var _water: MeshInstance3D
var _boat: Node3D
## Where the line leaves the rod. DERIVED from the rod's own transform in
## `_build_boat`, never typed twice - a hand-copied tip drifts the moment the
## rod is nudged, and the symptom is a line hanging in the air beside it.
var _rod_tip: Vector3 = Vector3(0.4, 1.0, 2.4)
var _line: MeshInstance3D
var _float: MeshInstance3D
var _fish: Node3D
var _ui: Control
var _readout: Label
var _stamp: Label
var _prompt: Label
var _cast_area: Control
var _rod: MeshInstance3D
var _wake: MeshInstance3D

var _charging := false
var _drag_id := -1
var _drag_from := 0.0
var _drag_pull := 0.0

## THERE IS NO GAUGE, AND THERE MUST NOT BE ONE.
##
## The first fight put the tension band on a control on the right-hand side.
## Gideon's note on 2026-09-09: "I don't like that my thumb will be blocking the
## gauge I am looking at." He is right, and the general form is worth keeping,
## because it is not obvious while building the thing:
##
##   **A readout that must be watched continuously cannot live under the thumb
##   that operates it.** Wrecking Crew's crane dial got away with it because you
##   GLANCE at a dial; a tension meter is read every frame.
##
## Rather than move it, it is gone. The ROD's bend is the tension, the float's
## wake is the fish's bearing, and the thumb drags anywhere on the lower half of
## the screen - a relative drag with no fixed control, so there is nothing on
## screen for a hand to cover. That also makes the instrument the actual object,
## which is what "draw the control as the thing it controls" was reaching for.

## How far the thumb travels for the rod's full range, as a fraction of screen
## height rather than a pixel count, so it feels the same on any phone.
const DRAG_SPAN := 0.28

## How far the rod bends, in degrees, at full load.
const ROD_BEND := 34.0

## Set by the headless harness. When true the frame loop does not step the sim,
## so `advance()` is the only thing moving time and results do not depend on how
## fast the machine boots.
var frozen := false

var _booted := false


func _ready() -> void:
	_ensure_booted()


## Building the world is idempotent and callable before the first frame.
##
## `_ready` does not run at `add_child()` - it is deferred to the first
## processed frame - so a headless harness that adds this node and immediately
## calls `advance()` finds `sim` still null. That cost an hour on another game:
## the symptom was seven hundred identical "Nonexistent function in base 'Nil'"
## errors and a run that never terminated, which reads like an engine problem
## and is really a lifecycle one.
##
## The fix is a guard rather than a rule about call order, because a rule about
## call order is something every future test has to remember.
func _ensure_booted() -> void:
	if _booted:
		return
	_booted = true
	sim = Sim.new(1)
	_build_world()
	_sync()


# --- world ----------------------------------------------------------------

func _build_world() -> void:
	# A real sky, not a background colour.
	#
	# It does three jobs at once, which is what earns it over a flat fill: it
	# lights the scene, it is what the WATER REFLECTS - and water is almost
	# entirely reflection, so with nothing to reflect it renders as a grey sheet
	# - and it is most of what the player is looking at in a portrait frame. The
	# first build used BG_COLOR and the lake read as wet concrete. A Poly Haven
	# HDRI replaces this when the mood arc arrives; the procedural sky is the
	# same three jobs for no bytes.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.44, 0.62)
	sky_mat.sky_horizon_color = Color(0.92, 0.79, 0.60)
	sky_mat.sky_curve = 0.16
	sky_mat.ground_bottom_color = Color(0.22, 0.26, 0.24)
	sky_mat.ground_horizon_color = Color(0.88, 0.76, 0.58)
	sky_mat.sun_angle_max = 6.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 3.0
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.86, 0.80, 0.68)
	e.fog_density = 0.0
	e.fog_depth_begin = 34.0
	e.fog_depth_end = 190.0
	e.fog_depth_curve = 1.4
	# The sky sits at infinity, so depth fog reaches it at full strength and
	# repaints the whole thing in the fog colour. The first build did exactly
	# that and the dawn sky rendered as a flat cream wall - which reads as a
	# missing skybox rather than as fog, and sends you looking at the sky
	# material for a fault that is not in it.
	e.fog_sky_affect = 0.22
	env.environment = e
	add_child(env)

	# Low, and AHEAD of the boat rather than behind it, so the specular path
	# runs sun -> water -> camera and the lake gets its long gold streak. Put
	# the sun behind the player and the water is lit but throws nothing back,
	# which is most of why the first build read as wet concrete.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-11, 8, 0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.86, 0.64)
	sun.name = "Sun"
	add_child(sun)

	_cam = Camera3D.new()
	_cam.fov = 58
	_cam.far = 260
	_cam.name = "Cam"
	add_child(_cam)

	_build_water()
	_build_boat()

	# The line. A thin box stretched between the rod tip and the float each
	# frame - cheaper than a curve and it reads correctly at this distance.
	_line = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, 1.0)
	_line.mesh = lm
	_line.material_override = _mat(Color(0.94, 0.93, 0.88), 0.4)
	_line.name = "Line"
	add_child(_line)

	_float = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.075
	fm.height = 0.24
	_float.mesh = fm
	_float.material_override = _mat(Color(0.86, 0.24, 0.18), 0.55)
	_float.name = "Float"
	add_child(_float)

	_fish = _build_fish()
	add_child(_fish)

	_build_hud()


## The water.
##
## Gerstner waves in the vertex shader, and the depth colour comes from a number
## the SIMULATION owns rather than from DEPTH_TEXTURE. That sample is corrupt on
## Forward Mobile with MSAA enabled, and more importantly the lake bed is
## already ours - it decides where the fish are - so asking the renderer for it
## would be a second source of truth that can disagree with the rules. See
## PIPELINE.md.
func _build_water() -> void:
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	# Enough subdivision for the waves to read near the boat, and no more; the
	# far half of the plane is under fog before it needs any detail.
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	_water.mesh = pm
	_water.name = "Water"

	var sh := Shader.new()
	sh.code = WATER_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("shallow", Color(0.33, 0.46, 0.40))
	m.set_shader_parameter("deep", Color(0.06, 0.13, 0.16))
	m.set_shader_parameter("sky", Color(0.78, 0.84, 0.86))
	m.set_shader_parameter("bed_depth", Tuning.BED_DEPTH)
	_water.material_override = m
	add_child(_water)


const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec4 shallow : source_color;
uniform vec4 deep : source_color;
uniform vec4 sky : source_color;
uniform float bed_depth = 4.0;

varying vec3 world_pos;

// One Gerstner wave. Four summed is enough for a lake: the surface has to
// move and answer, not be photoreal. A water normal map would give it relief
// and leave it just as dead - the wax pools on Candle Gift taught that.
vec3 gerstner(vec2 dir, float steep, float len, float speed, vec2 p, float t) {
	float k = 6.28318 / len;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - c * speed * t);
	float a = steep / k;
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 xz = p.xz;
	float t = TIME;
	vec3 o = vec3(0.0);
	o += gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz, t);
	o += gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz, t);
	o += gerstner(vec2( 0.4,-1.00), 0.07, 1.55, 1.60, xz, t);
	o += gerstner(vec2(-1.0,-0.20), 0.05, 0.85, 2.10, xz, t);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(o, 0.0)).xyz;
	world_pos = p + o;
}

void fragment() {
	// Central differences on the same wave sum, so the normal always agrees
	// with the surface the vertex shader actually built.
	float e = 0.18;
	vec2 xz = world_pos.xz;
	float t = TIME;
	vec3 a = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz + vec2(e,0.0), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz + vec2(e,0.0), t)
	       + gerstner(vec2( 0.4,-1.00), 0.07, 1.55, 1.60, xz + vec2(e,0.0), t)
	       + gerstner(vec2(-1.0,-0.20), 0.05, 0.85, 2.10, xz + vec2(e,0.0), t);
	vec3 b = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz - vec2(e,0.0), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz - vec2(e,0.0), t)
	       + gerstner(vec2( 0.4,-1.00), 0.07, 1.55, 1.60, xz - vec2(e,0.0), t)
	       + gerstner(vec2(-1.0,-0.20), 0.05, 0.85, 2.10, xz - vec2(e,0.0), t);
	vec3 c = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz + vec2(0.0,e), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz + vec2(0.0,e), t)
	       + gerstner(vec2( 0.4,-1.00), 0.07, 1.55, 1.60, xz + vec2(0.0,e), t)
	       + gerstner(vec2(-1.0,-0.20), 0.05, 0.85, 2.10, xz + vec2(0.0,e), t);
	vec3 d = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz - vec2(0.0,e), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz - vec2(0.0,e), t)
	       + gerstner(vec2( 0.4,-1.00), 0.07, 1.55, 1.60, xz - vec2(0.0,e), t)
	       + gerstner(vec2(-1.0,-0.20), 0.05, 0.85, 2.10, xz - vec2(0.0,e), t);
	vec3 tx = vec3(2.0 * e + a.x - b.x, a.y - b.y, a.z - b.z);
	vec3 tz = vec3(c.x - d.x, c.y - d.y, 2.0 * e + c.z - d.z);
	vec3 n = normalize(cross(tz, tx));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	// Analytic depth. The bed is flat at M1; when it becomes a heightfield the
	// sim uploads the same field it uses for the fish and this samples that.
	float depth_here = bed_depth;
	float murk = clamp(depth_here / bed_depth, 0.0, 1.0);
	vec3 body = mix(shallow.rgb, deep.rgb, murk);

	// Fresnel. Water is almost entirely reflection at a grazing angle, which
	// is what makes a lake read as a lake rather than as a coloured floor.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(body, sky.rgb, clamp(fres, 0.0, 0.82));
	ROUGHNESS = mix(0.06, 0.22, murk);
	METALLIC = 0.0;
	SPECULAR = 0.85;
}
"""


## The boat, the rod, and the reeds. Boxes for now: this milestone is about
## whether the fight feels good, and nothing here is what the player is looking
## at while they find out.
func _build_boat() -> void:
	_boat = Node3D.new()
	_boat.name = "Boat"
	add_child(_boat)

	# The bow only, and mostly below the frame. The first build put a 3.2 m hull
	# under a camera sitting in it, and the bottom third of a portrait screen
	# became a featureless brown slab - which is what a deck looks like from a
	# seat, and is not worth a third of the picture. What earns its place is the
	# bow pointing at the water the player is about to cast into.
	# Two rails and a bow point, not a deck.
	#
	# The first two builds drew the hull as a solid box under a camera sitting
	# in it, and its lit top face became the brightest object on screen and a
	# third of a portrait frame - a picture of a plank. What a person in a boat
	# actually sees is the gunwale running away on both sides and converging at
	# the bow, with water between them. Same read, three thin meshes, and it
	# frames the water instead of covering it.
	var rail_col := Color(0.34, 0.25, 0.17)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm2 := BoxMesh.new()
		rm2.size = Vector3(0.12, 0.17, 2.4)
		rail.mesh = rm2
		rail.material_override = _mat(rail_col, 0.7)
		rail.position = Vector3(side * 0.60, 0.20, 1.05)
		rail.rotation_degrees = Vector3(0, side * -5.5, 0)
		_boat.add_child(rail)

	# No bow block. One stood here for a build and it read as a floating crate
	# rather than as part of the boat - and worse, at a short cast it sat exactly
	# in front of the float, hiding the one object the player is watching. A prop
	# that occludes the thing the game is about is a bug, not a look.

	# The thwart the player is sitting behind. One edge across the bottom of the
	# frame, which is all the "you are in a boat" the picture needs.
	var thwart := MeshInstance3D.new()
	var tm2 := BoxMesh.new()
	tm2.size = Vector3(1.30, 0.10, 0.30)
	thwart.mesh = tm2
	thwart.material_override = _mat(Color(0.42, 0.32, 0.21), 0.65)
	thwart.position = Vector3(0.0, 0.14, -0.25)
	_boat.add_child(thwart)

	_build_rod()

	_update_rod_tip()

	# The fish's wake. A thin slab on the surface that points where the fish is
	# bearing, and the only thing on screen that tells the player a run has
	# started - which is deliberate. It appears during the TELL, before the run
	# does, so a player who is watching the water gets their warning from the
	# water rather than from a number.
	_wake = MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.10, 0.02, 1.4)
	_wake.mesh = wm
	var wmat := _mat(Color(0.95, 0.96, 0.94), 0.25)
	wmat.emission_enabled = true
	wmat.emission = Color(0.85, 0.90, 0.92)
	wmat.emission_energy_multiplier = 0.5
	_wake.material_override = wmat
	_wake.visible = false
	_wake.name = "Wake"
	add_child(_wake)

	_build_reeds()


## The rod, as a chain of segments that BENDS rather than a stick that tilts.
##
## Worth the extra four meshes, because the rod is the only instrument in the
## game now and it has to be readable at a glance. A single box rotated by the
## load reads as "the rod tilted" - the same silhouette, moved - and a player
## cannot tell 40% load from 60% that way. A chain whose segments each take a
## share of the angle, weighted toward the tip, reads as a rod under strain the
## way a real one looks: straight at the butt, curving hard at the last third.
##
## The weights are what make it look right. An even share bends it into an arc
## of a circle, which reads as a bow rather than a rod.
const ROD_SEGMENTS := 5
const ROD_CURVE := [0.05, 0.12, 0.20, 0.28, 0.35]  ## share of the bend, butt to tip
const ROD_SEG_LENGTH := 0.46

var _rod_chain: Array[Node3D] = []


func _build_rod() -> void:
	var parent: Node3D = _boat
	for i in ROD_SEGMENTS:
		var seg := MeshInstance3D.new()
		var m := BoxMesh.new()
		# Tapered, so the tip is visibly whippier than the butt.
		var thick := lerpf(0.030, 0.012, float(i) / float(ROD_SEGMENTS - 1))
		m.size = Vector3(thick, thick, ROD_SEG_LENGTH)
		seg.mesh = m
		seg.material_override = _mat(Color(0.46, 0.33, 0.21), 0.5)
		if i == 0:
			seg.position = Vector3(0.42, 0.56, 1.30)
			seg.rotation_degrees = Vector3(-14, 0, 9)
			_rod = seg
			seg.name = "Rod"
		else:
			seg.position = Vector3(0.0, 0.0, ROD_SEG_LENGTH)
			seg.name = "RodSeg%d" % i
		parent.add_child(seg)
		_rod_chain.append(seg)
		parent = seg


## Total bend across the whole rod, in degrees. The quantity the smoke test
## checks against `sim.load`, because the first segment's own rotation is only
## a twentieth of it and asserting on that would be asserting about the chain
## rather than about the instrument.
func rod_bend_degrees() -> float:
	var total := 0.0
	for i in _rod_chain.size():
		var seg := _rod_chain[i]
		total += absf(seg.rotation_degrees.x - (-14.0 if i == 0 else 0.0))
	return total


## The rod tip, in world space, from the rod's own transform.
##
## Recomputed whenever the rod bends, never typed twice - a hand-copied tip
## drifts the moment the rod moves, and the symptom is a line hanging in the air
## beside it. `transform` rather than `global_transform`: outside the tree the
## global one does not error, it returns IDENTITY, which is a plausible wrong
## answer and therefore worse. The headless harness builds this world before
## anything is in the tree.
func _update_rod_tip() -> void:
	# Walk the chain in local space and compose. `transform` rather than
	# `global_transform` throughout, because outside the tree the global one
	# returns IDENTITY instead of erroring - a plausible wrong answer - and the
	# headless harness builds this world before anything is in the tree.
	var t := _boat.transform
	for seg in _rod_chain:
		t = t * seg.transform
	_rod_tip = t * Vector3(0.0, 0.0, ROD_SEG_LENGTH * 0.5)


## Reeds, laid out for the aspect ratio the game actually has.
##
## Portrait at a 58 degree VERTICAL field is only about 28 degrees horizontal,
## so at ten metres out the visible width is roughly five metres total. The
## first build scattered reeds between five and ten metres either side of the
## boat and every one of them was off the edge of the screen - the lake read as
## an empty grey plane because its only landmarks were outside the frame.
##
## The fix is not to move them closer, which would put weeds around a boat in
## open water. It is to place them where the cone actually widens: far enough
## ahead that the frame has spread to reach them.
func _build_reeds() -> void:
	for i in 54:
		var reed := MeshInstance3D.new()
		var rr := BoxMesh.new()
		var h := 0.9 + SimUtil.hash2(i, 3) * 1.5
		rr.size = Vector3(0.045, h, 0.045)
		reed.mesh = rr
		reed.material_override = _mat(Color(0.31, 0.35, 0.17), 0.92)
		var side := -1.0 if i % 2 == 0 else 1.0
		# The bank sits well down the lake and spreads outward with distance, so
		# it stays inside the horizontal cone the whole way.
		var z := 17.0 + SimUtil.hash2(i, 17) * 30.0
		var spread := 1.6 + z * 0.17
		reed.position = Vector3(
			side * (spread + SimUtil.hash2(i, 11) * 4.5),
			h * 0.5 - 0.30,
			z
		)
		reed.rotation_degrees = Vector3(
			SimUtil.hash2(i, 23) * 14.0 - 7.0, 0, SimUtil.hash2(i, 29) * 12.0 - 6.0
		)
		add_child(reed)


## A fish, assembled rather than imported.
##
## Two rules point the same way and close this question. A fish is thirty pixels
## tall while it is swimming and is read as a silhouette; and - decisively - the
## shape of a fish is gameplay state, so it must be code. A Thin Perch is a
## perch with a wrong length and a Second Line is one more stripe, which is a
## data structure being drawn rather than a mesh with a skin.
##
## At M1 this is the landing shot only, which is the one place the asset rule's
## exception applies: stationary, close to the camera, looked at while nothing
## else is happening. The real generator - spine, swept rib profile, fin set -
## arrives with the second water.
func _build_fish() -> Node3D:
	var f := Node3D.new()
	f.name = "Fish"
	f.visible = false

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	bm.radial_segments = 20
	bm.rings = 12
	body.mesh = bm
	body.scale = Vector3(0.42, 0.78, 1.0)
	body.name = "Body"
	f.add_child(body)

	var tail := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.06, 0.62, 0.52)
	tail.mesh = tm
	tail.position = Vector3(0, 0, -0.62)
	tail.rotation_degrees = Vector3(0, 0, 90)
	tail.name = "Tail"
	f.add_child(tail)

	var dorsal := MeshInstance3D.new()
	var dm := PrismMesh.new()
	dm.size = Vector3(0.04, 0.30, 0.62)
	dorsal.mesh = dm
	dorsal.position = Vector3(0, 0.36, 0.02)
	dorsal.name = "Dorsal"
	f.add_child(dorsal)

	return f


# --- HUD ------------------------------------------------------------------

## Nothing here may be positioned against a literal screen size.
##
## The project stretches with `aspect = "expand"`, which keeps the base WIDTH
## and extends the HEIGHT - so on a 19.5:9 phone the canvas is about 1080x2340
## while the base is 1080x1920. Controls laid out against the literal 1920 drew
## hundreds of pixels above where they belonged, and the report on a sibling
## game was "the icons are about half an inch too high".
##
## Everything anchors to a full-rect Control, and every interactive control
## owns its own input through `_gui_input`, so its hit box and its drawing are
## the same object and cannot drift apart.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.name = "Ui"
	layer.add_child(_ui)

	# The cast area sits UNDER the gauge in the child order, so the gauge takes
	# the touches inside its own rectangle and this takes everything else. One
	# gesture drives one thing.
	_cast_area = Control.new()
	_cast_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cast_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_cast_area.name = "CastArea"
	_cast_area.gui_input.connect(_on_cast_input)
	_ui.add_child(_cast_area)

	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_readout.offset_left = 44
	_readout.offset_top = 54
	_readout.add_theme_font_size_override("font_size", 34)
	_readout.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_readout.add_theme_constant_override("outline_size", 8)
	_readout.name = "Readout"
	_ui.add_child(_readout)

	# Centred on the horizon rather than the whole screen, so it sits in the
	# picture instead of over the controls.
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = 320
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 44)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.name = "Prompt"
	_ui.add_child(_prompt)

	# On screen rather than behind a menu: the first thing to verify on a phone
	# is that the build you are holding is the build you just made.
	_stamp = Label.new()
	_stamp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stamp.offset_left = 44
	_stamp.offset_top = -54
	_stamp.offset_bottom = -18
	_stamp.add_theme_font_size_override("font_size", 20)
	_stamp.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_stamp.name = "Stamp"
	_ui.add_child(_stamp)


## One touch surface, and what it does depends on what the line is doing - so
## there is never a control on screen that does nothing, and never a control on
## screen at all.
##
##   Idle      hold to load the rod, release to cast
##   Waiting   tap to strike
##   Fighting  drag up to load the rod, down to give line
##
## The fight drag is RELATIVE to where the thumb went down, not absolute. That is
## the opposite of the rule the old gauge followed, and deliberately so: an
## absolute mapping needs a fixed track, a fixed track has to be drawn, and
## anything drawn is something a thumb can cover. Relative means the player can
## grab anywhere - including the far edge of the screen, away from the rod - and
## still have the full range under their thumb.
func _on_cast_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _drag_id >= 0 and sim.state == Sim.FIGHTING:
			_read_drag(event.position.y)
			_cast_area.accept_event()
		return

	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
	else:
		return

	if pressed:
		match sim.state:
			Sim.FIGHTING:
				_drag_id = event.index if event is InputEventScreenTouch else 0
				_drag_from = event.position.y
				_drag_pull = sim.pull
			Sim.BITING, Sim.WAITING, Sim.NIBBLING:
				sim.strike()
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				sim.hold_cast()
				_charging = true
			_:
				pass
	else:
		if _drag_id >= 0:
			_drag_id = -1
			# Letting go drops the rod, which is what a hand coming off a rod
			# does - and it means "give line NOW" is always one release away.
			# That matters, because giving line is the correct answer to the
			# fastest-failing thing in the game.
			sim.set_pull(0.0)
		if _charging:
			_charging = false
			sim.release_cast()
	_cast_area.accept_event()


func _read_drag(y: float) -> void:
	var h := maxf(1.0, _cast_area.size.y)
	# Up the screen is up the rod, so the sign is inverted.
	var moved := (_drag_from - y) / (h * DRAG_SPAN)
	sim.set_pull(clampf(_drag_pull + moved, 0.0, 1.0))


func _mat(c: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


# --- loop -----------------------------------------------------------------

func _process(delta: float) -> void:
	if frozen:
		return
	_tick(delta)


func _tick(dt: float) -> void:
	sim.advance(dt)
	_sync()


## The headless seam.
##
## `_process` computes a delta and calls `_tick`; this steps `_tick` at a fixed
## delta instead. A whole session compresses into one call, deterministically
## and far faster than real time, with no window open.
##
## Freeze first. Real frames run between the scene loading and a harness taking
## over, and how many depends on how fast the machine starts - which quietly
## makes every recorded number a function of the test runner's speed.
func advance(seconds: float, step: float = 1.0 / 60.0) -> void:
	_ensure_booted()
	var n := maxi(1, int(round(seconds / step)))
	for i in n:
		_tick(step)


func freeze(seed_value: int = 1) -> void:
	_ensure_booted()
	frozen = true
	sim.restart(seed_value)
	_sync()


## Drive the sim the way a thumb would, from a harness. Exists so the smoke test
## plays through the real input seam rather than reaching into Sim behind the
## renderer's back - a helper that computes its own inputs is a second, usually
## worse player.
func play(name: String, seconds: float, step: float = 1.0 / 60.0) -> void:
	_ensure_booted()
	var n := maxi(1, int(round(seconds / step)))
	for i in n:
		Policies.act(name, sim, step)
		_tick(step)


# --- drawing --------------------------------------------------------------

func _sync() -> void:
	_sync_rod()
	var out := _lure_position()

	# Transform3D.looking_at rather than Node3D.look_at. The node method
	# requires the node to be inside the tree and errors if it is not - which is
	# exactly the headless case, because add_child() during
	# SceneTree._initialize() does not put anything in the tree until the first
	# frame. This is pure maths and works anywhere.
	# Seated in the stern, looking out over the bow. High enough that the deck is
	# a foreground edge rather than a third of the picture, and aimed so the
	# horizon sits in the upper third - the water is the subject, and in portrait
	# there is not room for both a lot of sky and a lot of hull.
	var eye := Vector3(0.0, 1.16, -1.55)
	var focus := Vector3(0.0, 0.16, maxf(9.0, out.z * 0.62))
	_cam.transform = Transform3D(Basis.IDENTITY, eye).looking_at(focus, Vector3.UP)

	_float.position = out
	_float.visible = sim.state != Sim.IDLE and sim.state != Sim.CHARGING and sim.state != Sim.HOLDING

	_draw_line_between(_rod_tip, out)
	_line.visible = _float.visible

	_sync_wake(out)
	_sync_fish()
	_write_readout()


## The rod IS the tension gauge.
##
## Its bend is `sim.load`, straight through, so what the player reads off the
## picture and what the rules are scoring are the same number - not two numbers
## kept in sync. The old HUD gauge showed exactly this and was covered by the
## thumb that set it; a bent rod is in the upper half of the frame where nothing
## is touching.
func _sync_rod() -> void:
	if _rod == null:
		return
	var bend := 0.0
	if sim.state == Sim.FIGHTING:
		bend = sim.load
	elif sim.state == Sim.CHARGING:
		bend = sim.charge * 0.55
	# A rod under strain also shivers. Cosmetic, so `randf` would be legal here -
	# but it is keyed on the sim's own clock instead so two screenshots of the
	# same second are identical, which is what makes them comparable at all.
	var shiver := 0.0
	if sim.state == Sim.FIGHTING and sim.danger() > 0.35:
		shiver = sin(sim.time * 47.0) * (sim.danger() - 0.35) * 2.2

	var total := bend * ROD_BEND + shiver
	for i in _rod_chain.size():
		var share: float = ROD_CURVE[i] * total
		if i == 0:
			_rod_chain[i].rotation_degrees = Vector3(-14.0 - share, 0.0, 9.0)
		else:
			_rod_chain[i].rotation_degrees = Vector3(-share, 0.0, 0.0)
	_update_rod_tip()


## The fish's bearing, on the water.
##
## This is the tell, and it is the only warning a run gives. It appears DURING
## the tell window - before the run starts - so a player watching the water can
## drop the rod in time and take no damage at all. A player watching a number
## reacts after the run has begun and pays for it. That difference is the whole
## premise of the second fight, and `test_golden.gd` asserts a bot that ignores
## it does measurably worse than one that does not.
func _sync_wake(lure: Vector3) -> void:
	if _wake == null:
		return
	var showing := sim.state == Sim.FIGHTING and (
		sim.behaviour == Sim.B_RUNNING
		or (sim.tell > 0.0 and sim.next_behaviour == Sim.B_RUNNING)
	)
	_wake.visible = showing
	if not showing:
		return
	# Which way it bears is decided per fish, not per frame, so the wake does not
	# flicker side to side. Keyed on the fight's own start time.
	var side := 1.0 if SimUtil.hash2(int(sim.fight_time * 0.0) + sim.pumps, 71) > 0.5 else -1.0
	var lead := 1.0 if sim.tell > 0.0 else 1.9
	_wake.position = Vector3(lure.x + side * 0.55, 0.03, lure.z + 0.2)
	_wake.rotation_degrees = Vector3(0.0, side * 34.0, 0.0)
	_wake.scale = Vector3(1.0, 1.0, lead)


## Where the lure is, in world space. One function so the float, the line and
## anything that later cares about the splash all agree.
func _lure_position() -> Vector3:
	match sim.state:
		Sim.IDLE, Sim.CHARGING, Sim.HOLDING:
			return _rod_tip
		Sim.FLYING:
			# An arc, purely for the look: the sim owns the flight TIME, and
			# this owns where it appears to be during it.
			var total := maxf(0.001, Tuning.cast_flight_seconds(sim.charge))
			var k := clampf(sim.state_time / total, 0.0, 1.0)
			var z := lerpf(_rod_tip.z, sim.cast_distance, k)
			var y := lerpf(_rod_tip.y, 0.0, k) + sin(k * PI) * (1.4 + sim.cast_distance * 0.10)
			return Vector3(0.0, y, z)
		Sim.FIGHTING:
			# The float carries the three behaviours, because it is the only
			# thing on the water and the player is already looking at it.
			#
			#   holding    it sits, pulled under by the load on the rod
			#   running    it shears sideways and skates
			#   surfacing  it thrashes - fast, wide, and out of the water
			#
			# All three keyed on the sim's clock rather than randf, so the same
			# second of the same fight draws identically every time and two
			# screenshots a week apart are comparable.
			var z := maxf(0.6, sim.fish_distance)
			var t := sim.fight_time
			match sim.behaviour:
				Sim.B_SURFACING:
					return Vector3(
						sin(t * 21.0) * 0.42,
						0.10 + absf(sin(t * 17.0)) * 0.16,
						z + cos(t * 15.0) * 0.22
					)
				Sim.B_RUNNING:
					return Vector3(sin(t * 2.1) * 0.9, -0.02, z)
				_:
					# Pulled under by however hard the rod is bent. A slack line
					# lets it sit up; a hard pump drags it down and forward.
					return Vector3(0.0, -sim.load * 0.14, z)
		_:
			return Vector3(0.0, 0.0, sim.cast_distance)


func _draw_line_between(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	if len < 0.001:
		_line.visible = false
		return
	_line.transform = Transform3D(Basis.IDENTITY, mid).looking_at(b, Vector3.UP)
	_line.scale = Vector3(1.0, 1.0, len)


func _sync_fish() -> void:
	var showing := sim.state == Sim.HOLDING
	_fish.visible = showing
	if not showing:
		return
	var row := Species.by_id(sim.fish_id)
	if row.is_empty():
		return
	# Size read off the actual weight, so a big one looks big. The cube root is
	# what makes mass look like length rather than making a 3 kg bass three
	# times the length of a 1 kg one.
	var lo: float = row["weight_lo"]
	var span: float = maxf(0.001, float(row["weight_hi"]) - lo)
	var k := clampf((sim.fish_weight - lo) / span, 0.0, 1.0)
	var scale := 0.20 + 0.26 * pow(clampf(sim.fish_weight / 3.0, 0.05, 1.0), 1.0 / 3.0) + k * 0.06
	_fish.scale = Vector3.ONE * scale
	# Held up out of the water in front of the camera, turning slowly, with a
	# little life left in it.
	var t := sim.state_time
	_fish.position = Vector3(0.10, 1.05 + sin(t * 2.4) * 0.02, 1.15)
	_fish.rotation = Vector3(sin(t * 3.1) * 0.10, 1.45 + sin(t * 0.9) * 0.28, sin(t * 4.3) * 0.07)
	var tint := _fish_colour(sim.fish_id)
	for child in _fish.get_children():
		(child as MeshInstance3D).material_override = _mat(tint, 0.35)


func _fish_colour(id: String) -> Color:
	match id:
		"bluegill":
			return Color(0.36, 0.48, 0.34)
		"perch":
			return Color(0.72, 0.58, 0.20)
		"bass":
			return Color(0.30, 0.40, 0.26)
		_:
			return Color(0.55, 0.58, 0.55)


## What the player is told, in the words the rules use.
##
## "the line broke" and "it threw the hook" are different mistakes, and a player
## who cannot tell them apart cannot correct either. The strings come off Sim so
## the message and the cause cannot disagree.
func _write_readout() -> void:
	var line := ""
	match sim.state:
		Sim.IDLE:
			line = "HOLD TO CAST"
		Sim.CHARGING:
			line = "%.0f m" % Tuning.cast_distance(sim.charge)
		Sim.FLYING, Sim.SINKING:
			line = ""
		Sim.WAITING:
			line = ""
		Sim.NIBBLING:
			line = "..."
		Sim.BITING:
			line = "NOW"
		Sim.FIGHTING:
			# Distance only. No behaviour name, no tension number, no "GIVE
			# LINE!" prompt - the water is saying all of that, and a caption
			# that says it too means the player reads the caption forever and
			# never learns to read the water. This is the one restraint the
			# whole mechanic depends on.
			line = "%.1f m" % sim.fish_distance
		Sim.HOLDING:
			var row := Species.by_id(sim.fish_id)
			var nm: String = row["name"] if not row.is_empty() else "?"
			line = "%s   %.2f kg" % [nm, sim.fish_weight]
		Sim.LOST:
			line = ""
	_prompt.text = line

	_readout.text = "CAUGHT %d   LOST %d\n%.2f kg" % [sim.caught, sim.lost_count, sim.total_weight]
	_stamp.text = BuildStamp.line()
