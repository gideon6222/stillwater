# Stillwater — the plan

The complete specification: what the game is, how every part of it behaves, and
what is built versus what is not. `NOTES.md` records what was *learned*;
`CLAUDE.md` records the toolchain. **This file is what the game is meant to be.**

**Section 12 is the milestone list** — the checkboxes a resuming session works
from. Sections 1–11 say what each milestone is; section 12 says whether it
exists, and it is the only place that says so.

Where a section says MEASURED, the number came from a run, not a guess.
Where it says OPEN, it is not built yet.

(This file was `DESIGN.md` until 2026-09-09. It is `PLAN.md` because that is the
name every skill in the framework looks for when it resumes a game.)

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

### 5.1 The lake has to be a PLACE, not a spot with six numbers

Gideon: *"I don't want the whole game to take place in that one boat and in that
one spot."*

This is the largest structural note the game has had, and the care needed is that
**pillar 3 says it stays the same lake.** Those are not in conflict, and reading
them as if they were would break the game: he is not asking for a second location.
He is asking for the one location to have SIZE. Six spots currently differ by the
number on the depth readout, the palette, and which fish bite — everything the eye
uses to tell one place from another is identical.

Three answers, cheapest first, and the ordering is deliberate because the first is
most of the effect for almost none of the work.

**One unique landmark per spot, visible from the seat, never repeated.** Not
terrain — a silhouette. A single dead oak still standing in four metres of water;
the collapsed jetty; the road's guard rail running out of the water and back into
it; the steeple; the quarry's cut face; nothing at all at the Spring, which is
what makes the Spring the Spring. This is what a player will actually use to know
where they are, and it is one mesh each.

**The bank becomes somewhere you stand.** The gate, the wall and the shed already
exist in the fiction and the player already walks through them once, on the way in
(11.0). Turning that walk into a place you can stop in costs one camera mode and
no new fiction: the jetty to cast from, the shed to go inside, the bank to walk
along. **The first minute of the game already proves the machinery works** — the
gate sequence is a list of shots over the real scene, and standing still is a shot
that does not end.

**Two spots let you off the boat, and the second one is the image the act turns
on.** Reed Bay has the keeper's jetty. And at Old Town, at low water, **the
steeple's roof breaks the surface** — you can tie up to it and stand on a rooftop
in the middle of a lake, forty metres above a street. Nothing needs to be said
about that, which is exactly how this game says everything.

**And the same spot at a different hour or weather is content.** It is already
free — the mood arc runs on depth and the sky runs on the clock — and it is
currently spent only on atmosphere. A storm at the Drowned Road, or the Reeds at
night, should be a reason to go rather than a thing that happens to you.

| Spot | Landmark | Off the boat? |
|---|---|---|
| Reed Bay | the keeper's jetty and the gate above it | **yes** — the bank, the shed |
| The Narrows | a dead oak, still standing, in four metres | no |
| The Drowned Road | a guard rail entering and leaving the water | no |
| The Steeple | the steeple, and at low water its roof | **yes** — the roof |
| The Quarry Wall | the cut face, too regular to be a cliff | no |
| The Spring | nothing. Open water in every direction | no |

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

**And the gate opens itself.** Deep water with the wrong bait still gives up
OBJECTS — that is what stops it being a dead end. The loop below 80 m is: pull
up pieces of a drowned town until one of them is an offering, spend it on one
deep fish, repeat. The shallowest offering (a wristwatch, 28 m) sits well inside
water ordinary bait can already reach, so the gate can always be opened before
it is met. Asserted, both halves.

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
five hands, and the last one is yours: Ruth Alder (1994), Peter Vance (1958),
Edith Moss (1931), Samuel Crake (1871). Entries unlock on **the deepest cast
ever made** — the same one number the score and the picture use, so there is no
second progression. Read in book order that is most-recent first, working back
toward the keeper who was here before the water was. Each hand fades with its
age. **DONE.**

### 7.1 The three acts, and what turns each one

The story had a table of objects and an ending marked OPEN. That is a list of
beats, not a shape — nothing said when a player moves from one feeling to the
next, or what does it. Here is the shape. **Every turn below is a thing the player
DOES, never a thing they are told**, because the second pillar forbids the other
kind.

**Act I — a good morning's fishing.** The reeds, the Channel. It is pretty, the
fish are generous, the radio gives the weather. The junk is junk: a bike frame, a
kettle, a boot. One thing is faintly off and nothing draws attention to it — the
phone that still charges has photographs of this lake on it, taken from an angle
you cannot stand in, because the place it was taken from is underwater.

