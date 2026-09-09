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
var _tension_bar: Control
var _menus: Menus
var _dock: HBoxContainer
var _world_line: Label
var _audio: Audio
var _env: Environment
var _sun: DirectionalLight3D
var _water_mat: ShaderMaterial
var _dread := 0.0
var _sky_mat: ShaderMaterial
var _sky_a := "dawn"
var _sky_b := "dawn"
var _sky_blend := 0.0
var _sky_grey := 0.0
var _sky_dark := 0.0
var _sky_tint := Color(1, 1, 1)
var _sky_cloud := 0.0
var _fish_shown := ""
var _grade: ColorRect
var _rain: GPUParticles3D
var _mist: GPUParticles3D
var _reeds: Node3D
var _save_due := 0.0
var _sounder: Control

var _charging := false

## THE GAUGES LIVE AT THE TOP. THE THUMB LIVES AT THE BOTTOM.
##
## Two notes from Gideon, one round apart, and the resolution is the split above.
##
## On the first fight: "I don't like that my thumb will be blocking the gauge I
## am looking at." Correct, and the general form is worth keeping - **a readout
## that must be watched continuously cannot live under the thumb that operates
## it.** Wrecking Crew's crane dial got away with exactly that arrangement
## because you GLANCE at a dial; a tension meter is read every frame.
##
## On the second: "it is not very intuitive to tell what you are supposed to
## do... I think having visual on screen queues or gauges would be a good
## addition." Also correct, and it says the previous fix was an over-correction:
## deleting the gauge was never the answer to a gauge being in the wrong place.
##
## So the gauge is back, at the TOP, and the input is a tap anywhere. A tap needs
## no precision of position at all, which is the property that lets the two live
## at opposite ends of the screen - and it is why the input had to become a tap
## before the gauge could come back.
##
## Only the REEL has a gauge. Minigame 1 is the float being pulled under, in the
## world, with no HUD at all - which is the third note: "just watching the rod or
## bobber pull down... make it look like a fish is nibbling on the bait".
const BAR_W := 0.62           ## fraction of screen width
const GAUGE_TOP := 235.0      ## tension gauge, from the top edge
const GAUGE_H := 42.0

## How far the float is pulled under at a full take, in metres. Deep enough that
## a tease and a take are obviously different depths at cast range.
const FLOAT_DIP := 0.34

## How far the rod bends forward under load, in degrees.
const ROD_BEND := 40.0

## The cast, which is a ROTATION and not a bend.
##
## Gideon: "the rod bends back then flicks forward which isnt how it should work.
## the rod should be straight initially lift the rod up and back, then swing it
## forward. once the fish bites, the rod should bend forward since it is now
## under pressure."
##
## Exactly right, and the bug was that one number drove both: `charge` was fed
## into the same bend the fight uses, so loading a cast curved the rod like a
## fish was on it. They are different motions and now they are different code -
## the whole rod ROTATES back to load a cast and swings forward to release it,
## and only a hooked fish BENDS it.
## The rod at rest, and the two ends of the cast, as ABSOLUTE angles - so "still
## angled up" is a number you can read rather than the result of an arithmetic.
## All three are negative because negative is up; see the sign note in _sync_rod.
const ROD_REST := -14.0       ## tip a little up, holding the rod out
const CAST_BACK := 62.0       ## degrees lifted BEHIND rest at full charge
const CAST_THROW_TO := -6.0   ## where the throw stops. ABOVE horizontal, on purpose
const CAST_SWING_TIME := 0.20 ## seconds of forward swing

## How much taller than life the sounder draws whatever is standing on the bed.
## See the note in `_draw_sounder`: a real sounder exaggerates for exactly this
## reason, and the steeple has to be a STEEPLE on a phone screen.
const SOUNDER_RELIEF := 2.4

## EXPOSURE, and why it needed a constant of its own.
##
## The procedural sky was dim, so `Mood`'s sun energies were tuned against
## essentially one light source. A Poly Haven HDRI is real-world luminance and
## lights the scene as well, so the same numbers arrive roughly twice as hot -
## the first frame with a real sky in it had the lake as a sheet of pure white.
##
## Scaled HERE rather than in `Mood`, because Mood's numbers are asserted against
## each other (night darker than noon, and so on) and those relations are still
## right. This is the one global multiplier that turns them into an exposure.
const SUN_SCALE := 0.42
const AMBIENT_SCALE := 0.30
const SKY_ENERGY := 0.55

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
	var sky_mat := _build_sky_material()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.background_energy_multiplier = SKY_ENERGY
	# More headroom before white. Filmic at 3.0 was clipping the specular streak
	# into a flat blown shape the moment a real sky was reflecting in it.
	e.tonemap_exposure = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
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
	_env = e
	_sky_mat = sky_mat

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
	_sun = sun

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

	_build_weather()
	_build_grade()
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
	pm.size = Vector2(220, 220)
	# **Sized by the QUAD, not by the plane.** 300 m across 128 subdivisions is a
	# 2.3 m quad, and the ones within five metres of the camera are most of the
	# bottom of a portrait frame - the vertex-displaced surface came out as
	# visible flat plates the moment the water had enough specular to show them.
	# 256 puts it at 1.17 m, which reads. 66k vertices, and on this phone
	# neither vertices nor draw calls are a constraint - see PIPELINE.md.
	pm.subdivide_width = 384
	pm.subdivide_depth = 384
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
	m.set_shader_parameter("gloss", 1.0)
	m.set_shader_parameter("beam", 1.0)
	m.set_shader_parameter("ripple", 1.0)
	_water.material_override = m
	_water_mat = m
	add_child(_water)


const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec4 shallow : source_color;
uniform vec4 deep : source_color;
uniform vec4 sky : source_color;
uniform float bed_depth = 4.0;
// How glassy the surface is, 1 for a flat calm and 0 for a storm. A tight
// highlight on a DIM light is the worst of both: at night the specular came out
// as hard blue-white blobs on near-black water, which reads as a bug rather than
// as moonlight. Rough water spreads the same energy over a wider, softer streak,
// which is both what a choppy lake does and what makes a dark scene legible.
uniform float gloss = 1.0;
// How much DIRECT sun there is to make a streak out of. See the note on `spec`
// in mood.gd: this is the difference between a storm and a sunset.
uniform float beam = 1.0;
// How hard the fine ripple bites. Rises with the weather's chop.
uniform float ripple = 1.0;

varying vec3 world_pos;

// --- fine detail ----------------------------------------------------------
//
// The four Gerstner waves give the lake its SWELL, and in bright side light
// that was enough. In flat light - overcast, rain, fog, most of the second half
// of this game - a swell with no fine structure has nothing to catch, and the
// water rendered as a dark sheet with a horizon on it.
//
// So: three octaves of cheap value noise, scrolling on different headings, used
// only to perturb the NORMAL. It costs no vertices and no texture, it tiles
// forever because it is arithmetic, and it is the difference between water and
// a painted floor at every hour that is not sunrise.
float hashn(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hashn(i);
	float b = hashn(i + vec2(1.0, 0.0));
	float c = hashn(i + vec2(0.0, 1.0));
	float d = hashn(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Each octave is ROTATED as well as scaled. Value noise is built on an
// axis-aligned integer lattice, and stacking octaves that all share that lattice
// leaves the grid visible - the close water came out in square patches, which on
// a lake reads as a broken shader rather than as chop. Irrational-ish angles so
// the lattices never come back into alignment.
const mat2 ROT1 = mat2(vec2(0.8776, -0.4794), vec2(0.4794, 0.8776));
const mat2 ROT2 = mat2(vec2(0.5403, -0.8415), vec2(0.8415, 0.5403));

float ripple_height(vec2 p, float t) {
	float h = 0.0;
	// Frequencies are in CYCLES PER METRE, and the first version's base octave was
	// 1.7 - a 59 cm cell. At a grazing view from a camera a metre above the water
	// one of those cells covers a third of the screen, and the value-noise lattice
	// showed as flat rectangular plates. Ripples are five to twenty centimetres,
	// so that is what these are.
	h += vnoise(p * 6.5 + vec2(t * 0.35, t * 0.12)) * 0.55;
	h += vnoise(ROT1 * p * 15.0 - vec2(t * 0.22, t * 0.41)) * 0.30;
	h += vnoise(ROT2 * p * 33.0 + vec2(t * 0.61, -t * 0.28)) * 0.15;
	return h;
}

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
	// **Only the LONG swells are displaced.** The 1.55 m and 0.85 m waves used to
	// be here too, and on a 1.17 m quad they are below Nyquist - a wave shorter
	// than two samples cannot be represented and aliases into flat plates, which
	// is exactly what the near water came out as once it had enough specular to
	// show them. Displace what the mesh can carry; the short chop is the
	// fragment ripple's job, which is where it belongs anyway.
	o += gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz, t);
	o += gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz, t);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(o, 0.0)).xyz;
	world_pos = p + o;
}

