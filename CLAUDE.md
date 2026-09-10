# Stillwater

A fishing game for Android, built in Godot 4 on the phone-game stack: a pure simulation core,
headless tests, a whole-run golden, a size guard, CI, and an APK that installs on the phone.

It starts on a calm lake at dawn and becomes deeply unsettling. **Depth is time** — the lake
does not go down, it goes back — and the line upgrade IS the story progression, which is the
idea everything else hangs off.

**Read `NOTES.md` in this repo before writing game code.** It has the design constraints the
code has to honour, the measured balance, and the invariants specific to this game.

@../gamedev-notes/INDEX.md

The shared rules, the Godot traps, the toolchain paths, the export and signing rules and
the process are in `C:\dev\gamedev-notes` (`INDEX.md` above, then `GODOT.md`, `CRAFT.md`,
`TESTING.md`, `ASSETS.md`, `POLISH.md`). **This file carries only what is specific to this
game.** `NOTES.md` has the decisions and measurements; `PLAN.md` the milestones;
`C:\dev\gamedev-notes\playtests\stillwater.md` his words about it.

---

## Commands

**`scripts\check.ps1` is the gate.** Import, pure tests, smoke and the size guard, in the
order that fails fastest, exiting non-zero on the first failure. About fifteen seconds. Run
it before every commit that touches `src/` or `test/`; the individual commands below are for
when it has already told you which one to look at.

```powershell
scripts\check.ps1                     # the whole local gate (~15 s)
scripts\check.ps1 -Export             # ...and export the APK, then check its size

scripts\movie.ps1 -Seconds 10 -Name idle                      # film the attract state
scripts\movie.ps1 -Replay test\replays\first-cast.json -Seconds 20   # film a scripted run
godot --path . --resolution 460x996 -- record=test/replays/<name>.json touch   # record one

scripts\device.ps1 install | launch | log | shot | record 30 | perf   # the phone, over adb
```

```powershell
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --import                                   # after adding files
& $godot --headless --path . --script res://test/run_tests.gd           # pure tests, ~1s
& $godot --headless --path . --script res://test/run_smoke.gd           # boots the real scene
& $godot --headless --path . --export-debug "Android" build/stillwater.apk
& $godot --headless --path . --script res://scripts/check_size.gd       # size guard
& $godot --headless --path . --script res://scripts/make_audio.gd      # regenerate every sound
& $godot --headless --path . --script res://scripts/balance.gd         # print the difficulty table
& $godot --path . --resolution 460x996 --script res://scripts/shot.gd -- 45 shed   # photograph a room
& $godot --path .                                                        # open the editor
```

Every one exits non-zero on failure, which is what makes them a CI gate rather than
something to read.

## Files

