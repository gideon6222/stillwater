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
var _float: Node3D
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

# --- the boat's pose on the water, and where the player is looking ----------
var _look_yaw := 0.0          ## radians, where the view IS
var _look_pitch := 0.0
var _look_yaw_want := 0.0     ## where the finger has asked it to be
var _look_pitch_want := 0.0

## Player setting, 1.0 being the tuned default. Exposed because the research is
## unanimous that look sensitivity has to be adjustable - it is the one control
## value where individual preference genuinely differs, and no default is right
## for everyone.
var look_sensitivity := 1.0
var _cast_yaw := 0.0          ## the heading the current cast was made on
var _boat_pose := Transform3D.IDENTITY
var _drag_from := Vector2.ZERO
var _drag_moved := 0.0
var _touching := false
var _boat_heave := 0.0
var _boat_pitch := 0.0
var _boat_roll := 0.0
var _boat_time := 0.0
var _boat_dt := 1.0 / 60.0
var _grade: ColorRect
var _rain: GPUParticles3D
var _mist: GPUParticles3D
var _reeds: Node3D
var _save_due := 0.0
var _sounder: Control
var _action: Button
var _use: Button
var _title: TitleScreen
var _intro: Intro
var _things: Array[Dictionary] = []
var _looking_at := ""
var _splash: GPUParticles3D
var _ring: MeshInstance3D
var _shake := 0.0
var _shake_seed := 0.0
var _freeze_left := 0.0
var _hint: Label

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

	_float = _build_float()
	add_child(_float)

	_fish = _build_fish()
	add_child(_fish)

	_build_impact()
	_build_weather()
	_build_grade()
	_build_hud()
	_build_sequence_line()
	_build_title()


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
	# Generated, not typed twice - see the note on WAVES.
	sh.code = (WATER_SHADER
		.replace("__WAVE_VERT__", _wave_glsl("xz"))
		.replace("__WAVE_TAPS__",
			_wave_glsl_sum("a", "xz + vec2(e,0.0)")
			+ _wave_glsl_sum("b", "xz - vec2(e,0.0)")
			+ _wave_glsl_sum("c", "xz + vec2(0.0,e)")
			+ _wave_glsl_sum("d", "xz - vec2(0.0,e)")))
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


## THE SWELL, ONCE, and both the water and the boat read it.
##
## `[dir_x, dir_z, steepness, wavelength, speed]` per wave. The GLSL in the water
## shader is GENERATED from this array and `_wave_offset` below evaluates the
## same sum on the CPU, so the hull rides the surface it is actually floating on.
##
## Two copies of these numbers would be the worst kind of bug: a boat rocking
## slightly out of time with its own water reads as broken in a way nobody can
## name, and it would drift the first time either was tuned.
const WAVES := [
	[1.0, 0.35, 0.14, 5.10, 1.00],
	[-0.7, 0.90, 0.10, 2.90, 1.25],
]


## The Gerstner sum at a world point. Mirrors the shader function exactly.
func _wave_offset(x: float, z: float, t: float) -> Vector3:
	var o := Vector3.ZERO
	for w in WAVES:
		var dx: float = w[0]
		var dz: float = w[1]
		var steep: float = w[2]
		var wlen: float = w[3]
		var speed: float = w[4]
		var k := TAU / wlen
		var c := sqrt(9.8 / k)
		var d := Vector2(dx, dz).normalized()
		var f := k * (d.x * x + d.y * z - c * speed * t)
		var a := steep / k
		o += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return o


## The wave sum as GLSL, so the shader and `_wave_offset` cannot disagree.
static func _wave_glsl(coord: String) -> String:
	var out := ""
	for w in WAVES:
		out += "\to += gerstner(vec2(%.4f, %.4f), %.4f, %.4f, %.4f, %s, t);\n" % [
			w[0], w[1], w[2], w[3], w[4], coord]
	return out


## The same sum, as an expression that adds into `dst`, for the normal taps.
static func _wave_glsl_sum(dst: String, coord: String) -> String:
	var parts: Array[String] = []
	for w in WAVES:
		parts.append("gerstner(vec2(%.4f, %.4f), %.4f, %.4f, %.4f, %s, t)" % [
			w[0], w[1], w[2], w[3], w[4], coord])
	return "\tvec3 %s = %s;\n" % [dst, " + ".join(parts)]


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
__WAVE_VERT__
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
__WAVE_TAPS__
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
	# A REAL HULL, closed, with a floor you cannot see through.
	#
	# Gideon: "can you use a full model for the boat? I can see right through to
	# the water." Correct - there were two gunwales and a strake and nothing
	# under them, so the bottom of the frame was lake where the boat should be.
	#
	# An earlier build had gone the other way and put a solid box under the
	# camera, and the note from then still stands: a lit top face becomes the
	# brightest object on screen and eats a third of a portrait frame - a picture
	# of a plank. The resolution is that a hull is neither of those. It is a
	# U-shaped cross section swept bow to stern, seen from INSIDE, so what fills
	# the bottom of the frame is a floor with planks and ribs and a curved side
	# rising away on each hand. That is a place to be sitting rather than a slab.
	#
	# `cull_disabled` on the skin so it reads from inside as well as out, which
	# is what lets one swept surface be both the hull and the interior.
	var rail_mat := _wood_mat(Color(0.30, 0.22, 0.155), Vector3(1.0, 4.0, 1.0))
	var hull_mat := _wood_mat(Color(0.235, 0.175, 0.120), Vector3(2.0, 3.0, 1.0))
	hull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_mat := _wood_mat(Color(0.285, 0.215, 0.145), Vector3(3.0, 2.0, 1.0))
	floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var hull := MeshInstance3D.new()
	hull.mesh = _build_hull_mesh()
	hull.material_override = hull_mat
	hull.name = "Hull"
	_boat.add_child(hull)

	# Floor planks, laid athwartships and slightly proud of the skin so they
	# catch the light separately. This is the surface the player is actually
	# looking down at, so it is the one that has to have boards in it.
	for i in 9:
		var t := float(i) / 8.0
		var z: float = -0.75 + t * 2.55
		# Just inside the skin at that station. It was 1.62 - and since the box is
		# then twice that wide, every plank was over three times the beam and
		# poking clean through both sides of the boat. Invisible from the one seat
		# the player ever occupies, which is exactly the sort of thing that ships.
		var w: float = _hull_half_width(z) * 0.92
		if w < 0.10:
			continue
		var plank := MeshInstance3D.new()
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(w * 2.0, 0.030, 0.255)
		plank.mesh = pmesh
		plank.material_override = floor_mat
		plank.position = Vector3(0.0, _hull_floor_y(z) + 0.020, z)
		_boat.add_child(plank)

	# Ribs, up the inside of each side. The detail that says somebody built this.
	for i in 4:
		var z2: float = -0.45 + float(i) * 0.72
		var hw: float = _hull_half_width(z2)
		if hw < 0.14:
			continue
		for side in [-1.0, 1.0]:
			var rib := MeshInstance3D.new()
			var rmesh := BoxMesh.new()
			rmesh.size = Vector3(0.045, 0.36, 0.070)
			rib.mesh = rmesh
			rib.material_override = rail_mat
			rib.position = Vector3(side * (hw - 0.035), _hull_floor_y(z2) + 0.16, z2)
			rib.rotation_degrees = Vector3(0, 0, side * -11.0)
			_boat.add_child(rib)

	# The gunwale, capping the top edge of the skin on each side. Swept, because
	# a chain of short boxes was tried here first and read as floating debris -
	# every joint leaves a gap and every end cap catches the light on its own.
	for side in [-1.0, 1.0]:
		var rail_pts: Array[Vector3] = []
		for i in 15:
			var t := float(i) / 14.0
			var z: float = -0.80 + t * 3.05
			rail_pts.append(Vector3(side * _hull_half_width(z), _hull_rim_y(z), z))
		var rail := MeshInstance3D.new()
		rail.mesh = _sweep(rail_pts, 0.105, 0.085)
		rail.material_override = rail_mat
		rail.name = "Gunwale"
		_boat.add_child(rail)

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
	rope.position = Vector3(-0.34, _hull_rim_y(-0.16) + 0.030, -0.16)
	rope.name = "Rope"
	rope.rotation_degrees = Vector3(4, 18, 0)
	_boat.add_child(rope)

	_build_rod()

	_update_rod_tip()

	# The fish's wake. A thin slab on the surface that points where the fish is
	# bearing, and the only thing on screen that tells the player a run has
	# started - which is deliberate. It appears during the TELL, before the run
	# does, so a player who is watching the water gets their warning from the
	# water rather than from a number.
	# A TAPERED, FADING V - not a glowing bar.
	#
	# The last obviously crude thing in the scene: a 10 cm box with emission on
	# it, lying on the water. A wake is a disturbance, so it wants soft edges and
	# a shape that says which way the fish is going; a hard-edged lit slab says
	# "untextured primitive" from the first frame.
	#
	# Still generated, because a wake is not an object - it is a mark on the
	# surface whose length is `fish_distance`, which is gameplay state.
	_wake = MeshInstance3D.new()
	_wake.mesh = _build_wake_mesh()
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.vertex_color_use_as_albedo = true
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wmat.albedo_color = Color(0.95, 0.96, 0.94, 0.85)
	_wake.material_override = wmat
	_wake.visible = false
	_wake.name = "Wake"
	add_child(_wake)

	_build_shore()
	_build_props()
	_build_things()
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


