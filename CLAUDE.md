# Stillwater

A fishing game for Android, built in Godot 4 on the phone-game stack: a pure simulation core,
headless tests, a whole-run golden, a size guard, CI, and an APK that installs on the phone.

It starts on a calm lake at dawn and becomes deeply unsettling. **Depth is time** — the lake
does not go down, it goes back — and the line upgrade IS the story progression, which is the
idea everything else hangs off.

**Read `NOTES.md` in this repo before writing game code.** It has the design constraints the
code has to honour, the measured balance, and the invariants specific to this game.

**Read `C:\dev\gamedev-notes` too** — `SKILL.md` (process), `CRAFT.md` (design lessons, all of
which apply here), `PIPELINE.md` (the stack and the measured limits), `ASSETS.md`,
`PLAYTESTS.md`.

---

## Toolchain, and where it lives

Nothing is installed system-wide and nothing needed admin rights. Portable, under
`C:\dev\toolchain\`:

| Piece | Version | Path |
|---|---|---|
| Godot | 4.7.2 stable | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.2-stable_win64_console.exe` |
| JDK | Temurin 17.0.20.1 | `C:\dev\toolchain\jdk\jdk-17.0.20.1+1` |
| Android SDK | platform 36, build-tools 36.0.0, platform-tools 37.0.1 | `C:\dev\toolchain\android-sdk` |
| Debug keystore | | `C:\dev\toolchain\debug.keystore` (alias `androiddebugkey`, pass `android`) |
| Export templates | 4.7.2.stable | `%APPDATA%\Godot\export_templates\4.7.2.stable` |

Godot finds the SDK, the JDK and the keystore through **editor settings**, not through
environment variables — `%APPDATA%\Godot\editor_settings-4.7.tres`, keys under
`export/android/`. Setting `ANDROID_HOME` alone does nothing; that costs half an hour if
you do not know it.

## Commands

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

## Signing

**Set `ANDROID_DEBUG_KEYSTORE_B64` as a repository secret** from
`C:\dev\toolchain\debug.keystore`, base64-encoded, before the second build matters. CI
generates a throwaway key otherwise, so every build is signed differently and Android refuses
to update the app in place.

## Invariants

- **`src/sim/` may not reference a Node, a Viewport, an input event or a real frame.**
  That one rule is what makes a whole-run golden test possible and what lets the whole
  renderer be replaced without touching game logic. If something in there needs to know
  about the world, it takes it as an argument.
- **Nothing that affects game state may use `randf()`.** Place-keyed decisions go through
  `SimUtil.hash2` seeded on (chunk, level); stream-like values go through `SimRng`.
  Cosmetic jitter may use `randf()`. The trap is that "cosmetic" is not obvious — **a
  value that decides *when* something happens is simulation**, even if it looks like
  decoration. On the sibling web game, loot scatter velocity looked decorative and was
  deciding when score landed, which made the golden flake one run in ten.
- **The hash uses unsigned shifts on a masked 32-bit value.** A signed shift clears the
  top bit and the function silently returns only `[0, 0.5)` — which disabled three
  shipped mechanics on another game for its entire life, with no error. `test_util.gd`
  asserts the range and the distribution.
- **`_ready` does not run at `add_child()`.** It is deferred to the first processed
  frame, so a headless harness that adds the scene and immediately steps it finds every
  field null. `main.gd` guards this with `_ensure_booted()`; keep that guard.
- **Use `Transform3D.looking_at`, not `Node3D.look_at`.** The node method requires the
  node to be inside the tree and errors when it is not — which is exactly the headless
  case. The transform method is pure maths and works anywhere.
- **`visible_instance_count` is the flush.** Every MultiMesh is a reset → push → flush
  pipeline and forgetting the flush fails completely silently: the simulation carries on
  perfectly and nothing is drawn. `run_smoke.gd` compares the count against the model.
- **Freeze before advancing** in any harness, or results move with the speed of the
  machine.
- **There is always a way back to a cast** — from a landed fish, from a lost one, and from a
  dead cast sitting on the bottom. A game built from an earlier version of this template froze
  at a level boundary because nothing cleared `over`, and to the person holding the phone that
  is indistinguishable from a crash. `run_smoke.gd` drives THROUGH each terminal state rather
  than stopping at it, because a suite that always stops where the content stops cannot see
  past the end of the content.
