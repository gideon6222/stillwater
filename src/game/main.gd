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
## The ten segments the line is actually drawn as. See `_draw_line_between`.
var _line_chain: Array[MeshInstance3D] = []
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
var _needle := 0.0
var _needle_v := 0.0
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
var _stick: Control
var _stick_held := false
var _stick_from := Vector2.ZERO
var _stick_to := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _crosshair: Control
var _charge_ring: Control
var _boat_heave := 0.0
var _boat_pitch := 0.0
var _boat_roll := 0.0
## The head, which is NOT the hull. See `_sync_cam_pose`.
var _cam_heave := 0.0
var _cam_pitch := 0.0
var _cam_roll := 0.0
var _cam_pose := Transform3D.IDENTITY
## How far the rod is trailing the deck. See `_sync_rod_lag`.
var _rod_lag_pitch := 0.0
var _rod_lag_roll := 0.0
var _rod_lag_last_pitch := 0.0
var _rod_lag_last_roll := 0.0
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
const BAR_W := 0.78           ## fraction of screen width
const GAUGE_TOP := 196.0      ## tension gauge, from the top edge
const GAUGE_H := 96.0

## How far the float is pulled under at a full take, in metres. Deep enough that
## a tease and a take are obviously different depths at cast range.
## The printed page's own resolution. Named because the hit test divides by it,
## and when the two disagreed a tap on the middle of the page turned it back.
const BOOK_PAGE_PX := Vector2i(1024, 566)

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

	# The line. Ten thin boxes along a sagging curve, rebuilt each frame - see
	# `_draw_line_between`, where the shape is a readout of the tension. `_line`
	# itself is kept as the mesh and material every segment shares, and is never
	# drawn on its own any more.
	_line = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, 1.0)
	_line.mesh = lm
	_line.material_override = _mat(Color(0.94, 0.93, 0.88), 0.4)
	_line.visible = false
	# One mesh and one material, shared by every segment, so the whole line is
	# ten transforms and a single draw setup rather than ten of everything.
	for i in LINE_JOINTS:
		var seg := MeshInstance3D.new()
		seg.mesh = lm
		seg.material_override = _line.material_override
		seg.name = "LineSeg%d" % i
		seg.visible = false
		add_child(seg)
		_line_chain.append(seg)
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
	_build_stick()
	_build_crosshair()
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
	m.set_shader_parameter("clarity", 0.30)
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
## STILL WATER. The game is called that and the water was not.
##
## Amplitude is `steepness / k`, so these two waves summed to 0.16 m - a THIRTY
## TWO CENTIMETRE swell peak to peak, on a lake at dawn. That is a stiff breeze on
## a reservoir, and it is the real reason the boat would not settle no matter what
## the hull multipliers did: the hull was honestly riding water that was far too
## big. "Can you make the water calmer in general? It still rocks a bit too much."
##
## Now 0.062 m total, about 12 cm peak to peak, which is a lake with a light air
## moving over it. A third wave was added rather than simply shrinking the two:
## short, very low, and quick, it keeps the surface ALIVE at close range where the
## eye is, while the two long ones do the gentle work under the hull. Cutting
## amplitude alone gives calm water that also looks dead.
const WAVES := [
	[1.0, 0.35, 0.052, 5.10, 0.80],
	[-0.7, 0.90, 0.038, 2.90, 1.00],
	[0.4, -1.0, 0.020, 1.15, 1.35],
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
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

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
// How see-through the surface gets, and only where it is nearly underfoot.
uniform float clarity = 0.30;

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

	// TRANSLUCENT, BUT ONLY CLOSE, AND NEVER A WINDOW.
	//
	// Gideon: "can you make the water appear slightly translucent without
	// showing fish under the water". Both halves matter. Water you can see a
	// little way into reads as a liquid rather than as a lid; water you can see
	// THROUGH shows the fish, and the fish being invisible under the surface is
	// the entire first minigame - you are meant to be reading the float, not
	// watching what is coming for it.
	//
	// So the transparency is capped low, falls off with distance, and closes
	// completely at a grazing angle where a real lake also becomes a mirror.
	// The fish swim well below the depth this reaches.
	float near_edge = clamp(1.0 - length(VERTEX) / 7.0, 0.0, 1.0);
	float straight_on = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALPHA = 1.0 - clarity * near_edge * straight_on * (1.0 - clamp(fres, 0.0, 1.0));
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
	#
	# **SAMPLED AT THE HULL'S OWN STATIONS, over the hull's own z range.** It used
	# to run 15 points from -0.80 while the skin runs 22 from -0.85, so the two
	# polylines approximated the same curve at different places and crossed each
	# other between samples. Where the skin's chord stepped outboard of the rail's
	# chord it left a slit a fraction of a pixel wide along the whole sheer - and
	# a slit in a hull is a hole to the sky. It photographed as a dashed white
	# hairline running the length of the port rail, which read as an artefact
	# rather than as a gap and survived three passes looking for a shader.
	for side in [-1.0, 1.0]:
		var rail_pts: Array[Vector3] = []
		for i in HULL_STATIONS:
			var t := float(i) / float(HULL_STATIONS - 1)
			var z: float = -0.85 + t * 3.10
			rail_pts.append(Vector3(side * _hull_half_width(z), _hull_rim_y(z), z))
		var rail := MeshInstance3D.new()
		# HEAVY ENOUGH TO SWALLOW THE PLANKING'S LIP. The skin now runs 0.16 rad
		# past the rim, which is at most 50 mm of upstand at the widest station;
		# the bar is 120 mm deep so it reaches 60 mm either side of the sheer and
		# the lip stays inside it. Raise the overshoot without raising this and
		# the lip pokes out through the top of the rail, where its lit edge is the
		# same white hairline again, only brighter - which is exactly what the
		# first attempt at 0.24 rad photographed as.
		rail.mesh = _sweep(rail_pts, 0.130, 0.120)
		rail.material_override = rail_mat
		# NAMED PER SIDE. Two nodes called "Gunwale" meant Godot renamed the second
		# one, and a diagnostic that hides "Gunwale" then silently hides one rail
		# and reports success - which cost a full pass chasing a hairline on the
		# port sheer with the starboard rail switched off.
		rail.name = "GunwalePort" if side < 0.0 else "GunwaleStarboard"
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
	rope.position = Vector3(0.34, _hull_rim_y(1.05) + 0.030, 1.05)
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
	_build_book()
	_build_tacklebox()
	# AFTER everything in the boat exists, because it measures what is there.
	_build_aim_points()
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
			# IN THE HANDS, not planted in the boat ahead of you. The butt sits a
			# little forward of the chest and off to the right, where a seated
			# angler's hands are - about 36 cm from the eye at `Sequence.SEAT`.
			# It was at z = 1.30, which was three metres in front of the old seat
			# and read as a stick standing in the bottom of the boat.
			seg.position = Vector3(0.28, 0.98, 1.06)
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
	abox.bg_color = Color(0.135, 0.098, 0.062, 0.92)
	abox.border_color = Color(0.86, 0.68, 0.36, 0.55)
	abox.set_border_width_all(3)
	abox.set_corner_radius_all(int(ACTION_SIZE * 0.5))
	# A cast ring on a lake wants to look like something wet and brass, not like
	# a UI chip: a warm inner glow and a shadow that lifts it off the water.
	abox.shadow_color = Color(0, 0, 0, 0.45)
	abox.shadow_size = 10
	abox.shadow_offset = Vector2(0, 5)
	_action.add_theme_stylebox_override("normal", abox)
	_action.add_theme_stylebox_override("hover", abox)
	var apress := abox.duplicate() as StyleBoxFlat
	apress.bg_color = Color(0.42, 0.30, 0.15, 0.97)
	apress.border_color = Color(1.0, 0.90, 0.62, 1.0)
	# Pressed sits DOWN and loses its shadow, which is the cheapest way to make
	# a button feel like it took the press rather than merely noticed it.
	apress.shadow_size = 3
	apress.shadow_offset = Vector2(0, 1)
	_action.add_theme_stylebox_override("pressed", apress)
	_action.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	_action.add_theme_color_override("font_hover_color", Color(0.96, 0.90, 0.76))
	_action.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	_action.name = "Action"
	# `button_down` / `button_up`, not `pressed`. A click fires on RELEASE, which
	# cannot express "hold to load".
	_action.button_down.connect(_cast_pressed)
	_action.button_up.connect(_cast_released)
	_ui.add_child(_action)

	# THE CHARGE READS ON THE BUTTON ITSELF. The rod pulling back says how far
	# the cast will go, but the rod is at the top of the screen and the thumb is
	# at the bottom - so the ring fills under the thumb as well.
	_charge_ring = Control.new()
	_charge_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_charge_ring.offset_left = -ACTION_SIZE - 46
	_charge_ring.offset_right = -46
	_charge_ring.offset_top = -ACTION_SIZE - 150 - SAFE_BOTTOM
	_charge_ring.offset_bottom = -150 - SAFE_BOTTOM
	_charge_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_ring.name = "ChargeRing"
	_charge_ring.draw.connect(_draw_charge_ring)
	_ui.add_child(_charge_ring)

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
	# ABOVE the controls, not across them. The stick well reaches 457 px up from
	# the bottom and the cast ring 464; a caption at 244 was printed over both.
	_hint.offset_left = 40
	_hint.offset_right = -40
	_hint.offset_top = -600 - SAFE_BOTTOM
	_hint.offset_bottom = -540 - SAFE_BOTTOM
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	# It now sits over the boat's own planks rather than over water, and pale
	# varnished pine at dawn is almost exactly this grey - half the sentence
	# disappeared into the deck. Brighter, with a heavier outline behind it.
	_hint.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 0.88))
	_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.92))
	_hint.add_theme_constant_override("outline_size", 10)
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
	# UP AND OUT OF THE WAY. The stick now owns the bottom-left corner, and two
	# controls in one thumb's rest position is one control the player hits by
	# mistake. The rooms are read once every few minutes; they can be reached
	# for.
	_dock.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dock.offset_left = 34
	_dock.offset_right = 600
	_dock.offset_top = 196
	_dock.offset_bottom = 282
	_dock.add_theme_constant_override("separation", 10)
	_dock.name = "Dock"
	_ui.add_child(_dock)
	for pair in [[Menus.SHED, "Shed"], [Menus.MAP, "Lake"], [Menus.LOG, "Log"],
			[Menus.KIT, "Kit"]]:
		var screen: String = pair[0]
		var b := _dock_button(str(pair[1]))
		if screen == Menus.LOG:
			# THE REAL BOOK, not the flat page. There were two logbooks - a
			# notebook lying in the boat and a panel behind a button - and the
			# button is the one anybody finds, so the object might as well not
			# have existed.
			b.pressed.connect(func() -> void: _open_book())
		else:
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
	# CLEAR OF THE GAUGE. The tension dial now reaches 292 px down plus its
	# shadow, and two instruments whose cases touch read as one broken one.
	_sounder.offset_top = 334
	_sounder.offset_bottom = 848
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
	_build_room_bar()
	_build_box_hud()
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
		# ...and it goes cold when the fish is about to pull. Colour, caption and
		# the wake are three readings of one state: no single channel has to be
		# the one the player happens to be watching.
		var letting_go := sim.state == Sim.FIGHTING and (sim.running or sim.tell > 0.0)
		# DIM, NEVER HIDE. A Select with nothing under the crosshair greys out and
		# stays exactly where it is: removing it would reflow the layout under a
		# thumb already moving toward it, which reads as the game breaking.
		var idle_state := sim.state == Sim.IDLE or sim.state == Sim.HOLDING or sim.state == Sim.LOST
		var dead_select := idle_state and not _over_water_shown and _looking_at == ""
		var tint := Color(0.93, 0.90, 0.82)
		if letting_go:
			tint = Color(0.99, 0.80, 0.44)
		elif dead_select:
			tint = Color(0.55, 0.53, 0.49)
		elif idle_state and not _over_water_shown:
			# Something IS under it. Warm, so "there is a thing here" reads at a
			# glance rather than being spelled out.
			tint = Color(0.99, 0.84, 0.52)
		_action.add_theme_color_override("font_color", tint)
		_action.disabled = dead_select
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
	if _stick != null:
		_stick.visible = not in_room
		_stick.queue_redraw()
	if _crosshair != null:
		_crosshair.visible = not in_room and sim.state != Sim.HOLDING
		_crosshair.queue_redraw()
	if _charge_ring != null:
		_charge_ring.visible = not in_room and sim.state == Sim.CHARGING
		_charge_ring.queue_redraw()
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
	box.bg_color = Color(0.048, 0.062, 0.068, 0.72)
	box.border_color = Color(0.72, 0.58, 0.32, 0.34)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.32)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var press := box.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.26, 0.19, 0.10, 0.92)
	press.border_color = Color(0.98, 0.86, 0.56, 0.85)
	# Down, and the shadow goes with it - the same press the cast ring uses, so
	# every button on the boat answers a thumb the same way.
	press.shadow_size = 2
	press.shadow_offset = Vector2(0, 1)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78, 0.84))
	b.add_theme_color_override("font_hover_color", Color(0.94, 0.89, 0.78, 0.84))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.97, 0.90))
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
## Diameter of the round action button, on the 1080-wide base canvas.
const ACTION_SIZE := 260

## Clearance left under everything for the Android gesture bar.
##
## A fixed number rather than `DisplayServer.get_display_safe_area()`, because
## that returns the WINDOW on a desktop run and would move the whole HUD between
## the phone and every screenshot taken here.
const SAFE_BOTTOM := 54

const LOOK_SLOP := 14.0        ## pixels before a press becomes a look
const LOOK_YAW_LIMIT := 1.05   ## how far round you can turn in the seat (60 deg)
## HOW FAR A SEATED PERSON CAN LOOK, and it is not the same in both directions.
##
## One symmetric limit of 0.40 rad was correct while the camera floated a metre
## behind the transom looking at the boat: there was nothing underneath it to look
## at. Sitting on the thwart there is a whole boat under you, and 23 degrees does
## not reach your own feet - the sole one metre ahead is 50 degrees down.
##
## Measured, not reasoned: `scripts/probe_pitch.gd` prints the camera's forward
## vector against `_look_pitch`, because the basis is composed after a PI yaw and
## the sign is genuinely not readable from the source. NEGATIVE is down.
const LOOK_PITCH_DOWN := 1.00  ## 57 deg, plus the resting tilt. Down at the boards
const LOOK_PITCH_UP := 0.40    ## a seated person tips their head back much less
const LOOK_PITCH_LIMIT := LOOK_PITCH_UP   ## kept: the yaw/pitch sweep still reads it