## The rod, as a chain of segments that BENDS rather than a stick that tilts.
##
## Each link is still a transform carrier and the bend logic is untouched; what
## changed is that the link now holds a TAPERED CYLINDER instead of a box, plus
## the parts that make a rod a rod - a cork grip, a reel seat and a reel, and
## line guides standing off the blank at every joint.
##
## The guides matter more than they look. A rod is recognised by its silhouette
## against the sky, and a bare tapered stick is a stick; the little rings are
## what the eye reads as tackle. They cost five meshes.
func _build_rod() -> void:
	var blank := _mat(Color(0.115, 0.105, 0.100), 0.34)
	blank.metallic = 0.22
	var whipping := _mat(Color(0.50, 0.36, 0.14), 0.55)
	var metal := _mat(Color(0.62, 0.63, 0.64), 0.24)
	metal.metallic = 0.85
	var cork := _mat(Color(0.68, 0.55, 0.36), 0.92)

	var parent: Node3D = _boat
	for i in ROD_SEGMENTS:
		# The link itself carries no mesh - it is the transform the bend writes
		# to. Keeping it that way is what let the whole instrument be rebuilt
		# without touching `_sync_rod` or `rod_bend_degrees`.
		var seg := MeshInstance3D.new()
		var r0 := lerpf(0.0165, 0.0060, float(i) / float(ROD_SEGMENTS))
		var r1 := lerpf(0.0165, 0.0060, float(i + 1) / float(ROD_SEGMENTS))
		var shaft := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.height = ROD_SEG_LENGTH
		# +Y becomes +Z under the rotation below, so `top` is the tip end.
		cm.top_radius = r1
		cm.bottom_radius = r0
		cm.radial_segments = 10
		cm.rings = 1
		shaft.mesh = cm
		shaft.rotation_degrees = Vector3(90, 0, 0)
		shaft.material_override = blank
		seg.add_child(shaft)

		if i == 0:
			seg.position = Vector3(0.42, _hull_rim_y(1.30) + 0.10, 1.30)
			seg.rotation_degrees = Vector3(ROD_REST, 0, 9)
			_rod = seg
			seg.name = "Rod"

			# Cork grip, below the reel seat, where a hand goes.
			var grip := MeshInstance3D.new()
			var gm := CylinderMesh.new()
			gm.height = 0.20
			gm.top_radius = 0.026
			gm.bottom_radius = 0.023
			gm.radial_segments = 10
			grip.mesh = gm
			grip.rotation_degrees = Vector3(90, 0, 0)
			grip.position = Vector3(0, 0, -0.145)
			grip.material_override = cork
			seg.add_child(grip)

			# The reel seat, and a reel hanging under it. A spinning reel sits
			# BELOW the blank, which is also why it never crosses the water in
			# the frame - it hangs into the boat.
			var seat := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.height = 0.075
			sm.top_radius = 0.027
			sm.bottom_radius = 0.027
			sm.radial_segments = 10
			seat.mesh = sm
			seat.rotation_degrees = Vector3(90, 0, 0)
			seat.position = Vector3(0, 0, -0.030)
			seat.material_override = metal
			seg.add_child(seat)

			var stem := MeshInstance3D.new()
			var stm := BoxMesh.new()
			stm.size = Vector3(0.014, 0.055, 0.020)
			stem.mesh = stm
			stem.position = Vector3(0, -0.043, -0.030)
			stem.material_override = metal
			seg.add_child(stem)

			var spool := MeshInstance3D.new()
			var spm := CylinderMesh.new()
			spm.height = 0.042
			spm.top_radius = 0.040
			spm.bottom_radius = 0.040
			spm.radial_segments = 14
			spool.mesh = spm
			spool.rotation_degrees = Vector3(0, 0, 90)
			spool.position = Vector3(0, -0.088, -0.030)
			spool.material_override = metal
			seg.add_child(spool)

			var handle := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.height = 0.058
			hm.top_radius = 0.007
			hm.bottom_radius = 0.007
			hm.radial_segments = 8
			handle.mesh = hm
			handle.rotation_degrees = Vector3(0, 0, 90)
			handle.position = Vector3(0.050, -0.088, -0.030)
			handle.material_override = cork
			seg.add_child(handle)
		else:
			seg.position = Vector3(0.0, 0.0, ROD_SEG_LENGTH)
			seg.name = "RodSeg%d" % i

		# A line guide at the start of every link past the butt, standing off the
		# blank on a short foot. Ring outside, whipping where it is bound on.
		if i > 0:
			var foot := MeshInstance3D.new()
			var fm2 := BoxMesh.new()
			fm2.size = Vector3(0.006, 0.016, 0.030)
			foot.mesh = fm2
			foot.position = Vector3(0, -0.014, -ROD_SEG_LENGTH * 0.5 + 0.02)
			foot.material_override = whipping
			seg.add_child(foot)

			var ring := MeshInstance3D.new()
			var tm3 := TorusMesh.new()
			tm3.inner_radius = lerpf(0.019, 0.008, float(i) / float(ROD_SEGMENTS - 1))
			tm3.outer_radius = tm3.inner_radius + 0.004
			tm3.rings = 6
			tm3.ring_segments = 10
			ring.mesh = tm3
			ring.rotation_degrees = Vector3(90, 0, 0)
			ring.position = Vector3(0, -0.014 - tm3.outer_radius, -ROD_SEG_LENGTH * 0.5 + 0.02)
			ring.material_override = metal
			seg.add_child(ring)

		parent.add_child(seg)
		_rod_chain.append(seg)
		parent = seg

	# The tip ring, which is the one the line actually leaves from.
	var tip_ring := MeshInstance3D.new()
	var ttm := TorusMesh.new()
	ttm.inner_radius = 0.007
	ttm.outer_radius = 0.011
	ttm.rings = 6
	ttm.ring_segments = 10
	tip_ring.mesh = ttm
	tip_ring.rotation_degrees = Vector3(90, 0, 0)
	tip_ring.position = Vector3(0, 0, ROD_SEG_LENGTH * 0.5)
	tip_ring.material_override = metal
	_rod_chain[_rod_chain.size() - 1].add_child(tip_ring)


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
	var row := Species.by_id(id)
	# **THE WRONG ONES ARE THE SAME GENERATOR WITH WORSE NUMBERS.**
	#
	# `wrong` has been in the species data since the table was written and had
	# never once changed anything on screen - six species flagged as not-right
	# and all six drawn as ordinary fish. That is the whole reason the shape of a
	# fish lives in data: a wrong fish is not a new model or a new code path, it
	# is these fields pushed past the range a real fish uses.
	#
	# Nothing is ever remarked on. The logbook prints the note in the keeper's
	# hand and the game says nothing at all.
	var wrong: bool = bool(row.get("wrong", false))
	var long: float = look["long"]
	var deep: float = look["deep"]
	if wrong:
		# Too long in the body and too thin through it - which is exactly what
		# Edith Moss writes in the book at sixty-eight metres, forty years before
		# the player reads it.
		long *= 1.22
		deep *= 0.86
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
			if wrong:
				# The counter-shading gives out. A real fish is dark above and
				# pale below because that is what light in water does to a thing
				# that lives in it; one that is evenly coloured all round reads
				# as WRONG long before anyone works out which rule it broke.
				down = lerpf(down, 0.45, 0.55)
			# Cubed, so the dark holds most of the upper flank and the pale is
			# confined to the underside. A linear blend puts the midtone across
			# the widest part of the body, which is exactly where the eye looks,
			# and the fish came out as one pale tube under a bright dawn.
			var c := back.lerp(belly, pow(down, 3.1))
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

	# A SECOND PAIR OF FINS on the worst of them. Not on every wrong fish - the
	# ones in Old Town are subtly off and the ones in the Quarry are not subtle -
	# so `wrong` alone does not earn this; being deep as well does.
	if wrong and float(row.get("min_depth", 0.0)) >= 80.0:
		for side3 in [-1.0, 1.0]:
			var extra := _fin([
				Vector3(0, 0, -length * 0.10),
				Vector3(0, half_h * 0.50, -length * 0.24),
				Vector3(0, -half_h * 0.22, -length * 0.26),
			], fmat, "SecondPair")
			extra.rotation_degrees = Vector3(0, 0, side3 * 74.0)
			extra.position = Vector3(side3 * half_w * 0.80, -half_h * 0.20, 0)
			_fish.add_child(extra)

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
		if wrong:
			# Flat and matte. An eye with no highlight in it is the single
			# cheapest way to make something look dead, which is why every
			# taxidermist puts a glass one in.
			emat.metallic = 0.0
			emat.roughness = 0.95
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
	# BELOW the sounder, not across it. At 400 the prompt ran straight through
	# the depth trace - the one instrument the player is supposed to be reading.
	_prompt.offset_top = 880
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

	# THE ACTION BUTTON, and the reason it exists at all.
	#
	# Gideon: "there is not option to pull the line back in or recast". There
	# was - tapping during a wait called `reel_in` - but nothing on screen ever
	# said so, and that same tap sets the hook during a nibble. **An action with
	# no affordance, overloaded onto the gesture used for something else, is an
	# action that does not exist.**
	#
	# So the verb the player currently has is now written on a button, in words,
	# at all times. It is deliberately NOT the main input: tapping the water is
	# still how you fish, and this is the way out and the way back.
	# ROUND, WARM AND BIG, in the corner a right thumb rests in.
	#
	# Gideon: "it looks kind of out of place to have the cast button next to the
	# other menu style buttons." Exactly right, and the fault was categorical
	# rather than cosmetic: the game's VERB and the game's NAVIGATION were drawn
	# in one visual language and sat side by side, so casting read as a menu
	# item. They are different kinds of thing and now they look it - this is a
	# warm circle, the rooms are cool flat text, and they are at opposite ends of
	# the bar.
	#
	# 260 px on a 1080 base is about 15 mm on the phone, comfortably over the
	# 48 dp Android minimum, and it sits in the bottom-right "green zone" every
	# thumb-reach study puts the primary action in.
	_action = Button.new()
	_action.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action.offset_left = -ACTION_SIZE - 46
	_action.offset_right = -46
	_action.offset_top = -ACTION_SIZE - 150 - SAFE_BOTTOM
	_action.offset_bottom = -150 - SAFE_BOTTOM
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 36)
	var abox := StyleBoxFlat.new()
	abox.bg_color = Color(0.16, 0.115, 0.075, 0.90)
	abox.border_color = Color(0.88, 0.72, 0.40, 0.62)
	abox.set_border_width_all(3)
	abox.set_corner_radius_all(int(ACTION_SIZE * 0.5))
	_action.add_theme_stylebox_override("normal", abox)
	_action.add_theme_stylebox_override("hover", abox)
	var apress := abox.duplicate() as StyleBoxFlat
	apress.bg_color = Color(0.36, 0.26, 0.14, 0.96)
	apress.border_color = Color(0.98, 0.86, 0.56, 0.92)
	_action.add_theme_stylebox_override("pressed", apress)
	_action.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	_action.add_theme_color_override("font_hover_color", Color(0.96, 0.90, 0.76))
	_action.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	_action.name = "Action"
	_action.pressed.connect(_on_action)
	_ui.add_child(_action)

	# USE, above the action and only when there is something to use. Same corner,
	# same thumb, deliberately smaller and cooler - it is the second verb, not a
	# rival to the first.
	_use = Button.new()
	_use.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_use.offset_left = -ACTION_SIZE - 46
	_use.offset_right = -46
	_use.offset_top = -ACTION_SIZE - 262 - SAFE_BOTTOM
	_use.offset_bottom = -ACTION_SIZE - 158 - SAFE_BOTTOM
	_use.focus_mode = Control.FOCUS_NONE
	_use.add_theme_font_size_override("font_size", 30)
	var ubox := StyleBoxFlat.new()
	ubox.bg_color = Color(0.05, 0.09, 0.10, 0.86)
	ubox.border_color = Color(0.93, 0.90, 0.82, 0.34)
	ubox.set_border_width_all(2)
	ubox.set_corner_radius_all(52)
	_use.add_theme_stylebox_override("normal", ubox)
	_use.add_theme_stylebox_override("hover", ubox)
	var upress := ubox.duplicate() as StyleBoxFlat
	upress.bg_color = Color(0.17, 0.25, 0.26, 0.94)
	_use.add_theme_stylebox_override("pressed", upress)
	_use.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	_use.add_theme_color_override("font_hover_color", Color(0.93, 0.90, 0.82))
	_use.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	_use.visible = false
	_use.name = "Use"
	_use.pressed.connect(_on_use)
	_ui.add_child(_use)

	# A single line of what to do, under the action. Fades out once the player
	# has done the thing a few times - a prompt that never leaves is a prompt
	# the player reads instead of the water.
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 40
	_hint.offset_right = -40
	_hint.offset_top = -244 - SAFE_BOTTOM
	_hint.offset_bottom = -196 - SAFE_BOTTOM
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82, 0.62))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.name = "Hint"
	_ui.add_child(_hint)

	# THE DOCK, and it only exists when the line is in.
	#
	# It sits along the bottom, which is also where a thumb lands to reel - so if
	# it were ever visible during a fight the player would open the shop trying
	# to land a sturgeon. `_sync_bars` hides it in every state but IDLE, and that
	# is not a nicety: the alternative is a button under the one gesture the game
	# asks for most.
	# Navigation lives bottom-LEFT and is deliberately quiet: flat, unboxed,
	# low contrast. It is read once every few minutes; the action is pressed
	# every few seconds. Giving them equal weight was the bug.
	_dock = HBoxContainer.new()
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dock.offset_left = 34
	_dock.offset_right = 640
	_dock.offset_top = -150 - SAFE_BOTTOM
	_dock.offset_bottom = -46 - SAFE_BOTTOM
	_dock.add_theme_constant_override("separation", 10)
	_dock.name = "Dock"
	_ui.add_child(_dock)
	for pair in [[Menus.SHED, "Shed"], [Menus.MAP, "Lake"], [Menus.LOG, "Log"],
			[Menus.KIT, "Kit"]]:
		var screen: String = pair[0]
		var b := _dock_button(str(pair[1]))
		b.pressed.connect(func() -> void: _open(screen))
		_dock.add_child(b)

	_load_game()

	_wire_sim_signals()

	_audio = Audio.new()
	_audio.name = "Audio"
	add_child(_audio)
	_audio.setup(sim)
	_audio.set_muted(sim.sound_muted)
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
	# Seed the room from whatever the save restored, then push it straight back
	# out, so the first frame already honours the player's own settings.
	_menus.sensitivity = sim.sensitivity
	_menus.sound_muted = sim.sound_muted
	look_sensitivity = sim.sensitivity
	_menus.changed.connect(func() -> void:
		# The Kit owns the settings; this is where they reach the things that
		# actually use them. Neither the camera nor the mixer needs to know a
		# menu exists.
		look_sensitivity = _menus.sensitivity
		sim.sensitivity = _menus.sensitivity
		sim.sound_muted = _menus.sound_muted
		if _audio != null:
			_audio.set_muted(_menus.sound_muted)
			_audio.play("coin", -6.0)
		_want_save())


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
	# The title counts as "not playing" for everything the HUD does. It was not,
	# and the first screen of the game showed a purse, a depth sounder and a
	# "Reel in" button behind the word STILLWATER.
	var in_room := _hud_is_down()
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
	# What is under the aim, and therefore what the second button offers.
	var thing := _thing_under_aim()
	_looking_at = str(thing.get("id", "")) if not thing.is_empty() else ""
	if _use != null:
		_use.visible = _looking_at != "" and not in_room
		if _use.visible:
			_use.text = "Use"

	if _action != null:
		var label := _action_for_state()
		_action.visible = label != "" and not in_room
		_action.text = label
	if _hint != null:
		_hint.visible = not in_room
		# Priority: something just happened > something is under the aim > the
		# standing instruction. One line, three jobs, and the most recent thing
		# always wins - a hint that keeps saying the tutorial over the top of a
		# thing the player is actively pointing at is a hint nobody reads.
		if _intro != null and not _intro.done():
			# The intro owns the line while it is running. It is teaching the
			# thing the other hints describe, so letting both write here would
			# be two voices saying the same lesson differently.
			_hint.text = _intro.line()
		elif _hint_hold > 0.0:
			_hint.text = _hint_text
		elif _looking_at != "":
			for t in _things:
				if t["id"] == _looking_at:
					_hint.text = (t["look"] as Callable).call()
					break
		else:
			_hint.text = _hint_for_state()
	if _sounder != null:
		# Visibility HERE, never inside the draw callback - see the note above.
		_sounder.visible = sim.econ.has_sounder and not in_room
		_sounder.queue_redraw()


