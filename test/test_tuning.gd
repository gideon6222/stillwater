extends RefCounted

## Tests over the tuning curves and the species table.
##
## These check the SHAPE of the numbers rather than their values, because the
## values are meant to be changed. A test that pins a constant makes tuning
## painful and catches nothing; a test that pins the relationship between two
## constants catches the change that breaks the game.


func test_cast_distance_spans_the_advertised_range(t: TestHarness) -> void:
	t.approx(Tuning.cast_distance(0.0), Tuning.CAST_MIN, 1e-6, "a tap casts the minimum")
	t.approx(Tuning.cast_distance(1.0), Tuning.CAST_MAX, 1e-6, "a full charge casts the maximum")
	t.gt(Tuning.CAST_MAX, Tuning.CAST_MIN, "a full cast must go further than a tap")

	# Monotonic, so more hold is never less distance. A non-monotonic charge
	# curve is unlearnable however good the numbers look at the ends.
	var prev := -1.0
	for i in 21:
		var d := Tuning.cast_distance(float(i) / 20.0)
		t.gt(d, prev, "cast distance rises with charge at %d%%" % (i * 5))
		prev = d


func test_cast_distance_is_clamped_outside_the_unit_range(t: TestHarness) -> void:
	t.approx(Tuning.cast_distance(-1.0), Tuning.CAST_MIN, 1e-6, "negative charge clamps to the minimum")
	t.approx(Tuning.cast_distance(9.0), Tuning.CAST_MAX, 1e-6, "over-charge clamps to the maximum")


func test_flight_time_is_a_playable_length(t: TestHarness) -> void:
	var short_cast := Tuning.cast_flight_seconds(0.0)
	var long_cast := Tuning.cast_flight_seconds(1.0)
	t.gt(long_cast, short_cast, "a longer cast takes longer to land")
	t.gt(short_cast, 0.1, "even a tap has visible flight time")
	t.lt(long_cast, 2.0, "the longest cast must not feel like waiting")
## THE THREE NUMBERS THE FIFTH FIGHT HANGS ON, and each one is a promise to the
## player rather than a tuning preference.
##
## Gideon: "there should be a give and take, where you can keep reeling but risk
## losing the fish, but if you get in a good rythem and wear the fish out, you can
## reel while the fish is calm and stop when it starts pulling too hard."
##
## That sentence is three claims, and all three are arithmetic:
func test_reeling_in_calm_water_is_safe_forever(t: TestHarness) -> void:
	# 1. A patient player can hold the button all day in calm water and nothing
	# breaks. Tension settles at HOLD_RISE / TAP_DECAY, and that has to land
	# clearly BELOW the danger line - this is the whole difference from the fourth
	# fight, where a held button always ended in a snapped line.
	var settle := Tuning.HOLD_RISE / Tuning.TAP_DECAY
	t.lt(settle, Tuning.DANGER * 0.85,
		"reeling in calm water settles at %.2f against a danger line of %.2f - too close to hold" % [
			settle, Tuning.DANGER])
	t.gt(settle, Tuning.DANGER * 0.35,
		"reeling settles at %.2f, so far below danger that the rod never bends at all" % settle)


func test_reeling_into_a_run_reaches_danger_in_a_readable_time(t: TestHarness) -> void:
	# 2. Holding on through a run has to bite, and bite soon enough to be a
	# decision. Measured for an average fish by stepping the arithmetic rather
	# than by trusting a closed form.
	var tension := Tuning.HOLD_RISE / Tuning.TAP_DECAY
	var dt := 1.0 / 60.0
	var took := 0.0
	while tension < Tuning.DANGER and took < 8.0:
		tension += (Tuning.HOLD_RISE + Tuning.PULL_RISE * 1.0) * dt
		tension -= Tuning.TAP_DECAY * tension * dt
		took += dt
	t.lt(took, 1.6,
		"reeling into a run takes %.2f s to reach danger - the player will not connect the two" % took)
	t.gt(took, 0.25,
		"reeling into a run reaches danger in %.2f s, which is faster than anyone can react" % took)


func test_a_snapped_line_is_a_decision_and_not_a_surprise(t: TestHarness) -> void:
	# 3. From "the rod reads as over-bent" to a parted line must be long enough
	# that the red line and the heavy buzz land first. The research puts this at
	# the forgiving end deliberately: a snap the player did not choose is the
	# thing every source warns about.
	t.gt(Tuning.SNAP_SECONDS, 0.8,
		"the line parts %.1f s after the warning, which is a surprise rather than a choice" % Tuning.SNAP_SECONDS)
	t.lt(Tuning.SNAP_SECONDS, 3.0,
		"the line takes %.1f s to part, so over-bending it costs nothing in practice" % Tuning.SNAP_SECONDS)
	t.lt(Tuning.DANGER, Tuning.TENSION_MAX,
		"there is no headroom above the danger line to break the line in")


## THE TWO WAYS TO LOSE A FISH MUST LOOK DIFFERENT AND TAKE DIFFERENT TIMES.
##
## A parted line is sudden and is your fault: you held the reel against a fish
## that was pulling. An escape is slow and is also your fault, in the opposite
## direction: you would not hold it at all, and the fish took the line a run at a
## time. If those two ever took similar amounts of time the player could not tell
## which mistake they had made, and the fight would read as random.
func test_the_two_failures_are_different_speeds(t: TestHarness) -> void:
	t.gt(Tuning.SNAP_SECONDS, 0.8,
		"the line parts faster than a person can let go of a button")
	t.lt(Tuning.SNAP_SECONDS, 2.5,
		"the line takes so long to part that holding on has no cost")

	# How long the strongest fish needs to take the whole margin, unbraked.
	# Several runs, not one - a single run ending the fight is exactly the thing
	# ESCAPE_MARGIN was raised to stop, and a trace caught it doing so.
	var worst := 0.0
	for row in Species.TABLE:
		worst = maxf(worst, float(row["run_power"]))
	var one_run := Tuning.RUN_GAIN * worst * Tuning.RUN_MAX
	t.lt(one_run, Tuning.ESCAPE_MARGIN,
		"the strongest fish's longest run (%.1f m) clears the whole escape margin (%.1f m) by itself, so the fight can end before a decision is offered" % [
			one_run, Tuning.ESCAPE_MARGIN])

	var seconds_to_escape := Tuning.ESCAPE_MARGIN / (Tuning.RUN_GAIN * worst)
	t.gt(seconds_to_escape, Tuning.SNAP_SECONDS * 1.5,
		"being run off (%.1fs) takes about as long as parting the line (%.1fs), so the two mistakes are not tellable apart" % [
			seconds_to_escape, Tuning.SNAP_SECONDS])


## HOLDING ON HAS TO BE A REAL OPTION, or a run has one answer and no decision.
func test_holding_on_through_a_run_is_worth_considering(t: TestHarness) -> void:
	t.gt(Tuning.RUN_HOLD, 0.25,
		"holding on barely slows the run, so letting go is always correct")
	t.lt(Tuning.RUN_HOLD, 0.75,
		"holding on stops the run outright, so there is nothing to weigh")

	# And it has to COST, or it would not be a gamble. HOLDING an ordinary fish's
	# run on a held line - the centre of the slide, no crank - has to settle past
	# the danger line, or the middle of the slide is a free answer to every run.
	# A held line during a run carries the fish's whole resistance plus its pull.
	var settle_in_run := (Tuning.HOLD_RISE * Tuning.resist(1.0, 1.0) + Tuning.PULL_RISE) / Tuning.TAP_DECAY
	t.gt(settle_in_run, Tuning.DANGER,
		"holding through an average fish's run settles at %.2f, below the danger line, so there is no risk in it at all" % settle_in_run)

	# And against the strongest fish in the lake, holding on must still LOSE
	# ground. A brake that turned a run into progress would make the gamble the
	# only play and delete the decision from the other side.
	var worst := 0.0
	for row in Species.TABLE:
		worst = maxf(worst, float(row["run_power"]))
	var braked := Tuning.RUN_GAIN * worst * (1.0 - Tuning.RUN_HOLD)
	t.gt(braked, 0.0,
		"holding on through the hardest run in the game stops the fish dead, so a run is not a setback")