## The resting tilt, and it earns a name now that things live below it.
##
## It was -5.5 degrees with a comment saying it looked "a little above the
## horizon". Measured, it looks 5.5 degrees BELOW it - the comment had the sign
## wrong and nothing depended on it while the boat was in the middle distance.
## At -10 the gunwales and the gear frame the bottom of the picture the way they
## do when you are actually sitting in a boat, and the float, which sits about 3
## degrees below the horizon at casting range, is still comfortably in frame.
const REST_TILT := -7.0
const LOOK_SWEEP := 1.15       ## screen widths to travel the whole yaw range
const LOOK_BASE_WIDTH := 1080.0
const LOOK_FOLLOW := 16.0

## How far the stick's knob travels, and how fast a fully pushed stick turns you.
## Radians per second at full deflection - about four seconds from shoulder to
## shoulder, which is a person turning to look rather than a turret.
const STICK_RADIUS := 118.0
const LOOK_RATE := 0.62
const STICK_DEAD := 0.14   ## a thumb resting on the stick is not an instruction
const STICK_CURVE := 1.7   ## response exponent. Fine at the bottom, fast at the top


func _draw_tension_bar() -> void:
	if sim.state != Sim.FIGHTING:
		return
	var w := _tension_bar.size.x
	var h := _tension_bar.size.y

	# A BRASS SCALE, not a progress bar.
	#
	# It is the one instrument the player reads continuously, so it is drawn to
	# match the boat rather than to match a UI kit: a lacquered ground, an
	# engraved scale, a brass bezel and a needle on a pivot. Everything is sized
	# off `h`, so the whole thing scales with one constant instead of nineteen
	# hand-placed numbers going out of step.
	var pad := h * 0.09
	var face := Rect2(pad, pad, w - pad * 2.0, h - pad * 2.0)
	var lo := face.position.x + Tuning.SAFE_LO / Tuning.TENSION_MAX * face.size.x
	var hi := face.position.x + Tuning.SAFE_HI / Tuning.TENSION_MAX * face.size.x
	var good := sim.in_band()

	# The case. A style box rather than draw_rect, because a rounded corner and
	# a drop shadow are the two cheapest things that stop a HUD element looking
	# like it was pasted on.
	var case := StyleBoxFlat.new()
	case.bg_color = Color(0.055, 0.070, 0.078, 0.90)
	case.border_color = Color(0.72, 0.58, 0.32, 0.75)
	case.set_border_width_all(3)
	case.set_corner_radius_all(int(h * 0.16))
	case.shadow_color = Color(0, 0, 0, 0.45)
	case.shadow_size = 9
	case.shadow_offset = Vector2(0, 4)
	_tension_bar.draw_style_box(case, Rect2(Vector2.ZERO, _tension_bar.size))

	# The safe band. It BREATHES when you are in it, which is the whole feedback
	# loop: the player should be able to tell without looking straight at it.
	var pulse := 0.0
	if good:
		pulse = 0.13 + 0.09 * sin(sim.fight_time * 7.0)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.42, 0.74, 0.40, (0.24 if good else 0.11) + pulse)
	band.set_corner_radius_all(int(h * 0.09))
	_tension_bar.draw_style_box(band,
		Rect2(lo, face.position.y, hi - lo, face.size.y))
	# Its edges, which are the two numbers that actually matter.
	for x in [lo, hi]:
		_tension_bar.draw_rect(
			Rect2(x - 1.5, face.position.y, 3.0, face.size.y),
			Color(0.66, 0.90, 0.60, 0.62))

	# STRAIN, creeping in from the right as the line starts to go. Drawn before
	# the ticks so the engraving stays on top of it.
	if sim.strain > 0.01:
		_tension_bar.draw_rect(
			Rect2(hi, face.position.y, (face.end.x - hi) * sim.strain, face.size.y),
			Color(0.82, 0.24, 0.18, 0.18 + 0.48 * sim.strain))

	# The engraved scale. Long marks every fifth, hanging from the top edge, so
	# the needle has something to move against and the band has a width.
	for i in 21:
		var tx := face.position.x + face.size.x * float(i) / 20.0
		var tall := face.size.y * (0.34 if i % 5 == 0 else 0.19)
		_tension_bar.draw_rect(Rect2(tx - 1.0, face.position.y, 2.0, tall),
			Color(0.90, 0.84, 0.68, 0.30 if i % 5 == 0 else 0.16))

	# WHAT IT IS AND HOW FAR OFF THE FISH IS, on the face of the dial. The
	# distance used to float in the middle of the lake in 44 pt type, which put
	# the two numbers the fight is about at opposite ends of the screen.
	var font := ThemeDB.fallback_font
	_tension_bar.draw_string(font,
		Vector2(face.position.x + 10, face.end.y - face.size.y * 0.16),
		"LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.20),
		Color(0.86, 0.78, 0.60, 0.42))
	_tension_bar.draw_string(font,
		Vector2(face.position.x, face.end.y - face.size.y * 0.16),
		"%.1f m" % sim.fish_distance, HORIZONTAL_ALIGNMENT_RIGHT,
		int(face.size.x - 10), int(h * 0.24), Color(0.98, 0.92, 0.76, 0.72))

	# THE NEEDLE, on a smoothed value with overshoot - see `_sync_needle`. Warm
	# where it should be, hot where it should not, with a glow behind it and a
	# pivot under it so it reads as a moving part rather than a marker.
	var nx := face.position.x + clampf(_needle, 0.0, 1.0) * face.size.x
	var col := Color(0.99, 0.90, 0.62) if good else Color(0.97, 0.50, 0.32)
	_tension_bar.draw_rect(Rect2(nx - h * 0.10, face.position.y, h * 0.20, face.size.y),
		Color(col.r, col.g, col.b, 0.14))
	_tension_bar.draw_rect(Rect2(nx - 2.5, face.position.y - pad * 0.4, 5.0,
		face.size.y + pad * 0.8), col)
	_tension_bar.draw_circle(Vector2(nx, h * 0.5), h * 0.15,
		Color(col.r, col.g, col.b, 0.92))
	_tension_bar.draw_circle(Vector2(nx, h * 0.5), h * 0.07, Color(0.10, 0.09, 0.08))


## The needle has WEIGHT. It chases the true tension with a spring rather than
## snapping to it, so a tap kicks it and it settles back - which is the
## difference between a readout that reports the number and an instrument that
## answers the thumb. The rules never see this value; it is presentation only.
func _sync_needle(dt: float) -> void:
	var want := clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0)
	# Stiff enough to keep up with a run, loose enough to overshoot a tap by a
	# few per cent and swing back inside about a fifth of a second.
	_needle_v += (want - _needle) * 168.0 * dt
	_needle_v *= exp(-13.0 * dt)
	_needle += _needle_v * dt
	_needle = clampf(_needle, -0.04, 1.04)


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

	# THE BOX: a tap picks a row, or shuts it if it lands outside.
	if _at_box and not _in_sequence:
		if pressed:
			_tap_box(at)
		_cast_area.accept_event()
		return

	# READING: a press starts a gesture, a release decides what it was. Swiping is
	# how a page turns now - see `_release_page`.
	if _reading and not _in_sequence:
		if pressed:
			_page_from = at
			_page_swiped = false
		else:
			_release_page(at)
		_cast_area.accept_event()
		return

	if pressed and _in_sequence:
		# Any touch cuts the sequence, and does nothing else with that touch -
		# skipping and casting on the same press would fire a cast the player
		# never asked for.
		_skip_sequence()
		_cast_area.accept_event()
		return

	# **TOUCHING THE WATER NEVER CASTS.** It used to load the rod, which meant
	# every stray tap - reaching for a button, steadying the phone, tapping a
	# thing in the boat - pulled the rod back. Casting belongs to the cast
	# button and nothing else; the water is only ever a tap on the fish.
	if pressed:
		_touching = true
		_drag_from = at
		_drag_moved = 0.0
		match sim.state:
			Sim.IDLE, Sim.HOLDING, Sim.LOST:
				pass
			Sim.FIGHTING:
				# NOT THE WHOLE SCREEN ANY MORE. Gideon: "there is no dedicated
				# button to fill the bar. I want a button instead of just tapping
				# the screen." The REEL button owns the fight; the water is for
				# casting and for striking.
				pass
			_:
				sim.tap()
	else:
		_touching = false
	_cast_area.accept_event()


## HOLD THE BUTTON TO LOAD THE ROD, LET GO TO THROW IT.
##
## Gideon: "I want holding the cast button to pull back the rod, then flick
## forward when you release it." Which is also how a cast actually works, and it
## puts the charge under a thumb that is not covering the water.
func _cast_pressed() -> void:
	match sim.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			# Whatever the button SAYS is what it does - one decision, made once,
			# so the caption can never lie about the behaviour.
			if not _over_water_shown:
				if _looking_at != "":
					_on_use()
				return
			sim.hold_cast()
			_charging = true
		Sim.NIBBLING:
			sim.tap()
		Sim.FIGHTING:
			# HELD, and that is the whole change. The same button that charges a
			# cast reels the fish, because they are the same gesture - press and
			# hold, let go when you have enough - and one button that means "do
			# the thing this moment wants" is the rule the caption already follows.
			sim.set_reeling(true)
		_:
			# Anything else: the button is a "reel in", and that happens on
			# release so the press can still show as a press.
			pass


func _cast_released() -> void:
	if sim.state == Sim.FIGHTING:
		sim.set_reeling(false)
		return
	if _charging:
		_charging = false
		if _audio != null and sim.state == Sim.CHARGING:
			_audio.play("cast", -5.0)
		# The cast goes WHERE YOU ARE LOOKING.
		_cast_yaw = _look_yaw
		sim.release_cast()
		return
	match sim.state:
		Sim.FLYING, Sim.SINKING, Sim.WAITING, Sim.FIGHTING:
			sim.reel_in()
			if _audio != null:
				_audio.play("reel", -8.0)
		_:
			pass


## THE STICK. Left thumb, bottom-left, and it holds a direction rather than
## reporting a movement - which is the difference Gideon is asking for: a drag
## has to be repeated to keep turning, a stick can simply be held.
func _stick_input(event: InputEvent) -> void:
	var pressed := false
	var at := Vector2.ZERO
	var moved := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenDrag:
		at = (event as InputEventScreenDrag).position
		moved = true
	elif event is InputEventMouseMotion:
		at = (event as InputEventMouseMotion).position
		moved = _stick_held
	else:
		return

	if moved:
		if _stick_held:
			_stick_to = at
	elif pressed:
		_stick_held = true
		_stick_from = at
		_stick_to = at
	else:
		_stick_held = false
		_stick_vec = Vector2.ZERO
	if _stick != null:
		_stick.queue_redraw()