func _dock_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.07, 0.08, 0.55)
	box.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var press := box.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.13, 0.19, 0.20, 0.85)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 0.72))
	b.add_theme_color_override("font_hover_color", Color(0.90, 0.88, 0.80, 0.72))
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
## DRAG LOOKS, STILL-HOLD CASTS, TAP TAPS.
##
## One finger has to carry three verbs, and the discriminator is MOVEMENT rather
## than time - which is the only one that works here, because charging a cast is
## itself a long press. A held finger that has not moved is loading a cast; the
## moment it travels past `LOOK_SLOP` it becomes a look and the charge is
## abandoned. Quick taps never travel, so the fight is untouched.
##
## Getting this wrong in the other direction - time-based - would mean the player
## cannot look around without accidentally casting, which is exactly the kind of
## thing that reads as "clunky" without being nameable.
## Diameter of the round action button, on the 1080-wide base canvas.
const ACTION_SIZE := 260

## Clearance left under everything for the Android gesture bar.
##
## A fixed number rather than `DisplayServer.get_display_safe_area()`, because
## that returns the WINDOW on a desktop run and would move the whole HUD between
## the phone and every screenshot taken here - which is exactly the class of bug
## that shipped when controls were positioned against a literal 1920. 54 px on
## the 1080 base is a little over the gesture bar on an S26 Ultra, and costs
## nothing anywhere else.
const SAFE_BOTTOM := 54

const LOOK_SLOP := 14.0        ## pixels before a press becomes a look

## HOW FAR A SWIPE TURNS YOU, expressed as the thing that can be judged: what
## fraction of the screen you have to drag to look from one shoulder to the
## other. Mobile convention is roughly a full screen width per 90-180 degrees;
## the first version was 0.0042 rad/px, which turned the full 120-degree range in
## a QUARTER of a screen width. The note was "the turning is really fast", and it
## was - by about four times.
##
## Derived rather than typed, so the sensitivity and the limits cannot drift
## apart the way two hand-tuned constants do.
const LOOK_YAW_LIMIT := 1.05   ## how far round you can turn in the seat (60 deg)
const LOOK_PITCH_LIMIT := 0.40
const LOOK_SWEEP := 1.15       ## screen widths to travel the whole yaw range
const LOOK_BASE_WIDTH := 1080.0

## How hard the view chases the finger. Below 1 the camera eases in behind the
## drag, which removes the twitch that raw pixel deltas give on a touch screen -
## a finger reports in jumps, and a camera bolted straight to those jumps reads
## as cheap however correct the sensitivity is.
const LOOK_FOLLOW := 16.0