## GIVING LINE IS ALWAYS SAFE. That is the promise the whole fight rests on, and
## it is the one thing a player must be able to rely on without being told: the
## bottom of the slide can never part a line.
func test_giving_line_is_always_safe(t: TestHarness) -> void:
	# Nothing raises tension on a free spool: the pull loads a line in proportion
	# to how much of it is held, and at full give that is none. Tension can only
	# fall there, and faster than it does on a held line.
	t.gt(Tuning.TAP_DECAY, 0.0, "tension does not fall when the reel is held still")
	t.gt(Tuning.GIVE_RELIEF, 0.0, "giving line relieves nothing beyond what holding does")

	# And no jolt may part a line ON ITS OWN. Being caught mid-reel when the fish
	# goes is allowed to pin the rod at the top - that is what the tell is there to
	# let you avoid - but pinned is not parted: `SNAP_SECONDS` of warning has to
	# remain, every time, for every fish in the lake.
	#
	# This assertion used to be stronger, and wrongly so. It demanded that the jolt
	# never pin the rod at all, which is a promise the game does not make and
	# should not: a run that cannot bend the rod past the red is a run with no
	# stakes. What must hold is that the player always gets the same second and a
	# bit to decide.
	t.gt(Tuning.SNAP_SECONDS, 1.0,
		"a pinned line parts in %.1f s, which is inside a person's reaction time" % Tuning.SNAP_SECONDS)
	for row in Species.TABLE:
		var power := float(row["run_power"])
		var jolt := Tuning.RUN_JOLT * Tuning.jolt_scale(power)
		t.lt(jolt, Tuning.TENSION_MAX - Tuning.DANGER + 0.5,
			"%s's opening kick is most of the whole scale, so a run is a verdict rather than an event" % row["name"])


## NO FISH MAY BE SO STRONG THAT THE REEL BECOMES A REFLEX TEST.
##
## Arithmetic, not taste. A full crank settles at `crank_settle`, and once that is
## far enough above the danger line the tension pins at the top before a person
## can react - so the only playable input is a tap shorter than a reaction time.
## That is a dexterity wall, and this game is about watching.
##
## It shipped once. The Old Fish settled at 1.36 and the measurement was stark:
## ANGLER, perfect and instant, landed 44% of them; HUMAN, the same policy with
## three tenths of a second of lag, landed none and parted the line on three
## quarters. `RESIST_MAX` is the cap that fixed it.
func test_no_fish_is_a_reflex_test(t: TestHarness) -> void:
	for row in Species.TABLE:
		var power := float(row["run_power"])
		var settle := Tuning.crank_settle(power, 1.0)
		# Half a second of holding, from the tension a fresh hook starts at, must
		# not reach the top of the scale. That is the margin a person needs.
		var after_half := settle + (Tuning.SAFE_LO - settle) * exp(-Tuning.TAP_DECAY * 0.5)
		t.lt(after_half, Tuning.TENSION_MAX,
			"%s (settle %.2f) pins the line inside half a second, which is a reflex test rather than a judgement" % [
				row["name"], settle])


## A WORN-OUT FISH STOPS FIGHTING THE REEL, which is the reward the whole rhythm
## is for - and it is felt in the thumb rather than read off a number.
func test_wearing_a_fish_out_is_felt_in_the_reel(t: TestHarness) -> void:
	for row in Species.TABLE:
		var power := float(row["run_power"])
		var fresh := Tuning.crank_settle(power, 1.0)
		var spent := Tuning.crank_settle(power, 0.0)
		t.lt(spent, fresh + 0.0001,
			"%s fights the reel just as hard when it is spent" % row["name"])
		t.lt(spent, Tuning.DANGER,
			"%s still cannot be held flat once it is worn out, so the rhythm never pays off" % row["name"])

	# And the difference has to be big enough to feel. A tutorial fish barely
	# resists to begin with, so it is the deep ones that carry this.
	var deepest := 0.0
	for row in Species.TABLE:
		deepest = maxf(deepest, float(row["run_power"]))
	var gap := Tuning.crank_settle(deepest, 1.0) - Tuning.crank_settle(deepest, 0.0)
	t.gt(gap, 0.20,
		"wearing out the hardest fish in the lake changes the reel by only %.2f, which nobody would notice" % gap)


## THE SIXTH FIGHT'S FOUR PROMISES (F2.1), each a claim about the dial rather
## than about a number. Gideon: "a full progressive scale so you can let in or
## out slowly to match what the fish is doing."

## 1. The crank's settle point SCALES with the crank. Half speed is half the
## settle, which is what lets a fish that cannot be held flat out be worked at
## half - the whole reason the button became a slide.
func test_the_crank_settle_scales_with_the_crank(t: TestHarness) -> void:
	for row in Species.TABLE:
		var power := float(row["run_power"])
		var full := Tuning.crank_settle(power, 1.0, 1.0)
		var half := Tuning.crank_settle(power, 1.0, 0.5)
		t.approx(half, full * 0.5, 1e-6,
			"%s: half a crank settles at %.2f against %.2f flat out - the dial is not proportional" % [
				row["name"], half, full])
		t.approx(Tuning.crank_settle(power, 1.0, 0.0), 0.0, 1e-6,
			"%s: a held reel (no crank) still has a crank settle point" % row["name"])
	# And every fish in the lake can be worked SOMEWHERE on the dial: a crank speed
	# exists whose settle is under the danger line, even fresh.
	for row in Species.TABLE:
		var power := float(row["run_power"])
		var full := Tuning.crank_settle(power, 1.0, 1.0)
		var speed := clampf((Tuning.DANGER - 0.07) / maxf(0.0001, full), 0.0, 1.0)
		t.gt(speed, 0.15,
			"%s can only be worked at %.0f%% of the crank, which is a dial with one notch" % [
				row["name"], speed * 100.0])


## 2. A HELD line is a fighting line: the run loads it. A FREE spool is not.
## Driven through the real sim so the claim is about the fight, not about a
## formula the test could restate.
func test_holding_a_run_loads_the_line_and_giving_does_not(t: TestHarness) -> void:
	var held := _running_fish()
	var given := _running_fish()
	t.ok(held != null and given != null, "a running deep fish can be set up")
	if held == null or given == null:
		return
	held.set_reel(0.0)
	given.set_reel(-1.0)
	var step := 1.0 / 60.0
	for i in int(round(1.0 / step)):
		held.running = true
		given.running = true
		held.advance(step)
		given.advance(step)
	t.gt(held.tension, Tuning.SAFE_LO,
		"a held line during a run carries only %.2f - holding is not fighting" % held.tension)
	t.lt(given.tension, held.tension * 0.5,
		"a free spool during a run carries %.2f against %.2f held - giving line relieves nothing" % [
			given.tension, held.tension])


