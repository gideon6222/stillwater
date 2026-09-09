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
##    of game logic. It has been rewritten twice now, and the suite came across
##    both times.
##
## The rule that keeps it true: **nothing in this file may reference a Node, a
## Viewport, an input event or a delta that came from a real frame.** If it needs
## to know something about the world, it takes it as an argument.
##
## The second rule, specific to this game: **the line is arithmetic, never a
## physics body.** Wrecking Crew earned that one with a wrecking ball on a
## PinJoint3D - the moment the outcome of a fight lives inside the physics server
## it is at the mercy of the tick rate and the solver, and a whole-run golden
## becomes impossible. Rigid bodies are for things that decide nothing: the float
## bobbing, the boat's roll, spray.

signal cast_landed(distance: float)
signal nibble()
signal hook_offered(species_id: String)
signal hooked(species_id: String, perfect: bool)
signal tapped()
signal run_started()
signal landed(species_id: String, weight: float)
signal lost(reason: String)

## The states a line can be in. Named rather than numbered because they appear in
## the golden, where an integer would make a reordering silently pass.
const IDLE := "idle"              ## in the boat, nothing cast
const CHARGING := "charging"      ## holding, loading the cast
const FLYING := "flying"          ## in the air
const SINKING := "sinking"        ## on the water, going down
const WAITING := "waiting"        ## at depth, fishing
const NIBBLING := "nibbling"      ## the rod tip taps. Something is interested
const HOOKING := "hooking"        ## MINIGAME 1: the marker sweeps, tap in the zone
const FIGHTING := "fighting"      ## MINIGAME 2: tap to hold the needle in the band
const HOLDING := "holding"        ## landed, held up, being looked at
const LOST := "lost"              ## it came off

## Why the last fish was lost, in the words the player is shown. "The line broke"
## and "it got away" are different mistakes, and a player who cannot tell them
## apart cannot correct either.
const BROKE := "the line broke"
const ESCAPED := "it got away"
const MISSED := "you missed it"

var state: String = IDLE
var time: float = 0.0             ## seconds since the session started
var state_time: float = 0.0       ## seconds in the current state

# --- the cast -------------------------------------------------------------
var charge: float = 0.0           ## [0, 1] while CHARGING
var cast_distance: float = 0.0    ## metres out, once cast
var lure_depth: float = 0.0       ## metres down
var spook_timer: float = 0.0      ## fish put off by a wrong tap

# --- the fish -------------------------------------------------------------
var fish_id: String = ""
var fish_weight: float = 0.0
var fish_distance: float = 0.0    ## metres from the boat
var fish_stamina: float = 1.0     ## [0, 1], falls as it tires
var fight_time: float = 0.0       ## seconds this fish has been on

# --- MINIGAME 1: the hook -------------------------------------------------
## A marker sweeps a bar and the player taps while it is inside a green zone.
## The zone's WIDTH is the species and its POSITION is drawn per bite, so the
## bar has to be looked at every time rather than learned once.
var sweep: float = 0.0            ## [0, 1] where the marker is
var sweep_dir: float = 1.0
var sweeps_left: float = 0.0
var zone_lo: float = 0.0
var zone_hi: float = 0.0

# --- MINIGAME 2: the reel -------------------------------------------------
## Tapping is the whole input. Each tap kicks the needle up, it falls on its own
## between taps, and the band is fixed - so there is no position to hold and no
## meter under the thumb. During a RUN the needle climbs by itself, which makes
## "stop tapping" legible from the gauge alone.
var tension: float = 0.0          ## [0, TENSION_MAX]
var strain: float = 0.0           ## [0, 1] toward a snapped line
var running: bool = false         ## the fish is bolting
var phase_time: float = 0.0       ## seconds left in the current calm or run
var tell: float = 0.0             ## seconds of warning before a run, 0 otherwise
var taps: int = 0                 ## this fight, for the probe

# --- the session ----------------------------------------------------------
var caught: int = 0
var lost_count: int = 0
var total_weight: float = 0.0
var casts: int = 0