- **A species is a row in `Species.TABLE`, never a class or a scene**, and **every row must be
  reachable at a real fishing depth.** The lure sinks to the bed, so a species whose range sits
  entirely above it can never be caught — it is in the table, it is a blank page in the
  logbook, and no play will ever fill it in. The bluegill shipped that way for an hour with
  every subsystem working perfectly. `test_tuning.gd` asserts it.
- **Nothing in the HUD may be positioned against a literal screen size.** The project
  stretches with `aspect = "expand"`, so the canvas is about 1080x2340 on the phone and not
  1080x1920. Anchor to a full-rect `Control`, and let every interactive control own its input
  through `_gui_input`. See the long note in `main.gd` - this has shipped wrong once.
- **A golden over floats needs `TestHarness.FLOAT_EPS`**, not exact equality. `snappedf` does
  not round-trip through a source literal, and the goldens are recorded on Windows and checked
  on a Linux runner.
- **A headless run allocates no MultiMesh buffer**, so instance colours read back as black
  there and prove nothing. Check colour in a real renderer or not at all.
- **`global_transform` outside the tree does not error - it returns IDENTITY.** In any
  harness use `transform`. `Node3D.look_at` at least has the decency to fail.
- **A value read out of a Dictionary is a Variant**, and `:=` cannot infer from one. Annotate
  the local: `var pos: Vector3 = c.pos`. Entities held as dictionaries - which is what keeps
  the scene tree out of the test runner - make this constant.

## Signing, and the two builds

There are two export presets and they are not interchangeable.

| | `Android` | `Android Release` |
|---|---|---|
| Output | `.apk` | `.aab` (what Play accepts) |
| Build | prebuilt template, seconds, no Gradle | Gradle build, minutes, ~300 MB of downloads on a cold run |
| Signed with | debug key | **upload key**, from `C:\dev\keys\upload.keystore` |
| Trigger | every push | a `v*` tag |

- **AAB export is only valid with `gradle_build/use_gradle_build=true`.** The exporter
  refuses otherwise, and the Gradle build is also the only way to set `target_sdk`, which
  Play requires to be 36 and which rises every year.
- **`--install-android-build-template` only works alongside an export command.** On its own
  it opens the editor and never returns — it burns CPU and produces nothing, which looks
  like a hang.
- **The release keystore comes from environment variables**, not editor settings:
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD`. Godot falls back to editor
  settings for the *debug* key only, so a release export without them fails with
  "Could not find release keystore" — which reads like a missing file rather than a missing
  setting. The env vars are the right shape for CI anyway: the password never touches a
  committed file.
- **Set `GRADLE_OPTS=-Dorg.gradle.daemon=false` for any release export.** Without it Godot
  writes a perfectly good bundle and then **never exits** — Gradle forks a daemon that
  outlives the build and Godot waits on it. Measured: 0% CPU for eight minutes with the AAB
  already on disk. With the daemon off it exits 0. In CI that difference is a job that
  burns until the timeout with nothing actually wrong.
- **Verify the artifact, not the exit code.** This export has returned -1 while producing a
  valid bundle, and returned 0 while producing nothing. Check the file exists, is a
  plausible size, and passes `jarsigner -verify`.
- **Do not invoke it through PowerShell's `Start-Process -ArgumentList`.** It joins
  arguments without quoting, so the preset name `Android Release` arrives as two arguments
  and Godot exports the *`Android`* preset to a file called `Release` — which fails with
  `Invalid filename! Android APK requires the *.apk extension`, a message about nothing to
  do with the mistake. `scripts/export_release.bat` exists to pass the quotes through.
- **Keys live in `C:\dev\keys`**, outside every repository, and `android/` is gitignored
  because it is the export template unpacked, not source.
- See `PLAY.md` in `gamedev-notes` for the store side, and `PRIVACY.md` here for the policy
  every Play listing requires even when nothing is collected.

## Things the exporter will not tell you clearly

- `rendering/textures/vram_compression/import_etc2_astc=true` is **required** for an
  Android export. Without it the export fails with a message about Project Settings.
- A `config/icon` is required, or the export errors even though it still writes a file.
- `gradle_build/use_gradle_build=false` uses the prebuilt template and needs no Gradle
  at all. Turn it on only when a plugin or a custom target SDK demands it — and check
  the target API level against Play's requirement when you do.

## Record as you go

Write lessons into `gamedev-notes` **in the same commit as the change that taught them**,
never at the end of a session. Several games run at once; a lesson recorded after this one
finishes is one the next game never got.