## 3. Giving line drops tension FASTER than holding does, and it COSTS ground.
## Both halves, because a safe answer that is free is not a decision.
func test_giving_line_relieves_faster_and_costs_ground(t: TestHarness) -> void:
	var held := _calm_fish()
	var given := _calm_fish()
	t.ok(held != null and given != null, "a calm deep fish can be set up")
	if held == null or given == null:
		return
	held.tension = 0.7
	given.tension = 0.7
	held.set_reel(0.0)
	given.set_reel(-1.0)
	var start: float = given.fish_distance
	var step := 1.0 / 60.0
	for i in int(round(0.5 / step)):
		held.running = false
		given.running = false
		held.tell = 0.0
		given.tell = 0.0
		held.advance(step)
		given.advance(step)
	t.lt(given.tension, held.tension,
		"giving line left %.2f on the line against %.2f held - the bottom of the slide relieves nothing" % [
			given.tension, held.tension])
	t.gt(given.fish_distance, start + 0.3,
		"half a second of full give paid out only %.2f m - giving line is free" % (given.fish_distance - start))
	t.approx(held.fish_distance, start, 1e-6, "a held line in calm water moved the fish")


## 4. Pressure tires the fish whenever the line CARRIES it, cranked or held.
## Only a free spool takes nothing out of the fish.
func test_pressure_tires_the_fish_on_a_held_line(t: TestHarness) -> void:
	var held := _calm_fish()
	var given := _calm_fish()
	t.ok(held != null and given != null, "a calm deep fish can be set up")
	if held == null or given == null:
		return
	held.set_reel(0.0)
	given.set_reel(-1.0)
	var step := 1.0 / 60.0
	for i in int(round(2.0 / step)):
		# Pin the tension so the ONLY difference is whether the line is held.
		held.tension = 0.7
		given.tension = 0.7
		held.running = false
		given.running = false
		held.tell = 0.0
		given.tell = 0.0
		held.advance(step)
		given.advance(step)
	t.lt(held.fish_stamina, 1.0 - 0.02,
		"two seconds of pressure on a held line tired the fish by only %.3f - holding is not fighting" % (1.0 - held.fish_stamina))
	t.gt(given.fish_stamina, held.fish_stamina,
		"a free spool tires the fish as much as a held line does")


## 5. The crank has inertia, in the sim: a thumb slammed to the top does not put
## the reel there in one frame, and it is most of the way there well inside a
## reaction time - weight, not lag.
func test_the_crank_follows_the_thumb_with_weight(t: TestHarness) -> void:
	var s := _calm_fish()
	t.ok(s != null, "a calm deep fish can be set up")
	if s == null:
		return
	s.set_reel(1.0)
	s.advance(1.0 / 60.0)
	t.gt(s.reel, 0.0, "the crank did not move on the frame the thumb did")
	t.lt(s.reel, 0.5, "the crank was at %.2f one frame after the thumb - it has no weight at all" % s.reel)
	var step := 1.0 / 60.0
	for i in int(round(0.3 / step)):
		s.running = false
		s.tell = 0.0
		s.advance(step)
	t.gt(s.reel, 0.9, "the crank is only at %.2f a third of a second after the thumb - that is lag, not weight" % s.reel)


## A deep fish, calm, set up directly - the water where the dial matters.
func _calm_fish() -> Sim:
	var s := Sim.new(1)
	var row := Species.by_id("trout")
	if row.is_empty():
		return null
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = str(row["id"])
	s.fish_weight = float(row["weight_lo"])
	s.fish_distance = Tuning.CAST_MAX * 0.5
	s.fish_stamina = 1.0
	s.tension = Tuning.SAFE_LO
	s.running = false
	s.tell = 0.0
	s.phase_time = 30.0
	s.state = Sim.FIGHTING
	return s


func _running_fish() -> Sim:
	var s := _calm_fish()
	if s == null:
		return null
	s.running = true
	s.phase_time = 5.0
	return s


## The warning has to be longer than a person's reaction, because this is a game
## about watching rather than reflexes. The previous fight had it at 0.34s
## against a ~0.30s reaction and the margin was invisible.
func test_the_warning_is_generous(t: TestHarness) -> void:
	t.gt(Tuning.TELL_TIME, 0.40, "the warning is shorter than a person's reaction time")
	t.lt(Tuning.TELL_TIME, 1.5, "the warning is so long the run is no longer a surprise")


## The nibble has to be winnable, losable, and READABLE.
##
## The last one is the whole point of it. A tease and a take are told apart by
## how deep and how long, so both differences have to be big enough to see at
## cast range - there is no HUD element to fall back on.
func test_a_tease_and_a_take_look_different(t: TestHarness) -> void:
	t.lt(Tuning.TEASE_DEPTH, 0.6,
		"a tease pulls the float almost as far under as a real take")
	t.gt(Tuning.TAKE_DEPTH - Tuning.TEASE_DEPTH, 0.35,
		"the two depths are too close to tell apart at cast range")
	for s in Species.TABLE:
		var window: float = s["take_window"]
		t.gt(window, Tuning.TEASE_TIME * 1.4,
			"%s's take lasts %.2fs against a %.2fs tease - they read the same" % [
				s["name"], window, Tuning.TEASE_TIME])
		# And it has to be long enough to react to at all. Under about a third of
		# a second is a reflex test rather than a judgement.
		t.gt(window, 0.30, "%s gives only %.2fs to strike in" % [s["name"], window])
		t.lt(window, 2.0, "%s holds the bait so long that timing does not matter" % s["name"])


func test_the_tease_sequence_is_a_real_wait(t: TestHarness) -> void:
	t.gt(float(Tuning.TEASE_MIN), 0.5, "a fish can take the bait with no teasing at all")
	t.gt(float(Tuning.TEASE_MAX), float(Tuning.TEASE_MIN),
		"every bite offers exactly the same number of teases")
	t.lt(float(Tuning.TEASE_MAX), 6.0, "a bite takes so many teases that it is a waiting game")
	t.gt(Tuning.TUG_GAP_MIN, 0.2, "the tugs come so fast they blur into one")
	t.gt(Tuning.TUG_GAP_MAX, Tuning.TUG_GAP_MIN, "the gap between tugs never varies")


func test_the_tease_count_stays_in_range(t: TestHarness) -> void:
	for s in Species.TABLE:
		for i in 40:
			var n := Species.tease_count(s, float(i) / 40.0)
			t.ok(n >= Tuning.TEASE_MIN, "%s can offer fewer teases than the floor" % s["name"])
			t.ok(n <= Tuning.TEASE_MAX, "%s can offer more teases than the ceiling" % s["name"])


## A tired fish runs less, which is what makes the end of a fight feel different
## from the start rather than merely shorter.
func test_a_tired_fish_runs_less(t: TestHarness) -> void:
	for s in Species.TABLE:
		var fresh := 0
		var spent := 0
		for i in 400:
			var u := float(i) / 400.0
			if Species.runs_next(s, u, 1.0):
				fresh += 1
			if Species.runs_next(s, u, 0.0):
				spent += 1
		t.gt(float(fresh), float(spent) - 0.5, "%s runs as much when spent as when fresh" % s["name"])


func test_phase_lengths_are_playable(t: TestHarness) -> void:
	for u in [0.0, 0.5, 1.0]:
		var calm := Species.calm_seconds(u)
		t.gt(calm, Tuning.TELL_TIME * 1.5, "a calm phase is barely longer than its own warning")
		t.lt(calm, 10.0, "the fish sits still long enough to be boring")
		var run := Species.run_seconds(u, 1.0)
		t.gt(run, 0.5, "a run is over before it can be reacted to")
		t.lt(run, 5.0, "a run takes back more than the fight can recover")
		t.lt(Species.run_seconds(u, 0.0), run + 0.0001, "runs get longer as the fish tires")