void fragment() {
	// Central differences on the same wave sum, so the normal always agrees
	// with the surface the vertex shader actually built.
	float e = 0.18;
	vec2 xz = world_pos.xz;
	float t = TIME;
	// The SAME two waves the vertex shader displaced, so the normal always agrees
	// with the surface actually built. Four here against two there would light a
	// surface that does not exist.
	vec3 a = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz + vec2(e,0.0), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz + vec2(e,0.0), t);
	vec3 b = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz - vec2(e,0.0), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz - vec2(e,0.0), t);
	vec3 c = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz + vec2(0.0,e), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz + vec2(0.0,e), t);
	vec3 d = gerstner(vec2( 1.0, 0.35), 0.14, 5.10, 1.00, xz - vec2(0.0,e), t)
	       + gerstner(vec2(-0.7, 0.90), 0.10, 2.90, 1.25, xz - vec2(0.0,e), t);
	vec3 tx = vec3(2.0 * e + a.x - b.x, a.y - b.y, a.z - b.z);
	vec3 tz = vec3(c.x - d.x, c.y - d.y, 2.0 * e + c.z - d.z);
	vec3 n = normalize(cross(tz, tx));

	// Fine ripple on top of the swell, and FADED WITH DISTANCE - past about forty
	// metres a centimetre of chop is far below a pixel and all it can do is alias
	// into a shimmer that reads as a broken shader.
	//
	// `VERTEX` is already in VIEW space here, so its length IS the distance from
	// the camera. The first version subtracted the world position from it, which
	// evaluated to roughly zero everywhere - the fade did nothing and, worse, it
	// looked like it was working.
	float dist = length(VERTEX);
	float near = clamp(1.0 - dist / 40.0, 0.0, 1.0);
	if (near > 0.01) {
		float re = 0.06;
		float t2 = TIME;
		float hx = ripple_height(xz + vec2(re, 0.0), t2) - ripple_height(xz - vec2(re, 0.0), t2);
		float hz = ripple_height(xz + vec2(0.0, re), t2) - ripple_height(xz - vec2(0.0, re), t2);
		// The SLOPE has to be steep to read. A gentle perturbation of an already
		// near-vertical normal is no perturbation: the first attempt divided by
		// the sample width and produced a vector within a degree of straight up,
		// which is exactly the flat sheet it was meant to fix.
		// NOT eased off in the near field. It was, briefly, to hide the noise
		// lattice - and once the ripple moved to real ripple frequencies the
		// lattice was gone and the fade was doing the opposite job: it switched
		// the detail off over exactly the water where the mesh quads are largest
		// on screen, leaving the bare faceted geometry showing under the boat.
		// The fine normal is what BREAKS UP those facets, so it has to run right
		// up to the hull.
		float bite = 11.0 * ripple * near;
		vec3 rn = normalize(vec3(-hx * bite, 1.0, -hz * bite));
		n = normalize(mix(n, rn, 0.55 * near));
	}
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	// Analytic depth. The bed is flat at M1; when it becomes a heightfield the
	// sim uploads the same field it uses for the fish and this samples that.
	float depth_here = bed_depth;
	float murk = clamp(depth_here / bed_depth, 0.0, 1.0);
	vec3 body = mix(shallow.rgb, deep.rgb, murk);

	// Fresnel. Water is almost entirely reflection at a grazing angle, which
	// is what makes a lake read as a lake rather than as a coloured floor.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	// Only a LITTLE flat sky tint now. The engine reflects the real panorama into
	// this surface through ROUGHNESS and SPECULAR, so the old 0.82 Fresnel mix
	// toward a flat colour was the sky being counted twice - which is most of why
	// the lake came out as a white sheet the moment a real sky went in.
	ALBEDO = mix(body, sky.rgb, clamp(fres, 0.0, 0.30));
	ROUGHNESS = mix(mix(0.30, 0.07, gloss), 0.34, murk);
	METALLIC = 0.0;
	SPECULAR = 0.85 * beam;
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
	# TEXTURED, and SWEPT into a hull rather than assembled from blocks.
	#
	# The framing rule above still holds - no solid deck, gunwales converging on
	# a bow, water between them - and everything here is added inside it. What
	# was missing was surface: the rail is the closest object to the camera in
	# the whole game and fills a tenth of the frame, which is exactly the
	# situation ASSETS.md names as the exception to modelling in code. So it gets
	# a real plank normal and roughness.
	#
	# The COLOUR map is deliberately not imported. A photographic wood albedo
	# drags in its own palette and would be the one object in the picture not
	# taking its colour from `Mood`; the normal and the roughness are the halves
	# that are style-neutral, which is the rule from the notes.
	#
	# **A chain of boxes was tried first and read as floating debris.** Short
	# segments toed inward leave a visible gap at every joint and each one catches
	# the light on its own end cap, so the hull came out as a scatter of blocks. A
	# hull is a swept curve and has to be built as one - `_sweep` below.
	var rail_mat := _wood_mat(Color(0.30, 0.22, 0.155), Vector3(1.0, 4.0, 1.0))
	var strake_mat := _wood_mat(Color(0.245, 0.180, 0.128), Vector3(1.0, 4.0, 1.0))

	for side in [-1.0, 1.0]:
		var rail_pts: Array[Vector3] = []
		var strake_pts: Array[Vector3] = []
		for i in 13:
			var t := float(i) / 12.0
			# Widest about a third back, not at the stern, and drawing in to a
			# bow. A straight taper reads as a wedge rather than as a boat.
			# Converging to a real bow. An earlier taper stopped at 0.29 and left
			# the two sides a clear half-metre apart at the front, which reads as
			# two rails rather than as a boat that closes. No bow BLOCK though -
			# one stood here for a build and sat exactly in front of the float at
			# a short cast, hiding the one object the player is watching.
			var half: float = 0.615 - 0.50 * t * t
			var z: float = 0.05 + t * 2.25
			rail_pts.append(Vector3(side * half, 0.205 + 0.075 * t * t, z))
			strake_pts.append(Vector3(side * (half + 0.010), 0.055 + 0.055 * t * t, z))
		var rail := MeshInstance3D.new()
		rail.mesh = _sweep(rail_pts, 0.115, 0.150)
		rail.material_override = rail_mat
		_boat.add_child(rail)
		# One strake under the gunwale, catching the light differently. Two planks
		# read as a built object; one reads as an edge.
		var strake := MeshInstance3D.new()
		strake.mesh = _sweep(strake_pts, 0.075, 0.215)
		strake.material_override = strake_mat
		_boat.add_child(strake)

	# A coil of rope on the thwart. Tiny, and it is the whole difference between
	# a boat and a diagram of a boat - the eye reads "used" from one such object.
	var rope := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.115
	tm.rings = 10
	tm.ring_segments = 12
	rope.mesh = tm
	rope.material_override = _mat(Color(0.44, 0.39, 0.29), 0.95)
	rope.position = Vector3(-0.40, 0.215, -0.16)
	rope.rotation_degrees = Vector3(4, 18, 0)
	_boat.add_child(rope)

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
			seg.rotation_degrees = Vector3(ROD_REST, 0, 9)
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
## Total BEND across the rod, in degrees, excluding the cast swing.
##
## Measured off the segments PAST the butt, because the butt carries the swing as
## well as its own share of the bend - and counting it would report a rod being
## waved back for a cast as a rod under load, which is exactly the thing the two
## motions were separated to stop. Scaled back up by the butt's share so the
## number still means "the whole bend".
func rod_bend_degrees() -> float:
	var total := 0.0
	for i in range(1, _rod_chain.size()):
		total += absf(_rod_chain[i].rotation_degrees.x)
	var butt_share: float = ROD_CURVE[0]
	return total / maxf(0.01, 1.0 - butt_share)


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
## The bank. **Held in a parent so it can leave**, which it must: these are reeds
## in two metres of water, and the same fifty-four of them were standing in the
## middle of a hundred and fifty metres of open lake at The Spring. A shoreline
## that follows you out to the deepest water in the game is the sort of thing
## that is invisible while you build it and impossible to unsee afterwards.
func _build_reeds() -> void:
	_reeds = Node3D.new()
	_reeds.name = "Reeds"
	add_child(_reeds)
	# TAPERED BLADES, not sticks. A reed is a long triangle that leans and curls
	# at the tip, and at this distance that silhouette is the entire read - which
	# is exactly why it stays modelled in code rather than imported. `_sweep` is
	# already here for the hull, so a reed is four points and a taper.
	var blade := _mat(Color(0.255, 0.290, 0.150), 0.95)
	blade.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dry := _mat(Color(0.360, 0.330, 0.190), 0.95)
	dry.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in 120:
		var h := 0.85 + SimUtil.hash2(i, 3) * 1.7
		var side := -1.0 if i % 2 == 0 else 1.0
		# The bank sits well down the lake and spreads outward with distance, so
		# it stays inside the horizontal cone the whole way.
		var z := 14.0 + SimUtil.hash2(i, 17) * 34.0
		var spread := 1.6 + z * 0.17
		var base := Vector3(
			side * (spread + SimUtil.hash2(i, 11) * 6.0),
			-0.30,
			z
		)
		# The lean, and a curl at the top. A reed that is straight reads as a
		# fence post; the curl is most of what makes a bank look alive.
		var lean := Vector3(
			(SimUtil.hash2(i, 23) - 0.5) * 0.5,
			0.0,
			(SimUtil.hash2(i, 29) - 0.5) * 0.5
		)
		var pts: Array[Vector3] = []
		for k in 5:
			var t := float(k) / 4.0
			pts.append(base + Vector3(0, h * t, 0) + lean * (t * t * h))
		var reed := MeshInstance3D.new()
		# Swept with a width that closes to nothing, so the blade tapers.
		reed.mesh = _sweep_tapered(pts, 0.055, 0.004)
		reed.material_override = dry if SimUtil.hash2(i, 41) > 0.72 else blade
		_reeds.add_child(reed)


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
## THE FISH GENERATOR.
##
## A spine, a swept rib profile and a fin set, all from `Species.look_of`. This
## is the rule in ASSETS.md landing on the right side twice over: a landed fish
## is stationary, close to the camera and looked at while nothing else is
## happening, which is the exception that would allow an imported model - but the
## shape of a fish here IS gameplay state, and that closes the question. A Thin
## Perch is a perch with `long` at 4.1, a Blindfish has no iris, and the wrong
## ones in the later acts are these same fields at values no fish has.
##
## Colour is baked into VERTEX COLOURS - back to belly down the flank, plus the
## vertical bars - so a species needs no texture and no material of its own.
func _build_fish() -> Node3D:
	var f := Node3D.new()
	f.name = "Fish"
	f.visible = false
	_fish = f
	_rebuild_fish("bluegill")
	return f


