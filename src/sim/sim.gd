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
signal hooked(species_id: String, perfect: bool)
signal tapped()
signal run_started()
signal landed(species_id: String, weight: float)
signal object_found(object_id: String)
signal lost(reason: String)
## The light went. Fired whether the player slept or simply fished through it.
signal hour_turned(hour: String)

## The states a line can be in. Named rather than numbered because they appear in
## the golden, where an integer would make a reordering silently pass.
const IDLE := "idle"              ## in the boat, nothing cast
const CHARGING := "charging"      ## holding, loading the cast
const FLYING := "flying"          ## in the air
const SINKING := "sinking"        ## on the water, going down
const WAITING := "waiting"        ## at depth, fishing
const NIBBLING := "nibbling"      ## MINIGAME 1: watch the float. Strike on the take
const FIGHTING := "fighting"      ## MINIGAME 2: tap to hold the needle in the band
const HOLDING := "holding"        ## landed, held up, being looked at
const LOST := "lost"              ## it came off

## Why the last fish was lost, in the words the player is shown. "The line broke"
## and "it got away" are different mistakes, and a player who cannot tell them
## apart cannot correct either.
const BROKE := "the line broke"
const ESCAPED := "it got away"
const MISSED := "you were too slow"
const EARLY := "you struck too early"

var state: String = IDLE
var time: float = 0.0             ## seconds since the session started
var state_time: float = 0.0       ## seconds in the current state

# --- where and when -------------------------------------------------------
## The spine of the whole game. `spot` is where the boat is; the depth the lure
## reaches there is the shallower of the lake bed and what the LINE will stand -
## and depth is time, so the line IS the story progression. See `world.gd`.
var spot: String = "reed_bay"
var hour: String = "dawn"
var weather: String = "clear"
var day: int = 1
## How much of this hour is left, in seconds. See `Tuning.HOUR_SECONDS`.
##
## G4. The light going is the only clock in this game, and it is the thing that
## makes waiting a fish out a DECISION rather than simply the slow way to win.
var hour_left: float = Tuning.HOUR_SECONDS

var econ := Econ.new()

## Player settings. They live on the sim ONLY so that the pure save can carry
## them - nothing in the rules ever reads them, and nothing should.
var sensitivity: float = 1.0
var sound_muted: bool = false

## Whether the first morning has been played. On the sim only so the pure save
## can carry it; no rule reads it.
var intro_done: bool = false

## THE DEEPEST THE LINE HAS EVER BEEN, over the whole save.
##
## One float, and it is the only unlock in the game. The keeper's entries are
## keyed to it because depth is time: the player does not complete objectives to
## earn story, they look further back. It is a high-water mark and never falls,
## so a trip to the shallows cannot take the book away again.
var deepest_ever: float = 0.0

## Species landed at least once, and objects found at least once. The logbook is
## the collection, and a collection is the one reward whose value does not decay
## the way money does: every amount of money you earn makes the last amount
## irrelevant, and a filled page never stops being filled.
var logged: Dictionary = {}
## WHICH HOURS HAVE PRODUCED FISH, per spot: `spot -> { hour: count }`.
##
## P6: "The same spot at a different hour is a reason to go, not just something
## that happens to you." Several species only bite at dusk or at night and always
## have, and the player had no way to find that out except by accident and memory.
##
## This is the game's own answer rather than a hint system: the keeper writes down
## what they caught and when, and the chart reads their book back to them. Nothing
## is revealed that was not earned - a spot you have never fished at night says
## nothing about the night.
var caught_at: Dictionary = {}
var found: Dictionary = {}
var last_object: String = ""      ## what came up on the last cast, "" for a fish

# --- the cast -------------------------------------------------------------
var charge: float = 0.0           ## [0, 1] while CHARGING
var cast_charge: float = 0.0      ## the charge the CURRENT cast was made at.
                                  ## Kept separate because `charge` is cleared,
                                  ## and this is what decided the depth - and
                                  ## therefore the year - of this cast.
