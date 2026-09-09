class_name Mood
extends RefCounted

## What the lake LOOKS like, as data.
##
## Hour, weather and depth in; a flat dictionary of colours and energies out.
## Pure - no nodes, no shader, no frame - which is the only reason the mood arc
## can be tested at all. `main.gd` reads this and assigns it, and every claim
## worth making about the look ("night is darker than noon at every weather",
## "nothing about going deeper brightens anything") is an assertion over a
## function rather than a thing you can only check by looking at a screenshot.
##
## **The arc is the same shape as the music: one curve, no cuts.** `dread` is
## depth, exactly as in `audio.gd`, and it desaturates and darkens everything
## continuously rather than swapping a palette at a band boundary. The eeriness
## the brief asks for comes from the lake being the SAME lake, slightly wrong,
## and a hard palette switch would announce the trick.
##
## The one exception to smooth is weather, which is allowed to change when the
## player sleeps, because weather changing is a thing weather does.

## The hours. `sun` is the light's pitch in degrees below horizontal - low at the
## ends of the day, which is what gives the water its long gold streak.
const HOURS := {
	"dawn": {
		"top": Color(0.30, 0.44, 0.62), "horizon": Color(0.92, 0.79, 0.60),
		"sun": Color(1.00, 0.86, 0.64), "energy": 2.2, "pitch": -11.0,
		"ambient": 0.90, "fog": Color(0.86, 0.80, 0.68), "haze": 0.00030,
	},
	"morning": {
		"top": Color(0.28, 0.48, 0.74), "horizon": Color(0.80, 0.86, 0.88),
		"sun": Color(1.00, 0.95, 0.86), "energy": 2.8, "pitch": -34.0,
		"ambient": 1.05, "fog": Color(0.82, 0.86, 0.88), "haze": 0.00016,
	},
	"afternoon": {
		"top": Color(0.24, 0.44, 0.70), "horizon": Color(0.78, 0.81, 0.80),
		"sun": Color(1.00, 0.97, 0.92), "energy": 2.6, "pitch": -52.0,
		"ambient": 1.00, "fog": Color(0.78, 0.81, 0.82), "haze": 0.00022,
	},
	"dusk": {
		# The best-looking hour in the game, and the one the story leans on. The
		# horizon is nearly red and the sun is almost on the water.
		"top": Color(0.16, 0.20, 0.38), "horizon": Color(0.88, 0.50, 0.34),
		"sun": Color(1.00, 0.66, 0.42), "energy": 1.7, "pitch": -6.0,
		"ambient": 0.62, "fog": Color(0.62, 0.46, 0.44), "haze": 0.00048,
	},
	"night": {
		# Not black. A lake at night is a dark BLUE with a horizon you can still
		# find, and something you cannot see is not frightening - it is just off.
		"top": Color(0.03, 0.05, 0.11), "horizon": Color(0.10, 0.14, 0.22),
		"sun": Color(0.52, 0.62, 0.86), "energy": 0.42, "pitch": -38.0,
		"ambient": 0.20, "fog": Color(0.06, 0.09, 0.14), "haze": 0.00090,
	},
}

## Weather, as multipliers and pulls on whatever the hour gave. Kept as
## modifiers rather than as twenty-five hand-written palettes: five hours times
## five weathers is a table nobody keeps consistent, and the whole point is that
## a storm at dusk should look like BOTH.
## `spec` is how much of the sun survives as a DIRECT beam rather than being
## scattered into ambient by cloud, and it is the term that makes weather read.
##
## Without it a storm at dusk rendered as a golden sunset. The sun's energy was
## correctly low, but the light is at six degrees and water at a grazing angle
## throws a specular streak from almost nothing - and that streak carries the
## SUN's colour, so the one warm object in the frame was also the brightest. The
## picture said "beautiful evening" while every other number said "storm".
##
## Cloud does not dim a sunbeam, it turns it into a sky. `spec` removes the beam;
## `light` and `grey` handle the rest.
const WEATHERS := {
	"clear": {"light": 1.00, "haze": 1.00, "grey": 0.00, "spec": 1.00, "tint": Color(1, 1, 1), "chop": 1.00},
	"overcast": {"light": 0.62, "haze": 2.20, "grey": 0.45, "spec": 0.30, "tint": Color(0.86, 0.88, 0.90), "chop": 1.15},
	"fog": {"light": 0.50, "haze": 9.00, "grey": 0.62, "spec": 0.16, "tint": Color(0.88, 0.90, 0.90), "chop": 0.55},
	# `light` floors were raised after an afternoon storm rendered nearly black -
	# oppressive is right, unreadable is not, and the player still has to be able
	# to see their own boat. A STORM removes the sun (`spec`), it does not remove
	# the sky; that distinction is what keeps it gloomy rather than dark.
	"rain": {"light": 0.54, "haze": 3.60, "grey": 0.58, "spec": 0.22, "tint": Color(0.74, 0.80, 0.84), "chop": 1.45},
	"storm": {"light": 0.40, "haze": 5.00, "grey": 0.70, "spec": 0.10, "tint": Color(0.60, 0.66, 0.70), "chop": 2.10},
}