const FISH_RINGS := 22        ## along the body
const FISH_SIDES := 12        ## around it


## How fat the fish is at `t` along its length, 0 at the nose and 1 at the tail
## root. Peaks about a third back, which is where a fish is actually widest - a
## symmetrical bulge reads as a submarine.
func _fish_girth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return pow(x, 0.42) * pow(1.0 - x * 0.92, 0.75) * 1.72


func _rebuild_fish(id: String) -> void:
	if _fish == null:
		return
	for c in _fish.get_children():
		_fish.remove_child(c)
		c.queue_free()

	var look := Species.look_of(id)
	var long: float = look["long"]
	var deep: float = look["deep"]
	var back: Color = look["back"]
	var belly: Color = look["belly"]
	var stripes: int = int(look["stripes"])

	# Length is fixed and the body scaled around it, so every species arrives at
	# the same size on screen - the landing shot is a portrait, not a size
	# comparison. The weight is written underneath it in words.
	var length := 1.35
	var half_h := length / long * 0.5
	var half_w := half_h * deep * 0.62

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	for i in FISH_RINGS:
		var t := float(i) / float(FISH_RINGS - 1)
		var g := _fish_girth(t)
		var z := length * (0.5 - t)
		for j in FISH_SIDES:
			var a := TAU * float(j) / float(FISH_SIDES)
			var cx := sin(a)
			var cy := cos(a)
			verts.append(Vector3(cx * half_w * g, cy * half_h * g, z))
			norms.append(Vector3(cx * deep, cy, 0.0).normalized())
			# Counter-shading: dark along the back, pale on the belly. It is the
			# single thing that makes a generated body read as a fish rather than
			# as a lozenge, because it is what every real fish does.
			var down := clampf(0.5 - cy * 0.5, 0.0, 1.0)
			# Squared, so the dark holds most of the upper flank and the pale is
			# confined to the underside. A linear blend puts the midtone across
			# the widest part of the body, which is where the eye looks.
			var c := back.lerp(belly, pow(down, 2.1))
			if stripes > 0:
				var bar := sin(t * PI * float(stripes) * 1.15)
				if bar > 0.45:
					c = c.darkened(0.30 * (bar - 0.45) / 0.55)
			cols.append(c)

	for i in FISH_RINGS - 1:
		for j in FISH_SIDES:
			var a0 := i * FISH_SIDES + j
			var a1 := i * FISH_SIDES + (j + 1) % FISH_SIDES
			var b0 := (i + 1) * FISH_SIDES + j
			var b1 := (i + 1) * FISH_SIDES + (j + 1) % FISH_SIDES
			idx.append_array([a0, b0, a1, a1, b0, b1])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var body := MeshInstance3D.new()
	body.mesh = mesh
	var bmat := StandardMaterial3D.new()
	bmat.vertex_color_use_as_albedo = true
	# Wet, not chromed. Metallic at 0.12 with a low roughness put a sheen across
	# the whole flank that flattened the counter-shading into one pale tube - and
	# the counter-shading is the entire reason a generated body reads as a fish.
	bmat.roughness = 0.42
	bmat.metallic = 0.0
	body.material_override = bmat
	body.name = "Body"
	_fish.add_child(body)

	# Fins, cut from the same two numbers as the body, so a long thin fish gets
	# long thin fins without a second table.
	var fin_col: Color = look["fin"]
	var fmat := _mat(fin_col, 0.55)
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color = Color(fin_col.r, fin_col.g, fin_col.b, 0.90)

	# The tail, forked. The fork says "fish" at a glance more than the body does.
	var tail_z := -length * 0.52
	var tail_h := half_h * 1.30
	_fish.add_child(_fin([
		Vector3(0, 0, tail_z + 0.03),
		Vector3(0, tail_h, tail_z - length * 0.19),
		Vector3(0, tail_h * 0.26, tail_z - length * 0.10),
		Vector3(0, -tail_h * 0.26, tail_z - length * 0.10),
		Vector3(0, -tail_h, tail_z - length * 0.19),
	], fmat, "Tail"))

	_fish.add_child(_fin([
		Vector3(0, half_h * 0.88, length * 0.22),
		Vector3(0, half_h * 1.34, length * 0.06),
		Vector3(0, half_h * 1.22, -length * 0.12),
		Vector3(0, half_h * 0.84, -length * 0.08),
	], fmat, "Dorsal"))

	# An anal fin as well as a dorsal. Two read as a built animal; one reads as
	# a shark silhouette.
	_fish.add_child(_fin([
		Vector3(0, -half_h * 0.86, -length * 0.14),
		Vector3(0, -half_h * 1.22, -length * 0.24),
		Vector3(0, -half_h * 0.82, -length * 0.30),
	], fmat, "Anal"))

	for side in [-1.0, 1.0]:
		var pec := _fin([
			Vector3(0, 0, length * 0.20),
			Vector3(0, half_h * 0.55, length * 0.05),
			Vector3(0, -half_h * 0.25, length * 0.02),
		], fmat, "Pectoral")
		pec.rotation_degrees = Vector3(0, 0, side * 70.0)
		pec.position = Vector3(side * half_w * 0.85, -half_h * 0.15, 0)
		_fish.add_child(pec)

	# The eye, and it is the first place a wrong fish gives itself away - the
	# Blindfish has an iris the colour of its own skin, which reads before the
	# player has worked out why.
	for side2 in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = half_h * 0.20
		em.height = half_h * 0.40
		em.radial_segments = 8
		em.rings = 5
		eye.mesh = em
		var emat := _mat(look["eye"], 0.20)
		emat.metallic = 0.35
		eye.material_override = emat
		eye.position = Vector3(side2 * half_w * 0.62, half_h * 0.34, length * 0.395)
		eye.name = "Eye"
		_fish.add_child(eye)


