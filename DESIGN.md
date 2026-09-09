# Stillwater — the whole design

The complete specification: what the game is, how every part of it behaves, and
what is built versus what is not. `NOTES.md` records what was *learned*;
`CLAUDE.md` records the toolchain. **This file is what the game is meant to be.**

Where a section says MEASURED, the number came from a run, not a guess.
Where it says OPEN, it is not built yet.

---

## 1. The pillars

Three, and everything below is downstream of them.

**DEPTH IS TIME.** The lake does not go down, it goes back. Four metres is this
year's weed; forty is a road tarred in 1931; eighty is rooftops. The line
upgrade IS the story progression, so there is only ever one ladder to balance.

**THE GAME NEVER EXPLAINS ITSELF.** No cutscenes, one speaking character who is
a radio. The dates arrive on the end of a line and the player does the
arithmetic. The moment they work it out is the moment the logbook they already
filled in changes meaning.

**IT STAYS THE SAME LAKE.** The horror is not a different place. It is this
place, slightly wrong, and more wrong the further down you look. Every arc in
the game is therefore a CROSSFADE on one number, never a switch.

---

## 2. The loop

```
        ┌──────────────────────────────────────────────┐
        │                                              │
   cast ──▶ watch ──▶ strike ──▶ fight ──▶ land ──▶ keep or throw back
        │                                              │
        └────── sell ◀── travel ◀── upgrade ◀──────────┘
                  │
                  └── sleep ──▶ new hour, new weather, new fish
```

One outer loop, three nested minigames, no second currency and no second
progression track.

---

## 3. Controls — the complete input spec

One finger. Three verbs, discriminated by **movement**, not time — it has to be
movement, because charging a cast is itself a long press.

| Gesture | Verb | Notes |
|---|---|---|
| Press and hold, still | Charge a cast | Charge maps to distance AND to depth |
| Release | Cast | Goes where you are looking |
| Drag past 14 px | Look around | Cancels any charge; ±60° yaw, ±23° pitch |
| Tap during nibble | Strike | The one timing window in the game |
| Tap during fight | Reel | Rhythm, not mashing |
| Action button | The state's verb | Cast / Strike / Reel in |
| Dock (bottom-left) | Rooms | Shed, Lake, Log, Kit |

**Look sensitivity** is expressed as `LOOK_SWEEP` — screen widths of drag to
travel the whole yaw range — so it can be judged rather than guessed. Default
1.15. Adjustable in Kit across 0.6–1.7, and saved.

**Layout rules**, from the thumb-zone research:

- Primary action bottom-**right**, round, warm, 260 px on the 1080 base
  (≈15 mm, comfortably over the 48 dp Android minimum).
- Navigation bottom-**left**, flat, cool, low contrast. It is read once every
  few minutes; the action is pressed every few seconds. Equal weight was the bug
  Gideon reported as "out of place".
- 54 px kept clear at the bottom for the gesture bar.
- Nothing positioned against a literal 1920 — `stretch/aspect = expand` means
  the real canvas is ~1080×2340.
- Nothing the player must watch may sit under the thumb that operates it.

---

## 4. The three minigames

### 4.1 The cast — a depth selector wearing a distance meter

Charge time maps to distance, and distance maps to where on the spot's shelf the
lure lands, which maps to depth, which is time. The player is choosing a **year**
and is never told so.

### 4.2 The nibble — watch the float

No HUD at all. Teases pull the float down `TEASE_DEPTH`; the real take pulls it
under completely for `take_window` seconds. Strike in that window and you are on.

- Teases: 1–3, species-dependent
- **A missed take costs a CHANCE, not the fish** — `takes` in the species row,
  2 for most, 1 for each band's prize fish. Dredge's rule: fishing must not be
  frustrating.

### 4.3 The fight — hold the tension band

Tap to raise tension, it decays on its own, keep it inside the safe band. During
a **run** the needle climbs with no input and the answer is to stop tapping —
which the player works out from the water rather than from a caption.

- `run_chance` is how OFTEN it happens (teaches), `run_power` how hard (punishes).
  These must never be one number: see NOTES.md.
- Rod widens the band. Reel shortens the fight. Neither makes the fish weaker.

MEASURED land rate by band: **91 / 72 / 58 / 50 / 43 / 25 %**.

---

## 5. The world

Six bands, six spots, both ordered by depth. The band you can reach is
`min(spot bed, line length)`, and a spot whose shallowest water your line cannot
reach cannot be travelled to at all.

| Band | Depth | Year | Spot | Bed |
|---|---|---|---|---|
| The Reeds | 0–4 m | 2026–2011 | Reed Bay | 4 m |
| The Channel | 4–15 m | 2011–1968 | The Narrows | 15 m |
| The Drowned Road | 15–40 m | 1968–1931 | The Drowned Road | 40 m |
| Old Town | 40–80 m | 1931–1889 | The Steeple | 80 m |
| The Quarry | 80–140 m | 1889–1841 | The Quarry Wall | 140 m |
| The Spring | 140–152 m | — | The Spring | 152 m |

