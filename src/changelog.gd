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

const VERSION := "0.2.0"

const RELEASES := [
	{
		"version": "0.2.0",
		"date": "2026-09-09",
		"title": "You can fish",
		"notes": [
			"Hold anywhere to load the rod, let go to cast. Longer hold, longer cast.",
			"Tap the moment it takes - you get less than half a second.",
			"Drag the gauge on the right to fight it. Keep the line in the green band.",
			"Pull too hard and the line parts; too little and it throws the hook.",
			"Bluegill, yellow perch and largemouth bass, in a reed bay at dawn.",
		],
	},
]
