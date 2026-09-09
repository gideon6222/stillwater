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
var _sky_mat: ProceduralSkyMaterial
var _reeds: Node3D
var _save_due := 0.0

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
	m.set_shader_parameter("gloss", 1.0)
	m.set_shader_parameter("beam", 1.0)
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

	_sky_mat.sky_top_color = _sky_mat.sky_top_color.lerp(look["sky_top"], k)
	_sky_mat.sky_horizon_color = _sky_mat.sky_horizon_color.lerp(look["sky_horizon"], k)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sky_mat.ground_bottom_color = _sky_mat.ground_bottom_color.lerp(look["water_deep"], k)

	_env.fog_light_color = _env.fog_light_color.lerp(look["fog_color"], k)
	_env.fog_density = lerpf(_env.fog_density, float(look["fog_density"]), k)

	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(look["sun_color"], k)
		_sun.light_energy = lerpf(_sun.light_energy, float(look["sun_energy"]), k)
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
