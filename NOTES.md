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
- 96 tests, 10,804 assertions, under five seconds, no display. Plus 327 smoke assertions that
  boot the actual scene and catch a whole fish through it. (This line said 66/5,137 for a
  while after it stopped being true — a count in prose is stale the moment a test is added,
  so read it as an order of magnitude and run `scripts\check.ps1` for the number.)
- A whole-run golden over seven scripted sessions, which has earned its place twice: the first
  recording exposed stale fish state leaking through a cast made straight out of a loss, and a
  later one showed a bot that was never tapping at all.
- Screenshot at the phone's real aspect (460x996), not the project base - and `shot.gd` takes a
  STATE to stop at, because the moments worth photographing are the short ones. Three HUD bugs
  shipped at once partly because the single screenshot taken of them landed mid-fight, the one
  state in which none of them show.

## The tools, and what each one has actually been run on

Framework v2 landed here on 2026-09-09. Every tool below has been run on this game rather
than merely copied in, because the template's own notes shipped them marked "not yet run on
this machine".

| Tool | Proven by |
|---|---|
| `scripts\check.ps1` | The gate, green: import, 97 tests / 10,810 assertions, 327 smoke, size. ~15 s |
| `scripts\movie.ps1` | Filmed `idle` and `first-cast`. Contact sheets read correctly |
| `scripts\replay_player.gd` | `first-cast.json` drives the title, the gate, the walk down and a cast |
| `scripts\device.ps1` | **Not yet** — needs the phone on the desk. `/playtest phone` is the next thing |

The one number to know before filming: a second of film is about 60 full-resolution PNGs and
150 MB, so sixteen seconds is 2.4 GB and several minutes. Film the shortest run that shows
the thing, and `build/` is gitignored, so clear `build/movie/*/frame*.png` when done.

## The feel pass of 2026-09-10, as numbers

Every one of these was a complaint that survived being looked at in a screenshot,
and every one turned out to be structural rather than a tuning value.

| | before | after | what it was |
|---|---|---|---|
| Camera pitch | 20.0 deg p2p, 41.9 deg/s | 0.26 deg, 0.42 deg/s | the camera was bolted to the hull |
| Camera roll | 18.0 deg p2p, 36.2 deg/s | 0.71 deg, 1.15 deg/s | same |
| Hull pitch | 20.0 deg p2p | 2.15 deg | exaggerated 4.2x to make an unmovable horizon move |
| Hull roll | 18.0 deg p2p | 4.36 deg | it pitched further than it rolled, which is backwards |
| Wave amplitude | 0.16 m | 0.063 m | a 32 cm swell on a lake called Stillwater |
| Float height error | up to 1.3 m | under 0.02 m | it rode `_boat_pose`, not the water |
| Seat position | z = -1.90 | z = +0.70 | 1.05 m BEHIND the transom, outside the boat |

**The pattern across all of them: two things that had to be different were driven
by one value.** The camera and the hull. The float and the boat. Where a complaint
survived a correct fix, the fix was correct and the structure was not - see the
lesson filed in the knowledge base, which is the general form of it.

**And the instrument was the thing that was missing, again.** None of these is
visible in a still frame. `scripts/probe_motion.gd` reports peak-to-peak, RMS,
frequency and peak angular RATE for the hull and the camera; the rate is the number
that predicts discomfort and it is the one nobody looks at.

## The FOURTH fight: hold to reel, and greed is the risk dial (2026-09-10)

Gideon: *"there is no dedicated button to fill the bar. I want a button instead of just
tapping the screen. it is also not obvious that the fish will pull back and add pressure to
the bar... I want an obvious mechanic change, that uses the same principle but implements it
in a better way."*

Three changes. Researched against shipped fishing games; Ace Fishing is the closest one-thumb
analogue and is hold-to-reel for the same reason.

**1. Held, not tapped.** One dedicated control, one resting state. `HOLD_RISE` replaces the
tap's instant kick, and `tap()` lost its FIGHTING branch rather than being left as a second
way to add tension.

**2. The haul scales with height in the band** (`Tuning.greed`, 0.62 at the bottom to 1.62 at
the top). The band was pass-or-fail, so the correct play was the middle and there was nothing
to weigh. Now the fastest water is the inch below the strain zone. This is the change that
makes it risk/reward rather than maintenance.

**3. The run is telegraphed on four channels** - the wake, the tell lengthened to 0.65 s, the
action button going cold, and its caption changing to LET GO. Research puts a readable
telegraph at 0.25 s minimum and 0.25-1 s of wind-up.

### The trap that cost the most, and it is the first fight in disguise

A held button settles where rise balances decay: `HOLD_RISE / TAP_DECAY`. The first attempt
derived HOLD_RISE from the old tap rate and landed that at **0.60 - inside the band**. So
holding the button down parked the needle in the green and reeled the fish in with no further
input. That is "one correct sustained input", which is exactly what killed fight 1, arrived at
from the opposite direction and while adding a feature meant to improve things.

**What caught it was the invariant that every policy must fail for a different reason**:
`blind` and `angler` posted identical 5.83/0.00. The settle point is now 1.10, above
`TENSION_MAX`, so a held button always ends in a snapped line.

And the old test would not have caught it either. `test_there_is_no_setting_that_wins_on_its_own`
checked two tap rates, zero and thirty, and passed. **Swept across the whole range it would
have failed** - tension settles in proportion to input rate, so some middle rate has always
parked the needle in the band. That was as true of tapping as of holding; the test was never
asked. It now sweeps eleven duty cycles, in DEEP water, and compares against active play
rather than a typed-in number of seconds.

### Measured after the change

| policy | caught | lost | what it proves |
|---|---|---|---|
| `idle_hands` | 0.00 | 7.33 | both minigames are mechanics |
| `masher` | 0.00 | 14.17 | holding the button forever always parts the line |
| `slowpoke` | 0.00 | 4.00 | too timid to reel is still a loss |
| `blind` | 5.17 | 1.33 | ignoring the tell costs fish |
| `angler` | 5.33 | 0.83 | perfect play - read `human`, never this |
| `human` | **4.83** | **1.50** | a plausible player loses about one in four |

Land rate by band, from `scripts/balance.gd`: **100 / 83 / 63 / 38 / 23 / 17 %**. Monotonic
with real gaps. The old ladder was 91/72/58/50/43/25, so deep water is harder than it was -
the shape is right and the depths want another pass with the species table, which was tuned
for the old dynamics and has only been nudged here (channel run_power +18%, reeds -12%, and
the Spring hardened on stamina and haul rather than on runs, which do not govern it).

**`jolt_scale` is what keeps the tutorial forgiving**: at 0.55 + 0.45p a reeds fish still took
70% of the jolt and the reeds took five fish off a beginner. At 0.18 + 0.82p a weak fish takes
half and a strong one takes more, which widens the ladder from both ends at once.