*The turn:* **the licence plate, and the county that does not exist.** It is the
first object whose date and whose place cannot both be true. Most players will
shrug. It is meant to be shrugged at; it is the one they remember later.

**Act II — the town.** The Drowned Road and Old Town. The bells stop. The junk
stops being junk and starts being belongings: a suitcase packed by somebody who
expected to arrive, a mailbox with a compensation notice and the date everyone had
to be out by. The sounder — bought for fishing — is drawing rooftops.

*The turn:* **the school desk with a name cut into it, and the name is the one
written in your logbook.** This is the moment the game has been building to, and
it costs nothing but the player's own attention: they have been writing in that
book for hours.

**Act III — the keepers.** The Quarry and below. Every fish is wrong in a way that
is the same wrongness — same generator, worse numbers. The rope has no other end.
The ledger has five hands in it and you have been reading four of them since Act I
without noticing they were a list of people who did this job before you.

*The turn:* **you find the offering that opens the bottom, and it is personal.** Up
to here, an offering has been an object you chose not to sell. The last one is not
found — it is the thing you have been carrying: the logbook itself, with your
entries in it, which is what the previous four keepers each did in their turn.
That is why there are five hands, why each fades with age, and why the ledger's
wages run out.

### 7.2 The ending, which was OPEN

**The Old Fish at the Spring, and the blank page.** The Spring has no date because
it predates the town, the quarry and the water. Reaching it needs the last
offering, so the ending cannot be stumbled into — it is bought with the book.

What happens is deliberately small. The fight is the game's normal fight, at the
game's hardest numbers, with **no music at all** — the absence the score has been
building toward since the bells went. Land it and the logbook opens to the next
blank page, in a fifth hand that is not yours, dated after today.

**NG+ is the same lake, and you are the hand before last.** The book now opens
with your entries in it, one hand older and faded one step, and the keeper writing
now is somebody else. Nothing else changes, which is the point: the horror was
never that the lake was strange, it is that the job is a rota.

*Why this and not a revelation:* a game that has refused to explain itself for six
hours cannot end by explaining itself. The blank page is the only ending that
keeps the promise.

### 7.3 Progression, and how far it is really fleshed out

The ladders in §6 are sound and stay. What was missing is what each ACT feels like
to progress through, and the honest answer was that Acts II and III have the same
texture as Act I with bigger numbers.

- **Act I progresses on money.** Buy line, reach deeper, catch better fish, sell
  them. Familiar, and it should be.
- **Act II progresses on money and stops.** 40 m is the wall. The wallet keeps
  filling and buys nothing, which the player feels before they understand it.
- **Act III progresses on objects.** Money is now worthless and offerings are the
  currency, and offerings are finite. The economy inverts, and **the player who
  sold everything interesting in Act I has to go back and fish shallow water for
  things they threw away.** That is the design paying for itself: the pillar said
  money cannot buy the bottom, and this is what that costs.

**The one number.** Line length gates depth, depth gates era, era gates the story,
and the deepest cast ever made gates the logbook. Nothing is unlocked by a
separate counter, and nothing should be.

---

## 7.5 Making it more fun to actually play

Gideon: *"Look into ways to make the fishing game more fun and interactive."*
Researched against what shipped fishing games do, and filtered hard — most of what
the genre uses on mobile is live-service scaffolding this game has no use for.

**Taken, in the order they are worth building:**

- **The livewell becomes a space, not a number.** It is a weight cap today, which
  is a number that says no. Dredge's hold is a grid you pack, and it turns every
  catch into a decision — keep the good one and throw back two, or carry junk you
  suspect is an offering. This game already has the perfect tension for it,
  because **objects and fish compete for the same room**, and in Act III the
  objects are the currency. One mechanic, and it sharpens the economy inversion
  above rather than sitting beside it.
- **A second beat after the fight.** Ridiculous Fishing's lesson is that the catch
  should not end on the instant the rules resolve. Here the beat already exists in
  the fiction and is skipped in the code: **the fish comes over the gunwale and
  you decide.** Give it a moment, a weight in the hands, and the choice — keep, or
  put it back. Landing should feel like arriving, not like a state change.
