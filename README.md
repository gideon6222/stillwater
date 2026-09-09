# Stillwater

A fishing game for Android, built in Godot 4.7. You start on a calm lake at dawn catching
small fish from a rowboat. Line length is the only thing that decides how deep you can go,
and depth is not a distance.

Built on the phone-game stack: a pure simulation core with no renderer in it, headless
tests, a whole-run golden, an APK size guard, CI, a build stamp and a changelog.

```powershell
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --import                                 # after adding files
& $godot --headless --path . --script res://test/run_tests.gd         # pure tests
& $godot --headless --path . --script res://test/run_smoke.gd         # boots the real scene
& $godot --headless --path . --script res://test/run_probe.gd         # balance readings
& $godot --headless --path . --export-debug "Android" build/stillwater.apk
& $godot --headless --path . --script res://scripts/check_size.gd     # size guard
& $godot --path .                                                     # open the editor
```

Every one exits non-zero on failure, which is what makes them a gate rather than something
to read.

`CLAUDE.md` has the toolchain paths and the invariants — read it before writing game code.
`NOTES.md` has what is proven, what is not, and what to do next.
