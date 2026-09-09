# Notes — Stillwater

Decisions specific to this game, and what to do next in it. General lessons belong in
`C:\dev\gamedev-notes`, not here.

## What this game is

A fishing game that starts on a calm lake at dawn and becomes deeply unsettling. The full
design plan is a published document Gideon holds; the parts the code has to honour are here.

**The one structural idea: depth is time.** The lake does not go down, it goes back. Four
metres is this year's weed; forty is a road tarred in 1931; eighty is rooftops. The fish and
the objects age together, because they are what lived here *then*. The game never says so — the
sounder gives a number, the junk carries dates, and the player does the arithmetic.

What that buys, and the reason to protect it: **the line upgrade IS the story progression.**
Buying 40 lb braid is not "more power", it is reaching back another forty years. There is no
second progression system to balance against the first, because there is only one. Any feature
that adds a parallel ladder is working against the whole design.

**Money cannot buy the bottom.** Below 80 m the hook needs an *offering* — an object you fished
up and chose not to sell — and there is a finite number of them. So a player who ignores the
story caps out at 40 m with a full wallet. That is the "what happens if they ignore this?" test
passing: the answer is not "they score less", it is "they cannot continue".

## What is proven, as of 2026-09-09 (v0.5.0, M1)

- The fresh template copy passed its own gate before a line of game code — 28 tests, 4,410
  assertions — so nothing that fails from here is inherited.
- Cast → hook → reel → land, end to end, through the real scene and the real input seam.
- 66 tests, 5,137 assertions, about a second, no display. Plus 56 smoke assertions that boot
  the actual scene and catch a whole fish through it.
- A whole-run golden over seven scripted sessions, which has earned its place twice: the first
  recording exposed stale fish state leaking through a cast made straight out of a loss, and a
  later one showed a bot that was never tapping at all.
- Screenshot at the phone's real aspect (460x996), not the project base - and `shot.gd` takes a
  STATE to stop at, because the moments worth photographing are the short ones. Three HUD bugs
  shipped at once partly because the single screenshot taken of them landed mid-fight, the one
  state in which none of them show.

## The fight, and why it is built this way

**This is the THIRD fight.** The first two are worth knowing about, because both
died of something structural rather than of tuning.

**Fight 1 — a threshold band.** Hold the tension inside a moving band, with the
band drawn on a control on the right. Gideon: *"it is too easy and I don't like
that my thumb will be blocking the gauge I am looking at."* Two faults, one root:
a threshold fight settles into **one correct sustained input** — find the thumb
position that holds the needle and there is nothing left to do but not move — and
the readout that had to be watched every frame was underneath the thumb setting
it.

**Fight 2 — pump, give, hold steady.** Three fish behaviours wanting three
different responses, no HUD at all, the rod's bend as the only instrument.
Gideon: *"it is not very intuitive to tell what you are supposed to do... I think
having visual on screen queues or gauges would be a good addition."* Also right.
Deleting the gauge was an over-correction — the answer to a gauge in the wrong
place is to move it, not to remove it — and three responses to three situations
is a lot to infer from a bent stick.

**Fight 3 is what he described**, in two rounds: *"tapping to keep the pressure on without
breaking the line... a combination of two different mini games, like one to hook
the fish and one to reel it in... visual on screen queues or gauges."*

The first round of it built minigame 1 as a **sweep bar** - a marker crossing a
green zone. His next note replaced it: *"can you make the initial hook portion of
the mini game just watching the rod or bobber pull down. make it look like a fish
is nibbling on the bait and pulling on the line. try to use other games as
reference for it."*

Right, and the reason generalises: **the bar was an abstraction sitting on top of
a thing that could simply be shown.** A float being pulled under IS the timing
cue; drawing a second, invented representation of it above the horizon asks the
player to learn a symbol for something already in front of them.

| | what you do | what it teaches |
|---|---|---|
| **1. The nibble** | watch the FLOAT. It teases - short shallow dips that pop back - then takes it properly, deeper and held. Strike on the take | judgement rather than reflex, and it is entirely in the world: **no HUD at all** |
| **2. The reel** | tap to keep the needle in the green band | rate, not position |

