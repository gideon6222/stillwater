class_name Sim
extends RefCounted

## The whole game, with no renderer in it.
##
## `Sim` owns every number that decides what happens; the scene in `src/game/`
## reads those numbers and draws them, and never the other way round. Two things
## fall out of that, and both are worth more than they cost:
##
## 1. `test/` can play a whole session in milliseconds with no window, no GPU and
##    no scene tree - so a golden test over an entire run is possible, which is a
##    far stronger safety net than testing any single function.
## 2. Rendering can be rewritten, or replaced entirely, without touching a line
##    of game logic.
##
## The rule that keeps it true: **nothing in this file may reference a Node, a
## Viewport, an input event or a delta that came from a real frame.** If it needs
## to know something about the world, it takes it as an argument.
##
## The second rule, specific to this game: **the line is arithmetic, never a
## physics body.** Wrecking Crew earned that one with a wrecking ball on a
## PinJoint3D - the moment the outcome of a fight lives inside the physics
## server it is at the mercy of the tick rate and the solver, and a whole-run
## golden becomes impossible. Rigid bodies are for things that decide nothing:
## the float bobbing, the boat's roll, spray.

signal cast_landed(distance: float)
signal nibble()
signal bite(species_id: String)
signal hooked(species_id: String)
signal landed(species_id: String, weight: float)
signal lost(reason: String)

## The states a line can be in. Named rather than numbered because they appear
## in the golden, where an integer would make a reordering silently pass.
const IDLE := "idle"              ## in the boat, nothing cast
const CHARGING := "charging"      ## holding, the rod loading
const FLYING := "flying"          ## in the air
const SINKING := "sinking"        ## on the water, going down
const WAITING := "waiting"        ## at depth, fishing
const NIBBLING := "nibbling"      ## taps on the rod tip, the warning
const BITING := "biting"          ## the window is open
const FIGHTING := "fighting"      ## on, and being fought
const HOLDING := "holding"        ## landed, held up, being looked at
const LOST := "lost"              ## it came off

## Why the last fish was lost. Reported to the player in those words, because
## "the line broke" and "it threw the hook" are different mistakes and a player
## who cannot tell them apart cannot correct either.
const BROKE := "the line broke"
const SLIPPED := "it threw the hook"
const MISSED := "you were too slow"

var state: String = IDLE
var time: float = 0.0             ## seconds since the session started
var state_time: float = 0.0       ## seconds in the current state

# --- the cast -------------------------------------------------------------
var charge: float = 0.0           ## [0, 1] while CHARGING
var cast_distance: float = 0.0    ## metres out, once cast
var lure_depth: float = 0.0       ## metres down
var spook_timer: float = 0.0      ## fish put off by a wrong strike

# --- the fish -------------------------------------------------------------
## What the fish is doing. The player has to read this off the WATER - the float
## shearing away, the line going flat, the fish breaking the surface - and there
## is deliberately no HUD element that names it.
const B_HOLDING := "holding"       ## sullen. Pump it in
const B_RUNNING := "running"       ## bolting. Give line or lose the lot
const B_SURFACING := "surfacing"   ## head-shaking on top. Hold steady

var fish_id: String = ""
var fish_weight: float = 0.0
var fish_distance: float = 0.0    ## metres from the boat
var fish_stamina: float = 1.0     ## [0, 1], falls as it tires
var fight_time: float = 0.0       ## seconds this fish has been on

var behaviour: String = B_HOLDING
var behaviour_time: float = 0.0   ## seconds left in the current behaviour
var behaviour_elapsed: float = 0.0 ## seconds since it started, for the run surge
var next_behaviour: String = ""   ## what the tell is warning about
var tell: float = 0.0             ## seconds of warning left, 0 when not telling

# --- the line -------------------------------------------------------------
var pull: float = 0.0             ## the thumb, [0, 1]
var load: float = 0.0             ## the rod's actual bend, chasing the thumb
var strain: float = 0.0           ## [0, 1] toward a snapped line
var slip: float = 0.0             ## [0, 1] toward a thrown hook
var wear: float = 0.0             ## [0, 1] the hook working loose, all fight long