## Turn the stick's offset into a look rate, once a frame.
func _sync_stick(dt: float) -> void:
	if _stick_held:
		var off := _stick_to - _stick_from
		var far := off.length()
		if far > STICK_RADIUS:
			off = off / far * STICK_RADIUS
			far = STICK_RADIUS
		_stick_vec = off / STICK_RADIUS
	else:
		_stick_vec = _stick_vec.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * dt))

	# A DEAD ZONE, because a thumb resting on a stick is not an instruction - but
	# a SCALED GRADIENT one, which is the difference between this and what was
	# here before.
	#
	# The old version was a hard cutoff: below 0.14 nothing at all, and at 0.141
	# the full fourteen per cent of top speed, arriving in one frame. That step is
	# felt every time the thumb crosses it, which is constantly, because the edge
	# of the dead zone is exactly where fine aiming happens. "I want the looking,
	# casting, and fishing mechanics to be much smoother."
	#
	# Rescaling from 0 at the dead zone's edge to 1 at full throw removes the step
	# entirely: the stick now starts from nothing wherever the thumb picks it up.
	var mag := _stick_vec.length()
	if mag <= STICK_DEAD:
		return
	var throw := (mag - STICK_DEAD) / (1.0 - STICK_DEAD)
	# ...and then an EXPONENTIAL RESPONSE on top. Linear means the slowest turn
	# available is a fourteen per cent lean, which is not slow enough to line up
	# on a float thirty metres out; squaring it gives a long, fine low end and
	# keeps the top speed where it was. `STICK_CURVE` 1.7 is inside the 1.5-2.0
	# the research gives for touch look.
	var gain := pow(throw, STICK_CURVE) / mag
	var v := _stick_vec * gain
	var speed := LOOK_RATE * look_sensitivity * dt
	_look_yaw_want = clampf(_look_yaw_want - v.x * speed,
		-LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
	_look_pitch_want = clampf(_look_pitch_want - v.y * speed * 0.72,
		-LOOK_PITCH_DOWN, LOOK_PITCH_UP)


## A DRAG ACROSS THE WATER NO LONGER TURNS THE VIEW. The stick does that, and only
## the stick.
##
## Gideon: "You can still turn by swiping the screen, I only want to be able to
## turn by using the virtual thumb stick."
##
## The drag was here first and the stick was added beside it, so for a while the
## game had two ways to look, which is one too many for a reason beyond tidiness:
## the whole screen is the cast button, so every swipe was BOTH a look and a
## cancelled cast, and a thumb that brushes sideways while charging lost the cast
## and moved the aim at the same time.
##
## What survives is the cancel, and it has to. A swipe that quietly charged and
## then fired a cast on release would be worse than the thing being removed.
func _apply_look(rel: Vector2) -> void:
	_drag_moved += rel.length()
	if _charging and _drag_moved > LOOK_SLOP:
		_charging = false
		# Abandon the charge the instant this becomes a swipe, so a brushed thumb
		# cannot throw a cast nobody asked for.
		sim.cancel_cast()


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
	_sync_stick(dt)
	_sync_needle(dt)
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
	# And the book shut. `freeze` means "the game, now, in a known state" - an
	# open logbook is as much a front door as the title is, and leaving it open
	# hid the HUD from every test that ran after one which used it.
	_reading = false
	# The box shut too. `freeze` means "the game, now, in a known state", and an
	# open toolbox is as much a front door as the title is - leaving it open hid
	# the HUD from every test that ran after one which used it.
	_at_box = false
	if _tacklebox != null:
		_tacklebox.state = Room3D.State.SHUT
		_tacklebox.openness = 0.0
	if _book != null:
		_book.state = Room3D.State.SHUT
		_book.openness = 0.0
		_book.page = 0
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
	#
	# THERE IS NO LONGER A READING CAMERA. It used to be the first branch here,
	# recomputing `_book_pose()` every frame to hold the eye over the page. Now
	# that the book is picked up instead, that branch became a feedback loop -
	# the book hangs off the camera and the camera hung off the book, so the two
	# chased each other; measured, they were sixteen metres away at the gate
	# within two hundred frames. The camera stays on the seat. The book moves.
	if _at_box and not _in_sequence and _tacklebox != null:
		# LEANING OVER THE BOX. A toolbox on the sole is not picked up, so unlike
		# the logbook the camera comes to it - which is safe here for the reason
		# it was not there: the box does not move, so there is no pair to chase
		# each other. Recomputed every frame so the view rides the swell with the
		# boat rather than hanging still above a moving hull.
		var bp := _box_pose()
		var bup: Vector3 = bp[2] if bp.size() > 2 else _boat_pose.basis.y
		_cam.transform = Transform3D(Basis.IDENTITY, bp[0]).looking_at(bp[1], bup)
	elif _in_sequence:
		# The camera goes on rails and NOTHING ELSE IS SKIPPED. An early return
		# here meant the rest of `_sync` never ran during a sequence - so the
		# HUD, which stands down on exactly that condition, was never told to.
		# The title showed a purse and a Cast button over the gate.
		_cam.transform = Transform3D(Basis.IDENTITY, _seq_at).looking_at(_seq_look, Vector3.UP)
	else:
		_sync_play_camera(out)

	_float.position = out
	_float.visible = sim.state != Sim.IDLE and sim.state != Sim.CHARGING 		and sim.state != Sim.HOLDING and not _in_sequence
	# The line exists exactly when the float does, and `_draw_line_between` is the
	# only thing that shows a segment - so ask it for nothing when there is no
	# cast, rather than drawing a curve and hiding it afterwards.
	if _float.visible:
		_draw_line_between(_rod_tip, out)
	else:
		for seg in _line_chain:
			seg.visible = false

	_sync_wake(out)
	_sync_fish()
	_write_readout()
	_sync_bars()
	_sync_primary_button()
	_sync_room_bar()
	_sync_box_hud()


## The camera during play: riding the boat, riding the water.
func _sync_play_camera(out: Vector3) -> void:
	#
	# This is the single largest thing that was missing. Swink's definition of
	# game feel starts with "real-time control of virtual objects in a simulated
	# space" - and until now the space did not move and the player controlled
	# nothing continuously at all. A lake that heaves under you turns a picture
	# into a place, and it costs two wave samples a frame.
	var seat := Sequence.SEAT
	# THE EYE RIDES `_cam_pose`, NOT `_boat_pose` - a damped share of the hull.
	# See the note on `_sync_cam_pose`: the head keeps itself level, so the boat
	# swings against the horizon instead of the horizon swinging against the boat.
	var eye := _cam_pose * seat
	# Yaw and pitch are the PLAYER's, applied on top of the boat's own motion, so
	# looking around never fights the swell and the swell never steals the aim.
	# A Godot camera looks down its own -Z, and the boat's bow is at +Z, so the
	# rig has to be turned about. The old code used `looking_at`, which hid this
	# entirely; building the basis by hand to carry the boat's motion exposed it,
	# and the first frame of it was a beautifully lit view out over the stern.
	var basis := _cam_pose.basis * Basis(Vector3.UP, PI + _look_yaw) 		* Basis(Vector3.RIGHT, _look_pitch)
	# Sat down, looking a little above the horizon.
	basis = basis * Basis(Vector3.RIGHT, deg_to_rad(REST_TILT))
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

	# THE ROD IS HELD IN A HAND, IN A BOAT THAT IS MOVING.
	#
	# Gideon: "the rod and the fishing line don't react to movement and don't feel
	# great." They did not react at all - the chain was a pure function of sim
	# state, so a rod in a boat rolling ten degrees stayed welded to the deck as
	# if it were bolted there. Two separate models of one world, which is the
	# fault this game's own notes name most often.
	#
	# A mass on the end of a springy stick LAGS the hand carrying it. The lag is
	# what makes it read as having weight, and it is cheap: track the hull's
	# angular VELOCITY, damp it, and feed it in as extra bend and sideways whip.
	# Researched time constant for prop lag is 0.1-0.2 s; ROD_LAG_FOLLOW is 0.14.
	#
	# It is derived from `_boat_pose`, not from `_cam_pose`, on purpose. The rod
	# is in the boat, the eye is not - which is exactly why the rod now visibly
	# moves against the view instead of with it.
	var lag_pitch := rad_to_deg(_rod_lag_pitch) * ROD_LAG_BEND
	var lag_roll := rad_to_deg(_rod_lag_roll) * ROD_LAG_WHIP
	for i in _rod_chain.size():
		var share: float = ROD_CURVE[i] * bend
		# The lag builds along the rod exactly as the bend does - a butt barely
		# moves and a tip moves most - so one curve describes both.
		var lag_share: float = ROD_CURVE[i] * lag_pitch
		var whip_share: float = ROD_CURVE[i] * lag_roll
		if i == 0:
			# The butt carries the whole swing plus its share of the bend. Both
			# are down-positive, and `back` is a lift, so it subtracts.
			_rod_chain[i].rotation_degrees = Vector3(
				ROD_REST - back + share + lag_share, whip_share, 9.0)
		else:
			_rod_chain[i].rotation_degrees = Vector3(share + lag_share, whip_share, 0.0)
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


## THE LINE, AS A LINE UNDER TENSION - not a stick between two points.
##
## It was one stretched box from the rod tip to the lure: perfectly straight at
## all times, identical slack or hooked, and unmoved by anything the boat did.
## Gideon: "the rod and the fishing line don't react to movement and don't feel
## great."
##
## What makes a line read as a line is that it is the only thing on screen whose
## SHAPE is a readout of a force. So the shape is driven by the number the fight
## is already using:
##
##   slack (no fish)   - hangs in a catenary and sways behind the rod tip
##   tension rising    - the sag pulls out of it
##   near breaking     - dead straight, and it is the straightness that reads
##
## Which means the player can see how much trouble they are in without looking at
## the gauge at all - the same principle as the float being the nibble minigame.
## One number, two readings, and they cannot disagree because there is only one.
##
## Built as a strip of segments rather than a curve resource: the sag is one
## `sin` per joint and the whole thing is eleven small transforms, which costs
## less than the ribbon it replaces would and needs no addon. Verlet rope is the
## "correct" answer and is deliberately not used - this game's rules are pure
## arithmetic, and a physics body would be a second model of the same world.
const LINE_JOINTS := 10
const LINE_SAG := 0.30      ## metres of droop at midspan on a fully slack line
const LINE_SWAY := 0.055    ## metres of lateral lag, slack, at midspan
const LINE_SWAY_RATE := 1.7 ## how fast a slack line swings


func _draw_line_between(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var span := d.length()
	if span < 0.001:
		_line.visible = false
		for seg in _line_chain:
			seg.visible = false
		return
	_line.visible = false

	# How taut it is. Only a fight has a real tension, but a cast in flight is
	# being dragged through the air and a sinking lure is pulling it down, so
	# those get their own values rather than hanging slack in mid air.
	var taut := 0.0
	match sim.state:
		Sim.FIGHTING:
			taut = clampf(sim.tension / Tuning.TENSION_MAX, 0.0, 1.0)
		Sim.FLYING:
			taut = 0.92
		Sim.NIBBLING:
			taut = 0.34 + sim.tug * 0.30
		Sim.SINKING, Sim.WAITING:
			taut = 0.30
		_:
			taut = 0.22
	var slack := 1.0 - taut
	# A long line sags further than a short one, which is what stops a
	# thirty-metre cast looking as tight as a two-metre one.
	var sag := LINE_SAG * slack * clampf(span / 12.0, 0.25, 1.6)
	var sway := LINE_SWAY * slack * clampf(span / 12.0, 0.25, 1.6)
	# The sway is driven off the ROD's lag, so the line trails the same motion the
	# rod does, one step further behind. That is the whole "reacts to movement"
	# ask: the boat moves, the rod trails it, and the line trails the rod.
	var phase := _boat_time * LINE_SWAY_RATE + _rod_lag_roll * 2.0
	var side := d.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT

	for i in LINE_JOINTS:
		var t0 := float(i) / float(LINE_JOINTS)
		var t1 := float(i + 1) / float(LINE_JOINTS)
		var p0 := _line_point(a, b, t0, sag, sway, side, phase)
		var p1 := _line_point(a, b, t1, sag, sway, side, phase)
		var seg := _line_chain[i]
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1)
		if seg_len < 0.0001:
			seg.visible = false
			continue
		seg.visible = true
		seg.transform = Transform3D(Basis.IDENTITY, mid).looking_at(p1, Vector3.UP)
		seg.scale = Vector3(1.0, 1.0, seg_len)


## One point along the line. `sin(PI * t)` is zero at both ends and one in the
## middle, which is the whole reason the sag never detaches the line from the rod
## tip or the lure - the two places a visible gap would be unforgivable.
func _line_point(a: Vector3, b: Vector3, t: float, sag: float, sway: float,
		side: Vector3, phase: float) -> Vector3:
	var p := a.lerp(b, t)
	var belly := sin(PI * t)
	p.y -= sag * belly
	p += side * sin(phase + t * 2.4) * sway * belly
	return p


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
			# NOTHING. The distance moved onto the face of the gauge, where it
			# sits beside the tension instead of 700 px away from it: during a
			# fight the player's eye should have ONE place to go. Floating it
			# over the middle of the lake in 44 pt also put the game's largest
			# type on top of the thing the game is about.
			line = ""
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
	if _book != null:
		_book.advance(dt)
		_sync_book_hold(dt)
	if _tacklebox != null:
		_tacklebox.advance(dt)
		_sync_box_items()
		if _box_lamp != null:
			_box_lamp.light_energy = 2.4 * _tacklebox.openness if _at_box else 0.0
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
		var cl: float = _water_mat.get_shader_parameter("clarity")
		# Clearer in the reeds, opaque in the deep. Depth is time, and the older
		# the water the less it gives up.
		_water_mat.set_shader_parameter("clarity",
			lerpf(cl, lerpf(0.34, 0.05, _dread), k))
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
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


## THE ANDROID BACK BUTTON, which `quit_on_go_back=false` hands to us.
##
## It unwinds ONE layer, the same order `_hud_is_down` layers them in, and only
## leaves the game when there is nothing left to back out of. Godot's default is
## to quit the app on this button, which from inside an open logbook or the shed
## is indistinguishable from a crash - the player meant "shut this", not "throw
## the morning away".
##
## The opposite mistake is just as easy and it is why the project setting and this
## function belong in the same commit: turning the default off and handling nothing
## makes the button DEAD, and a dead system button reads as a hung app.
func _go_back() -> bool:
	if not _booted:
		return false
	if _reading:
		_shut_book()
		return true
	if _at_box:
		_shut_tacklebox()
		return true
	if _menus != null and _menus.is_open():
		_menus.close()
		return true
	if _in_sequence:
		# Same courtesy a touch gets: a cinematic you cannot leave is the worst
		# thing in the game by the fifth time through it.
		_in_sequence = false
		_seq.running = false
		return true
	if _title != null and _title.is_up():
		# The title IS the front door. Back from here is the way out of the app.
		_save_game()
		get_tree().quit()
		return false
	# On the seat with nothing open: save, then go. The save matters because
	# NOTIFICATION_WM_CLOSE_REQUEST does not arrive on an Android back-out.
	_save_game()
	get_tree().quit()
	return false


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

	# A CASE, and a screen inside it. At 62% alpha over a bright sky the old flat
	# rectangle averaged out to mid-grey with hard square corners, which is the
	# single most placeholder-looking thing that can appear on a screen.
	var case := StyleBoxFlat.new()
	case.bg_color = Color(0.018, 0.042, 0.050, 0.88)
	case.border_color = Color(0.50, 0.72, 0.64, 0.42)
	case.set_border_width_all(2)
	case.set_corner_radius_all(12)
	case.shadow_color = Color(0, 0, 0, 0.40)
	case.shadow_size = 8
	case.shadow_offset = Vector2(0, 4)
	_sounder.draw_style_box(case, Rect2(0, 0, w, h))
	# The phosphor wash, brightest at the top where the transducer is.
	_sounder.draw_rect(Rect2(2, 2, w - 4, h * 0.34), Color(0.30, 0.62, 0.55, 0.055))

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
	# ANISOTROPIC, AND IT IS THE SINGLE BIGGEST LOOK FIX IN THE GAME.
	#
	# Every plank in this boat is seen almost edge on, and the grain tiles seven
	# to twenty times across it. Without mipmaps at all - which is how these
	# textures imported, `mipmaps/generate=false` by default - the normal map
	# aliases into a dither of black and tan speckle across the hull, the floor
	# and the rail. It reads as compression noise and it is why "the graphics
	# still dont look very polished". The default trilinear filter fixes the
	# speckle but smears the grain at a glancing angle, which is exactly the
	# angle everything here is at; anisotropic keeps both.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
			# A half-ellipse from port rim, down round the bilge, up to starboard -
			# and a little PAST the rim at each end.
			#
			# The overshoot is the fix for a dashed white hairline that ran the
			# length of the port sheer in every screenshot ever taken of this
			# boat. The skin ended exactly at the rim and the gunwale bar was
			# centred exactly on it, so the two met edge to edge with nothing to
			# spare; the skin falls away inboard as it descends while the bar's
			# inner face is straight, and the slit that opens between them is a
			# hole to the sky. Photographed as an artefact, chased as a shader
			# bug, and it was a hull with a gap in it. Now the planking runs a few
			# centimetres up INSIDE the rail, the way real planking does.
			var a := -0.16 + (PI + 0.32) * float(j) / float(HULL_ARC - 1)
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


## THE HULL AND THE HEAD ARE TWO DIFFERENT THINGS, and separating them is what
## lets the boat move without the picture moving.
##
## A person in a small boat does not rotate with it. The neck and the inner ear
## hold the head roughly level - the vestibulo-ocular reflex is doing it whether
## you like it or not - so a passenger watching the far bank sees the GUNWALES
## swing against a horizon that stays put. Rendering the camera as bolted to the
## hull reproduces the opposite: a level boat inside a world that heaves.
##
## So the camera takes a SHARE of the hull's motion, and takes it late:
##
##   share  - how much of the hull's angle the head keeps. Rotation is what makes
##            people ill and translation is what makes a boat feel afloat, so
##            heave passes through almost whole and pitch keeps least.
##   follow - slower than the hull's own damping, so the head lags the deck. That
##            lag is most of what reads as a neck rather than a tripod.
##
## Researched rather than invented, and the shares below sit inside the range the
## research gives: inherit the hull's POSITION nearly untouched, take 20-30% of its
## ROTATION, and smooth with a time constant of about 0.5-1 s (`CAM_FOLLOW` 2.1 is
## 0.48 s). The cautionary case is Sea of Thieves, which bolts the first-person
## camera to the hull: it is the longest-running complaint on that game's own
## forums and it is the exact thing this game was doing.
##
## Measured, 40 s, from `scripts/probe_motion.gd`, which is the only reason any of
## these numbers can be defended:
##
##            hull p2p   camera p2p   camera peak rate
##   before     20.0 deg    20.0 deg      41.9 deg/s      "the movement has felt odd"
##   after       5.0 deg     1.1 deg       3.1 deg/s
##
## The hull still moves - more visibly than before against a steady horizon, which
## is the point - and the view no longer swings.
const HULL_FOLLOW := 3.2       ## how fast the hull answers the swell
const HULL_HEAVE := 0.78       ## metres of rise, as a share of the sampled wave
const HULL_PITCH := 1.05       ## a long hull in a low swell barely pitches
const HULL_ROLL := 0.80        ## ...and rolls about twice as far as it pitches
const CAM_FOLLOW := 2.1        ## the head lags the deck. Lower than HULL_FOLLOW
const CAM_PITCH_SHARE := 0.22  ## rotation is what makes people ill
const CAM_ROLL_SHARE := 0.30
const CAM_HEAVE_SHARE := 0.90  ## ...and translation is what makes it feel afloat


## How far the rod is trailing the boat, right now.
##
## The quantity is the hull's angular VELOCITY, damped - not its angle. That
## distinction is the whole effect: a rod in a boat held at a steady angle hangs
## straight, and it is only while the deck is TURNING that the tip is left behind.
## Driving it from the angle instead would bend the rod hardest at the top of a
## roll, where a real one is momentarily still.
const ROD_LAG_FOLLOW := 0.14   ## seconds. Researched prop lag is 0.1-0.2 s
const ROD_LAG_BEND := 0.55     ## degrees of tip lag per degree/s of hull pitch
const ROD_LAG_WHIP := 0.42     ## ...and sideways, per degree/s of hull roll


func _sync_rod_lag() -> void:
	if _boat_dt <= 0.0:
		return
	var d_pitch := (_boat_pitch - _rod_lag_last_pitch) / _boat_dt
	var d_roll := (_boat_roll - _rod_lag_last_roll) / _boat_dt
	_rod_lag_last_pitch = _boat_pitch
	_rod_lag_last_roll = _boat_roll
	var k := 1.0 - exp(-_boat_dt / ROD_LAG_FOLLOW)
	_rod_lag_pitch = lerpf(_rod_lag_pitch, d_pitch, k)
	_rod_lag_roll = lerpf(_rod_lag_roll, d_roll, k)


func _sync_cam_pose() -> void:
	var ck := 1.0 - exp(-CAM_FOLLOW * _boat_dt)
	_cam_heave = lerpf(_cam_heave, _boat_heave * CAM_HEAVE_SHARE, ck)
	_cam_pitch = lerpf(_cam_pitch, _boat_pitch * CAM_PITCH_SHARE, ck)
	_cam_roll = lerpf(_cam_roll, _boat_roll * CAM_ROLL_SHARE, ck)
	var b := Basis(Vector3.RIGHT, _cam_pitch) * Basis(Vector3.FORWARD, _cam_roll)
	_cam_pose = Transform3D(b, Vector3(0.0, _cam_heave, 0.0))


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

	# The damping IS the boat. A dinghy answers a swell late and ROLLS FURTHER
	# THAN IT PITCHES, which is most of what tells you how big the boat is.
	#
	# These multipliers were once 4.20 on pitch and 1.45 on roll, which inverted
	# that: measured, the hull pitched 20 degrees peak to peak and rolled 18. The
	# reason is worth keeping, because the fix that produced it was correct
	# reasoning from a true premise - at the honest numbers the report was "the
	# boat is flat the whole time", because THE CAMERA RIDES THE BOAT and a
	# camera that matches the hull exactly sees no motion at all. Exaggerating the
	# hull was the only lever available, so it got pulled until the horizon moved.
	#
	# But it moves the camera too, and 20 degrees of camera pitch at 0.55 Hz is
	# not a boat, it is a fairground ride: "the movement has felt odd." The lever
	# was the wrong one. `_sync_cam_pose` below is the right one - the head is
	# separated from the hull, so the boat can move properly and the view can stay
	# still, and neither complaint has to be traded against the other any more.
	# Now that the two are independent, these are back to what a rowing boat does.
	var k := 1.0 - exp(-HULL_FOLLOW * _boat_dt)
	_boat_heave = lerpf(_boat_heave, heave * HULL_HEAVE, k)
	_boat_pitch = lerpf(_boat_pitch, pitch * HULL_PITCH, k)
	_boat_roll = lerpf(_boat_roll, roll * HULL_ROLL, k)

	var basis := Basis(Vector3.RIGHT, _boat_pitch) * Basis(Vector3.FORWARD, _boat_roll)
	_boat_pose = Transform3D(basis, Vector3(0.0, _boat_heave, 0.0))
	_sync_cam_pose()
	_sync_rod_lag()
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
## WHERE THE FLOAT ACTUALLY IS, and the Y is the whole of it.
##
## Gideon: "the bobber comes all the way out of the water, or goes completely below
## the wave, even when a fish isn't biting."
##
## It was `_boat_pose * local` - the float rode the BOAT. Two faults in one line,
## and the second is much larger than the first:
##
##  1. The boat heaves on its own wave, thirty metres from the float's wave, so
##     the two were never at the same point in the swell.
##  2. `_boat_pose` carries the hull's PITCH, and a point thirty metres down +Z
##     rotated by two and a half degrees moves 1.3 METRES vertically. The float
##     was being swung a metre and a half up and down by the boat tipping.
##
## Both are the same underlying fault the rest of this game is careful about: two
## models of one surface. The water is a shader driven by `WAVES`, and the thing
## floating on it was reading the hull instead. Now it reads the water, from the
## same array the shader is generated from, so the float and the surface it sits
## in cannot disagree.
##
## The dip stays exactly what it was - `_lure_position` returns Y as depth BELOW
## the waterline - so minigame one is untouched. It is now measured from a
## waterline that moves, which is what makes a tease read as a tease rather than as
## the lake going past.
func lure_world_position() -> Vector3:
	var local := Basis(Vector3.UP, _cast_yaw) * _lure_position()
	match sim.state:
		Sim.IDLE, Sim.CHARGING, Sim.HOLDING:
			# In the hand and in the boat, so it rides the hull like the rod does.
			return _boat_pose * local
		_:
			pass
	# On the water, or in the air above it. The boat sits at the origin and only
	# heaves, so the float's XZ is its own - it must not inherit the hull's tilt.
	return Vector3(local.x, water_height(local.x, local.z) + local.y, local.z)


## The height of the lake surface at a point, from the same `WAVES` the shader is
## built from. Public because the smoke test asks the same question the renderer
## does, and a float that agrees with a private copy of the water proves nothing.
func water_height(x: float, z: float) -> float:
	return _wave_offset(x, z, _boat_time).y


# --- the one button ---------------------------------------------------------

## What the action button DOES right now, as one word the player can read.
##
## Derived from the state rather than stored, so the label and the behaviour are
## the same decision made once. A button whose caption and effect are computed in
## two places is a button that lies the first time a state is added.
func _action_for_state() -> String:
	match sim.state:
		Sim.IDLE, Sim.HOLDING, Sim.LOST:
			# CAST ONLY OVER THE WATER. Looking into the boat, the same button
			# becomes Select - which is what the moment wants there, and stops the
			# game offering a cast into its own floorboards.
			if not _over_water_shown:
				return "Select"
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
			# THE CAPTION IS THE TELEGRAPH. During the tell and the run, the same
			# button that says REEL says LET GO instead - so the instruction is on
			# the control the thumb is already on, not only on a wake out on the
			# water where nobody is looking during a fight. Gideon: "it is also
			# not obvious that the fish will pull back and add pressure to the bar."
			if sim.running or sim.tell > 0.0:
				return "LET GO"
			return "Reel"
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
			# The stick looks, and only the stick. This line still said "drag to
			# look around" for one build after the drag was removed, which is the
			# worst kind of hint: it teaches a control that no longer exists.
			return "hold the water to aim and cast   -   lean the stick to look"
		Sim.CHARGING:
			return "let go to cast"
		Sim.SINKING, Sim.WAITING:
			return "watch the float"
		Sim.NIBBLING:
			return "tap when it goes under"
		Sim.FIGHTING:
			# HOLD, not tap - and this line taught the wrong control for one
			# build after the fight changed, exactly as the look hint did. A hint
			# that names a control the game no longer has is worse than no hint,
			# because the player trusts it and concludes the game is broken.
			if sim.running or sim.tell > 0.0:
				return "LET GO   -   it is running"
			return "hold to reel   -   let go when it runs"
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
			"at": Vector3(-0.34, _hull_floor_y(0.98) + 0.14, 0.98),
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
			"at": Vector3(-0.22, _hull_floor_y(1.90) + 0.10, 1.90),
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
			"id": "logbook",
			"name": "The logbook",
			"at": Vector3(-0.26, _hull_floor_y(1.30) + 0.11, 1.30),
			"look": func() -> String:
				var met := Keepers.hands_met(sim.deepest_ever)
				return "The keeper's logbook   -   %d of %d hands" % [met, Keepers.total_hands()],
			"use": func() -> void:
				_open_book(),
		},
		{
			"id": "tacklebox",
			"name": "The tackle box",
			"at": Vector3(0.14, _hull_floor_y(1.52) + 0.14, 1.52),
			"look": func() -> String:
				return "The tackle box   -   %s on the hook" % str(
					Gear.bait_by_id(sim.econ.bait)["name"]),
			"use": func() -> void:
				_open_tacklebox(),
		},
		{
			"id": "rope",
			"name": "The rope",
			"at": Vector3(0.34, _hull_rim_y(1.05) + 0.06, 1.05),
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
var _book: Room3D
var _book_page: VBoxContainer
var _book_pages := 1
var _reading := false
## THE BOOK IS PICKED UP, so it needs a resting place to be picked up FROM and a
## pose to be held in. See `_sync_book_hold`.
var _book_rest := Transform3D.IDENTITY
var _book_hold := 0.0        ## 0 on the sole, 1 in the hands
var _book_hold_want := 0.0
var _book_rel := Transform3D.IDENTITY
## The swipe that turns a page, and the little kick the paper gives afterwards.
var _page_from := Vector2.ZERO
var _page_swiped := false
var _page_turn := 0.0
## THE TACKLE BOX. See `_build_tacklebox`.
var _tacklebox: Room3D
var _box_list: VBoxContainer
var _box_rows: Array = []
## The real things lying in the box. See `_build_box_items`.
var _box_items: Array[Node3D] = []
var _box_lamp: OmniLight3D
var _box_name: Label
var _box_note: Label
var _box_pips: Control
var _box_left: Button
var _box_right: Button
var _at_box := false
## id -> the measured centre of its geometry, in boat space. See `_build_aim_points`.
var _aim_points: Dictionary = {}
## Which side of the gunwale the primary button is currently showing, and how
## long the ray has been on the other one. See `_sync_primary_button`.
var _over_water_shown := true
var _boundary_held := 0
var _box_sel := 0
## The bar of controls shown while a room is open. See `_build_room_bar`.
var _room_bar: HBoxContainer
var _room_prev: Button
var _room_next: Button
var _room_ok: Button
var _room_close: Button
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
	# THE NEAREST THING IN THE CONE, not the best aligned one.
	#
	# Taking the highest dot product means a distant object that happens to line
	# up beats a near one you are looking straight at. Found by the assertion that
	# looking at a thing must select it: the bait box and the tackle box selected
	# EACH OTHER, because from the seat they are nearly collinear and whichever
	# was further had the marginally smaller angle. "What am I looking at" means
	# the closest thing along the line, the way an eye means it.
	#
	# The cone is widened for things that are close, because angular size grows as
	# you approach: a bucket at 70 cm subtends far more than ten degrees, so a
	# fixed cone made the nearest objects the hardest to select - which is the
	# livewell reporting nothing at all while being stared at.
	var best := {}
	var best_range := INF
	for t in _things:
		var at: Vector3 = _boat_pose * aim_point_of(t)
		var to := (at - eye)
		var range_to := to.length()
		if range_to < 0.05:
			continue
		var d := fwd.dot(to.normalized())
		# AIM_COS at arm's length, opening up as the thing gets closer.
		var cone: float = lerpf(AIM_COS_NEAR, AIM_COS, clampf((range_to - 0.5) / 0.9, 0.0, 1.0))
		if d < cone:
			continue
		if range_to < best_range:
			best_range = range_to
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
	"book": "res://assets/props/binder_notebook/binder_notebook_1k.gltf",
	"toolbox": "res://assets/props/metal_toolbox/metal_toolbox_1k.gltf",
	# In the tackle box. The only two things on the tray list that exist as free
	# photoreal models anywhere - and both come from the same Poly Haven
	# collection the toolbox itself does, so they need no reconciling.
	"knife": "res://assets/props/fish_knife/fish_knife/fish_knife_1k.gltf",
	"pliers": "res://assets/props/pliers/pliers/pliers_1k.gltf",
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
	_place_prop("livewell", Vector3(-0.34, _hull_floor_y(0.98), 0.98), 0.80, 18.0)
	_place_prop("baitbox", Vector3(-0.22, _hull_floor_y(1.90), 1.90), 0.50, -12.0)
	# The lantern goes on the STEM, where it lights the water ahead rather than
	# the boards - and where it is a silhouette against the sky at night.
	var lamp := _place_prop("lamp", Vector3(0.0, _hull_rim_y(2.05) + 0.03, 2.05), 1.05, 0.0)
	if lamp != null:
		_lamp_prop = lamp
	_place_prop("lifebuoy", Vector3(-0.56, _hull_rim_y(0.95) - 0.16, 0.95), 0.62, 90.0)

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
	# LONG ENOUGH TO STAND ON. It was 11 m and the new-game camera starts at
	# z = -26, which put the player wading toward their own gate across open
	# lake. The bank has to reach behind the furthest shot in any sequence.
	bm.size = Vector3(30.0, 0.5, 26.0)
	bank.mesh = bm
	var bank_mat := _mat(Color(0.20, 0.20, 0.17), 0.98)
	var stone_n := load("res://assets/tex/stone_normal.jpg")
	if stone_n != null:
		bank_mat.normal_enabled = true
		bank_mat.normal_texture = stone_n
		bank_mat.normal_scale = 0.7
		bank_mat.uv1_scale = Vector3(7.0, 3.0, 1.0)
		bank_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	bank.mesh = bm
	bank.material_override = bank_mat
	bank.position = Vector3(0.0, 0.12, SHORE_Z - 6.0)
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
	# Pulled well off the map's own red. A warm brick reads as a garden wall in
	# the Home Counties; this valley is quarried grey-green stone and the wall
	# has to belong to the same place as the water in front of it.
	m.albedo_color = Color(0.42, 0.45, 0.42)
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
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	return _in_sequence or _reading or _at_box


# --- the book, as a thing in the boat ---------------------------------------

## Paper, ink and rule for the page. Same values the flat room used, because it
## is the same paper - only now it is printed onto a page instead of the screen.
const PAGE_WARM := Color(0.878, 0.847, 0.773)
const PAGE_INK := Color(0.145, 0.130, 0.110)
const PAGE_INK_DIM := Color(0.145, 0.130, 0.110, 0.58)
const PAGE_RULE := Color(0.145, 0.130, 0.110, 0.18)


## THE LOGBOOK LIES ON THE THWART.
##
## It is a real notebook, at a real place in the hull, and the page is a
## SubViewport printed onto a quad just above the cover. Look at it, press Use,
## and the camera comes down over it while it opens.
func _build_book() -> void:
	var model := _prop("book")
	if model == null:
		push_warning("the logbook model is missing - the book will not open")
		return
	# Real size. The mesh is 36 cm across open, which is about right for a
	# keeper's ledger, so it needs no scaling at all.
	#
	# THE TURN IS ON THE OBJECT, NOT ON THE MODEL. It used to be set here, on the
	# mesh alone - and the printed page is a sibling of the mesh, not a child of
	# it, so the paper lay across the notebook fourteen degrees out of true with
	# the cover showing past two of its corners.

	_book = Room3D.new()
	_book.name = "Logbook"
	# On the sole, on the clear side. It was on the thwart at first and the rope
	# coil sat straight across the open page.
	# ABOVE THE FLOORBOARDS. The planks are 30 mm thick and sit 20 mm off the
	# sole, so their top face is at floor + 35 mm - and the book was at +12 with
	# its page at +32, which buried the page INSIDE the floor. Only the corner
	# poking past a plank edge was visible, and it cost four rounds of blaming
	# the camera, the quad, the viewport and the anchors in turn. The texture had
	# been correct the whole time.
	# FORWARD, WHERE THE SEATED PLAYER CAN SEE IT. At z = 0.10 it lay two metres
	# ahead and 1.13 m below a camera that sits 1.35 m up, which puts it 27
	# degrees below the view axis - the very bottom edge of a 58 degree frame,
	# behind the near thwart. "I dont see the log book in the game" was literally
	# true: the object existed, in shot, and off the bottom of the picture.
	# FRONT AND CENTRE ON THE SOLE, and this is the third time this object has had
	# to move for the same reason. Gideon, on the phone: "i cant see the log book
	# on the ground" - in a frame whose own prompt read "The keeper's logbook - 2
	# of 5 hands", so the crosshair was on it and the eye still could not find it.
	# It was at z = 1.80, up by the bow, where the sole is narrow, dark and behind
	# every other prop. Here it is the nearest thing on the floor, in the clear
	# space between the tackle box and the bucket, and nothing overlaps it.
	_book.position = Vector3(-0.26, _hull_floor_y(1.30) + 0.052, 1.30)
	# Not square to the boat. A book somebody put down is never square to
	# anything, and this is the whole difference between a prop and a menu.
	_book.rotation_degrees = Vector3(0, 14, 0)
	# Read from just above and behind, looking down - the pose of somebody
	# leaning over a book that was already here rather than holding their own.
	# FAR ENOUGH BACK TO SEE THE WHOLE SPREAD. The page is 33 cm wide and the
	# frame is portrait, so the visible width at distance d is only about 0.51*d
	# - at 40 cm that is 20 cm and two thirds of the book is off screen, which is
	# exactly how the first pass came out. 80 cm fits it with room to spare.
	_book_rest = _book.transform
	_book.read_from = Vector3(0.02, 0.72, -0.36)
	_book.read_at = Vector3(0.026, 0.02, 0.02)

	var page := _page_root()
	# A5-ish, and the pixel size is what decides whether the ink is crisp when
	# the camera is 40 cm off it.
	# The page is sized and placed off the OPEN mesh's own bounds - 36 x 20 cm,
	# centred at x = 2.6 cm - rather than guessed at. A quad that does not match
	# the book it is printed on reads as a sheet lying beside it, which is
	# exactly how the first attempt came out.
	# THE PAGE FACES THE READER. Laying the quad flat with a -90 turn about X
	# leaves its up-axis pointing at a camera that is BEHIND the book, so the
	# whole page came out upside down. The extra half turn about the page's own
	# normal is what puts the top of the text at the far edge.
	var lie_flat := Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	_book.build(model, Vector2(0.335, 0.185),
		Transform3D(lie_flat, Vector3(0.026, 0.020, 0.0)),
		page, BOOK_PAGE_PX)
	_boat.add_child(_book)
	_refresh_book()


## The Control tree that becomes the page texture.
## THE ROOT *IS* THE PAPER.
##
## It was a bare Control with a full-rect ColorRect inside it, and the anchoring
## did not resolve against a SubViewport the way it does against a Control - so
## the paper covered only part of the page and the rest of the quad showed the
## viewport's own dark clear colour. A ColorRect sized directly cannot have that
## problem: there is no anchor to fail to resolve.
func _page_root() -> Control:
	var root := ColorRect.new()
	root.color = PAGE_WARM

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 64)
	pad.add_theme_constant_override("margin_right", 48)
	pad.add_theme_constant_override("margin_top", 54)
	pad.add_theme_constant_override("margin_bottom", 54)
	root.add_child(pad)

	_book_page = VBoxContainer.new()
	_book_page.add_theme_constant_override("separation", 14)
	pad.add_child(_book_page)
	return root