func test_every_species_is_reachable_and_sane(t: TestHarness) -> void:
	t.gt(float(Species.TABLE.size()), 0.0, "there is something to catch")
	for s in Species.TABLE:
		t.gt(s["weight_hi"], s["weight_lo"], "%s has a real weight range" % s["name"])
		t.gt(s["max_depth"], s["min_depth"], "%s has a real depth range" % s["name"])
		t.gt(s["stamina"], 0.0, "%s has stamina" % s["name"])
		t.gt(s["haul"], 0.0, "%s can be reeled in" % s["name"])
		t.gt(s["take_window"], 0.0, "%s never actually takes the bait" % s["name"])
		t.gt(s["teases"], 0.0, "%s never teases at all" % s["name"])
		t.gt(s["weight"], 0.0, "%s can actually be picked" % s["name"])
		t.gt(s["value"], -1.0, "%s has no price" % s["name"])
		# A fish that spends most of the fight running can never be reeled in, so
		# it is unlandable however well it is played.
		var busy: float = float(s["run_chance"])
		t.lt(busy, 0.75, "%s runs so often it can never be reeled in" % s["name"])


## EVERY SPECIES MUST BE CATCHABLE SOMEWHERE.
##
## The lure fishes at ONE depth - the shallower of the lake bed where you are and
## what your line will stand - so a row whose range never contains a reachable
## depth is unreachable everywhere. It is in the table, it is a blank page in the
## logbook, and no amount of play will ever fill it in.
##
## This has already caught a real one: the bluegill shipped with `max_depth` 2.4
## in 4 m of water - the commonest fish in the game, uncatchable, with nothing
## reporting a fault because every subsystem was working perfectly. The check now
## walks every spot at every line level, which is the real set of depths the game
## can produce.
func test_every_species_is_reachable_somewhere(t: TestHarness) -> void:
	var depths := World.all_reachable_depths()

	for s in Species.TABLE:
		var min_d: float = s["min_depth"]
		var max_d: float = s["max_depth"]
		var reachable := false
		for d in depths:
			if d >= min_d and d <= max_d:
				reachable = true
				break
		t.ok(reachable,
			"%s (%.0f-%.0fm) sits between the depths the game can actually fish" % [
				s["name"], min_d, max_d])


## And every OBJECT too, for the same reason - an object that can never be found
## is a story beat that never fires.
func test_every_object_is_reachable_somewhere(t: TestHarness) -> void:
	var depths := World.all_reachable_depths()

	for o in Objects.TABLE:
		var min_d: float = o["min"]
		var max_d: float = o["max"]
		var reachable := false
		for d in depths:
			if d >= min_d and d <= max_d:
				reachable = true
				break
		t.ok(reachable, "%s can never be found at any reachable depth" % o["name"])


## Every SPOT must have something in it, or a place on the map is an empty room.
func test_every_spot_holds_something_at_every_line(t: TestHarness) -> void:
	for spot in World.SPOTS:
		var reach := World.reachable_depth(spot["id"], Gear.LINE.size() - 1)
		var rows := Species.at_depth(reach)
		t.gt(float(rows.size()), 0.0,
			"%s has nothing living at %.0fm" % [spot["name"], reach])


func test_pick_is_stable_and_covers_the_table(t: TestHarness) -> void:
	var seen := {}
	for i in 200:
		var u := float(i) / 200.0
		var s := Species.pick(Tuning.BED_DEPTH, u)
		t.ok(not s.is_empty(), "pick always returns a row at the bed")
		seen[s["id"]] = true
	var expected := Species.at_depth(Tuning.BED_DEPTH).size()
	t.eq(seen.size(), expected, "every species at that depth can be picked")


func test_pick_is_weighted_toward_the_common_fish(t: TestHarness) -> void:
	var counts := {}
	for i in 1000:
		var s := Species.pick(Tuning.BED_DEPTH, float(i) / 1000.0)
		counts[s["id"]] = counts.get(s["id"], 0) + 1
	# Bluegill carries the highest weight of anything at the bed, so it must be
	# the most common. If a rebalance inverts this the early game changes
	# character with nothing else to say so.
	t.gt(float(counts.get("bluegill", 0)), float(counts.get("bass", 0)),
		"the common fish is more common than the prize")


## Bait is the targeting system, so it has to actually move the odds - and it
## must never reduce a species to zero, because a bait that hard-gates is a
## lockout wearing a choice's clothes.
func test_bait_shifts_the_odds_without_locking_anything_out(t: TestHarness) -> void:
	var worms := 0
	var minnows := 0
	for i in 600:
		var u := float(i) / 600.0
		if Species.pick(3.0, u, "", "worm")["id"] == "bass":
			worms += 1
		if Species.pick(3.0, u, "", "minnow")["id"] == "bass":
			minnows += 1
	t.gt(float(minnows), float(worms), "minnows do not bring up more bass than worms")
	t.gt(float(worms), 0.0, "worms lock the bass out entirely")


## Time of day has to gate something, or the clock is decoration.
func test_some_fish_only_bite_at_certain_hours(t: TestHarness) -> void:
	var gated := 0
	for s in Species.TABLE:
		if s.has("hour"):
			gated += 1
			var hours: Array = s["hour"]
			t.gt(float(hours.size()), 0.0, "%s has an empty hour list" % s["name"])
	t.gt(float(gated), 0.0, "nothing in the lake cares what time it is")

	# And the gate has to bite: a night fish must be absent by day.
	var day_rows := Species.at_depth(12.0, "morning")
	var night_rows := Species.at_depth(12.0, "night")
	t.gt(float(night_rows.size()), float(day_rows.size()),
		"the same fish are available at midnight as at noon")


## THE RESISTANCE LADDER IS THE DEPTH LADDER, and it comes free.
##
## `run_power` already has to climb with depth (`test_runs_get_stronger_with_depth`)
## and `resist` is built on it, so the reel gets harder to hold the deeper you fish
## without one extra number to keep in step. This asserts the thing that makes the
## water feel different: the first water can be held flat and the deep cannot.
func test_the_reel_gets_harder_to_hold_with_depth(t: TestHarness) -> void:
	var settles := {}
	for band in World.BANDS:
		var total := 0.0
		var n := 0
		for row in Species.TABLE:
			if row["band"] != band["id"]:
				continue
			total += Tuning.crank_settle(float(row["run_power"]), 1.0)
			n += 1
		if n > 0:
			settles[band["id"]] = total / float(n)

	t.lt(float(settles["reeds"]), Tuning.DANGER - 0.10,
		"the first water cannot be learned on: holding the reel there is already near the red")
	t.gt(float(settles["town"]), Tuning.DANGER,
		"Old Town can be fished by holding the button down, so nothing is asked of the player")
	t.gt(float(settles["quarry"]), float(settles["road"]),
		"the Quarry does not fight the reel harder than the Drowned Road")


## THE TUTORIAL HAS TO TEACH THE RUN.
##
## The reeds are where a player learns what the needle means, and they can only
## learn it from a fish that runs. This shipped broken once in the other
## direction: run frequency and run strength were the same number, so making the
## first water winnable made its fish stop running, and a player could finish the
## whole tutorial without ever seeing the mechanic the fight is built on.
##
## The pair of assertions is the point - OFTEN and GENTLY, not one or the other.
func test_the_first_water_teaches_the_run(t: TestHarness) -> void:
	for row in Species.TABLE:
		if row["band"] != "reeds":
			continue
		t.gt(float(row["run_chance"]), 0.30,
			"%s hardly ever runs, so the tutorial does not teach the run" % row["name"])
		t.lt(float(row["run_power"]), 0.80,
			"%s runs hard enough to punish a player still learning what a run is" % row["name"])


## Every band's runs are stronger than the one above it. The frequency is free to
## go up or down - what has to climb with depth is the STAKES.
func test_runs_get_stronger_with_depth(t: TestHarness) -> void:
	var last := 0.0
	var last_name := ""
	for band in World.BANDS:
		var total := 0.0
		var n := 0
		for row in Species.TABLE:
			if row["band"] == band["id"]:
				total += float(row["run_power"])
				n += 1
		if n == 0:
			continue
		var mean := total / float(n)
		if last_name != "":
			t.gt(mean, last,
				"runs in %s (%.2f) are no stronger than in %s (%.2f)" % [
					band["name"], mean, last_name, last])
		last = mean
		last_name = band["name"]


