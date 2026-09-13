extends SceneTree

## WHY FISH ARE LOST, split by cause, because the two causes mean opposite things.
##
## A parted line is a decision the player made: they kept reeling into a run.
## An escape can be a decision too - refusing to take any risk while the fish
## takes ground - but it can also be arithmetic: if one maximum-length run moves
## the fish further than `ESCAPE_MARGIN`, the fish is gone and nothing the player
## did or could have done touched it. That second kind is a coin flip wearing a
## mechanic's clothes, and it is what this probe is here to count.
##
## The PERFECT column is the instrument. It plays the fight the way the design
## says to: reel every moment the water is calm, let go the instant the tell
## fires, never reel into a run. Anything that bot loses, a human cannot save.

const Policies := preload("res://test/policies.gd")


func _fight(id: String, seed_i: int, policy: String) -> String:
	var s := Sim.new(seed_i)
	var mem := {}
	var step := 1.0 / 60.0
	var row := Species.by_id(id)
	s.cast_distance = Tuning.CAST_MAX
	s.fish_id = id
	s.fish_weight = row["weight_lo"]
	s.fish_distance = Tuning.CAST_MAX
	s.fish_stamina = 1.0
	s.tension = Tuning.SAFE_LO
	s.running = false
	s.phase_time = 2.0
	s.state = Sim.FIGHTING
	s.state_time = 0.0
	# A DICTIONARY, NOT A LOCAL. GDScript lambdas capture by VALUE, so a lambda
	# assigning to a captured `var why` writes to its own copy and the caller sees
	# nothing. This probe's first run reported "no fish is ever lost anywhere in
	# the game", which was a fact about the closure and not about the game, and a
	# model change was half-built on it before a trace caught it.
	var out := {"why": ""}
	s.lost.connect(func(reason: String) -> void:
		out["why"] = "broke" if reason == Sim.BROKE else "escaped")
	for j in int(round(120.0 / step)):
		if s.state != Sim.FIGHTING:
			break
		# Every column is a committed policy now. The hand-written "perfect"
		# column that used to sit here reeled in calm water and let go at the
		# tell - which in the sixth fight is GIVER, and GIVER lives in
		# policies.gd where the golden can see it.
		Policies.act(policy, s, step, mem)
		s.advance(step)
	if s.state == Sim.HOLDING:
		return "landed"
	var why := String(out["why"])
	return why if why != "" else "ran out of clock"


func _init() -> void:
	var tries := 16
	var names := [Policies.MASHER, Policies.SLOWPOKE, Policies.GIVER, Policies.BLIND,
		Policies.ANGLER, Policies.HUMAN]
	var head := "%-18s" % ""
	for n in names:
		head += "  %-26s" % n
	print(head)
	for band in World.BANDS:
		var line := "%-18s" % band["name"]
		for n in names:
			var tally := {}
			for row in Species.TABLE:
				if row["band"] != band["id"]:
					continue
				for i in tries:
					var r := _fight(row["id"], i + 1, n)
					tally[r] = int(tally.get(r, 0)) + 1
			line += "  %-26s" % _fmt(tally)
		print(line)
	quit()


func _fmt(d: Dictionary) -> String:
	var total := 0
	for k in d:
		total += int(d[k])
	var parts: Array[String] = []
	for k in ["landed", "escaped", "broke", "ran out of clock"]:
		if d.has(k):
			parts.append("%s %.0f%%" % [k.substr(0, 4), float(d[k]) / float(total) * 100.0])
	return ", ".join(parts)