func _refresh_book() -> void:
	if _book_page == null:
		return
	_book_pages = Book3D.fill(_book_page, sim, _book.page if _book != null else 0,
		PAGE_INK, PAGE_INK_DIM, PAGE_RULE)


## THE BOOK IS PICKED UP AND HELD, rather than the camera diving onto the floor.
##
## Gideon: "When you look at the log book and hit the interact button, can you make
## it so that you actually pick up and view the log book."
##
## The difference is not cosmetic. Flying the camera down to a book on the sole
## says "this is a menu, rendered in the world"; the hands lifting it says "you are
## a person in a boat holding your own book". It is also the gesture the game ENDS
## on - in Act III the logbook is the last offering - and handing over a thing you
## have never held costs nothing.
##
## Mechanically it is the same move inverted. `_book_rel` is the camera-to-book
## transform the old reading pose produced, so hanging the book off the live camera
## by that transform frames it identically while leaving the player's head free:
## the lake stays visible over the top of the page, which is the whole point of
## reading in the boat rather than in a screen.
const BOOK_HOLD_RATE := 3.4    ## how fast it comes up. About 0.3 s, hand speed
## Where it sits in the hands, in CAMERA space: a little below the view axis so
## the lake stays visible over the top of it. 0.92 m rather than a real reading
## distance of 0.45 because the spread is 36 cm wide and the frame is portrait -
## the horizontal half-angle here is only 14 degrees, so a book any closer runs
## off both sides. That is a phone constraint, not an anatomy one.
const BOOK_HELD_AT := Vector3(0.02, -0.10, -0.92)