- **Bait that visibly matters.** The bait table exists and does almost nothing the
  player can see. Make the choice read at the moment it pays: the right bait for
  the water gets more teases and a longer take, which is a change to the minigame
  the player is already watching rather than a hidden multiplier.
- **Daylight as the pressure, sharpened.** Time is already the resource. What is
  missing is the squeeze: the good fish are at dawn and dusk, the lamp only buys
  a little, and running out of light should feel like running out of light rather
  than like a number rolling over.
- **The wrongness of an object relative to its depth.** In Act III, objects begin
  surfacing from the wrong era for the water they came out of. The logbook records
  depth and date, so **the player's own records are what contradict each other** —
  the game never says a word. This is the one idea here that no other fishing game
  is doing, and it exists because "depth is time" is this game's alone.

**Rejected, and why, so they do not come back:**

- *Tackle as collectible cards, gacha, weekly legendary fish.* Live-service pacing
  for a game with no live service. It would add a second progression ladder, which
  pillar 1 forbids.
- *Full rod/line physics.* The rules are arithmetic. A physics body would be a
  second model of the same world — see the note in `_draw_line_between`.
- *A hunger/stamina bar.* Time is already the resource and two is one too many.

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

### 8.1 The art pass, as a list of things to fetch

Gideon: *"Update all of the models, textures, sounds, graphics in general."* The
first across-the-board art note the game has had. Scouted; everything below is
CC0 or MIT unless marked, and everything below stays inside the photoreal family
the existing Poly Haven props and HDRIs already set.

**The single biggest change is the water.** It is a shaded plane with a specular
path on it, and it is most of what the eye reads as "this looks unfinished",
because it is half the screen at all times.

| What | Source | Licence | Why |
|---|---|---|---|
| **Water shader** — Gerstner ripple, foam round the hull, shore foam | `Chrisknyfe/boujie_water_shader` | MIT | Half the screen. Drive its colour and foam from `dread`, so it is the same one number as the fog and the palette, never a second state |
| Overcast sky | Poly Haven `overcast_soil_puresky` | CC0 | The one hour the six existing HDRIs do not cover, and the right sky for the middle bands |
| Weathered planking | ambientCG `WoodSiding008` | CC0 | Reads as a boat that has sat wet for years rather than a lumberyard board |
| Rope | ambientCG `Rope001` | CC0 | The painter line, and the rope that has no other end |
| Jetty | Poly Haven `modular_wooden_pier` | CC0 | Reed Bay's landmark, and the thing you stand on |
| Roof tiles | ambientCG `RoofingTiles014B` | CC0 | The steeple's roof, at the moment you stand on it |
| Wet asphalt | ambientCG `Asphalt025C` | CC0 | The Drowned Road, which should read as a road |
| Quarry rock | ambientCG `Rock058` | CC0 | The cut face |
| Brick | ambientCG `Bricks089` | CC0 | The shed, and the town |
| Torn net | ambientCG `Net002B` | CC0 | Deep-water dressing. The intact variant nearer the surface |
| **Five handwriting faces** | Google Fonts `Caveat`, `Kalam`, `Dancing Script`, `IM Fell English`, `Homemade Apple` | OFL / Apache | The five keepers differ by WEIGHT AND COLOUR today, which is not five hands. Five real faces is about 20 KB each and is the cheapest large improvement in the game |
| UI face | Google Fonts `Manrope` | OFL | So UI chrome can never be mistaken for the logbook |
| UI kit, icons | Kenney `ui-pack`, Lucide | CC0 / ISC | Recolour the one atlas to the game's palette rather than tinting per button |
| Oars | Freesound `585312` | CC0 | Real oarlock creak. The travel-between-spots sound, which does not exist |
| Dawn birds | Freesound `852696` | CC0 | Lakeside, not generic woodland. Fades out entirely by mid-depth, beside the bells |

**What is deliberately NOT being imported, and this is a decision, not a gap:**
the hull, rod, float, fish and reeds stay generated. Their shape IS game state —
the rod's bend is the tension gauge, the float's dip is the whole nibble minigame
— and every candidate mesh found was either the wrong style family or would delete
the mechanism. The nineteen generated sounds also stay: they crossfade on `dread`,
and static loops would reintroduce a second thing that has to agree with the score.

**Misses worth knowing:** there is no CC0 photoreal rowboat, no freshwater fish, no
reeds, no stone wall, gate, church or steeple anywhere. Those are generated
geometry skinned with the textures above — which is what the existing hull already
does, so this is the established pattern rather than a compromise.