**And the tell is measured in two different waters now**, which is what this file has always
said and what that test had stopped doing: forgiveness in the reeds (a beginner loses no
fish), a real cost on the Drowned Road (they land fewer). Measuring it in TIME stopped working,
and the reason is the mechanic itself - letting go on the tell decays the needle to about 0.47
and the jolt then lands it near the TOP of the band, where greed hauls hardest, so reacting
correctly is not merely safe, it is briefly faster.

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
- **`run_power` has a ceiling, and the fifth fight moved where it comes from.**
  It used to be arithmetic on the safe band: above about 1.99 a run parked the
  needle above the band on its own and no play survived it. The band is gone with
  its needle. What a strong fish does now is resist the REEL, so the cap is
  `RESIST_MAX` and the assertion is `test_no_fish_is_a_reflex_test`. The table
  still tops out at 1.48.

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

## The sounder is the story, not a fishing aid

It costs 1200 - the most expensive thing in the shed - and buys **no fishing
advantage whatsoever.** No better bites, no bigger fish, no wider band. It buys
knowing what is under the boat.

That is the whole design. A depth column with the bed's own silhouette drawn
from `World.BOTTOMS`: weed in the reeds, a dead flat level line at the Drowned
Road that is unmistakably not natural, rooftops and one tall thin spike at Old
Town, quarry walls below that. At The Spring the bed does not come back at all.

**The player reads the bottom long before they can reach it.** Buy the sounder
with 40 lb braid and the steeple is on screen forty metres below anything the
line will touch, and nothing in the game says a word about it. The dates on what
comes up explain it hours later; the shape was there the whole time.

Two things it needed to actually work:

- **Vertical exaggeration**, as a real sounder has. At true scale an eleven-metre
  steeple in eighty metres of water is a fourteen per cent tick that reads as
  noise on the bed. `SOUNDER_RELIEF` is 2.4, capped so a tall structure cannot
  fill the column and hide the water the fish are in.
- **A panel, not a ribbon.** The first version ran most of the screen height down
  the left edge, over the boat and the rod, with the silhouette squashed into the
  last inch. Everything it draws is metres straight off the sim, so the trace and
  the rules cannot disagree - it is not a second model of the lake, it is the one
  the fish are in.

## Render settings, and why each one is there

These are three lines of configuration that between them changed the look of the game more than
any modelling session did. Written down because every one of them defaults to the wrong value for
this game, and because the first two are invisible in the editor.

| Setting | Value | Why |
|---|---|---|
| `mipmaps/generate` on every texture `.import` | `true` | Godot's default is **false**. Every surface here is a plank, a rail or a lake seen almost edge on with the grain tiling 7-20x across it; without mipmaps that aliases into a dither of black-and-tan speckle over the whole boat, which does not scale away at higher resolution and reads as compression noise |
| `textures/default_filters/anisotropic_filtering_level` | `3` (16x) | Mipmaps alone trade the speckle for a blur *along* the grain, because a grazing pixel's footprint is a long thin smear. Anisotropic keeps both. **The project setting does nothing on its own** - `StandardMaterial3D` defaults to the non-anisotropic filter, so `_wood_mat` and the stone materials set `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC` themselves |
| `anti_aliasing/quality/msaa_3d` | `1` (2x) | Everything in this game is a long thin edge - a gunwale, a reed, a rod, a plank. On a tile-based mobile GPU MSAA resolves inside tile memory, and this phone measures 5 ms a frame at the 50th, 90th and 95th percentile |

Cost: the APK went 32.4 -> 35.6 MB, all of it the mip chains. There is no download-size
constraint on this stack; the budget in `size-budget.json` was moved to match.

`test/test_assets.gd` asserts the first one, and that everything is VRAM compressed. It is a
pure test that walks `res://assets` and reads the `.import` files - no GPU, no scene - and it
exists because `.import` files are regenerated whenever a source file changes, and because the
next texture anybody adds will arrive with the default again.

## Diagnosing a graphical artefact: sample the pixels first

A dashed white hairline ran the length of the port gunwale in every screenshot ever taken of this
boat. It was chased as specular aliasing, as a sharpening filter and as a bad roughness map. What
settled it was reading the pixels: the bright ones were `(232,234,235)` - neutral, exactly the
sky - while every lit surface near them was warm. **Sky-coloured pixels in the middle of a model
are a hole**, and the hull had one where the swept skin and the swept gunwale met edge to edge.

Two tools came out of that, both worth keeping:

- `scripts/shot.gd` honours a `SHOT_HIDE` environment variable and hides every node whose name
  contains it before the shutter. "Is that a gap onto the sky or a highlight on the rail" is one
  screenshot with the rail off.
- The rails are named `GunwalePort` and `GunwaleStarboard`. They were both called `Gunwale`,
  Godot renamed the second on `add_child`, and `SHOT_HIDE=Gunwale` then hid one rail, printed
  success, and sent a whole pass looking at the wrong side of the boat.

## The FIFTH fight: distance is the score, tension is the danger (2026-09-11)

Gideon, after playing the fourth: *"I think we are not showing a different between reeling
speed and tension on the line... there should be a give and take, where you can keep reeling
but risk losing the fish, but if you get in a good rythem and wear the fish out, you can reel
while the fish is calm and stop when it starts pulling too hard."*

**He named the fault in the MODEL and he was right.** One `tension` value was the throttle
(holding raised it), the score (progress happened inside a band) and the danger (a run raised
it) at once, so none of the three could be read. The fourth fight made that value a hold
instead of a tap, which improved the control and left the conflation exactly where it was.

Three quantities now, each answering a different question:

| | what it is | where the player sees it |
|---|---|---|
| `fish_distance` | PROGRESS | the distance meter, top of screen |
| `tension` | DANGER, and only danger | the ROD: bend, shake, the line going red |
| `fish_stamina` | the resource that turns danger into progress | nowhere. It is FELT, in the reel |

**The fish fights the reel, and a spent one does not.** A held reel settles at
`HOLD_RISE * resist / TAP_DECAY`, and `resist = 1 + RESIST_GAIN * run_power² * stamina_left`,
capped at `RESIST_MAX`. Squared, because a linear term could not separate the tutorial from
the deep without making the tutorial tense. The settle tension against a FRESH fish of each
band's mean power:

| water | settle | what that means |
|---|---|---|
| The Reeds | 0.63 | hold the button down, nothing happens. Where it is learned |
| The Channel | 0.75 | visibly bent, still safe |
| The Drowned Road | 0.78 | exactly the danger line: hold it and strain creeps |
| Old Town | 0.96 | real feathering. A held button parts the line |
| The Quarry | 1.01 | feather hard |
| The Spring | capped | the Old Fish cannot be held at all while fresh |

That ladder is free: `run_power` already has to climb with depth by rule, so one species stat
pays for the runs AND for the resistance and the two cannot drift. And because `stamina_left`
multiplies it, **wearing a fish out is felt in the CONTROL** — the button that parted the line
at the start of the fight can be held flat at the end of it.

### The constants, and what each one was measured against

