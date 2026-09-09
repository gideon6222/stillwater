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
var fish_id: String = ""
var fish_weight: float = 0.0
var fish_distance: float = 0.0    ## metres from the boat
var fish_stamina: float = 1.0     ## [0, 1], falls under pressure
var fight_time: float = 0.0       ## seconds this fish has been on

# --- the line -------------------------------------------------------------
var pull: float = 0.0             ## the thumb, [0, 1]
var tension: float = 0.0          ## [0, TENSION_MAX]
var stress: float = 0.0           ## [0, 1] toward a break
var slip: float = 0.0             ## [0, 1] toward a thrown hook

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
	pull = 0.0
	tension = 0.0
	stress = 0.0
	slip = 0.0
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
		"tension": snappedf(tension, 0.001),
		"stress": snappedf(stress, 0.001),
		"slip": snappedf(slip, 0.001),
		"draws": _rng.draws(),
	}


## The safe band right now, as [lo, hi]. The HUD draws exactly this, so the band
## the player sees and the band the rules use cannot drift apart - the same
## guarantee as showing the real ship in Coreward's shop instead of a copy.
func band() -> Array:
	if fish_id == "":
		return [Tuning.band_lo(0.3), Tuning.band_hi(0.3)]
	var s := Species.by_id(fish_id)
	if s.is_empty():
		return [Tuning.band_lo(0.3), Tuning.band_hi(0.3)]
	var w: float = s["band"]
	return [Tuning.band_lo(w), Tuning.band_hi(w)]


## True while the tension is where it should be. Drives both the rules and the
## colour of the band, for the same reason.
func in_band() -> bool:
	var b := band()
	return tension >= b[0] and tension <= b[1]


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
	pull = 0.0
	tension = 0.0
	stress = 0.0
	slip = 0.0
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
	tension = Tuning.BAND_CENTRE
	stress = 0.0
	slip = 0.0
	fight_time = 0.0
	_enter(FIGHTING)
	hooked.emit(fish_id)


func _miss() -> void:
	lost_count += 1
	_enter(LOST)
	lost.emit(MISSED)


## The fight.
##
## Tension is the thumb PLUS the fish, chased toward its target rather than
## snapped to it, so the rod has some give in it. The band is fixed, so staying
## inside means giving line when the fish surges and taking it back when it
## rests. That is the whole mechanic and everything else here is bookkeeping.
func _fight(dt: float) -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(IDLE)
		_clear_fish()
		return

	fight_time += dt
	var fish_pull := Species.pull_at(s, fight_time, fish_stamina)
	var target := clampf(pull * Tuning.ROD_GAIN + fish_pull, 0.0, Tuning.TENSION_MAX)
	tension = lerpf(tension, target, SimUtil.smooth(Tuning.TENSION_RATE, dt))

	var b := band()
	var lo: float = b[0]
	var hi: float = b[1]

	if tension > hi:
		# How far over, as a fraction of the headroom. A line an inch over the
		# band must not fail as fast as one at the stop, or there is no reason
		# to ease off rather than let go entirely.
		var over := (tension - hi) / maxf(0.001, Tuning.TENSION_MAX - hi)
		stress = clampf(stress + Tuning.STRESS_RATE * over * dt, 0.0, 1.0)
		slip = maxf(0.0, slip - Tuning.RECOVER_RATE * dt)
		if stress >= 1.0:
			_break_off(BROKE)
			return
	elif tension < lo:
		var under := (lo - tension) / maxf(0.001, lo)
		slip = clampf(slip + Tuning.SLIP_RATE * under * dt, 0.0, 1.0)
		stress = maxf(0.0, stress - Tuning.RECOVER_RATE * dt)
		if slip >= 1.0:
			_break_off(SLIPPED)
			return
	else:
		var haul: float = s["haul"]
		fish_distance = maxf(0.0, fish_distance - Tuning.RETRIEVE_RATE * haul * dt)
		var stam: float = s["stamina"]
		fish_stamina = maxf(0.0, fish_stamina - (Tuning.STAMINA_DRAIN / stam) * dt)
		stress = maxf(0.0, stress - Tuning.RECOVER_RATE * dt)
		slip = maxf(0.0, slip - Tuning.RECOVER_RATE * dt)

	if fish_distance <= Tuning.LAND_DISTANCE:
		_land()


func _land() -> void:
	caught += 1
	total_weight += fish_weight
	_enter(HOLDING)
	landed.emit(fish_id, fish_weight)


func _break_off(reason: String) -> void:
	lost_count += 1
	_enter(LOST)
	lost.emit(reason)