## THE LURE CAN NEVER HANG IN OPEN WATER OVER THE DEEP.
##
## `depth_for_cast` clamps the lure to the line's length, and clamping ALONE was
## wrong at the far end: six pound mono at The Spring returned four metres, in a
## hundred and fifty of water, and `Species.at_depth(4.0)` duly offered bluegill.
## A player with the starting line and a motor could fish the reeds at the bottom
## of the quarry.
##
## Two rules close it, and both are asserted because either alone leaves the hole
## open: the depth never comes back shallower than the spot's own shallowest
## water, and a spot whose shallowest water the line cannot reach cannot be
## travelled to at all.
func test_the_lure_never_fishes_above_the_water_it_is_in(t: TestHarness) -> void:
	for spot in World.SPOTS:
		var shallow: float = spot["shallow"]
		for level in Gear.LINE.size():
			for i in 9:
				var d := World.depth_for_cast(spot["id"], level, float(i) / 8.0)
				t.gt(d, shallow - 0.001,
					"%s with %s fishes at %.1f m, above its own %.1f m shallows" % [
						spot["name"], Gear.line_name(level), d, shallow])


func test_you_cannot_travel_where_your_line_reaches_nothing(t: TestHarness) -> void:
	for spot in World.SPOTS:
		var id: String = spot["id"]
		for level in Gear.LINE.size():
			var s := Sim.new(1)
			s.econ.has_motor = true
			s.econ.line = level
			var went := s.travel_to(id)
			var reaches := World.line_reaches_water(id, level)
			t.eq(went, reaches,
				"%s with %s: travel says %s but the line reaching the water says %s" % [
					spot["name"], Gear.line_name(level), went, reaches])
			if not reaches:
				t.ok(s.spot_blocked(id) != "",
					"%s is unfishable with %s and the map gives no reason" % [
						spot["name"], Gear.line_name(level)])


## And the consequence worth stating on its own: WHEREVER YOU CAN LEGALLY BE,
## every fish on offer belongs to water that deep. This is the assertion that
## would have failed loudest on the bug above.
func test_no_spot_ever_offers_a_fish_from_the_wrong_water(t: TestHarness) -> void:
	for spot in World.SPOTS:
		var id: String = spot["id"]
		for level in Gear.LINE.size():
			if not World.line_reaches_water(id, level):
				continue
			for i in 9:
				var d := World.depth_for_cast(id, level, float(i) / 8.0)
				# THE claim, and the one the old code broke: the depth fished at a
				# spot is always inside that spot's own water. Asserting instead
				# that each species suits the DEPTH would be tautological - the
				# depth is the only thing `at_depth` is given, so it can never
				# disagree with itself. The bug was that the depth was wrong.
				t.gt(d, float(spot["shallow"]) - 0.001,
					"%s with %s fishes %.1f m, shallower than its own %.1f m shallows" % [
						spot["name"], Gear.line_name(level), d, float(spot["shallow"])])
				t.lt(d, float(spot["bed"]) + 0.001,
					"%s with %s fishes %.1f m, below its own %.1f m bed" % [
						spot["name"], Gear.line_name(level), d, float(spot["bed"])])


