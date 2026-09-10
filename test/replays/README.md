# Replays

Recorded touch scenarios for `scripts\movie.ps1`. JSON arrays of
`{"f": physics_frame, "t": "touch"|"drag", "i": index, "x": px, "y": px, "p": pressed, "rx": dx, "ry": dy}`
in **viewport** coordinates.

## The coordinate space is 1080x2338, not the 460x996 in movie.ps1's help

Measured, because getting this wrong makes every tap miss and the run still films
perfectly, so it looks like a game bug rather than a coordinate bug. **Movie Maker mode
ignores `--resolution`**: it renders at the project's viewport size, and the log says so —
"Movie Maker mode enabled, recording movie in 1080x1920 @ 60 FPS" — while
`get_visible_rect()` inside the run reports **1080x2338**, the project's 1080 width with
`stretch/aspect="expand"` extending the height to the phone's shape. `movie.ps1 -Resolution`
sizes the window and changes nothing about the frames. ffmpeg does the downscaling
afterwards, which is why the contact sheet still looks like a phone.

So write replay coordinates against 1080x2338. Ones measured from inside a real run:

| | centre |
|---|---|
| Title: Continue / New game / Settings | (540, 1644) / (540, 1802) / (540, 1960) |
| CastArea (the whole screen; press-hold-release to charge and cast) | (540, 1150) is safely inside it |

To measure more, print `get_global_rect()` from inside `_tick` on one frame and film three
seconds — the rects a headless run reports are against a 100x100 viewport and are useless
for this.

## Recording and filming

Record one: `godot --path . -- record=test/replays/<name>.json touch`, play with the mouse,
close the window. Every game keeps at least `idle` (no input), `first-minute`, `boundary`,
`fail` and `shop`. `idle.json` is an empty array: film it with `movie.ps1 -Seconds 10 -Name
idle` and no `-Replay`.

Note the cost before filming something long: frames are full-resolution PNGs, so sixteen
seconds is 960 files and takes minutes. Film the shortest run that shows the thing.

Stillwater keeps:

- `idle.json` — empty. The title over the live lake
- `first-cast.json` — Continue, the walk down, charge and cast, then the tap rhythm of a fight