## A flat fin from a fan of points in the YZ plane, double sided.
func _fin(pts: Array, mat: Material, fin_name: String) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for p in pts:
		verts.append(p)
	for i in range(1, pts.size() - 1):
		idx.append_array([0, i, i + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = fin_name
	return mi


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

	# The whole screen takes touches, because a tap needs no precision of
	# position and the gauges are drawn on top of it without consuming anything.
	# Nothing the player looks at can be covered, because nothing they look at is
	# something they touch.
	_cast_area = Control.new()
	_cast_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cast_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_cast_area.name = "CastArea"
	_cast_area.gui_input.connect(_on_cast_input)
	_ui.add_child(_cast_area)

	# MINIGAME 1 has NO HUD AT ALL - the float is the whole instrument, which is
	# what was asked for. Only the reel has a gauge, and it is anchored to the TOP
	# centre and MOUSE_FILTER_IGNORE: it is a readout, not a control, and a readout
	# that eats a touch is a readout the player cannot tap through.
	_tension_bar = Control.new()
	_tension_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tension_bar.anchor_left = 0.5 - BAR_W * 0.5
	_tension_bar.anchor_right = 0.5 + BAR_W * 0.5
	_tension_bar.offset_left = 0.0
	_tension_bar.offset_right = 0.0
	_tension_bar.offset_top = GAUGE_TOP
	_tension_bar.offset_bottom = GAUGE_TOP + GAUGE_H
	_tension_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tension_bar.name = "TensionBar"
	_tension_bar.draw.connect(_draw_tension_bar)
	_ui.add_child(_tension_bar)

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
	# Below both bars, not through them. At 320 it ran straight across the tension
	# gauge, which is the one thing on screen that has to stay readable.
	_prompt.offset_top = 400
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 44)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 10)
	_prompt.name = "Prompt"
	_ui.add_child(_prompt)

	# The world line: where you are, what day and hour it is, and what the weather
	# is doing. Top-RIGHT, opposite the catch tally, because the two are read at
	# different moments and stacking them makes one block nobody reads.
	_world_line = Label.new()
	_world_line.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_world_line.offset_left = -640
	_world_line.offset_right = -44
	_world_line.offset_top = 54
	_world_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_line.add_theme_font_size_override("font_size", 30)
	_world_line.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 0.88))
	_world_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_world_line.add_theme_constant_override("outline_size", 8)
	_world_line.name = "WorldLine"
	_ui.add_child(_world_line)

	# THE DOCK, and it only exists when the line is in.
	#
	# It sits along the bottom, which is also where a thumb lands to reel - so if
	# it were ever visible during a fight the player would open the shop trying
	# to land a sturgeon. `_sync_bars` hides it in every state but IDLE, and that
	# is not a nicety: the alternative is a button under the one gesture the game
	# asks for most.
	_dock = HBoxContainer.new()
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 40
	_dock.offset_right = -40
	_dock.offset_top = -196
	_dock.offset_bottom = -84
	_dock.add_theme_constant_override("separation", 18)
	_dock.name = "Dock"
	_ui.add_child(_dock)
	for pair in [[Menus.SHED, "Shed"], [Menus.MAP, "Lake"], [Menus.LOG, "Log"]]:
		var screen: String = pair[0]
		var b := _dock_button(str(pair[1]))
		b.pressed.connect(func() -> void: _open(screen))
		_dock.add_child(b)

	_load_game()

	_audio = Audio.new()
	_audio.name = "Audio"
	add_child(_audio)
	_audio.setup(sim)
	_audio.start()

	# THE SOUNDER. Down the left edge, narrow, and only there once it is bought.
	# It is a readout and not a control, so MOUSE_FILTER_IGNORE - the whole screen
	# under it is still the cast surface.
	_sounder = Control.new()
	_sounder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_sounder.offset_left = 34
	_sounder.offset_right = 366
	_sounder.offset_top = 300
	_sounder.offset_bottom = 830
	_sounder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sounder.name = "Sounder"
	_sounder.draw.connect(_draw_sounder)
	_ui.add_child(_sounder)

	_menus = Menus.new()
	_menus.name = "Menus"
	add_child(_menus)
	_menus.setup(sim)
	_menus.changed.connect(func() -> void:
		_audio.play("coin", -6.0)
		_want_save())

	# Anything that changes the boat asks for a write. Landing a fish is the one
	# a player would be most upset to lose, and it is also the most frequent, so
	# the request is COALESCED rather than written immediately - see `_want_save`.
	sim.landed.connect(func(_id: String, _w: float) -> void: _want_save())
	sim.object_found.connect(func(_id: String) -> void: _want_save())
	_menus.changed.connect(_sync)
	_menus.closed.connect(_sync)

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


## Show, hide and redraw the bars. Their SIZE is anchors, so nothing here has to
## compute it - see the note where they are built.
##
## **Visibility is set HERE, never inside the draw callback.**
##
## It was, and it shipped. The draw handler began with
## `visible = (state == FIGHTING)`, which is a LATCH: a hidden Control never
## receives `draw` again, so the first frame in any other state switched it off
## permanently and the gauge was NEVER SEEN on the phone. It survived my own
## screenshot because that capture happened to freeze mid-fight - the one state
## in which the bug cannot appear.
##
## The general form, worth carrying: **a callback must not decide whether it is
## called.** Anything that gates its own invocation can only ever fail closed.
func _sync_bars() -> void:
	if _tension_bar == null:
		return
	var in_room := _menus != null and _menus.is_open()
	_tension_bar.visible = sim.state == Sim.FIGHTING and not in_room
	_tension_bar.queue_redraw()
	if _dock != null:
		_dock.visible = sim.state == Sim.IDLE and not in_room
	if _world_line != null:
		_world_line.visible = not in_room
	if _readout != null:
		_readout.visible = not in_room
	if _prompt != null:
		_prompt.visible = not in_room
	if _sounder != null:
		# Visibility HERE, never inside the draw callback - see the note above.
		_sounder.visible = sim.econ.has_sounder and not in_room
		_sounder.queue_redraw()


func _dock_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.09, 0.82)
	box.border_color = Color(0.93, 0.90, 0.82, 0.22)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var press := box.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.14, 0.20, 0.21, 0.92)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	b.add_theme_color_override("font_hover_color", Color(0.93, 0.90, 0.82))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return b


## Rooms open only from the boat. Refused rather than queued: a shop that opens
## the moment a fish comes off is a shop that opens by accident.
func _open(screen: String) -> void:
	if sim.state != Sim.IDLE:
		return
	if _audio != null:
		_audio.play("page", -4.0)
	_menus.open(screen)
	_sync_bars()


## MINIGAME 2: the tension gauge.
##
## Horizontal and at the top, so it never sits under a hand. The band is drawn
## from `Tuning.SAFE_LO`/`SAFE_HI` and the needle from `sim.tension`, which are
## the numbers the rules use.
##
## The part that teaches the mechanic without a word of text: during a RUN the
## needle climbs with the player's thumb completely still, and they work out on
## their own that the answer is to stop tapping.
func _draw_tension_bar() -> void:
	if sim.state != Sim.FIGHTING:
		return
	var w := _tension_bar.size.x
	var h := _tension_bar.size.y

	_tension_bar.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.07, 0.09, 0.72))

	var lo := Tuning.SAFE_LO / Tuning.TENSION_MAX * w
	var hi := Tuning.SAFE_HI / Tuning.TENSION_MAX * w
	var good := sim.in_band()
	_tension_bar.draw_rect(Rect2(lo, 2, hi - lo, h - 4),
		Color(0.42, 0.86, 0.48, 0.42 if good else 0.24))

	# The danger end, filling as the line takes strain.
	if sim.strain > 0.0:
		_tension_bar.draw_rect(Rect2(hi, 2, w - hi, h - 4),
			Color(0.92, 0.30, 0.24, 0.25 + 0.6 * sim.strain))

	var nx := clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0) * w
	var ncol := Color(0.70, 0.98, 0.74) if good else Color(0.98, 0.55, 0.38)
	_tension_bar.draw_rect(Rect2(nx - 3.0, -8, 6.0, h + 16), ncol)

	_tension_bar.draw_rect(Rect2(0, 0, w, h), Color(0.88, 0.90, 0.86, 0.35), false, 2.0)

	# A run, said in the gauge's own language: the frame flashes rather than a
	# caption appearing. The needle climbing on its own is the real instruction;
	# this only makes it impossible to miss.
	if sim.running or sim.tell > 0.0:
		var pulse := 0.45 + 0.35 * sin(sim.time * 14.0)
		_tension_bar.draw_rect(Rect2(-4, -4, w + 8, h + 8),
			Color(0.98, 0.72, 0.30, pulse), false, 4.0)


## One touch surface: **tap**.
##
## Hold to cast, release to send it, then tap for both minigames. That the whole
## fight is one gesture is the point - the previous version had three different
## responses to three situations, and the note on it was that it was not
## intuitive to tell what you were supposed to do.
func _on_cast_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
	else:
		return

	if pressed:
		match sim.state:
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				sim.hold_cast()
				_charging = true
			_:
				sim.tap()
	elif _charging:
		_charging = false
		if _audio != null and sim.state == Sim.CHARGING:
			_audio.play("cast", -5.0)
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
	_sync_mood(dt)
	if _save_due > 0.0:
		_save_due -= dt
		if _save_due <= 0.0:
			_save_game()
	if _menus != null:
		_menus.tick(dt)
	if _audio != null:
		_audio.tick(dt, _menus != null and _menus.is_open())
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
	# One memory for the whole run - see the note on Policies.act. A fresh dict
	# per frame silently stops the bot tapping at all.
	var mem := {}
	var n := maxi(1, int(round(seconds / step)))
	for i in n:
		Policies.act(name, sim, step, mem)
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
	_sync_bars()