func _on_cast_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_apply_look((event as InputEventScreenDrag).relative)
		_cast_area.accept_event()
		return
	if event is InputEventMouseMotion:
		if _touching:
			_apply_look((event as InputEventMouseMotion).relative)
			_cast_area.accept_event()
		return

	var pressed := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
		at = (event as InputEventMouseButton).position
	else:
		return

	if pressed and _in_sequence:
		# Any touch cuts the sequence, and does nothing else with that touch -
		# skipping and casting on the same press would fire a cast the player
		# never asked for.
		_skip_sequence()
		_cast_area.accept_event()
		return

	if pressed:
		_touching = true
		_drag_from = at
		_drag_moved = 0.0
		match sim.state:
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				sim.hold_cast()
				_charging = true
			_:
				sim.tap()
	else:
		_touching = false
		if _charging:
			_charging = false
			if _drag_moved > LOOK_SLOP:
				# It turned out to be a look. Put the rod down rather than firing
				# a cast the player never asked for.
				sim.cancel_cast()
			else:
				if _audio != null and sim.state == Sim.CHARGING:
					_audio.play("cast", -5.0)
				# The cast goes WHERE YOU ARE LOOKING. Aim is the whole reason
				# the look control earns its place - without it, turning the
				# head is scenery.
				_cast_yaw = _look_yaw
				sim.release_cast()
	_cast_area.accept_event()