The reference is Animal Crossing, which is the right one to copy here. Stardew
and Zelda give a single cue with no teases, which is a pure timing test; the
teases are what make it a judgement. The tease count is drawn per bite, because a
fixed count is a metronome and two bites later the player is counting tugs
instead of looking at anything.

**The gauges are at the TOP and the tap target is the whole screen.** That split
is the settlement of both earlier notes, and it is only possible because the
input became a *tap*: a tap needs no precision of position, so the thing you look
at and the thing you touch can live at opposite ends of the screen.

**Tapping is a RATE.** The needle falls on its own, so there is no setting to
hold — doing nothing decays and doing everything overshoots. That is asserted
directly (`test_there_is_no_setting_that_wins_on_its_own`), because it is the one
property whose loss would silently return this to fight 1.

**A run climbs the needle by itself, and that is the whole instruction.** The
player sees it rising with their thumb still and works out to leave it alone. No
caption says so, and none should — a caption that says it means they read the
caption forever instead of learning the gauge.

**The JOLT is what makes the warning worth watching.** A run adds `RUN_JOLT` the
instant it starts, so what decides the outcome is whether you had *already*
stopped, not how fast you react afterwards. Left alone, a run settles just below
the band: safe, but no progress — that is its cost. Tap through one and the line
parts.

**The line is arithmetic, never a physics body.** Wrecking Crew earned this with
a wrecking ball on a `PinJoint3D`.

## Balance, measured 2026-09-09

Six seeds, ninety-second sessions, from `test/run_probe.gd`:

| policy | caught | lost | what it proves |
|---|---|---|---|
| `idle_hands` | 0.00 | 8.67 | both minigames are mechanics |
| `masher` | 0.00 | 11.83 | striking at the first twitch is almost always a tease |
| `slowpoke` | 0.00 | 2.83 | the band has a bottom; the fish takes line back |
| `blind` | 4.67 | 0.17 | ignoring the run warning costs fish — **in deep water** |
| `angler` | 4.83 | 0.00 | perfect play wins - see the warning below |
| `human` | **4.83** | **0.83** | a plausible player loses about one in seven |

Per BAND, landed by `human` from a worst-case full-length cast — the reel only,
since these start already hooked. Regenerate with
`godot --headless --path . --script res://scripts/balance.gd`, which prints every
species:

| band | landed by `human` | what the band is for |
|---|---|---|
| The Reeds | **91%** | the tutorial. A beginner keeps almost everything |
| The Channel | 72% | the first water that can beat you |
| The Drowned Road | 58% | the floor has come up; there is no filler fish left |
| Old Town | 50% | a coin flip on the prizes |
| The Quarry | 43% | most of what you hook, you lose |
| The Spring | 25% | one fish, and it is a gamble |

### Frequency teaches, power punishes, and they must not be one number

This is the balance lesson of M2 and it cost a full rebalance to find. There was
originally one difficulty knob per species, `run_chance`, and it swamped the
other two — the whole table fitted `win ≈ 1.06 − 1.15 × run_chance`, with
`stamina` and `haul` only setting how LONG a fight ran. So "harder" and "runs
more often" were the same statement, and tuning the reeds to be winnable tuned
the runs out of them. A player could finish the entire tutorial without once
seeing the mechanic the fight is built on.

`run_power` splits it. The reeds now run *constantly* at a third of the strength
and the quarry runs less often for very much more: **depth raises the stakes,
never the tempo.**

Two things had to be true for that to work:

- **The opening jolt is compressed against `run_power`; the sustained pull is
  not** (`Tuning.jolt_scale`). Scaling both fully made `run_power` a cliff —
  everything below 0.85 was landed every time, everything above it was a coin
  flip — because the spike alone decided the fight in one frame. Compressed, a
  strong fish means *hold this off for the whole run*, not *one instant decided
  it*. That is also simply the better mechanic.
- **`run_power` has a hard ceiling of `SAFE_HI × TAP_DECAY / RUN_PULL ≈ 1.99`,**
  where a run parks the needle above the safe band on its own and no play
  survives it. `test_tuning.gd` asserts every row stays clear of it. The table
  tops out at 1.48.

Difficulty response is still steep in places — a 0.04 change to four reed fish
moved that band from 84% to 100% — so tune against `balance.gd` and do not chase
precision finer than about five points. It is a 24-sample measurement.