func _sync_book_hold(dt: float) -> void:
	if _book == null:
		return
	if is_equal_approx(_book_hold, _book_hold_want) and _book_hold <= 0.0:
		return
	_book_hold = move_toward(_book_hold, _book_hold_want, BOOK_HOLD_RATE * dt)
	# Eased, so it lifts away and settles rather than sliding at one speed.
	var k := _book_hold * _book_hold * (3.0 - 2.0 * _book_hold)
	var held_local := _boat_pose.affine_inverse() * (_cam.transform * _book_rel)
	_book.transform = _book_rest.interpolate_with(held_local, k)
	if _book_hold <= 0.0 and not _reading:
		# Back on the sole before it shuts, so it is never seen closing in mid air.
		_book.transform = _book_rest
		_book.close()


## Open the book: the object opens and the camera comes down to read it.
func _open_book() -> void:
	if _book == null or _reading:
		return
	_reading = true
	_book.page = 0
	_refresh_book()
	_book.open()
	# THE RELATIVE POSE THAT ALREADY FRAMES IT, reused rather than re-derived.
	#
	# `frame_pose` computes where a camera must STAND to fit the whole spread at
	# this aspect - it is measured off the open mesh's own bounds and it is
	# already correct. So instead of moving the camera there, take the
	# camera-to-book relationship it implies and hang the book off the live
	# camera by it. The book arrives at exactly the size and angle the old dive
	# framed it at, and it cannot drift out of frame, because the framing is the
	# same arithmetic that used to place the camera.
	var pose := _book_pose()
	# THE PAGE'S UP, not the world's. `frame_pose` returns it as a third element
	# precisely because the book lies at an angle in the hull - it is put down,
	# not filed - and building the reference camera with `Vector3.UP` instead
	# bakes that 14 degrees of yaw in as a ROLL. Photographed: the held book came
	# up with the text running visibly downhill.
	var up: Vector3 = pose[2] if pose.size() > 2 else _boat_pose.basis.y
	var read_cam := Transform3D(Basis.IDENTITY, pose[0]).looking_at(pose[1], up)
	_book_rel = read_cam.affine_inverse() * (_boat_pose * _book_rest)
	# ...but only its ORIENTATION. `frame_pose` measures the open mesh's bounds,
	# and it is called here while the lid is still animating, so the distance it
	# implies depends on WHEN it was asked - measured, the same call gave 0.73 m
	# from a fresh boot and 1.29 m after the book had been opened a few times.
	# A held book is at a fixed, comfortable distance by definition, so the
	# distance is stated rather than derived, and only the angle that faces it at
	# the reader is kept.
	_book_rel = Transform3D(_book_rel.basis, BOOK_HELD_AT)
	_book_hold_want = 1.0
	if _audio != null:
		_audio.play("page", -3.0)


func _shut_book() -> void:
	if _book == null or not _reading:
		return
	_reading = false
	_book_hold_want = 0.0
	# The lid shuts only once the book is back down, so it is not seen closing in
	# mid air. `_sync_book_hold` calls `close()` when the hold reaches zero.
	if _audio != null:
		_audio.play("page", -6.0)


## PAGES ARE SWIPED, and this is the one place a drag survives in the game.
##
## Gideon: "you physically swipe the pages to read through it, rather than a
## scroll page." He asked for the swipe and the removal of drag-to-look in the same
## message, which sounds contradictory and is not: a drag means "turn the view"
## nowhere and "turn the page" here, so the gesture has exactly one meaning in
## each context and never two at once. That is only possible BECAUSE the stick
## took over looking.
##
## Right-to-left goes on, left-to-right goes back - the direction the paper
## physically moves under the thumb, not the direction of travel through the book.
## Getting that backwards is the single most common way this gesture is got wrong.
##
## A press that never travels is still a tap, and a tap off the page still shuts
## the book, because that is what a reader expects from a thing they picked up.
const PAGE_SWIPE := 46.0   ## px of travel before a press becomes a swipe


func _release_page(at: Vector2) -> void:
	if _book == null:
		return
	var moved := at - _page_from
	if absf(moved.x) >= PAGE_SWIPE and absf(moved.x) > absf(moved.y):
		if moved.x < 0.0:
			_turn_page(1)
		else:
			_turn_page(-1)
		return
	# Not a swipe. Treat it as the tap it was, at the point it started - using
	# the release point would mis-place a tap that drifted a few pixels.
	_tap_page(_page_from)


## One page, in either direction, with the sound and the shut at the end.
func _turn_page(by: int) -> void:
	var want := _book.page + by
	# THE BOOK NEVER PUTS ITSELF DOWN.
	#
	# Gideon: "you put it down instantly after running out of pages... when you run
	# iut of pages keep the book out. only exit when I hit the X button."
	#
	# It used to shut at the back cover, which is the same accidental-exit family
	# as the tap-outside that was removed last build - he has now asked three
	# times for the X to be the only way out, and this was the last place that was
	# not true. Running out of pages stops, and the arrow greys.
	if want < 0 or want >= _book_pages:
		return
	_book.page = want
	_refresh_book()
	_page_turn = 1.0 * signf(float(by))
	if _audio != null:
		_audio.play("page", -5.0)


## A tap while reading: the left third goes back, the right two thirds go on,
## and past the last page it shuts. That is how a person holds a book - you
## reach for the outside edge to turn forward - and it needs no buttons drawn
## over the page.
func _tap_page(at: Vector2) -> void:
	if _book == null:
		return
	var from := _cam.transform.origin
	var dir := _screen_ray(at)
	var on_page := _book.hit_page(from, dir, _boat_pose)
	if on_page.x < 0.0:
		# Tapped away from the page, and NOTHING HAPPENS.
		#
		# This used to shut the book, on the reasoning that everything outside a
		# thing you picked up is a way out. True of a real book and wrong here:
		# it is also how a brushed thumb loses your place, and it compounded with
		# the swipe - a swipe not quite horizontal enough falls back to a tap, so
		# trying to turn a page could close the book instead. The X in the room
		# bar is the only way out now.
		return
	var frac := on_page.x / float(BOOK_PAGE_PX.x)
	if frac < 0.34:
		_book.page = maxi(0, _book.page - 1)
	else:
		_book.page += 1
		if _book.page >= _book_pages:
			_shut_book()
			return
	_refresh_book()
	if _audio != null:
		_audio.play("page", -5.0)


## Where the camera reads the book from, framed off the page's real size and the
## camera's real field of view.
func _book_pose() -> Array:
	# Guarded: a camera that is not in a running tree has no viewport, and the
	# headless harness is exactly that case.
	var aspect := 0.46
	if _cam != null and is_inside_tree() and _cam.get_viewport() != null:
		var vs := _cam.get_viewport().get_visible_rect().size
		if vs.y > 1.0:
			aspect = vs.x / vs.y
	return _book.frame_pose(_boat_pose, _cam.fov if _cam != null else 58.0, aspect)


## A ray from the camera through a point on the screen.
func _screen_ray(at: Vector2) -> Vector3:
	if _cam == null or not is_inside_tree():
		# Straight ahead. Only the headless harness ever asks off-tree, and a
		# ray it cannot cast should miss the page rather than crash.
		return -_cam.transform.basis.z if _cam != null else Vector3.FORWARD
	return _cam.project_ray_normal(at)


# --- the stick and the sight ------------------------------------------------

