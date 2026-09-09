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

## What is proven, as of 2026-09-09 (v0.4.0, M1)

- The fresh template copy passed its own gate before a line of game code — 28 tests, 4,410
  assertions — so nothing that fails from here is inherited.
- Cast → hook → reel → land, end to end, through the real scene and the real input seam.
- 60 tests, 5,227 assertions, about a second, no display. Plus 45 smoke assertions that boot
  the actual scene and catch a whole fish through it.
- A whole-run golden over seven scripted sessions, which has earned its place twice: the first
  recording exposed stale fish state leaking through a cast made straight out of a loss, and a
  later one showed a bot that was never tapping at all.
- Screenshot at the phone's real aspect (460x996), not the project base.

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

**Fight 3 is what he described:** *"tapping to keep the pressure on without
breaking the line... a combination of two different mini games, like one to hook
the fish and one to reel it in... visual on screen queues or gauges."*

| | what you do | what it teaches |
|---|---|---|
| **1. The hook** | a marker sweeps a bar; tap while it is in the green | timing, and that the bar must be *looked* at — the zone moves every bite |
| **2. The reel** | tap to keep the needle in the green band | rate, not position |

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
| `idle_hands` | 0.00 | 9.00 | both minigames are mechanics |
| `masher` | 0.00 | 12.67 | tapping flat out is the fastest way to lose |
| `slowpoke` | 0.00 | 4.17 | the band has a bottom; the fish takes line back |
| `blind` | 5.50 | 0.33 | ignoring the run warning costs fish |
| `angler` | 5.67 | 0.00 | perfect play wins — see the warning below |
| `human` | **5.33** | **0.67** | a plausible player loses about one in nine |

Per species, landed by `human` from a worst-case full-length cast — the reel
only, since these start already hooked:

| species | landed | seconds | taps |
|---|---|---|---|
| Bluegill | 92% | 10.8 | 27 |
| Yellow Perch | 67% | 14.0 | 34 |
| Largemouth Bass | 50% | 19.1 | 45 |

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
- **The gauges live in the top third and the tap target is everything.** `run_smoke.gd` asserts
  the separation, because it is the settlement of two separate playtest notes and neither should
  come back.
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