**Read `human`, never `angler`.** `angler` is a zero-latency, perfect-information
controller and it beats any mechanic that is fair — its score says nothing about
difficulty. That is not a guess: fight 1's probe showed `angler` at 6.83 caught /
0 lost, it was written down here as "the number to watch", the build shipped, and
the first thing Gideon said was that it was too easy.

**And the model of a player matters as much as the model of the fish.** The first
version of these bots re-read the gauge every frame and tapped whenever the
needle was low — which *automatically* stops tapping during a run, because a run
pushes the needle up. The run solved itself and `blind`, `angler` and `human` all
scored an identical 100%. Nobody taps by sampling sixty times a second. Once they
held a rhythm and corrected it a few times a second, the warning became worth
something and the numbers above appeared.

**Tune the game until `human` struggles. Never tune `human` until the game looks
hard.**

**And measure a claim in the water the claim is about.** `Policies.play` could
only ever fish the starting reeds, so every assertion in the suite was secretly
an assertion about five tutorial fish. "Ignoring the run warning costs you" was
therefore being tested in the one band deliberately built so that it does not —
and when the reeds got gentler the test failed, correctly, and looked like a
regression in the game. It was a regression in the *measurement*. `play` now
takes a spot and a line, the warning claim is made on the Drowned Road, and the
reeds get their own weaker claim: a missed tell there costs TIME, not fish, so
the tutorial can be forgiving without teaching the player that the tell is
decoration.

## The two arcs, and why they are the same shape

The score and the picture are both driven by ONE number - `dread`, which is
depth, the same quantity the whole game is built on - and both move continuously
rather than switching at a band boundary.

| | Surface | The Quarry |
|---|---|---|
| bells | the whole first hour | gone, and nothing replaces them |
| what is underneath | silent | most of what you can hear |
| colour | pale gold, warm | drained to a green-grey |
| light | 2.2 with a long streak | 0.10 and no beam at all |
| fog | 0.0003 | up to the 0.011 cap |
| the bank | reeds down both sides | open water in every direction |

Three things about this are worth keeping.

**It runs backwards.** Fish the reeds after the quarry and the bells come back,
the colour returns, and the bank is there again. Nothing else in the game gives
that, and finding out the cheerful version still exists is stranger than losing
it was. It is free only because the arc is tied to depth rather than to progress.

**The layer that LEAVES does more than any layer that arrives.** An absence is
the loudest thing you can put in a score and it costs no assets.

**Both arcs are asserted, not eyeballed.** `Mood.at` is a pure function so
"night is darker than noon in every weather" and "nothing about going deeper
brightens anything" are tests; the mixer is driven at the depths the game
actually produces and checked for monotonicity AND a 20 dB span at each end. A
mix or a palette that quietly stopped changing would otherwise be an invisible
regression - nobody compares a screenshot with the one from an hour ago.

### What only screenshots caught

The suites were green for all of these:

- the logbook could never show a fish under a kilo (`int(0.14) > 0`)
- owned gear was drawn in the same dead grey as unaffordable gear
- the map printed the same true, useless sentence five times
- reeds stood in a hundred and fifty metres of open water at The Spring
- near-black gradients banded into rainbow contour rings (fixed with
  `use_debanding`) and a storm at dusk rendered as a golden sunset, because a
  grazing specular streak survives a dim sun and carries the SUN's colour

**Photograph every screen and every extreme of the arc, once, and look at it.**
`scripts/shot.gd` takes an hour, a weather and a depth for exactly this.

## Open, in rough priority order

1. **Does the third fight feel good?** Specifically: is the hook bar readable at a glance, is
   the tap rate comfortable rather than frantic, and is the run warning noticeable without
   being told what it means? "It looks fine" will not cover any of those.
2. The boat is three boxes and the fish is a sphere with two prisms. Both are deliberate for M1
   — see the asset rule — but the fish generator (spine, swept rib profile, fin set) is the next
   real piece of art work, because species is data and the wrong ones in Act III are the same
   generator with wrong numbers.
3. The water is a four-wave Gerstner sum with an analytic depth term that is currently one
   constant. When the bed becomes a heightfield, the sim uploads the field it already uses for
   the fish and the shader samples that — **do not reach for `DEPTH_TEXTURE`**, it is corrupt on
   Forward Mobile with MSAA and the simulation already owns the answer.