func _apply_look(rel: Vector2) -> void:
	_drag_moved += rel.length()
	if _charging and _drag_moved > LOOK_SLOP:
		_charging = false
		# Abandon the charge the instant this becomes a look, so the rod does not
		# sit loaded behind a camera move.
		sim.cancel_cast()
	if not _touching:
		return
	if _drag_moved <= LOOK_SLOP:
		return
	var speed := (LOOK_YAW_LIMIT * 2.0) / (LOOK_BASE_WIDTH * LOOK_SWEEP) * look_sensitivity
	_look_yaw_want = clampf(_look_yaw_want - rel.x * speed, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
	# Pitch gets less range than yaw and the same rate, because a seated person
	# turns their head much further than they tip it.
	_look_pitch_want = clampf(_look_pitch_want - rel.y * speed,
		-LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)


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
	# HIT STOP freezes the PICTURE, never the rules. The simulation keeps its own
	# time either way, so the golden test and the phone see the same game.
	if _freeze_left > 0.0:
		_freeze_left -= dt
		dt *= 0.12
	_shake = maxf(0.0, _shake - dt * 3.4)
	_hint_hold = maxf(0.0, _hint_hold - dt)
	if _title != null:
		_title.tick(dt)
	_sync_sequence(dt)
	_sync_intro(dt)
	var lk := 1.0 - exp(-LOOK_FOLLOW * dt)
	_look_yaw = lerpf(_look_yaw, _look_yaw_want, lk)
	_look_pitch = lerpf(_look_pitch, _look_pitch_want, lk)
	_sync_ring(dt)
	_boat_dt = dt
	_boat_time += dt
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
	# PAST THE TITLE. `freeze` means "put the game in a known state and let me
	# drive it", and a title screen is not part of that state - leaving it up
	# hid the whole HUD from every test that checks the HUD. A harness that has
	# to know about the front door is a harness testing the wrong thing.
	if _title != null:
		_title.skip()
	# And no cinematic. `freeze` means "the game, now" - a camera on rails is
	# not the state any test wants to measure.
	_in_sequence = false
	_seq.running = false
	_gate_open = 1.0
	if _seq_line != null:
		_seq_line.text = ""
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
	# FIRST, because everything below positions against it - the lure, the line,
	# the fish, the wake and the camera all live on the boat. Establishing the
	# pose halfway down meant `out` was computed against last frame's boat and
	# the camera against this one, and the float drifted a few millimetres off
	# the end of its own line every frame.
	_sync_boat_pose()
	_sync_rod()
	var out := lure_world_position()

	# Transform3D.looking_at rather than Node3D.look_at. The node method
	# requires the node to be inside the tree and errors if it is not - which is
	# exactly the headless case, because add_child() during
	# SceneTree._initialize() does not put anything in the tree until the first
	# frame. This is pure maths and works anywhere.
	# Seated in the stern, looking out over the bow. High enough that the deck is
	# a foreground edge rather than a third of the picture, and aimed so the
	# horizon sits in the upper third - the water is the subject, and in portrait
	# there is not room for both a lot of sky and a lot of hull.
	# A SEQUENCE OWNS THE CAMERA WHILE ONE IS RUNNING.
	#
	# The whole title and both intros are camera moves over the real scene, so
	# there is no separate menu world to keep in step with this one - the water,
	# the sky and the hour are already right because they are the same water,
	# sky and hour. It also means the hand-over at the end is invisible: the last
	# shot rests exactly on the seat the player is about to be given.
	if _in_sequence:
		# The camera goes on rails and NOTHING ELSE IS SKIPPED. An early return
		# here meant the rest of `_sync` never ran during a sequence - so the
		# HUD, which stands down on exactly that condition, was never told to.
		# The title showed a purse and a Cast button over the gate.
		_cam.transform = Transform3D(Basis.IDENTITY, _seq_at).looking_at(_seq_look, Vector3.UP)
	else:
		_sync_play_camera(out)

	_float.position = out
	_float.visible = sim.state != Sim.IDLE and sim.state != Sim.CHARGING 		and sim.state != Sim.HOLDING and not _in_sequence
	_draw_line_between(_rod_tip, out)
	_line.visible = _float.visible

	_sync_wake(out)
	_sync_fish()
	_write_readout()
	_sync_bars()


## The camera during play: riding the boat, riding the water.
func _sync_play_camera(out: Vector3) -> void:
	#
	# This is the single largest thing that was missing. Swink's definition of
	# game feel starts with "real-time control of virtual objects in a simulated
	# space" - and until now the space did not move and the player controlled
	# nothing continuously at all. A lake that heaves under you turns a picture
	# into a place, and it costs two wave samples a frame.
	var seat := Vector3(0.0, 1.30, -1.90)
	var eye := _boat_pose * seat
	# Yaw and pitch are the PLAYER's, applied on top of the boat's own motion, so
	# looking around never fights the swell and the swell never steals the aim.
	# A Godot camera looks down its own -Z, and the boat's bow is at +Z, so the
	# rig has to be turned about. The old code used `looking_at`, which hid this
	# entirely; building the basis by hand to carry the boat's motion exposed it,
	# and the first frame of it was a beautifully lit view out over the stern.
	var basis := _boat_pose.basis * Basis(Vector3.UP, PI + _look_yaw) 		* Basis(Vector3.RIGHT, _look_pitch)
	# Sat down, looking a little above the horizon.
	basis = basis * Basis(Vector3.RIGHT, deg_to_rad(-5.5))
	if _shake > 0.001:
		# Decaying, and on rotation only - see `_kick`.
		var a := _shake * _shake * 0.030
		var t2 := _boat_time * 46.0 + _shake_seed
		basis = basis * Basis(Vector3.RIGHT, sin(t2 * 1.7) * a) \
			* Basis(Vector3.UP, sin(t2 * 2.3) * a) \
			* Basis(Vector3.FORWARD, sin(t2 * 1.1) * a * 0.7)
	_cam.transform = Transform3D(basis, eye)


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
	# The mesh runs one unit astern from its own origin, so the head sits on the
	# fish and the scale is how far the disturbance trails it.
	_wake.scale = Vector3(1.0, 1.0, lead * 1.7)


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
			# NOTHING. The button says "Cast" and the hint under it says how -
			# a third instruction in the middle of the screen was the same
			# sentence a third time, and it landed on top of the sounder.
			line = ""
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
	_sync_lamp()
	if _lamp != null and _lamp.visible:
		# Brightest at night and in fog, and almost nothing at noon - a lamp that
		# is equally bright in daylight reads as a bug.
		var want_lamp := 2.6 * (1.0 - clampf(float(look["ambient"]) / 0.9, 0.0, 1.0))
		_lamp.light_energy = lerpf(_lamp.light_energy, maxf(0.35, want_lamp), k)
	_sync_gate()
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


# --- the hull --------------------------------------------------------------
#
# One set of functions describes the boat's shape and EVERYTHING reads them - the
# skin, the floor planks, the ribs and the gunwale. When they were separate the
# planks floated and the ribs stood in the water; a hull is one form, so it gets
# one definition.

## Half the beam at a station. Widest about a third back from the bow, drawing in
## at both ends - a straight taper reads as a wedge.
## Half the beam at a station. Widest about a third back from the bow, drawing in
## at both ends - a straight taper reads as a wedge.
##
## Note the 0.10 floor: the ends do NOT come to a point, they come to a 200 mm
## slot, and the swept skin had no caps on it. That slot is the gap Gideon could
## see at the front of the boat - you were looking through the bow at the lake.
## `_build_hull_mesh` now closes both ends; the floor stays because a real boat
## has a stem and a transom rather than a knife edge, and a cap needs something
## to be a cap of.
func _hull_half_width(z: float) -> float:
	var t := clampf((z + 0.85) / 3.10, 0.0, 1.0)
	var shape := sin(PI * pow(t, 0.72))
	return 0.10 + 0.545 * shape


## The bottom of the hull at a station. It rises toward the bow, which is the
## rocker, and is what stops the boat looking like a bathtub.
##
## **ABOVE THE WATERLINE, and that is the whole bug this file had.** The lake is
## one 220 m plane at y = 0 and it does not know the boat is there, so a floor at
## y = -0.4 put the entire surface of the lake INSIDE the hull, a foot above the
## boards - which is precisely "I can see right through to the water". Nothing
## was missing; the water was simply in front of it.
##
## A real boat's sole sits above its waterline and the skin carries on down
## outside. Only the inside is ever seen here, so the floor goes above y = 0 and
## the draft is left as something the player never has a view of.
## MEASURED, not guessed. The swell is 0.160 m peak from the two displaced waves
## (0.114 + 0.046), the hull heaves at 0.75 of it, so 0.040 m of water moves
## relative to the boat before pitch is even counted - and the sole was at 0.045
## at the stern. That is the "water clipping into the bottom" report: not a
## rendering fault, an actual freeboard of five millimetres.
##
## 0.150 at the stern clears the residual with room for the pitch as well.
func _hull_floor_y(z: float) -> float:
	var t := clampf((z + 0.85) / 3.10, 0.0, 1.0)
	return 0.150 + 0.24 * pow(t, 2.3)


## The top edge - the sheer. Rises toward the bow, like every boat ever built.
func _hull_rim_y(z: float) -> float:
	var t := clampf((z + 0.85) / 3.10, 0.0, 1.0)
	return 0.46 + 0.155 * pow(t, 2.0)


const HULL_STATIONS := 22
const HULL_ARC := 11


## The skin, as a U-section swept bow to stern and closed at both ends.
func _build_hull_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()

	for i in HULL_STATIONS:
		var t := float(i) / float(HULL_STATIONS - 1)
		var z: float = -0.85 + t * 3.10
		var hw := _hull_half_width(z)
		var fy := _hull_floor_y(z)
		var ry := _hull_rim_y(z)
		for j in HULL_ARC:
			# A half-ellipse from port rim, down round the bilge, up to starboard.
			var a := PI * float(j) / float(HULL_ARC - 1)
			var x := -cos(a) * hw
			var y := fy + (ry - fy) * (1.0 - sin(a))
			verts.append(Vector3(x, y, z))
			# Outward and downward, which is right for both faces given the skin
			# is drawn double-sided.
			norms.append(Vector3(-cos(a), -sin(a) * 0.55, 0.0).normalized())
			uvs.append(Vector2(float(j) / float(HULL_ARC - 1), t * 3.0))

	for i in HULL_STATIONS - 1:
		for j in HULL_ARC - 1:
			var a0 := i * HULL_ARC + j
			var a1 := i * HULL_ARC + j + 1
			var b0 := (i + 1) * HULL_ARC + j
			var b1 := (i + 1) * HULL_ARC + j + 1
			idx.append_array([a0, b0, a1, a1, b0, b1])

	# THE TRANSOM AND THE STEM. A swept surface is an open tube; without these
	# the boat has a 200 mm slot at each end and you can see the lake through the
	# bow. Each is a fan from the mid-point of the end ring.
	for pair in [[0, false], [HULL_STATIONS - 1, true]]:
		var station: int = pair[0]
		var flip: bool = pair[1]
		var base := station * HULL_ARC
		var mid := Vector3.ZERO
		for j in HULL_ARC:
			mid += verts[base + j]
		mid /= float(HULL_ARC)
		var centre := verts.size()
		verts.append(mid)
		norms.append(Vector3(0, 0, 1) if flip else Vector3(0, 0, -1))
		uvs.append(Vector2(0.5, 0.5))
		for j in HULL_ARC - 1:
			if flip:
				idx.append_array([centre, base + j, base + j + 1])
			else:
				idx.append_array([centre, base + j + 1, base + j])

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## A real float, not a red ball.
##
## The classic waggler shape, and every part of it is doing a job the player
## reads without being told: a RED CAP that is visible against dark water at
## twenty metres, a WHITE WAIST so the eye can see exactly how far down it has
## been pulled, a weighted stem below to keep it upright, and an antenna above
## that is the first thing to go under when a fish tries the bait.
##
## That last one is the whole of minigame one. Gideon asked for the hook phase to
## be "just watching the rod or bobber pull down", so the object being watched
## has to have a part whose entire purpose is to be watched.
## SIZED FOR LEGIBILITY, NOT FOR REALISM. A real waggler twenty metres out is a
## few pixels on a phone, and the first minigame is "watch the float go under" -
## an object the player cannot resolve cannot be watched. Built at roughly twice
## life size, with an antenna long enough that its DISAPPEARANCE is the event,
## which is what a real angler is actually reading too.
func _build_float() -> Node3D:
	var f := Node3D.new()
	f.name = "Float"
	f.visible = false

	var red := _mat(Color(0.86, 0.22, 0.14), 0.42)
	var white := _mat(Color(0.94, 0.93, 0.88), 0.42)
	var dark := _mat(Color(0.14, 0.13, 0.12), 0.60)
	var orange := _mat(Color(0.98, 0.52, 0.10), 0.35)
	orange.emission_enabled = true
	orange.emission = Color(0.85, 0.35, 0.05)
	# Barely glowing. Enough that the tip still reads at dusk and at depth, where
	# everything else in the frame has been drained - and not so much that it
	# looks like a light.
	orange.emission_energy_multiplier = 0.55

	var top := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.098
	tm.height = 0.196
	tm.is_hemisphere = true
	tm.radial_segments = 14
	tm.rings = 7
	top.mesh = tm
	top.material_override = red
	top.position = Vector3(0, 0.010, 0)
	f.add_child(top)

	var bottom := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.098
	bm.height = 0.250
	bm.is_hemisphere = true
	bm.radial_segments = 14
	bm.rings = 7
	bottom.mesh = bm
	bottom.material_override = white
	bottom.position = Vector3(0, 0.010, 0)
	bottom.rotation_degrees = Vector3(180, 0, 0)
	f.add_child(bottom)

	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.height = 0.20
	sm.top_radius = 0.011
	sm.bottom_radius = 0.006
	sm.radial_segments = 8
	stem.mesh = sm
	stem.material_override = dark
	stem.position = Vector3(0, -0.205, 0)
	f.add_child(stem)

	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.height = 0.260
	am.top_radius = 0.010
	am.bottom_radius = 0.014
	am.radial_segments = 8
	ant.mesh = am
	ant.material_override = orange
	ant.position = Vector3(0, 0.238, 0)
	f.add_child(ant)

	return f


## Float the boat on the swell.
##
## Sampled at four points - bow, stern and both beams - and the plane through
## them gives heave, pitch and roll together. That is much better than driving
## the three from one sample each: a hull sits ON the surface, so a long boat in
## a short swell should pitch LESS than a short one, and reading real points is
## what makes that happen for free.
##
## Damped, because raw Gerstner at the boat's scale is livelier than a two-metre
## rowing boat would be, and a camera that matches the water exactly is a camera
## that makes people put the phone down.
func _sync_boat_pose() -> void:
	var t := _boat_time
	var bow := _wave_offset(0.0, 1.9, t)
	var stern := _wave_offset(0.0, -0.8, t)
	var port := _wave_offset(-0.6, 0.5, t)
	var starboard := _wave_offset(0.6, 0.5, t)

	var heave := (bow.y + stern.y + port.y + starboard.y) * 0.25
	var pitch := atan2(bow.y - stern.y, 2.7)
	var roll := atan2(starboard.y - port.y, 1.2)

	# The damping IS the boat. A dinghy answers a swell late and rolls further
	# than it pitches, which is most of what tells you how big the boat is.
	var k := 1.0 - exp(-3.2 * _boat_dt)
	_boat_heave = lerpf(_boat_heave, heave * 0.75, k)
	_boat_pitch = lerpf(_boat_pitch, pitch * 0.62, k)
	_boat_roll = lerpf(_boat_roll, roll * 0.85, k)

	var basis := Basis(Vector3.RIGHT, _boat_pitch) * Basis(Vector3.FORWARD, _boat_roll)
	_boat_pose = Transform3D(basis, Vector3(0.0, _boat_heave, 0.0))
	if _boat != null:
		_boat.transform = _boat_pose
	if _reeds != null:
		# The bank does NOT ride the boat - it is the one thing on screen that
		# stays still, which is what makes the boat read as the thing moving.
		_reeds.transform = Transform3D.IDENTITY


## Where the lure actually IS, in the world.
##
## `_lure_position` describes the shape of the cast in CAST SPACE - straight out
## in front of the rod - and this rotates that onto the heading the cast was made
## on and lifts it onto the moving boat. Split in two so the shape of a cast is
## one idea and where the boat happens to be pointing is another.
##
## Public because the smoke test has to ask the same question the renderer does.
## It previously read `_lure_position` directly and compared it against the
## float, which silently became a comparison between two different coordinate
## spaces the moment casting gained a heading - the assertion still passed for a
## while, for the wrong reason.
func lure_world_position() -> Vector3:
	return _boat_pose * (Basis(Vector3.UP, _cast_yaw) * _lure_position())


# --- the one button ---------------------------------------------------------

## What the action button DOES right now, as one word the player can read.
##
## Derived from the state rather than stored, so the label and the behaviour are
## the same decision made once. A button whose caption and effect are computed in
## two places is a button that lies the first time a state is added.
func _action_for_state() -> String:
	match sim.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			return "Cast"
		Sim.CHARGING:
			return "Cast"
		Sim.FLYING, Sim.SINKING:
			return "Reel in"
		Sim.WAITING:
			return "Reel in"
		Sim.NIBBLING:
			return "Strike"
		Sim.FIGHTING:
			return "Reel in"
	return ""


func _on_action() -> void:
	match sim.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			# A tap of the button casts at a fixed, comfortable distance. Holding
			# the WATER is still how you choose the range - this is the "just get
			# me fishing again" control, which is what a player wants after
			# losing one.
			sim.hold_cast()
			for i in 18:
				sim.advance(1.0 / 60.0)
			_cast_yaw = _look_yaw
			if _audio != null:
				_audio.play("cast", -5.0)
			sim.release_cast()
		Sim.NIBBLING:
			sim.tap()
		_:
			# Everything else winds in. This is the way out that existed in the
			# simulation and nowhere on the screen.
			sim.reel_in()
			if _audio != null:
				_audio.play("reel", -8.0)


## The hint. Says the thing that is true now, and stops saying it once the
## player has plainly learnt it.
func _hint_for_state() -> String:
	if sim.caught >= 3:
		return ""
	match sim.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			return "hold the water to aim and cast   -   drag to look around"
		Sim.CHARGING:
			return "let go to cast"
		Sim.SINKING, Sim.WAITING:
			return "watch the float"
		Sim.NIBBLING:
			return "tap when it goes under"
		Sim.FIGHTING:
			return "tap to reel   -   stop when it runs"
	return ""


# --- impact -----------------------------------------------------------------

## A SPLASH AND A RING where the lure lands.
##
## The survey's "event signification" - particles, decals, persistence - and the
## cheapest of all of them. Before this a cast simply ended: the lure arrived and
## the water did not acknowledge it, so the most frequent action in the game had
## no consequence anyone could see. **An action with no reaction reads as not
## having happened**, however correct the simulation underneath is.
##
## The expanding ring matters more than the droplets. Droplets are over in a
## third of a second; the ring persists for two, which is what makes the water
## feel like it remembers being hit.
func _build_impact() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "Splash"
	_splash.amount = 26
	_splash.lifetime = 0.75
	_splash.one_shot = true
	_splash.explosiveness = 0.95
	_splash.emitting = false
	_splash.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 42.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.1
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	_splash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.92, 0.95, 0.96, 0.80)
	_splash.draw_pass_1 = q
	_splash.material_override = m
	add_child(_splash)

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.30
	tm.outer_radius = 0.36
	tm.rings = 4
	tm.ring_segments = 24
	_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.94, 0.96, 0.97, 0.0)
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = rm
	_ring.visible = false
	add_child(_ring)