## Pump tracking. A pump is a lift over PUMP_HIGH then a drop under PUMP_LOW, and
## the line is gained on the DOWN stroke - so a steady lift, which is what beat
## the first version of this fight, gains exactly nothing.
var _pump_armed := false
var _pump_peak := 0.0
var pumps: int = 0                ## completed this fight, for the probe and HUD

# --- the session ----------------------------------------------------------
var caught: int = 0
var lost_count: int = 0
var total_weight: float = 0.0
var casts: int = 0

## Anything that decides *when* something happens is simulation, however
## decorative it looks - so bite timing and which species takes it both come
## off a seeded stream rather than randf(). Leaving that on randf() made the
## golden on a sibling game fail about one run in ten.
var _rng: SimRng


func _init(seed_value: int = 1) -> void:
	restart(seed_value)


## Full reset. Called at boot; the test harness calls it to get a clean,
## identical starting state on any machine.
func restart(seed_value: int = 1) -> void:
	state = IDLE
	time = 0.0
	state_time = 0.0
	charge = 0.0
	cast_distance = 0.0
	lure_depth = 0.0
	spook_timer = 0.0
	fish_id = ""
	fish_weight = 0.0
	fish_distance = 0.0
	fish_stamina = 1.0
	fight_time = 0.0
	behaviour = B_HOLDING
	behaviour_time = 0.0
	behaviour_elapsed = 0.0
	next_behaviour = ""
	tell = 0.0
	pull = 0.0
	load = 0.0
	strain = 0.0
	slip = 0.0
	wear = 0.0
	_pump_armed = false
	_pump_peak = 0.0
	pumps = 0
	caught = 0
	lost_count = 0
	total_weight = 0.0
	casts = 0
	_rng = SimRng.new(seed_value)


# --- input, which is the only seam a thumb uses ---------------------------

## Begin loading the rod. Ignored unless the line is in the boat, so a stray
## touch during a fight cannot start a cast.
##
## Clears the last fish explicitly rather than relying on the HOLDING and LOST
## timers to do it. A player who casts the instant a fish comes off never passes
## through IDLE, so the cleanup on that transition never ran - which left the
## previous fish's id, stress and slip live through the next cast. It was
## harmless only because `_hook` happens to reset the same fields; the golden
## showed a session sitting in `waiting` with `slip: 1.0` and a species still
## named, which is a state that should not be able to exist.
func hold_cast() -> void:
	if state != IDLE and state != LOST and state != HOLDING:
		return
	_clear_fish()
	_enter(CHARGING)
	charge = 0.0


## Let go. The rod unloads and the lure goes.
func release_cast() -> void:
	if state != CHARGING:
		return
	casts += 1
	cast_distance = Tuning.cast_distance(charge)
	fish_distance = cast_distance
	lure_depth = 0.0
	_enter(FLYING)


## Strike. The one input with a right moment, and the whole tutorial.
##
## Outside the window it spooks whatever was interested, which is what makes
## the window a decision rather than something to mash through.
func strike() -> void:
	match state:
		BITING:
			_hook()
		WAITING, NIBBLING:
			spook_timer = Tuning.SPOOK_TIME
			_enter(WAITING)
		_:
			pass


## The thumb, [0, 1]. Held during a fight; ignored everywhere else.
func set_pull(v: float) -> void:
	pull = clampf(v, 0.0, 1.0)


## Wind in without a fish on, which is how a player gets out of a dead cast.
## There must always be a way back to IDLE or the game is stuck, and "stuck"
## reads to the person holding the phone as a crash.
func reel_in() -> void:
	if state == WAITING or state == NIBBLING or state == BITING or state == SINKING:
		_enter(IDLE)
		_clear_fish()


# --- the step -------------------------------------------------------------

