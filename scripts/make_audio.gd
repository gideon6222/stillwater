extends SceneTree

## Generates every sound in the game, as WAV files, from arithmetic.
##
##   godot --headless --path . --script res://scripts/make_audio.gd
##
## **Why generated and not downloaded.** A fishing game needs about twenty
## sounds that all have to belong to each other - the reel click and the drag
## buzz are the same mechanism, the calm pad and the deep pad are the same chord
## - and a free-asset pack gives you twenty sounds that belong to twenty other
## games. Here the whole set is one key (D minor pentatonic), one sample rate and
## one set of envelopes, so it is coherent by construction. It also costs nothing
## to change: the brief is that the game turns from happy-but-eerie to genuinely
## unpleasant, and that is a parameter here rather than a shopping trip.
##
## **Why at build time and not at boot.** GDScript synthesises roughly a million
## samples a second. The music beds alone are four million, which is four seconds
## of a black screen on the phone. Generated once, committed as WAVs, imported
## like any other asset.
##
## **Why 22050 Hz mono.** Nothing here has content above about 8 kHz - it is
## water, wind, wood and low sine tones - and the rate halves the size of a set
## that would otherwise be most of the APK. The whole library is around 4 MB.
##
## Everything is deterministic: same seed, same bytes, so re-running this and
## getting a diff means something actually changed.

const RATE := 22050
const OUT := "res://assets/audio"

## D minor pentatonic, the key the whole game is in. Act I uses it plainly; the
## later acts use the SAME notes detuned and slowed, so the music does not change
## so much as go wrong - which is the effect asked for, and is much more
## unsettling than a different tune would be.
const D := 146.83
const F := 174.61
const G := 196.00
const A := 220.00
const C := 261.63

var _seed := 20260909


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0

	# --- the rod and the reel ---------------------------------------------
	n += _write("cast", _cast())
	n += _write("splash", _splash())
	n += _write("nibble", _knock(0.13, 190.0, 0.55, 0.010))
	n += _write("tug", _knock(0.20, 140.0, 0.85, 0.016))
	n += _write("hook", _hook())
	n += _write("reel", _reel_click())
	n += _write("drag", _drag())
	n += _write("snap", _snap())
	n += _write("land", _land())
	n += _write("clunk", _knock(0.45, 78.0, 1.0, 0.055))

	# --- the rooms ---------------------------------------------------------
	n += _write("coin", _coin())
	n += _write("page", _page())

	# --- the lake ----------------------------------------------------------
	n += _write("amb_water", _water(8.0))
	n += _write("amb_wind", _wind(8.0))
	n += _write("amb_deep", _deep(8.0))

	# --- the music ---------------------------------------------------------
	# Four beds, one chord, all sixteen seconds so any of them loops against any
	# other. The arc is a MIX, not a playlist: Act I is bells over the calm pad,
	# and by the quarry the bells are gone, the deep pad is up and `under` is
	# audible. Nothing ever cuts.
	n += _write("bed_calm", _pad(16.0, [D, A, C], 1.0, 0.6))
	n += _write("bed_deep", _pad(16.0, [D * 0.5, A * 0.5, F], 3.2, 0.9))
	n += _write("bed_bells", _bells(16.0))
	n += _write("bed_under", _under(16.0))

	print("wrote %d sounds to %s" % [n, OUT])
	quit()


# --- synthesis ------------------------------------------------------------

func _rand() -> float:
	# One deterministic stream for the whole library, so the bytes are stable.
	_seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_seed) / float(0x7FFFFFFF) * 2.0 - 1.0


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(round(seconds * RATE)))
	b.fill(0.0)
	return b


## One-pole low pass. Cheap, and the only filter any of this needs - everything
## in the set is either noise that wants dulling or a sine that is already clean.
func _lp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var k := clampf(cutoff / float(RATE) * 6.283185, 0.0, 1.0)
	var y := 0.0
	for i in b.size():
		y += k * (b[i] - y)
		b[i] = y
	return b


func _hp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := _lp(b.duplicate(), cutoff)
	for i in b.size():
		b[i] = b[i] - low[i]
	return b