---

## 9. Audio

Nineteen generated WAVs, one key (D minor pentatonic), 22050 Hz mono.

Four music beds run **continuously** from the first second to the last; only
their levels change, on the same `dread` = depth the picture uses. The bells are
most of the first hour and gone by Old Town, and nothing replaces them — **an
absence is the loudest thing you can put in a score.**

---

## 9.4 Every menu is a thing you pick up

Gideon, in one message, asked for the logbook to be **picked up and held** with the
pages swiped, the equipment menu to be **a tackle box you look at and open**, and
the shop to be **a room the camera moves into**. Three asks, one principle, and he
arrived at it himself after seeing it work exactly once — on the logbook.

So it is the rule now, and it is worth stating as a rule because it decides
arguments that have not happened yet:

> **A screen the player opens is an object in the boat, or a place the boat
> takes them. There are no panels.**

What that buys, beyond looking better. A panel has to be *told* what it contains;
an object simply IS what it contains, so the tackle box with three lures in it has
three lures in it and cannot disagree with the economy. It also means the HUD
stops growing: the Shed / Lake / Log / Kit dock exists only because there was
nowhere else to put four buttons.

### 9.4.1 The logbook, held

*What.* Look at the book, press Use, and your hands **pick it up**. It comes up
into a reading pose, filling the lower two thirds of the frame, and the lake stays
visible over the top of it — you are reading in the boat, not in a menu.

*The pages turn by being swiped*, which is the one place a drag survives in this
game now that the stick owns looking. A page lifts, rotates about its spine and
falls, with the next page printed on its back. That is 11.9d, and it is the same
single rotating quad the old plan described.

*What is in it.* It already holds the species pages and the five hands. It gains
the front matter a keeper's book actually opens with: **fish counted, biggest by
species, days kept, deepest cast, spots visited, offerings kept.** Those are stats,
and putting them in the book rather than on a stats screen is the whole point —
**the book is the save file made visible**, and in Act III it becomes the last
offering, which only lands if the player has spent hours in it.

*Why it matters to the story.* Picking it up is the gesture the game ends on. If
the player has never held it, handing it over costs nothing.

### 9.4.2 The tackle box, opened

*What.* The metal toolbox is already in the boat and already downloaded. Look at
it, press Use, the **lid opens** and the camera comes down over it. Inside, in the
trays: the rods you own, the reels, the lines, the baits. Tap one to equip it.

*Why this is better than the Kit panel.* Line is the story's only ladder, and in a
list it is a row that says "40 lb braid". In a box it is a spool that is
physically there, next to the four you have outgrown, and the empty tray where the
one you cannot afford yet would go. **The progression becomes a picture of
itself.**

*Same pattern as the book*, which is the proof it works: a `Room3D` with an open
and shut state, a printed surface, and hit-testing on the tray.

### 9.4.3 The shed, entered

*What.* The shop button stays — it is the one screen that is not in the boat, and
you have to go somewhere for it. Pressing it **rows you to the bank and walks you
into the shed**, and the camera does not cut once.

*What the shed is.* A small stone-and-timber building beyond the gate, lit by one
window and the lamp you may or may not have bought. It is an old bait shop that
has not been a shop for a long time: a counter, a ledger, shelves with more empty
hooks than full ones, and price tickets in a hand you will later recognise from
the logbook. **The keeper before you ran it.** Nothing says so.

*Why a room and not a counter.* Because of what it lets Act III do. When money
stops working, the shed does not close — it stays open, fully stocked, and useless,
and the player walks through it to reach the one shelf that matters. A panel cannot
be walked through.

*Cost control.* One room, one door, three fixed camera poses (in the doorway, at
the counter, at the shelf). It is not a walking simulator, it is the gate sequence
pointed at a building, and the gate sequence already exists.

---

## 9.5 The seams, which are where it currently stops being a place

Gideon: *"make sure each part moves smoothly into the next."*

Read as a note about SEAMS it is precise and actionable. The game has one
beautiful transition — the walk down through the gate — and everywhere else a
screen replaces another screen instantly. The gate proves the machinery: a
sequence is a list of shots over the real scene, so the world never has to be
kept in step with itself and the hand-back is invisible.

Every seam below is currently a cut, and every one of them already has the tool
to be a move.