var _ring_age := 9.0

## Fire everything an impact produces, in one call, because they are one event.
func _impact_at(where: Vector3, force: float) -> void:
	if _splash != null:
		# `position`, not `global_position`: both of these are direct children of
		# the scene root, which sits at the origin, so they are the same value -
		# and `global_position` needs a live tree, which a headless harness does
		# not have. Same trap as starting audio playback too early.
		_splash.position = where
		_splash.amount_ratio = clampf(force, 0.25, 1.0)
		_splash.restart()
		_splash.emitting = true
	if _ring != null:
		_ring.position = Vector3(where.x, 0.02, where.z)
		_ring_age = 0.0
		_ring.visible = true


## The ring grows and fades. Kept here rather than in a shader because it is four
## lines and a shader would be a file.
func _sync_ring(dt: float) -> void:
	if _ring == null or not _ring.visible:
		return
	_ring_age += dt
	var k := _ring_age / 2.1
	if k >= 1.0:
		_ring.visible = false
		return
	var scale := 0.35 + k * 2.6
	_ring.scale = Vector3(scale, 1.0, scale)
	var m := _ring.material_override as StandardMaterial3D
	if m != null:
		# Fades on a curve rather than linearly, so it is bright the instant it
		# appears and lingers faintly - which is how a real ring reads.
		m.albedo_color.a = 0.55 * pow(1.0 - k, 2.2)


## SCREEN SHAKE, and the note that stops it being a toy.
##
## The survey is explicit that juice needs adequacy - Kao's study found medium
## juiciness beat both extremes. So this is small: a couple of degrees at the
## most violent event in the game, decaying in about a third of a second. It is
## on the CAMERA's rotation rather than its position, because a boat's camera is
## already translating with the swell and adding more would read as nausea.
func _kick(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)
	_shake_seed = randf() * 100.0


## HIT STOP. A few frames of frozen time on the one event worth it: the strike.
##
## Not applied to the simulation - the rules must not care that the picture
## paused - only to the presentation clock. That distinction is the reason this
## is safe to add to a game with a whole-run golden test.
func _hit_stop(seconds: float) -> void:
	_freeze_left = maxf(_freeze_left, seconds)


## The phone buzzing. The third feedback channel, and on a touch device it is the
## only one that reaches the hand doing the work.
func _buzz(ms: int, amplitude: float) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, clampf(amplitude, 0.0, 1.0))


# --- things in the boat -----------------------------------------------------

## THE BOAT IS A PLACE, NOT A CAMERA MOUNT.
##
## Gideon: "part of the issue is the small details. like being able to move
## around the boat, interact with things. right now it just feels like you can
## only cast and reel."
##
## Right, and the look control on its own does not fix it - turning your head in
## a room where nothing can be touched is scenery, not agency. So the objects
## already in the hull become things you can USE, by looking at them. No new
## gesture: the same drag that turns your head aims at them, and the same button
## that casts uses them.
##
## Each entry is a world point, a radius on screen, and what using it does. Kept
## as data so adding the lamp or the radio later is one row.
func _build_things() -> void:
	_things = [
		{
			"id": "livewell",
			"name": "The livewell",
			"at": Vector3(0.34, _hull_floor_y(0.90) + 0.14, 0.90),
			"look": func() -> String:
				if sim.econ.held.is_empty():
					return "The livewell   -   empty"
				return "The livewell   -   %d fish, %.1f of %.1f kg" % [
					sim.econ.held.size(), sim.econ.load_kg(), sim.econ.capacity()],
			"use": func() -> void:
				_open(Menus.SHED),
		},
		{
			"id": "baitbox",
			"name": "The bait box",
			"at": Vector3(-0.32, _hull_floor_y(0.35) + 0.10, 0.35),
			"look": func() -> String:
				var b := Gear.bait_by_id(sim.econ.bait)
				return "%s on the hook   -   tap to change" % str(b["name"]),
			"use": func() -> void:
				_cycle_bait(),
		},
		{
			"id": "lamp",
			"name": "The deck lamp",
			"at": Vector3(0.0, _hull_rim_y(2.05) + 0.16, 2.05),
			"look": func() -> String:
				if not sim.econ.has_lamp:
					return "A bracket where a lamp would go"
				return "The deck lamp   -   %s" % ("lit" if _lamp_on else "out"),
			"use": func() -> void:
				if not sim.econ.has_lamp:
					_say_hint("There is no lamp in the bracket.")
					return
				_lamp_on = not _lamp_on
				_sync_lamp()
				if _audio != null:
					_audio.play("page", -6.0),
		},
		{
			"id": "rope",
			"name": "The rope",
			"at": Vector3(-0.34, _hull_rim_y(-0.16) + 0.03, -0.16),
			"look": func() -> String:
				return "A coil of rope. Somebody else's knot.",
			"use": func() -> void:
				_say_hint("You leave it where it is."),
		},
	]


var _lamp_on := false
var _lamp: OmniLight3D
var _lamp_prop: Node3D
var _shore: Node3D
var _gate_left: Node3D
var _gate_right: Node3D
var _gate_open := 0.0
var _seq := Sequence.new()
var _seq_line: Label
var _seq_at := Sequence.OUTSIDE
var _seq_look := Sequence.GATE_AT
var _in_sequence := false
var _hint_hold := 0.0
var _hint_text := ""


## What the player is currently looking at, or "" for the water.
##
## A dot product rather than a raycast: the things are small, close, and never
## occluded from the one seat in the game, so "is it near the middle of the
## screen" is both the right question and a hundredth of the cost.
func _thing_under_aim() -> Dictionary:
	if sim.state != Sim.IDLE and sim.state != Sim.WAITING:
		return {}
	if _cam == null:
		return {}
	var eye := _cam.global_transform.origin if is_inside_tree() else _cam.transform.origin
	var fwd := -_cam.transform.basis.z.normalized()
	var best := {}
	var best_dot := 0.985
	for t in _things:
		var at: Vector3 = _boat_pose * (t["at"] as Vector3)
		var to := (at - eye)
		if to.length() < 0.05:
			continue
		var d := fwd.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = t
	return best


func _cycle_bait() -> void:
	# Only through bait actually owned, and only forwards. A chooser in the boat
	# is a convenience, not a second shop - the shed is still where bait is
	# bought, and this is for the thing every angler does twenty times an hour.
	var owned: Array[String] = []
	for b in Gear.BAIT:
		var id: String = b["id"]
		if sim.econ.has_bait(id):
			owned.append(id)
	if owned.size() <= 1:
		_say_hint("Nothing else in the box.")
		return
	var i := owned.find(sim.econ.bait)
	sim.econ.bait = owned[(i + 1) % owned.size()]
	_say_hint("%s on the hook." % str(Gear.bait_by_id(sim.econ.bait)["name"]))
	if _audio != null:
		_audio.play("page", -8.0)
	_want_save()


func _say_hint(text: String) -> void:
	_hint_text = text
	_hint_hold = 2.6


func _sync_lamp() -> void:
	# THE LAMP IS ONLY THERE IF YOU BOUGHT IT. The shed sells a deck lamp for 400
	# and one was standing on the stem from the first frame, while the boat's own
	# hint said "a bracket where a lamp would go". A prop that contradicts the
	# shop is worse than no prop.
	if _lamp_prop != null:
		_lamp_prop.visible = sim.econ.has_lamp
	if _lamp == null:
		_lamp = OmniLight3D.new()
		_lamp.name = "DeckLamp"
		_lamp.omni_range = 9.0
		_lamp.light_energy = 0.0
		_lamp.light_color = Color(1.0, 0.86, 0.62)
		_lamp.position = Vector3(0.0, _hull_rim_y(2.05) + 0.18, 2.05)
		add_child(_lamp)
	_lamp.visible = _lamp_on and sim.econ.has_lamp