## P6: THE CHART READS YOUR OWN BOOK BACK, and never more than that.
##
## "The same spot at a different hour is a reason to go, not just something that
## happens to you." Several species only bite at dusk or at night and always have,
## and there was no way to find that out except by accident and memory.
##
## The claim worth guarding is the RESTRAINT. It would be trivial - and wrong - to
## read `Species.TABLE` and print "walleye here at dusk"; this whole game is built
## on the player working the lake out, and that would be the strategy guide in the
## box. So: nothing is said about an hour that has not been fished, and one fish
## is not a pattern.
func test_the_chart_only_knows_what_you_have_caught(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.eq(s.caught_at.size(), 0, "a new keeper's book already has opinions in it")

	# One fish at an hour says nothing. A single catch is an anecdote and the
	# chart is not allowed to draw a line through one point.
	s.caught_at = {"reed_bay": {"dusk": 1}}
	t.eq(s.best_hour_at("reed_bay"), "", "one fish at dusk was enough to call it good at dusk")

	# Two at the same hour is the least that can be a finding.
	s.caught_at = {"reed_bay": {"dusk": 2}}
	t.eq(s.best_hour_at("reed_bay"), "dusk", "two fish at dusk is not enough to say so")

	# A tie is not a finding either.
	s.caught_at = {"reed_bay": {"dusk": 3, "dawn": 3}}
	t.eq(s.best_hour_at("reed_bay"), "", "the chart picked a favourite out of a dead heat")

	# And it never speaks about water you have not fished.
	t.eq(s.best_hour_at("quarry"), "", "the chart has an opinion about water you have never been to")

	# IT IS WRITTEN BY LANDING FISH, not by being told. Driven through the real
	# rules, so this fails if `_land_fish` ever stops keeping the record.
	var played := Sim.new(4)
	played.spot = "reed_bay"
	played.hour = "dusk"
	played.fish_id = "bluegill"
	played.fish_weight = 0.2
	played._land_fish()
	played.state = Sim.IDLE
	played.fish_id = "bluegill"
	played.fish_weight = 0.3
	played._land_fish()
	t.eq(played.best_hour_at("reed_bay"), "dusk",
		"two fish landed at dusk did not get written down")



## G4: DAYLIGHT IS A RESOURCE, and until it was one the fight had nothing to
## trade against.
##
## `Tuning.TIRE_RATE`'s own note says waiting a fish out "costs the clock, which
## is the one resource this game says is scarce". That sentence was false: the
## hour only ever changed when the player asked it to, so patience was free and
## the fifth fight's central decision was a decision against nothing.
func test_the_light_goes_while_you_fish(t: TestHarness) -> void:
	var s := Sim.new(1)
	var started := s.hour
	t.gt(s.hour_left, 0.0, "a new day begins with no light in it")

	# IT RUNS DOWN IN EVERY STATE, including a fight. That is the whole point:
	# a fish that takes two minutes to land costs two minutes of light.
	s.state = Sim.FIGHTING
	s.advance(30.0)
	t.lt(s.hour_left, Tuning.HOUR_SECONDS,
		"half a minute of fighting cost no daylight at all")

	# AND IT TURNS THE HOUR ON ITS OWN, without being asked.
	s.advance(Tuning.HOUR_SECONDS)
	t.ok(s.hour != started, "the light ran out and the hour did not turn")
	t.gt(s.hour_left, 0.0, "the new hour started with no light in it")

	# An hour has to hold several real attempts at a fish, or every cast is
	# rushed; and it has to be short enough that a session has a shape.
	t.gt(Tuning.HOUR_SECONDS, 180.0,
		"an hour is %.0f s, which is barely two fish" % Tuning.HOUR_SECONDS)
	t.lt(Tuning.HOUR_SECONDS, 900.0,
		"an hour is %.0f s, which is long enough that the light never matters" % Tuning.HOUR_SECONDS)


## AND THE LAMP BUYS THE DARK.
##
## It cost 400 and changed nothing - "fishing after dark is currently identical to
## fishing at noon" had been on the open-issues list since the day it went in.
func test_the_lamp_is_worth_buying(t: TestHarness) -> void:
	t.gt(Tuning.LAMP_NIGHT_BITE, Tuning.DARK_NIGHT_BITE * 2.0,
		"a lamp barely beats no lamp, so there is no reason to own one")
	t.lt(Tuning.LAMP_NIGHT_BITE, 1.0,
		"a lamp makes the night as good as the day, so nothing is lost by fishing it")
	t.gt(Tuning.DARK_NIGHT_BITE, 0.0,
		"the night without a lamp is dead water rather than hard water")

	# Driven through the real draw, so this fails if `_arm_bite` stops asking.
	var lit := Sim.new(3)
	lit.hour = "night"
	lit.econ.has_lamp = true
	lit._arm_bite()
	var dark := Sim.new(3)
	dark.hour = "night"
	dark.econ.has_lamp = false
	dark._arm_bite()
	t.lt(lit.bite_in, dark.bite_in,
		"the same night with a lamp is no quicker than without one")



## THE LOGBOOK IS A RECORD BOOK, AND A SMALL FISH STILL GETS A PAGE.
##
## `sim.logged` maps a species to the HEAVIEST one landed, not to a count. The
## logbook read that as a tally and tested it with `int(weight) > 0`, which is
## false for every fish under a kilo - so a bluegill, the first thing anyone
## catches, would never have appeared on its own page for the whole game.
##
## Asserted here rather than in the menu because the semantics belong to the sim:
## anything reading `logged` has to know it holds kilos.
func test_the_logbook_records_a_fish_lighter_than_a_kilo(t: TestHarness) -> void:
	var light := ""
	var lightest := 1000.0
	for row in Species.TABLE:
		if float(row["weight_lo"]) < lightest:
			lightest = float(row["weight_lo"])
			light = row["id"]
	t.lt(lightest, 1.0, "no species in the game weighs under a kilo, so this proves nothing")

	var s := Sim.new(1)
	s.fish_id = light
	s.fish_weight = lightest
	s._land_fish()
	t.ok(s.logged.has(light),
		"%s was landed and never reached the logbook" % Species.by_id(light)["name"])
	t.gt(float(s.logged[light]), 0.0, "the logbook recorded a weight of nothing")
	t.eq(int(float(s.logged[light])), 0,
		"this species is no longer under a kilo, so the truncation bug cannot be caught here")

	# And the record is the BEST, not the last.
	s.fish_weight = lightest * 3.0
	s._land_fish()
	t.gt(float(s.logged[light]), lightest * 2.0, "a heavier one did not beat the record")
	s.fish_weight = lightest
	s._land_fish()
	t.gt(float(s.logged[light]), lightest * 2.0, "a smaller one wiped out the record")


## Every species sits inside the band it claims, as a fact about the TABLE.
##
## The first attempt at this compared a species' band against `World.band_at` of
## the depth it was offered at, and every reed fish failed at exactly 4.0 m -
## because `band_at` is half-open (`min <= d < max`) while `Species.at_depth` is
## inclusive at both ends, and Reed Bay's bed is exactly the reeds' 4.0 m limit.
## Neither convention is wrong; comparing them at a boundary is. **A boundary two
## functions disagree about is not an edge case here - it is where the starting
## spot's full-charge cast lands every single time.**
##
## So the claim is made where it is unambiguous: statically, over the table.
func test_every_species_sits_inside_the_band_it_claims(t: TestHarness) -> void:
	for row in Species.TABLE:
		var band := {}
		for b in World.BANDS:
			if b["id"] == row["band"]:
				band = b
		t.ok(not band.is_empty(), "%s claims band '%s', which does not exist" % [
			row["name"], row["band"]])
		if band.is_empty():
			continue
		# OVERLAP, not containment. Species range ACROSS band lines on purpose - a
		# largemouth runs a metre into the channel and the Old Fish starts ten
		# metres above the spring - because hard edges would make the lake read as
		# six rooms rather than one body of water that gets older downwards. What
		# must be true is only that the band a fish is FILED under is water it can
		# actually be caught in, or the logbook lists it on a page you can never
		# fill.
		var lo := maxf(float(row["min_depth"]), float(band["min_depth"]))
		var hi := minf(float(row["max_depth"]), float(band["max_depth"]))
		t.gt(hi, lo - 0.001,
			"%s lives at %.1f-%.1f m but is filed under %s, which is %.1f-%.1f m - they do not meet" % [
				row["name"], float(row["min_depth"]), float(row["max_depth"]), band["name"],
				float(band["min_depth"]), float(band["max_depth"])])


## THE LOOK IS A PURE FUNCTION, SO THE LOOK IS TESTABLE.
##
## `Mood.at(hour, weather, dread)` is the whole appearance of the lake, and the
## reason it is a function rather than thirty assignments inside the renderer is
## precisely this block. "Night is darker than noon in every weather" is a claim
## about the game; made in the renderer it could only ever be checked by taking
## twenty-five screenshots and squinting.
func test_night_is_darker_than_the_day_in_every_weather(t: TestHarness) -> void:
	for w in Mood.WEATHERS:
		var night := Mood.brightness(Mood.at("night", w, 0.0))
		for hour in ["dawn", "morning", "afternoon", "dusk"]:
			t.lt(night, Mood.brightness(Mood.at(hour, w, 0.0)),
				"night is no darker than %s in %s weather" % [hour, w])


func test_worse_weather_is_always_darker(t: TestHarness) -> void:
	# In the order they are written, which is also the order they get worse.
	var order := ["clear", "overcast", "rain", "storm"]
	for hour in Mood.HOURS:
		for i in order.size() - 1:
			var a := Mood.brightness(Mood.at(hour, order[i], 0.0))
			var b := Mood.brightness(Mood.at(hour, order[i + 1], 0.0))
			t.lt(b, a + 0.0001,
				"%s at %s is no darker than %s (%.3f against %.3f)" % [
					order[i + 1], hour, order[i], b, a])


## NOTHING ABOUT GOING DEEPER MAKES ANYTHING BRIGHTER OR MORE COLOURFUL.
##
## The single claim the whole visual arc rests on. It is easy to break by
## accident - one `lerp` toward a colour lighter than where it started - and
## impossible to notice, because no screenshot is ever compared with the one from
## an hour of play earlier.
func test_the_lake_only_ever_gets_darker_and_greyer(t: TestHarness) -> void:
	for hour in Mood.HOURS:
		for w in Mood.WEATHERS:
			var last := 999.0
			var last_sat := 999.0
			var last_fog := -1.0
			for i in 11:
				var look := Mood.at(hour, w, float(i) / 10.0)
				var bright := Mood.brightness(look)
				t.lt(bright, last + 0.0001,
					"%s/%s gets BRIGHTER at dread %.1f" % [hour, w, float(i) / 10.0])
				last = bright

				var c: Color = look["sky_horizon"]
				var sat: float = c.s
				t.lt(sat, last_sat + 0.002,
					"%s/%s gets more colourful at dread %.1f" % [hour, w, float(i) / 10.0])
				last_sat = sat

				var fog: float = look["fog_density"]
				t.gt(fog, last_fog - 0.0000001,
					"%s/%s loses fog going deeper" % [hour, w])
				last_fog = fog


## Every combination has to produce something a renderer can actually use. A
## negative light energy or a fog density of two is not a look, it is a bug that
## only shows on the one hour and weather nobody screenshotted.
func test_every_hour_and_weather_produces_a_usable_picture(t: TestHarness) -> void:
	for hour in Mood.HOURS:
		for w in Mood.WEATHERS:
			for i in 3:
				var look := Mood.at(hour, w, float(i) / 2.0)
				var where := "%s/%s/%.1f" % [hour, w, float(i) / 2.0]
				t.gt(float(look["sun_energy"]), 0.05,
					"%s has no sun at all, so the water throws nothing back" % where)
				t.lt(float(look["sun_energy"]), 6.0, "%s is blown out" % where)
				t.gt(float(look["ambient"]), 0.05, "%s has no ambient light" % where)
				t.gt(float(look["fog_density"]), 0.0, "%s has no fog at all" % where)
				t.lt(float(look["fog_density"]), Mood.MAX_FOG + 0.0001,
					"%s is solid fog - the player cannot see the float" % where)
				for key in ["sky_top", "sky_horizon", "fog_color", "water_shallow",
						"water_deep", "water_sky", "sun_color"]:
					var c: Color = look[key]
					t.gt(c.r + c.g + c.b, -0.001, "%s has a negative %s" % [where, key])
					t.lt(maxf(c.r, maxf(c.g, c.b)), 1.001, "%s blows out %s" % [where, key])


# --- the save -------------------------------------------------------------

## A PLAYED SESSION SURVIVES THE ROUND TRIP.
##
## Everything a player would be upset to lose: the money, the ladders, the
## logbook, the box, the clock and where the boat is.
func test_a_played_session_comes_back_exactly(t: TestHarness) -> void:
	var a := Sim.new(7)
	a.econ.money = 2000
	a.econ.line = 3
	a.econ.rod = 2
	a.econ.reel = 1
	a.econ.livewell = 1
	a.econ.has_motor = true
	a.econ.has_sounder = true
	a.econ.buy_bait("minnow")
	a.econ.bait = "minnow"
	# Set to the exact figure AFTER the shopping, because `buy_bait` spends - and
	# it also REFUSES when the purse is empty, so buying before funding left the
	# session with no minnows and the save correctly falling back to worms. Two
	# rounds of this test failing on its own setup rather than on the save.
	a.econ.money = 1234
	a.econ.keep("bluegill", 0.22, false)
	a.econ.keep("perch", 0.41, false)
	a.logged["bluegill"] = 0.31
	a.logged["carp"] = 8.4
	a.found["boot"] = true
	a.found["plate"] = true
	a.day = 5
	a.hour = "dusk"
	a.weather = "fog"
	a.spot = "road"
	a.caught = 19
	a.lost_count = 6
	a.casts = 41
	a.total_weight = 55.25

	var b := Sim.new(1)
	t.ok(Save.apply(b, Save.to_dict(a)), "the save did not load at all")

	t.eq(b.econ.money, 1234, "the money did not come back")
	t.eq(b.econ.line, 3, "the line did not come back")
	t.eq(b.econ.rod, 2, "the rod did not come back")
	t.eq(b.econ.reel, 1, "the reel did not come back")
	t.eq(b.econ.livewell, 1, "the livewell did not come back")
	t.ok(b.econ.has_motor, "the motor did not come back")
	t.ok(b.econ.has_sounder, "the sounder did not come back")
	t.ok(not b.econ.has_lamp, "a lamp appeared that was never bought")
	t.eq(b.econ.bait, "minnow", "the bait on the hook did not come back")
	t.eq(b.econ.held.size(), 2, "the livewell did not come back")
	t.eq(b.day, 5, "the day did not come back")
	t.eq(b.hour, "dusk", "the hour did not come back")
	t.eq(b.weather, "fog", "the weather did not come back")
	t.eq(b.spot, "road", "the boat came back somewhere else")
	t.eq(b.caught, 19, "the tally did not come back")
	t.eq(b.logged.size(), 2, "the logbook did not come back")
	t.eq(b.found.size(), 2, "what came off the bottom did not come back")
	# The records are WEIGHTS. Truncating them to counts is the bug that kept
	# every sub-kilo fish off its own page; a save that rounds them re-creates it.
	t.gt(float(b.logged["bluegill"]), 0.30, "the record weight was rounded away")


## THE CAST IS NOT SAVED, AND THAT IS THE RULE.
##
## Quitting mid-fight loses the fish. Saving one would mean restoring a state
## machine mid-transition, and every bug in that only appears to players who quit
## at exactly the wrong moment - which is to say a bug nobody can reproduce.
func test_a_fish_on_the_line_is_not_saved(t: TestHarness) -> void:
	var a := Sim.new(3)
	a.state = Sim.FIGHTING
	a.fish_id = "pike"
	a.fish_weight = 4.5
	a.tension = 0.61
	a.cast_distance = 18.0

	var b := Sim.new(1)
	Save.apply(b, Save.to_dict(a))
	t.eq(b.state, Sim.IDLE, "the game came back mid-fight")
	t.eq(b.fish_id, "", "a fish came back on the line")
	t.eq(b.cast_distance, 0.0, "the line came back out")


## NOTHING IN A BROKEN SAVE MAY THROW.
##
## A save is data from a build that no longer exists. A boot that hard-fails on
## one is the worst bug a game can ship - the player loses everything AND cannot
## get back in - so every one of these has to land on a playable boat.
func test_no_save_however_broken_can_stop_the_game_booting(t: TestHarness) -> void:
	var broken := [
		{},                                              # not a save at all
		{"version": 1},                                  # a save of nothing
		{"version": 99, "money": 10},                    # from the future
		{"version": 1, "money": -500, "line": 99, "rod": -3},
		{"version": 1, "logged": {"a_fish_that_never_existed": 3.0}},
		{"version": 1, "found": ["nothing_by_this_name"]},
		{"version": 1, "held": ["not even a dictionary", {"id": "ghost"}]},
		{"version": 1, "hour": "half past four", "weather": "raining frogs"},
		{"version": 1, "bait": "gold", "lures": ["worm", "nonsense"]},
		{"version": 1, "money": "lots", "day": "tuesday", "caught": []},
		# The one that matters most: somewhere the loaded gear cannot fish.
		{"version": 1, "spot": "spring", "line": 0},
		{"version": 1, "spot": "quarry", "line": 5},     # deep water, no motor
		{"version": 1, "spot": "a place that is not on the lake"},
	]
	for data in broken:
		var s := Sim.new(1)
		Save.apply(s, data)
		t.ok(s.spot != "", "a broken save left the boat nowhere: %s" % data)
		t.ok(World.line_reaches_water(s.spot, s.econ.line),
			"a broken save left the boat where its line cannot fish: %s" % data)
		t.ok(not bool(World.spot_by_id(s.spot)["needs_motor"]) or s.econ.has_motor,
			"a broken save left the boat off the bay with no motor: %s" % data)
		t.gt(float(s.econ.money), -0.001, "a broken save left the player in debt: %s" % data)
		t.lt(float(s.econ.line), float(Gear.LINE.size()), "a broken save bought line that does not exist")
		t.ok(s.hour in World.HOURS, "a broken save left the clock at '%s'" % s.hour)
		# And the boat has to actually WORK afterwards, not merely exist.
		s.hold_cast()
		s.advance(0.1)
		s.release_cast()
		for i in 600:
			s.advance(1.0 / 60.0)
		t.ok(s.state != Sim.CHARGING, "the game will not cast after loading: %s" % data)


## A save may never put more in the box than the box holds - including one
## written by a build whose livewell was bigger than this one's.
func test_a_save_cannot_overfill_the_livewell(t: TestHarness) -> void:
	var held := []
	for i in 40:
		held.append({"id": "carp", "weight": 6.0, "wrong": false})
	var s := Sim.new(1)
	Save.apply(s, {"version": 1, "livewell": 0, "held": held})
	t.lt(s.econ.load_kg(), s.econ.capacity() + 0.001,
		"a save loaded %.1f kg into a %.1f kg livewell" % [s.econ.load_kg(), s.econ.capacity()])
	t.gt(float(s.econ.held.size()), 0.0, "the whole livewell was thrown away")


# --- the offering gate ------------------------------------------------------

## MONEY CANNOT BUY THE BOTTOM.
##
## The pillar the whole economy hangs off, and it was written in three design
## documents and implemented nowhere - worms worked perfectly well at a hundred
## and forty metres. The test suite did not catch it because nothing in it ever
## fished deep water with a named bait, which is the same failure one level up.
func test_ordinary_bait_catches_nothing_in_the_deep(t: TestHarness) -> void:
	for id in ["worm", "corn", "minnow", "cut", "spoon", "glow"]:
		for depth in [80.0, 110.0, 140.0, 152.0]:
			var any := 0.0
			for row in Species.at_depth(depth, "morning"):
				any += Gear.bait_weight(id, row["id"], depth)
			t.eq(any, 0.0,
				"%s still catches things at %.0f m - the deep is not gated" % [id, depth])

	# And the offering does, or the gate is a wall.
	for depth in [80.0, 110.0, 140.0]:
		var reachable := 0.0
		for row in Species.at_depth(depth, "morning"):
			reachable += Gear.bait_weight("offering", row["id"], depth)
		t.gt(reachable, 0.0, "an offering catches nothing at %.0f m either" % depth)


## THE GATE HAS TO BE OPENABLE, and openable BEFORE it is met.
##
## At least one offering must live in water an ordinary bait can already reach,
## or the player arrives at eighty metres holding the wrong thing with no way to
## ever hold the right one.
func test_an_offering_can_be_found_before_it_is_needed(t: TestHarness) -> void:
	var shallowest := 999.0
	for o in Objects.offerings():
		shallowest = minf(shallowest, float(o["min"]))
	t.lt(shallowest, Gear.OFFERING_DEPTH,
		"every offering is below %.0f m, so the only way to get one is to already be past the gate"
			% Gear.OFFERING_DEPTH)


## FINDING ONE GIVES YOU ONE. It is the only bait in the game that cannot be
## bought, so hooking it has to be what puts it in the box.
func test_hooking_an_offering_puts_it_in_the_bait_box(t: TestHarness) -> void:
	var s := Sim.new(1)
	var before := int(s.econ.bait_left.get("offering", 0))
	var found := false
	# Fish the water an offering lives in until one comes up.
	for i in 4000:
		s.lure_depth = 34.0
		s._hook_object()
		if s.last_object != "" and Objects.by_id(s.last_object)["kind"] == Objects.OFFERING:
			found = true
			break
	t.ok(found, "no offering came up in four thousand objects at 34 m")
	t.gt(float(int(s.econ.bait_left.get("offering", 0))), float(before),
		"an offering was found and never reached the bait box")
	t.ok(s.econ.has_bait("offering"), "the offering is in the box but cannot be fished with")


## AND THE DEEP IS NEVER A DEAD END.
##
## Fishing eighty metres with worms must still produce SOMETHING. A player who
## waits and gets nothing concludes the game is broken; a player who keeps
## pulling up pieces of a drowned town concludes, correctly, that this water
## wants something else.
func test_the_deep_still_gives_up_objects_to_the_wrong_bait(t: TestHarness) -> void:
	var s := Sim.new(3)
	s.econ.line = 4
	s.econ.has_motor = true
	s.econ.bait = "worm"
	t.ok(s.travel_to("quarry"), "could not reach the quarry to test it")
	s.cast_charge = 1.0
	s.lure_depth = s.fishing_depth()
	t.gt(s.lure_depth, Gear.OFFERING_DEPTH - 0.01, "the quarry is not actually deep water")

	var objects := 0
	for i in 240:
		s.state = Sim.WAITING
		s.state_time = 0.0
		s.bite_in = 0.0
		s.last_object = ""
		for j in 900:
			s.advance(1.0 / 60.0)
			if s.last_object != "":
				objects += 1
				break
			if s.state == Sim.NIBBLING or s.state == Sim.FIGHTING:
				break
		if objects > 30:
			break
	t.gt(float(objects), 20.0,
		"only %d objects came up in the quarry on worms - the deep is a dead end" % objects)


# --- the keeper's logbook ---------------------------------------------------

## EVERY PAGE CAN BE REACHED.
##
## The book is keyed to the deepest cast ever made, so an entry placed below the
## deepest water in the game is a page that exists and can never be read. The
## intro promises the player that somebody has written in this book before them;
## a promise the game cannot keep is worse than one it never made.
func test_every_page_of_the_book_can_be_reached(t: TestHarness) -> void:
	var deepest := 0.0
	for d in World.all_reachable_depths(24):
		deepest = maxf(deepest, d)
	for e in Keepers.ENTRIES:
		t.lt(float(e["at"]), deepest + 0.001,
			"%s's entry at %.0f m is below the deepest water in the game (%.0f m)" % [
				e["hand"], float(e["at"]), deepest])
		t.ok(str(e["text"]).length() > 40, "%s wrote almost nothing" % e["hand"])


## THE BOOK OPENS FROM THE FIRST CAST, and never all at once.
##
## The first entry has to be inside the water a brand new player can reach, or
## the promise the intro just made goes unhonoured for an hour. And the last has
## to be deep, or there is nothing left to find.
func test_the_book_opens_early_and_finishes_late(t: TestHarness) -> void:
	var first := 9999.0
	var last := 0.0
	for e in Keepers.ENTRIES:
		first = minf(first, float(e["at"]))
		last = maxf(last, float(e["at"]))
	t.lt(first, 4.0, "the first page needs %.0f m - a new player cannot open the book" % first)
	t.gt(last, 100.0, "the whole book is readable from shallow water")

	# And it arrives in pieces rather than in one lump.
	var seen := 0
	var steps := 0
	for i in 15:
		var depth := float(i) * 10.0
		var n := Keepers.unlocked(depth).size()
		if n > seen:
			steps += 1
			seen = n
	t.gt(float(steps), 5.0, "the book unlocks in only %d jumps - it is a wall, not a book" % steps)


## FIVE HANDS, AND THE LAST IS YOURS.
func test_the_book_is_in_five_hands(t: TestHarness) -> void:
	t.eq(Keepers.total_hands(), 5, "the book is not in five hands")
	t.eq(Keepers.hands_met(0.0), 1, "a player who has never cast is not the only hand yet")
	var deepest := 0.0
	for d in World.all_reachable_depths(24):
		deepest = maxf(deepest, d)
	t.eq(Keepers.hands_met(deepest), 5,
		"fishing the deepest water in the game does not meet all five keepers")

	# TWO claims, not one, and the first version conflated them into a wrong test.
	#
	# WITHIN a hand the years run FORWARD, because a person writes across their
	# own years. BETWEEN hands they run BACKWARD, because deeper is older. Ruth
	# writes 1994 to 1996 and then Peter starts in 1958.
	var hand := ""
	var last_in_hand := 0
	var last_hand_start := 99999
	for e in Keepers.ENTRIES:
		var who: String = e["hand"]
		var year := int(e["year"])
		if who != hand:
			t.lt(float(year), float(last_hand_start),
				"%s starts in %d, which is not older than the hand before them" % [who, year])
			hand = who
			last_hand_start = year
		else:
			t.gt(float(year), float(last_in_hand) - 0.001,
				"%s writes backwards through their own tenure" % who)
		last_in_hand = year


## THE DEEPEST CAST IS REMEMBERED, and never falls.
func test_the_deepest_cast_is_a_high_water_mark(t: TestHarness) -> void:
	var s := Sim.new(1)
	s.econ.line = 3
	s.econ.has_motor = true
	s.travel_to("steeple")
	t.eq(s.deepest_ever, 0.0, "a fresh boat has already been somewhere")

	s.cast_charge = 1.0
	s.state = Sim.SINKING
	for i in 900:
		s.advance(1.0 / 60.0)
	var deep := s.deepest_ever
	t.gt(deep, 40.0, "a full cast at the steeple was not recorded as deep water")

	# Back to the shallows, and the book must not shut again.
	s.state = Sim.IDLE
	s.travel_to("reed_bay")
	s.cast_charge = 0.2
	s.state = Sim.SINKING
	for i in 600:
		s.advance(1.0 / 60.0)
	t.eq(s.deepest_ever, deep, "going back to the shallows took pages out of the book")
