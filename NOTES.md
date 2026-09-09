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

**The band is FIXED and the fish pushes tension around it.** Staying inside means giving line
when it surges and taking it back when it rests. A band centred on the fish would need one
constant thumb position and would not be a mechanic at all — that was the first model, and it
was discarded on paper before it was written.

**Rods change the WIDTH of the band and nothing else.** Not a damage number. That is legible in
ten seconds of use, and it means buying a rod is felt on every species at once. A fish is hard
because its surge is wide and its period short — never because its band is narrow, which is the
rod's job.

**The line is arithmetic, never a physics body.** Wrecking Crew earned this with a wrecking ball
on a `PinJoint3D`: the moment an outcome lives in the physics server it is at the mercy of the
tick rate, and a whole-run golden becomes impossible. Rigid bodies are for things that decide
nothing.

**The gauge draws the state, not the input.** Band, live tension, and where the thumb is asking
for, on one track. The gap between the last two is the rod's give. Wrecking Crew's crane dial is
the precedent: a control that shows the state lets the player read their own aim without looking
away from it.

## Balance, measured 2026-09-09

Six seeds, ninety-second sessions, from `test/run_probe.gd`:

| policy | caught | lost | what it proves |
|---|---|---|---|
| `idle_hands` | 0.00 | 8.00 | the fight is a mechanic, not decoration |
| `masher` | 0.00 | 9.83 | pulling flat out is a real mistake, and a fast one |
| `timid` | 0.00 | 3.67 | the band has a bottom; failing slowly is still failing |
| `angler` | **6.83** | **0.00** | it is winnable by reading the gauge |

Fight lengths from a full 22 m cast: bluegill 7.9 s, perch 9.6 s, bass 17.5 s. At the bot's
actual cast distance (12.6 m) those are roughly 4.5 s and 10 s.

**The number to watch is the angler losing zero.** A perfect proportional controller is not a
thumb, so this is not necessarily a difficulty problem — but if Gideon reports the fight is too
easy, that column is where it was already visible, and the lever is `surge` and `period` per
species rather than the band.

## Open, in rough priority order

1. **Does the fight feel good?** Everything else is downstream of ninety seconds with a thumb on
   the gauge. Nothing else should be built until that is answered.
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
- **The rod tip is derived from the rod's transform**, never typed twice. A hand-copied tip
  drifts the moment the rod is nudged, and the symptom is a line hanging in the air beside it.