func _noise(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		b[i] = _rand()
	return b


## Exponential decay, which is what a struck or plucked thing does. `power`
## above 1 makes the tail shorter than the attack suggests, which reads as
## "small and hard" - the reel click uses it heavily.
func _decay(b: PackedFloat32Array, power: float = 1.0) -> PackedFloat32Array:
	var n := b.size()
	for i in n:
		var t := float(i) / float(n)
		b[i] *= pow(1.0 - t, 2.4 * power)
	return b


func _fade_in(b: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := mini(b.size(), int(seconds * RATE))
	for i in n:
		b[i] *= float(i) / float(n)
	return b


func _mix(into: PackedFloat32Array, from: PackedFloat32Array, gain: float,
		at: float = 0.0) -> PackedFloat32Array:
	var off := int(at * RATE)
	for i in from.size():
		var j := i + off
		if j >= 0 and j < into.size():
			into[j] += from[i] * gain
	return into


## Normalise to a headroom, so nothing in the library clips and everything
## arrives at the mixer at a predictable level. The per-sound balance then lives
## in `audio.gd` as decibels, where it can be reasoned about.
func _norm(b: PackedFloat32Array, peak: float = 0.89) -> PackedFloat32Array:
	var hi := 0.0
	for v in b:
		hi = maxf(hi, absf(v))
	if hi < 0.00001:
		return b
	var g := peak / hi
	for i in b.size():
		b[i] *= g
	return b


## Make a buffer loop without a click, by crossfading its own tail over its head.
## Only for noise beds - the tonal ones are built from frequencies that are whole
## multiples of the loop length, so they already join.
func _seamless(b: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var n := b.size()
	var f := mini(n / 2, int(fade * RATE))
	var out := b.duplicate()
	out.resize(n - f)
	for i in f:
		var t := float(i) / float(f)
		out[i] = b[i] * t + b[n - f + i] * (1.0 - t)
	return out


## A frequency that completes a whole number of cycles in `seconds`, so a tonal
## loop joins itself exactly. Without this every music bed ticks once a bar.
func _snap_hz(hz: float, seconds: float) -> float:
	return maxf(1.0, round(hz * seconds)) / seconds


func _tone(seconds: float, hz: float, loop: bool = false) -> PackedFloat32Array:
	var f := _snap_hz(hz, seconds) if loop else hz
	var b := _buf(seconds)
	var w := 6.283185307 * f / float(RATE)
	for i in b.size():
		b[i] = sin(w * float(i))
	return b


# --- the rod and the reel -------------------------------------------------

## The cast. Noise swept from dull to bright and back, which is the sound of
## something moving past your ear rather than something being hit.
func _cast() -> PackedFloat32Array:
	var secs := 0.55
	var src := _noise(secs)
	var out := _buf(secs)
	var y := 0.0
	for i in out.size():
		var t := float(i) / float(out.size())
		# Rises then falls - the rod is fastest through the middle of the swing.
		var cut := 300.0 + 3400.0 * sin(t * PI)
		var k := clampf(cut / float(RATE) * 6.283185, 0.0, 1.0)
		y += k * (src[i] - y)
		out[i] = y * sin(t * PI) * sin(t * PI)
	return _norm(out, 0.7)


## The lure hitting the water: a bright scatter for the surface and one low
## rounded thump under it, which is the part that makes it sound like water and
## not like gravel.
func _splash() -> PackedFloat32Array:
	var out := _buf(0.5)
	var top := _hp(_noise(0.5), 900.0)
	_decay(top, 1.9)
	_mix(out, top, 0.8)
	var plop := _buf(0.5)
	for i in plop.size():
		var t := float(i) / float(RATE)
		# Pitch falls away fast, which is the whole cue for "into" rather than "on".
		plop[i] = sin(6.283185 * (420.0 - 300.0 * minf(1.0, t * 14.0)) * t)
	_decay(plop, 2.6)
	_mix(out, plop, 0.55)
	return _norm(out, 0.8)


## A knock on the line, felt through the rod. Used for the nibble, the tug and,
## slower and lower, for something that is not a fish arriving on the hook.
func _knock(secs: float, hz: float, power: float, click: float) -> PackedFloat32Array:
	var out := _buf(secs)
	var body := _buf(secs)
	for i in body.size():
		var t := float(i) / float(RATE)
		body[i] = sin(6.283185 * hz * t) + 0.35 * sin(6.283185 * hz * 2.02 * t)
	_decay(body, power * 1.4)
	_mix(out, body, 0.9)
	var tick := _lp(_noise(click), 2600.0)
	_decay(tick, 2.0)
	_mix(out, tick, 0.45)
	return _norm(out, 0.75)


## Setting the hook. A hard click, then a short bright ring - the rod loading.
func _hook() -> PackedFloat32Array:
	var out := _buf(0.3)
	var tick := _hp(_noise(0.02), 1400.0)
	_decay(tick, 1.0)
	_mix(out, tick, 1.0)
	var ring := _buf(0.3)
	for i in ring.size():
		var t := float(i) / float(RATE)
		ring[i] = sin(6.283185 * 660.0 * t) * 0.6 + sin(6.283185 * 990.0 * t) * 0.3
	_decay(ring, 2.2)
	_mix(out, ring, 0.7, 0.012)
	return _norm(out, 0.82)


## ONE click of the ratchet, played per tap. It has to be very short and very
## dry: the player will hear this four or five times a second through a whole
## fight, and anything with a tail turns into a buzz by the third one.
func _reel_click() -> PackedFloat32Array:
	var out := _lp(_hp(_noise(0.045), 700.0), 5200.0)
	_decay(out, 2.8)
	return _norm(out, 0.55)


## The drag giving line. Loops for as long as the fish runs, so it is the only
## sound in the game the player hears continuously - which is why it is a rough
## buzz around a low note rather than anything with a pitch to fixate on.
func _drag() -> PackedFloat32Array:
	var secs := 0.5
	var out := _buf(secs)
	for i in out.size():
		var t := float(i) / float(RATE)
		# A ratchet is a rate, not a tone: this is a pulse train, roughened.
		var ph := fmod(t * 62.0, 1.0)
		out[i] = (1.0 - ph) * 2.0 - 1.0
	out = _lp(out, 1800.0)
	var grit := _lp(_noise(secs), 3000.0)
	_mix(out, grit, 0.35)
	return _norm(_seamless(out, 0.03), 0.5)


## The line going. A crack, then the sound of everything that was under tension
## suddenly not being - which is the part that carries the feeling.
func _snap() -> PackedFloat32Array:
	var out := _buf(0.7)
	var crack := _hp(_noise(0.05), 1800.0)
	_decay(crack, 0.8)
	_mix(out, crack, 1.0)
	var whip := _buf(0.5)
	for i in whip.size():
		var t := float(i) / float(RATE)
		whip[i] = sin(6.283185 * (900.0 - 780.0 * minf(1.0, t * 3.0)) * t)
	_decay(whip, 1.6)
	_mix(out, whip, 0.45, 0.02)
	var tail := _lp(_noise(0.6), 800.0)
	_decay(tail, 1.2)
	_mix(out, tail, 0.30, 0.04)
	return _norm(out, 0.85)


## A fish coming over the gunwale: water, then a small warm interval. The chime
## is two notes of the game's own scale, so landing a fish is consonant with
## whatever the music is doing at the time.
func _land() -> PackedFloat32Array:
	var out := _buf(1.1)
	var slosh := _lp(_noise(0.45), 1500.0)
	_decay(slosh, 1.1)
	_mix(out, slosh, 0.75)
	var chime := _buf(0.9)
	for i in chime.size():
		var t := float(i) / float(RATE)
		chime[i] = sin(6.283185 * A * 2.0 * t) * 0.6 + sin(6.283185 * C * 2.0 * t) * 0.4
	_decay(chime, 1.5)
	_mix(out, chime, 0.42, 0.16)
	return _norm(out, 0.8)


# --- the rooms ------------------------------------------------------------

func _coin() -> PackedFloat32Array:
	var out := _buf(0.5)
	for k in 3:
		var c := _buf(0.3)
		var hz: float = [1180.0, 1560.0, 2040.0][k]
		for i in c.size():
			var t := float(i) / float(RATE)
			c[i] = sin(6.283185 * hz * t) + 0.4 * sin(6.283185 * hz * 1.51 * t)
		_decay(c, 2.4)
		_mix(out, c, 0.6 - 0.13 * k, 0.045 * k)
	return _norm(out, 0.6)


## Paper. Short filtered noise with a soft edge - a page rather than a click,
## because the rooms are a book and the water is the game.
func _page() -> PackedFloat32Array:
	var out := _lp(_hp(_noise(0.22), 1100.0), 6000.0)
	for i in out.size():
		var t := float(i) / float(out.size())
		out[i] *= sin(t * PI) * (0.5 + 0.5 * sin(t * 34.0))
	return _norm(out, 0.42)


# --- the lake -------------------------------------------------------------

## Water against a hull. Filtered noise with a slow swell, and a second slower
## swell over it so it never settles into an obvious period.
func _water(secs: float) -> PackedFloat32Array:
	var b := _lp(_noise(secs + 1.0), 900.0)
	b = _hp(b, 90.0)
	for i in b.size():
		var t := float(i) / float(RATE)
		b[i] *= 0.55 + 0.45 * sin(6.283185 * 0.31 * t) * sin(6.283185 * 0.13 * t + 1.1)
	return _norm(_seamless(b, 1.0), 0.55)


func _wind(secs: float) -> PackedFloat32Array:
	var b := _lp(_noise(secs + 1.0), 420.0)
	for i in b.size():
		var t := float(i) / float(RATE)
		b[i] *= 0.35 + 0.65 * pow(0.5 + 0.5 * sin(6.283185 * 0.17 * t + 0.6), 2.0)
	return _norm(_seamless(b, 1.0), 0.45)


## What the deep sounds like. Almost entirely below 120 Hz, so on a phone speaker
## it is barely audible and on headphones it is the whole room - which is exactly
## right for a game whose deep water is meant to be felt rather than noticed.
func _deep(secs: float) -> PackedFloat32Array:
	var b := _lp(_noise(secs + 1.0), 110.0)
	var groan := _buf(secs + 1.0)
	for i in groan.size():
		var t := float(i) / float(RATE)
		groan[i] = sin(6.283185 * (41.0 + 3.0 * sin(6.283185 * 0.07 * t)) * t)
	_mix(b, groan, 0.5)
	for i in b.size():
		var t := float(i) / float(RATE)
		b[i] *= 0.5 + 0.5 * sin(6.283185 * 0.09 * t)
	return _norm(_seamless(b, 1.0), 0.6)


# --- the music ------------------------------------------------------------

## A sustained chord, built from pairs of sines a few cents apart. The beating
## between each pair is the entire character: at `detune` 1.0 it is warm, and at
## 3.2 it is the same chord sounding like it is being held by something that
## cannot quite hold it.
func _pad(secs: float, notes: Array, detune: float, wobble: float) -> PackedFloat32Array:
	var out := _buf(secs)
	for k in notes.size():
		var hz: float = notes[k]
		var a := _tone(secs, hz, true)
		var b := _tone(secs, hz * (1.0 + 0.0009 * detune), true)
		_mix(out, a, 0.5)
		_mix(out, b, 0.5)
		# A third voice an octave up, quieter, for air.
		_mix(out, _tone(secs, hz * 2.0, true), 0.12)
	for i in out.size():
		var t := float(i) / float(RATE)
		out[i] *= 0.72 + 0.28 * sin(6.283185 * (0.06 * wobble) * t)
	return _norm(_lp(out, 2200.0), 0.42)


## The happy part, and the part that goes away. Sparse plucked notes from the
## pentatonic, placed on a slow grid so they never form a tune the player can
## get tired of. Act I fades these UP; by Old Town they are gone entirely, and
## nothing replaces them - the absence is the effect.
func _bells(secs: float) -> PackedFloat32Array:
	var out := _buf(secs)
	var scale := [D * 2.0, F * 2.0, G * 2.0, A * 2.0, C * 2.0, D * 4.0]
	var at := 0.35
	while at < secs - 1.4:
		var hz: float = scale[int(absf(_rand()) * scale.size()) % scale.size()]
		var note := _buf(1.6)
		for i in note.size():
			var t := float(i) / float(RATE)
			note[i] = sin(6.283185 * hz * t) + 0.28 * sin(6.283185 * hz * 2.0 * t) \
				+ 0.10 * sin(6.283185 * hz * 3.01 * t)
		_decay(note, 1.15)
		_mix(out, note, 0.5 + 0.28 * absf(_rand()), at)
		at += 1.1 + absf(_rand()) * 1.5
	return _norm(_seamless(out, 0.4), 0.40)


## What is underneath. A sub pulse at walking pace and two partials that are
## deliberately not in the harmonic series, so it never resolves into a note.
## Silent for the whole of Act I; by the Spring it is most of what you can hear.
func _under(secs: float) -> PackedFloat32Array:
	var out := _buf(secs)
	var sub := _buf(secs)
	for i in sub.size():
		var t := float(i) / float(RATE)
		var beat := pow(0.5 + 0.5 * sin(6.283185 * _snap_hz(0.42, secs) * t), 5.0)
		sub[i] = sin(6.283185 * _snap_hz(D * 0.25, secs) * t) * beat
	_mix(out, sub, 1.0)
	for hz in [D * 1.41, D * 2.73]:
		var p := _tone(secs, hz, true)
		for i in p.size():
			var t := float(i) / float(RATE)
			p[i] *= 0.5 + 0.5 * sin(6.283185 * 0.043 * t + hz)
		_mix(out, p, 0.10)
	return _norm(_lp(out, 900.0), 0.5)


# --- writing --------------------------------------------------------------

## A 16-bit mono PCM WAV, written by hand. Godot imports it like any other.
func _write(name: String, samples: PackedFloat32Array) -> int:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 2, v)

	var f := FileAccess.open("%s/%s.wav" % [OUT, name], FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % name)
		return 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)            # PCM header size
	f.store_16(1)             # format: PCM
	f.store_16(1)             # channels: mono
	f.store_32(RATE)
	f.store_32(RATE * 2)      # byte rate
	f.store_16(2)             # block align
	f.store_16(16)            # bits
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	print("  %-12s %5.2f s" % [name, float(samples.size()) / float(RATE)])
	return 1