## Anything that decides *when* something happens is simulation, however
## decorative it looks - so bite timing, which species takes it, and where the
## hook zone sits all come off a seeded stream rather than randf(). Leaving that
## on randf() made the golden on a sibling game fail about one run in ten.
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
	caught = 0
	lost_count = 0
	total_weight = 0.0
	casts = 0
	_rng = SimRng.new(seed_value)
	_clear_fish()


# --- input, which is the only seam a thumb uses ---------------------------

## Begin loading the cast. Ignored unless the line is in the boat, so a stray
## touch during a fight cannot start one.
##
## Clears the last fish explicitly rather than relying on the HOLDING and LOST
## timers to do it. A player who casts the instant a fish comes off never passes
## through IDLE, so cleanup on that transition never ran - which left the
## previous fish's id and damage live through the next cast. The golden caught
## it as a session sitting in `waiting` with a species still named.
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


## The one input for both minigames, and for striking. **Tap.**
##
## That it is the same gesture throughout is the point: there is one verb in the
## fight and the screen tells you when to use it. The second version of this
## fight had three different responses to three situations and Gideon's note was
## that it was not intuitive to tell what you were supposed to do.
func tap() -> void:
	match state:
		HOOKING:
			_try_hook()
		FIGHTING:
			taps += 1
			tension = clampf(tension + Tuning.TAP_KICK, 0.0, Tuning.TENSION_MAX)
			tapped.emit()
		WAITING, NIBBLING:
			# Tapping at nothing puts them off. That is what makes the hook
			# minigame a decision rather than something to mash through.
			spook_timer = Tuning.SPOOK_TIME
			_enter(WAITING)
		_:
			pass


## Wind in without a fish on, which is how a player gets out of a dead cast.
## There must always be a way back to IDLE or the game is stuck, and "stuck"
## reads to the person holding the phone as a crash.
func reel_in() -> void:
	if state == WAITING or state == NIBBLING or state == SINKING:
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
				_offer_hook()
		HOOKING:
			_sweep(dt)
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
## Deliberately flat and all-scalar: the golden asserts this whole thing at once,
## and a nested structure would make a one-field change unreadable in the diff.
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
		"sweep": snappedf(sweep, 0.001),
		"tension": snappedf(tension, 0.001),
		"strain": snappedf(strain, 0.001),
		"running": running,
		"taps": taps,
		"draws": _rng.draws(),
	}


## True while the marker is inside the green zone. The HUD draws the zone from
## `zone_lo`/`zone_hi` and the rules use this, so what the player sees and what
## is scored cannot disagree.
func sweep_in_zone() -> bool:
	return sweep >= zone_lo and sweep <= zone_hi


## True while the tension needle is inside the safe band.
func in_band() -> bool:
	return Tuning.in_band(tension)


## How close the line is to going, [0, 1]. Drives the gauge's colour, the sound
## and the shake off one reading.
func danger() -> float:
	return strain


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
	sweep = 0.0
	sweep_dir = 1.0
	sweeps_left = 0.0
	zone_lo = 0.0
	zone_hi = 0.0
	tension = 0.0
	strain = 0.0
	running = false
	phase_time = 0.0
	tell = 0.0
	taps = 0
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


## MINIGAME 1 opens. The zone's position is drawn now, so the bar is different
## every time and cannot be played from memory.
func _offer_hook() -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(WAITING)
		return
	var z := Species.hook_zone(s, _rng.next())
	zone_lo = z[0]
	zone_hi = z[1]
	sweep = 0.0
	sweep_dir = 1.0
	sweeps_left = Tuning.HOOK_SWEEPS
	_enter(HOOKING)
	hook_offered.emit(fish_id)


func _sweep(dt: float) -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(WAITING)
		return
	var speed: float = s["sweep_speed"]
	sweep += sweep_dir * speed * dt
	# Bounce, and count a pass each time it turns round. Two passes and the fish
	# loses interest, which is the time limit.
	while sweep > 1.0 or sweep < 0.0:
		if sweep > 1.0:
			sweep = 2.0 - sweep
			sweep_dir = -1.0
		else:
			sweep = -sweep
			sweep_dir = 1.0
		sweeps_left -= 1.0
	if sweeps_left <= 0.0:
		lost_count += 1
		_enter(LOST)
		lost.emit(MISSED)


