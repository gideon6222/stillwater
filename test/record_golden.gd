extends SceneTree

## Records the golden. Run it, paste the output into `test/test_golden.gd`.
##
##   godot --headless --path . --script res://test/record_golden.gd
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
	{"policy": "angler", "seconds": 60.0, "seed": 4},
	{"policy": "masher", "seconds": 60.0, "seed": 1},
	{"policy": "idle_hands", "seconds": 60.0, "seed": 1},
	{"policy": "timid", "seconds": 60.0, "seed": 1},
]


func _initialize() -> void:
	print("")
	print("const GOLDEN := [")
	for c in CASES:
		var policy: String = c["policy"]
		var seconds: float = c["seconds"]
		var seed_value: int = c["seed"]
		var r := Policies.play(policy, seconds, seed_value)
		print("\t{")
		print("\t\t\"policy\": \"%s\"," % policy)
		print("\t\t\"seconds\": %s," % _num(seconds))
		print("\t\t\"seed\": %d," % seed_value)
		print("\t\t\"expect\": {")
		var keys := r.keys()
		keys.sort()
		for k in keys:
			print("\t\t\t\"%s\": %s," % [k, _lit(r[k])])
		print("\t\t},")
		print("\t},")
	print("]")
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
