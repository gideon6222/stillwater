extends RefCounted

## THE IMPORT SETTINGS ARE PART OF THE LOOK, AND THEY DEFAULT WRONG.
##
## Godot imports a texture with `mipmaps/generate=false`, and every texture in
## this game arrived that way. It is not a subtle setting: almost every surface
## here is a plank, a gunwale or a lake seen at a grazing angle, the grain tiles
## seven to twenty times across each one, and without mipmaps that samples into a
## dither of black and tan speckle over the whole boat. It reads as compression
## noise, it does not go away at higher resolution, and it is most of what
## "the graphics still dont look very polished like a professional game" was
## pointing at.
##
## It is asserted here rather than fixed by hand because the setting lives in a
## `.import` file that is regenerated whenever the source changes, and because
## the next texture anybody adds will arrive with the same default.

## THE LAUNCHER ICONS ARE NOT GAME TEXTURES.
##
## `assets/icon/` is read by the ANDROID PACKAGER, not by the renderer - those
## PNGs become the app's icon in the phone's launcher and are never drawn by this
## game at all. Mipmaps and VRAM compression are meaningless for them, and the two
## checks above exist for a reason that does not apply: a texture tiling twenty
## times across a plank at a grazing angle.
##
## Excluded rather than silenced. The rules above stay strict for everything the
## game actually draws.
static func _is_launcher_icon(path: String) -> bool:
	return path.begins_with("res://assets/icon/")



func test_every_imported_texture_has_mipmaps(t: TestHarness) -> void:
	var missing: Array[String] = []
	var checked := 0
	for path in _import_files("res://assets"):
		if _is_launcher_icon(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("mipmaps/generate="):
			continue
		checked += 1
		if text.contains("mipmaps/generate=false"):
			missing.append(path)
	t.gt(float(checked), 10.0,
		"only %d importable textures found - the walk is not reaching them" % checked)
	t.eq(missing.size(), 0,
		"imported without mipmaps: %s" % ", ".join(missing))


## Everything is imported for a phone, so everything is VRAM compressed and
## capped. An uncompressed 4K HDRI is 14 MB on its own, and there are six.
func test_every_imported_texture_is_sized_for_a_phone(t: TestHarness) -> void:
	var loose: Array[String] = []
	for path in _import_files("res://assets"):
		if _is_launcher_icon(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("compress/mode="):
			continue
		if not text.contains("compress/mode=2"):
			loose.append(path)
	t.eq(loose.size(), 0,
		"not VRAM compressed: %s" % ", ".join(loose))


## THE VERSION IS WRITTEN IN TWO PLACES AND THEY MUST AGREE.
##
## `Changelog.VERSION` is what the game shows the player; `version/name` in
## export_presets.cfg is what Android records for the APK it installs. Nothing
## derives one from the other - Godot will not read a constant out of a script
## when it exports - so the only thing keeping them in step is this assertion.
##
## They had already drifted once, silently, and the shape of that failure is the
## reason it is worth a test: the game says 0.5.2 on its own title screen while
## the phone's app info says 0.5.1, so "did my build land" gets two different
## answers depending on where you look, which is exactly the question the build
## stamp and the changelog exist to answer.
##
## Both presets are checked, because the debug APK and the Play AAB each carry
## their own copy and only one of them is ever in front of you.
func test_the_version_agrees_everywhere_it_is_written(t: TestHarness) -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.ok(text != "", "export_presets.cfg could not be read")
	var found: Array[String] = []
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("version/name="):
			found.append(s.trim_prefix("version/name=").replace("\"", ""))
	t.gt(float(found.size()), 1.0,
		"expected a version/name in each preset, found %d" % found.size())
	for v in found:
		t.eq(v, Changelog.VERSION,
			"export_presets.cfg says %s but Changelog.VERSION says %s" % [v, Changelog.VERSION])
	# And the newest release in the changelog is the version being shipped, since
	# a bumped constant with no entry under it is a build the player cannot read.
	t.gt(float(Changelog.RELEASES.size()), 0.0, "the changelog is empty")
	t.eq(String(Changelog.RELEASES[0]["version"]), Changelog.VERSION,
		"the newest changelog entry is not the version being built")


## THE BOOT SPLASH IS THIS GAME, NOT THE ENGINE.
##
## The phone playtest on 2026-09-12 caught "GODOT Game engine" on a dark plate
## at every launch. T4 had replaced the launcher icon and asserted nothing about
## the splash, which is the same class of default: it ships unless something
## looks. The plate must be set to the game's own colour (Godot's default is a
## near-black grey) and the picture must be a file that exists, because a path
## to a missing image falls back to the logo without a word.
func test_the_boot_splash_is_the_games_own(t: TestHarness) -> void:
	var image := String(ProjectSettings.get_setting("application/boot_splash/image", ""))
	t.ok(image != "", "application/boot_splash/image is unset, so the engine logo ships as the splash")
	t.ok(image != "" and FileAccess.file_exists(image),
		"the boot splash image %s does not exist, so the engine logo ships as the splash" % image)
	var plate: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.14, 0.14, 0.14))
	t.gt(plate.get_luminance(), 0.3,
		"the boot splash plate is %s - Godot's dark default, not this game's dawn" % plate)


## AND version/code, WHICH IS THE ONE THE STORE ACTUALLY READS.
##
## The test above collected only `version/name=`, so the CODE was asserted
## nowhere: it sat at 1 while the name climbed to 0.5.2. Play rejects every
## upload after the first unless the code is higher than the last one, so the
## single number that decides whether a build can be uploaded at all was the one
## number no test looked at. gravewell and wildform carry the same assertion.
##
## It is tied to the changelog rather than typed by hand: one released entry is
## one upload, so the code rises exactly when a note is written for it and can
## never stand still or go backwards.
func test_the_version_code_is_the_release_count(t: TestHarness) -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	t.ok(text != "", "export_presets.cfg could not be read")
	var codes: Array[int] = []
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("version/code="):
			codes.append(int(s.trim_prefix("version/code=")))
	t.gt(float(codes.size()), 1.0,
		"expected a version/code in each preset, found %d" % codes.size())
	for c in codes:
		t.eq(c, codes[0],
			"the export presets disagree about version/code: %d against %d" % [c, codes[0]])
	t.eq(codes[0], Changelog.RELEASES.size(),
		"version/code is %d but the changelog carries %d releases - bump the code to %d"
			% [codes[0], Changelog.RELEASES.size(), Changelog.RELEASES.size()])


func _import_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir.path_join(name)
		if d.current_is_dir():
			out.append_array(_import_files(path))
		elif name.ends_with(".import"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	return out