## Use whatever is being looked at. Refuses silently if that is the water, which
## is the only correct behaviour for a button that should not have been visible.
func _on_use() -> void:
	for t in _things:
		if t["id"] == _looking_at:
			(t["use"] as Callable).call()
			return


# --- what is actually in the boat -------------------------------------------

## THE PROPS, AND WHY THEY ARE IMPORTED.
##
## These four were interaction points with NOTHING THERE. The livewell, the bait
## box and the lamp could all be looked at and used, and none of them existed as
## geometry - the player was pointing at empty air and getting a prompt. That is
## the worst kind of placeholder, because it passes every test: the reachability
## sweep found all four, because it tests the aim and not the picture.
##
## They are imported rather than modelled, and the asset rule agrees once it is
## actually read rather than reached for. "Model in code anything thirty pixels
## tall and judged on silhouette" - a bucket in the bottom of a boat you are
## sitting in is four hundred pixels tall and read as an OBJECT. It is the named
## exception word for word: stationary, close to the camera, looked at while
## nothing else is happening.
##
## Poly Haven, CC0, photoreal - which is the other half of the decision. Kenney,
## Quaternius and KayKit are all excellent and all stylised low-poly, and any of
## them next to a photographic HDRI and a PBR plank would look like a different
## game had leaked in.
const PROPS := {
	"livewell": "res://assets/props/wooden_bucket_01/wooden_bucket_01_1k.gltf",
	"baitbox": "res://assets/props/wooden_crate_01/wooden_crate_01_1k.gltf",
	"lamp": "res://assets/props/Lantern_01/Lantern_01_1k.gltf",
	"lifebuoy": "res://assets/props/lifebuoy/lifebuoy_1k.gltf",
}


## Load a prop, or return null if it is missing.
##
## Null rather than a crash, because a model that failed to import must not stop
## the boat existing - but it must also not leave an invisible thing you can
## still interact with, which is what `_build_props` checks.
func _prop(id: String) -> Node3D:
	var path: String = PROPS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _place_prop(id: String, at: Vector3, scale: float, yaw: float) -> Node3D:
	var n := _prop(id)
	if n == null:
		push_warning("prop '%s' is missing - it will not be interactable" % id)
		return null
	n.name = "Prop_" + id
	n.position = at
	n.scale = Vector3.ONE * scale
	n.rotation_degrees = Vector3(0, yaw, 0)
	_boat.add_child(n)
	return n


func _build_props() -> void:
	# Each sits ON the sole at its own station, read from the hull functions, so
	# raising the freeboard moved every one of them without a second edit.
	# Placement is composition, not bookkeeping. The first pass put all four where
	# their interaction points happened to be and the bucket filled a third of the
	# frame while the lantern hid behind the rod. Spread along the hull, none of
	# them across the water the player is casting into, and none of them large
	# enough to be the subject.
	_place_prop("livewell", Vector3(0.34, _hull_floor_y(0.90), 0.90), 0.80, 18.0)
	_place_prop("baitbox", Vector3(-0.32, _hull_floor_y(0.35), 0.35), 0.50, -12.0)
	# The lantern goes on the STEM, where it lights the water ahead rather than
	# the boards - and where it is a silhouette against the sky at night.
	var lamp := _place_prop("lamp", Vector3(0.0, _hull_rim_y(2.05) + 0.03, 2.05), 1.05, 0.0)
	if lamp != null:
		_lamp_prop = lamp
	_place_prop("lifebuoy", Vector3(-0.58, _hull_rim_y(0.30) - 0.16, 0.30), 0.62, 90.0)

	# THE BRACKET IS ALWAYS THERE, the lantern only once bought. Hiding the lamp
	# until it is paid for immediately re-created the invisible-prompt bug in the
	# other direction: the hint said "a bracket where a lamp would go" and there
	# was no bracket either. If the game names a thing, the thing exists.
	var bracket := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.045, 0.14, 0.045)
	bracket.mesh = bm
	var bmat := _mat(Color(0.24, 0.22, 0.20), 0.45)
	bmat.metallic = 0.7
	bracket.material_override = bmat
	bracket.position = Vector3(0.0, _hull_rim_y(2.05) + 0.05, 2.05)
	bracket.name = "LampBracket"
	_boat.add_child(bracket)