func _try_hook() -> void:
	if not sweep_in_zone():
		lost_count += 1
		_enter(LOST)
		lost.emit(MISSED)
		return

	# Dead centre starts the fight with the needle already in the band, which is
	# a real reward for a clean set rather than a score bonus - the player feels
	# it in the first second of the fight instead of reading it in a number.
	var mid := (zone_lo + zone_hi) * 0.5
	var half := maxf(0.0001, (zone_hi - zone_lo) * 0.5)
	var off := absf(sweep - mid) / half
	var perfect := off <= Tuning.HOOK_PERFECT

	fish_distance = cast_distance
	tension = Tuning.SAFE_LO + (Tuning.HOOK_PERFECT_BONUS if perfect else 0.0)
	strain = 0.0
	taps = 0
	fight_time = 0.0
	running = false
	tell = 0.0
	phase_time = Species.calm_seconds(_rng.next())
	_enter(FIGHTING)
	hooked.emit(fish_id, perfect)


## MINIGAME 2.
##
## Tension falls on its own and every tap kicks it up, so holding the needle in
## the band is a RATE rather than a position - which is what makes it tappable
## and what stops it collapsing into "find the spot and freeze", the fault that
## killed the first version of this fight.
func _fight(dt: float) -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(IDLE)
		_clear_fish()
		return

	fight_time += dt
	_advance_phase(s, dt)

	# The fish's own pull during a run. The needle climbs with no input at all,
	# which is the entire instruction for what to do about it: the player sees
	# it rising while their thumb is still and works out to leave it alone.
	if running:
		tension = clampf(tension + Tuning.RUN_PULL * dt, 0.0, Tuning.TENSION_MAX)
		fish_distance += Tuning.RUN_GAIN * dt

	tension = maxf(0.0, tension - Tuning.TAP_DECAY * tension * dt)

	if tension > Tuning.SAFE_HI:
		var over := (tension - Tuning.SAFE_HI) / maxf(0.001, Tuning.TENSION_MAX - Tuning.SAFE_HI)
		strain = clampf(strain + Tuning.STRAIN_RATE * over * dt, 0.0, 1.0)
		if strain >= 1.0:
			lost_count += 1
			_enter(LOST)
			lost.emit(BROKE)
			return
	else:
		strain = maxf(0.0, strain - Tuning.STRAIN_RECOVER * dt)

	if Tuning.in_band(tension):
		var haul: float = s["haul"]
		fish_distance = maxf(0.0, fish_distance - Tuning.REEL_RATE * haul * dt)
		var stam: float = s["stamina"]
		fish_stamina = maxf(0.0, fish_stamina - (Tuning.TIRE_RATE / stam) * dt)
	elif tension < Tuning.SAFE_LO:
		# Slack. The fish takes line back rather than throwing the hook, so not
		# tapping enough is a slow bleed and not a sudden death - one clear
		# failure per mistake, and this one is legible on the distance readout.
		fish_distance += Tuning.SLIP_RATE * dt

	if fish_distance >= cast_distance + Tuning.ESCAPE_MARGIN:
		lost_count += 1
		_enter(LOST)
		lost.emit(ESCAPED)
		return

	if fish_distance <= Tuning.LAND_DISTANCE:
		caught += 1
		total_weight += fish_weight
		_enter(HOLDING)
		landed.emit(fish_id, fish_weight)


## Calm and run alternate, with a generous warning before each run.
##
## `TELL_TIME` is deliberately long. This is a game about watching the water, and
## a warning shorter than a person's reaction time makes a mechanic that punishes
## reflexes rather than attention - which the second version of this fight got
## wrong in the other direction.
func _advance_phase(s: Dictionary, dt: float) -> void:
	if tell > 0.0:
		tell -= dt
		if tell <= 0.0:
			running = true
			tension = clampf(tension + Tuning.RUN_JOLT, 0.0, Tuning.TENSION_MAX)
			phase_time = Species.run_seconds(_rng.next(), fish_stamina)
			run_started.emit()
		return

	phase_time -= dt
	if phase_time > 0.0:
		return

	if running:
		running = false
		phase_time = Species.calm_seconds(_rng.next())
		return

	if Species.runs_next(s, _rng.next(), fish_stamina):
		tell = Tuning.TELL_TIME
	else:
		phase_time = Species.calm_seconds(_rng.next())