## One step. `dt` is seconds; the caller decides whether that came from a real
## frame or from a test stepping at a fixed rate, and the result is identical
## either way.
func advance(dt: float) -> void:
	time += dt
	state_time += dt
	if spook_timer > 0.0:
		spook_timer -= dt

	match state:
		CHARGING:
			charge = clampf(charge + dt / Tuning.CAST_CHARGE_TIME, 0.0, 1.0)
		FLYING:
			if state_time >= Tuning.cast_flight_seconds(charge):
				_enter(SINKING)
				cast_landed.emit(cast_distance)
		SINKING:
			lure_depth = minf(lure_depth + Tuning.SINK_RATE * dt, Tuning.BED_DEPTH)
			if lure_depth >= Tuning.BED_DEPTH:
				_enter(WAITING)
		WAITING:
			_wait(dt)
		NIBBLING:
			if state_time >= Tuning.NIBBLE_TIME:
				_enter(BITING)
				bite.emit(fish_id)
		BITING:
			if state_time >= Tuning.BITE_WINDOW:
				_miss()
		FIGHTING:
			_fight(dt)
		HOLDING:
			if state_time >= Tuning.HOLD_TIME:
				_enter(IDLE)
				_clear_fish()
		LOST:
			if state_time >= Tuning.HOLD_TIME * 0.5:
				_enter(IDLE)
				_clear_fish()


## Everything a harness or a HUD needs, in one dictionary.
##
## Deliberately flat and all-scalar: the golden asserts this whole thing at
## once, and a nested structure would make a one-field change unreadable in the
## diff.
func state_snapshot() -> Dictionary:
	return {
		"state": state,
		"caught": caught,
		"lost": lost_count,
		"casts": casts,
		"total_weight": snappedf(total_weight, 0.001),
		"cast_distance": snappedf(cast_distance, 0.001),
		"lure_depth": snappedf(lure_depth, 0.001),
		"fish_id": fish_id,
		"fish_distance": snappedf(fish_distance, 0.001),
		"fish_stamina": snappedf(fish_stamina, 0.001),
		"behaviour": behaviour,
		"load": snappedf(load, 0.001),
		"strain": snappedf(strain, 0.001),
		"slip": snappedf(slip, 0.001),
		"wear": snappedf(wear, 0.001),
		"pumps": pumps,
		"draws": _rng.draws(),
	}


## Is the thumb doing the right thing for what the fish is doing right now?
##
## The renderer uses this to decide how hard the rod is bending and whether the
## line is singing, and the rules use the same call - so what the player reads
## off the picture and what the game is scoring cannot drift apart. There is no
## HUD element for it and there must not be one: the whole point of the second
## fight is that the instrument is the rod.
func doing_well() -> bool:
	if state != FIGHTING:
		return false
	match behaviour:
		B_RUNNING:
			return load <= Tuning.GIVE_MAX
		B_SURFACING:
			return Tuning.shake_ok(load)
		_:
			return load < Tuning.strain_start()


## How close the line is to going, [0, 1]. The worst of the three failures, so a
## single reading can drive the sound and the shake.
func danger() -> float:
	return maxf(strain, maxf(slip, wear))


# --- internals ------------------------------------------------------------

func _enter(next: String) -> void:
	state = next
	state_time = 0.0


func _clear_fish() -> void:
	fish_id = ""
	fish_weight = 0.0
	fish_distance = 0.0
	fish_stamina = 1.0
	fight_time = 0.0
	behaviour = B_HOLDING
	behaviour_time = 0.0
	behaviour_elapsed = 0.0
	next_behaviour = ""
	tell = 0.0
	pull = 0.0
	load = 0.0
	strain = 0.0
	slip = 0.0
	wear = 0.0
	_pump_armed = false
	_pump_peak = 0.0
	pumps = 0
	charge = 0.0
	lure_depth = 0.0


## Fishing. A per-second chance converted to a per-step one, so the bite rate is
## the same at 60 fps and at 120 - the thing a raw `chance * dt` gets wrong at
## large dt and the reason this is not written the obvious way.
func _wait(dt: float) -> void:
	if spook_timer > 0.0:
		return
	var p := 1.0 - exp(-Tuning.BITE_CHANCE_PER_SEC * dt)
	if _rng.next() >= p:
		return
	var s := Species.pick(lure_depth, _rng.next())
	if s.is_empty():
		return
	fish_id = s["id"]
	fish_weight = lerpf(s["weight_lo"], s["weight_hi"], _rng.next())
	fish_stamina = 1.0
	fight_time = 0.0
	_enter(NIBBLING)
	nibble.emit()