## The wake: a narrow V that widens and fades astern of the fish.
##
## Vertex alpha does the fading, so there is no texture and no shader - the head
## is bright and narrow, the tail is wide and gone. Built once and stretched by
## the fight, because its LENGTH is the distance to the fish.
func _build_wake_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var steps := 14
	for i in steps:
		var t := float(i) / float(steps - 1)
		# Widens astern, and the alpha goes with the square so the tail
		# disappears rather than ending.
		var half := 0.035 + t * 0.30
		var a := (1.0 - t) * (1.0 - t) * 0.9
		var z := -t
		verts.append(Vector3(-half, 0.0, z))
		verts.append(Vector3(half, 0.0, z))
		cols.append(Color(1, 1, 1, a))
		cols.append(Color(1, 1, 1, a))
	for i in steps - 1:
		var a0 := i * 2
		var a1 := i * 2 + 1
		var b0 := (i + 1) * 2
		var b1 := (i + 1) * 2 + 1
		idx.append_array([a0, b0, a1, a1, b0, b1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Everything this scene listens to on the Sim, in one place.
##
## Extracted so "New game" can point it at a fresh Sim without rebuilding the
## scene - a rebuild would drop the water, the sky and the props for a beat, and
## the title is fading out over them at exactly that moment.
func _wire_sim_signals() -> void:
	# The impact, the shake, the buzz and the sound are ONE event with four
	# channels, so they are wired together and fired together. The survey's point
	# about layering: screen shake plus particles plus audio plus haptics work
	# synergistically, and any of them alone reads as thin.
	sim.cast_landed.connect(func(_d: float) -> void:
		_impact_at(lure_world_position(), 0.7)
		_buzz(18, 0.30))
	sim.hooked.connect(func(_id: String, perfect: bool) -> void:
		_impact_at(lure_world_position(), 1.0)
		_kick(0.55 if perfect else 0.34)
		_hit_stop(0.09 if perfect else 0.05)
		_buzz(45, 0.85 if perfect else 0.55))
	sim.run_started.connect(func() -> void:
		_kick(0.30)
		_buzz(70, 0.60))
	sim.landed.connect(func(_id: String, w: float) -> void:
		_impact_at(lure_world_position(), 1.0)
		_kick(0.22)
		_buzz(30, 0.45))
	sim.lost.connect(func(reason: String) -> void:
		_kick(0.75 if reason == Sim.BROKE else 0.30)
		_buzz(110 if reason == Sim.BROKE else 40, 0.9 if reason == Sim.BROKE else 0.4))

	# Anything that changes the boat asks for a write. Landing a fish is the one
	# a player would be most upset to lose, and it is also the most frequent, so
	# the request is COALESCED rather than written immediately - see `_want_save`.
	sim.landed.connect(func(_id: String, _w: float) -> void: _want_save())
	sim.object_found.connect(func(_id: String) -> void: _want_save())

	# The first morning listens to the same signals. A beat that waits for a
	# landed fish cannot be allowed to miss one because the player recast on the
	# very next frame - see the note in intro.gd.
	sim.cast_landed.connect(func(_d: float) -> void:
		if _intro != null:
			_intro.note_cast())
	sim.nibble.connect(func() -> void:
		if _intro != null:
			_intro.note_nibble())
	sim.hooked.connect(func(_id: String, _perfect: bool) -> void:
		if _intro != null:
			_intro.note_hooked())
	sim.landed.connect(func(_id: String, _w: float) -> void:
		if _intro != null:
			_intro.note_landed())


# --- the title and the first morning ----------------------------------------

## The title goes up over a scene that is already running - see title.gd. The
## intro is created either way and simply starts finished if the save says it
## has been seen.
func _build_title() -> void:
	_intro = Intro.new()
	if sim.intro_done:
		_intro.finish()

	_title = TitleScreen.new()
	_title.name = "Title"
	add_child(_title)
	_title.setup(FileAccess.file_exists(SAVE_PATH))
	# The title is a PLACE: standing outside the gate, in the real scene, with
	# the real water beyond it. Nothing here is a separate menu world.
	_in_sequence = true
	_seq_at = Sequence.OUTSIDE
	_seq_look = Sequence.GATE_AT
	_gate_open = 0.0
	_title.start_continue.connect(_on_continue)
	_title.start_new.connect(_on_new_game)
	_title.open_settings.connect(func() -> void:
		# The SAME settings room the game uses. One settings screen in the
		# project, not two that have to agree with each other.
		_menus.open(Menus.KIT))


func _on_continue() -> void:
	_title.dismiss()
	if _audio != null:
		_audio.play("page", -4.0)
	_play_sequence(Sequence.going_out())


## Wipe and start again. The save is deleted rather than overwritten, so a crash
## between here and the first write cannot leave half of the old game behind.
func _on_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var settings_sensitivity := sim.sensitivity
	var settings_muted := sim.sound_muted
	sim = Sim.new(randi() % 100000 + 1)
	# Settings survive a new game. They are about the person holding the phone,
	# not about the save.
	sim.sensitivity = settings_sensitivity
	sim.sound_muted = settings_muted
	_intro = Intro.new()
	_fish_shown = ""
	_look_yaw = 0.0
	_look_pitch = 0.0
	_look_yaw_want = 0.0
	_look_pitch_want = 0.0
	_cast_yaw = 0.0
	_rewire(sim)
	_title.dismiss()
	if _audio != null:
		_audio.play("page", -4.0)
	# A first arrival gets the long version; anyone who has seen it gets the
	# same walk without the letter.
	_play_sequence(Sequence.arriving())


## Point everything that holds a Sim at the new one. Listed explicitly rather
## than rebuilding the scene, because rebuilding would drop the water, the sky
## and the props for a beat - and the title is fading out over them.
func _rewire(s: Sim) -> void:
	if _audio != null:
		_audio.retarget(s)
		_audio.set_muted(s.sound_muted)
	if _menus != null:
		_menus.retarget(s)
		_menus.sensitivity = s.sensitivity
		_menus.sound_muted = s.sound_muted
	_wire_sim_signals()
	_want_save()


## The intro's copy goes in the hint line, which is where every other piece of
## in-boat guidance already lives - so it is one thing that speaks, not two.
func _sync_intro(dt: float) -> void:
	if _intro == null or _intro.done():
		return
	if _title != null and _title.is_up():
		return
	_intro.note_state(sim.state, sim.taking)
	if absf(_look_yaw) > 0.06 or absf(_look_pitch) > 0.04:
		_intro.note_look()
	_intro.advance(dt)
	if _intro.done() and not sim.intro_done:
		sim.intro_done = true
		_want_save()


# --- the shore, the wall and the gate ---------------------------------------

## THE KEEPER'S GATE.
##
## Behind the boat, at the end of a short bank, there is a stone wall with a
## wooden gate in it. The game begins on the wrong side of that gate.
##
## It is not set dressing for a menu. **It is the ritual.** A keeper of this
## water walks down through the gate to the boat, and does it every time - so
## the way into the game and the way the fiction works are the same motion. That
## is the whole reason the title is a place rather than a picture: the player
## does not press "Continue", they go out.
##
## It sits at negative Z, behind the stern, which is the one direction the
## playing camera never looks. So it costs nothing during a session and is
## simply there if the player turns round far enough to see it.
const SHORE_Z := -13.0
const GATE_HALF := 1.15

func _build_shore() -> void:
	_shore = Node3D.new()
	_shore.name = "Shore"
	add_child(_shore)

	var stone := _stone_mat()
	var timber := _wood_mat(Color(0.255, 0.185, 0.125), Vector3(1.0, 2.4, 1.0))
	timber.cull_mode = BaseMaterial3D.CULL_DISABLED

	# The bank. A slab from the wall down to the waterline, tilted just enough
	# to read as a slope rather than a shelf.
	var bank := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(26.0, 0.5, 11.0)
	bank.mesh = bm
	var bank_mat := _mat(Color(0.20, 0.20, 0.17), 0.98)
	var stone_n := load("res://assets/tex/stone_normal.jpg")
	if stone_n != null:
		bank_mat.normal_enabled = true
		bank_mat.normal_texture = stone_n
		bank_mat.normal_scale = 0.7
		bank_mat.uv1_scale = Vector3(7.0, 3.0, 1.0)
	bank.mesh = bm
	bank.material_override = bank_mat
	bank.position = Vector3(0.0, 0.12, SHORE_Z + 4.6)
	bank.rotation_degrees = Vector3(-2.6, 0, 0)
	_shore.add_child(bank)

	# The wall, in two pieces with the gateway between them.
	for side in [-1.0, 1.0]:
		var seg := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(9.4, 2.9, 0.55)
		seg.mesh = wm
		seg.material_override = stone
		seg.position = Vector3(side * (GATE_HALF + 4.7), 1.30, SHORE_Z)
		_shore.add_child(seg)

	# A capping course, so the wall has a top rather than an edge.
	for side in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(9.6, 0.16, 0.72)
		cap.mesh = cm
		cap.material_override = stone
		cap.position = Vector3(side * (GATE_HALF + 4.7), 2.82, SHORE_Z)
		_shore.add_child(cap)

	# Gate posts.
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.26, 2.5, 0.30)
		post.mesh = pm
		post.material_override = timber
		post.position = Vector3(side * GATE_HALF, 1.10, SHORE_Z)
		_shore.add_child(post)

	# THE GATE ITSELF, two leaves hinged on the posts. Each is a pivot at the
	# hinge with the boards hung off it, so opening is one rotation.
	_gate_left = _build_gate_leaf(-1.0, timber)
	_gate_right = _build_gate_leaf(1.0, timber)
	_shore.add_child(_gate_left)
	_shore.add_child(_gate_right)


## One leaf: five vertical boards and two rails, hung off a hinge pivot.
func _build_gate_leaf(side: float, timber: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "GateLeaf"
	pivot.position = Vector3(side * GATE_HALF, 1.05, SHORE_Z)

	var width := GATE_HALF - 0.06
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width / 5.0 - 0.03, 2.05, 0.075)
		board.mesh = bm
		board.material_override = timber
		board.position = Vector3(-side * t * width, 0.0, 0.0)
		pivot.add_child(board)

	for y in [-0.66, 0.66]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(width, 0.16, 0.055)
		rail.mesh = rm
		rail.material_override = timber
		rail.position = Vector3(-side * width * 0.5, float(y), -0.06)
		pivot.add_child(rail)

	# The diagonal brace, which is what makes a gate read as a gate.
	var brace := MeshInstance3D.new()
	var brm := BoxMesh.new()
	brm.size = Vector3(sqrt(width * width + 1.32 * 1.32), 0.13, 0.05)
	brace.mesh = brm
	brace.material_override = timber
	brace.position = Vector3(-side * width * 0.5, 0.0, -0.06)
	brace.rotation_degrees = Vector3(0, 0, rad_to_deg(atan2(1.32, width)) * side)
	pivot.add_child(brace)
	return pivot


func _stone_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# The COLOUR map is taken this time, unlike the timber. On a stone wall the
	# variation between one block and the next is structural information rather
	# than palette - it is what makes it masonry instead of a grey slab - so it
	# earns its place, and it is tinted hard toward the game's own colours so it
	# still belongs to this lake.
	var col := load("res://assets/tex/stone_color.jpg")
	if col != null:
		m.albedo_texture = col
	m.albedo_color = Color(0.52, 0.53, 0.50)
	var n := load("res://assets/tex/stone_normal.jpg")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.1
	var r := load("res://assets/tex/stone_rough.jpg")
	if r != null:
		m.roughness_texture = r
	m.roughness = 1.0
	m.uv1_scale = Vector3(3.4, 1.1, 1.0)
	return m


## Swing the leaves. 0 is shut, 1 is wide.
func _sync_gate() -> void:
	if _gate_left == null:
		return
	var a := deg_to_rad(_gate_open * 96.0)
	_gate_left.rotation.y = -a
	_gate_right.rotation.y = a


# --- the sequences ----------------------------------------------------------

## Run a camera sequence, and hold the game while it plays.
func _play_sequence(shots: Array) -> void:
	_in_sequence = true
	_seq.start(shots)
	var first: Dictionary = shots[0]
	_seq_at = first["at"]
	_seq_look = first["look"]
	_gate_open = float(first.get("gate", 0.0))
	_sync_bars()


## Advance whichever sequence is playing. Called from the frame tick, so a
## sequence moves on real time and not on the simulation's - it has to keep
## running while the game underneath is held still.
func _sync_sequence(dt: float) -> void:
	if not _in_sequence:
		return
	var f := _seq.advance(dt)
	if f.is_empty():
		_end_sequence()
		return
	_seq_at = f["at"]
	_seq_look = f["look"]
	_gate_open = float(f["gate"])
	if _seq_line != null:
		var say := str(f.get("say", ""))
		_seq_line.text = say
		# Fade each line in over its own shot rather than snapping it on. Text
		# that appears instantly on a moving camera reads as a subtitle; text
		# that arrives reads as a thought.
		_seq_line.modulate.a = 0.0 if say == "" else minf(1.0, _seq_line.modulate.a + dt * 1.8)
	if _seq.done():
		_end_sequence()


func _end_sequence() -> void:
	_in_sequence = false
	_gate_open = 1.0
	if _seq_line != null:
		_seq_line.text = ""
		_seq_line.modulate.a = 0.0
	_sync_bars()
	_want_save()


## A tap anywhere cuts to the end. **Every sequence in this game is skippable**,
## because a beautiful thing you cannot skip is the worst thing in the game by
## the fifth time you sit through it.
func _skip_sequence() -> void:
	if not _in_sequence:
		return
	var f := _seq.skip()
	if not f.is_empty():
		_seq_at = f["at"]
		_seq_look = f["look"]
	_end_sequence()


func _build_sequence_line() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.name = "SeqText"
	add_child(layer)
	_seq_line = Label.new()
	_seq_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_seq_line.offset_left = 90
	_seq_line.offset_right = -90
	_seq_line.offset_top = -520
	_seq_line.offset_bottom = -340
	_seq_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seq_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seq_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_seq_line.add_theme_font_size_override("font_size", 38)
	_seq_line.add_theme_color_override("font_color", Color(0.95, 0.93, 0.87))
	_seq_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_seq_line.add_theme_constant_override("outline_size", 10)
	_seq_line.modulate.a = 0.0
	_seq_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_seq_line)


## Whether the HUD should stand down: a room is open, the title is up, or a
## camera sequence is running.
##
## A function rather than an inline expression because the inline one was a
## multi-line boolean and a line continuation got mangled - twice - leaving the
## sequence clause silently dropped and the whole HUD drawn over the gate. A
## condition three things depend on should have one name.
func _hud_is_down() -> bool:
	if _menus != null and _menus.is_open():
		return true
	if _title != null and _title.is_up():
		return true
	return _in_sequence