4. No sound at all yet. The plan is offline-generated WAVs committed to the repo; the reel click
   is the workhorse and is what will make reeling feel physical.
5. `ANDROID_DEBUG_KEYSTORE_B64` is not yet set as a repository secret. Until it is, every CI
   build is signed with a throwaway key and **Android will refuse to update the installed app** —
   each build has to be uninstalled before the next one will go on.

## Invariants specific to this game

- **`src/sim/` may not reference a Node, a Viewport, an input event or a real frame.**
- **A species is a row in `Species.TABLE`, never a class or a scene.** The wrong fish in Act III
  are the same generator with different numbers; anything that special-cases a species in code
  breaks that before it is built.
- **Every species must be reachable at a real fishing depth.** The lure sinks to the bed, so a
  row whose range sits entirely above it can never be caught — it is in the table, it is a blank
  page in the logbook, and no amount of play will ever fill it in. The bluegill shipped that way
  for an hour with nothing reporting a fault. `test_tuning.gd` asserts it now.
- **Every policy must fail for a different reason.** If two post the same numbers, one is not
  testing anything. If the one that reads the gauge ever loses to one that ignores it, fix the
  bot before touching a constant.
- **There is always a way back to a cast.** From landed, from lost, and from a dead cast on the
  bottom. A game built from an earlier template froze at a level boundary and it read to the
  player as a crash.
- **Nothing in the HUD may be positioned against a literal screen size**, and every interactive
  control owns its own input through `_gui_input`.
- **The nibble has NO HUD, and adding one undoes the whole point of it.** The float being
  pulled under is the instrument. `run_smoke.gd` asserts the float actually dips and that no
  control named `HookBar` has come back.
- **The cast STOPS above horizontal.** It lifts back, flings forward past rest, and settles -
  it never swings the tip into the water. `CAST_THROW_TO` is an absolute angle so that is a
  number you can read rather than the result of an arithmetic.
- **`TAP_KICK` and `TAP_DECAY` are coupled, and so are `RUN_PULL` and `TAP_DECAY`.** Taps per
  second is `TAP_DECAY * tension / TAP_KICK`, and a run left alone settles at
  `RUN_PULL / TAP_DECAY`. Halving the decay alone doubled the tapping rate AND moved the run
  settle point into the band; all four move together or none do.
- **The gauges live in the top third and the tap target is everything.** `run_smoke.gd` asserts
  the separation, because it is the settlement of two separate playtest notes and neither should
  come back.
- **Never set `visible` inside a `draw` callback.** A hidden Control never receives `draw` again,
  so it is a latch that can only fail closed - it shipped a build where NEITHER gauge was ever
  seen. Visibility belongs in `_sync_bars`, which runs every frame regardless. `run_smoke.gd`
  now asserts each gauge is visible in its own state AND comes back after being hidden.
- **Every state needs a way out THROUGH THE RENDERER, not just through Sim.** `reel_in()` existed,
  was tested, and passed - and nothing in `main.gd` called it, so a cast with no bite had no way
  back to the boat. Test the call the touch handler makes.
- **Rod rotation is down-positive.** A positive X rotation points the tip DOWN, so lifting back to
  cast is NEGATIVE and a fish bending it forward is POSITIVE. Both were inverted once and the
  report was "it pushes down and flings up when you let go".
- **No caption may say what to do about a run.** No "STOP TAPPING!". The needle climbing on its
  own with the thumb still is the instruction, and a caption that says it too means the player
  reads the caption forever and never learns the gauge.
- **Every caller stepping a session must hold ONE `mem` dict** for the policies. A fresh `{}` per
  frame resets the tap rhythm and the bot silently never taps - six tests and most of the smoke
  suite failed at once with "correct play landed nothing", which reads as a broken game.
- **The cast is a SWING and only a fish is a BEND.** One number drove both once and charging
  curved the rod as if a fish were on it.
- **Balance is read off `human`, not `angler`.** See the warning in the balance section.
- **The rod tip is derived from the rod's transform**, never typed twice. A hand-copied tip
  drifts the moment the rod is nudged, and the symptom is a line hanging in the air beside it.