| File | What it is |
|---|---|
| `src/sim/sim.gd` | **The whole game, with no renderer in it.** The cast and fight state machine |
| `src/sim/species.gd` | What lives in the water, as DATA. A species is a row, never a class |
| `src/sim/tuning.gd` | Every number that shapes how it feels, plus the derived arithmetic |
| `src/sim/util.gd` | `smooth`, `hash2`, `fmt`, `fmt_m` — pure, and the hash is load-bearing |
| `src/sim/world.gd` | The lake: bands, spots, the clock, the weather. **Depth is time** |
| `src/sim/gear.gd` | Every ladder you can buy, as data. LINE is the progression |
| `src/sim/econ.gd` | Money, what you own, and the livewell's weight cap |
| `src/sim/objects.gd` | What comes up that is not a fish. **This is how the story is told** |
| `src/game/menus.gd` | The Shed, the Lake and the Logbook. Built from `sim` every open |
| `src/game/audio.gd` | The mixer. The music arc is a crossfade on DEPTH, never a playlist |
| `scripts/make_audio.gd` | Generates all nineteen sounds from arithmetic. Deterministic |
| `scripts/balance.gd` | Prints the land rate per species and per band. Tune against this |
| `src/sim/rng.gd` | A seeded stream for values that decide *when* something happens |
| `src/game/main.gd` | The shell: reads `Sim`, draws it, feeds it input. Decides nothing |
| `src/game/main.tscn` | Four lines. One node with the script; the world is built in code |
| `src/build_stamp.gd` | Overwritten at build time. Committed fallback says `dev` |
| `src/changelog.gd` | `VERSION` and the player-facing history |
| `test/policies.gd` | Scripted players. **The definition of "playing well"** |
| `test/run_tests.gd` | Pure tests. No node, no viewport, no GPU |
| `test/run_smoke.gd` | Boots the real scene and catches a fish through it |
| `test/run_probe.gd` | Balance readings over several seeds. Prints; never fails |
| `test/record_golden.gd` | Regenerates the golden. **Read the diff before pasting it in** |
| `test/harness.gd` | The assertions. Deliberately small — see NOTES.md |
| `scripts/shot.gd` | Screenshot of the real game, at the PHONE's aspect ratio |
| `scripts/check_size.gd` | APK size guard, fails in both directions |
| `scripts/stamp.ps1` | Writes the build stamp from git |
| `scripts/check.ps1` | **The local gate.** Everything that runs on the desk, fastest failure first |
| `scripts/movie.ps1` | Films a deterministic run into a contact sheet. Movie Maker mode, fixed fps |
| `scripts/device.ps1` | The phone over adb: install, launch, log, shot, record, perf, poke |
| `scripts/replay_player.gd` | The `ReplayPlayer` autoload. Records and replays touches by physics frame |
| `scripts/probe_prop.gd` | Prints an imported prop's mesh names and real bounds in metres |
| `test/replays/` | Recorded touch scenarios for `movie.ps1`. `idle.json` is empty on purpose |

## Invariants

Shared invariants (pure sim, no `randf()` in state, the hash, `_ensure_booted`, `looking_at`, the flush, freeze-before-advance, anchored HUD, `FLOAT_EPS`, headless MultiMesh colours, `global_transform`, Dictionary Variants, `use_colors`, `Basis.scaled`, `TorusMesh`, culling against the camera) are in `GODOT.md` and are not repeated here.

- **There is always a way back to a cast** — from a landed fish, from a lost one, and from a
  dead cast sitting on the bottom. A game built from an earlier version of this template froze
  at a level boundary because nothing cleared `over`, and to the person holding the phone that
  is indistinguishable from a crash. `run_smoke.gd` drives THROUGH each terminal state rather
  than stopping at it, because a suite that always stops where the content stops cannot see
  past the end of the content.
- **The Android back button unwinds ONE layer and never quits out of an open screen.**
  `quit_on_go_back=false` takes it off Godot and `_go_back()` in `main.gd` handles it: book,
  room, cinematic, title, then out. The two failures here are opposites and both ship easily —
  left at the default, back throws the morning away from inside the logbook; turned off with
  nothing handling it, back does nothing at all and a dead system button reads as a hung app.
  Which is why the project setting and the handler belong in one commit, and why
  `run_smoke.gd` asserts the unwinding rather than the setting.
- **A species is a row in `Species.TABLE`, never a class or a scene**, and **every row must be
  reachable at a real fishing depth.** The lure sinks to the bed, so a species whose range sits
  entirely above it can never be caught — it is in the table, it is a blank page in the
  logbook, and no play will ever fill it in. The bluegill shipped that way for an hour with
  every subsystem working perfectly. `test_tuning.gd` asserts it.

## Shared rules and recording

Everything general lives in `C:\dev\gamedev-notes`: the invariants every game keeps and the
engine traps in `GODOT.md`, design in `CRAFT.md`, the ship gate in `POLISH.md`. Record a
lesson the moment it is learned with `/record-lesson` (it writes to the notes' `inbox/`),
and his words with `/record-lesson playtest stillwater`. Never edit the notes' topic files from
a build session.
