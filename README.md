# Stillwater

A fishing game for Android, built in Godot 4.7. You start on a calm lake at dawn catching
small fish from a rowboat. Line length is the only thing that decides how deep you can go,
and depth is not a distance.

Built on the phone-game stack: a pure simulation core with no renderer in it, headless
tests, a whole-run golden, an APK size guard, CI, a build stamp and a changelog.

```powershell
scripts\check.ps1                     # the gate: import, tests, smoke, size. ~15 s
scripts\check.ps1 -Export             # ...and build the APK, then check its size

scripts\movie.ps1 -Seconds 10 -Name idle    # film a run into a contact sheet
scripts\device.ps1 install ; scripts\device.ps1 launch   # onto the phone over adb

$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --script res://test/run_probe.gd         # balance readings
& $godot --headless --path . --script res://scripts/balance.gd        # the difficulty table
& $godot --path .                                                     # open the editor
```

Every one exits non-zero on failure, which is what makes them a gate rather than something
to read.

`PLAN.md` is what the game is meant to be, and its section 12 is the milestone list.
`CLAUDE.md` has the toolchain paths and the invariants — read it before writing game code.
`NOTES.md` has what is proven, what is not, and why each decision went the way it did.
