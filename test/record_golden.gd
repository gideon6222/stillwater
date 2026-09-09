extends SceneTree

## Records the golden, and WRITES IT IN ITSELF with `-- --write`.
##
## The paste used to be manual, and it went wrong the same way twice: the splice
## left a second `]` after the const, which GDScript does not fail fast on - the
## suite ran for sixteen minutes on the first occasion before anyone worked out
## it was a parse error and not a slow test. **A hand-edit that has broken twice
## is a tool that has not been written yet**, so this is that tool. It rewrites
## the const in place and verifies the file still has exactly one top-level
## closer before saving.
##
##   godot --headless --path . --script res://test/record_golden.gd -- write
##
## It exists as a committed script rather than a session command for the same
## reason the policies do: a golden recorded from something typed once cannot be
## re-recorded identically later, and the first time a deliberate balance change
## needs new values that becomes an hour of guessing.
##
## **Read the diff before pasting.** A golden is only worth having if a change
## to it is a decision. Regenerating on red is how a suite quietly stops
## asserting anything.

const CASES := [
	{"policy": "angler", "seconds": 60.0, "seed": 1},
	{"policy": "human", "seconds": 60.0, "seed": 1},
	{"policy": "human", "seconds": 60.0, "seed": 4},
	{"policy": "blind", "seconds": 60.0, "seed": 1},
	{"policy": "masher", "seconds": 60.0, "seed": 1},
	{"policy": "idle_hands", "seconds": 60.0, "seed": 1},
	{"policy": "slowpoke", "seconds": 60.0, "seed": 1},
]


func _initialize() -> void:
	# Built into a string first, then either printed or written. One producer
	# for both paths, so what you read is exactly what gets saved.
	var block := "const GOLDEN := [\n"
	for c in CASES:
		var policy: String = c["policy"]
		var seconds: float = c["seconds"]
		var seed_value: int = c["seed"]
		var r := Policies.play(policy, seconds, seed_value)
		block += "\t{\n"
		block += "\t\t\"policy\": \"%s\",\n" % policy
		block += "\t\t\"seconds\": %s,\n" % _num(seconds)
		block += "\t\t\"seed\": %d,\n" % seed_value
		block += "\t\t\"expect\": {\n"
		var keys := r.keys()
		keys.sort()
		for k in keys:
			block += "\t\t\t\"%s\": %s,\n" % [k, _lit(r[k])]
		block += "\t\t},\n"
		block += "\t},\n"
	block += "]"

	# `write`, not `--write`: Godot eats a leading double dash even after the
	# `--` separator, so the flag never reached `get_cmdline_user_args` and the
	# tool silently fell back to printing - which looks exactly like it worked.
	if "write" in OS.get_cmdline_user_args():
		var err := write_golden(block)
		if err != "":
			printerr("  golden NOT written: %s" % err)
			quit(1)
			return
		print("")
		print("  golden written into test/test_golden.gd - READ THE DIFF")
		print("")
		quit(0)
		return

	print("")
	print(block)
	print("")
	quit(0)


func _lit(v: Variant) -> String:
	if v is String:
		return "\"%s\"" % v
	if v is bool:
		return "true" if v else "false"
	if v is float:
		return _num(v)
	return str(v)


## Floats are printed with enough digits to round-trip, and the golden compares
## with TestHarness.FLOAT_EPS rather than exact equality - `snappedf` does not
## round-trip through a source literal, and the values are recorded on Windows
## and checked on a Linux runner.
func _num(f: float) -> String:
	return "%.6f" % f


const GOLDEN_FILE := "res://test/test_golden.gd"


## Splice `block` into `test_golden.gd` in place of the existing const.
##
## Refuses to save a file whose top-level bracket count is wrong, which is the
## exact failure this function exists to end. Returns an empty string on success
## and the reason on refusal.
static func write_golden(block: String) -> String:
	var f := FileAccess.open(GOLDEN_FILE, FileAccess.READ)
	if f == null:
		return "cannot read %s" % GOLDEN_FILE
	var text := f.get_as_text()
	f.close()

	# LINE BASED, not substring based. The first version looked for the literal
	# "\n]\n" and refused to write a file that a Windows tool had touched, because
	# the endings were "\r\n" - and the message it gave ("no closing bracket") sent
	# you looking at the brackets rather than at the newlines.
	var lines := text.replace("\r\n", "\n").split("\n")
	var first := -1
	var last := -1
	for i in lines.size():
		if first < 0 and lines[i].begins_with("const GOLDEN := ["):
			first = i
		elif first >= 0 and lines[i] == "]":
			last = i
			break
	if first < 0:
		return "no GOLDEN const in %s" % GOLDEN_FILE
	if last < 0:
		return "the GOLDEN const is never closed by a line that is just ]"

	var out: Array[String] = []
	for i in first:
		out.append(lines[i])
	for line in block.split("\n"):
		out.append(line)
	for i in range(last + 1, lines.size()):
		out.append(lines[i])

	# The check that ends the bug this whole function exists for: a stray second
	# closer is a parse error GDScript does not fail fast on, and it cost a
	# sixteen minute hang before anyone realised the suite was not slow.
	var closers := 0
	for line in out:
		if line == "]":
			closers += 1
	if closers != 1:
		return "refusing to write: %d top-level closers, expected 1" % closers

	var w := FileAccess.open(GOLDEN_FILE, FileAccess.WRITE)
	if w == null:
		return "cannot write %s" % GOLDEN_FILE
	w.store_string("\n".join(out))
	w.close()
	return ""