var cast_distance: float = 0.0    ## metres out, once cast
var lure_depth: float = 0.0       ## metres down
var spook_timer: float = 0.0      ## fish put off by a wrong tap
var bite_in: float = 0.0          ## seconds until the next bite, drawn once
## How many takes this fish will offer before it gives up on the bait. More than
## one for almost everything - see the note in `_nibble`.
var takes_left: int = 2

# --- the fish -------------------------------------------------------------
var fish_id: String = ""
var fish_weight: float = 0.0
var fish_distance: float = 0.0    ## metres from the boat
var fish_stamina: float = 1.0     ## [0, 1], falls as it tires
var fight_time: float = 0.0       ## seconds this fish has been on
## THE REEL BUTTON, held or not. See `set_reeling` and Tuning.HOLD_RISE.
var reeling := false

# --- MINIGAME 1: the nibble -----------------------------------------------
## The fish teases the bait a few times - short shallow tugs that pop straight
## back - and then takes it properly, deeper and for longer. Strike on the take
## and you are on; strike on a tease and you have pulled it out of its mouth.
##
## `tug` is what the renderer pulls the float under by, so the ONE number that
## decides the outcome is also the one the player is watching. There is no HUD
## element for any of this and there must not be one.
var tug: float = 0.0              ## [0, 1] how far the float is pulled under
var taking: bool = false          ## this tug is the real take, not a tease
var teases_left: int = 0
var tug_timer: float = 0.0        ## seconds left in the current tug or gap
var in_tug: bool = false          ## false means still water between tugs

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
	bite_in = 0.0
	caught = 0
	lost_count = 0
	total_weight = 0.0
	casts = 0
	spot = "reed_bay"
	hour = "dawn"
	weather = "clear"
	day = 1
	econ.reset()
	logged = {}
	found = {}
	last_object = ""
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
	cast_charge = charge
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
		NIBBLING:
			_strike()
		FIGHTING:
			# NOTHING. The fight is held, not tapped - see `set_reeling`. The
			# stand-in is deleted in the same commit as the real thing, so there
			# is no second way to add tension that could drift from the first.
			pass
		WAITING:
			# **A tap on a dead cast winds the line in.** It used to spook, which
			# left a player waiting for a bite that never came with NO way back to
			# the boat: `hold_cast` is refused while a line is out, and tapping
			# only reset a timer. It shipped, and the report was "I cant recast or
			# anything".
			#
			# `reel_in` existed the whole time and nothing in the renderer called
			# it. The suite checked the way out of every state the SIM has, and
			# never that the game offered one - **a way out only the simulation
			# knows about is not a way out.**
			_enter(IDLE)
			_clear_fish()
		_:
			pass


## PUT THE ROD DOWN WITHOUT CASTING.
##
## The renderer needs this because one finger carries three verbs: a still hold
## loads a cast and a drag looks around, so the instant a hold turns out to be a
## drag the loaded cast has to go away. There was no way to do that - the only
## exit from CHARGING was `release_cast`, which THROWS - so looking around threw
## a line every time. A feel test caught it on its first run.
##
## Distinct from `reel_in`, which is for a line already in the water.
func cancel_cast() -> void:
	if state != CHARGING:
		return
	charge = 0.0
	_enter(IDLE)
	_clear_fish()


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

	# THE LIGHT GOES WHILE YOU FISH. G4.
	#
	# It runs in every state, including a fight - that is the entire point. The
	# note on TIRE_RATE says waiting a fish out "costs the clock, which is the one
	# resource this game says is scarce", and until this line existed the clock
	# was not a resource: an hour only changed when the player asked it to, so
	# patience was free and the fifth fight's central trade was a trade against
	# nothing.
	hour_left -= dt
	if hour_left <= 0.0:
		_turn_hour()

	match state:
		CHARGING:
			charge = clampf(charge + dt / Tuning.CAST_CHARGE_TIME, 0.0, 1.0)
		FLYING:
			if state_time >= Tuning.cast_flight_seconds(charge):
				_enter(SINKING)
				cast_landed.emit(cast_distance)
		SINKING:
			# Sinks to the depth the LINE reaches at this spot, not to the bed. Those
			# are the same number in the reeds and nowhere else, and the difference
			# is the whole progression: better line, deeper lure, older water.
			var target := fishing_depth()
			deepest_ever = maxf(deepest_ever, target)
			lure_depth = minf(lure_depth + Tuning.SINK_RATE * Tuning.sink_speed(target) * dt, target)
			if lure_depth >= target - 0.001:
				_enter(WAITING)
		WAITING:
			_wait(dt)
		NIBBLING:
			_nibble(dt)
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
		"tug": snappedf(tug, 0.001),
		"taking": taking,
		"tension": snappedf(tension, 0.001),
		"strain": snappedf(strain, 0.001),
		"running": running,
		"taps": taps,
		"draws": _rng.draws(),
	}