Five hours (dawn → night), five weathers. Sleeping advances the hour; a new dawn
advances the day. **Time is the tension resource** — no fuel, no stamina.

---

## 6. Progression and economy

One ladder that matters (line) and three that support it.

| | Rungs | Prices |
|---|---|---|
| Line | 6 | 0 / 60 / 220 / 700 / 2000 / found |
| Rod | 5 | 0 / 120 / 450 / 900 / found |
| Reel | 4 | 0 / 200 / 600 / 1800 |
| Livewell | 3 | 0 / 180 / 520 |
| Boat | motor / sounder / lamp | 500 / 1200 / 400 |

**Money cannot buy the bottom.** Below 80 m the only bait that works is an
OFFERING, which is found and never sold. A player who ignores the story caps out
at 40 m with a full wallet — the answer to "what if they ignore this?" is not
"they score less", it is "they cannot continue".

**The sounder buys no fishing advantage at all.** It draws what is under the
hull. It is the most expensive thing in the shed because it is the best
storytelling instrument in the game.

---

## 7. The story, and how it is delivered

Told entirely through what comes up on the line, dated, from a depth.

| Depth | What surfaces | What it says |
|---|---|---|
| 1–6 m | A phone, dead, that charges | The photographs are of this lake |
| 8–15 m | A licence plate, 1994 | The county does not exist |
| 20–40 m | A road sign: STILLWATER 2 | The chart in the cabin is a chart of a lake |
| 25–40 m | A packed suitcase, 1949 | Packed by somebody who expected to arrive |
| 45–80 m | A mailbox, 1931 | Compensation, and the date everyone had to be out by |
| 50–80 m | A school desk | The name cut in it is the name in your logbook |
| 85–140 m | A rope | You keep hauling. There is no other end to it |
| 95–140 m | A ledger, 1871 | Wages in five hands. Five keepers, too |
| 110–140 m | A carved stone | Older than the quarry that cut around it |

**The five keepers.** The logbook you write in has been written in before, in
five hands, and the last one is yours. OPEN.

**The blank page ending.** The Old Fish is at the Spring, which has no date. OPEN.

---

## 8. Art direction

| | Surface | The Quarry |
|---|---|---|
| Sky | warm dawn HDRI, real cloud | drained, cloud multiplied in |
| Water | gold specular path, fine chop | flat green-grey |
| Light | 2.2 energy, long streak | 0.10, no direct beam at all |
| Fog | 0.0003 | up to 0.011 (capped: see NOTES) |
| Bank | reeds both sides | open water in every direction |
| Grade | grain 0.040, vignette 0.28 | grain 0.115, vignette 0.66, aberration |

**The asset rule, stated so it can be applied rather than reached for.** Estimate
how many pixels tall the thing will be on the phone:

- Under ~60 px, judged on silhouette → **model it in code**
- Over ~200 px and permanently on screen → **import it**, and modelling is what
  needs justifying
- Shape is gameplay state → **code, and the question is closed**

*If you cannot say roughly how many pixels tall it will be, you have not applied
this rule, you have skipped it.* Three interactables in the boat had no geometry
at all because of exactly that.

| In the boat | Which | Why |
|---|---|---|
| Bucket, crate, lantern, lifebuoy | imported (Poly Haven, CC0) | 200–400 px, permanently on screen |
| Hull, ribs, planks, gunwales | generated | derived from the hull functions |
| Rod | generated | its bend IS the tension gauge |
| Float | generated | its dip IS minigame one |
| Fish | generated | a Thin Perch is a perch with one number changed |
| Reeds | generated | distant, read as silhouette |
| Wake, splash, ring | generated | marks on a surface, sized by fight state |

Style matters more than licence: Kenney, Quaternius and KayKit are CC0 and
excellent, and all stylised low-poly — any of them beside a photographic HDRI
and PBR timber reads as a different game leaking in.

---

## 9. Audio

Nineteen generated WAVs, one key (D minor pentatonic), 22050 Hz mono.

Four music beds run **continuously** from the first second to the last; only
their levels change, on the same `dread` = depth the picture uses. The bells are
most of the first hour and gone by Old Town, and nothing replaces them — **an
absence is the loudest thing you can put in a score.**

---

## 10. The standard for "finished"

Feel is asserted, not eyeballed. Every one of these is a test:

| Claim | How it is failed |
|---|---|
| Affordance | a state names no visible action |
| Dead time | the one visible control does not lead back to playing |
| Latency | an input is not answered within two frames (~33 ms) |
| Liveness | two samples of the world a second apart are identical |
| Discrimination | a drag becomes a cast, or a still hold does not |
| Difficulty ladder | a band is not meaningfully harder than the one above |
| Mood arc | the score or the palette stops changing with depth |
| Save | any malformed save fails to leave a playable boat |

---

## 11. The build, section by section

Every remaining piece, with **how** it gets done rather than only what it is.
Ordered so each one is playable when it lands.