## The rod IS the tension gauge.
##
## Its bend is `sim.load`, straight through, so what the player reads off the
## picture and what the rules are scoring are the same number - not two numbers
## kept in sync. The old HUD gauge showed exactly this and was covered by the
## thumb that set it; a bent rod is in the upper half of the frame where nothing
## is touching.
## Two different motions, and keeping them separate is the whole fix.
##
##   SWING  the whole rod rotates about the butt. Loading a cast lifts it up and
##          BACK; releasing swings it forward through the rest angle and settles.
##          The rod stays straight throughout, because a rod being waved is not
##          a rod under load.
##   BEND   only a hooked fish curves it, and it curves FORWARD, toward the fish.
##
## One number drove both before, so charging bent the rod as if a fish were on
## it - "the rod bends back then flicks forward which isnt how it should work".
func _sync_rod() -> void:
	if _rod == null:
		return

	# SIGN CONVENTION, because getting it wrong shipped once.
	#
	# The rod points along its own +Z. A POSITIVE rotation about X maps
	# (0,0,1) -> (0,-sin,cos), which points the tip DOWN. So:
	#
	#   negative X  =  tip up and back   (loading a cast)
	#   positive X  =  tip down and forward   (the throw, and a fish pulling)
	#
	# The first version had both inverted, and the report was exactly that:
	# "it pushes down and flings up when you let go".
	#
	# `back` and `bend` below are both written as POSITIVE quantities meaning
	# what they say, and the sign is applied once, at the bottom.
	var back := 0.0    ## degrees lifted up and behind the shoulder
	var bend := 0.0    ## degrees the tip is pulled down and forward

	match sim.state:
		Sim.CHARGING:
			back = sim.charge * CAST_BACK
		Sim.FLYING:
			# The throw: from wherever the charge had it, forward and down to a
			# stop that is STILL ABOVE HORIZONTAL.
			#
			# Gideon: "when you cast the rod should pull back, then fling forward
			# but still be angled up. when you cast currently, it pulls back a
			# little then angles all the way into the water before returning."
			# It was written as an offset PAST the rest angle, which put the tip
			# under the waterline at the end of every cast. `CAST_THROW_TO` is an
			# absolute angle now, so "still angled up" is stated rather than
			# arrived at, and the smoke test asserts it stays above horizontal.
			var k := _ease_out(clampf(sim.state_time / CAST_SWING_TIME, 0.0, 1.0))
			back = lerpf(sim.charge * CAST_BACK, -(CAST_THROW_TO - ROD_REST), k)
		Sim.SINKING:
			# Drift back to rest rather than snapping, so the whole cast reads as
			# one continuous motion.
			var settle := _ease_out(clampf(sim.state_time / 0.55, 0.0, 1.0))
			back = lerpf(-(CAST_THROW_TO - ROD_REST), 0.0, settle)
		Sim.NIBBLING:
			# The rod tip twitches with the tug as well as the float dipping -
			# "just watching the rod or bobber pull down". Two readings of one
			# number, so whichever the player happens to be looking at tells them
			# the same thing.
			bend = sim.tug * ROD_BEND * 0.30
		Sim.FIGHTING:
			bend = clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0) * ROD_BEND
		_:
			pass

	# A rod near breaking shivers. Cosmetic, so `randf` would be legal - but it
	# is keyed on the sim's own clock so two screenshots of the same second are
	# identical, which is what makes them comparable at all.
	if sim.state == Sim.FIGHTING and sim.danger() > 0.3:
		bend += sin(sim.time * 47.0) * (sim.danger() - 0.3) * 3.0

	for i in _rod_chain.size():
		var share: float = ROD_CURVE[i] * bend
		if i == 0:
			# The butt carries the whole swing plus its share of the bend. Both
			# are down-positive, and `back` is a lift, so it subtracts.
			_rod_chain[i].rotation_degrees = Vector3(ROD_REST - back + share, 0.0, 9.0)
		else:
			_rod_chain[i].rotation_degrees = Vector3(share, 0.0, 0.0)
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
	var showing := sim.state == Sim.FIGHTING and (sim.running or sim.tell > 0.0)
	_wake.visible = showing
	if not showing:
		return
	# Which way it bears is decided per FISH, not per frame, so the wake does not
	# flicker side to side. Keyed on the cast number, which is stable for the
	# whole fight.
	var side := 1.0 if SimUtil.hash2(sim.casts, 71) > 0.5 else -1.0
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
			# The float says what the fish is doing, because it is the only thing
			# on the water and the player is already looking at it. Keyed on the
			# sim's own clock rather than randf, so the same second of the same
			# fight draws identically and two screenshots a week apart compare.
			var z := maxf(0.6, sim.fish_distance)
			var t := sim.fight_time
			if sim.running:
				# Shearing off and skating - the same thing the wake is saying.
				return Vector3(sin(t * 2.1) * 0.9, -0.02, z)
			# Pulled under by however much tension is on it. A slack line lets it
			# sit up, which is the second reading of "you are not tapping enough".
			return Vector3(0.0, -sim.tension * 0.16, z)
		Sim.NIBBLING:
			# **MINIGAME 1, and it is entirely here.** `sim.tug` is how far the
			# fish has the float under - shallow and brief for a tease, deep and
			# held for the real take - so the one number that decides the outcome
			# is the one the player is watching. There is no HUD for this at all.
			#
			# The jitter is what sells it as something alive rather than a value
			# being animated: a float being mouthed shakes as well as sinking.
			# Keyed on the sim clock, so two captures of one instant are identical.
			var jitter := sin(sim.time * 34.0) * sim.tug * 0.035
			return Vector3(
				jitter,
				-sim.tug * FLOAT_DIP,
				sim.cast_distance + jitter * 0.5
			)
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
	# Lower and nearer than it was. Held at eye level in open air the fish read as
	# levitating: with nothing behind it and nothing under it there was no scale
	# and no place. Dropped to just above the gunwale it has both.
	_fish.position = Vector3(0.13, 0.78 + sin(t * 2.4) * 0.02, 0.92)
	_fish.rotation = Vector3(sin(t * 3.1) * 0.10, 1.45 + sin(t * 0.9) * 0.28, sin(t * 4.3) * 0.07)
	# REBUILT, not recoloured. The old path tinted one sphere, so every species in
	# the game was the same fish in a different colour - and only three of the
	# twenty-six even had a colour.
	if _fish_shown != sim.fish_id:
		_fish_shown = sim.fish_id
		_rebuild_fish(sim.fish_id)


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
			# The one hint the game gives, and only until the first fish is landed.
			# After that the float has taught it and a caption would just be read
			# instead of the water.
			line = "WATCH THE FLOAT" if sim.caught == 0 else ""
		Sim.FIGHTING:
			# Distance only. No "STOP TAPPING!" during a run - the needle
			# climbing on its own while the thumb is still says it better than
			# words, and a caption that says it too means the player reads the
			# caption forever instead of learning the gauge.
			line = "%.1f m" % sim.fish_distance
		Sim.HOLDING:
			var row := Species.by_id(sim.fish_id)
			var nm: String = row["name"] if not row.is_empty() else "?"
			line = "%s   %.2f kg" % [nm, sim.fish_weight]
		Sim.LOST:
			line = ""
	_prompt.text = line

	_readout.text = "%d coin\n%.1f of %.1f kg" % [
		sim.econ.money, sim.econ.load_kg(), sim.econ.capacity()]

	# Metres, never years. The player does that arithmetic themselves, from the
	# dates on what comes up off the bottom - see world.gd.
	if _world_line != null:
		var spot := World.spot_by_id(sim.spot)
		_world_line.text = "%s\nday %d, %s, %s\n%s under you" % [
			spot["name"], sim.day, sim.hour, sim.weather,
			SimUtil.fmt_m(sim.deepest_here())]
	_stamp.text = BuildStamp.line()