## True while the fish has the bait properly - the one moment a strike works.
##
## The renderer pulls the float under by `tug` and the rules read `taking`, and
## both come from the same tug sequence, so what the player is looking at and
## what is scored cannot disagree. **There is no HUD element for this** - the
## float is the whole instrument, which is what was asked for.
func can_hook() -> bool:
	return in_tug and taking



## How close the line is to going, [0, 1]. Drives the gauge's colour, the sound
## and the shake off one reading.
func danger() -> float:
	return strain


# --- internals ------------------------------------------------------------

func _enter(next: String) -> void:
	state = next
	state_time = 0.0
	# A HELD BUTTON MUST NOT LEAK OUT OF THE FIGHT. The thumb can still be down
	# when the fish lands or the line parts, and a `reeling` left true would then
	# be pulling on the next cast before it was made.
	if next != FIGHTING:
		reeling = false


func _clear_fish() -> void:
	fish_id = ""
	fish_weight = 0.0
	fish_distance = 0.0
	fish_stamina = 1.0
	fight_time = 0.0
	tug = 0.0
	taking = false
	teases_left = 0
	takes_left = 2
	tug_timer = 0.0
	in_tug = false
	tension = 0.0
	strain = 0.0
	running = false
	phase_time = 0.0
	tell = 0.0
	taps = 0
	charge = 0.0
	cast_charge = 0.0
	lure_depth = 0.0
	bite_in = 0.0


## Waiting for a bite.
##
## **The interval is DRAWN ONCE, not rolled every frame.**
##
## Rolling a per-step coin is the obvious way and it is subtly wrong: the number
## of draws then depends on the frame rate, so the whole rng stream diverges
## between 60 fps and 120 - the physics stayed identical and every downstream
## decision drifted. The phone runs at 120 and the tests at 60, so this was a
## real difference and `test_the_simulation_is_frame_rate_independent` caught it
## the moment the content grew enough to make it visible.
##
## Drawing the WAIT and counting it down consumes exactly one draw per bite at
## any step rate, which makes the stream a property of the game rather than of
## the machine.
func _wait(dt: float) -> void:
	if spook_timer > 0.0:
		return

	if bite_in <= 0.0:
		_arm_bite()
		return

	bite_in -= dt
	if bite_in > 0.0:
		return

	# An OBJECT rather than a fish, sometimes - and the deeper you are the more
	# often, because the deep is where the town is. This is how the story is
	# told: not in cutscenes, in what comes up on the hook.
	if _rng.next() < Objects.chance_at(lure_depth):
		_hook_object()
		return

	var s := Species.pick(lure_depth, _rng.next(), hour, econ.bait)
	if s.is_empty():
		# NOTHING WILL TAKE THIS BAIT HERE - which below eighty metres means the
		# player is fishing the deep with worms. They get the bottom instead of a
		# fish, and that is the whole gate: the deep pays in objects until one of
		# those objects is an offering, and then it pays in fish.
		#
		# Hooking an object rather than re-arming is what stops it being a dead
		# end. A player who waits and waits and gets nothing concludes the game
		# is broken; a player who keeps pulling up pieces of a drowned town
		# concludes, correctly, that this water wants something else.
		_hook_object()
		return
	fish_id = s["id"]
	fish_weight = lerpf(s["weight_lo"], s["weight_hi"], _rng.next())
	fish_stamina = 1.0
	fight_time = 0.0
	last_object = ""
	_start_nibble()


