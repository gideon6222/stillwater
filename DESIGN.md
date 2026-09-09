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

Rules: import what is read at real size (HDRIs, textures); model anything judged
on silhouette or whose shape is gameplay state (fish, reeds, hull, rod, float).

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

## 11. Build order

**Done:** the world, economy, three rooms, save, sounder, audio, mood arc, boat
motion, look control, action button, juice layer, feel tests, Kit settings.

**Next, in order:**

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