## Ease-out, so the rod decelerates into the end of a swing instead of arriving
## at constant speed. A linear cast reads as a mechanism rather than an arm.
func _ease_out(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


## Put the hour, the weather and the depth into the picture.
##
## `Mood.at` decides everything and this only assigns it, which is what lets the
## look be tested at all - "night is darker than noon in every weather" is an
## assertion over a pure function, and would otherwise be a thing you could only
## check by taking twenty-five screenshots.
##
## Everything is followed rather than set, at the same rate as the score, so the
## lake changes on the way down instead of at the moment a band boundary is
## crossed. Weather is the exception the player is allowed to notice: it changes
## while they are asleep.
func _sync_mood(dt: float) -> void:
	if _env == null or _sky_mat == null:
		return

	var want := clampf(sim.lure_depth / Audio.DREAD_FULL, 0.0, 1.0)
	if sim.state == Sim.IDLE or sim.state == Sim.CHARGING:
		want = clampf(sim.deepest_here() / Audio.DREAD_FULL, 0.0, 1.0) * 0.5
	_dread = lerpf(_dread, want, 1.0 - exp(-1.1 * dt))

	var look: Dictionary = Mood.at(sim.hour, sim.weather, _dread)
	var k := 1.0 - exp(-2.2 * dt)

	_sync_sky(look, k)

	_env.ambient_light_energy = lerpf(_env.ambient_light_energy,
		float(look["ambient"]) * AMBIENT_SCALE, k)
	_env.fog_light_color = _env.fog_light_color.lerp(look["fog_color"], k)
	_env.fog_density = lerpf(_env.fog_density, float(look["fog_density"]), k)

	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(look["sun_color"], k)
		_sun.light_energy = lerpf(_sun.light_energy, float(look["sun_energy"]) * SUN_SCALE, k)
		var pitch := lerpf(_sun.rotation_degrees.x, float(look["sun_pitch"]), k)
		_sun.rotation_degrees = Vector3(pitch, 8.0, 0.0)

	# The bank recedes as the water gets older, and is gone by Old Town. There is
	# no shoreline in the middle of the lake and there is nothing to replace it
	# with - open water in every direction is the correct and much worse picture.
	if _reeds != null:
		var near := 1.0 - clampf(sim.deepest_here() / 45.0, 0.0, 1.0)
		_reeds.visible = near > 0.02
		for r in _reeds.get_children():
			var mi := r as MeshInstance3D
			if mi != null:
				mi.transparency = 1.0 - near

	_sync_weather(look, k)
	_sync_grade(k)

	if _water_mat != null:
		var sh: Color = _water_mat.get_shader_parameter("shallow")
		var dp: Color = _water_mat.get_shader_parameter("deep")
		var sk: Color = _water_mat.get_shader_parameter("sky")
		_water_mat.set_shader_parameter("shallow", sh.lerp(look["water_shallow"], k))
		_water_mat.set_shader_parameter("deep", dp.lerp(look["water_deep"], k))
		_water_mat.set_shader_parameter("sky", sk.lerp(look["water_sky"], k))
		var gl: float = _water_mat.get_shader_parameter("gloss")
		_water_mat.set_shader_parameter("gloss",
			lerpf(gl, clampf(1.0 / float(look["chop"]), 0.0, 1.0), k))
		var bm: float = _water_mat.get_shader_parameter("beam")
		_water_mat.set_shader_parameter("beam", lerpf(bm, float(look["specular"]), k))
		var rp: float = _water_mat.get_shader_parameter("ripple")
		_water_mat.set_shader_parameter("ripple",
			lerpf(rp, clampf(float(look["chop"]), 0.5, 2.6), k))


# --- keeping it -----------------------------------------------------------

const SAVE_PATH := "user://stillwater.json"

## How long to wait before actually writing. Landing three fish in a minute
## should be one write, not three - but the delay is short, because **a save
## that only happens on quit is a save that loses the session** whenever the OS
## kills a backgrounded app, which on a phone it does without warning and
## without running any exit handler.
const SAVE_DELAY := 1.5


func _want_save() -> void:
	_save_due = SAVE_DELAY


func _save_game() -> void:
	_save_due = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(Save.to_dict(sim)))
	f.close()


## Read the save if there is one. Anything wrong with it - missing, truncated,
## not JSON, written by a build that no longer exists - leaves a new game
## running, silently. **A boot that hard-fails on an old save is the worst bug a
## game can ship**: the player loses everything AND cannot get back in.
func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	Save.apply(sim, parsed)


## The phone can take the app away at any moment, so write on the way out too -
## belt and braces over the coalesced write, not instead of it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if sim != null and _booted:
			_save_game()


## THE SOUNDER, and it is the game's best storytelling instrument.
##
## A depth column: surface at the top, the bed at the bottom, the lure where the
## lure is, and the bottom's own silhouette drawn from `World.BOTTOMS`. It costs
## 1200 and buys NO fishing advantage at all - no better bites, no bigger fish.
## It buys knowing what is under the boat.
##
## Which is the point. The player sees rooftops and one tall spike at Old Town
## forty metres below anything their line will touch, and nothing in the game
## says a word about it. The dates on what comes up explain it hours later, and
## the shape was on screen the whole time.
##
## Everything drawn is metres off the sim. The trace and the rules cannot
## disagree, because the trace is not a second model of the lake - it is the one
## the fish are in.
func _draw_sounder() -> void:
	if not sim.econ.has_sounder:
		return
	var w := _sounder.size.x
	var h := _sounder.size.y
	var spot := World.spot_by_id(sim.spot)
	var bed: float = spot["bed"]
	if bed <= 0.01:
		return

	_sounder.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.05, 0.06, 0.62))
	_sounder.draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.78, 0.70, 0.22), false, 2.0)

	# Depth gridlines, every 25% of the bed, labelled in metres. The player reads
	# this and does the arithmetic that turns metres into years by themselves.
	for i in range(1, 4):
		var y := h * float(i) / 4.0
		_sounder.draw_line(Vector2(0, y), Vector2(w, y), Color(0.55, 0.78, 0.70, 0.13), 1.0)

	# The bed, and whatever is standing on it.
	var pts := PackedVector2Array()
	var bottom := World.bottom_of(sim.spot)
	# VERTICALLY EXAGGERATED, exactly as a real sounder is. At true scale an
	# eleven metre steeple in eighty metres of water is a fourteen per cent tick
	# that reads as noise on the bed - and this display exists to be READ, from a
	# phone, at a glance. Capped so a tall structure cannot fill the column and
	# hide the water the fish are in.
	var per_m := (h / bed) * SOUNDER_RELIEF
	var tallest := 0.0
	for p in bottom:
		tallest = maxf(tallest, float(p[1]))
	if tallest * per_m > h * 0.55:
		per_m = h * 0.55 / tallest
	pts.append(Vector2(0, h))
	for p in bottom:
		var across: float = p[0]
		# Every value out of a nested Array is a Variant, so both are annotated -
		# `:=` cannot infer from one and the parse error names the local, not the
		# lookup. Third time this has bitten in this repo.
		var up: float = p[1]
		pts.append(Vector2(across * w, h - up * per_m))
	pts.append(Vector2(w, h))
	_sounder.draw_colored_polygon(pts, Color(0.30, 0.44, 0.36, 0.72))

	# How far the line will reach, as a hard rule across the column. Everything
	# below it is water the player can see and cannot touch, which is the whole
	# progression drawn as one line.
	var reach := minf(bed, Gear.line_depth(sim.econ.line))
	var ry := h * clampf(reach / bed, 0.0, 1.0)
	_sounder.draw_line(Vector2(0, ry), Vector2(w, ry), Color(0.86, 0.72, 0.38, 0.55), 2.0)

	# Fish, at the depths they actually live at. Only the ones this cast could
	# meet: a mark for something the line cannot reach would be a lie.
	var hour := sim.hour
	for row in Species.at_depth(sim.lure_depth if sim.lure_depth > 0.1 else reach * 0.5, hour):
		var lo: float = row["min_depth"]
		var hi: float = row["max_depth"]
		var mid := clampf((lo + hi) * 0.5, 0.0, bed)
		var x := w * (0.24 + SimUtil.hash2(int(sim.time * 0.4), row["id"].length()) * 0.6)
		var y := h * (mid / bed)
		_sounder.draw_arc(Vector2(x, y), 7.0, PI * 1.1, PI * 1.9, 8,
			Color(0.92, 0.86, 0.58, 0.75), 2.5)

	# The lure. The one mark the player is actually steering.
	if sim.lure_depth > 0.01:
		var ly := h * clampf(sim.lure_depth / bed, 0.0, 1.0)
		_sounder.draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, ly),
			Color(0.90, 0.92, 0.88, 0.35), 1.0)
		_sounder.draw_circle(Vector2(w * 0.5, ly), 5.0, Color(0.92, 0.34, 0.26))

	var font := ThemeDB.fallback_font
	_sounder.draw_string(font, Vector2(10, h - 12), SimUtil.fmt_m(bed),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.72, 0.86, 0.78, 0.7))
	# The lure's depth is written NEXT TO THE LURE, not in a corner. It is the one
	# number on this display that moves, and a moving number in a fixed caption
	# box is a number the player has to look for.
	if sim.lure_depth > 0.01:
		var ly2 := h * clampf(sim.lure_depth / bed, 0.0, 1.0)
		_sounder.draw_string(font, Vector2(w * 0.5 + 12, clampf(ly2 + 8.0, 20.0, h - 6.0)),
			SimUtil.fmt_m(sim.lure_depth),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.90, 0.80, 0.92))


# --- the sky ---------------------------------------------------------------