## THE LOOK STICK, bottom-left, under the left thumb.
##
## Gideon: "can you add a small analog stick to the left side of the screen to
## control where you look instead of sliding on the screen to turn."
##
## The difference that matters is not the picture, it is that a stick HOLDS a
## direction. A drag reports movement, so to keep turning you have to keep
## dragging and then lift and do it again; a stick you simply lean on. It also
## frees the rest of the screen, which now only ever means "tap the water".
##
## Drawn rather than imported: a ring, a knob, and the knob follows the thumb.
func _build_stick() -> void:
	_stick = Control.new()
	_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stick.offset_left = 40
	_stick.offset_right = 40 + STICK_RADIUS * 2.4
	_stick.offset_top = -STICK_RADIUS * 2.4 - 120 - SAFE_BOTTOM
	_stick.offset_bottom = -120 - SAFE_BOTTOM
	_stick.mouse_filter = Control.MOUSE_FILTER_STOP
	_stick.name = "Stick"
	_stick.gui_input.connect(_stick_input)
	_stick.draw.connect(_draw_stick)
	_ui.add_child(_stick)


func _draw_stick() -> void:
	var mid := _stick.size * 0.5
	var r := STICK_RADIUS
	var lit := _stick_vec.length()
	# The well. Faint when idle - it is furniture, not an instrument, and the
	# water behind it is what the player is looking at - but never invisible:
	# at 30% alpha over pale varnished planks it disappeared completely, and a
	# control the player cannot find is a control they do not use.
	_stick.draw_circle(mid, r + 3.0, Color(0.02, 0.04, 0.05, 0.22 + 0.14 * lit))
	_stick.draw_circle(mid, r, Color(0.06, 0.10, 0.11, 0.34 + 0.20 * lit))
	_stick.draw_arc(mid, r, 0.0, TAU, 48, Color(0.05, 0.06, 0.05, 0.45), 5.0)
	_stick.draw_arc(mid, r, 0.0, TAU, 48,
		Color(0.95, 0.92, 0.84, 0.44 + 0.34 * lit), 2.5)

	# A cross of hairlines, so the well reads as a stick at rest rather than as
	# a smudge, and so the knob has a centre to return to.
	for i in 4:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 4.0)
		_stick.draw_line(mid + d * (r * 0.20), mid + d * (r * 0.34),
			Color(0.95, 0.92, 0.84, 0.24), 2.0)

	# The knob, where the thumb has pushed it.
	var knob := mid + _stick_vec * r * 0.72
	_stick.draw_circle(knob, r * 0.40, Color(0.03, 0.05, 0.05, 0.42))
	_stick.draw_circle(knob, r * 0.36, Color(0.13, 0.18, 0.19, 0.80))
	_stick.draw_arc(knob, r * 0.36, 0.0, TAU, 36,
		Color(0.96, 0.93, 0.86, 0.58 + 0.36 * lit), 3.0)


## THE SIGHT. A dot in the middle, so the player can tell what they are pointed
## at - which in a first-person game with no cursor is otherwise guesswork, and
## was reported as "very difficult to see where you are looking".
##
## It grows and warms when something in the boat is under it, which is the same
## information the Use button carries but available BEFORE the eye travels to
## the corner to look for it.
func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.name = "Sight"
	_crosshair.draw.connect(_draw_crosshair)
	_ui.add_child(_crosshair)


func _draw_crosshair() -> void:
	var mid := _crosshair.size * 0.5
	var on := _looking_at != ""
	var r := 16.0 if not on else 24.0
	var col := Color(0.96, 0.95, 0.90, 0.78) if not on else Color(1.0, 0.84, 0.46, 0.98)
	# A ring rather than a filled dot: a solid dot sits ON the thing being
	# looked at and hides it, and the thing being looked at is the point.
	# The dark ring under the light one is what makes it survive sun glitter.
	_crosshair.draw_arc(mid, r, 0.0, TAU, 32, Color(0, 0, 0, 0.45), 7.0)
	_crosshair.draw_arc(mid, r, 0.0, TAU, 32, col, 3.0)
	# Four ticks outside it, which is what tells the eye this is an aim and not
	# a stain on the screen. They open up when something is under the sight.
	var reach := r + (9.0 if not on else 15.0)
	for i in 4:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / 4.0)
		_crosshair.draw_line(mid + d * (r + 4.0), mid + d * reach,
			Color(0, 0, 0, 0.40), 6.0)
		_crosshair.draw_line(mid + d * (r + 4.0), mid + d * reach, col, 2.5)
	_crosshair.draw_circle(mid, 3.0, Color(0, 0, 0, 0.5))
	_crosshair.draw_circle(mid, 2.0, col)


## The charge, as an arc filling round the cast button.
func _draw_charge_ring() -> void:
	if sim.state != Sim.CHARGING:
		return
	var mid := _charge_ring.size * 0.5
	var r := _charge_ring.size.x * 0.5 - 5.0
	var k := clampf(sim.charge, 0.0, 1.0)
	# Starts at the top and fills clockwise, which is the direction every dial
	# anybody has ever used fills in.
	_charge_ring.draw_arc(mid, r, -PI * 0.5, -PI * 0.5 + TAU * k, 48,
		Color(1.0, 0.86, 0.52, 0.95), 6.0)
	# And the distance, in the middle, because the charge IS a distance.
	var font := ThemeDB.fallback_font
	var text := "%.0f m" % Tuning.cast_distance(sim.charge)
	# Centred on the button under the word, at a size that can be read while the
	# thumb is on it. 30 pt on a 260 px ring was a caption on a dinner plate.
	_charge_ring.draw_string(font,
		Vector2(0.0, mid.y + _charge_ring.size.y * 0.26), text,
		HORIZONTAL_ALIGNMENT_CENTER, int(_charge_ring.size.x), 46,
		Color(1.0, 0.93, 0.74, 0.95))



# --- the tackle box -------------------------------------------------------

## THE EQUIPMENT MENU IS A TACKLE BOX YOU OPEN.
##
## Gideon: "Can you also make your equipment menu a tackle box that you look at
## and click to view. This should open the tackle box and show all of your
## current equitable equipment."
##
## Third time he has asked for this shape - the logbook, this, and the shed - so
## it is written in PLAN.md 9.4 as a rule rather than answered three times: a
## screen the player opens is an object in the boat, or a place the boat takes
## them. There are no panels.
##
## What it buys beyond looking better: a panel has to be TOLD what it contains,
## and an object simply is what it contains. Line is the story's only ladder, and
## in a list it is a row reading "40 lb braid". In a box it is a spool sitting
## next to the four you have outgrown, with an empty slot where the one you
## cannot afford yet would go - the progression becomes a picture of itself.
##
## Unlike the logbook, the box is NOT picked up. A book is held and a toolbox on
## the sole is leaned over, so here the camera comes down to it. That is safe for
## the reason the book's version was not: the box does not move, so there is no
## chance of the pair chasing each other (see `_sync_play_camera`).
## 1024x512 matches the surface's own 0.360 x 0.180 aspect exactly, so the print
## is not squashed - and the TYPE is then sized to fit inside it. The first pass
## overflowed by one row and clipped "Reel" off the bottom silently, which is the
## failure mode of a SubViewport: it does not scroll, it does not warn, it just
## ends. Count the rows against the height before choosing a font size.
const BOX_PAGE_PX := Vector2i(1024, 512)
const BOX_LID_DEGREES := -104.0   ## negative turns the lid AWAY from the reader


func _build_tacklebox() -> void:
	var model := _prop("toolbox")
	if model == null:
		push_warning("the toolbox model is missing - the tackle box will not open")
		return
	_tacklebox = Room3D.new()
	_tacklebox.name = "TackleBox"
	# On the sole, INBOARD, ahead of the seat and clear of the logbook. Sized and
	# placed off the model's own bounds (scripts/probe_prop.gd): the body is
	# 40 x 12 x 22 cm, a real toolbox, and it needs no scaling.
	#
	# x = 0.15 rather than 0.34, and that number is the whole of a bug worth
	# recording. `frame_pose` puts the camera on the surface's normal, straight
	# up, so a box against the hull side puts the CAMERA above the gunwale - and
	# the photograph came back as a wall of planking with the panel split down the
	# middle by a rail. The hull is only 0.337 m half-wide at z = 1.62 (M), so a
	# 0.40 m box at x = 0.34 was inside the boat's side. Check `_hull_half_width`
	# at the station before placing anything against the beam.
	_tacklebox.position = Vector3(0.14, _hull_floor_y(1.52) + 0.035, 1.52)
	_tacklebox.rotation_degrees = Vector3(0, -24, 0)
	_boat.add_child(_tacklebox)

	# The printed surface lies in the open box, facing up, the same way the page
	# lies on the book - and for the same reason: the camera reads it from above,
	# and a surface standing up inside the lid faces the wrong way at that angle.
	var lie_flat := Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	_tacklebox.build(model, Vector2(0.360, 0.180),
		# ABOVE THE TRAY, not in it. The model's lift-out tray sits at y = 0.152 and
		# is 0.087 tall (M, scripts/probe_prop.gd), so a surface at 0.150 is
		# coplanar with it - photographed, the tray's centre divider ran straight
		# across the panel and hid a whole heading. 0.205 clears its top face.
		Transform3D(lie_flat, Vector3(0.0, 0.205, 0.0)),
		_box_root(), BOX_PAGE_PX)

	# The lid turns about its BACK EDGE. The mesh spans z from -0.106 to +0.111
	# about its own origin, so the hinge line is at z = -0.106; turning it about
	# the origin instead swings the lid down through the box.
	# NO PRINTED SURFACE. The things in the trays are the contents.
	_tacklebox.show_surface = false
	_build_box_items()
	_box_lamp = OmniLight3D.new()
	_box_lamp.name = "BoxLamp"
	_box_lamp.light_color = Color(1.0, 0.93, 0.80)
	_box_lamp.light_energy = 2.4
	_box_lamp.omni_range = 0.42
	_box_lamp.shadow_enabled = false
	_tacklebox.add_child(_box_lamp)
	var lid := _tacklebox.find_part("lid")
	if lid != null:
		_tacklebox.set_hinge(lid, Vector3(0.0, 0.0, -0.106), Vector3.RIGHT, BOX_LID_DEGREES)
	_refresh_tacklebox()


## The Control tree printed on the inside of the box. Same trick as the page: the
## layout is ordinary Controls rendered to a SubViewport and used as a texture,
## so none of the layout work has to be redone in world space.
func _box_root() -> Control:
	var root := ColorRect.new()
	root.color = Color(0.128, 0.132, 0.138)
	root.size = Vector2(BOX_PAGE_PX)
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 30)
	root.add_child(pad)
	_box_list = VBoxContainer.new()
	_box_list.add_theme_constant_override("separation", 8)
	pad.add_child(_box_list)
	return root


## What is in the box, right now. Rebuilt on every open and every change, from
## `sim` - so it cannot describe gear the player does not have.
## WHAT THE BOX SAYS ABOUT THE THING YOU HAVE SELECTED.
##
## The printed list that used to live on a quad inside the lid is gone - it was a
## panel wearing an object's clothes, and Gideon said so. The objects are the rows
## now, and the only words left are the name, the one line of description, and the
## pips. Those live on the HUD rather than on the surface, for a reason he gave
## directly: "since the text is small". Text printed on a quad at an angle 70 cm
## away is the smallest text in the game; the same words on the HUD are the
## largest, and the research puts the description on the screen after the
## selection settles anyway.
func _refresh_tacklebox() -> void:
	if _box_name == null:
		return
	var slot := _box_slot(_box_sel)
	_box_name.text = "%s   -   %s" % [str(slot["name"]), str(slot["what"])]
	_box_note.text = str(slot["note"])
	_box_pips.queue_redraw()
	if _box_left != null:
		# HIS MECHANISM, kept exactly: yellow when there is another version to move
		# to, grey when this is all you own. It says "you have one rod" without a
		# sentence, and it is the only way the empty rungs of a ladder are visible
		# from inside the boat.
		var many: bool = int(slot["variants"]) > 1
		var live := Color(0.99, 0.84, 0.42)
		var dead := Color(0.42, 0.41, 0.39)
		_box_left.add_theme_color_override("font_color", live if many else dead)
		_box_right.add_theme_color_override("font_color", live if many else dead)


func _box_heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.62, 0.60, 0.55))
	_box_list.add_child(l)


## One row, and its hit rectangle recorded in PAGE pixels so a tap on the
## physical surface can be turned back into the thing it landed on.
func _box_row(name: String, state: String, id: String, tappable: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var left := Label.new()
	left.text = name
	left.add_theme_font_size_override("font_size", 34)
	# SAY THE STATE MORE THAN ONE WAY. Colour alone fails a colour-blind player
	# and fails again on a dim phone in daylight, so the chosen bait carries the
	# words "on the hook" as well as the brighter ink.
	left.add_theme_color_override("font_color",
		Color(0.94, 0.92, 0.86) if (tappable or state == "on the hook") else Color(0.52, 0.50, 0.47))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := Label.new()
	right.text = state
	right.add_theme_font_size_override("font_size", 28)
	right.add_theme_color_override("font_color",
		Color(0.78, 0.68, 0.42) if state == "on the hook" else Color(0.55, 0.53, 0.50))
	row.add_child(right)
	_box_list.add_child(row)
	if tappable and id != "":
		_box_rows.append({"id": id, "row": row})
		# THE ARROWS NEED SOMETHING TO POINT AT. A caret rather than a colour
		# alone, for the same reason the state is said three ways: it survives a
		# colour-blind player and a dim phone in daylight.
		if _box_rows.size() - 1 == _box_sel:
			left.text = "> " + name
			left.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))


## Where the camera sits to read the open box. Computed by `frame_pose` off the
## surface's own size, not typed - the same arithmetic that frames the logbook,
## and the reason a hand-tuned offset is wrong three times running.
func _box_pose() -> Array:
	var aspect := 0.46
	if _cam != null and is_inside_tree() and _cam.get_viewport() != null:
		var vs := _cam.get_viewport().get_visible_rect().size
		if vs.y > 1.0:
			aspect = vs.x / vs.y
	return _tacklebox.frame_pose(_boat_pose, _cam.fov if _cam != null else 58.0, aspect)


func _open_tacklebox() -> void:
	if _tacklebox == null or _at_box:
		return
	_at_box = true
	_refresh_tacklebox()
	_tacklebox.open()
	if _audio != null:
		_audio.play("clunk", -4.0)