| | value | why |
|---|---|---|
| `HOLD_RISE` / `TAP_DECAY` | 0.69 / 1.25 | ×2.5 on the fourth fight's pair. At 0.276/0.50 the time constant was 2 s, and a quantity that slow cannot carry a decision: a 0.30 s reaction lag reached 0.747 against a settle of 0.96 and never crossed the danger line. Feathering was free |
| `RESIST_GAIN` | 0.45 | fits the six-band settle ladder above |
| `RESIST_MAX` | 1.9 | uncapped, the Old Fish settled at 1.36. ANGLER landed 44% of them; HUMAN — the same policy with 0.30 s of lag — landed NONE and parted the line on three quarters. A gap that size between perfect and human play is a dexterity wall |
| `PULL_RISE` | 1.05 × power² | squared, like `resist`. Linear, it made the TUTORIAL part a line: a reeds fish held through one run pinned and broke off in 1.2 s |
| `RUN_GAIN` | 3.9 | swept: 3.4 gave 100/99/88/65/31/4 and the Channel was not a step up; 4.4 started losing fish to beginners in the Channel |
| `RUN_HOLD` | 0.40 | holding on BRAKES a run rather than out-hauling it. As an additive reel term it bought back a third of a metre out of twelve, so "keep reeling and risk it" was never a real option |
| `ESCAPE_MARGIN` | 18.0 | six metres was ONE run. A traced Longnose Gar ended at 4.2 s: its first run took it from 22 m to 28 m and it was gone, with the player's only decision worth a third of a metre |
| `STRAIN_RECOVER` | 0.025 | at 0.12 a fight had no memory of mistakes, so nothing accumulated and "eventually snaps" was never true |
| `TIRE_PRESSURE` | 0.10 | pressure tires the fish, so the greedy line is genuinely faster. Without it the player had no lever on the length of a fight at all — deep fish were slow rather than hard |

### Landed by band, and what it means

`human` bot: **100 / 100 / 100 / 99 / 72 / 56.** `blind`: **100 / 100 / 99 / 85 / 59 / 38.**
`masher`, which never lets go: 91% in the reeds and nothing at all in the Quarry.

**The first three waters are a reliable win for a competent player, and that is a property of
the model rather than a tuning miss** — a weak fish cannot escape someone feathering well,
whatever its stats say. `test_the_bands_form_a_difficulty_ladder` was rewritten to say that:
never easier going deeper, a real total drop, and real steps in the deep half. It used to
demand better than three points between EVERY pair, which this model cannot honour at the
shallow end. **If that flatness is wrong, it is a design decision and not a bug** — the honest
lever is giving easy water a loss mode a careful player can still hit.

### Two probes that paid for themselves in one run each

- **`scripts/probe_loss.gd`** splits losses by cause per bot per band. Its first run said *no
  fish can be lost anywhere in the game* — which was a fact about a GDScript closure, not
  about the game (see the lesson). A trace of one fight contradicted it in two minutes.
- **`scripts/probe_rod.gd`** prints where each part of the rod lands as a fraction of the
  viewport. The reel was **more than a full viewport width off the left edge** at the phone's
  real 19.5:9, so the bend, the shake, the red line and the new reeling animation were all
  invisible on the device. It looked fine in a screenshot taken at the wrong aspect.

### What the player sees and feels, and its numbers

- **The reel handle turns** while the button is held and stalls to `REEL_SPIN_STALL` (0.22)
  while the fish takes line, so the handle is a second readout of the meter. The rod's pump is
  keyed to the crank's own angle so the two cannot drift.
- **The line reddens `LINE_WARN_FROM` (0.18) BEFORE the danger line**, not at it. A colour that
  arrives once the damage has started is a verdict, not a warning.
- **Two haptics, both discrete.** 22 ms at 0.35 when the fish goes; 55 ms at 0.9 repeating
  every 0.17 s while over-bent. A pulse train, never a hum — Android's guidance is explicit
  that continuous vibration costs battery, desensitises the hand in seconds and is an
  accessibility problem. **`permissions/vibrate` was missing from both export presets**, so
  every haptic this game had ever fired was silently discarded on the phone.
- **The rod mount is `(-0.08, 0.96, 1.38)`**, measured in three sweeps. The reel lands at
  x 0.47–0.61, y 0.78–0.82 of the frame across five seconds of swell.

## Phases W, P, G and T, as numbers (2026-09-11)

### W — the water and the art pass

- **`boujie_water_shader` was deliberately NOT imported.** It brings its own waves, and this
  game's wave sum is shared with the CPU — `_wave_offset` floats the bobber, heaves the hull
  and hangs the line. Swapping the surface would break that agreement or mean re-deriving it,
  to gain a look this shader already has. What W1 actually wanted was the boat sitting IN the
  water, which is the foam.
- **The foam is analytic**, because `DEPTH_TEXTURE` is corrupt on Forward Mobile with MSAA.
  The surface is told the hull's pose every frame; `HULL_FOAM_MID` is 0.70 because the hull
  runs z −0.85 to 2.25 and an ellipse on the origin rings the water astern of the transom.
  Band width **0.80 m**: a third of a metre is right for a boat and about fifteen pixels from
  the seat at a grazing angle. Found by widening it to 2.5 m in a diagnostic, which showed the
  collar had been in exactly the right place the whole time and simply too thin.
- **Overcast was 55% of the STORM panorama**, so the four non-clear weathers were one sky at
  four strengths. `overcast_soil_puresky` is a second cloud layer laid UNDER the storm one — a
  storm is towers standing on an overcast base. `SKY_PALL_FROM_DREAD` 0.46 flattens the sky as
  you fish deeper, on a clear day as much as a wet one.
- **The hull had a normal map and a roughness map and no albedo texture at all** — every plank
  was a flat tint with relief lit across it. Moved onto the shed's plank set; the second wood
  set it replaced is deleted.
- **Five real hands in the logbook**, assigned chronologically: Crake in a 1680s English cut,
  Vance in a slow upright penmanship hand, Moss and Alder fast and modern, the player the
  roundest. The `size` in `Book3D.HANDS` is a MULTIPLIER, not a size — these faces have wildly
  different x-heights and one number per face is what stops the book reading as five point
  sizes rather than five people.
- **`Manrope` is the project default font** so UI chrome can never be mistaken for the
  logbook. The three `draw_string` sites needed doing by hand: `draw_string` takes a Font
  directly and never consults the theme.
- **The oar and the dawn chorus** are the only two sounds not generated. 9.6 MB of field
  recording became 240 KB. `-ss` AFTER `-i` decoded these Vorbis files to SILENCE — right
  durations, −91 dB levels — and a 6 KB file for 24 s of audio is itself the tell.
- **W3 is deliberately unticked.** Those are textures for the drowned town's geometry, and
  Phase P has only just started building it.

### P — the lake as a place

- **Six landmarks, none repeated**, at **78–118 m**. The first pass put them at 30–44 m and
  every one filled the frame: a quarry face you cannot see the top of is a wall you are moored
  against, not a place across the water.