func _hook() -> void:
	fish_distance = cast_distance
	load = 0.0
	strain = 0.0
	slip = 0.0
	wear = 0.0
	pumps = 0
	_pump_armed = false
	_pump_peak = 0.0
	fight_time = 0.0
	# Every fish starts sullen, so the first thing a player ever does in a fight
	# is pump. Opening on a run would teach the wrong lesson first.
	behaviour = B_HOLDING
	behaviour_time = Species.hold_seconds(Species.by_id(fish_id), _rng.next())
	next_behaviour = ""
	tell = 0.0
	_enter(FIGHTING)
	hooked.emit(fish_id)


func _miss() -> void:
	lost_count += 1
	_enter(LOST)
	lost.emit(MISSED)


## The fight.
##
## Three behaviours, three different correct answers, and a wear clock underneath
## that makes doing nothing a way to lose. See the long note in `tuning.gd` for
## why the previous threshold model was replaced.
func _fight(dt: float) -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(IDLE)
		_clear_fish()
		return

	fight_time += dt

	# The rod chases the thumb rather than snapping to it. That lag IS the cane
	# rod's character, and it is why a late reaction to a run still costs you
	# something even after the thumb has moved.
	var before := load
	load = lerpf(load, pull * Tuning.ROD_GAIN, SimUtil.smooth(Tuning.LOAD_RATE, dt))
	var load_speed := absf(load - before) / maxf(0.0001, dt)

	_advance_behaviour(s, dt)

	match behaviour:
		B_RUNNING:
			_run(dt)
		B_SURFACING:
			_shake(s, dt, load_speed)
		_:
			_pump(s, dt)

	# Wear runs for the whole fight and faster under load, so a cautious player
	# loses too. Without it the winning strategy is to take all day, which is
	# what every forgiving fishing minigame collapses to.
	wear = clampf(wear + (Tuning.WEAR_RATE + Tuning.WEAR_LOAD * load) * dt, 0.0, 1.0)

	if strain >= 1.0:
		_break_off(BROKE)
		return
	if slip >= 1.0 or wear >= 1.0:
		_break_off(SLIPPED)
		return

	if fish_distance <= Tuning.LAND_DISTANCE:
		_land()


## The behaviour clock, and the tell.
##
## The tell is the whole reason this is a game of awareness rather than reaction:
## the water changes about four tenths of a second before the fish does, so a
## player who is watching drops the rod BEFORE a run starts and takes no damage
## at all. A player who is watching the numbers instead reacts after it begins
## and pays for it.
func _advance_behaviour(s: Dictionary, dt: float) -> void:
	if tell > 0.0:
		tell -= dt
		if tell > 0.0:
			return
		behaviour = next_behaviour
		behaviour_elapsed = 0.0
		next_behaviour = ""
		behaviour_time = (
			Species.run_seconds(s, _rng.next(), fish_stamina) if behaviour == B_RUNNING
			else Tuning.SHAKE_TIME if behaviour == B_SURFACING
			else Species.hold_seconds(s, _rng.next())
		)
		return

	behaviour_time -= dt
	behaviour_elapsed += dt
	if behaviour_time > 0.0:
		return

	# Decide the next behaviour now, but do not switch to it yet - announce it.
	next_behaviour = Species.next_behaviour(s, _rng.next(), fish_stamina)
	if next_behaviour == behaviour and behaviour == B_HOLDING:
		# Do not "tell" a hold that follows a hold; there is nothing to warn
		# about, and a tell that fires for nothing teaches the player to ignore
		# tells - which is the only way this mechanic can actually break.
		behaviour_time = Species.hold_seconds(s, _rng.next())
		behaviour_elapsed = 0.0
		next_behaviour = ""
		return
	tell = Tuning.TELL_TIME


