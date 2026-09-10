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


func test_every_imported_texture_has_mipmaps(t: TestHarness) -> void:
	var missing: Array[String] = []
	var checked := 0
	for path in _import_files("res://assets"):
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
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("compress/mode="):
			continue
		if not text.contains("compress/mode=2"):
			loose.append(path)
	t.eq(loose.size(), 0,
		"not VRAM compressed: %s" % ", ".join(loose))


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