## The five skies, in the order the hours run. Poly Haven 1k HDRIs, CC0.
##
## The `puresky` variants are sky ONLY - no ground, no trees, no horizon clutter
## - which is what a lake needs, because the horizon in this game is water and
## anything baked into the bottom half of the panorama would be reflected in it.
const SKIES := {
	"dawn": "res://assets/sky/sky_dawn.hdr",
	"morning": "res://assets/sky/sky_morning.hdr",
	"afternoon": "res://assets/sky/sky_afternoon.hdr",
	"dusk": "res://assets/sky/sky_dusk.hdr",
	"night": "res://assets/sky/sky_night.hdr",
}

## The weather sky, laid OVER whichever hour is running. Heavy cloud has no time
## of day in it, so one panorama covers all five - and blending it in by how bad
## the weather is means a storm at dusk gets storm clouds lit dusk-coloured,
## rather than a second complete sky that has to agree with the first.
const STORM_SKY := "res://assets/sky/sky_storm.hdr"

## How much of the storm sky each weather pulls in.
const SKY_CLOUD := {
	"clear": 0.00, "overcast": 0.55, "fog": 0.30, "rain": 0.70, "storm": 0.92,
}


## A real sky, WITHOUT giving up the mood arc.
##
## The obvious way to use an HDRI is `PanoramaSkyMaterial`, and it is wrong here:
## a panorama is one fixed photograph, and this game's whole look is a continuous
## curve through hour, weather and depth. Swapping panoramas at each hour would
## be exactly the hard cut the arc exists to avoid.
##
## So the sky is a shader that samples TWO panoramas and crossfades them, then
## applies the same tint, grey and darkening `Mood.at` hands everything else.
## Real cloud detail - which is the grit that was missing - and the arc still
## drives it. The water reflects the result, which is most of why the lake now
## reads as water rather than as a coloured surface.
func _build_sky_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SKY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sky_a", load(SKIES["dawn"]))
	m.set_shader_parameter("sky_b", load(SKIES["dawn"]))
	m.set_shader_parameter("blend", 0.0)
	m.set_shader_parameter("sky_cloud", load(STORM_SKY))
	m.set_shader_parameter("cloud", 0.0)
	m.set_shader_parameter("tint", Color(1, 1, 1))
	m.set_shader_parameter("grey", 0.0)
	m.set_shader_parameter("darken", 0.0)
	m.set_shader_parameter("horizon", Color(0.8, 0.8, 0.8))
	_sky_a = "dawn"
	_sky_b = "dawn"
	return m


const SKY_SHADER := """
shader_type sky;

uniform sampler2D sky_a : source_color, filter_linear;
uniform sampler2D sky_b : source_color, filter_linear;
uniform sampler2D sky_cloud : source_color, filter_linear;
uniform float blend = 0.0;
uniform float cloud = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float grey = 0.0;
uniform float darken = 0.0;
uniform vec3 horizon : source_color = vec3(0.8);

vec2 equirect(vec3 dir) {
	return vec2(atan(dir.x, -dir.z) / (2.0 * PI) + 0.5, acos(clamp(dir.y, -1.0, 1.0)) / PI);
}

void sky() {
	vec2 uv = equirect(EYEDIR);
	vec3 c = mix(texture(sky_a, uv).rgb, texture(sky_b, uv).rgb, blend);

	// The BOTTOM HALF is never seen as sky - the lake covers it - but it IS what
	// the water samples for its reflection, and a `puresky` panorama has nothing
	// down there but a flat colour. Folding the horizon band down gives the
	// reflection something with structure in it, which is what stops the lake
	// reading as a coloured floor.
	if (EYEDIR.y < 0.0) {
		vec2 folded = vec2(uv.x, 0.5 - (uv.y - 0.5) * 0.55);
		vec3 f = mix(texture(sky_a, folded).rgb, texture(sky_b, folded).rgb, blend);
		c = mix(c, f, clamp(-EYEDIR.y * 2.4, 0.0, 0.85));
	}

	// The weather's cloud, laid over the hour and MULTIPLIED rather than mixed,
	// so it takes its light from whatever time of day it is instead of dragging
	// its own noon in with it. A storm at dusk stays a dusk.
	if (cloud > 0.001) {
		vec3 cl = texture(sky_cloud, uv).rgb;
		float lum = dot(cl, vec3(0.299, 0.587, 0.114));
		vec3 shaped = c * (0.35 + 1.15 * lum);
		c = mix(c, shaped, cloud);
	}

	c *= tint;
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), grey);
	c *= (1.0 - darken);
	COLOR = c;
}
"""


## Crossfade the two skies the current hour sits between, and hand the shader the
## same colour treatment everything else in the picture gets.
##
## `_sky_a`/`_sky_b` are only reassigned when the HOUR changes, because setting a
## sampler uniform every frame re-uploads the texture binding for no reason.
func _sync_sky(look: Dictionary, k: float) -> void:
	var hour := sim.hour
	if hour != _sky_b:
		_sky_a = _sky_b
		_sky_b = hour
		_sky_mat.set_shader_parameter("sky_a", load(SKIES.get(_sky_a, SKIES["dawn"])))
		_sky_mat.set_shader_parameter("sky_b", load(SKIES.get(_sky_b, SKIES["dawn"])))
		_sky_blend = 0.0
	_sky_blend = minf(1.0, _sky_blend + k)
	_sky_mat.set_shader_parameter("blend", _sky_blend)

	var w: Dictionary = Mood.WEATHERS.get(sim.weather, Mood.WEATHERS["clear"])
	var tint: Color = w["tint"]
	_sky_cloud = lerpf(_sky_cloud, float(SKY_CLOUD.get(sim.weather, 0.0)), k)
	_sky_mat.set_shader_parameter("cloud", _sky_cloud)
	# Weather greys the sky and depth drains it, exactly as they do everything
	# else - the numbers come from the same table the water and the light use.
	_sky_grey = lerpf(_sky_grey, float(w["grey"]) + (1.0 - float(w["grey"])) * _dread * 0.75, k)
	_sky_dark = lerpf(_sky_dark, (1.0 - float(w["light"])) * 0.55 + _dread * 0.45, k)
	_sky_tint = _sky_tint.lerp(tint, k)
	_sky_mat.set_shader_parameter("tint", _sky_tint)
	_sky_mat.set_shader_parameter("grey", _sky_grey)
	_sky_mat.set_shader_parameter("darken", _sky_dark)
	_sky_mat.set_shader_parameter("horizon", look["sky_horizon"])


# --- the grade -------------------------------------------------------------

## THE FILM THE LAKE IS PHOTOGRAPHED ON.
##
## Vignette, grain and a little chromatic aberration, all rising with `dread`.
## This is the cheapest and by a distance the most effective mood tool in the
## project - the geometry, the light and the palette were all doing their jobs
## and the picture still looked CLEAN, which is the one thing this game must not
## look. Nothing here is simulated; it is the camera, and a camera is exactly
## what a game about watching water should feel like it has.
##
## Under the HUD on purpose. It sits on a CanvasLayer BELOW the HUD's, so it
## grades the 3D and leaves the text alone - grain over a price list reads as a
## broken display rather than as atmosphere, and the numbers have to stay
## legible at arm's length on a phone.
func _build_grade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.name = "Grade"
	add_child(layer)

	var sh := Shader.new()
	sh.code = GRADE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("dread", 0.0)
	m.set_shader_parameter("grain", 0.045)
	m.set_shader_parameter("vignette", 0.30)
	m.set_shader_parameter("aberration", 0.0)
	m.set_shader_parameter("lift", Color(0.014, 0.024, 0.026))

	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.material = m
	_grade.name = "Grade"
	layer.add_child(_grade)