| Seam | Now | Should be |
|---|---|---|
| Travel between spots | the map closes, you are elsewhere | you row. Oars, the bank sliding past, the landmark you are leaving and the one you are arriving at |
| Sleeping | the hour changes | the light goes, the boat is tied up, dawn |
| Opening the shed | a panel | the walk up the jetty and in through the door (11.9c) |
| Landing a fish | a state change | over the gunwale, weight in the hands, then the decision (7.5) |
| Buying line | a list row | spooled onto the reel, which is the one purchase that changes the story |
| Going to the title | a fade | there should be no title after the first launch. Continue IS the walk down |

**The rule this comes down to:** a cut is acceptable when the player asked to be
somewhere else immediately, and never when the game is moving them. Rowing is the
game moving you and it is currently a menu closing.

**And a seam has a cost.** The gate sequence is under five seconds because it
plays every session, and any touch cuts it. Every transition above inherits both
rules — a beautiful thing you cannot skip is the worst thing in the game by the
fifth time.

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

### 11.0 The gate

*What.* The game begins on the WRONG SIDE of a wooden gate in a stone wall, at
the end of the keeper's bank. Continue opens it and walks you down to the boat.
New game does the same walk with the reason for it.

*Why it is not set dressing.* **It is the ritual.** A keeper of this water walks
down through that gate to the boat and does it every morning — so the way into
the game and the way the fiction works are the same motion. The player does not
press Continue; they go out.

*How.* `sequence.gd` is a list of shots — position, look-at, duration, easing,
how far the gate is open, and optionally a line. The rig interpolates between
consecutive shots, so a cinematic is written as places to BE rather than as a
path, and it is data rather than code. It plays over the real scene: same water,
same sky, same hour, so nothing has to be kept in step, and the hand-over at the
end is invisible because the last shot rests exactly on the seat.

*Rules.* Under five seconds for Continue, because it plays every session. **Any
touch cuts it** — a beautiful thing you cannot skip is the worst thing in the
game by the fifth time. The touch that skips does not also cast.

*Test.* Both sequences end at the seat with the gate open and the HUD back; a
tap on the first frame cuts either one and fires nothing.

---

### 11.1 The title

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

### 11.2 The first morning

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

### 11.3 The keeper's logbook

*What.* The story's spine. Entries in five hands, unlocked by DEPTH.

*How.* A table in `src/sim/keepers.gd`: `{keeper, depth, text}`. The Log grows a
second tab. Unlock is the deepest cast ever made, saved as one float — the same
number the score and the picture already use, so no new progression.

*Feel.* Handwriting changes between keepers by font weight and colour only. The
fifth hand is the player's, and its entries are the ones the game has been
writing all along: the species records.

---

### 11.4 The radio

*What.* The one speaking character.

*How.* A prop on the thwart with an interaction point. Generated speech is out
of reach, so it is TEXT over a generated carrier-and-static bed — which is
better anyway, because a voice would date the game and static does not. Messages
are a table keyed on depth and hour.

*Feel.* Starts as weather reports. The reports slowly stop being about weather.
By the Quarry it reads the day's catch back to you.

---

### 11.5 Wrong fish

*What.* `wrong` exists in the species data and changes nothing on screen.

*How.* The generator already takes every shape parameter from data. A wrong fish
gets its `look` fields pushed past the range a real fish uses — an extra pair of
fins, an eye with no iris, a body a third too long. No new code path; the same
generator, worse numbers.

*Feel.* Never remarked on. The logbook prints the note in the keeper's hand and
the game says nothing.

*Built as:* body 22% longer and 14% thinner; the counter-shading gives out, so
it is evenly coloured all round, which reads as wrong long before anyone works
out which rule it broke; the eye goes matte with no highlight, the cheapest way
to make a thing look dead. Below 80 m it also grows a **second pair of fins** -
`wrong` alone does not earn that, being deep as well does, so Old Town is subtly
off and the Quarry is not subtle.

---

### 11.6 First-run polish

Orientation lock, a pause that actually pauses, a proper app icon, and the
audio starting on first touch rather than on boot.

---

### 11.7 The ending

The Old Fish at the Spring, the blank page, and NG+ where the lake remembers.

---

### 11.9 Rooms as objects IN THE WORLD

*What.* Gideon: "I was wanting real physical objects and places... I want to
physically see the book in the boat. When you click on it, it opens and zooms in
on the pages, then you flip each page." And the tackle box as a real 3D model
you open to choose gear, and the shed as a building the camera flies to.