## How long until something is interested.
##
## An exponential draw off the mean, so the wait has the shape a Poisson process
## has - mostly short, occasionally long - rather than the flat feel of a uniform
## roll. Weather and bait both move the mean: rain is the best fishing in the
## game and a storm is the worst, which is a reason to look at the sky.
func _arm_bite() -> void:
	var rate := Tuning.BITE_CHANCE_PER_SEC * World.weather_bite(weather)
	rate *= float(Gear.bait_by_id(econ.bait)["bite"])
	# G4: AND THE DARK. The deck lamp existed, cost 400, and changed nothing -
	# "fishing after dark is currently identical to fishing at noon" has been on
	# the open-issues list since it was bought. It buys the night now: three
	# quarters of daylight fishing with one lit, and not much better than watching
	# the water without.
	#
	# It does not hold the sun up. What it buys is the hours that are already
	# dark, which is why it is the last thing on the shed's shelf and not the
	# first - and why dusk and night are worth reaching rather than worth avoiding
	# once you own it.
	if World.is_night(hour):
		rate *= Tuning.LAMP_NIGHT_BITE if econ.has_lamp else Tuning.DARK_NIGHT_BITE
	rate = maxf(0.02, rate)
	var u := clampf(_rng.next(), 0.0001, 0.9999)
	bite_in = -log(u) / rate


## MINIGAME 1 begins. The fish is on the bait but has not committed.
##
## The number of teases is drawn per bite rather than fixed, because a fixed
## count is a metronome: two bites and the player is counting tugs instead of
## watching the float, which is the whole thing this exists to make them do.
func _start_nibble() -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(WAITING)
		return
	teases_left = Species.tease_count(s, _rng.next())
	# The prize fish of each band give ONE take and no second chance; everything
	# else gives two. Written as a species field rather than a constant so the
	# forgiveness is content, and the hardest fish can be genuinely unforgiving
	# without making the tutorial so.
	takes_left = int(s.get("takes", 2))
	tug = 0.0
	taking = false
	in_tug = false
	tug_timer = Species.tug_gap(_rng.next())
	_enter(NIBBLING)
	nibble.emit()


## The tug sequence: still water, a tug, still water, a tug... and then the take.
##
## `tug` rises and falls within each pull rather than switching on and off, so
## the float DIPS AND RECOVERS instead of teleporting. That shape is the whole
## readability of the mechanic - a tease is shallow and brief, the take is deep
## and holds, and the difference has to be visible in the movement itself.
func _nibble(dt: float) -> void:
	var s := Species.by_id(fish_id)
	if s.is_empty():
		_enter(WAITING)
		return

	tug_timer -= dt

	if in_tug:
		var span: float = float(s["take_window"]) if taking else Tuning.TEASE_TIME
		var depth: float = Tuning.TAKE_DEPTH if taking else Tuning.TEASE_DEPTH
		# A quick pull under and a slower recovery, which is what a float does.
		var k := 1.0 - clampf(tug_timer / maxf(0.001, span), 0.0, 1.0)
		tug = depth * sin(clampf(k, 0.0, 1.0) * PI)
		if tug_timer <= 0.0:
			if taking:
				# **A MISSED TAKE IS NOT THE END OF THE FISH.**
				#
				# It was: one late tap and the fish was gone. Dredge's designers
				# named the rule this breaks - "fishing should not be
				# frustrating" - and went as far as making their minigame
				# succeed even if the player never touches it. This does not go
				# that far, because the strike IS the mechanic here, but a fish
				# that gives you one chance in a two-second window is a fish that
				# teaches the player to distrust the whole system.
				#
				# So a miss costs a chance, not the fish. Most species give a
				# second go, the best of them do not, and running out is what
				# actually loses it.
				takes_left -= 1
				if takes_left > 0:
					in_tug = false
					tug = 0.0
					teases_left = 1
					tug_timer = Species.tug_gap(_rng.next())
					return
				lost_count += 1
				_enter(LOST)
				lost.emit(MISSED)
				return
			in_tug = false
			tug = 0.0
			tug_timer = Species.tug_gap(_rng.next())
		return

	# Still water between tugs.
	tug = 0.0
	if tug_timer > 0.0:
		return
	in_tug = true
	taking = teases_left <= 0
	teases_left -= 1
	tug_timer = float(s["take_window"]) if taking else Tuning.TEASE_TIME


