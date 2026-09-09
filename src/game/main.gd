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
var _gauge: Control
var _cast_area: Control

var _charging := false
var _gauge_grab := -1

## The gauge is the tension band AND the thumb that sets it, in one control.
## Wrecking Crew's crane dial earned this: a control that draws the STATE rather
## than the input lets the player read the gap between what they are asking for
## and what is actually happening, without looking away at a separate gauge.
const GAUGE_W := 132.0
const GAUGE_H := 560.0
const GAUGE_RIGHT := 46.0    ## from the right edge
const GAUGE_BOTTOM := 190.0  ## from the real bottom edge, clear of the gesture bar

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

	# The rod. Points out over the bow; the tip is where the line starts, and
	# that point is shared with _sync so the line cannot leave from somewhere
	# the rod is not.
	# Thin, and out of the middle of the frame. The tip is where the line starts
	# and that point is shared with `_sync`, so the line cannot leave from
	# somewhere the rod is not.
	var rod := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.022, 0.022, 2.3)
	rod.mesh = rm
	rod.material_override = _mat(Color(0.46, 0.33, 0.21), 0.5)
	rod.position = Vector3(0.42, 0.56, 1.30)
	rod.rotation_degrees = Vector3(-14, 0, 9)
	rod.name = "Rod"
	_boat.add_child(rod)

	# The tip, in world space, from the rod's own transform. `transform` rather
	# than `global_transform`: outside the tree the global one does not error, it
	# returns IDENTITY - a plausible wrong answer, which is worse - and the
	# headless harness builds this world before anything is in the tree.
	var half_length: float = rm.size.z * 0.5
	_rod_tip = _boat.transform * (rod.transform * Vector3(0.0, 0.0, half_length))

	_build_reeds()


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

	# Anchored to the real bottom-right corner. PRESET_BOTTOM_RIGHT plus
	# negative offsets puts it a fixed distance from the actual edge at any
	# aspect ratio, which is the whole point.
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_gauge.offset_left = -GAUGE_W - GAUGE_RIGHT
	_gauge.offset_right = -GAUGE_RIGHT
	_gauge.offset_top = -GAUGE_H - GAUGE_BOTTOM
	_gauge.offset_bottom = -GAUGE_BOTTOM
	_gauge.mouse_filter = Control.MOUSE_FILTER_STOP
	_gauge.name = "Gauge"
	_gauge.gui_input.connect(_on_gauge_input)
	_gauge.draw.connect(_draw_gauge)
	_ui.add_child(_gauge)

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


## The gauge draws the state, not the input.
##
## Three things on one track: the safe BAND, the live TENSION, and where the
## thumb is asking for. The gap between the last two is the rod's give, and it
## is the thing a player learns to anticipate. A plain slider would show only
## the input, which is the part they already know.
func _draw_gauge() -> void:
	var w := _gauge.size.x
	var h := _gauge.size.y
	var fighting := sim.state == Sim.FIGHTING

	_gauge.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.06, 0.55))
	_gauge.draw_rect(Rect2(0, 0, w, h), Color(0.85, 0.88, 0.86, 0.22), false, 2.0)

	if not fighting:
		return

	var b := sim.band()
	var lo: float = b[0]
	var hi: float = b[1]
	var y_of := func(v: float) -> float:
		return h - clampf(v / Tuning.TENSION_MAX, 0.0, 1.0) * h

	# The band, drawn from the same numbers the rules use.
	var band_top: float = y_of.call(hi)
	var band_bottom: float = y_of.call(lo)
	var good := sim.in_band()
	var band_col := Color(0.55, 0.85, 0.62, 0.30) if good else Color(0.85, 0.72, 0.35, 0.22)
	_gauge.draw_rect(Rect2(0, band_top, w, band_bottom - band_top), band_col)
	_gauge.draw_line(Vector2(0, band_top), Vector2(w, band_top), Color(0.75, 0.92, 0.78, 0.7), 2.0)
	_gauge.draw_line(Vector2(0, band_bottom), Vector2(w, band_bottom), Color(0.75, 0.92, 0.78, 0.7), 2.0)

	# Tension. The needle, and the only number that matters.
	var ty: float = y_of.call(sim.tension)
	var tc := Color(0.62, 0.95, 0.68) if good else Color(0.95, 0.45, 0.32)
	_gauge.draw_line(Vector2(0, ty), Vector2(w, ty), tc, 6.0)

	# Where the thumb is. Deliberately quieter than the needle: it is the
	# request, and the needle is the answer.
	var py: float = h - clampf(sim.pull, 0.0, 1.0) * h
	_gauge.draw_line(Vector2(w * 0.18, py), Vector2(w * 0.82, py), Color(1, 1, 1, 0.5), 3.0)

	# Damage. Fills from the top for a line about to part, from the bottom for
	# a hook working loose - so which mistake you are making is readable at a
	# glance rather than from a number.
	if sim.stress > 0.0:
		_gauge.draw_rect(Rect2(0, 0, w, h * 0.06 * 1.0), Color(0.95, 0.30, 0.22, sim.stress))
	if sim.slip > 0.0:
		_gauge.draw_rect(Rect2(0, h - h * 0.06, w, h * 0.06), Color(0.95, 0.72, 0.25, sim.slip))


## Absolute, not relative: the thumb's position on the track IS the pull. A
## relative mapping lets the control and the value drift apart, which defeats
## the point of drawing them together.
func _on_gauge_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_gauge_grab = event.index if event is InputEventScreenTouch else 0
			_read_gauge(event.position)
		else:
			_gauge_grab = -1
			sim.set_pull(0.0)
		_gauge.accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _gauge_grab >= 0:
			_read_gauge(event.position)
			_gauge.accept_event()


func _read_gauge(local: Vector2) -> void:
	var h := maxf(1.0, _gauge.size.y)
	sim.set_pull(clampf(1.0 - local.y / h, 0.0, 1.0))


## Hold to cast, tap to strike. One control, and which it does depends on what
## the line is doing - so there is never a button on screen that does nothing.
func _on_cast_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
		released = not event.pressed
	else:
		return

	if pressed:
		match sim.state:
			Sim.BITING, Sim.WAITING, Sim.NIBBLING:
				sim.strike()
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				sim.hold_cast()
				_charging = true
			_:
				pass
	elif released and _charging:
		_charging = false
		sim.release_cast()
	_cast_area.accept_event()


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

	_sync_fish()
	_write_readout()
	_gauge.queue_redraw()


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
			return Vector3(0.0, 0.0, maxf(0.6, sim.fish_distance))
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
