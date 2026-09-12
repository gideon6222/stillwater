extends SceneTree

## Entry point for the pure tests.
##
##   godot --headless --script res://test/run_tests.gd
##
## Almost nothing loaded here touches a Node, a viewport or an input event, so
## this runs in a container with no GPU and no display - in about fifteen
## seconds, ten of them the whole-run golden and three the bot seam, which
## boots the scene off-tree. The scene is exercised properly by run_smoke.gd,
## which adds it to a tree and catches a different class of bug.
##
## **The suite list is a glob, not a hand-written array.** A hand-maintained
## list is a second place to remember, and this studio has already paid for
## that: nine tests were added to a sibling game, the list was not, and the
## runner cheerfully reported "65 passing" for a suite that never ran. An
## empty glob FAILS rather than passing - zero tests is not zero failures.
##
## **And a suite count below the floor fails.** See MIN_ASSERTIONS below.


## The floor under the whole suite's assertion count.
##
## Not a target - a canary. A runtime error inside a test is non-fatal in
## GDScript: the method stops at that line, every assertion below it never runs,
## and the harness carries on and prints "all passing" with a smaller number
## nobody reads. That happened HERE on 2026-09-11: a new test called a method
## that did not exist, the runner said all passing, and reintroducing the bug
## the test was written for still passed. The harness now fails the test that
## raised the error (TestHarness._Errors); this floor is the second, blunter
## instrument, for the case where nothing errors and coverage still quietly
## shrinks - a renamed check, a loop bound that fell to zero.
##
## Measured, not counted: 10,964 on 2026-09-12 with seven suites. The floor sits
## below that so an off-by-a-few in a conditional branch cannot go red on its
## own, and the runner nags when the count outgrows it. **Raise it when you add
## suites.**
const MIN_ASSERTIONS := 10900

## How far above the floor the count may drift before the runner asks for the
## floor to be re-recorded. Without this the floor rots: a suite that has
## doubled in size is no longer guarded by a number set when it was half that.
const FLOOR_SLACK := 400


func _initialize() -> void:
	var names: Array[String] = []
	var dir := DirAccess.open("res://test")
	if dir == null:
		print("  FAIL  cannot open res://test - the runner is broken, not the game")
		quit(1)
		return
	for f in dir.get_files():
		# `.gd` in the editor and in a source checkout, `.gd.remap` in an
		# exported build, where the script itself has been compiled away.
		var file := f.trim_suffix(".remap")
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		if not names.has(file):
			names.append(file)
	names.sort()

	if names.is_empty():
		print("")
		print("  FAIL  the glob matched no suites in res://test")
		print("        Zero tests is not zero failures. Either the files moved or the")
		print("        naming convention did; a green exit here would be a lie.")
		quit(1)
		return

	var suites := []
	for file in names:
		suites.append(load("res://test/" + file).new())

	print("  suites: %s" % ", ".join(names))
	var t := TestHarness.new()
	var code := TestHarness.run_all(suites, t)

	if code == 0 and t.checks < MIN_ASSERTIONS:
		print("")
		print("  FAIL  %d assertions ran, but at least %d are expected." % [t.checks, MIN_ASSERTIONS])
		print("        Nothing is red, which is the point: a check errored part-way and")
		print("        every assertion below it never ran. Look for a renamed property")
		print("        read off an untyped local. Fix that, do not lower the floor.")
		code = 1
	elif code == 0 and t.checks > MIN_ASSERTIONS + FLOOR_SLACK:
		print("  note: %d assertions against a floor of %d - raise MIN_ASSERTIONS in run_tests.gd"
			% [t.checks, MIN_ASSERTIONS])

	quit(code)