## The strike. The first tap, and the whole of minigame 1.
##
## On the take you are on; on a tease or on still water you have pulled the bait
## out of its mouth. Two different messages, because "too early" and "too slow"
## are different mistakes and a player who cannot tell them apart cannot correct
## either.
func _strike() -> void:
	if not taking or not in_tug:
		lost_count += 1
		_enter(LOST)
		lost.emit(EARLY)
		return

	var s := Species.by_id(fish_id)
	# Striking early in the take is a clean set, and it is worth something the
	# player FEELS rather than reads: the fight opens with the needle already in
	# the band instead of below it.
	var span: float = maxf(0.001, float(s["take_window"]))
	var into := 1.0 - clampf(tug_timer / span, 0.0, 1.0)
	var perfect := into <= Tuning.HOOK_PERFECT

	fish_distance = cast_distance
	tension = Tuning.SAFE_LO + (Tuning.HOOK_PERFECT_BONUS if perfect else 0.0)
	strain = 0.0
	taps = 0
	fight_time = 0.0
	running = false
	tell = 0.0
	tug = 0.0
	in_tug = false
	taking = false
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
	var power: float = s["run_power"]
	var haul: float = s["haul"]
	var stam: float = s["stamina"]

	# TENSION IS THE DANGER, AND ONLY THE DANGER.
	#
	# Three inputs, and each one is a thing the player did or the fish did:
	#   reeling at all           the fish pulls back, harder the fresher it is
	#   reeling INTO a run       the give and take, and it climbs fast
	#   letting go               it falls back
	#
	# `resist` is what makes the first of those a decision rather than a switch.
	# A fresh deep fish settles a held reel ABOVE the danger line, so the thumb has
	# to feather; a fish worn down to nothing settles well below it, so the same
	# button can be held flat. Nothing tells the player this happened - the rod
	# stops bending as far, and they feel it.
	if reeling:
		var resist := Tuning.resist(power, fish_stamina)
		tension = clampf(tension + Tuning.HOLD_RISE * resist * dt, 0.0, Tuning.TENSION_MAX)
		if running:
			# Squared, like `resist`, so the tutorial's fish can be held through a
			# run and nothing deeper can. One relationship rather than two.
			tension = clampf(tension + Tuning.PULL_RISE * power * power * dt,
				0.0, Tuning.TENSION_MAX)
	tension = maxf(0.0, tension - Tuning.TAP_DECAY * tension * dt)

	# THE ROD IS OVER-BENT. Strain accrues, and at full overshoot the line has
	# SNAP_SECONDS before it parts - long enough that the red line and the heavy
	# buzz are a decision point rather than a surprise.
	if tension > Tuning.DANGER:
		var over := (tension - Tuning.DANGER) / maxf(0.001, Tuning.TENSION_MAX - Tuning.DANGER)
		strain = clampf(strain + (over / Tuning.SNAP_SECONDS) * dt, 0.0, 1.0)
		if strain >= 1.0:
			lost_count += 1
			_enter(LOST)
			lost.emit(BROKE)
			return
	else:
		strain = maxf(0.0, strain - Tuning.STRAIN_RECOVER * dt)

	# DISTANCE IS THE PROGRESS, and what it does depends on the two of you.
	if running:
		# The fish is taking line. Reeling into it slows that but does not stop
		# it for anything strong - which is what makes holding on a gamble rather
		# than simply slower.
		# Holding on BRAKES the run rather than out-hauling it. A reel term could
		# never beat a strong fish's own pull, which is what made the gamble a
		# non-choice; a brake on the run's own gain is a decision worth making and
		# worth paying tension for.
		var brake := (1.0 - Tuning.RUN_HOLD) if reeling else 1.0
		fish_distance += Tuning.RUN_GAIN * power * brake * dt
		# AND A RUNNING FISH TIRES ITSELF. Not the reeling - the running. So
		# waiting a run out is a real strategy and its cost is the clock, which is
		# the one resource this game says is scarce.
		fish_stamina = maxf(0.0, fish_stamina - (Tuning.TIRE_RATE / stam) * dt)
	elif reeling:
		# Calm water, and the thumb down. This is where the ground is made.
		fish_distance = maxf(0.0, fish_distance - Tuning.REEL_RATE * haul * dt)

	# AND PRESSURE TIRES IT TOO, which is the reward half of the risk.
	#
	# Held near the red a fish gives up roughly twice as fast as one played
	# gently, so the greedy line really is the quick way home and really is the
	# one that parts lines. Without this the player had no lever on the length of
	# a fight at all and a deep fish was slow rather than hard.
	if reeling:
		fish_stamina = maxf(0.0, fish_stamina - (Tuning.TIRE_PRESSURE * tension / stam) * dt)

	if fish_distance >= cast_distance + Tuning.ESCAPE_MARGIN:
		lost_count += 1
		_enter(LOST)
		lost.emit(ESCAPED)
		return

	if fish_distance <= Tuning.LAND_DISTANCE:
		_land_fish()


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
			# The jolt is deliberately COMPRESSED against run_power while the
			# sustained pull is not. Scaling both fully made run_power a cliff:
			# every fish below 0.85 was landed every time and every fish above it
			# was a coin flip, because the spike alone decided the fight in one
			# frame and nothing after it mattered.
			#
			# Compressed, the difference between a bluegill and the Old Fish is
			# pressure you have to hold off for the whole run rather than one
			# moment you either survived or did not. Strong fish should mean
			# "fight this the whole way", never "one instant decided it".
			var jolt: float = Tuning.RUN_JOLT * Tuning.jolt_scale(float(s["run_power"]))
			tension = clampf(tension + jolt, 0.0, Tuning.TENSION_MAX)
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