*The architecture that makes it affordable.* `room3d.gd`. A room is a Node3D in
the boat with a model, a **SubViewport** whose Control tree is rendered onto a
quad on the object, and a computed camera pose. So the page content is still
ordinary Control layout — the same paper, ink and entries — but it becomes the
SURFACE of a physical thing rather than a panel over the screen. Laying text out
as 3D nodes instead would mean re-solving wrapping and hit-testing in a space
that has neither.

*The book — DONE.* A Poly Haven notebook on the sole. The asset ships BOTH an
open and a closed mesh, so opening it is a swap between the model's own two
states rather than an animation nobody has to author. The camera distance is
**computed** from the page size and the camera's own fov — hand-tuned poses were
wrong three times running. Taps land on the page by ray: left third goes back,
the rest goes on, past the last page it shuts, and tapping off the book shuts
it too.

*Hard-won:* the page spent four rounds of debugging **buried in the
floorboards** — planks are 30 mm thick sitting 20 mm off the sole, and the page
was below their top face. The texture was correct the whole time. A test now
asserts the page clears everything lying on the sole, which is the only thing
that could have found it.

*The tackle box — NEXT.* `metal_toolbox` is already downloaded. Same Room3D:
it sits by the thwart, the lid opens, and the inside of the lid is the surface.
Gear as objects in the trays rather than rows — spools for line, a card of hooks
for rods, the bait tins already modelled.

*The shed — NEXT.* Not a Room3D: a place. Build it beyond the gate from the
stone and timber already in the project, and make Shed a camera SEQUENCE that
lifts off the water, turns, and drops into the doorway — the same rig the gate
walk uses.

---

### 11.8 Rooms as flat skins **[superseded by 11.9 for the book]**

*What.* Gideon: "I want the menus to feel more interactive, like a physical book
with pages that turn, a store front, a lunch box with items, not just text
menus." Right, and it applies to the three the player uses most.

*The book — DONE.* The Logbook is a sheet of paper: warm ground, a darker gutter
and stitching down the binding edge, foxing placed off a fixed hash so it does
not crawl on redraw, a page-edge shadow, ruled lines under every heading, and
dark INK instead of cream. The older a keeper's hand, the more it has faded into
the paper. The way out says "Shut the book".

Everything is drawn rather than imported: a page is a colour, a grain and an
edge shadow, and a photograph of paper would drag its own lighting into a game
that has spent a lot of effort having one of its own.

*Still to do on the book:* actual page TURNS instead of one scroll — split the
entries into spreads with a corner to tap, and a turn that animates.

*The shed — DONE.* Varnished planks running across, each with a lit top edge and
a shadow under it, grain strokes, and a worn band along the near edge where a
hundred years of forearms have rested. Items sit on lighter shelf slats. **The
price is a card** propped against each one, with its own drop shadow — it is the
one thing on a shopfront that is always written down rather than known, and
giving it its own bit of stock is most of what makes a row read as a shelf.
The way out says "Back to the water".

*The kit — DONE.* Painted metal seen from above: a lid seam with hinge knuckles
across the top, rivets in the corners, paint worn off down both edges, and rows
as SUNK trays — light edge at the bottom rather than the top, which is what
makes a rectangle read as a recess instead of a button. The way out says "Shut
the lid".

*How they share it.* Not by copying the book — a room declares a SKIN and the
ground, the row styling, the ink, the headings and the way out all read it. Four
skins, one code path. Copying would have been three special cases that drift.

*Test.* Each room is a DIFFERENT skin, and its ink is legible on its own ground
— composited, since a row colour can be translucent. Cream on cream is one edit
away at all times and is exactly what this catches.

*Still to do:* real page TURNS for the book — split the entries into spreads
with a corner to tap.

*The rule for all of them:* the room should look like the object it is named
after, and every one is drawn, not imported — a photograph of paper or wood
would drag its own lighting into a game that has worked hard to have one of its
own.

---

## 12. The milestones

**This list is the single record of what is built.** Section 11 says what each
one IS; this says whether it exists. The status used to be written in both
places and they drifted — section 12 was still calling the logbook "next" after
11.3 shipped it — so the markers came out of the section 11 headings and live
only here. A resuming session works from the first unticked box.

### Foundations

