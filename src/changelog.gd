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

const VERSION := "0.5.0"

const RELEASES := [
	{
		"version": "0.5.0",
		"date": "2026-09-09",
		"title": "Watch the float",
		"notes": [
			"HOOK IT: no bar any more. Watch the FLOAT.",
			"The fish teases the bait - short shallow dips that pop straight back.",
			"Then it takes it properly: deeper, and it stays under. Tap THEN.",
			"Tap on a tease and you pull the bait out of its mouth.",
			"Strike early in the take and the fight starts already up to pressure.",
			"REEL IT IN: tap to keep the needle in the green. Smaller steps now.",
			"When the fish RUNS the needle climbs on its own. Stop tapping.",
			"Casting: the rod lifts up and BACK, then flings forward - still angled up.",
		],
	},
]