## A fish is on the boat.
##
## Three things happen and they are deliberately separate: it is COUNTED, it is
## LOGGED, and it is KEPT - and the last one can fail. A fish too heavy for the
## livewell is landed, admired, written in the book, and then goes back in the
## water, which is a legible wall rather than a bug: the answer is a bigger box
## and the shed says so.
func _land_fish() -> void:
	caught += 1
	total_weight += fish_weight
	var row := Species.by_id(fish_id)
	var wrong: bool = row.get("wrong", false)
	logged[fish_id] = maxf(float(logged.get(fish_id, 0.0)), fish_weight)
	var book: Dictionary = caught_at.get(spot, {})
	book[hour] = int(book.get(hour, 0)) + 1
	caught_at[spot] = book
	econ.keep(fish_id, fish_weight, wrong)
	econ.spend_bait()
	_enter(HOLDING)
	landed.emit(fish_id, fish_weight)


## Something that is not a fish. It comes straight up - there is no fight in a
## boot - and it goes in the book if it is worth remembering.
func _hook_object() -> void:
	var o := Objects.pick(lure_depth, _rng.next())
	if o.is_empty():
		return
	last_object = o["id"]
	fish_id = ""
	fish_weight = 0.0
	found[o["id"]] = true
	# AN OFFERING GOES IN THE BAIT BOX. It is the only bait in the game that
	# cannot be bought, and this is the only way to get one - which is what makes
	# the bottom of the lake something you earn by paying attention rather than
	# by grinding.
	if o["kind"] == Objects.OFFERING:
		econ.bait_left[Gear.OFFERING] = int(econ.bait_left.get(Gear.OFFERING, 0)) + 1
	if o["kind"] == Objects.JUNK:
		econ.money += int(o["value"])
	econ.spend_bait()
	_enter(HOLDING)
	object_found.emit(o["id"])


# --- the day, and where the boat is ---------------------------------------