func _shut_tacklebox() -> void:
	if _tacklebox == null or not _at_box:
		return
	_at_box = false
	_tacklebox.close()
	_play_sequence([
		{"at": _cam.transform.origin, "look": _cam.transform.origin - _cam.transform.basis.z * 3.0,
			"for": 0.40, "gate": _gate_open, "ease": "inout"},
		{"at": Sequence.SEAT, "look": Sequence.SEAT_LOOK, "for": 0.35, "gate": _gate_open, "ease": "out"},
	])
	if _audio != null:
		_audio.play("clunk", -8.0)


## A tap on the open box: work out which row it landed on, and equip it.
##
## The hit test goes through `Room3D.hit_page`, which returns the point in PAGE
## PIXELS - so the row rectangles recorded during layout can be compared against
## it directly. That is the whole reason the surface is a SubViewport of ordinary
## Controls: the layout already knows where everything is, and none of it has to
## be re-solved in world space.
func _tap_box(at: Vector2) -> void:
	if _tacklebox == null:
		return
	var from := _cam.transform.origin
	var dir := _screen_ray(at)
	var on := _tacklebox.hit_page(from, dir, _boat_pose)
	if on.x < 0.0:
		# Tapped off the box, and nothing happens - see the note in `_tap_page`.
		# The X closes it.
		return
	for entry in _box_rows:
		var row: Control = entry["row"]
		var r := row.get_global_rect()
		if r.has_point(on):
			_set_bait(str(entry["id"]))
			_refresh_tacklebox()
			if _audio != null:
				_audio.play("clunk", -10.0)
			return


## Put a bait on the hook, from the box. The shed is still where bait is BOUGHT -
## this is the thing an angler does twenty times an hour, and it is why the tray
## is the tappable part of the box and the rod's gear above it is only shown.
func _set_bait(id: String) -> void:
	if not sim.econ.has_bait(id) or str(sim.econ.bait) == id:
		return
	sim.econ.bait = id
	_say_hint("%s on the hook." % str(Gear.bait_by_id(id)["name"]))
	_want_save()


# --- the room bar ---------------------------------------------------------

## CONTROLS FOR A ROOM THAT IS AN OBJECT, which a panel used to provide free.
##
## Gideon, after playing the rooms on the phone: "instead of clicking outside the
## menu to close it, i want an X or back button to prevent accidentally closing
## out of the menue. since the text is small I want arrow keys and confirm button
## to navigate the menues."
##
## Both are the same debt. Making a menu physical bought a lot and quietly gave
## up three things a panel had always done: it never intersected the world, it
## always had a close button, and it could be driven without aiming. The first is
## fixed in `Room3D` (the surface no longer depth-tests). These are the other two.
##
## Why it is worth doing properly rather than adding one X. Tap-to-dismiss was
## written down here as "what a reader expects from a thing they picked up", and
## that is true and was still wrong: it is also how you lose your place by
## brushing the screen. Worse, it interacts with the swipe - a swipe that is not
## quite horizontal enough falls back to being a tap, and a tap off the page shut
## the book. So "I cant swipe the pages" and "it closes accidentally" were one
## fault with two faces, and an explicit bar settles both: the ONLY thing that
## closes a room now is the X.
##
## The arrows also answer something a 3D menu has that a panel does not: the text
## lives on a surface at an angle, so it is smaller than a panel's and hitting a
## row means aiming at a plane. Arrows make every row reachable without aiming at
## anything, which is an accessibility floor rather than a convenience.
const ROOMBAR_H := 132.0
const ROOMBAR_GAP := 18.0


func _build_room_bar() -> void:
	_room_bar = HBoxContainer.new()
	_room_bar.name = "RoomBar"
	_room_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_room_bar.offset_left = 46
	_room_bar.offset_right = -46
	_room_bar.offset_top = -ROOMBAR_H - 54 - SAFE_BOTTOM
	_room_bar.offset_bottom = -54 - SAFE_BOTTOM
	_room_bar.add_theme_constant_override("separation", int(ROOMBAR_GAP))
	_room_bar.visible = false
	_ui.add_child(_room_bar)

	_room_prev = _room_button("<", func() -> void: _room_step(-1))
	_room_next = _room_button(">", func() -> void: _room_step(1))
	_room_ok = _room_button("Use", func() -> void: _room_confirm())
	_room_close = _room_button("X", func() -> void: _room_close_pressed())
	for b in [_room_prev, _room_ok, _room_next, _room_close]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_room_bar.add_child(b)
	# The X is the way out, so it is the one that must never be pressed by
	# accident on the way to something else: last, hard against the right edge,
	# and coloured apart from the three that act on the contents.
	_room_close.size_flags_stretch_ratio = 0.7


func _room_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROOMBAR_H)
	b.add_theme_font_size_override("font_size", 44)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.09, 0.10, 0.88)
	box.border_color = Color(0.93, 0.90, 0.82, 0.34)
	box.set_border_width_all(2)
	box.set_corner_radius_all(22)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var press := box.duplicate() as StyleBoxFlat
	press.bg_color = Color(0.17, 0.25, 0.26, 0.96)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	b.pressed.connect(on_press)
	return b


## Step through whatever the open room is: pages in the book, rows in the box.
func _room_step(by: int) -> void:
	if _reading:
		_turn_page(by)
	elif _at_box:
		_box_move(by)


func _room_confirm() -> void:
	if _reading:
		# A book has nothing to confirm, so the middle button turns the page on -
		# which is what a reader pressing the big button in the middle means.
		_turn_page(1)
	elif _at_box:
		# The middle button steps to the next VERSION of the selected thing, which
		# for bait is the choice and for everything else is a no-op the greyed
		# arrows have already said is unavailable.
		_box_variant(1)


func _room_close_pressed() -> void:
	if _reading:
		_shut_book()
	elif _at_box:
		_shut_tacklebox()


## Show the bar only while a room is open, and label the middle button for the
## room that is open - a caption computed from the state rather than stored, the
## same rule the action button follows.
func _sync_room_bar() -> void:
	if _room_bar == null:
		return
	var open := (_reading or _at_box) and not _in_sequence
	_room_bar.visible = open
	if not open:
		return
	if _reading:
		_room_ok.text = "Turn"
		_room_prev.text = "<"
		_room_next.text = ">"
		# DIM, NEVER HIDE, at both covers - so the end of the book reads as the
		# end rather than as a control that stopped working.
		var page: int = _book.page if _book != null else 0
		_room_prev.disabled = page <= 0
		_room_next.disabled = page >= _book_pages - 1
		_room_ok.disabled = _room_next.disabled
		for b in [_room_prev, _room_next, _room_ok]:
			b.add_theme_color_override("font_color",
				Color(0.44, 0.42, 0.39) if b.disabled else Color(0.93, 0.90, 0.82))
	else:
		_room_ok.text = "Swap"
		_room_prev.text = "^"
		_room_next.text = "v"
		var nothing := int(_box_slot(_box_sel)["variants"]) <= 1
		# Up and down always work - there is always another thing in the box.
		# Only the middle button, which swaps the VERSION, can be dead.
		_room_prev.disabled = false
		_room_next.disabled = false
		_room_ok.disabled = nothing
		for b in [_room_prev, _room_next, _room_ok]:
			b.add_theme_color_override("font_color",
				Color(0.44, 0.42, 0.39) if b.disabled else Color(0.93, 0.90, 0.82))


# --- where a thing actually IS ---------------------------------------------

## THE AIM POINT OF EVERY INTERACTABLE, COMPUTED FROM ITS GEOMETRY.
##
## Gideon: "when I look at the book I cant click it but I can click it if I look
## forward on the boat." Two screenshots proved it: in one the crosshair sits on
## bare floorboards and the prompt reads "The keeper's logbook"; in the next the
## book is plainly under the crosshair and there is no prompt at all.
##
## The cause is that each `_things` entry carried a hand-typed `at`, and an
## imported model's ORIGIN is wherever the exporter left it rather than where the
## shape is. Measured with `scripts/probe_anchor.gd`: the logbook's anchor was
## 0.14 m from its own mesh, 0.13 m of it sideways. The aim cone is 0.985 of a dot
## product, about ten degrees, and at that range 0.14 m IS nine degrees - so the
## book was just outside its own hit box while the empty floor beside it was
## inside. The livewell was out by 0.10 m and the tackle box by 0.11 m; nobody had
## noticed because both are large enough to be found anyway.
##
## So the typed number is gone and the aim point is derived from the visible
## bounds once, at build time. One source of truth: the thing you can see and the
## thing you can aim at are the same object, and moving a prop moves its hit box
## for free. `run_smoke.gd` asserts the two agree.
## How far off centre a thing may be and still count as looked at, as a dot
## product. Two values, because angular size grows as you approach: a bucket at
## 70 cm subtends far more than a fixed ten-degree cone, so one constant made the
## NEAREST objects the hardest to select.
const AIM_COS := 0.985       ## about 10 degrees, at arm's length and beyond
const AIM_COS_NEAR := 0.93   ## about 21 degrees, for something right under you

const AIM_NODE := {
	"livewell": "Prop_livewell",
	"baitbox": "Prop_baitbox",
	"lamp": "Prop_lamp",
	"logbook": "Logbook",
	"tacklebox": "TackleBox",
	"rope": "Rope",
}


func _build_aim_points() -> void:
	_aim_points.clear()
	for id in AIM_NODE:
		var n := _boat.get_node_or_null(NodePath(str(AIM_NODE[id]))) as Node3D
		if n == null:
			continue
		var c := _visual_centre(n)
		if c != Vector3.INF:
			_aim_points[id] = c


## Where a thing is aimed at: its measured centre if it has one, and the typed
## `at` only as a fallback for something with no geometry yet.
func aim_point_of(t: Dictionary) -> Vector3:
	var id := str(t.get("id", ""))
	if _aim_points.has(id):
		return _aim_points[id]
	return t["at"]


## The centre of everything a node actually DRAWS, in boat space. The mesh AABB
## rather than the node's origin, which is the whole point.
func _visual_centre(n: Node3D) -> Vector3:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var stack: Array = [n]
	while not stack.is_empty():
		var node = stack.pop_back()
		var mi := node as MeshInstance3D
		if mi != null and mi.mesh != null and mi.visible:
			var aabb := mi.mesh.get_aabb()
			var x := _relative_to(mi, n)
			for i in 8:
				var corner := aabb.position + Vector3(
					aabb.size.x * float(i & 1),
					aabb.size.y * float((i >> 1) & 1),
					aabb.size.z * float((i >> 2) & 1))
				var p := x * corner
				lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
				hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		for c in node.get_children():
			stack.append(c)
	if lo.x == INF:
		return Vector3.INF
	# The middle of the box, then lifted to the upper third: a thing lying on the
	# sole is aimed at where a person would look at it, which is its top face
	# rather than its buried centre.
	var mid := (lo + hi) * 0.5
	mid.y = lerpf(mid.y, hi.y, 0.5)
	return n.transform * mid


## A node's transform relative to an ancestor, for turning a mesh's own AABB into
## the space the ancestor lives in.
func _relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur is Node3D and cur != ancestor:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# --- what the moment wants -------------------------------------------------

## IS THE CROSSHAIR OVER THE WATER, OR OVER THE BOAT?
##
## Gideon: "I also want the cast button to only pop up when the cursor is above
## the boat. if you are looking in the boat, change it to a select button."
##
## Cast is currently offered while the player is looking at the floorboards, which
## is an instruction the game cannot honour - the cast would go into the bottom of
## the boat. The button should say what the moment wants, which is the rule the
## CAPTION already follows; this extends it to the button's whole identity.
##
## Answered by intersecting the look ray with the waterline and asking whether it
## lands inside the hull's own footprint, so it follows the boat's real shape
## rather than a guessed angle. A ray that never reaches the water at all - level
## or climbing - is looking at the horizon, which is water.
const BOUNDARY_FRAMES := 4   ## how long a side must hold before the button changes


func _aim_is_over_water() -> bool:
	if _cam == null:
		return true
	var origin := _cam.transform.origin
	var dir := -_cam.transform.basis.z.normalized()
	if dir.y >= -0.0001:
		return true
	var t := -origin.y / dir.y
	if t <= 0.0:
		return true
	var hit := origin + dir * t
	# Inside the hull's plan view is the boat; anything past bow or stern, or
	# outside the beam at that station, is open water.
	if hit.z < -0.85 or hit.z > 2.25:
		return true
	return absf(hit.x) > _hull_half_width(hit.z)


## The primary button, debounced. Without the hysteresis a slow pan across the
## gunwale flickers Cast/Select at the edge, which is the researched failure of
## this pattern - and the thumb is usually already moving toward the button.
func _sync_primary_button() -> void:
	if _action == null:
		return
	var over_water := _aim_is_over_water()
	if over_water == _over_water_shown:
		_boundary_held = 0
	else:
		_boundary_held += 1
		if _boundary_held >= BOUNDARY_FRAMES:
			_over_water_shown = over_water
			_boundary_held = 0


# --- the tackle box is its contents ----------------------------------------

## REAL THINGS IN THE TRAYS, not a menu printed on the inside of a lid.
##
## Gideon: "It also just has a menu in it. instead can you make 3d objects for each
## option and make it look like they are physically in the box. For the rod, just
## show a mini version of the rod. for the line, show a small spool of line."
##
## He is right and the miss was mine: PLAN 9.4 said "an object IS what it contains"
## and I printed a list on a surface, which is a panel wearing an object's clothes.
##
## The layout follows the researched pattern rather than a grid. Everything really
## is lying in the box - they ARE physically in it, which is what he asked for -
## but the SELECTED one lifts toward the reader and lights while the rest dim.
## That is Resident Evil's case plus Half-Life: Alyx's highlight-before-commit: a
## grid of six small objects on a phone is a thing to scan, and one lit object is
## a thing to read.
##
## Two of the six are imported (`knife`, `pliers` - the only photoreal free tackle
## that exists anywhere). The rest are modelled here, and the spool is the reason
## that is a gain rather than a compromise: it takes its colour from the line
## strength, so the picture of the ladder cannot disagree with the economy.
const BOX_LIFT := 0.075        ## how far the selected item rises out of the tray
## How far the unselected things recede. 0.78 rather than the 0.34 it started at:
## transparency makes a thing SEE-THROUGH rather than quiet, and at 0.34 the whole
## tray went murky and the box read as badly lit instead of as focused. The lift,
## the scale and the lamp below carry the highlight; this only pushes the rest back.
const BOX_DIM := 0.78


