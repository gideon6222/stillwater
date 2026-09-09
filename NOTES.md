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

## What is proven, as of 2026-09-09 (v0.2.0, M1)

- The fresh template copy passed its own gate before a line of game code — 28 tests, 4,410
  assertions — so nothing that fails from here is inherited.
- Cast → hook → fight → land, end to end, through the real scene and the real input seam.
- 46 tests, 5,826 assertions, about a second, no display. Plus 33 smoke assertions that boot
  the actual scene and catch a whole fish through it.
- A whole-run golden over five scripted sessions, which has already earned its place: the first
  recording exposed stale fish state leaking through a cast made straight out of a loss.
- Screenshot at the phone's real aspect (460x996), not the project base.

## The fight, and why it is built this way

**This is the SECOND fight.** The first was a threshold model — hold the tension inside a band,
with the band drawn on a control on the right-hand side — and Gideon killed it in one sentence:
*"it is too easy and I don't like that my thumb will be blocking the gauge I am looking at."*
Both faults had one root, and it is worth keeping:

- **A threshold fight settles into ONE correct sustained input.** Find the thumb position that
  holds the needle in the band and the mechanic is over; there is nothing left but not moving.
- **A readout that must be watched continuously cannot live under the thumb that sets it.**
  Wrecking Crew's crane dial got away with exactly that arrangement because you *glance* at a
  dial. A tension meter is read every frame.

**So there is no gauge, and there must not be one.** The rod's bend is the tension, the float
and its wake are the fish, and the thumb drags anywhere on the lower half of the screen — a
relative drag with no fixed track, so nothing on screen can be covered.

**Line is gained on a PUMP, never on a value.** A lift above `PUMP_HIGH` then a drop below
`PUMP_LOW`, and the gain lands on the down stroke. Holding any constant load — high, low or
perfect — gains exactly nothing. `test_a_steady_hand_gains_no_line_at_any_load` asserts that at
six held values and is the one test that would catch a silent reversion to a threshold fight.

**Three behaviours, three different answers, each telegraphed ~0.34 s ahead:**

| the fish | you must | getting it wrong |
|---|---|---|
| holds | pump | a steady hold gains nothing; slack works the hook loose |
| runs | give line | the line parts, and **fastest at the very start of the run** |
| surfaces | hold steady, mid-load | pumping or slacking throws the hook |

**A run hits hardest at its start** (`RUN_SURGE`, decaying over `RUN_SURGE_DECAY`). That is the
single change that made this a game of awareness rather than reaction: being a tenth of a second
late costs several times what being late later does, so reading the tell and dropping the rod
*before* the run beats any amount of reaction speed. Before it existed, more runs only made
fights longer — the bass went from 96% landed to 54% when it went in.

**The wear clock means doing nothing also loses.** ~46 s and the hook is out regardless.

**Rods change the strain threshold and nothing else** — not a damage number. A fish is hard
because of what it *does* and how often, never because its tolerances are tighter. Tolerances
belong to the rod, so a rod purchase is felt on every species at once.

**The line is arithmetic, never a physics body.** Wrecking Crew earned this with a wrecking ball
on a `PinJoint3D`.

## Balance, measured 2026-09-09

Six seeds, ninety-second sessions, from `test/run_probe.gd`:

| policy | caught | lost | what it proves |
|---|---|---|---|
| `idle_hands` | 0.00 | 8.33 | the fight is a mechanic, not decoration |
| `masher` | 0.00 | 10.00 | holding on flat out is a fast way to lose |
| `hauler` | 3.83 | 3.83 | pumping while ignoring the water halves your catch |
| `panicker` | 0.00 | 4.50 | giving line at every sign never lands anything |
| `angler` | 6.33 | 0.00 | perfect play wins — see the warning below |
| `human` | **5.33** | **1.67** | a plausible player loses about a quarter of what they hook |

Per species, landed by `human` from a worst-case full-length cast:

| species | landed | seconds | pumps |
|---|---|---|---|
| Bluegill | 92% | 8.3 | 12.4 |
| Yellow Perch | 75% | 10.8 | 15.7 |
| Largemouth Bass | 54% | 15.9 | 21.5 |

**Read `human`, never `angler`.** `angler` is a zero-latency, perfect-information controller and
it will beat any mechanic that is fair — its score says nothing about difficulty. That is not a
guess: the first fight's probe showed `angler` at 6.83 caught / 0 lost, it was written down here
as "the number to watch", the build shipped, and the first thing Gideon said was that it was too
easy. **The instrument was wrong, not the reading.**

`human` adds a 300 ms reaction, a tell it misreads one time in six, and a thumb that wobbles.
The first version of it was stateless and scored *identically* to `angler` — because a stateless
bot corrects itself the instant the world changes, so a misread costs it only the tell window. A
person keeps doing the wrong thing until they notice. Belief has to lag reality by a reaction
time, and once it did the same build went from 0% losses to 24%.

**Tune the game until `human` struggles. Never tune `human` until the game looks hard.**

## Open, in rough priority order

1. **Does the second fight feel good?** Everything else is downstream of ninety seconds with a
   thumb on the screen and eyes on the rod. Nothing else should be built until that is answered.
   The specific things to ask about, because "it looks fine" will not cover them: whether the
   run warning is readable in the water without being told what it means, and whether the pump
   rhythm is satisfying or fiddly.
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
- **There is no tension gauge, and adding one back undoes the whole second fight.** The rod is
  the instrument. `run_smoke.gd` asserts the absence of a control named `Gauge`, because that is
  the only way a deleted thing stays deleted.
- **No caption may name what the fish is doing.** No "GIVE LINE!", no behaviour label, no
  tension number. The water is already saying it, and a caption that says it too means the
  player reads the caption forever and never learns to read the water.
- **Balance is read off `human`, not `angler`.** See the warning in the balance section.
- **The rod tip is derived from the rod's transform**, never typed twice. A hand-copied tip
  drifts the moment the rod is nudged, and the symptom is a line hanging in the air beside it.