## Sullen. Pump it in: lift over PUMP_HIGH, then drop under PUMP_LOW, and the
## line comes in on the drop. A steady lift gains nothing, which is the single
## rule that killed the first fight's one-thumb-position exploit.
func _pump(s: Dictionary, dt: float) -> void:
	if load >= Tuning.PUMP_HIGH:
		_pump_armed = true
		_pump_peak = maxf(_pump_peak, load)
	elif _pump_armed and load <= Tuning.PUMP_LOW:
		var haul: float = s["haul"]
		fish_distance = maxf(0.0, fish_distance - Tuning.pump_gain(_pump_peak, haul))
		var stam: float = s["stamina"]
		fish_stamina = maxf(0.0, fish_stamina - Tuning.PUMP_TIRE / stam)
		pumps += 1
		_pump_armed = false
		_pump_peak = 0.0

	# The risk dial. Line gained scales with the peak, and damage begins just
	# above the most profitable pump - so a greedy lift is worth more and is
	# genuinely near the edge.
	var start := Tuning.strain_start()
	if load > start:
		var over := (load - start) / maxf(0.001, 1.0 - start)
		strain = clampf(strain + Tuning.STRAIN_RATE * over * dt, 0.0, 1.0)
	else:
		strain = maxf(0.0, strain - Tuning.RECOVER_RATE * dt)

	# Leaving the line slack for a long stretch works the hook loose on its own.
	if load < Tuning.PUMP_LOW * 0.5:
		slip = clampf(slip + Tuning.SLACK_SLIP * dt, 0.0, 1.0)
	else:
		slip = maxf(0.0, slip - Tuning.RECOVER_RATE * dt)


## It has bolted. There is nothing to do but let it go, and holding on is the
## fastest way to lose a fish in the game.
func _run(dt: float) -> void:
	fish_distance += Tuning.RUN_SPEED * dt
	if load > Tuning.GIVE_MAX:
		var over := (load - Tuning.GIVE_MAX) / maxf(0.001, 1.0 - Tuning.GIVE_MAX)
		# **A run hits hardest at its start**, decaying over the first third of a
		# second. That is what actually parts line on a real rod, and it is the
		# change that makes this mechanic reward AWARENESS rather than reflexes:
		# being a tenth of a second late costs several times what being late
		# later in the run does, so a player who reads the tell and drops the rod
		# BEFORE the run starts wins by a margin nobody can close by reacting
		# faster. Without it, more runs only made fights longer.
		var surge := 1.0 + Tuning.RUN_SURGE * exp(-behaviour_elapsed / Tuning.RUN_SURGE_DECAY)
		strain = clampf(strain + Tuning.RUN_STRAIN * surge * over * dt, 0.0, 1.0)
	else:
		strain = maxf(0.0, strain - Tuning.RECOVER_RATE * dt)
	# A pump cannot be banked across a run.
	_pump_armed = false
	_pump_peak = 0.0


## Head-shaking on the surface. The opportunity and the trap: it tires the fish
## faster than anything else, and it is the only moment in the game where MOVING
## the thumb is the mistake.
func _shake(s: Dictionary, dt: float, load_speed: float) -> void:
	var steady := Tuning.shake_ok(load) and load_speed <= Tuning.SHAKE_STILL
	if steady:
		var stam: float = s["stamina"]
		fish_stamina = maxf(0.0, fish_stamina - (Tuning.SHAKE_TIRE / stam) * dt)
		slip = maxf(0.0, slip - Tuning.RECOVER_RATE * dt)
		strain = maxf(0.0, strain - Tuning.RECOVER_RATE * dt)
	else:
		slip = clampf(slip + Tuning.SHAKE_SLIP * dt, 0.0, 1.0)
	_pump_armed = false
	_pump_peak = 0.0


func _land() -> void:
	caught += 1
	total_weight += fish_weight
	_enter(HOLDING)
	landed.emit(fish_id, fish_weight)


func _break_off(reason: String) -> void:
	lost_count += 1
	_enter(LOST)
	lost.emit(reason)
