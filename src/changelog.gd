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

const VERSION := "0.3.0"

const RELEASES := [
	{
		"version": "0.3.0",
		"date": "2026-09-09",
		"title": "The rod is the gauge",
		"notes": [
			"The tension meter is gone. Watch the ROD - how far it bends is the load.",
			"Drag anywhere on the lower half now. Nothing on screen to cover up.",
			"It sits still: PUMP. Lift, then lower to take up line. A steady hold gains nothing.",
			"It runs: GIVE. Drop the rod or the line parts, and it parts fastest at the start.",
			"It thrashes on top: HOLD STEADY. Moving the thumb throws the hook.",
			"The water warns you about a third of a second before each one.",
			"The hook works loose the whole time, so taking it slowly is also losing.",
		],
	},
]