func _build_box_items() -> void:
	_box_items.clear()
	var tray := Vector3(0.0, 0.175, 0.0)
	# Two rows of three across the box's 40 x 22 cm, laid out so nothing overlaps
	# and the whole tray reads at the angle the camera comes down at.
	var spots := [
		Vector3(-0.125, 0.0, -0.045), Vector3(0.0, 0.0, -0.050), Vector3(0.125, 0.0, -0.045),
		Vector3(-0.125, 0.0, 0.050), Vector3(0.0, 0.0, 0.052), Vector3(0.125, 0.0, 0.050),
	]
	var made: Array[Node3D] = [
		_box_rod(), _box_reel(), _box_spool(),
		_box_tin(), _box_import("knife", 1.0, Vector3(0, 0, 90)), _box_import("pliers", 1.0, Vector3(90, 0, 0)),
	]
	for i in made.size():
		var n := made[i]
		if n == null:
			continue
		n.position = tray + spots[i]
		n.name = "BoxItem%d" % i
		_tacklebox.add_child(n)
		_box_items.append(n)


## The rod, broken down, lying across the tray. The SAME generator the live rod
## uses, at a shorter length - so its shading matches for free and there is no
## second model to keep in step. The scout's recommendation, and the one item where
## code was the better answer on its own merits rather than a fallback.
func _box_rod() -> Node3D:
	var root := Node3D.new()
	var blank := _mat(Color(0.115, 0.105, 0.100), 0.34)
	blank.metallic = 0.22
	var cork := _mat(Color(0.68, 0.55, 0.36), 0.92)
	for i in 2:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		# 8.5 cm a section: two of them plus the grip is 20 cm, which fits inside a
		# 40 cm box with room either side. At 11.5 cm the rod stuck out through the
		# end of the tray, which reads as a modelling mistake rather than as a rod.
		cm.height = 0.085
		cm.top_radius = lerpf(0.0055, 0.0022, float(i))
		cm.bottom_radius = lerpf(0.0080, 0.0055, float(i))
		cm.radial_segments = 8
		cm.rings = 1
		seg.mesh = cm
		seg.material_override = blank
		seg.rotation_degrees = Vector3(0, 0, 90)
		seg.position = Vector3(-0.044 + 0.088 * float(i), 0.0, 0.012 * float(i))
		root.add_child(seg)
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.height = 0.048
	gm.top_radius = 0.0105
	gm.bottom_radius = 0.0115
	gm.radial_segments = 10
	grip.mesh = gm
	grip.material_override = cork
	grip.rotation_degrees = Vector3(0, 0, 90)
	grip.position = Vector3(-0.072, 0.0, 0.0)
	root.add_child(grip)
	return root


## A closed-face reel: a drum, a cover and a handle.
func _box_reel() -> Node3D:
	var root := Node3D.new()
	var metal := _mat(Color(0.60, 0.61, 0.63), 0.28)
	metal.metallic = 0.85
	var dark := _mat(Color(0.16, 0.16, 0.17), 0.42)
	dark.metallic = 0.5
	var drum := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.height = 0.042
	dm.top_radius = 0.031
	dm.bottom_radius = 0.034
	dm.radial_segments = 14
	drum.mesh = dm
	drum.material_override = metal
	drum.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(drum)
	var foot := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.016, 0.030, 0.010)
	foot.mesh = fm
	foot.material_override = dark
	foot.position = Vector3(0.0, 0.030, 0.0)
	root.add_child(foot)
	var crank := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.044, 0.006, 0.006)
	crank.mesh = km
	crank.material_override = dark
	crank.position = Vector3(0.016, 0.0, 0.024)
	crank.rotation_degrees = Vector3(0, 0, 22)
	root.add_child(crank)
	return root


## A SPOOL OF LINE, and its colour is the line you actually have on.
##
## The whole argument for modelling these rather than importing them: the spool
## reads its shade from the rung of the ladder, so "what is on the reel" and "what
## the box shows" are one fact. A set of fixed meshes would be two.
func _box_spool() -> Node3D:
	var root := Node3D.new()
	var plastic := _mat(Color(0.22, 0.20, 0.18), 0.55)
	var line_col := _line_colour(sim.econ.line)
	var wound := _mat(line_col, 0.30)
	wound.metallic = 0.10
	for i in 2:
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.height = 0.004
		cm.top_radius = 0.030
		cm.bottom_radius = 0.030
		cm.radial_segments = 16
		disc.mesh = cm
		disc.material_override = plastic
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position = Vector3(0.0, 0.0, -0.013 + 0.026 * float(i))
		root.add_child(disc)
	var core := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.height = 0.024
	km.top_radius = 0.024
	km.bottom_radius = 0.024
	km.radial_segments = 16
	core.mesh = km
	core.material_override = wound
	core.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(core)
	return root


## Mono is pale and almost clear, braid is dark and flat, wire is grey. One place,
## so the spool in the box and the line on the reel cannot drift apart.
func _line_colour(level: int) -> Color:
	match clampi(level, 0, 5):
		0: return Color(0.86, 0.86, 0.82)
		1: return Color(0.80, 0.80, 0.74)
		2: return Color(0.26, 0.30, 0.26)
		3: return Color(0.18, 0.20, 0.20)
		4: return Color(0.52, 0.53, 0.55)
		_: return Color(0.38, 0.34, 0.30)


## The bait tin: a shallow box with the lid ajar.
func _box_tin() -> Node3D:
	var root := Node3D.new()
	var tin := _mat(Color(0.46, 0.44, 0.38), 0.46)
	tin.metallic = 0.62
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.070, 0.026, 0.050)
	body.mesh = bm
	body.material_override = tin
	root.add_child(body)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.070, 0.004, 0.050)
	lid.mesh = lm
	lid.material_override = tin
	lid.position = Vector3(0.0, 0.020, -0.022)
	lid.rotation_degrees = Vector3(-38, 0, 0)
	root.add_child(lid)
	return root


## One of the two imported items, scaled and laid down in the tray.
func _box_import(id: String, scale: float, rot: Vector3) -> Node3D:
	var n := _prop(id)
	if n == null:
		return null
	n.scale = Vector3.ONE * scale
	n.rotation_degrees = rot
	return n


## THE SLOTS, and what each one is. Order matches `_build_box_items`.
##
## `rungs` is how long that ladder is and `owned` is how far up it you are, which
## is what the PIP ROW draws: six pips for the line, two filled, and the next one
## visibly waiting. The research is clear that arrows alone are not enough - they
## say "you can move" and never "how far" or "where you are" - so the arrows are
## the input and the pips are the state.
##
## `variants` is how many versions of THIS thing the player can actually choose
## between right now. One for the rod, the reel and the line, because you own a
## rung rather than a collection; several for bait. That is exactly the mechanism
## Gideon described: "show yellow arrows to the left and right of the object if
## there are other versions I can select. if I dont have other versions yet, make
## the arrows grey, so it is obvious that this is my only option currently."
func _box_slot(i: int) -> Dictionary:
	match i:
		0:
			return {
				"name": "Rod",
				"what": str(Gear.ROD[sim.econ.rod]["name"]),
				"note": "Broken down in the tray. A wider band on the gauge than the last one.",
				"rungs": Gear.ROD.size(), "owned": sim.econ.rod + 1, "variants": 1, "pick": 0,
			}
		1:
			return {
				"name": "Reel",
				"what": str(Gear.REEL[sim.econ.reel]["name"]),
				"note": "Takes line back faster. It does not make the fish smaller.",
				"rungs": Gear.REEL.size(), "owned": sim.econ.reel + 1, "variants": 1, "pick": 0,
			}
		2:
			return {
				"name": "Line",
				"what": Gear.line_name(sim.econ.line),
				"note": "How deep you can reach. The only thing that decides it.",
				"rungs": Gear.LINE.size(), "owned": sim.econ.line + 1, "variants": 1, "pick": 0,
			}
		3:
			var owned := _owned_baits()
			return {
				"name": "Bait",
				"what": str(Gear.bait_by_id(sim.econ.bait)["name"]),
				"note": "On the hook. Different water wants different things.",
				"rungs": Gear.BAIT.size(), "owned": owned.size(),
				"variants": owned.size(), "pick": maxi(0, owned.find(str(sim.econ.bait))),
			}
		4:
			return {
				"name": "Knife", "what": "Bone handled",
				"note": "The keeper's. Older than the boat, by the look of it.",
				"rungs": 1, "owned": 1, "variants": 1, "pick": 0,
			}
		_:
			return {
				"name": "Pliers", "what": "For the hook",
				"note": "For getting a hook back out of something that swallowed it.",
				"rungs": 1, "owned": 1, "variants": 1, "pick": 0,
			}


func _owned_baits() -> Array[String]:
	var out: Array[String] = []
	for b in Gear.BAIT:
		if sim.econ.has_bait(str(b["id"])):
			out.append(str(b["id"]))
	return out


## Move between the things in the box. Up and down, as he asked.
func _box_move(by: int) -> void:
	if _box_items.is_empty():
		return
	_box_sel = wrapi(_box_sel + by, 0, _box_items.size())
	_refresh_tacklebox()
	if _audio != null:
		_audio.play("clunk", -14.0)


## Move between the VERSIONS of the selected thing. Left and right.
##
## Stops at the ends rather than wrapping: the research names silent wraparound as
## the way a player loses their sense of where they are in a set.
func _box_variant(by: int) -> void:
	var slot := _box_slot(_box_sel)
	if int(slot["variants"]) <= 1:
		return
	if str(slot["name"]) != "Bait":
		return
	var owned := _owned_baits()
	var i := clampi(int(slot["pick"]) + by, 0, owned.size() - 1)
	if owned[i] == str(sim.econ.bait):
		return
	_set_bait(owned[i])
	_refresh_tacklebox()
	if _audio != null:
		_audio.play("clunk", -10.0)


## Lift and light the selected thing; sit the rest back down and fade them.
func _sync_box_items() -> void:
	for i in _box_items.size():
		var n := _box_items[i]
		var chosen := i == _box_sel and _at_box
		var want := Vector3(n.position.x, 0.175 + (BOX_LIFT if chosen else 0.0), n.position.z)
		n.position = n.position.lerp(want, 0.25)
		n.scale = n.scale.lerp(Vector3.ONE * (1.10 if chosen else 1.0), 0.25)
		_tint_tree(n, 1.0 if chosen else BOX_DIM)
		if chosen and _box_lamp != null:
			# ONE OBJECT, LIT. The researched pattern is a single foregrounded and
			# lit item rather than a grid to scan, and inside a box in a boat at
			# dawn there is no light to do it with - so the box brings its own.
			_box_lamp.position = want + Vector3(0.0, 0.115, 0.0)


## Fade a whole subtree without touching the shared materials the rest of the boat
## uses - `instance_shader_parameters` would be cleaner, but a per-instance modulate
## on the MeshInstance is the one thing that works on an imported glTF hierarchy
## whose materials are shared between props.
func _tint_tree(n: Node, k: float) -> void:
	var mi := n as MeshInstance3D
	if mi != null:
		mi.transparency = clampf(1.0 - k, 0.0, 0.66)
	for c in n.get_children():
		_tint_tree(c, k)


## The words and the pips, on the HUD above the room bar.
func _build_box_hud() -> void:
	_box_name = Label.new()
	_box_name.name = "BoxName"
	_box_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box_name.offset_left = 46
	_box_name.offset_right = -46
	_box_name.offset_top = -ROOMBAR_H - 240 - SAFE_BOTTOM
	_box_name.offset_bottom = -ROOMBAR_H - 186 - SAFE_BOTTOM
	_box_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_name.add_theme_font_size_override("font_size", 40)
	_box_name.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	_box_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_box_name.add_theme_constant_override("outline_size", 8)
	_ui.add_child(_box_name)

	_box_note = Label.new()
	_box_note.name = "BoxNote"
	_box_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box_note.offset_left = 60
	_box_note.offset_right = -60
	_box_note.offset_top = -ROOMBAR_H - 182 - SAFE_BOTTOM
	_box_note.offset_bottom = -ROOMBAR_H - 118 - SAFE_BOTTOM
	_box_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box_note.add_theme_font_size_override("font_size", 28)
	_box_note.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	_box_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_box_note.add_theme_constant_override("outline_size", 7)
	_ui.add_child(_box_note)

	# THE PIP ROW. Arrows are the input; pips are the state. One per rung of that
	# ladder, filled for what is owned and outline for what is not, so the line
	# ladder - the only progression in the game - is a picture of itself with the
	# next rung visibly waiting.
	_box_pips = Control.new()
	_box_pips.name = "BoxPips"
	_box_pips.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box_pips.offset_left = 46
	_box_pips.offset_right = -46
	_box_pips.offset_top = -ROOMBAR_H - 112 - SAFE_BOTTOM
	_box_pips.offset_bottom = -ROOMBAR_H - 68 - SAFE_BOTTOM
	_box_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_pips.draw.connect(_draw_box_pips)
	_ui.add_child(_box_pips)

	# The two arrows, either side of the object, as he described them.
	_box_left = _arrow_button("<", func() -> void: _box_variant(-1))
	_box_right = _arrow_button(">", func() -> void: _box_variant(1))
	_box_left.offset_left = 40
	_box_left.offset_right = 140
	_box_right.offset_left = -140
	_box_right.offset_right = -40
	_box_left.set_anchors_preset(Control.PRESET_CENTER_LEFT, true)
	_box_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT, true)
	_ui.add_child(_box_left)
	_ui.add_child(_box_right)


## The arrows are PRESSED, not just shown. He described them as an indicator -
## "show yellow arrows to the left and right of the object if there are other
## versions I can select" - and the thing a player does next with an arrow beside
## an object is tap it, so it had better be a button.
func _arrow_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.add_theme_font_size_override("font_size", 76)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", 9)
	b.pressed.connect(on_press)
	return b


func _draw_box_pips() -> void:
	var slot := _box_slot(_box_sel)
	var rungs: int = maxi(1, int(slot["rungs"]))
	var owned: int = clampi(int(slot["owned"]), 0, rungs)
	if rungs <= 1:
		return
	var w := _box_pips.size.x
	var y := _box_pips.size.y * 0.5
	var gap := minf(46.0, w / float(rungs + 1))
	var start := (w - gap * float(rungs - 1)) * 0.5
	for i in rungs:
		var at := Vector2(start + gap * float(i), y)
		if i < owned:
			_box_pips.draw_circle(at, 9.0, Color(0.95, 0.86, 0.58))
		else:
			# Outline only: the rung exists and you have not reached it. An absent
			# pip would say the ladder is shorter than it is.
			_box_pips.draw_arc(at, 9.0, 0.0, TAU, 18, Color(0.62, 0.60, 0.56, 0.85), 2.5)


func _sync_box_hud() -> void:
	if _box_name == null:
		return
	var on := _at_box and not _in_sequence
	for c in [_box_name, _box_note, _box_pips, _box_left, _box_right]:
		c.visible = on