- **Rock is not masonry.** `_stone_mat` is a block wall, right for the steeple and the
  boathouse because those are buildings; on the quarry it read as a forty-metre garden wall
  standing in a lake. `_rock_mat` is the same map at an eighth the scale, pulled grey-green.
- **Rowing swaps the water under `Sequence.ROWING_SWAP` (shot 2)**, which looks at open water
  and nothing else — the only moment the swap can happen without something popping. A cut
  crossing still arrives, and a refused one plays nothing.
- **Sleeping turns the hour under `SLEEP_SWAP`** with nothing in frame but the sky it turns,
  and the mood runs at ×4 while your eyes are shut. **It also fixed a hole R5 left: sleeping
  lived on the old map screen, and when the dock went the hour could not be changed at all.**
- **P6 reads the keeper's own book back.** `caught_at` is `spot -> {hour: count}`, and
  `Sim.best_hour_at` needs two fish at one hour and no tie. **The restraint is the feature** —
  reading `Species.TABLE` to print which fish bite at dusk would be the strategy guide in the
  box.

### G — the game underneath

- **`HOUR_SECONDS` 360.** The note on `TIRE_RATE` has claimed since the fifth fight that
  waiting a fish out "costs the clock, which is the one resource this game says is scarce".
  That was false: the hour only changed when the player asked. Six minutes is chosen against
  the FIGHT — a deep fish takes one to two minutes, so an hour holds three or four attempts.
- **The lamp finally does something.** Night is `DARK_NIGHT_BITE` 0.18 of daylight without one
  and `LAMP_NIGHT_BITE` 0.75 with. It does not hold the sun up; it buys hours that are already
  dark, which is why it is last on the shed's shelf.
- **The fish stays in your hands until you decide** (G2). No timer on the choice. What you
  CAUGHT goes in the book either way; what you KEPT is the choice. A fish too big says
  "Too big" rather than greying out with no reason.
- **A boot takes livewell room** (G1). Junk used to pay out the instant it broke the surface,
  which made the bottom of the lake a slot machine and the boat infinite. ONE list, because
  two capacities would be two spaces and the decision would evaporate. Weights: junk 0.8,
  story 2.2, offering 0.4. An offering is the exception and goes straight to the bait box.
- **Bait is read on the float** (G3). `BAIT_TAKE_BONUS` 0.55 longer take on the right bait,
  `BAIT_WRONG_TAKE` 0.72 shorter on the wrong one, and one extra tease. `take_window_now` is
  the single source: the float's dip, the clock that runs the take and the judgement of a clean
  set all read it.

### T — the seams

- **No title after the first launch.** A returning player walks straight down. Starting again
  moved to the settings room behind a confirm — and the guard checks it is still REACHABLE,
  because removing the only door to it is the whole risk.
- **The app now pauses when backgrounded.** Android leaves a paused process alive, so the lake
  ran on behind a phone call: the clock advancing, a hooked fish still pulling. `paused` is
  deliberately separate from `frozen` — the first is the phone's switch, the second the test
  harness's.
- **Both export presets shipped the Godot logo.** The launcher icon slots were empty and Godot
  does not rasterise the project SVG into them. There is a real icon now at 512/432/192,
  drawn for a launcher: three shapes, one accent, and the red float is the only thing in it
  that is not the game's palette. The launcher PNGs are excluded from the mipmap and VRAM
  checks, with the reason written down.

### Size

**The APK is 43.71 MB** (budget `size-budget.json`). The shed took it to 64.58 MB and CI
caught it at +81%; the local `size` step had PASSED because it measures whatever APK is
sitting in `build/` and mine was stale. **Run `scripts\check.ps1 -Export` when assets
change.** The cut was `process/size_limit`: 512 across the shed and 256 on the five props that
are only ever background. VRAM-compressed textures are a fixed rate per pixel, so how well the
source JPEG packs is irrelevant.

## The harness can lie, and here is how (2026-09-11)

**A test that throws half way through is reported as PASSING.** A new test called
`sim._begin_tug()` — a method I had invented. GDScript threw, the test body aborted at that
line, and the runner printed `107 tests, 10877 assertions, all passing`. Every assertion after
it silently did not run, including the only one that could catch a real bug. **Then the
verification step was fooled too:** reintroducing the bug still passed, because the check was
unreachable.

The only signal was the assertion COUNT moving by four when the new test had eight. The smoke
suite has `MIN_ASSERTIONS := 390` for exactly this reason after a rename dropped fifteen
checks; **the pure suite has no such floor.** That is the first thing worth fixing and it is
now a milestone (T5).

Two more of the same family, both found this session:

- **A comparison that varies two things measures neither.** "The right bait means more teases"
  compared a bluegill on worms against a CARP on worms — two species, two base tease counts,
  two RNG draws. It reported 3 against 3 and would have reported something for any pair.
- **`test_the_catch_is_in_the_livewell`'s containment bound was loose enough to admit the bug
  it was written for.** It allowed nine tenths of the bucket's width and the bug lands at two
  thirds. A containment check that passes with the bug in it is not a containment check.

**Fixed 2026-09-12 (T5), in three layers, and the fix is in the template too.** The harness
installs a `Logger` through `OS.add_logger` and counts every non-warning error the engine
prints; `begin` closes the previous test and `end` the last, and a test whose body raised an
error FAILS with the error's own text, file and line. Verified by reintroducing the bug: the
runner now prints `Nonexistent function 'no_such_method'` and the line it was called on. A
test that asserts nothing also fails (ported from the template), and the pure suite has a
floor of 10,900 assertions with a nag when the live count outgrows it by 400. **The
asserted-nothing rule found a real one on its first run**: `test_an_offering_is_never_a_trade`
hooked at 150 m, where no offering row reaches, so its assertions sat inside an `if` that was
never true and it had passed vacuously since the day it was written. It hooks at 125 m now,
until an offering comes up, and fails as itself if one never does.

## Working agreement (2026-09-11)

**Gideon reviews by screenshot.** He is frequently unable to run a build when the work lands
("I can't test currently, but I can check screen shots"). So: **a screenshot of every change
that has a visible result, at every check-in**, shot at the DEVICE aspect —
`godot --path . --resolution 460x996 --script res://scripts/shot.gd -- <args>`. A desktop
window shot is nearly square and hides anything near an edge; that is how a rod a full
viewport off the left edge passed review. For a change that only exists mid-animation, add a
shot mode that stops the clock inside it rather than reporting that it is hard to capture.

`scripts/shot.gd` grew modes for this: `turn` (mid page-turn), `inshed`, `hull` (the waterline
over the side), `stow` (the port side), `chart`, `well`, and a sixth argument that names the
spot so each landmark can be photographed.

## The bot that holds a thumb (2026-09-12)

**`scripts\movie.ps1 -Seconds 30 -Name policy-angler -UserArgs policy=angler` films any
build being PLAYED, through the real buttons.** The template's policy driver could only
drag, and this game is played entirely by pressing and holding one button, so the template
grew a second, optional contract and this game was the first to pay it: `bot_touch_pixels`
returns where the thumb is down (or `Vector2.INF` for up) and the driver turns the edges into
real touches on finger 1. What it taught:

- **`Policies.act` is now `apply(wants(...))`.** The filmed bot reads the verb and presses
  the button that calls the sim; the balance bots read the same verb and call the sim. One
  decision, two seams, and the gate asserts asking never changes `state_snapshot()`.
- **A one-frame press needs an explicit lift frame.** Strike and Keep are presses; the reel
  that follows a strike is a hold on the SAME button. Without `bot_lift` in `mem` the thumb
  never came up, no second `button_down` fired, and the fish was never reeled - the film
  showed a caption reading Reel over a thumb that was already there.
- **The bot reads the caption.** At "No room" or "Too big" the sim's `keep_fish` would put
  the object down but the button refuses, so the bot takes the other door, like a player.
- **The front door is pressed, not bypassed.** `TitleScreen.entry_button()` is Continue when
  there is a save and New game when there is not.
- **Off-tree, a container's children have no size and anchored controls report offsets.**
  The pure suite boots `main.tscn` without a tree (1.3 s) and `has_point` against the title's
  button failed on a zero-size rect at `(150, -760)`. The test asserts WHICH button the bot
  reached for; whether a press lands inside it is the film's job.
- **The pure suite is 15 s, not the "~1 s" `CLAUDE.md` claimed.** Measured per file:
  `test_golden.gd` 10.3 s, `test_replay_policy.gd` 2.7 s, everything else under 0.6 s
  together. The seam run stops at the first landed fish for that reason.
- **The intro's "look around" beat stalls a filmed bot on a fresh save.** No policy looks,
  and the stick is the only way to look, so the hint stays up. Harmless to the film and
  noted rather than fixed: a bot that wiggles a stick to satisfy a tutorial is a bot lying
  about the player.

## The cast is one motion (F5, 2026-09-12)

**"The movement has felt odd" was a number.** `scripts/probe_cast.gd` samples the rod butt's
pitch every frame through a charge, a throw and the settle and reports the largest change in
angular velocity between two frames. Before: at the release the rod went from 54 deg/s
backwards (the linear lift) to 361 deg/s forwards in ONE frame for a 0.55 s hold, and 671 at
full charge - the lift, the throw and the settle were three eases that shared no state, so
the release restarted the motion at the ease-out's peak speed. The other two boundaries were
already continuous (0 to 0 deg/s).

The swing is one damped spring now (`_spring_swing`), the ONE state all three phases drive
toward a different target: the charge while loading (lagging it, `CAST_LIFT_TIME` 0.22 s,
which is what makes the lift start and stop like an arm), `CAST_THROW_TO` on release
(`CAST_SWING_TIME` 0.20 s), rest for everything else (`CAST_SETTLE_TIME` 0.55 s). The
frequency is derived from the arrival time (`omega = 3 / (zeta * seconds)`, three time
constants of the envelope) so the numbers in the file are the ones a person would tune.
`SWING_DAMPING` 0.8 gives 1.5% overshoot, which on the throw is 0.1° past the stop. And
**the spring alone was not enough**: a stiff spring's first frame IS a step, so
`SWING_ACCEL_MAX` 7200 deg/s² bounds the reversal to a ramp of 120 deg/s per frame.

After: the worst single-frame step is 120 (the cap, by design) for every hold length, the
throw still peaks at 278 deg/s for a 0.55 s hold and 531 at full charge (a whip, not a
lever), and the tip tops out at -5.9°, above horizontal. The smoke check asserts the step
under 150, the peak over 200 and the tip under 0 - so raising the cap past the step's
threshold, or damping the whip away, both go red. `_ease_out` had no other caller and is
gone. Still owed: F6 and F7 need the phone, which was not attached this session.