Legend: **[done]** shipped · **[now]** this pass · **[next]** ordered after.

---

### 11.1 The title **[done]**

*What.* First thing on launch: the lake at dawn behind the game's name, with
**Continue**, **New game** and **Settings**. Continue is greyed with no save.

*How.* Not a separate scene. The real boat scene boots and runs behind a
`CanvasLayer` — the water is already moving, the sky is already the right hour,
so the title is a photograph of the game rather than an image of it. New game
clears the save through `Save`, Continue simply lifts the layer. Settings reuses
the Kit room; there is one settings screen in the project, not two.

*Feel.* The lake keeps moving under the menu, so the first frame is already
alive. Buttons stack in the bottom third, in the thumb zone, using the same
warm-verb / cool-navigation split the HUD uses.

*Test.* Boots to the title, Continue disabled with no save and enabled with one,
New game leaves a fresh boat, and every button leads somewhere.

---

### 11.2 The first morning **[done]**

*What.* The intro. Teaches look → cast → watch → strike → reel → keep, in that
order, and plants the story on the last beat.

*How.* A beat list in `src/game/intro.gd`: each beat is a line of copy and a
CONDITION that ends it, read off the sim. No timers where a condition will do —
the tutorial waits for the player rather than the player waiting for it. Beats
never block input; the game underneath is the real game from the first second.

*The beats.*

| # | Says | Ends when |
|---|---|---|
| 1 | "Dawn. Nothing on the water yet." | 2 s |
| 2 | "Drag to look around." | the view has turned |
| 3 | "Hold anywhere to cast. Hold longer to go further out." | a cast is in the air |
| 4 | "Now watch the float." | a fish starts nibbling |
| 5 | "It is only mouthing it. Wait for it to go under." | the float is properly under |
| 6 | "NOW — tap." | hooked |
| 7 | "Tap to reel. Stop when it runs." | landed |
| 8 | "A bluegill. It goes in the book." | 3 s |
| 9 | "Somebody has already written in it." | opens the Log |

*Story.* Beat 9 is the hook. The logbook is not blank — it is a keeper's
logbook, and there is a name in the front that is not yours.

*Feel.* Copy is short, lower-case, and never repeats a beat already passed. It
disappears the moment the condition is met, so the player's own action ends the
sentence rather than a timer.

*Test.* A bot that plays normally reaches beat 9 without the intro ever blocking
it; every beat's condition is reachable; and the intro never reappears once done.

---

### 11.3 The keeper's logbook **[next]**

*What.* The story's spine. Entries in five hands, unlocked by DEPTH.

*How.* A table in `src/sim/keepers.gd`: `{keeper, depth, text}`. The Log grows a
second tab. Unlock is the deepest cast ever made, saved as one float — the same
number the score and the picture already use, so no new progression.

*Feel.* Handwriting changes between keepers by font weight and colour only. The
fifth hand is the player's, and its entries are the ones the game has been
writing all along: the species records.

---

### 11.4 The radio **[next]**

*What.* The one speaking character.

*How.* A prop on the thwart with an interaction point. Generated speech is out
of reach, so it is TEXT over a generated carrier-and-static bed — which is
better anyway, because a voice would date the game and static does not. Messages
are a table keyed on depth and hour.

*Feel.* Starts as weather reports. The reports slowly stop being about weather.
By the Quarry it reads the day's catch back to you.

---

### 11.5 Wrong fish **[next]**

*What.* `wrong` exists in the species data and changes nothing on screen.

*How.* The generator already takes every shape parameter from data. A wrong fish
gets its `look` fields pushed past the range a real fish uses — an extra pair of
fins, an eye with no iris, a body a third too long. No new code path; the same
generator, worse numbers.

*Feel.* Never remarked on. The logbook prints the note in the keeper's hand and
the game says nothing.

---

### 11.6 First-run polish **[next]**

Orientation lock, a pause that actually pauses, a proper app icon, and the
audio starting on first touch rather than on boot.

---

### 11.7 The ending **[next]**

The Old Fish at the Spring, the blank page, and NG+ where the lake remembers.

---

## 12. Build order

**Done:** the world, economy, four rooms, save, sounder, audio, mood arc, boat
motion, look control, action button, juice layer, feel tests, Kit settings,
imported props, the title, and the first morning.

**Next, in order:** (detail in section 11)

1. **In-boat interaction.** Look at the livewell, the lamp, the bait box, the
   rope — a prompt appears, tapping uses it. This is the "small details" note:
   the boat should be a place with things in it, not a camera mount.
2. **The keeper's logbook.** Entries in five hands, unlocked by depth. The story
   currently lives only in object notes.
3. **The radio.** The one speaking character. Weather reports that stop being
   weather reports.
4. **The lamp** doing something: fishing after dark is currently identical.
5. **First-run flow.** No title, no settings prompt, no orientation.
6. **Wrong fish visuals.** The `wrong` flag exists in data and changes nothing
   on screen.
7. **NG+.** The lake remembers.