## Travel. Refused rather than silently ignored when the spot is out of reach, so
## the map can say WHY - "you need the motor" and "your line will not reach" are
## different answers and a player who cannot tell them apart cannot act on either.
func travel_to(id: String) -> bool:
	if state != IDLE:
		return false
	var s := World.spot_by_id(id)
	if s["needs_motor"] and not econ.has_motor:
		return false
	# Refused rather than allowed-and-useless. Somewhere your line cannot reach
	# any water is somewhere the game would let you sit and catch nothing, which
	# is the worst kind of no: one that looks like a bug.
	if not World.line_reaches_water(id, econ.line):
		return false
	spot = id
	_clear_fish()
	return true


## Why a spot cannot be fished usefully yet, in the words the map shows. Empty
## means it is fine.
func spot_blocked(id: String) -> String:
	var s := World.spot_by_id(id)
	if s["needs_motor"] and not econ.has_motor:
		return "you would have to row"
	if not World.line_reaches_water(id, econ.line):
		return "your line will not reach this water at all"
	var reach := World.reachable_depth(id, econ.line)
	if reach < float(s["bed"]) - 0.01:
		return "your line will not reach the bottom"
	return ""


## How deep the lure actually fishes here. The shallower of the lake bed and what
## the line will stand - the one line of arithmetic the whole progression is.
## How deep the lure fishes on THIS cast. The charge chose it - see world.gd.
func fishing_depth() -> float:
	return World.depth_for_cast(spot, econ.line, cast_charge)


## The deepest this spot goes with the line you own. What the map shows.
func deepest_here() -> float:
	return World.reachable_depth(spot, econ.line)


## The year at the depth being fished. Never shown as a caption; the sounder
## shows metres and the objects carry dates, and the player joins them up.
func year_here() -> int:
	return World.depth_to_year(fishing_depth())


## Sleep. Advances the hour, rolls the weather, and on a new dawn advances the
## day. There is no fatigue meter: the clock exists to change what bites and what
## the lake looks like, not to ration play.
func sleep() -> void:
	if state != IDLE:
		return
	_turn_hour()


## The hour turns, whether you asked for it or not.
##
## One place, so sleeping and simply running out of light do exactly the same
## thing - the alternative is two paths that drift, and the one nobody exercises
## is the one that forgets to roll the day over.
func _turn_hour() -> void:
	hour = World.next_hour(hour)
	hour_left = Tuning.HOUR_SECONDS
	if hour == "dawn":
		day += 1
	weather = World.pick_weather(_rng.next())
	hour_turned.emit(hour)


## THE HOUR THIS WATER HAS GIVEN UP THE MOST FISH AT, or "" if it has given up
## none worth calling a pattern.
##
## P6, and the RESTRAINT is the feature. It would be trivial and wrong to read
## `Species.TABLE` and tell the player which fish bite at dusk: the whole game is
## built on working the lake out, and that would be the strategy guide printed
## inside the box. This only ever reads back what the keeper has already written.
##
## Lives here rather than in the chart that draws it, because it is a fact about
## the save and not about rendering - and because a copy of it in the renderer and
## a copy in a test is two rules that can disagree about what the book says.
func best_hour_at(spot_id: String) -> String:
	var book = caught_at.get(spot_id, {})
	if not (book is Dictionary) or (book as Dictionary).is_empty():
		return ""
	var best := ""
	var best_n := 0
	var tied := false
	for h in book:
		var n := int(book[h])
		if n > best_n:
			best_n = n
			best = str(h)
			tied = false
		elif n == best_n:
			tied = true
	# ONE FISH IS NOT A PATTERN, and a dead heat is not a finding.
	if tied or best_n < 2:
		return ""
	return best


## Sell the livewell. Returns what it paid so the shed can say it out loud.
func sell() -> int:
	return econ.sell_all()


## HOLD TO REEL. The renderer calls this on press and on release.
##
## Separate from `tap()`, which stays for the STRIKE - the one place a discrete
## press is still the right verb, because striking is an instant, not a duration.
## Two names for two genuinely different actions rather than one overloaded one.
func set_reeling(on: bool) -> void:
	if state != FIGHTING:
		reeling = false
		return
	reeling = on