- [x] The stack: pure sim, headless tests, whole-run golden, size guard, CI, build stamp, changelog
- [x] The world — bands, spots, clock, weather, `BOTTOMS` (§5)
- [x] The economy and the gear ladders, LINE as the only progression (§6)
- [x] The three minigames: cast, nibble, fight (§4)
- [x] Save and restore, including a malformed save leaving a playable boat
- [x] The sounder — the bed's own silhouette, and no fishing advantage at all
- [x] Audio and the mood arc, both driven by `dread` and both asserted (§9)
- [x] Boat motion, look control, action button, the juice layer, feel tests
- [x] Imported props, mipmaps and anisotropic filtering, `test_assets.gd` (§8)
- [x] The four rooms: Shed, Lake, Log, Kit
- [x] In-boat interaction — the livewell, lamp, bait box and rope answer a look

### The build, section by section

- [x] **11.0 The gate.** The game begins on the wrong side of it; Continue is the walk down
- [x] **11.1 The title.** The real scene running behind it, not a separate scene
- [x] **11.2 The first morning.** The intro that teaches by being played
- [x] **11.3 The keeper's logbook.** Entries in five hands, unlocked by depth
- [x] **11.5 Wrong fish.** The same generator with worse numbers, and they look it
- [x] **11.9 Rooms as objects in the world** — the logbook, as a real notebook in the boat

---

## Phase F — feel. *"The movement has felt odd"* (2026-09-10)

- [x] **F1 The hull and the head are two transforms.** Camera pitch 20.0° → 1.1° peak-to-peak, peak rate 41.9 → 3.1 °/s, hull back to rolling further than it pitches. Measured with `scripts/probe_motion.gd`
- [x] **F2 The rod lags the boat.** Driven by the hull's angular velocity, not its angle
- [x] **F3 The line is a line under tension.** Ten segments along a sag whose depth is the fight's own tension
- [x] **F4 The stick has a gradient dead zone and a response curve.** The hard 0.14 cutoff is gone
- [ ] **F5 The cast is smooth.** The charge, the throw and the settle are three eases that do not share a curve; the release should carry momentum into the flight rather than restarting it
- [ ] **F6 The fight is smooth.** The needle's overshoot should read as weight rather than lag — this is the one that needs the phone, not the desk
- [ ] **F7 Judge F1–F6 on the phone.** `/playtest phone`. Nothing in this phase is finished until it has been held

## Phase B — the body. *"So it doesn't look like a person is actually sitting in it"* (2026-09-10)

- [x] **B1 Still water.** Wave amplitude 0.16 m → 0.063 m. A third short wave keeps the surface alive at close range, because cutting amplitude alone gives calm water that also looks dead
- [x] **B2 The bobber floats on the lake, not on the boat.** It read `_boat_pose`, so it inherited the hull's heave from 30 m away and its pitch, which swung it 1.3 m
- [x] **B3 The seat is inside the boat.** It was 1.05 m behind the transom. Now on the centre thwart, placed off the hull's own profile
- [x] **B4 The rod is in the hands**, not standing in the bottom of the boat three metres ahead
- [x] **B5 The stick is the only way to turn.** Swiping no longer looks. The charge-cancel survives, so a brushed thumb cannot fire a cast
- [x] **B6 A seated person can look down.** The pitch limit is asymmetric: 57° down, 23° up
- [ ] **B7 Hands.** There is a rod and no one holding it. Two low-poly hands on the grip, and the near one leaves to tap
- [ ] **B8 The cast is a body movement.** The rod comes back past the shoulder, so the butt moves and not only the tip

## Phase R — the rooms as objects (§9.4). *"You actually pick up and view the log book"*

- [ ] **R1 The logbook is picked up and held.** Into a reading pose over the lake, not a camera dive onto the sole. Front matter added: fish counted, biggest by species, days kept, deepest cast, spots visited, offerings kept
- [ ] **R2 Pages are swiped, and they turn.** One rotating quad with the next page on its back. The one place a drag survives now the stick owns looking. Subsumes 11.9d
- [ ] **R3 The tackle box replaces the Kit panel.** Look at the box, the lid opens, the gear is in the trays, tap to equip. The line ladder becomes a picture of itself. Subsumes 11.9b
- [ ] **R4 The shed is a room you are taken to.** Shop button, rowed to the bank, walked in, no cut. Three fixed poses; it is the gate sequence pointed at a building. Subsumes 11.9c and P3
- [ ] **R5 The dock disappears.** Shed / Lake / Log / Kit exists only because there was nowhere else to put four buttons. Once each is a thing, the HUD is the action button and the stick