**B8 rides on the same spring.** The butt's position is `ROD_MOUNT + CAST_HAND_TRAVEL *
(swing / CAST_BACK)`: 0.25 m back and 0.10 m up at full lift, 3 cm forward on the throw. One
state drives the rotation and the translation, so the hands cannot lead or trail the rod. At
full charge the grip fills the bottom-right corner and the reel foot touches the Cast
button's edge - photographed with `shot.gd -- 1.3 cast`; if that reads as crowded on the
phone, `CAST_HAND_TRAVEL.z` is the one number. The smoke check waits for the LANDING before
timing the settle: a full cast flies for 1.3 s with the hands held at the throw, and the
first version measured 0.031 m of "hands not home" that was the flight, not the hands.

`shot.gd` grew `cast` and `throw` modes for this. They are modes and not a third argument
because the third argument is the hour, and `-- 1.3 cast throw` photographed a day whose
time of day was "throw".

**Filmed (desk, 2026-09-12, `movie.ps1 -UserArgs policy=angler,record=...`, frames 340-386
at one tile per 1/30 s).** Does it read? Yes: the lift takes nine tiles with the grip coming
down and right toward the eye, the reversal spans three tiles instead of one, and the rod
holds the throw pose while the float sails out with the line drawn to it. Anything wrong?
At full charge the grip fills the bottom-right corner and the reel foot touches the Cast
button - readable, but the one thing to ask him about on the phone. The caption swaps to
"Reel in" on the release frame, which is right. Nothing snaps, nothing pops, the boat's own
roll is visible under the rod throughout. Not judged: the feel of the reversal under a thumb
(F7, phone).

**`test/replays/first-cast.json` was stale and filmed nobody playing.** Recorded on
2026-09-09 when touching the water cast; the water no longer casts, so its touches landed on
the water and the sheet was 36 tiles of a rod at rest with the caption still reading "Cast".
It is now GENERATED from the bot (`-UserArgs policy=angler,record=test/replays/first-cast.json`
writes the bot's real touches out as a replay), so it cannot be typed against an old layout
again. Regenerate it the same way whenever the buttons move.

## The sixth fight: the model and the bots (F2.1, F2.2, 2026-09-12)

**The model** (`Sim.reel` in [-1, 1], `Tuning.REEL_INERTIA` 0.12 s, `GIVE_RATE` 1.2 m/s,
`GIVE_RELIEF` 3.0/s) is §4.3d of the plan, with one correction that was MEASURED rather
than reasoned: the first cut loaded a held line during a run with the pull term only
(`PULL_RISE * power²`), and with deep fish at run power 1.3-1.8 that is nothing - nobody
ever broke a line, every deep loss was an escape, and the middle of the slide was free. A
held line now carries the fish's whole resistance (`HOLD_RISE * resist * max(crank,
held)`) plus the pull, which is exactly what "reeling into a run" cost in the fifth fight.
The run's kick lands in proportion to how much line is held, so giving during the tell
turns it into line rather than tension.

**The instrument that set the bots is `scripts/probe_dial.gd`**: one deep fish, twelve
seeds per bot, and per bot the outcomes, the fight length, peak tension, peak strain, metres
given, metres the fish took, and the share of the fight spent over the danger line. Three
things it caught that the land-rate table could not:

- **With a valve, every bot surfs the danger line during a run**, so the one that reads the
  water and the one that reads only the rod tied on fish. What separated them was STRAIN:
  0.02-0.14 for the water-reader against 0.62-0.72 for the rod-reader - and at
  `STRAIN_RECOVER` 0.025/s that washed out between runs, so a player who lived over the red
  with the heavy buzz going landed the fish anyway. **0.012/s now**, so a late thumb's strain
  outlasts the calm and "eventually snaps" means this fight.
- **ANGLER gave line through the warning** and paid out a metre per tell for a fish that was
  not yet pulling, then escaped a quarter of the Old Fish - the perfect player losing to
  caution. It HOLDS at the tell now (the crank's tension decays off, the kick lands slack),
  and its valve aims at `DANGER - 0.02` with a 0.06 span: the least line that keeps the rod
  under the red, which is the most brake and the most tiring a run can be made to pay.
- **HUMAN's hands were perfect.** With the valve reading the live tension, HUMAN tied ANGLER
  (strain 0.14 against 0.10). Its slide now eases against a tension felt `HAND_LAG` 0.15 s
  ago and shoves rather than trims (`HUMAN_SPAN` 0.06), so it over-corrects and pays in
  ground. A first cut lagged the felt tension by the whole `REACTION` 0.3 s, and against a
  run that pins the line in a third of a second that broke eleven sturgeon in twelve - worse
  than the bot that never reads the water, which the rule in `policies.gd` forbids.

**Every bot fails for its own reason, measured on the Old Fish / White Sturgeon / Longnose
Gar (landed of 12):** GIVER 6 / 0 / 11, all by escape; BLIND 6 / 4 / 7, all by breaking;
HUMAN 8 / 10 / 12, three broke and one escaped on the Old Fish; ANGLER 9 / 10 / 12, three
Old Fish escaped and nothing ever broke.

**The ladder, `human` bot, by band: 100 / 100 / 100 / 99 / 76 / 58** against the fifth
fight's 100 / 100 / 100 / 99 / 72 / 56. `blind` 100 / 98 / 93 / 78 / 58 / 56 (was 100 /
100 / 99 / 85 / 59 / 38); `giver` 100 / 99 / 95 / 86 / 56 / 44; `masher` 86 / 28 / 13 / 11 /
0 / 0; `slowpoke` 60 / 22 / 1 / 3 / 0 / 0; `angler` 100 / 100 / 100 / 100 / 78 / 75. The
Road is landable by a player who reads only the rod now; Old Town is where ignoring the
water starts to part lines (23%), and the two golden claims about the tell moved there and
are measured in LOST fish over four-minute sessions - the rod-reader lands as many per hour
as the careful player (37 against 36) because its greedy fights are shorter, which is the
risk dial doing its job, not the tell failing.

**Golden re-recorded and the diff read**: the same fish land in every session; what moved is
the fight state at the sixty-second mark (distance, stamina, tension), the draw count by
two, and the new `reel` key. The pure suite's floor is unchanged at 10,900 (11,063 live).

## The slide (F2.3, 2026-09-12)

**The Cast button becomes the reel slide for the fight, in the same corner.** A vertical
slot above and below the button's rect (`SLIDE_UP` 260 px, `SLIDE_DOWN` 150, not the plan's 280
each way: the knob at rest is 334 px above the bottom edge, and a knob pulled fully down must
not enter the gesture bar - 150 is the most the geometry allows and the smoke suite asserts the
inequality; a thumb pulling toward the edge of the glass runs out of room before one pushing
away from it anyway), a scaled dead zone of 12% and the
look stick's 1.7 curve, the landing point as the zero so nothing has to be hit exactly, and a
spring home to HOLD on release through the same `_spring_step` the cast's swing uses - one
curve for everything that settles. The knob is the Cast button's own face with a reel
handle on it that turns by `_reel_spin`, the number the rod's crank turns by, so the
thumb sees the line going the way it is sending it. The caption rides on the knob: Reel, or
Ease when the fish is about to pull. The R10 cross-fade swaps button and slide over 0.2 s.

**Two things the suite caught before a picture did.** The slide's per-frame sync sent zero
to the sim whenever no thumb was on it, which overwrote the bots and the harness sixty times
a second - "two minutes of correct play landed nothing". It speaks only while a thumb is on
it and once as it lifts. And the intro still said "tap to reel it in. stop tapping when it
runs", three fights after tapping went; it and the fight hint say the slide's words now.

**Gates.** `test/test_controls.gd`: up cranks and down gives through the real handler, the
low end is finer than linear, the dead zone is silent, letting go asks for zero and the knob
comes home in under half a second with no single-frame speed step, and the bot's pixel for
an amount produces that amount through the handler (the inversion and the curve cannot
disagree). The seam test drags the slide rather than pressing it; the template driver
turns a moved thumb into a `ScreenDrag` on the same finger now.

## The pressure gauge (F2.4, 2026-09-12)

**Up the LEFT side, because the right belongs to the thumb and the slide.** 44 px wide, 36
px in from the edge, from 880 px below the top (under the sounder's column, which ends at
848) to 0.68 of the height (above the look stick's zone). Pixels above and a fraction below
on purpose: the sounder is anchored in pixels, so a fractional top cleared it on the phone and
ran into it on a 16:9 screen - the first cut, at 0.28 of the height, did exactly that. The
smoke suite asserts both relations against the sounder's own offset and the thumb zone.

**Fill, brightness, mark, pulse, in that order of what a peripheral eye reads.** The fill is
`sim.tension` straight through (`pressure_shown`), brightening and going opaque as it climbs;
the danger mark is a bar across the case at `DANGER`, fixed, with the headroom above it
hatched faintly so the top reads as "past the line"; above the line the case, the mark and a
glow ring pulse on the heavy haptic's own timer (`pressure_pulse` reads `_buzz_wait`), so
the eye and the palm beat together. Colour ramps along the line's own calm-to-hot, third.

**The rule "gauges live in the top third" is replaced** by "readouts are clear of both thumbs'
rest zones and of the centre of the frame". The old rule was the settlement of a note about
a thumb covering a needle; this gauge is precisely where no thumb goes.

**The shot tool trap, a second time in one day.** `-- 0.7 fight hot` photographed nothing new:
the third argument is the HOUR, "hot" became the time of day, and the run died before the
shutter with no message. It is a mode now (`strain`), as `throw` had to be. The trap is written
in `shot.gd` twice; it belongs in a sentence at the top of that file's argument handling.

## The line counter (F2.5, 2026-09-12)

**The brass case at the top is gone.** In its place a line counter: a ruler half the width
and 56 px tall, the boat at the right end and the cast at the left, a tick every metre and a
longer one every five, the net's reach as a short green bar at the boat end, a still marker
where the fish is, and the metres in small digits over the marker. It is the thing you
glance at. **The order he asked for is a number**: the counter's rect is under a quarter of
the gauge's height on the base screen (56 against 425), its scale ink is 0.58 and its digits
0.80 against the gauge's case at 0.82, and the smoke suite asserts all three.

**Quiet is not invisible.** The first cut was pale grey with no shadow, and at the top of the
frame it sat on the dawn sky and disappeared - the old case had carried its own contrast. The
counter draws the way every other line of HUD text does now: cream ink over a dark outline
(0.78, the HUD's own), and the hairlines over a dark shadow line.

**The marker no longer shakes during a run.** That shake was "the one place the danger touches
this instrument"; the danger has its own instrument now, and a measurement that trembles is
one you cannot read. The fourth fight's needle (`_needle`, `_sync_needle`), written every frame
and read by nothing since the fifth fight, went with the bar.

## Sound and touch follow the dial (F2.7, 2026-09-12)

- **The reel clicks at the crank's own rate.** `_sync_reel` counts quarter-turn crossings of
  `_reel_spin` and asks the mixer for one pitched click per crossing (`Audio.click`, pitched
  by tension as before): at the full 25 rad/s that is sixteen a second and reads as a whirr,
  at a fifth of a crank three a second and reads as ticks. Giving line has the drag's ratchet
  instead. The click that used to fire on `sim.tapped` went with its signal: there is no tap in
  a fight now. A held reel coasts across at most one click as the inertia settles - the smoke
  check allows that one, because the model's inertia is the point.
- **The drag sings for line pulled off the spool under load**, whoever is pulling. `Audio.
  drag_level` is 1 for a running fish, `give * tension / DANGER` for line given by the thumb,
  and 0 for slack line given in calm water, because nothing is being pulled against. The mixer
  sets the loop's volume from it rather than from `running` alone.
- **The heavy train starts at the warn line and closes up.** `buzz_gap(tension)` runs from
  170 ms at `DANGER - LINE_WARN_FROM` (discrete pulses - Android reads 100 ms and over as
  separate) to 50 ms at the top (one buzz), straight between; its weight climbs the same way.
  The gauge's pulse reads the same timer, so the eye and the palm start together at the warn
  line, which is the answer to "easy to miss initially": the warning now arrives on three
  channels before the danger line, not at it.

Tolerances that had to be measured rather than typed: the drag's "silent" is under 0.01, not
under a millionth, because the crank's exponential tail sits at a quarter of a percent two
thirds of a second after the thumb lifts and no ear hears that.

## The face of it, filmed (F2.6, 2026-09-12)

The bot (`policy=angler`) filmed through a whole fight at 30 fps, 45 s, and read at tile
spacings of 4 frames (0.13 s) round the strike, the run and the landing, with the slide and
the gauge cropped out at full size. `build/movie/policy-fight` is the first film,
`policy-fight-2` the one after the fix. The six questions, and what changed:

1. **Feedback in the same frame.** The knob's handle turns between every 4-frame tile while
   the thumb is up (frames 600 to 628: about 45 degrees a tile, a steady crank), turns the
   other way slowly while it is down (632 to 676), and the gauge's fill follows the tension
   with no lag the eye can find: 80 % at frame 630, 60 % at 640, 35 % at 650, empty at 660
   while the bot eases through the run, 80 % again at 670 and the fill gone pink and full at
   690 as it cranks back into the danger band. Yes.
2. **Speed and coasting.** The bot's thumb is a step function, so the knob jumps from the top
   of the slot to the bottom between frames 628 and 632. That is the bot, not the control:
   `SLIDE_ACCEL_MAX` caps the return spring, not a held thumb, and a human thumb moves at
   thumb speed. Left alone, and noted so the next reader does not chase it.
3. **Pop-in and layering. Found and fixed.** The cross-fade at the strike (frames 382 to 398)
   showed the ghost of the outgoing button AND the incoming slide both captioned "Reel" for
   six frames, and at the landing (frame 934) a second faint "Cast" hung under the button
   while the slide faded out. Both ends of the fade computed their caption from the state.
   Now each control's word is written only while it is the live control (`_slide_caption`
   for the slide, `_action.text` for the button) and the one leaving keeps the word it left
   with. Asserted in the smoke suite one frame into each fade; reintroducing the bug fails
   both claims.
4. **The short states.** "watch the float" at frame 360 with the Strike button up, then
   "slide up to reel - ease down when it pulls" through the fight, "it is running - hold on
   if the rod can take it" at the run (frame 660) with the knob captioned Ease in the warm
   tint, and "Back it goes." after the landing. Every state names its verb.
5. **The first-minute win and the next goal.** Hooked at 12.6 s from the title, landed at
   about 31 s, "Back it goes" (undersize) and the Cast button returned with the aim hint.
   The counter at the top reads as a small measurement over the sky and the gauge is the
   thing the eye lands on: the hierarchy he asked for.
6. **A frame where the player would not know what to do.** None in this run. The nearest is
   the empty gauge at frame 660 while the fish runs: the bot has eased fully and the fill has
   gone to nothing, which is the model doing what "giving line is always safe" promises. A
   human would ease less and keep some fill; the caption says Ease and the pull says why.

The 1/60 s tiles the plan asked for became 1/30 s: the film is 30 fps because the movie
writer's cost is per frame and a 45 s fight at 60 fps is an hour on this PC. Nothing in the
morph is shorter than two of those frames.

## Playtest 2026-09-12 (phone, Galaxy S26 Ultra, desk-exported APK)

**Driven from the desk over adb** (`device.ps1 install / launch / perf / record 30 / tap /
swipe / home / resume / back / log -Dump`), one cast by a 0.9 s press on the Cast button's
drawn centre (904, 2004), then the game's own nibble. The video is 120 fps
(`build/phone/20260912-170119.mp4`); sheets at one tile per half second, per 1/60 s and per
1/120 s. What the machine can judge:

1. **The reversal is continuous on the phone.** At 120 Hz the rod reverses over about fifteen
   frames after the release, with no single-frame jump in any tile; the throw pose is reached
   as the float leaves the tip (F5 holds at the phone's own rate, since the spring integrates
   in seconds, not frames). The hands come back with the rod (B8) and the grip fills the
   bottom-right corner at full charge without covering the Cast button.
2. **Hit box and caption agree.** The press at the button's drawn centre charged ("Cast 5 m"
   → "Cast 18 m" under the thumb) and the release threw; the caption became "Reel in" on the
   release frame and "Strike" when the float dipped nine seconds later.
3. **Frame time and thermal.** Average 125 fps (the 120 Hz panel), 0 dropped and 0 janky
   frames in every 20 s, 8 s, 6 s and 3 s window, before play, during the cast, after
   home-and-resume; thermal status 0 throughout, AP 33-38 °C. **Five minutes in the boat:
   36,617 frames, 0 dropped, 0 janky, 125.0 fps, thermal status 0, AP 37.7 °C, battery
   32.2 °C** (from 28.5 at the start). `device.ps1 perf` reports SurfaceFlinger's counts and
   an average, not percentiles; POLISH.md's p95 rule is answered by "no janky frames in
   36,617" rather than by a number.
4. **Home then resume** comes back to the running game at the same state, audio unmuted;
   the game pauses while away (`paused`) and resumes on `APPLICATION_RESUMED` with no pause
   face. That is this game's design (there is nothing to pause a lake for), not the template's
   "returns to a paused game".
5. **Back from the seat quits**, saving first, as `CLAUDE.md` says it should; from a room it
   unwinds one layer (asserted in the smoke suite, not re-driven here).
6. **Safe area.** The HUD text sits either side of the camera hole, the stick is 200 px above
   the gesture bar, nothing under either. The build stamp reads `unbuilt` because a desk
   export does not run `stamp.ps1`; CI's APK carries the real stamp.
7. **No `ERROR` in the log.** Only the engine's boot lines (Vulkan, Forward Mobile, Adreno 840).

**Findings that changed something:**

- **The boot splash was the Godot logo** on a dark plate at every launch, caught when the
  app relaunched after `back`. T4 fixed the launcher icon and left this default. Now the
  launcher icon on a dawn-sky plate, and `test_assets.gd` asserts the setting and the file
  (verified failing with the default reintroduced in memory). Two plates remain on launch:
  Android's own system splash first, the launcher icon on a DARK plate painted by the export
  template's theme, then ours. The first one is not a project setting; changing it means a
  gradle build with a theme override, which is a ship-time job (POLISH.md names it).
  POLISH.md's `splash_screen/disable_godot_boot_splash` does not exist in the 4.7 Android
  preset; the boot splash is `application/boot_splash/*` in project.godot.
- **The black wedge on the near port rail is a shadow, not a hole.** Sampled off the phone
  screenshot: the pixels are (38-73, 34-70, 36-73), warm-tinted dark grey, where the old
  hairline was sky-coloured (232,234,235). It is the inner face of the port gunwale in the
  shade of a low dawn sun, crushed to near-black by too little ambient light. Not fixed here:
  it wants the lighting pass to lift the shadow floor, and a sample first, since a fix that
  moves a rail to cure a shadow would be the wrong mechanism.

**What the machine cannot judge and he can:** the two haptic levels (the tell's small pulse,
the over-bend's heavy train) have still never been felt by anyone; the fight's give and take
under a thumb (F6); whether the reversal at the release FEELS like weight. `permissions/vibrate`
is set in both presets. F7 stays open until he has held it.

## Open

**The list moved to `PLAN.md` section 12**, which is now the milestone checklist the
framework's skills read when they resume this game. It was kept here as well and the two
drifted, which is the whole argument for one of them: `PLAN.md` §12 was still calling the
logbook "next" months after it shipped. What stays here is only what a milestone cannot
carry — the reasoning behind a fix, and the numbers.

**As of 2026-09-12 the unticked boxes are F5–F7, B7–B8, W3, P3–P4, G5, S1–S5, T1 and T5.**
Phases R and W are complete; P, G and T are part-done. The next milestone is **F7 — judge the
fight on the phone** (`/playtest phone`), and it is first for a reason: the fifth fight, the
foam, the reeling animation, the haptics and the two-level buzz have ALL been judged on a
desk, against screenshots, by someone who cannot feel a phone vibrate. Nothing in this
session's feel work has been felt. `permissions/vibrate` was missing until this session, so
the haptics have literally never fired on hardware.

After that, **T5 (the harness gap)** before any more balance work — a suite that reports an
aborted test as passing is a suite that can bless a wrong number.

The heavy remaining work is Phase S (the three act turns, the radio, the Act III inversion,
the ending, NG+) and P3/P4, which are the first places the player leaves the boat.

The sheer-hairline remnant on the near port rail is understood rather than fixed — see the
diagnosis above. The fix is a lip whose upstand and a rail whose depth are one number in two
places; the remnant is the case where perspective makes the sliver subtend more than a pixel.

## Invariants specific to this game

- **`src/sim/` may not reference a Node, a Viewport, an input event or a real frame.**
- **Every openable thing is built SHUT.** State entered in a builder has no natural exit:
  `_build_chart` called `open()` and nothing ever closed it, so an unshaded map glowed on the
  thwart through every hour of the game. A builder that opens something is a `new` with no
  matching `free`.
- **A hit box does not have to be the whole object.** `AIM_NODE` takes a list of node names.
  An oar is over a metre long, so lying down its box spans half the boat and crowds everything
  else out of its twelve degrees — which is why the oars stood absurdly on end for one build.
  The boat has SEVEN interactables and has run out of angles: the next thing that wants one
  should go on the chart, not on the sole.
- **`rotation.y = x` destroys the rest of the basis.** It is the Euler decomposition of the
  whole thing, so writing one component rebuilds the basis from `(0, y, 0)`. Compose onto a
  stored rest transform. The page-turn leaf stood bolt upright in the middle of the boat.
- **`render_priority` orders TRANSPARENT materials only.** Opaque geometry sorts by depth and
  ignores it — with `no_depth_test` on both a page and the leaf turning over it, the draw
  order was undefined and the page won.
- **Anything the player holds up hangs off the CAMERA, not off a world point.** The held fish
  was at a fixed world position chosen when the hold lasted 2.4 s; once G2 let the player hold
  one indefinitely it was measured at 0.27 m from the lens and 0.40 m below the view axis — 56
  degrees down against a 37 degree half-angle. How far out is computed from the fish's MEASURED
  length (`d = 2.57 × L`), because a carp is three times a bluegill and one distance frames
  neither.
- **Scale every item in a group from its own measured bounds, never per-object by hand.** The
  shed's counter had a crate three times the reel beside it; one line — scale so the largest
  dimension is `SHED_ITEM_SIZE` — fixed it for props not added yet.
- **`global_transform` is IDENTITY and `get_viewport()` is null in the hand-stepped headless
  harness.** Multiply local transforms up the parent chain and project by hand. Doing it by
  hand is BETTER than the engine call here: it tests the phone's aspect and it runs in CI.
- **An object the player is meant to notice must be asserted to be IN SHOT, not merely in the
  scene.** The logbook was in the boat, above the floorboards, with a working page and a passing
  test for every one of those - and it sat 27 degrees below a view axis in a frame that reaches
  29, so it was never in the picture. `_in_frame` in `test/run_smoke.gd` projects a world point
  into the seated camera's frustum at the PHONE's aspect ratio and fails if it is past 88% of the
  way to any edge.
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
- **`HOLD_RISE` and `TAP_DECAY` are one ratio, and `PULL_RISE` rides on the same decay.**
  A held reel settles at `HOLD_RISE * resist / TAP_DECAY`, so scaling the pair leaves every
  settle point alone and changes only how FAST tension gets there. Both were multiplied by 2.5
  together for exactly that reason — see the fifth fight below. `PULL_RISE` had to move with
  them or runs would have quietly weakened.
  *(This invariant used to name `TAP_KICK` and `RUN_PULL`. Neither exists: the fifth fight
  replaced the tap with a hold and deleted them. A stale invariant is worse than none — it
  sends the next session looking for a constant that was removed three fights ago.)*
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