const GRADE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float dread = 0.0;
uniform float grain = 0.045;
uniform float vignette = 0.30;
uniform float aberration = 0.0;
uniform vec3 lift : source_color = vec3(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = uv - vec2(0.5);
	float r2 = dot(off, off);

	// Chromatic aberration, radial and only at the edges. Deliberately tiny -
	// past about a pixel and a half it stops reading as a lens and starts
	// reading as a fault in the phone.
	vec3 col;
	if (aberration > 0.0001) {
		vec2 dir = off * aberration * r2;
		col.r = texture(screen, uv + dir).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - dir).b;
	} else {
		col = texture(screen, uv).rgb;
	}

	// Lifted blacks, toward the colour of the water rather than toward grey. A
	// true black on an OLED phone is a HOLE, and a hole reads as the screen
	// being off, not as darkness.
	col += lift * (1.0 - col);

	// Grain. Animated, because static grain is dirt on the lens.
	float n = hash(uv * vec2(1024.0, 1024.0) + fract(TIME) * 91.7) - 0.5;
	// Strongest in the mid-tones, as real film is: none in the highlights, and
	// almost none in the blacks where it would just be noise.
	float mid = 1.0 - abs(dot(col, vec3(0.333)) * 2.0 - 1.0);
	col += n * grain * mid;

	// Vignette last, so nothing above brightens the corners back up.
	float v = smoothstep(0.86, 0.10, r2 * (1.0 + 1.4 * dread));
	col *= mix(1.0, v, vignette);

	COLOR = vec4(col, 1.0);
}
"""


## The grade follows dread, like everything else. The numbers are small: at the
## bottom of the lake the grain is about triple the surface value and the
## vignette has roughly doubled, which is a long way from a filter and is meant
## to be noticed only in the sense that the player stops feeling comfortable.
func _sync_grade(k: float) -> void:
	if _grade == null:
		return
	var m := _grade.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("dread", _dread)
	m.set_shader_parameter("grain", lerpf(0.040, 0.115, _dread))
	m.set_shader_parameter("vignette", lerpf(0.28, 0.66, _dread))
	m.set_shader_parameter("aberration", lerpf(0.0, 0.020, _dread))


## Wood, from the ambientCG plank maps. Albedo is a FLAT colour we choose, so the
## boat still takes its palette from the game rather than from a photograph; the
## normal and roughness carry the grain, the saw marks and the wear, which is
## what a flat colour cannot do and what makes the rail read as timber at the
## thirty centimetres it sits from the camera.
func _wood_mat(albedo: Color, tiling: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 1.0
	m.uv1_scale = tiling
	var n := load("res://assets/tex/wood_normal.jpg")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.85
	var r := load("res://assets/tex/wood_rough.jpg")
	if r != null:
		m.roughness_texture = r
	return m


## Sweep a rectangular cross-section along a path, as one continuous mesh.
##
## Written because the boat needed it and kept because anything long and curved
## in this game wants it. The alternative - a row of short boxes rotated to
## follow the curve - was tried on the hull and reads as floating debris: every
## joint leaves a gap, and every end cap catches the light on its own.
##
## UVs run ACROSS in u and ALONG in v, so a plank texture runs the length of the
## timber rather than wrapping around it.
func _sweep(path: Array[Vector3], width: float, height: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := path.size()

	var run := 0.0
	for i in n:
		var here: Vector3 = path[i]
		var tangent: Vector3
		if i == 0:
			tangent = (path[1] - here)
		elif i == n - 1:
			tangent = (here - path[n - 2])
		else:
			tangent = (path[i + 1] - path[i - 1])
		tangent = tangent.normalized()
		var right := tangent.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.RIGHT
		var up := right.cross(tangent).normalized()
		if i > 0:
			run += here.distance_to(path[i - 1])

		var hw := width * 0.5
		var hh := height * 0.5
		# Four corners, in order, so consecutive rings can be stitched blindly.
		var corners := [
			here - right * hw + up * hh,
			here + right * hw + up * hh,
			here + right * hw - up * hh,
			here - right * hw - up * hh,
		]
		var normals := [up, right, -up, -right]
		for c in 4:
			verts.append(corners[c])
			norms.append(normals[c])
			uvs.append(Vector2(float(c) / 4.0, run))

	for i in n - 1:
		for c in 4:
			var a0 := i * 4 + c
			var a1 := i * 4 + (c + 1) % 4
			var b0 := (i + 1) * 4 + c
			var b1 := (i + 1) * 4 + (c + 1) % 4
			idx.append_array([a0, b0, a1, a1, b0, b1])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


# --- weather you can see ---------------------------------------------------

## RAIN AND MIST, because until now weather was a word in the HUD.
##
## `Mood` made storms darker and greyer and raised the fog, which is real but is
## also exactly what dusk does - so "rain" and "evening" were the same picture
## with different captions. Weather has to be something in the air between the
## player and the water, or the map's promise that the hours and the sky matter
## is a promise about numbers.
##
## Both are GPUParticles3D parented to the CAMERA rig position rather than to the
## world, because the player never travels far enough within a scene for a
## world-anchored volume to be worth its cost - and an unanchored one is the
## classic mistake ambient particles make. Here the boat genuinely is the frame
## of reference: it does not move.
func _build_weather() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.visibility_aabb = AABB(Vector3(-9, -3, -3), Vector3(18, 14, 22))
	_rain.local_coords = false
	var rp := ParticleProcessMaterial.new()
	rp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rp.emission_box_extents = Vector3(8.0, 0.5, 10.0)
	rp.direction = Vector3(0.12, -1.0, 0.0)
	rp.spread = 3.0
	rp.initial_velocity_min = 13.0
	rp.initial_velocity_max = 17.0
	rp.gravity = Vector3(0, -9.0, 0)
	rp.scale_min = 0.7
	rp.scale_max = 1.3
	_rain.process_material = rp
	# A long thin quad, unshaded and barely there. Rain that is LIT reads as
	# sparks; rain is a smear of the sky, so it takes its colour from the fog and
	# nothing else in the frame lights it.
	var rq := QuadMesh.new()
	rq.size = Vector2(0.012, 0.42)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	rm.albedo_color = Color(0.78, 0.84, 0.88, 0.30)
	rm.vertex_color_use_as_albedo = false
	_rain.draw_pass_1 = rq
	_rain.material_override = rm
	_rain.position = Vector3(0, 7.0, 6.0)
	_rain.emitting = false
	add_child(_rain)

	_mist = GPUParticles3D.new()
	_mist.name = "Mist"
	_mist.amount = 46
	_mist.lifetime = 13.0
	_mist.visibility_aabb = AABB(Vector3(-16, -2, -4), Vector3(32, 10, 30))
	_mist.local_coords = false
	var mp := ParticleProcessMaterial.new()
	mp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mp.emission_box_extents = Vector3(13.0, 0.35, 11.0)
	mp.direction = Vector3(1.0, 0.06, 0.0)
	mp.spread = 22.0
	mp.initial_velocity_min = 0.25
	mp.initial_velocity_max = 0.75
	mp.gravity = Vector3.ZERO
	mp.scale_min = 5.0
	mp.scale_max = 11.0
	# Fades in and out over its life, so nothing ever pops.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	mp.alpha_curve = ct
	_mist.process_material = mp
	var mq := QuadMesh.new()
	mq.size = Vector2(1.0, 0.55)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = Color(0.80, 0.83, 0.82, 0.055)
	_mist.draw_pass_1 = mq
	_mist.material_override = mm
	_mist.position = Vector3(0, 0.55, 9.0)
	_mist.emitting = false
	add_child(_mist)


## Rain falls when it is raining. Mist sits on the water in fog - and, more
## quietly, in the deep, where it is the one thing in the picture that behaves
## like the lake is exhaling.
func _sync_weather(look: Dictionary, k: float) -> void:
	if _rain == null or _mist == null:
		return
	var wet := 0.0
	match sim.weather:
		"rain": wet = 0.62
		"storm": wet = 1.0
		_: wet = 0.0
	_rain.emitting = wet > 0.01
	if _rain.emitting:
		_rain.amount_ratio = wet
		var rm := _rain.material_override as StandardMaterial3D
		if rm != null:
			var fogc: Color = look["fog_color"]
			rm.albedo_color = Color(fogc.r, fogc.g, fogc.b, 0.16 + 0.22 * wet)

	var haze := 0.0
	if sim.weather == "fog":
		haze = 1.0
	elif sim.weather == "overcast":
		haze = 0.25
	haze = maxf(haze, _dread * 0.55)
	_mist.emitting = haze > 0.02
	if _mist.emitting:
		_mist.amount_ratio = clampf(haze, 0.05, 1.0)
		var mm := _mist.material_override as StandardMaterial3D
		if mm != null:
			var fogc2: Color = look["fog_color"]
			mm.albedo_color = Color(fogc2.r, fogc2.g, fogc2.b, 0.030 + 0.055 * haze)


## `_sweep` with a width that changes along the path. Split out rather than
## folded in, because the hull wants a constant section and a plant wants a
## taper, and one function doing both by flag reads worse than two.
func _sweep_tapered(path: Array[Vector3], w0: float, w1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := path.size()
	for i in n:
		var t := float(i) / float(n - 1)
		var here: Vector3 = path[i]
		var tangent: Vector3
		if i == 0:
			tangent = path[1] - here
		elif i == n - 1:
			tangent = here - path[n - 2]
		else:
			tangent = path[i + 1] - path[i - 1]
		tangent = tangent.normalized()
		var right := tangent.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.RIGHT
		var hw := lerpf(w0, w1, t) * 0.5
		verts.append(here - right * hw)
		verts.append(here + right * hw)
		var nrm := right.cross(tangent).normalized()
		norms.append(nrm)
		norms.append(nrm)
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
	for i in n - 1:
		var a0 := i * 2
		var a1 := i * 2 + 1
		var b0 := (i + 1) * 2
		var b1 := (i + 1) * 2 + 1
		idx.append_array([a0, b0, a1, a1, b0, b1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