## Phase W — the water and the art pass. *"Update all of the models, textures, sounds, graphics"*

- [ ] **W1 The water shader.** `boujie_water_shader` (MIT), foam round the hull, colour and foam driven from `dread` so it is not a second state. Half the screen at all times; the biggest single change in the game
- [ ] **W2 The overcast sky**, and the middle bands moved onto it
- [ ] **W3 The surfaces of the drowned town.** Roof tiles, wet asphalt, quarry rock, brick, torn net — the textures the generated geometry in Phase P will be skinned with
- [ ] **W4 Five real hands in the logbook.** Five typefaces, not one at five weights. About 20 KB each and the cheapest large improvement available
- [ ] **W5 UI face, kit and icons**, with the atlas recoloured once to the game's palette
- [ ] **W6 Oars and dawn birds.** The two sounds that genuinely do not exist. Everything else generated stays generated
- [ ] **W7 The planking and rope textures** on the hull that already exists

## Phase P — the lake as a place. *"Not that one boat in that one spot"*

- [ ] **P1 One landmark per spot.** Six silhouettes, each visible from the seat and never repeated. Most of the effect for almost none of the work — do this first
- [ ] **P2 Rowing between spots.** The map stops being a teleport. Oars, the landmark you leave, the one you arrive at, skippable like the gate
- [ ] **P3 The bank you can stand on.** Reed Bay: the jetty, the wall, the gate, walkable. Subsumes 11.9c, the shed as a place
- [ ] **P4 The roof of the steeple.** At low water at Old Town, tie up and stand on a rooftop forty metres above a street. The image Act II turns on
- [ ] **P5 Sleeping, and the light going.** The hour change becomes a transition rather than a number
- [ ] **P6 The same spot at a different hour is a reason to go**, not just something that happens to you

## Phase G — the game underneath. *"More fun and interactive"*

- [ ] **G1 The livewell becomes a space you pack**, where fish and objects compete for the same room. Sharpens the Act III economy inversion rather than sitting beside it
- [ ] **G2 A second beat after the fight.** Over the gunwale, weight in the hands, then keep or return
- [ ] **G3 Bait that visibly matters** — more teases and a longer take, read in the minigame the player is already watching
- [ ] **G4 Daylight as a squeeze.** The good fish at dawn and dusk; the lamp buys a little; running out of light should feel like it
- [ ] **G5 Objects from the wrong era for their depth**, in Act III. The player's own logbook is what contradicts itself

## Phase S — the story finished. *"Make the story and progression fleshed out"*

- [ ] **S1 The three act turns land**, each as a thing the player does: the licence plate, the school desk, the logbook as the last offering (§7.1)
- [ ] **S2 The radio** (11.4). The one speaking character; weather reports that stop being weather reports
- [ ] **S3 The economy inverts in Act III.** Money worthless, offerings finite, and the player who sold everything in Act I goes back for it
- [ ] **S4 The ending** (§7.2). The Old Fish, no music at all, the blank page in a hand that is not yours
- [ ] **S5 NG+.** The same lake, your entries one hand older, somebody else writing now

## Phase T — the seams (§9.5)

- [ ] **T1 Travel, sleep, shed, landing and the line purchase all become moves rather than cuts.** Every one already has the tool: a sequence is a list of shots over the real scene
- [ ] **T2 No title after the first launch.** Continue IS the walk down
- [ ] **T3 11.9b The tackle box as a Room3D**, and **11.9d real page turns** — the two remaining room seams
- [ ] **T4 11.6 First-run polish.** Orientation lock, pause, app icon, audio on first touch

### Open, and not milestones

- [ ] **The lamp doing something.** Fishing after dark is currently identical to fishing at noon. Folded into G4
- [ ] **The sheer hairline remnant** on the near port rail at a low sun. Mechanism understood (NOTES.md); the fix is one number in two places

### The order, and why

**F and B are done. Then R, then W1, then P1.** Feel first because he raised it
first and because everything else is judged through it. Then the rooms, because he
has now asked for that pattern in every screen the game has and because R4's shed
is also P3's bank - one build, two milestones. Then the water, because it is half
the screen and the whole game looks unfinished until it is fixed. Then the
landmarks, because they are one mesh each and they are what makes six spots six
places.

After that the phases interleave rather than run in order: P2 rowing wants W6 oars,
G2 wants T1's landing transition, S1 wants G5's wrong-era objects. The dependencies
are named in each line so a session can pick up any of them.
