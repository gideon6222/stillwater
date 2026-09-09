class_name Changelog
extends RefCounted

## What changed, in the player's terms.
##
## The build stamp answers "did my update land". It cannot answer "what is
## actually different", which after a few sessions of work is the question that
## matters more - and a commit log is the wrong shape for it, being written for
## whoever maintains the code.
##
## Rules for entries: describe what the player can now do or see, not what was
## refactored; one line each; newest first. Add this from day one. On an
## earlier game it arrived far too late to be as useful as it should have been.

const VERSION := "0.4.1"

const RELEASES := [
	{
		"version": "0.4.1",
		"date": "2026-09-09",
		"title": "The gauges actually appear now",
		"notes": [
			"HOOK IT: a marker sweeps a bar. Tap while it is in the green.",
			"Dead centre starts the fight already up to pressure.",
			"REEL IT IN: tap to keep the needle in the green band.",
			"Stop tapping and it falls - the fish takes line back.",
			"Tap too much and it goes into the red, and the line parts.",
			"When the fish RUNS the needle climbs on its own. Stop tapping.",
			"The bar flashes just before a run. Watch for it.",
			"Gauges are at the top now, so your thumb never covers them.",
			"The rod lifts UP AND BACK to cast, then swings forward. Only a fish bends it.",
			"Fixed: neither gauge was ever visible. They are now.",
			"Fixed: tap to wind a dead cast back in. You could get stuck with a line out.",
		],
	},
]