## Where the water colour ends up at the bottom of the lake. Not black and not
## blue: a dead, slightly green grey, which is what still water over stone
## actually looks like and is much worse to be above than black would be.
const DEEP_WATER := Color(0.030, 0.052, 0.055)
const DEEP_SKY := Color(0.30, 0.33, 0.32)

## How much of the deep's character has arrived by the time dread is 1.
const DREAD_DRAIN := 0.72         ## saturation removed
const DREAD_DARKEN := 0.55        ## light removed

## THE MOST FOG THE GAME IS ALLOWED TO HAVE.
##
## Fog is stacked multiplicatively - the hour's haze, times the weather, times up
## to 3.4 for depth - and three multipliers all at their worst is a combination
## nobody thinks to look at. Night, in fog, in the quarry came out at 0.0275,
## which is not atmosphere: the float is at cast range and would simply not be
## visible, so the one minigame the player has to WATCH stops existing.
##
## Clamped rather than re-balanced, because every individual multiplier is right
## and it is only the corner that is wrong. 0.011 is thick enough that the far
## bank is gone and the reeds are suggestions, and thin enough that a red float
## twenty metres out still reads.
const MAX_FOG := 0.011


## The whole look, in one dictionary.
##
## `dread` is 0 at the surface and 1 in the quarry - the same number `audio.gd`
## mixes on, so the picture and the score arrive together without either knowing
## about the other.
static func at(hour: String, weather: String, dread: float) -> Dictionary:
	var h: Dictionary = HOURS.get(hour, HOURS["dawn"])
	var w: Dictionary = WEATHERS.get(weather, WEATHERS["clear"])
	var d := clampf(dread, 0.0, 1.0)

	var tint: Color = w["tint"]
	var grey: float = w["grey"]
	var light: float = w["light"] * (1.0 - DREAD_DARKEN * d)

	var top := _drain(_apply(h["top"], tint, grey), d)
	var horizon := _drain(_apply(h["horizon"], tint, grey), d)
	var fog := _drain(_apply(h["fog"], tint, grey), d)

	return {
		"sky_top": top,
		"sky_horizon": horizon,
		"sun_color": _drain(_apply(h["sun"], tint, grey * 0.5), d * 0.7),
		# Floored above zero: a scene with no directional light at all loses the
		# specular streak that makes the water read as water, and the lake goes
		# back to looking like the wet concrete of the very first build.
		"sun_energy": maxf(0.10, float(h["energy"]) * light),
		"sun_pitch": float(h["pitch"]),
		"ambient": maxf(0.06, float(h["ambient"]) * light),
		"fog_color": fog,
		# Fog climbs with weather AND with depth. It is the cheapest thing in the
		# renderer and the most effective: it removes the draw distance that would
		# otherwise need managing, and it is the single best way to make a
		# friendly lake stop being friendly.
		"fog_density": minf(MAX_FOG, float(h["haze"]) * float(w["haze"]) * (1.0 + 2.4 * d)),
		"water_shallow": _drain(_apply(Color(0.33, 0.46, 0.40), tint, grey), d).lerp(DEEP_WATER, d * 0.55),
		"water_deep": _drain(Color(0.06, 0.13, 0.16), d).lerp(DEEP_WATER, d * 0.8),
		"water_sky": _drain(_apply(horizon, tint, grey * 0.4), d).lerp(DEEP_SKY, d * 0.5),
		"chop": float(w["chop"]) * (1.0 + 0.25 * d),
		# The deep keeps a little of the beam even in cloud, because water that
		# throws nothing back at all stops reading as water - see the sun floor.
		"specular": maxf(0.06, float(w["spec"]) * (1.0 - 0.35 * d)),
	}


## Push a colour toward the weather's tint and toward its own grey.
static func _apply(c: Color, tint: Color, grey: float) -> Color:
	var out := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b)
	var lum := out.r * 0.299 + out.g * 0.587 + out.b * 0.114
	return out.lerp(Color(lum, lum, lum), clampf(grey, 0.0, 1.0))


## Drain the colour out of something as the water gets older. Saturation goes
## first and value follows, which is the order in which a photograph fades - and
## it reads as age rather than as a lighting change.
static func _drain(c: Color, d: float) -> Color:
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var out := c.lerp(Color(lum, lum, lum), DREAD_DRAIN * d)
	return out.darkened(DREAD_DARKEN * d * 0.55)


## Total light in a look, for the tests. One number so "darker" is a thing that
## can be asserted rather than argued about.
static func brightness(look: Dictionary) -> float:
	var a: Color = look["sky_top"]
	var b: Color = look["sky_horizon"]
	var sky := (a.r + a.g + a.b + b.r + b.g + b.b) / 6.0
	return sky * 0.5 + float(look["sun_energy"]) * 0.12 + float(look["ambient"]) * 0.2
