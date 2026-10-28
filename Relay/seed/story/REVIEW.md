# Story table rows: review

The reviewed rows of the relay's story tables, one seed file per table in this folder. Every
row was checked against the game's own events in the TEST install (untranslated 3.06) on
2026-10-28: rows that were wrong were fixed from the data, rows the data does not hold were
dropped, and missing rows were added only where the table's purpose needs them. Each table's
section below lists what was checked, fixed, dropped and added, with the reasons, and what is
left for the user to decide.

## How the rows reach a relay

- Each `<table>.json` is the list of edits an admin sends to `POST /v1/admin/story/edit`, each an
  `add` of the file's table. The rules, counts and companion values are kept by hand in
  `make_seed.rb` as `{source, rows}` instead.
- At its start the relay fills each table that holds no rows from its file, once. A table it
  filled or found with rows is never seeded again, so a table the admins emptied stays empty.
- The admin route takes at most 2,000 edits per request, so an admin sends the larger files in
  slices. The seeding has no such limit.
- Seeding leaves the edits' `note` out; an admin who applies the files keeps them.
- The tests of the DLL and of the scripts still read the generated candidates in
  `fixtures/catchup/generated`, which `make_seed.rb` writes from the Ruby constants, since their
  recorded cases were decided over those tables. The reviewed rows reach only the relay.
- The review scripts are kept outside the repository, in `MGQ-Online-wt/rows-scratch`.
- The `index` of `joins` and `removals` was reviewed as the command's place in the TEST install's
  lists; since 2026-10-28 it holds the command's `ord` in the events database, which
  `MGQOnline.Data.Generator ordinals` wrote from those places with every join and removal of one
  companion in one list kept in its order (Relay/README.md "Join and removal indexes as ords").

| Group | Table | Rows |
|---|---|---|
| Chests | [chests](#chests) | 107 |
| Chests | [chest_flags](#chest_flags) | 227 |
| Chests | [party_chests](#party_chests) | 5,303 |
| Classes | [class_levels](#class_levels) | 2,079 |
| Rewards | [rewards](#rewards) | 888 |
| Rewards | [key_items](#key_items) | 153 |
| Rewards | [event_rewards](#event_rewards) | 417 |
| Companions | [joins](#joins) | 662 |
| Companions | [removals](#removals) | 222 |
| Companions | [lessons](#lessons) | 112 |
| Companions | [actor_changes](#actor_changes) | 81 |
| World | [parts](#parts) | 6 |
| World | [settings](#settings) | 95 |
| World | [vehicles](#vehicles) | 23 |
| World | [warp_free_maps](#warp_free_maps) | 158 |
| World | [makina](#makina) | 29 |
| World | [prize_variables](#prize_variables) | 88 |
| World | [prize_switches](#prize_switches) | 5 |
| World | [side_events](#side_events) | 19 |
| Keys | [keys](#keys) | 3,754 |
| Keys | [events](#events) | 251 |

The user decided the review's open questions on 2026-10-28 ("MGQ Online row decisions.md" in the
workspace); each section lists them under "Decided by the user" with what they changed. The 164
loot pages that also move the story and the places of the 8 world chests without a part were
decided after the research the user asked for (the [party_chests](#party_chests) and
[chests](#chests) sections). Still open: the three warp-free maps left out for their own bans (the
[warp_free_maps](#warp_free_maps) section), and the defeated-boss rows (BEATEN), which wait for the
raid rules question C4.

## Chests

### chests

These are the chests that hold key items, or items that unlock a job or a race. In a Raid World
each of these chests opens once for the whole world, together with the chest flags it turns on
(world `CHESTS` of `world_catchup_data.rbx`). Reviewed on 2026-10-28 against the game data of the
TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/chests.json`) | 95 |
| Confirmed in bulk | 91 |
| Checked by hand | 4 (and the place of 10 more) |
| Fixed | 3, and the places of 10 by the user's decision |
| Dropped | 0 |
| Added | 12 (by the user's decisions) |
| Written (`Relay/seed/story/chests.json`) | 107 |

### How the rows were checked

A script checked each row against the event its key names:

- The page that turns the row's self switch on must give each listed item. The self switch must
  be turned on in the same branch as the gift.
- The items must be exactly the key items (item type 2, described as `[Key Item]` or
  `[Material]`) and job or race unlock items (described as `[Job]`/`[Race]`, or `[職業]`/`[種族]`)
  that this page gives.
- `flags` must be exactly the chest flags (the reviewed `chest_flags`) that the page turns on.

91 rows passed. The other 4 were read by hand.

Missing rows were looked for the other way round: every reviewed party chest that gives a key
item or an unlock item was compared with this table. Only the three fixed rows below turned up,
so no row is missing.

### Checked by hand and confirmed (1)

- **ss298.12.A** (Hall of Creation B1F): the chest turns A on before a branch. The branch gives
  the Baptism Seal (621), or a Frigid Blue Ice Stone (57) when the player already holds the seal.
  The row is right.

### Fixed (3)

- **ss51.23.A → ss51.23.B** (Pornof, Fortune Teller Permit 610): B shuts the trade that gives the
  permit. A only marks the first talk. With A, any player who had talked to the Fortune Teller
  would have handed every player who falls behind the permit and opened A for them, which leaves
  the trade open for a second permit.
- **ss1650.14.A → ss1650.14.C, step 18 → 30** (Dark Goddess' Castle, Saja, Sealed Orb of the
  Warrior 665): C shuts this gift, in her talk on route steps 30 to 42. A shuts her earlier gift
  of four weapons. Order 410 → 425, after Finoa (route step 20) and before the Gold Volcano (31).
- **ss1650.44.A → ss1650.44.B, step 44 → 52** (Dark Goddess' Castle, Minagi, Sealed Orb of the
  Seeker 671): B shuts this gift, in her talk on route steps 52 to 57. A only marks a talk.
  Order 510 → 565, after the other chests at route step 52.

Each fixed row carries a `note` with its reason.

### Added by the user's decisions (12)

- **s2719** (Monster Realm Sabasa indoors, map 1556 event 121, Sealed Orb of the Land-Dweller
  767, `[Job]`): the chest gives the orb and turns on switch 2719 ("Treasure Chest: Land-Dweller's
  Sealed Orb"), whose page 2 shuts it. The user decided on 2026-10-28: "Once opened everyone
  acquires it." So it is a world chest, keyed by its switch: the relay's `chests` take a switch
  (`s<id>`) as `key` besides a self switch, and the DLL's catch-up reads that switch for the
  world's and the player's story and turns it on where it shuts a self switch. Part `mr`, step 51,
  as its rewards row had it (order 535). The rewards row of the orb is dropped (see the
  [rewards](#rewards) section), so the orb is not given twice. The switch stays `shared` in `keys`.
  In a Classic party the leader's switch carries over already, and the member gets the orb with
  the leader's key items (item type 2, `coop_story.rbx` `fill_items`).
- **11 of the loot pages that also move the story** (the [party_chests](#party_chests) section),
  by the user's decision of 2026-10-28 on the research of decision 3 ("accept the proposals"):
  key items and ores a quest needs that lie in a chest or are a plain pick-up, and two job items.
  Each opens once for the whole world, as the Lump of Iron and the Gold Ore do already. Each has
  its `events` row (`shared`, the [events](#events) section), and the row that gave its item to
  players behind is dropped, so nothing is given twice: 9 `key_items` rows and 2 `rewards` rows
  (see those sections). Part and step are those rows' places, the order among the rows of the
  same step by key:
  - **The five Mitra tablets** (Chaos step 21): ss1271.25.A Sealing (948), ss1353.11.A White
    (951), ss1377.105.A Sin (950), ss1798.12.A Black (952), ss1830.6.A Shinra (949). Each chest
    adds 4 to the shared v1350 (tablets remaining) and calls CE 9053 (the tablet's lines); as a
    world chest it opens, and counts in v1350, once.
  - **ss67.2.A**, the Magical Thread (518) in Seeker's Cave B3F, which moves the Puppeteer's
    Tower quest on (v1026 to 3). Its key_items row had no place. The page sends the player away
    until v1023 and v1026 are at 2, and v1023 reaches 2 at part 2 step 28 (map 351 event 16), so
    the row sits at part 2 step 28.
  - **ss1649.14.A**, the Witch's Secret Elixir Recipe (958) in the Chaos Grand Pirate's Cave
    (Chaos step 21), which moves Vanilla's elixir quest on (v1366, s7062).
  - **ss205.4.A**, the Witch's Soul (675, `[Job]`) in the Forgotten Tower (Collapsed), part 3
    step 35.
  - **ss645.9.A**, Mithril Ore (153) on Mt. Saint Amos, part 1 step 12. Page 1 gives the ore and
    page 2 asks for self switch A, so the self switch shuts it; the shared switch 2066 (Mythril
    Possession) only notes the ore for the blacksmith. Its key_items row was marked by 2066, but
    none of the 11 pages is shut by a plain switch, so none needs a switch key like s2719.
  - **ss267.7.A**, Orichalcum (156) in the Lava Mining Cave B1F, part 2 step 26 (v1064 to 2).
  - **ss551.17.B**, King Remina's Soul of the Warrior God (622, `[Job]`), part 2 step 29: B
    shuts the gift; A only marks Heinrich's talk on Ilias's side and stays the story's.

  None of the 11 is a party chest: in a Classic party their self switches follow the leader's
  story together with the quest values they move, as before.

### Part and step

The game reads only `key`, `items` and `flags` of these rows (`CatchupLook.WorldItems`,
`CatchupEngine`). `part` and `step` only give the rows their order. They were checked like this:

- Every Final Chapter row's part was compared with the route variables its map's events read
  (1141 for the Angelic Dominion, 1142 for the Monster Realm, 1143 for Chaos) and with its map's
  name. No row contradicts them.
- Every row's step was compared with the progress conditions on its page and branch. Only the
  two Dark Goddess' Castle rows had a step to fix.

The places of these 10 rows were read by hand, and the generated values were kept at first:

- **Maps 265, 298, 369, 371, 372** (8 rows: Pornof Mines B2F, Hall of Creation B1F, the Ghost
  Ship) have no part and no step. Each map can be entered from the field in Parts 1 to 3 and
  again from Chaos route maps, so no single place fits them.
- **ss288.6.A** (Midas Abandoned Mines B1F, Gold Ore) and **ss368.7.A** (Hidden Hole, Beckoning
  Cat) are placed on the Chaos route, at steps 10 and 21. Both maps can be reached from the field
  earlier too. These are questionable, but the game does not read them.

The user then had them researched and placed them on 2026-10-28 (decision 2): each sits where the
story first leads to its area. Every dungeon is entered from the field (map 2) or from a town
without a story condition, so the place is the earliest step where the area's own rows and quests
sit, held against its enemies' levels; the Final Chapter maps that lead into the same dungeons
again gave the generator no place or a Chaos one. Each moved row carries a `note`, and the order
values keep the table's order (by part and step, by key within a step):

| Row | Item | Was | Now | Order |
|---|---|---|---|---|
| ss265.3.A, Pornof Mines B2F | Lump of Iron (151) | none | part 1 step 10 | 880 → 52 |
| ss288.6.A, Midas Abandoned Mines B1F | Gold Ore (152) | Chaos step 10 | part 1 step 10 | 770 → 56 |
| ss368.7.A, Hidden Hole | Beckoning Cat of Good Fortune (544) | Chaos step 21 | part 1 step 13 | 870 → 95 |
| ss369.10.A, Ghost Ship deck | Captain's Cabin Key (534) | none | part 2 step 25 | 910 → 151 |
| ss371.12.A, Ghost Ship B2F | Purple Orb (541) | none | part 2 step 25 | 920 → 152 |
| ss371.20.A, Ghost Ship B2F | Pirate Treasure (545) | none | part 2 step 25 | 930 → 153 |
| ss372.3.A, Ghost Ship cabin | Treasure Vault Key (535) | none | part 2 step 25 | 940 → 154 |
| ss372.7.A, Ghost Ship cabin | Healing Shell (511) | none | part 2 step 25 | 950 → 155 |
| ss298.12.A, Hall of Creation B1F | Baptism Seal (621) | none | part 2 step 32 | 890 → 172 |
| ss298.14.A, Hall of Creation B1F | Spirit Powder (554) | none | part 2 step 32 | 900 → 174 |

- **Pornof Mines and Midas Abandoned Mines** (part 1 step 10): the mines' enemies are level 5 and
  9, Pornof's own rows sit at part 1 step 10, and the Midas Village smith asks for the Gold Ore
  on his page for 1001 at 10.
- **Hidden Hole** (part 1 step 13): reached through Orochi's Cave and the Waterfall; the area is
  Yamatai's, whose rows start at part 1 step 13, as the joins review placed Yamata no Orochi.
- **The Ghost Ship** (part 2 step 25): boarded from Gold Port once the Ghost Ship event (v1067)
  is at 2; the ship's own rows sit at part 2 steps 24 and 25, the crew joining through CE 341 at
  step 25, and its enemies are level 36.
- **Hall of Creation** (part 2 step 32): the story leads there in Micaela and Lucifina's revival
  quest (v1077, map 297 event 13) at part 2 step 32, and its enemies are level 51 to 52.

No chest row is left without a part.

### Decided by the user (2026-10-28)

1. **A chest shut by a switch, not a self switch, that gives a job item** (switch 2719): "Once
   opened everyone acquires it." It became a world chest keyed by its switch, see Added.
2. **Places** of the 8 rows without a place and the two Chaos placements: decided after the
   research, "accept the proposals": Pornof Mines and Midas Abandoned Mines at part 1 step 10,
   the Hidden Hole at part 1 step 13, the five Ghost Ship chests at part 2 step 25 and the Hall
   of Creation at part 2 step 32, see Part and step.
3. **The 164 loot pages that also move the story** (the [party_chests](#party_chests) section):
   after the research, 11 of them became world chests, see Added.

### Notes

- The generator's first-letter rule (`raid_data.rb` `scan_chest`) caused all three fixes.

### chest_flags

These are the switches only chests turn on. Each one is a chest's own record that it was opened,
so each player keeps their own, like the chests (`coop_story_rewards.rbx` `CHEST_FLAGS`; the
story mapping's `chest` kind). Reviewed on 2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/chest_flags.json`) | 196 |
| Confirmed in bulk | 185 |
| Checked by hand | 11 |
| Fixed | 0 |
| Dropped | 1 |
| Added | 32 |
| Written (`Relay/seed/story/chest_flags.json`) | 227 |

### How the rows were checked

Running the Event Checker's own flag rule (`story_rewards.rb` `chest_flags_of`) over the TEST
install gives exactly the 196 candidates. A separate script then went through every place that
turns a switch on, turns it off or reads it: map pages, common events, troop pages, and scripts.
A switch passed in bulk when all of these hold:

- Every page that turns it on is a chest: it gives something, and it does nothing that moves the
  story (no variables, battles, transfers, common event calls or other switches).
- Nothing turns it off except the chapter resets. Common events 153, 154 and 155 clear whole
  ranges of switches when the player restarts a chapter.
- Nothing reads it except the events that turn it on.

185 switches passed. The other 11 were read by hand.

### Checked by hand and confirmed (10)

- **2045 Initial Machine**: six Makina chests in Tartarus turn it on. The engineer at map 191
  event 86 reads it and hands out the Machinist License once a Makina was found. A player who
  opens their own chest gets their own license, so the switch belongs to each player.
- **2047 Old Betty Parting Gift**: a one-time gift of potions (map 6 event 26). The switch shuts
  the gift. Old Betty's other lines (an inn rest) kept this page out of the bulk pass.
- **2636, 2637, 2638 Treasure Chest: Angelic Dominion Grand Noah Castle 1-3**: these chests
  appear on two map copies. The conquest copy (map 1516) also calls common event 421, which only
  holds a remark (it turns on 2593 for the remark).
- **2750 Ragnarok Acquired**: the Ragnarok chest (map 1081 event 52) turns it on. The only other
  reader is Velraune's lines on map 1080.
- **2917 Dragonstone Treasure Chest**: a scene (map 922 event 8) opens the chest of event 7 and
  notes it in this switch. Event 7 reads it to stay open.
- **7102, 7103, 7104 Carrying Moonbow Crystal / Crystal of Nothingness / Final Ore**: the world
  chests of these materials turn them on. The Chaos forge (map 1692) reads them to offer that
  material's equipment. Each player's own material gives each player's own offer.

### Dropped (1)

- **2914 Give Sheep-sama Alcohol**: no chest turns it on. It is set when the player gives the
  Sheep Girl a Yamatai Sake (map 885 event 25), and that page takes an item away instead of
  giving one. The generator counted a command that takes an item as a gift. Until now 2914 was
  each player's own; from now on the story mapping decides it. Its self switch `ss885.25.A` is
  dropped from `party_chests` too.

### Added (32)

- **2915 Ruling Crown Treasure Chest** (map 892/953 event 2) and **2927 to 2957, T1-1 to T10-3**
  (the Demon Castle Tour's chests, maps 922 to 931). Each is a chest that gives equipment, plays
  the chest sound and records being opened in its own switch instead of a self switch, just like
  the Final Chapter's "Treasure Chest:" flags. The generator left them out because one more
  event reads them: on each floor the Spirit Fox counts the chests still closed (variable 1229)
  and says how many remain. That count covers exactly these chests, so it fits each player's own
  chests. Without these rows a party member's tour chests follow the leader's. The table exists
  so that each player's chests stay their own, so the switches were added. Each carries a `note`.

### Not added

- **2958 Sheep-sama** (map 925 event 11): a one-time gift that records itself in its switch,
  like Old Betty's. But its page asks for the tour's progress (variable 1216), so it is part of
  the story, not a chest.
- **2719 Treasure Chest: Land-Dweller's Sealed Orb**: a chest of a job item that records itself
  in a switch. See the open questions in the [chests](#chests) section.
- **2593** (the remark of common event 421) and similar switches that only a chest's remark
  turns on.

### Decided by the user (2026-10-28)

1. **The 32 added switches** stay each player's own, as recommended: each player opens their own
   tour chests, and the Spirit Fox counts each player's own. The 32 rewards rows they alone mark
   stay dropped.
2. **2914** is shared ("global"): the world's story keeps the Sheep Girl's sake, as the `keys`
   rows have it since this review.
3. **2719** became a world chest keyed by its switch, see the [chests](#chests) section.

### Notes

- The Event Checker's `chest_flags_of` keeps out switch chests that any other event reads, which
  is how the tour's chests were missed. Its `CHEST_CODES` also counts taking an item as a gift.

### party_chests

The self switch of every chest of the game, which a party member who catches up keeps their own
of (`coop_story_rewards.rbx` `CHESTS`). Reviewed 2026-10-28 against the TEST install's data
(`MGQ Paradox Test/Data`, maps 0-999, 1000-1999 and 2000+).

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/party_chests.json`) | 5,223 |
| Confirmed in bulk | 5,180 |
| Checked by hand | 43 |
| Fixed | 2 |
| Dropped | 2 (one by the user's decision) |
| Added | 82 (81 by the user's decision) |
| Written (`Relay/seed/story/party_chests.json`) | 5,303 |

### How the rows were checked

The game's data was read with Ruby 3.3 and Marshal stubs, the same way the Event Checker reads
it. Running the Event Checker's own chest rule (`story_rewards.rb`) over the TEST install gives
exactly the 5,223 candidates, so they come from the same data.

A separate script then checked every row. A row passed in bulk when the map and event exist and
every page of the event that turns the row's self switch on:

- gives something: gold, an item, a weapon or an armor;
- does nothing that moves the story: no variables, party changes, battles, transfers, shops or
  common event calls, and no scripts except `gain_medal` and `actor_label_jump`;
- turns on no switch other than a chest flag;
- turns on no other self switch;
- is shut by that self switch, through a later page that asks for it or a branch on it.

The 43 rows that failed any of these were read by hand.

### Checked by hand and confirmed (40)

- **ss44.10.A** (Saloon Indoors, Mimi): a one-time gift of three accessories, then her shop. The
  shop does not change the story.
- **ss371.12.A** (Ghost Ship B2F): the Purple Orb chest. It also calls common event 330, which sets
  the story to 32 once all orbs are held. See the open questions below.
- **ss1007.170.A** (Grangold Castle Prison B1F): a chest with a remark and a map scroll.
- **ss1193.30.A** (Angelic Dominion teleport shrine): the transfer runs every time. Self switch A
  only shuts the first-arrival talk and the gift of the Warp Stone OFB (570).
- **ss1457.4/6/8/9/10/11/12/14/16/17/18/19/22/23.A** (14 pedestals, 天界封印の間): each gives a
  weapon and calls common event 427, which counts the pickups in variable 1166.
- **ss1510.32 to ss1510.51.A** (20 pedestals, 混沌ミトラ封印城 封印の間): each gives a gem and calls
  common event 9054, which counts the pickups in variable 1351 and gives medal 2150 at 20.
- **ss1650.14.A** (Dark Goddess' Castle, Saja): A shuts her gift of four weapons (206, 259, 325,
  393). The page also turns on B (a talk) and C (another gift, added below).
- **ss1753.8.A** (Chaos Ilias Temple, Head Priest): a one-time gift of an armor (1763), then the
  job change, which every visit opens.

### Fixed (2)

- **ss51.23.A → ss51.23.B** (Pornof, Fortune Teller): A only marks the first talk. B shuts the
  trade that gives the Fortune Teller Permit (610). The generator takes the first letter a page
  turns on.
- **ss1650.44.A → ss1650.44.B** (Dark Goddess' Castle, Minagi): A only marks a talk. B shuts her
  gift of the Sealed Orb of the Seeker (671).

### Dropped (1)

- **ss885.25.A** (Demonic Castle 1FC, Sheep Girl): this is not a chest. The page gives nothing:
  A marks the first talk, and the choice takes a Yamatai Sake (431) away. The generator read the
  item command as a gift without checking whether it gives or takes. Its switch 2914 is dropped
  from `chest_flags` for the same reason.
- **ss371.12.A** (Ghost Ship B2F, the Purple Orb chest), by the user's decision of 2026-10-28:
  "Global. Once opened, all players receive it." In a Classic party the leader's opened chest now
  carries over, and the member gets the Purple Orb (541, a key item) with the leader's key items
  (`coop_story.rbx` `fill_items`), so no member opens it late and runs common event 330, which
  would set the story back to 32. In a Raid World it stays a world chest (`chests`), so a player
  who did not open it gets the orb from the catch-up and never runs that event either; the
  catch-up plays the orbs' event only before the story reached 32 (`OrbsDue`).

### Added (1)

- **ss1650.14.C** (Dark Goddess' Castle, Saja): C shuts her gift of the Sealed Orb of the Warrior
  (665), on route steps 30 to 42. This is the same kind of one-time gift as A. The candidates
  missed it because the generator keeps only the first letter of a page.

### Added by the user's decision (81)

The user decided the 164 loot pages left out below on 2026-10-28, after the research they asked
for (decision 3):

- **The 76 pay-outs of the Grand Theater's shows** ("each player gets paid once"): self switch A
  of page 0 of events 21 to 31 on maps 639, 638, 640, 641, 642 and 637 (stages 1 to 50) and 758,
  759 and 760 (stages 51 to 76). Each page is an autorun under the switch of its show (s601 to
  s676) and plays again on every visit, but gives its pay-out only inside "if self switch A is
  off", and A is the only self switch it turns on; a script checked all 76 against the data. In
  all they pay 7,000 G (two shows), 57 accessories, and food and consumables with 6 Small Medals
  among them. Each is a party chest now, and its self switch A is each player's own in a Raid
  World too: its event turns the shared s2119 off, runs under a shared stage switch and calls CE
  129, so the derived index shares it, and each has an `events` row (`personal`, `chest: true`,
  the [events](#events) section). The 87 `rewards` rows of 74 of these pages are dropped (the two
  gold pay-outs have none; the [rewards](#rewards) section): each player gets the pay-out by
  staging the show.
- **5 one-time pick-ups** ("accept the proposals"):
  - **ss344.4.A**, the small chest of the North Haunted Mansion's doll (a Small Medal), which
    opens once switch 2070 is on; the shared switch 2073 it turns on only sends the doll away.
    Its rewards row is dropped.
  - **ss1714.3.A**, the Noble Rose's one-time Yggdrasil Leaf on the Chaos World Tree 4F. Vanilla's
    leaf quest (v1365, s7061) runs on its shared keys whatever the self switch says. Its rewards
    row is dropped.
  - **ss1502.30.A**, the Chimera Dryads' Great Gem of All Stats in the Remina Research Facility,
    after their fight. The derived index leaves it each player's own already, so it needs no
    `events` row.
  - **ss228.48.B**, the Pocket Castle's Kagetsumugi scene (page 2, Chaos route 21 and later) that
    gives the CD One Woven From Shadows (1821). It was shared, so only the first player saw it.
  - **ss1890.28.B**, Furiel's free gift of two Next Cores in the Monster Realm's Ilias Temple. B
    shuts the gift and opens her trade of Next Cores for Monster Lord Puppet Cores; A only marks
    the first talk and stays the story's.

  The four whose event the derived index shares have an `events` row (`personal`, `chest: true`).

Each added row carries a `note` with its reason.

### How the stage pay-outs fit the shared stage switches

s601 to s700 stay shared by the user's decision (decision 2 of the [keys](#keys) section). They
mark the show that is running: CE 121 to 128 turn one on right before the transfer to the stage,
and the manager (event 202 on maps 624, 1980 and 1755) turns all of them off again. A show's page
runs whenever its switch is on and the player is on its stage map, so the shared switch only says
which show plays; whether it pays is up to self switch A alone, inside the page. That self switch
is each player's own: its own `events` row comes first in the lookup (its own key, then its
event's, the common event's that wrote it, its map's letter's and its map's; `StoryTable.ClassOf`
and the relay's `kindOf`), before the derived index. No `events` row names a whole event, a
letter or a whole map of the nine stage maps, and none names a common event, so nothing makes
the self switches shared again. The real derivation (`SelfSwitchIndex.Derive` over the new
`keys` and `events` rows and the TEST install's data) gives the same index as before (18,049 map
events, all 76 stage events among them, and 2,572 common events), and every party chest's self
switch is now each player's own except the 94 that are world chests. So the shows play as
before, and each player who stages a show gets its pay-out once, from their own A.

### Left out on purpose (not added)

The generator rule leaves out 164 more pages that give loot and turn on a self switch, because
those pages also change the story. They set variables (25, among them ss67.2.A, the Magical
Thread, which moves the Puppeteer's Tower quest on), start battles (such as 7 guarded chests on
map 209), set story switches (such as ss344.4.A, the doll quest's small medal, and ss645.9.A,
Mithril), or are stage shows that pay once (76, such as maps 638 and 639). The table is for
chests, and those events belong to the story, so none of them was added at first; the user's
decision then added 81 of them (see above).

### Decided by the user (2026-10-28)

1. **ss371.12.A, the Purple Orb chest**: global, once opened all players receive it. Dropped, see
   Dropped.
2. **Pickup counters** v1166, v1351 (and the tour's v1229): each player's own, as recommended and
   as the `keys` rows have them.
3. **The 164 loot pages that also move the story** (Left out on purpose), decided after the
   research: each player gets each stage show's pay-out once (76 party chests, their 87 rewards
   rows dropped), the 5 proposed pick-ups are party chests (see Added by the user's decision),
   11 pages are world chests (the [chests](#chests) section), and the other 72 stay story: boss
   fights, recruits, quest trades and route scenes whose loot reaches players behind through
   `rewards` or `key_items` rows, and the 15 Lucifina ring pages, which follow decision 13 of the
   rewards.

### Notes

- An admin applies `party_chests.json` in three batches (at most 2,000 edits each).
- After decision 3, every changed file (`chests`, `party_chests`, `events`, `rewards`,
  `key_items`) passes `readEdit` and `readRow` of the relay unchanged, applies as an admin's
  batches with the rows read back equal, and the whole folder seeds at one start.
- The fixed and added rows carry a `note` with their reason.
- Generator bugs in the Event Checker:
  - `story_rewards.rb` `chest?` and `raid_data.rb` `scan_chest` take the first self switch a page
    turns on, not the one that shuts the gift.
  - `CHEST_CODES` counts item, weapon and armor commands that take things away as gifts.

## Classes

### class_levels

The classes and races the story and its quests give a character at a level (`CLASS_LEVELS` of
world_catchup_data.rbx). The catch-up gives a row's class to the hero or a roster companion once the
player's or the world's story is past the row's place, and only when `ran` is true.

Checked against the game's own data in the TEST install
(`Desktop\Monster Girl Quest Paradox\MGQ Paradox Test\Data`), read with Ruby 3.3 and Marshal stubs
as the Event Checker reads it: every common event, every page of every map event (maps 1-999,
1000-1999 and 2000+) and every troop page.

### Counts

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/class_levels.json) | 2,171 |
| Written (Relay/seed/story/class_levels.json) | 2,079 |
| Confirmed in bulk | 788 |
| Checked by hand | 1,192 kept rows at 63 sites, plus the 191 dropped and 99 added rows |
| Fixed | 2, plus the marks of the 40 added rows of map 1462 event 13 (see Added), and the 51 rows of CE 9022 and map 1462 event 13 by the user's decision |
| Dropped | 191 |
| Added | 99 |

### How the rows were checked

1. **The command.** A scan found every `set_class_level(actor, class, level, ...)` in the game's
   script commands: 2,475 calls with whole numbers, plus 54 whose actor is a variable (`v(12)`).
   Every one of the 2,171 rows names a site that holds that call for its actor and class, at the
   row's level, which is the highest level the list gives that pair. No row was missing from the
   data, and no list gives one pair at two different levels.
2. **The place, in bulk.** For each row the script read the page's conditions, the conditions of
   the branches around the command, and what the list itself sets (switches turned on, variables
   set, self switches). A row was confirmed in bulk when every mark comes from these, the part's
   progress mark (1001, 1141, 1142 or 1143) matches the row's step, the step lies in the row's part,
   and the side matches a side switch (4 or 5) on the command's path. 788 rows passed.
3. **The place, by hand.** The other 1,192 kept rows (63 sites) were looked at site by site:
   - 1,119 rows (56 sites) carry marks their own list does not show. Each such mark was traced to
     the events that set it: the warp crystal or warp flag of the same dungeon or town (switches
     3191-3196, 3228-3229, 3465-3485, 5018, 5104-5138), the Chaos route's earlier events on the way
     there (1301-1323 and the like; for example 1302 = 8, 1303 = 1 and 1323 = 4 are all set by the
     Grand Noah Castle 4F event), or the scene that leads in (Sabasa's warp flag before the Sabasa
     attack, the Spider Princess event before CE 347). All are values the story sets before the
     event; they only make a row wait longer, never pass early.
   - 68 rows (4 sites) have a progress mark one above their step: map 1877 event 71, map 1820
     event 2, map 1187 event 29 and CE 9001. Each list sets that progress value itself after the
     class commands, on the same path, so the marks are right.
   - 5 rows name a side without a side switch on the command's path. Map 750 is "Middle Chapter
     Final Battle (Alice)" and map 751 the Ilias one, so their sides are right. CE 366 is wrong,
     see Fixed.
   - The 74 rows of map 1752 event 37 (the Chaos route's final battle) keep `ran` false: the
     autorun gives the final battle's characters their classes on entering, and its marks (1143 =
     24, 1348 = 5) hold before it runs. The catch-up never applies them, which is right.
   - The non-Chaos places were checked one by one against their lists, among them the Great
     Decision (CE 380): Ilias's way on Alice's side gives Ilias her classes (Monster Realm, side
     alice), the Dark Goddess's way on Ilias's side gives Alice hers (Angelic Dominion, side ilias),
     both only on a first playthrough (912 = 0).

### Fixed

- **CE 366, Hakunen's Sorcerer (actor 811, classes 33 and 7006): side `alice` changed to null.**
  The Hall of Creation 2F event 16 calls CE 366 from page 1 on Alice's side (switch 4) and from
  page 2 on Ilias's side (switch 5), and nothing in the CE asks for a side around the class
  commands. With `alice` an Ilias-side player never got the job.

### Dropped

- **All 191 rows of CE 209 ("Final Chapter 3.0 only processing").** It is a save upgrade, not a
  story event: the transfer process (CE 114) calls it while switch 146 is off, and its first command
  turns 146 on; no other list touches 146. So every game, a new one too, runs it once by itself on
  its first transfer and gives these races (Feral Youth, Monster Soul, Wildheart and more) to every
  listed character. There is nothing to catch up, and its rows carry no marks and no part, so the
  catch-up could never apply them anyway.

### Added

- **99 rows at five sites of the Chaos route where companions join** (each list adds them with
  `add_actor_ex` and then gives their classes; the generator left these lists out because they set
  no story value besides their own self switch or a scratch switch). The joins table holds these
  joins, so a companion the catch-up brings would lack the classes the story gives with the join.
  Each added row takes the place of its join row at the same site (the class commands sit on the
  same branch as the join, right after it), with the highest level its list gives each class:
  - CE 9022 (No-Life King fight): Chrome (134) and Frederica (762), 11 rows; place
    `[v1143 21, v1316 5]`, `ran` false as the join's (both changed by the user's decision, see
    below).
  - Map 1232 event 243 (Cursed Undersea Temple 1F): Roza (373) and Selene (536), 12 rows; place
    `[v1143 21, ss1232.243.A]`, `ran` true.
  - Map 1267 event 176 (Cursed Undersea Temple 2F): Poseidoness (280) and Kraken (329), 24 rows;
    `[v1143 21, ss1267.176.A]`, `ran` true.
  - Map 1268 event 274 (Cursed Undersea Temple 3F): Levia (205), 12 rows;
    `[v1143 21, s3469, ss1268.274.A]`, `ran` true (3469 is that temple's warp crystal).
  - Map 1462 event 13 (Chaos Navy Headquarters, "Start the Decisive Battle"): Ashel (201) and
    Bonnie (202), 40 rows; `[v1143 21, v1313 4, v1352 5]`, `ran` false as the join's (`ran`
    changed by the user's decision, see below). The join's
    generated place said 1313 at 5, but the joins and the class commands sit in the choice "決戦を
    始める" under `1313 == 3`, and nothing in the list sets 1313. The battle leads to the Cursed
    Island (map 1832) and on into the Cursed Undersea Temple, whose 1F autorun (map 1232 event
    242) sets 1313 to 4 first. So 4 is the first value after the event; the sampling review of
    2026-10-28 changed these 40 rows and the two joins together.

Added rows come after the kept rows of their part and step; all rows were renumbered 10 apart in
the story's order (part, step, route), which keeps the generated rows' order.

### Left out on purpose (calls in the data without a row)

- CE 114, 267 and 268: the load fix-ups and the Reaper's resets, which are no story.
- CE 233-259: Promestein's race changes, which the player picks for a character of their choice
  (`v(12)`).
- Map 628 event 2 (Pocket Castle): gives Luka the Lowly Angel only when he lacks it; the story's own
  row at map 128 event 59 covers it.
- The collaboration scenario's own party set-ups in the Collab Overworld: map 848 event 18 (Lest,
  824), map 852 event 73 (Rigeo), map 858 event 230 (Kazuya, Hakunen, 813, 816) and map 872 event 4
  (Tarsa, a temporary member). They set nothing of the world's story; Rigeo's jobs there repeat
  rows the table holds already (maps 45 and 46), apart from Imp and Succubus (175, 176).

### Decided by the user (2026-10-28)

1. **CE 9022 and map 1462 event 13** move to the points the data shows, as recommended. Their 4
   join rows and 51 class rows now have `ran` true, and CE 9022's carry `[v1143 21, v1316 6]`
   instead of `[v1143 21, v1316 5]`. Read again in the data: CE 9022 adds Chrome and Frederica in
   its branch on 1316 = 5 and turns on switch 32 (command 409); the strategy meeting (map 1550
   event 11 page 1, switch 32 and 1316 at 5) sets 1316 to 6 (command 393), so 6 shows that CE 9022
   ran. Map 1462 event 13's marks already showed its battle ran (see Added). Each changed row
   carries a `note` with its reason.
2. **The collaboration scenario's party set-ups** stay out of Raid Worlds, as recommended: the
   collaboration's companions come through their own content and the planned raid shop.

### Notes

- An admin applies the file's 2,079 edits in two batches: the first 2,000, then 79.
### Validation

- Every edit has the shape `{"op":"add","table":"class_levels","row":{...}}`, and every row passes
  `readRow` of `STORY_TABLES.class_levels` unchanged.
- Seeded from a folder holding this file alone through `seedStoryTables` (Relay/node/story_seed.js)
  into a `StoryMapping` over the in-memory store: 2,079 rows at rev 1, a second start seeds
  nothing, and `forGames` hands back exactly the file's rows in order.
- Applied through `StoryMapping.edit` in two batches (2,000 and 79): both answered 200, and the rows
  read back equal the file's.
- The whole seed folder seeds together with the other tables at a start.

## Rewards

### rewards

Every skill Luka learns and every item, weapon and armor the story and its side quests give, key
items aside (`REWARDS` of world_catchup_data.rbx). The catch-up gives a row when a story laid over
the player's (the world's) carries them past the row's place, and only when `ran` is true; a row
with `ran` false is only noted as done once the player's own story passes it, and gives nothing.
A prize row (a count of `prize_variables` or a switch of `prize_switches` among its marks) also
gives when the player's own story is past it and they hold none of the prize.

Checked against the game's own data in the TEST install
(`Desktop\Monster Girl Quest Paradox\MGQ Paradox Test\Data`, untranslated 3.06), read with Ruby 3.3
and Marshal stubs as the Event Checker reads it: every common event and every page of every map
event (maps 1-999, 1000-1999 and 2000+).

### Counts

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/rewards.json) | 1,089 |
| Written (Relay/seed/story/rewards.json) | 888 |
| Confirmed in bulk | 571 |
| Checked by hand | 518 (344 kept unchanged at 56 sites, 18 fixed, 156 dropped), plus the 47 added |
| Fixed | 18 |
| Dropped | 248 (92 by the user's decisions) |
| Added | 47 |

Of the written rows, 322 keep `ran` false and so never give anything. The sampling review of
2026-10-28 moved 33 rows that the bulk check had passed to the hand checks: the Sealed Orb of
Yamato (fixed) and the 32 tour chests (dropped).

### How the rows were checked

1. **Regenerated.** The Event Checker's `raid_data.rb` run over the TEST install writes exactly the
   1,089 candidates (no line differs from world_catchup_data.rbx at 54a0c4ae).
2. **The command, for every row.** The row's site exists, and its list holds a command that gives
   that skill to Luka (318, actor 1, learn) or that item, weapon or armor (126, 127, 128, gain,
   constant amount), and the row's amount is the largest such command of the list. No row failed.
   No row's item is a key item.
3. **The place, for every row.** The part and step fit (Part 1 steps 0-18, Part 2 19-33, Part 3
   from 34; a map under the Chaos route's or a route's root in the map tree has that part), the
   part's progress mark (1001, 1141, 1142 or 1143) is there and not below the step, the step is not
   below what the page and branches ask of the progress variable, and the side matches a side
   switch (4 or 5) of the page or of a branch around the command, or the map's name. Every mark
   was traced: to what the list itself sets or asks for (page conditions, branches, switches
   turned on, variables set, self switches), to the progress mark, to the generator's hand pins
   (camps, hide and seek, Amira's side quest lists, the Library Flag events), or to the lists
   around the event (the common event's callers, the events of the same map and the lists that
   transfer onto it, up to four steps away). `ran` was held against what the command's path sets.
4. **What a catch-up would over-give.** Separate scans looked for: gifts in one branch of a choice
   or of an if/else whose marks nothing in that branch sets (the alternatives would come along);
   gifts paid for with gold or an item in the same branch; items the story takes back later;
   several rows of one gift with the same marks; marks on a variable that names one of several
   things rather than counting up (1079, 1402).
5. **Completeness.** Every skill and item of coop_story_rewards.rbx (event_rewards) has a row
   here or in key_items. The battlefuck events were scanned for gifts (see Added).

604 rows passed 2 to 4 without a question: their marks come from their own list, the progress
mark, or the lists around them, and any choice or else branch they stand in sets one of their
marks.

### Checked by hand (kept unchanged)

- **Hide and seek (CE 322)**: the gifts go by the count of Amiras found (1043 at 2, 4, 6, ... 23),
  which only goes up by one per find, so 1043 at least the count is right.
- **The camps (maps 523, 604, 711, 736, 741, and the route camps 1697, 1698, 1769, 1770, 1771)**:
  side skills on autorun pages; the pins name the camp's switch or the field event's self switch
  (map 2 events 254, 262, 270 turn theirs on first), the route camps' marks come from the field
  events that send the player in.
- **The Colosseum (CE 158, 161-186)**: CE 158 and CE 164 were read in full, the other cups follow
  the same list. The rank and cup prizes are prize rows of 701 and 703-728 (`ran` true); the same
  items placed at Part 2 step 24 (1052 at 6, where the Colosseum opens) and the seeds of a repeated
  win keep `ran` false, which is right: those marks only show the Colosseum is there.
- **Black Alice's Sakura Shura Helm (CE 487)**: the Monster Lord Blacksmith in Grangold Castle
  Prison B3F (map 1009, under the Angelic Dominion in the map tree), so `ad` is right; its marks
  1146 at 2 and 1171 at 6 are that route's prison and escape events.
- **The common events and route events that ran with their caller** (CE 299, 9003, 9060, map
  1979 event 49, map 1994 event 101 (EX-tuple Zeta, the camp's first rest, which sets 3491)).
- **Two route skills with step null** (Ghatanothoa and Grimoire, maps 1249 and 1262): optional
  dungeons of the Monster Realm route that nothing places further; null is allowed and orders
  them first in the route.
- **The fireworks loop (CE 570, Pizza)** and **the Lampas Crossroads (CE 505)**: side content
  without a part, marked by their own values.
- The Navy's supplies (map 280 event 16) give one item at two stages (High-Quality Herb at 1053 0
  and 2); the generator keeps one row per item and list, with the larger amount, so the second
  stage's herbs are not caught up. 1053 is each player's own (a choice's outcome), so these rows
  pass by the player's own story only. Left as is.

### Fixed

- **Four queen trophies (map 378 event 7 page 5, map 355 event 32 page 3, map 38 event 29, map 383
  event 4): the mark on variable 1079 removed.** 1079 only tells CE 329 which queen was beaten
  last (values 1-4 by queen); each list sets its queen's own variable (1070-1073) to 3, which
  proves the fight. With 1079 at least a value, a trophy failed once another queen was beaten
  after.
- **CE 366, Ayakashi's Talisman: side `alice` changed to null.** The Hall of Creation 2F event 16
  calls CE 366 from Alice's side (page 1) and Ilias's side (page 2); nothing in the CE asks for a
  side around the gift. (The class_levels review fixed the same CE.)
- **Map 121 event 12, Black Alice in the Monster Lord's Castle of the past (Empress Dress, Demon
  Claw:Hekatonkheires): side `alice` changed to null.** The event branches on both side switches
  before the fight and gives the prizes after it, outside those branches.
- **Ten battlefuck victory gifts: the battlefuck's own counter added to the marks, `ran` set to
  true.** Battlefuck progress and rewards are world-wide (user decision 2026-10-24), but the
  generator only knew variables from 1001 on, so these rows were either marked only by where the
  battlefucks open (Battle Fucker Permit, Soul of the Lecher and Queen Fucker's Proof of CE 6999
  passed as soon as the story reached step 7, without a single win) or kept `ran` false and never
  gave. Now: CE 6999 at 907 (wins) 15, 35 and 40, as its branches ask; CE 7334, 7344, 7354 at
  834-836 = 2; CE 7534, 7554, 6997, 7544 at 855, 857, 854, 856 = 3, each set on the gift's path.
  CE 7564 was right already (1374 at 11 is set on its path).

- **CE 479, the Sealed Orb of Yamato (item 669): marks `[1142 at 74, 2621]` changed to `[2621]`,
  step 74 changed to null.** The orb is given only in the common event's first branch (1142 at
  most 43, switch 2621 off, which the branch turns on, command 32). The second and third branches
  (1142 47-57 and 58-75) give it only when the player lacks it and set 2622 and 2623. The mark 1142
  at 74 came from a later page of a caller (map 1110 event 8 page 2), so a world that got the orb
  early passed only at step 74, and one that got it after step 43 never did. The callers on
  Yamatai Village B1F (map 1110 events 8 and 9, page 1) ask for nothing, and neither does the
  field's way in (map 1001 events 25 and 55 call CE 477), so nothing places the talk at a step;
  null orders it first in the route, like the route's optional skills. A world whose first talk
  came after step 43 (2622 or 2623 only) is not covered: rows for those switches would give the
  orb twice, as those branches set their switch even when the orb is held.

### Dropped

- **32 rows of the Demon Castle Tour and Ruling Crown chests** (31 armors and weapons on maps
  922-931, orders 8810-9030 and 9540-9650 before the renumbering, and the Ruling Crown on map 892).
  Each row's only mark is its chest's flag (2915, 2927-2957). The chest_flags review made these
  flags each player's own (kind `chest`), which the world's story never holds, so the rows could
  never pass for a player behind the world; each player loots their own tour chest. This follows
  open question 1 of the [chest_flags](#chest_flags) section; see decision 5.
- **49 rows of Lucifina's ring (map 1994, the Chaos route's camp, events 1-113).** Each companion's
  event takes the Eternal Pledge Ring and gives that companion's ring accessory, setting 1401 to 2
  and 1402 to the companion's number. Only one companion ever gets the ring, but a mark asks for
  1402 at least a value: a world that gave it to companion 11 would hand every ring of 1 to 11,
  and one per page of the event (map 1994 event 5 has seven pages). See the decisions.
- **46 rows that repeat another row's gift with the same marks.** The two to four events of one
  fight on the field (maps 209, 721, 1497, 1503, 1877, 1879, 1884, 1904: the same battle, the same
  switch, the same gift, a copy per enemy sprite; map 1503 events 81 and 86 differ only in the
  battle's escape flag), and the Ruling Crown chest shown on two maps (892 and 953, both turning on
  2915). The story gives such a gift once, and the catch-up gave it once per row. The first row of
  each group is kept (the Ruling Crown's kept row is dropped with the tour chests above).
- **9 rows of the Medal King's exchange (CE 140): Life Nut, Mystery Nut, the six seeds and
  Etemenanki.** Bought with the player's own small medals, as often as wanted; their marks (1090
  at 3) only show that the exchange opened. The one-of-a-kind exchanges stay, see the decisions.
- **8 rows the Four Spirits' pedestals give back (map 1830 event 8).** The pedestals (events 12,
  13, 16, 17) take the four spirit weapons and later the four guardians' arms; event 8 gives them
  back with the new sword. The story leaves the count as it was, and a player who catches up still
  loots their own chests that hold them. The two new swords (4228, 4229) stay.
- **6 rows of CE 209**, the "Final Chapter 3.0 only processing": a save upgrade every game runs
  once on its first transfer, no story event; no part, no marks (the class_levels review dropped
  its rows too).
- **3 rows of Milk (map 52 event 16, map 1613 event 18, CE 118):** Panty Sensei's joke gives one
  Milk and takes it back two commands later.
- **2 rows the story trades away later:** the Fallen Sword Angel Halo (map 1583 event 17), which
  map 1075 event 35 takes for the Fallen Angel Halo, and the Ancient Sushi (map 1072 event 36),
  which Sariela's request (CE 482) takes for the Sealed Orb of the Seeker. The table gives both
  results; rewards have no take, so the traded item would stay as well. Neither later event checks
  that the player holds it.
- **1 row bought for gold:** 3 Phoenix Tails in the Nameless Slums (map 185 event 13, "Pay 60G").
- **1 row of a world chest:** the Sealed Orb of the Land-Dweller (767, map 1556 event 121). The
  user's decision of 2026-10-28 made its chest a world chest keyed by switch 2719 (see the
  [chests](#chests) section), which gives the orb; the row would give it a second time.
- **87 rows of 74 Grand Theater show pay-outs** (maps 637-642 and 758-760; 81 at part 3 step 38,
  6 at Chaos step 21), by the user's decision of 2026-10-28 ("each player gets paid once"): each
  pay-out page is a party chest now (the [party_chests](#party_chests) section), so each player
  gets it once by staging the show.
- **2 rows of party chests** by the same decision: the doll's Small Medal (map 344 event 4) and the
  Noble Rose's Yggdrasil Leaf (map 1714 event 3).
- **2 rows of world chests** by the same decision: the Soul of the Warrior God (622, map 551 event
  17) and the Witch's Soul (675, map 205 event 4), which their chests give now (the
  [chests](#chests) section).

### Added

- **47 battlefuck victory gifts** that had no row: each battlefuck's victory common event (CE 7016
  to CE 7524, from Elly to Kanna) gives one accessory or gem and sets the battlefuck's counter
  (802-853) to 2 on the same path; the generator skipped them because these lists set nothing from
  1001 on. Each row: the gift, `site` the victory event, `part`, `step` and `side` null, `marks`
  the counter at 2, `ran` true, after the other rows without a part. Battlefuck rewards are
  world-wide (user decision 2026-10-24, "Everyone"), so a player behind the world must get the
  gifts of the battlefucks the world won; they cannot win them again.

All rows were renumbered 10 apart, keeping the generated order.

### Decided by the user (2026-10-28)

1. **Lucifina's ring**: the 49 ring rows stay dropped, as recommended.
2. **Battlefuck prizes**: "recommended as long as every player gets it". The battlefuck counters
   801-858 and the wins 907 are prize variables now (59 rows added to `prize_variables`, see that
   section). All 57 rows they mark give items, weapons or armors and have `ran` true, so every
   player gets each prize: one the world's story carries past it by the carried review, as before,
   and one who keeps up with the world, whose story holds the shared count, at the next look once
   they hold none of the prize.
3. **The Medal King's one-of-a-kind exchanges** (Heinrich's Sword, Armor, Helmet and Shield, the
   Noble Orb; switches 2324-2327 and 2336, shared): "once anyone buys, distributed to everyone".
   The 5 rows stay, and their switches are prize switches, a new table beside `prize_variables`
   (`prize_switches`, see that section): a prize row now also counts a switch of that table among
   its marks, so a player whose story holds the switch and who holds none of the prize gets it,
   as the global prizes of 0.6.9.2 do by their counts.
4. **The two traded items** stay dropped, as recommended.
5. **The 32 tour chest rows** stay dropped: the tour chest flags stay each player's own (the
   [chest_flags](#chest_flags) section, decision 1).
6. **The loot pages that also move the story** (decision 3 of the
   [party_chests](#party_chests) section): 91 rows dropped, see Dropped.

### Notes for other tables

- keys.json now makes v1079 `shared` (it was `one_way`): the game sets 1079 to the queen just
  beaten (1 to 4, in the order the player beats them) and CE 329 reads it right away.
- prize_variables and prize_switches: see decisions 2 and 3.

### Notes

- 65 edits carry a `note` (each fixed and added row, with its reason).
### Validation

- Every edit has the shape `{"op":"add","table":"rewards","row":{...}}` (plus `note` on fixed and
  added rows), and every row passes `readRow` of `STORY_TABLES.rewards` unchanged.
- Seeded from a folder holding the three files of this group alone through `seedStoryTables`
  (Relay/node/story_seed.js) into a `StoryMapping` over an in-memory store: 1,012 rows at rev 1, a
  second start seeds nothing.
- After the sampling review's fixes: 980 edits, each passing `readEdit` and `readRow` unchanged.
- Applied through `StoryMapping.edit` as an admin's batch (980 edits, under `maxEdits` 2,000):
  answered 200, and the rows read back equal the file's.
- The whole seed folder, with every other reviewed table, seeds together at one start.
- After decision 3 of the [party_chests](#party_chests) section: 888 edits, each passing
  `readEdit` and `readRow` unchanged, applied as one batch and read back equal.

### key_items

Every key item (and ore, "[Material]") the story's events give (amount above 0) or take (below
0), outside chests and the talks with a companion of the player's own roster (`KEY_ITEMS` of
world_catchup_data.rbx). The catch-up restocks a given key item whenever the player's or the
world's story is past its row and no later take row the story passed took it back, whatever the
row's `ran`; it takes an item only for a take row with `ran` true that a story laid over the
player's carried them past. Several rows of one item owe the largest amount, not the sum.

Checked against the game's own data in the TEST install
(`Desktop\Monster Girl Quest Paradox\MGQ Paradox Test\Data`, untranslated 3.06), read with Ruby 3.3
and Marshal stubs as the Event Checker reads it.

### Counts

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/key_items.json) | 166 |
| Written (Relay/seed/story/key_items.json) | 153 |
| Confirmed in bulk | 137 |
| Checked by hand | 29 (20 kept unchanged at 19 sites, 5 fixed, 4 dropped) |
| Fixed | 5 |
| Dropped | 13 (9 by the user's decision) |
| Added | 0 |

### How the rows were checked

The same checks as the rewards review (see the [rewards](#rewards) section), with the key item's own rules:

1. `raid_data.rb` over the TEST install writes exactly the 166 candidates.
2. Every row's site holds a command that gives (126, gain) or takes (126, lose) that item with a
   constant amount, the row's amount is the largest of the list's, and the item is a key item or
   an ore (item type 2, description "[Key Item]" or "[Material]").
3. Part, step, progress mark, side and every mark were held against the list, its page and
   branches, the generator's pins and the lists around the event; `ran` against what the
   command's path sets.
4. Scans for choice and else branches no mark of the row proves, for gifts paid with gold or an
   item, and for marks on variables that name one thing rather than count up.
5. Completeness: every command of the game that gives or takes a key item has a row, unless the
   page is a chest's (the chests table) or a talk with a companion of the player's roster (needs
   one of the switches 1001-2000), which the table leaves out on purpose.

### Checked by hand (kept unchanged)

- **Pocket Castle (map 748 event 3) and Remina Key Card (map 730 event 19)**: one row per side;
  each list gives the item once in Alice's branch and once in Ilias's, so both rows are right
  (the bulk check only looked at the first command).
- **Storehouse Key (map 6 event 33)**: the village chief gives it on every talk until 2007 is on;
  `ran` false with the Part 1 step 6 mark, and the catch-up owes one at most.
- **Yellow Orb (map 117 event 6 page 2)**: the choice "I want the Yellow Orb" at 1001 = 31 calls
  the orbs' common event (330); `ran` false is right, the orbs are the rules' (`orbs`).
- **Hide & Seek Trophy (CE 322)**: given at 21 Amiras found, the count only goes up.
- **Meteorite (map 1650 event 1)**: given only when the player lacks it, which the marks of the
  event prove.
- **Kage Key (map 1817 event 9)**: the Monster Realm's Black Mansion, step null, marked by its own
  self switch.
- **Pocket Castle taken on the Chaos route (map 475 event 8)**: the Pocket Castle's attack; 1143
  at 8 comes from the transfer that leads in.
- **Magical Thread (map 67 event 2)**: Seeker's Cave B3F, no part; its own self switch proves it,
  and the page sends the player away unless 1023 and 1026 are at 2 or more.
- **Key to Chaos (CE 908, 909, map 665 event 11, map 817 events 2 and 3, map 800 event 22)**: the
  Labyrinth of Chaos, outside the story's order; no part and no marks, so they never pass. Kept as
  the data shows them.

### Fixed

- **Orb of Life-Drain (CE 7007) and Lady Shirley's Lover (CE 7124): the battlefuck's counter
  added (801 and 813 at 2), `ran` set to true.** Battlefuck progress and rewards are world-wide
  (user decision 2026-10-24). The rows were marked only by where the battlefucks open (Part 1 step
  7 with switch 2049, step 13 with 5015), so the restock gave the prize to every player at that
  step, won or not. The part and step stay, so the take of Lady Shirley's Lover (map 164 event 20)
  still counts as later.
- **Seven Crow Mirror (map 121 event 12): side `alice` changed to null.** Black Alice's event in
  the Monster Lord's Castle of the past plays on both sides; the mirror lies outside the side
  branches.
- **Warp Stone NAX (map 1002 event 12): the marks 1142 at 46 and 1169 at 24 removed.** Map 1002 is
  the Demon Castle's recapture, entered from map 1883, which sets 1141 to 52 on the Angelic
  Dominion route right before. The Monster Realm marks came from a San Ilia transfer to the field
  that the generator read as one onto map 1002, and would have held the stone back until the other
  route got that far.
- **Eternal Pledge Ring taken (map 1994 event 25): the mark on 1402 removed.** The ring goes to
  whichever companion the player picks; 1402 names that companion, so "1402 at least 9" is no
  proof. 1401 at 2 (the ring given) is, and it still comes after the row that gives the ring.

### Dropped

- **Snake Doll and Squid Doll on the Chaos route (map 1197 events 62 and 100).** Bought for 25 and
  24 gold; the story gives them on the Monster Realm route (map 1580, kept). With `ran` false the
  restock handed them to every Chaos route player at step 21.
- **La Croix's Notes taken in Hades (map 154 event 5).** The game over's return to an earlier
  point, not the story; CE 357 is the story's own take (kept).
- **Eternal Pledge Ring taken at map 1994 event 8.** Once 1402 is left out (see Fixed) it is the
  same take as the one kept at event 25; the ring is taken once.
- **9 rows of world chests**, by the user's decision of 2026-10-28 (decision 3 of the
  [party_chests](#party_chests) section): the five Mitra tablets (948-952), the Witch's Secret
  Elixir Recipe (958), the Magical Thread (518), Mithril Ore (153) and Orichalcum (156). Their
  pages are world chests now (the [chests](#chests) section), and this table leaves out chests.

### Decided by the user (2026-10-28)

Decision 3 of the [party_chests](#party_chests) section dropped 9 rows, see Dropped. The
battlefuck counters became prize variables (the [rewards](#rewards) section,
decision 2); that concerns these two rows only as far as restock goes, which already gives a key
item from the world's story.

### Notes

- 5 edits carry a `note` with the reason of their fix.
### Validation

- Every edit has the shape `{"op":"add","table":"key_items","row":{...}}`, and every row passes
  `readRow` of `STORY_TABLES.key_items` unchanged.
- Seeded alone through `seedStoryTables` into a `StoryMapping` over an in-memory store: 153 rows at
  rev 1, a second start seeds nothing; applied through `StoryMapping.edit` as one batch: answered
  200, rows read back equal. The whole seed folder seeds together.

### event_rewards

What the game's events give a party member of a Classic world who catches up with the leader's
story (coop_story_rewards.rbx `SKILLS`, `ACTORS`, `ITEMS`, `SIDED`, `ROUTE` and `FINAL`, now
written by PartyRewards in the DLL). The member gets, of what the leader holds, the skills and
companions listed here and the items up to `most`; a `sided` one only comes with the events where
the sides differ, a `route` one also once the story is past the Great Decision, and a `final` one
is left out for a member who starts another route than the leader's.

Checked against the game's own data in the TEST install
(`Desktop\Monster Girl Quest Paradox\MGQ Paradox Test\Data`, untranslated 3.06), read with Ruby 3.3
and Marshal stubs as the Event Checker reads it.

### Counts

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/event_rewards.json) | 417 (43 skills, 346 companions, 28 items) |
| Written (Relay/seed/story/event_rewards.json) | 417 |
| Confirmed in bulk | 377 |
| Checked by hand | 40 (the 28 items, and 12 skills and companions) |
| Fixed | 15 |
| Dropped | 0 |
| Added | 0 |

### How the rows were checked

1. **Regenerated.** The Event Checker's `story_rewards.rb` run over the TEST install writes the
   same SKILLS, ACTORS, ITEMS, SIDED, ROUTE and FINAL as coop_story_rewards.rbx at 79c36f1f.
2. **Recounted with a script of its own.** Every list of the game outside the chests was read
   again: Luka's learned skills (318, actor 1), the companions brought by party changes (129),
   by `add_actor_ex`, `add_actor_ex_nc`, `add_stand_actor` and `set_actors`, and by their party
   switches (1001-2000), the items the lists that move the story's progress (1001, 1141-1143) give,
   each list's largest amount summed into `most`, and the sides each gift comes on (the page's
   side switch, a branch on switch 4 or 5, the map's name, or the side the list chooses). Every row
   is given by some list, every gift of those kinds has a row, and all of `most`, `sided`, `route`
   and `final` came out the same under the generator's rule for the Final Chapter: a common event
   named "Great Decision" or from 9000 on, a map from 1000 on, or a list that reads a route's
   progress.
3. **The Final Chapter, by hand.** That rule misses lists that only *set* a route's progress, and
   common events that only route maps call. Counting those too, 14 rows changed; each was looked
   up (see Fixed). The 28 items were checked one by one against every list that gives them.

### Fixed

- **14 rows `final` false changed to true**, each given only by the Final Chapter:
  - Kirin, Korikicho and their Support skills (9780, 9781, 10035, 10036) and Null Cogito (999):
    CE 424, the boss fight of the Angelic Dominion's Black Mansion (map 1682).
  - Raphaela (510): CE 455 (the Monster Realm's oasis) and Final Chapter maps of every route.
  - Monster Train (658): CE 467, called from the Monster Realm Station (map 1643), and map 1740.
  - Alipheese the 9th (740): CE 460, Enrika in the Monster Realm (map 1469).
  - Alipheese the 15th (752): CE 385, the Kagetsumugi fight in Puppeteer's Tower 5F (map 436),
    whose event sets the Monster Realm route's progress (1142 = 47).
  - Aži Dahāka (756): CE 418 (the Angelic Dominion's San Ilia) and CE 9008.
  - Teenia (774) and Granpapi (776): CE 408 and 409 on the Angelic Dominion's Monster Lord's Castle
    Ruins (maps 1859, 1860), and map 1331.
  - Archfiend Orb and Sealed Orb of the Archfiend (items 658, 751): CE 299 in Central Tartarus
    (map 453, the Chaos route's prologue), which sets 1143 to 6.
  With `final` false a member who starts another route than the leader's got these from the
  leader's catch-up although their own route gives what it gives.
- **Pocket Castle (item 501) `final` true changed to false.** Part 2 gives it (map 2 event 5,
  Alice handing it over, and map 748 event 3); those lists do not move the story's progress, so
  the generator only counted the Chaos route's revival (CE 9001). With `final` true a member who
  starts another route than the leader's would not get the Pocket Castle. `most` stays 1.

Each fixed edit carries a `note` with its reason.

### Needs the user's decision

None.

### Validation

- Every edit has the shape `{"op":"add","table":"event_rewards","row":{...}}`, and every row passes
  `readRow` of `STORY_TABLES.event_rewards` (with its check of `most`, `sided` and `route`)
  unchanged.
- Seeded alone through `seedStoryTables` into a `StoryMapping` over an in-memory store: 417 rows at
  rev 1, a second start seeds nothing; applied through `StoryMapping.edit` as one batch: answered
  200, rows read back equal. The whole seed folder seeds together.

## Companions

### joins

Every story join of a companion (Relay/core/story_catchup.js `joins`), reviewed row by row against
the TEST install's events (`MGQ Paradox Test/Data`) on 2026-10-28.

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/joins.json) | 664 |
| Written (Relay/seed/story/joins.json) | 662 |
| Confirmed in bulk | 551 (553 before the sampling review moved two rows to Fixed) |
| Checked by hand | 113 |
| Fixed | 11, then 2 more and 4 placed back by the user's decisions |
| Dropped | 2 (one by the user's decision) |
| Added | 0 |

### How the rows were checked

1. The candidates are what the Event Checker's raid_data.rb writes from the TEST install, exactly:
   running it again on that install gives the same 664 rows. On the Translated install one command
   index differs (map:1613:18:1, Panty Sensei's join, 15 in TEST and 20 there); the rows keep
   TEST's. The index only orders a join against a removal of the same list, which no translation
   changes.
2. An independent checker (Ruby over the game's Marshal data, not raid_data.rb's code) confirmed
   for every row:
   - the site exists: map, event, page, or common event;
   - the command at `index` adds `persona` (event command 129 or a join script), and it is a
     lasting join, not a temporary one;
   - `actor` is the main persona of `persona` (DataEx cache, else the note tag);
   - the gate: a `start` gate is the persona's start level (held at 250); a `floor` gate is a
     level_adjust in the same list or an earlier list of the story; a `kept` gate is an earlier
     join's; a `cap` gate is the Level Cap milestone reached at the place;
   - every mark has a source in the data: the page's conditions, the branches around the command,
     a command of the list, the lists that call the common event or transfer onto the map (to any
     depth, transfers on maps from 1000 on into their own thousand), or a later page that needs the
     companion in the party (a talk join's proof);
   - the step lies in the part, and the part's variable reaches that step where the row's own
     marks are set;
   - the side, where there is one, is asked for by the page, a branch or the map's name.
3. Targeted scans looked for what a row-by-row check misses: sides taken over from the way onto a
   map, rows placed on a route or the Chaos route while an earlier way in exists, give-backs the
   generator could not order, and join commands without a row.

Rows the checker could not confirm, and every row the scans named, were read by hand.

### Checked by hand and confirmed

- 44 `cap` gates: each matches the Level Cap milestone list at its place (Great Decision 65 at
  the routes' start, Monster Realm 83/95/100, Angelic Dominion 95, Chaos 130 from 1143 at 18, 135
  and 140 by Grand Noah (1302) or 1304, 145 by Yamatai (1307), 225 by 1373 at 13, the finale held
  at 250).
- 16 `floor` gates set outside their own list: the Ilias Temple upper layer's angels (map 1294
  event 7), the Six Ancestors (map 1271 event 32), the Pocket Castle revival's temporary joins
  (CE 9001, map 1187), and Alice's and Alicetroemeria's levels on the routes before the Chaos
  prologue (map 1650 event 19, map 1075 event 35).
- 18 `start` gates after a join of the same companion elsewhere in the table: those are on the
  other route, in the Chaos route's free order, or side content sorted last, where neither join
  surely comes first, so each is a first join.
- 15 pinned places of the generator (RAN_MARKS, PLACES, MAP_MARKS): Radio's join leads to map 619,
  whose event sets 1032 to 7; Sarasa's ship leads to map 1919, whose event 15 sets 1150 to 14;
  the Pocket Castle revival (CE 9141) runs at 1143 = 20 from the Reaper and map 1432 then sets 21;
  Monte Carlo's evacuation (map 1979 event 49) sets 1305 to 6 itself; map 1890 event 12 is the
  first visit to the Ilias Temple in the Monster Realm's map tree, at the route's start.
- Lilith & Lilim (map 182 event 14) on Alice's side: switch 2257 is turned on only by map 182
  event 15, whose page needs switch 4.
- The angel choice on map 1294 (events 16 to 21): each join sits in a Yes/No choice and carries
  the switch only its own event turns on, so only the chosen angel's row passes.
- The remaining marks without a direct source (Grangold warp 3228, Dying World 1032 at 7) come from
  the pinned scenes above.

### Fixed

| Row | Was | Now | Reason |
|---|---|---|---|
| Micaela-chan (34) and Lucifina-chan (36), map:297:13:3 | Part 1, step 13, Alice's side, marks 1001≥13, 1077≥2, 1231≥3 | Part 2, step 32, Ilias's side, marks 1001≥32, 1077≥2; moved after the Snow Shrine join | The revival page needs 1077≥1, which only Snow Shrine B1F's Ilias page (map 181 event 10 page 2, Part 2 step 32) sets. The old side kept every Ilias-side player from getting them. 1231 is the optional Sorcerer job event's value, which the revival does not need. |
| Aurora (582), map:222:42:1 | Alice's side | no side | Her page and branches ask for no side, and Remina's events have branches for both sides, so both sides play there. The side was taken from the way onto the map. |
| Granberia (16), map:1986:28:1 | gate 132, `kept` | gate 130, `cap` | Her nightmare event 1 (CE 9104) adds her, event 2 (CE 9105) removes her on a first playthrough, and this event brings her back. By the table's rule a give-back takes the cap there (130). The generator could not order CE 9105, whose conditions do not name 1373. |
| Melty (87), map:100:6:2 | no part, no step | Part 1, step 10, marks 1001≥10, 1017≥2, 2131 | The Slug Tower quest is Midas Village's (its rewards rows stand at Part 1 step 10), and her page needs 1017≥2 from it. The catch-up never brings in a join without a part. |
| Yamata no Orochi (230), map:367:8:1 | Chaos route, step 21, Chaos marks | Part 1, no step, mark 2317 | An optional boss. Her cave is entered from the world field (map 2 event 142) with no condition. The Chaos place came from the Chaos route's second way in (CE 9099), so only Chaos worlds carried her. Switch 2317 ("Yamata no Orochi Defeated") turns on right after the join, in the same branch. |
| Giganto (779), map:387:35:1 | Monster Realm route, step 62 | Part 3, no step, mark 2466 | An optional Tartarus boss. The Hellgondo crater has pages for both routes, so it belongs to neither alone. Switch 2466 turns on right after the join. |
| Nephilim (780), map:404:30:1 | Monster Realm route, step 62, marks 1141≥2, 1142≥62, 2447, 2740 | Part 3, no step, marks 2740, 2447 | An optional Tartarus boss whose crater is entered from Esta from 1141≥2 (the Angelic Dominion route). The row asked for both routes' progress at once. 2740 (Esta Tartarus entry) and 2447 (turned on right after the join) tell the event ran. |
| King of Sabasa (526), ce:382 | Monster Realm route, step 62, marks 1142≥62, 1145≥3, 7087, 7088 | Part 3, no step, marks 7085, 7087, 7088 | His revival needs 7087 (set on the Angelic Dominion route) and 7088 (set on the Monster Realm route), so it plays during whichever route comes second. 1145 is cleared by the route return; 7085 turns on right after the join. |
| Bonnie (202) and Ashel (201), map:1462:13:1 | marks 1143≥21, 1313≥5, 1352≥5 | marks 1143≥21, 1313≥4, 1352≥5 (`ran` stays false) | Found by the sampling review of 2026-10-28. Both joins (commands 205 and 206) sit in the choice "決戦を始める" under `1313 == 3`, and nothing in the list sets 1313, so 1313≥5 contradicted the branch. The battle leads to the Cursed Island (map 1832) and into the Cursed Undersea Temple, whose 1F autorun (map 1232 event 242) sets 1313 to 4 first. The 40 class_levels rows of the same site carry the same marks and changed with them. By the user's decision of 2026-10-28 (decision 1 of the [class_levels](#class_levels) section) both rows now have `ran` true. |

The review gave the optional rows Part 1 or 3 rather than a route because the catch-up passes a
route's rows once the route is finished, without their marks, which hands out an optional companion
nobody recruited. The user decided on 2026-10-28 that this is wanted ("auto unlock missed
companions"), so the four optional bosses are placed back on their generated route rows: Yamata no
Orochi on the Chaos route at step 21 (order 3205), Giganto, Nephilim and the King of Sabasa on the
Monster Realm route at step 62 (orders 2835 to 2838), each with its generated marks. Every player
gets them once that route is finished, and earlier where the world's story holds the marks. Each
carries a `note` with its reason.

Also by the user's decisions, the joins of CE 9022 (Chrome, Frederica) have `ran` true and the marks
`[v1143 21, v1316 6]`, and those of map 1462 event 13 (Ashel, Bonnie) have `ran` true; see the
[class_levels](#class_levels) section, decision 1.

### Dropped

| Row | Reason |
|---|---|
| Merlin (522), ce:209 | CE 209 ("Final Chapter 3.0-only processing") is a save repair that only the load fix-ups (CE 114) call, never a story event. The row has no marks and could never pass. |
| Cassandra (834), map:817:3:8 | By the user's decision of 2026-10-28: the Labyrinth of Chaos super boss joins like the collaboration's companions, through the raid shop later. Her page needs only the Labyrinth's own variable 126, so the row had no marks and no part and could never pass. |

### Not added

Every join command of the game outside the skipped maps and common events has a row. Temporary
joins have none, by the table's rule.

### Decided by the user (2026-10-28)

1. **Cassandra (834), map:817:3:8**: dropped (see Dropped); she comes through the raid shop later,
   like the collaboration's companions.
2. **The other 21 joins without a part** (20 collaboration companions, one recollection): intended,
   as recommended. The catch-up notes them as done and never brings them in; the collaboration's
   companions come through their own content and the planned raid shop.
3. **Optional companions on the routes**: "auto unlock missed companions". The rule stays: once a
   route is finished, its optional recruits reach every player, recruited or not. The four optional
   bosses the review had moved off the routes are placed back (see above).

### removals

Every removal of a companion by the story outside the player's own choices (Relay/core/
story_catchup.js `removals`), reviewed row by row against the TEST install's events
(`MGQ Paradox Test/Data`) on 2026-10-28.

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/removals.json) | 222 |
| Written (Relay/seed/story/removals.json) | 222 |
| Confirmed in bulk | 100 |
| Checked by hand | 122 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |

### How the rows were checked

1. The candidates are what the Event Checker's raid_data.rb writes from the TEST install, exactly.
   On the Translated install one command index differs (map:1529:6:1, Raphaela, 296 in TEST and
   300 there); the rows keep TEST's, and the order against her join in the same list (252) holds
   in both.
2. An independent checker (Ruby over the game's Marshal data) confirmed for every row: the site
   exists; the command at `index` removes `persona` (event command 129 or delete_actor_ex);
   `actor` is its main persona; `first` is true exactly when the command stands in a branch on
   "Overall Cycles" (912) = 0; the command is not in a choice; the list does not add the companion
   back later; and every mark, step and side has a source in the data (page, branches, the list's
   own commands, the lists leading to it).

### Checked by hand and confirmed

- 116 rows of CE 9141, the Pocket Castle's revival on the Chaos route: the Reaper calls it at
  1143 = 20 (map 576 event 2), it removes every companion in a first-playthrough branch and sets
  1344 to 1, and map 1432 sets 1143 to 21 afterwards. All 124 removal lines of the list are
  covered: the 8 without a row of their own are other personas of companions that have one
  (Priestess, Cassandra, Mephisto, Sara, Black Alice, Frederica).
- Morrigan (382), CE 379, Part 3 step 39: the throne scene runs after the Granberia battle on map
  332, whose move route turns switch 2487 on (the mark the checker could not trace).
- Alma Elma (19), CE 381, Ilias's side: CE 381 is called only from map 431, "Great Decision -
  Ilias".
- Raphaela (510) and Minagi (678), map:1978:5:1: destroyed San Ilia's autorun removes
  them, and the row passes once Monte Carlo's evacuation (map 1979 event 49) sets 1305 to 6, the
  next story value after them.
- Alma Elma and Morrigan, map:430:1:1 (Great Decision - Alice): the list sets 1001 to 40 and 1141
  to 1 itself.

### Not added

Of the 340 removal commands without a row, every one is left out by the table's rule: 85 stand in
a choice the player makes (such as which angel goes along), 253 are in the Labyrinth of Chaos or
the collaboration chapter (side content), and 2 lists add the same companion back in another
persona (the Witch on map 1374, Sonya on map 1834).

### For the user to decide

Nothing.

### lessons

Every skill the story and its quests teach a companion's persona (Relay/core/story_catchup.js
`lessons`), reviewed row by row against the TEST install's events (`MGQ Paradox Test/Data`) on
2026-10-28.

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/lessons.json) | 112 |
| Written (Relay/seed/story/lessons.json) | 112 |
| Confirmed in bulk | 102 |
| Checked by hand | 10 |
| Fixed | 6 |
| Dropped | 0 |
| Added | 0 |

### How the rows were checked

1. The candidates are what the Event Checker's raid_data.rb writes from the TEST install, exactly
   (the Translated install gives the same rows).
2. An independent checker (Ruby over the game's Marshal data) confirmed for every row: the site
   exists; the list teaches `actor` the skill `skill` (event command 318, learn); the skill and
   actor exist; no event takes the skill away again; the actor is not Luka; and every mark, step
   and side has a source in the data.
3. Scans looked for sides taken over from the way onto a map and for rows placed on a later part
   than an earlier way in allows.

### Checked by hand and confirmed

- Alma Elma's four skills at Monte Carlo's evacuation (map 1979 event 49), pinned by the
  generator to 1305 at 6, which that event sets itself.

### Fixed

| Row | Was | Now | Reason |
|---|---|---|---|
| Hakunen (811), Goblin Punch (6080), ce:366 | Alice's side | no side | CE 366, the Sorcerer job event, is called from map 297 event 16's Alice page and its Ilias page alike and teaches the skill on both sides. The side was taken from the way onto the map. Its mark 1231≥3 (set by the event itself) keeps the row from passing before it ran; the step (Part 1, 13) is only an early bound, since the event opens after the collaboration chapter ends (1212 at 8). |
| Lucia (167), skills 3038, 3043, 3047 and 859, map:330:72:1 | Chaos route, step 21, marks 1047≥3, 1143≥21, 1312≥3, 3193 | Part 2, step 25, marks 1001≥25, 1047≥3; moved before the Part 2 step 26 rows | Undine's lesson in Lucia's spirit quest (1047: Sylph 1 and Gnome 2 in Part 1, Undine 3, Salamander 4 at Part 2 step 28). The page needs Undine in the roster and 1047≥2; Undine joins on map 330 event 69, which sets 1001 to 25. The Chaos place came from the Chaos route's way into Undine's Spring (CE 9017), so only Chaos worlds carried the skills. |
| Gigi (99), skill 3047, map:330:75:1 | Chaos route, step 21, marks 1143≥21, 1312≥3, 2143, 3193 | Part 2, step 25, marks 1001≥25, 2143 | The same spring: the page needs Undine in the roster and Gigi in the party, and the event turns 2143 ("Gigi Water 1") on. Gigi's wind and earth lessons (2141, 2142) stand at Part 1 step 15. |

### Not added

Every learn command for a companion outside the skipped lists has a row, except 46 that the
table's rule leaves out:

- 10 in CE 208 ("trial v0.1 only processing"), a save repair the load fix-ups call;
- 36 in the collaboration chapter (Collab Overworld, maps 848, 852, 858, 872, 935), whose lists
  neither move the story nor share a side quest.

### Decided by the user (2026-10-28)

- **The collaboration chapter's 36 lessons** stay out, as recommended: the collaboration's
  companions are not carried (the [joins](#joins) section, decision 2).

### actor_changes

What the story's events change of the characters by the game's script calls, as the power-ups
(Relay/core/story_catchup.js `actor_changes`), reviewed row by row against the TEST install's
events (`MGQ Paradox Test/Data`) on 2026-10-28.

| | Rows |
|---|---|
| Candidates (fixtures/catchup/generated/actor_changes.json) | 81 |
| Written (Relay/seed/story/actor_changes.json) | 81 |
| Confirmed in bulk | 78 |
| Checked by hand | 3 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |

### How the rows were checked

1. The candidates are what the Event Checker's raid_data.rb writes from the TEST install, exactly
   (the Translated install gives the same rows).
2. An independent checker (Ruby over the game's Marshal data) read every script of the row's
   list, its continuation lines joined, and confirmed that `calls` are exactly the list's calls
   of persona_change, level_adjust, change_actor_ability, force_change_equip,
   change_actor_equip_stone and set_actor_had for that character, in order, with their numbers,
   leaving out calls inside a choice; each call's `once` is true exactly when it stands in a
   branch on "Overall Cycles" (912) = 0; `gate` is the highest level_adjust level, held at 250
   like the levels inside the calls (null without one); the personas exist; and every mark, step
   and side has a source in the data.
3. Scans looked for rows placed on a later part than an earlier way in allows, and for lists that
   change a character without a row.

### Checked by hand and confirmed

- The Reaper's Hades (map 576 event 2) power-ups of 696 and 698 on the Chaos route: the branch
  needs 1344 (the White Rabbit's revival) at 2, which only the Chaos route's Ilias Temple ruins
  (map 1589 event 10) set, after the Pocket Castle's revival set it to 1.
- The Pocket Castle's set_actor_had of 767 (map 228 event 86): its page needs 1143≥21.

### Not added

Every list that changes a character this way has its row.

### For the user to decide

Nothing.

## World

### parts

These are the story's parts in their order. Each has the marks that hold right before its ending
starts and its level gate, the cap of the last Level Cap milestone in the part
(`world_catchup_data.rbx` `PARTS`). Reviewed by hand on 2026-10-28 against the game data of the
TEST install and the workspace's "Level Cap milestones.md".

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/parts.json`) | 6 |
| Confirmed in bulk | 0 |
| Checked by hand | 6 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |
| Written (`Relay/seed/story/parts.json`) | 6 |

### Checked by hand and confirmed (6)

The ids and names are the relay's parts (`story.js` `PART`). Each gate matches the last
milestone of its part in "Level Cap milestones.md". Each ending was traced through the events
that set its values:

- **Part 1, gate 25 (Adramelech), ending 1001 >= 18 and 1032 >= 5.** Safar Desert Ruins 4L
  (map:414:8:1) sets 1001 = 18. Administrator's Tower 4F (map:174:6:1) sets "Dying World Events"
  1032 = 5. Adramelech's event on X1F (map:619:2:1) sets 1032 = 7 and sends the player to the
  Tartarus Escape, which sets 1001 = 19, the relay's end of Part 1.
- **Part 2, gate 55 (Sonya Chaos; the optional Black Alice is no gate), ending 1001 >= 33 and
  1075 >= 14.** Holy Wings Shrine (map:390:7:3) sets 1001 = 33. Later the Ilias Temple Ruins
  (map:727:5:1) set "Ilias Temple White Rabbit" 1075 = 14. The Middle Chapter's final battle sets
  1001 = 34.
- **Part 3, gate 65 (the Great Decision), ending 1001 >= 39 and switches 2485, 2486, 2487.**
  Monster Lord's Castle 1F (map:324:22:1) sets 1001 = 39. The three switches are the castle's
  Tamamo, Erubetie and Granberia battles, and nothing turns them off. The Great Decision (CE 380)
  sets 1001 = 40.
- **Angelic Dominion, gate 120 (Chaos Ilias), ending 1141 >= 73.** The Ilias Temple's 5th layer
  (map:1326:11:1) sets 73 after Micaela; the final battles follow at 74 to 76.
- **Monster Realm, gate 120 (Chaos Alipheese), ending 1142 >= 81.** The Saja battle (CE 469)
  sets 81; the final battles follow.
- **Chaos, gate 300 (Deus Ex Machina), ending 1143 >= 24 and 1348 >= 5.** The Chaos field
  (map:1287:233:1) sets 1143 = 24. The inner world (map:1843:1:1) sets "Final Battle" 1348 = 5
  after World Breaker and Judgement; the last fight follows.

None of the ending marks is undone later in the story.

### Notes

- No event in the data stops a player from entering the Administrator's Tower before the Safar
  Desert Ruins. The story's own order is Safar first, which Part 1's ending follows. A player who
  took the tower first would reach the ending at 1001 = 17, where these marks never held. This is
  a side path of the game's own and needs no row change.

### settings

These are the values of the player's own that follow the story: the game over's return point
(variable 1002) and whether random encounters are on. The catch-up sets one only where the player
still holds what an earlier story step set (`world_catchup_data.rbx` `SETTINGS`). Reviewed on
2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/settings.json`) | 95 |
| Confirmed in bulk | 48 |
| Checked by hand | 47 |
| Fixed | 7 |
| Dropped | 0 |
| Added | 0 |
| Written (`Relay/seed/story/settings.json`) | 95 |

### How the rows were checked

Running the Event Checker's `raid_data.rb` over the TEST install gives exactly the 95 candidates.
A separate script then checked every row against the game data:

- The site exists, and its list sets the row's value: an encounter command (code 136) or a
  constant set of variable 1002. Where the list sets it more than once, the row holds the last.
  All 95 rows passed this.
- The step lies in its part, the part's progress variable is among the marks near the step, and
  a site on a map from 1000 on lies under that route's root in the map tree.
- Each mark is found near the command: in the page's conditions, the branches around the command,
  the list's own commands, or one step out (the callers of a common event, the event's other
  pages, the lists that transfer onto the map).
- No mark names another route's progress variable.
- No mark is undone later in the story. Variables that only go up, the progress variables and
  the resets that never run in a Raid World were left out of this test.
- Within a part, rows of the same value come in story order.

48 rows passed every test. The other 47 were read by hand.

### Checked by hand and confirmed (40)

- **Progress marks without evidence nearby (31 rows).** The route maps are reached through long
  chains of transfers and scenes. For each row the setters of the part's progress at its step and
  the next step were listed and compared with the row's map. All fit the story's order:
  Part 1 rows 8 and 9, Part 2 rows 13, 14, 16, 18, 19 and 20, Monster Realm rows 24, 30, 44, 48,
  49, 51 to 56, 66, 70 and 77, Angelic Dominion rows 58, 64, 68, 69 and 72, Chaos rows 79, 81, 82
  and 85.
- **The Chaos route's free order (7 rows: 87 to 91, 93 and 94).** The step is 21 by rule: the
  free order starts after the Pocket Castle's revival (CE 9141). Every site lies under the Chaos
  root (map 1287) or is a Chaos common event (9000 and up).
- **Row 7** (map:738:5:2): its marks are found two and three transfers back.
- **Row 23** (CE 380, the Great Decision): 1002 = 112 is the return point of the Monster Realm's
  choice. Its mark, 1142 >= 1, holds from the route's first step on.

### Fixed (7)

Row numbers are the candidates' places in the generated file, counted from 0.

- **Row 26** (map:1890:8:1, return point 114): dropped the mark `s2491`. The arrival's next
  autorun (map:1890:12:1) turns that switch off at once, so the row would stop holding right
  after it ran, and the return point would fall back to an older one.
- **Row 32** (map:1650:3:1, return point 113): dropped the mark `s2490` for the same reason; the
  autorun map:1650:19:1 turns it off.
- **Rows 40 and 41** (map:1917:34:1 and map:1916:2:1, return points 54 and 55): dropped the mark
  `v1171 >= 6`. Grangold Castle 2F (map:1918:5:1) sets 1171 back to 0 on the way to row 41.
- **Row 59** (map:1002:12:1, return point 60): dropped the Monster Realm marks `v1142 >= 46` and
  `v1169 >= 24`. They came from map 1904's edge exits, which the thousand rule sends to map 1002.
  The event follows map:1883:11:1, which sets the Angelic Dominion's 1141 = 52. With those marks
  the row could never hold in an Angelic Dominion world.
- **Row 73** (map:1005:3:3, return point 67): part `ad` step 66 became part `mr` step 70, with
  marks `[["v", 1142, 70]]`. Page 3 of the moon event asks for 1142 >= 69 and sets 1142 = 70
  before the return point. The generator took the part from the map's root, which is the
  Angelic Dominion's. The row now sits after the Monster Realm's step 67 row (order 765).
- **Row 92** (CE 9003, return point 140): the mark `v1302 >= 6` became `>= 5`, and the row moved
  before CE 9004's (order 915). The Uriela battle leaves 1302 at 5, and the Erubetie battle
  (CE 9004) sets 6 after it. Before the fix, once both had run the older return point (140) won
  over the newer one (127).

### Missing rows

The game sets 1002 or the encounters in 726 more places. 721 of them (708 return points, 13
encounter commands) are in lists that never move the story on: the player's own prayers, inns
and passages. 2 are the resets to the Great Decision
(CE 267 and 268) and 1 is the game over map. The last 2 were read by hand:

- map:389:3:1 sets 1002 = 71 only in the branch where the corridor is a plain passage.
- map:1486:45:1 sets 1002 = 45 when the player chooses to pray.

Neither follows the story, so no row was added.

### Decided by the user (2026-10-28)

- **The Chaos route's free order**: the catch-up leaves the return point alone on that stretch,
  as recommended. The rows stay as they are; the rules got `free_order`
  (`[{"part": "chaos", "step": 21}]`, `make_seed.rb` `RULES`, `rules.json`), and the catch-up
  sets none of the player's own values whose latest row passed lies on such a step
  (`CatchupLook.Settle`). Once the world passes a later row, that row's value counts again.

### For the generator (`raid_data.rb`, Event Checker)

- It takes a map's part from its root even where the page asks for the other route (row 73).
- It marks variables and switches that a later scene of the same visit undoes (rows 26, 32, 40,
  41).
- It reads edge exits that the thousand rule sends elsewhere as the way into the map (row 59).

### vehicles

These are the events placed in the story that put a vehicle on a map for the player. The
catch-up gives a player each vehicle once any of its rows lies behind their story or the
world's (`world_catchup_data.rbx` `VEHICLES`). Reviewed on 2026-10-28 against the game data of
the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/vehicles.json`) | 23 |
| Confirmed in bulk | 8 |
| Checked by hand | 15 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |
| Written (`Relay/seed/story/vehicles.json`) | 23 |

### How the rows were checked

Running the Event Checker's `raid_data.rb` over the TEST install gives exactly the 23 candidates.
A separate script checked every row:

- The site's list puts the row's vehicle on a map. That is a "set vehicle location" command
  (code 202) naming a map, `forced_get_on_<vehicle>`, or `$game_map.<vehicle>.set_location` with
  a map. All 23 rows passed.
- The place was checked as for the settings: step against part, marks near the command, no mark
  of another route, no mark undone later.

8 rows passed every test. The other 15 were read by hand.

### Checked by hand and confirmed (15)

- **Rows 0, 1 and 2** (the ship at step 13): CE 7354 is the Gloria's victory, and map:753:67 is
  the Gloria's own talk pages. 1001 = 13 is set on the ship to the Sentora Continent.
- **Rows 5 and 6** (the boat at Esta, step 24) and **rows 8 and 9** (the ship at the World Tree and
  at the Succubus Village, step 30): each fits between the setters of its step and the next.
- **Rows 14 to 22** (the Chaos route): all lie under the Chaos root (map 1287), or on the Chaos
  Domain's camp (map 1994), and sit at the free order's step 21 by rule. The switches 3228 and
  3229 (Chaos Grangold warps) are set on the Chaos Grangold maps and never turned off, so they
  hold by the final battle.
- The `ran: false` rows (1, 2, 5, 9, 14, 18, 19, 21) are talks or autoruns the player may meet
  later. The catch-up gives vehicles without asking `ran`, so this changes nothing.

### Missing rows

Every command of the game that puts a vehicle on a map has a row, except 16 airship placements in
CE 31, the Escape spell's way out of the Chaos Domain onto Galda. They have no place in the story
and are left out on purpose; the airship comes with the Chaos rows anyway.

### Notes

- Rows 0 to 2 and rows 21 and 22 are not in the order their marks give. This does not matter here,
  since the catch-up only asks whether any row of a vehicle passed.

### warp_free_maps

These are the maps where a warp ban (switch 100, "Warp OFF Switch") left on while no event runs
is left over. The catch-up lifts it there (`world_catchup_data.rbx` `WARP_FREE_MAPS`). The table's
rule: the game sends the player to the map with the ban lifted more often than with it set.
Reviewed on 2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/warp_free_maps.json`) | 157 |
| Confirmed in bulk | 117 |
| Checked by hand | 18 (1 kept, 13 of the dropped, the 4 added) |
| Fixed | 0 |
| Dropped | 39 |
| Added | 4, and 36 by the user's decision |
| Written (`Relay/seed/story/warp_free_maps.json`) | 158 |

### How the rows were checked

Running the Event Checker's `raid_data.rb` over the TEST install gives exactly the 157 candidates.
Recounting showed that its count goes wrong in two ways:

- **The map a transfer really goes to.** The game's transfer command first reads variable 57
  (`NWConst::Var::MAP_TRANSFER`). When an event sets it, the transfer goes there, whatever map the
  command names. The Escape spell (CE 31), the game over (Hades) and many Final Chapter scenes
  work this way. They name a placeholder map such as 544, or the map's number without its
  thousand. The generator counted the named map.
- **A ban state from a branch that already left.** The generator kept the ban state the list
  last set, across branches. So in a menu that lifts the ban in its first branch and transfers,
  the other branches counted as lifted too, though they never touch the ban.

So every direct transfer of the game was counted again:

- at the map the game really sends the player to (variable 57 first, then the thousand rule);
- with the ban the player arrives with. That is the ban set or lifted at the transfer's own level
  right after it. Otherwise it is the nearest ban command before it, on the transfer's path or in
  an earlier branch that did not leave.

A map counts where more transfers arrive with the ban lifted than with it set. 117 rows passed
this recount and needed nothing more. The rest were read by hand.

### Checked by hand and confirmed (1)

- **1481** (Chaos Kitsune Village): map:1483:5:1 lifts the ban in a branch at its story step
  (1137 = 8), then sends the player here. Kept.

### Dropped (39)

- **The transfers counted for it go to another map, through variable 57 (28):** 75 (to 1075),
  76 (1076), 154 (1154), 162 (1162), 193 (1193), 276 (1276), 405 (1405), 430 (1430), 439 (1439),
  441 (1441), 461 (1461), 469 (1469), 544 (the placeholder map; its transfers go to 2, 576, 407,
  1861, 1911, 1650, 1890, 1558, 1375, 1791, 1598 and 1658), 642 (1642), 731 (1731), 745 (1745),
  750 (1750), 758 (1758), 762 (1762), 778 (1778), 791 (1791), 805 (1805), 831 (1831), 832 (1832),
  855 (1855), 1002 (1287), 1228 (228), 1544 (2, 389 and 576). Most of the real maps are already in
  the table.
- **No such map in the game (4):** 555, 561, 605 and 973. Their transfers go to 1555, 1561, 1605
  and 1973, which are in the table.
- **Only a ban state from a branch that left (2):** 312 and 315 (Hellgondo Shrine). The Pyramid's
  warp crystal (CE 9132) lifts the ban only in its branch to map 638; its branches to 312 and 315
  never touch it.
- **The game over keeps the ban on the way back (3):** 1527, 1531 and 1777. Each is reached once
  with the ban lifted and once from Hades with it set (a tie).
- **The map's own events set the ban while the player stays (2), read by hand:**
  - 358 (Don Father House): talking to Merlin (map:358:240:1) bans warping until his errand is
    done.
  - 1655 (Grand Noah destroyed, Monster Realm): the arrival's autorun bans warping. The ban stays
    until the story event at the exit (map:1655:1:1), which sets 1142 = 59, brings companion 385
    along and lifts it. Lifting the ban earlier would let a player warp past that event.

### Added (4)

The game sends the player to these maps with the ban lifted. The generator credited the transfers
to a placeholder map:

- **1375** Esta (AD): map:405:2:1 lifts the ban and sends the player here through variable 57
  (2 lifted, 1 set).
- **1435** Chaos Lost Forest 1F: the Escape spell (CE 31) lifts the ban and sends the player here
  (5 lifted, 1 set from Hades).
- **1441** Chaos Saloon: the Saloon's victory and defeat events (CE 7163, 7164) lift the ban on the
  way back (2 lifted, 1 set).
- **1558** Hellgondo Continent West Tartarus: the corridor map:389:3:1 lifts the ban on the way
  here (2 lifted).

### Decided by the user (2026-10-28)

- **The 39 more maps** of the recount: add them, as recommended. 36 were added, each with a
  `note`. Three were left out by the rule the review used for maps 358 and 1655, since their own
  story events set the ban while the player stays, and the catch-up lifts a ban on a warp-free
  map at every look: **7** Iliasville (event 63, Sonya's join, sets it until a later Iliasville
  event lifts it: events 2, 3, 76, 87 to 90), **280** Navy Headquarters Indoors (event 13 sets
  it with 1050 = 4, the choice to join the Navy) and **1535** Finoa Indoors, Monster Realm (event
  27 sets it with 1159 = 4). Lifting it there would let a player warp away in the middle of these
  events; that call is the user's to confirm.
- **The majority rule** stays, as recommended.

The recount's report as it stood before the decision:

- The recount finds 39 more maps the game sends the player to with the ban lifted, nearly all
  from a single transfer: 5 Ilias Temple 1F, 7 Iliasville, 13 Monte Carlo, 14 Yamatai Amabie 2,
  21 Grand Noah, 25 Finoa, 28 San Ilia Indoors, 29 Iliasburg, 30 Iliasburg Indoors, 31 Midas
  Village, 39 Port Marle, 43 Saloon, 61 North Ilias Monastery, 139 Iliasport, 141 Port Natalia,
  172 Administrator's Tower 3F, 206 Kitsune Village, 235 Nameless Slums, 256 Ilias Continent
  South Large Crater, 280 Navy Headquarters Indoors, 297 Hall of Creation 2F, 338 Grandeur
  Indoors, 341 Happiness Village, 422 Sabasa Continent North Large Crater, 426 Gold Continent West
  Large Crater, 683 Pornof, 690 Port Natalia, 766 Yamatai Village, 887 Demonic Castle 1FC Upper,
  925 Château des Romances Layer 4, 950 Alliance Gathering, 1006, 1046 Grangold Castle 5F (MR),
  1105, 1268, 1288, 1535 Finoa Indoors (MR), 1753 and 1812. They are not added, since a missing
  map only keeps a left-over ban the player can walk out of. Add them?
- The majority rule still lifts a few bans the game sets on purpose, such as on the field (map 2)
  right after the Gold Fort scene (5 of 299 arrivals there come with the ban set). Keep the rule
  as it is?

### For the generator (`raid_data.rb` `scan_warp_places`, Event Checker)

- Read variable 57 before a transfer's own map, and the thousand rule for every map event,
  whatever map the command names.
- Do not carry a ban state from a branch that left, and count a ban set right after the transfer
  for the map it arrives at.
- `read_area` builds the Makina's transfer links from the raw map number. For maps from 1000 on
  this drops the links; it changed no Makina's level (see the [makina](#makina) section).

### makina

These are the Makina: each one's item, the level a player of a Raid World reaches it at, and the
easiest place that gives it. The level is that place's area level, and at least the Level Cap's
cap where the gift waits for the story (`world_catchup_data.rbx` `MAKINA`). Reviewed on
2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/makina.json`) | 29 |
| Confirmed in bulk | 24 |
| Checked by hand | 5 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |
| Written (`Relay/seed/story/makina.json`) | 29 |

### How the rows were checked

Running the Event Checker's `raid_data.rb` over the TEST install gives exactly the 29 candidates.
A separate script then:

- listed every item of type 2 described as `[Makina]`: the same 29 items (700 to 728). No row
  names another item, and no Makina lacks a row;
- found every event command that gives each Makina (code 126, adding a constant);
- worked out each giving place's area level on its own. That is the highest enemy level (the
  enemies' `<逃走レベル>` tag) of the random encounters in the event's region. Failing that, it
  takes the nearest maps' by transfers, up to 4 steps away, and then the fights there. Transfers
  were read the way the game reads them (variable 57, the thousand rule).

24 rows give the same place and the same level as the lowest of these. The other 5 were read by
hand.

### Checked by hand and confirmed (5)

- **715 MLRS (level 45) and 719 8.8cm Anti-Monster Church Cannon (level 60)**: San Ilia's
  laboratory (map:588:8:1) has area level 15. These gifts wait for the story, though. 715 asks
  for 1001 from 29 to 39 and 1071 >= 3, where the Level Cap is 45 (Queen Mermaid). 719 asks for
  1001 >= 40, where the cap is 60. The rows hold those caps.
- **725 Charged Particle Acceleration Cannon (level 90)**: the review finds area level 75 for
  Grand Noah Palace 4F (MR), where the generator found none. The page asks for 1142 >= 47, where
  the Monster Realm's cap is 90 (Kagetsumugi), and the higher of the two counts. So 90 holds
  either way.
- **728 Dimensional Collapse Launcher (level 260)**: area level 147, cap 260. This is the user's
  decision of 2026-10-24 that 728 stays at 260.
- **720 Anti-Particle Railgun (level 72)**: the same chest stands on both copies of Grand Noah
  Palace 1F (AD), map:1581:44:1 and the conquest copy map:1872:42:1, both at level 72. The row
  names the second, and the level is the same, so it stays.

### For the generator (`raid_data.rb` `read_area`, Event Checker)

- The area's transfer links use the raw map number, so for maps from 1000 on most links are lost.
  None of the rows' levels changed because of it (725 is held at its cap). A later game update
  could expose it.

### prize_variables

These are the counts of prizes handed out once, outside the story's range of variables. A Raid
World shares each count, so once any player claims a prize it is past for everyone. The rewards
table holds each prize as a reward of the count past its step (`world_catchup_data.rbx`
`PRIZE_VARIABLES`). Reviewed on 2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/prize_variables.json`) | 29 |
| Confirmed in bulk | 29 |
| Checked by hand | 0 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 59 (by the user's decision) |
| Written (`Relay/seed/story/prize_variables.json`) | 88 |

### How the rows were checked

Running the Event Checker's `raid_data.rb` over the TEST install gives exactly the 29 candidates.
A separate script went through every list of the game for a prize branch: "if the variable equals
a step" (code 111), holding a set of the variable to the next step and a gift of an item, weapon
or armor. It found such branches for every row's variable, each with the variable's own name:

- 83 Survival 1 Item Get (7 prize branches, CE 188);
- 87 Challenge Prize (10, CE 148), the Reaper's Battle Challenge;
- 701 Colosseum Rank (6, CE 158);
- 703 to 728, the Colosseum's cups by race, "Yoma Only" to "Roids Only" (4 each, CE 161 to 186).

### Missing rows

The same scan finds such branches on other variables too. All of them are each player's own: the
companions' "Ally: Presents" (4000 and up), the affection range, and the event variant (129). Or
they are scratch variables. None belongs in this table, so nothing was added by the review.

### Added by the user's decision (59)

- **v801-858 and v907**, the battlefucks' progress and wins (user decision of 2026-10-28,
  "recommended as long as every player gets it"). They are no counts of a prize branch: each
  battlefuck's victory sets its counter (2, or 3 for 854-857), and CE 6999 gives its prizes at 15,
  35 and 40 wins. But battlefuck progress and rewards are world-wide (user decision 2026-10-24),
  and the 57 rewards rows they mark are the battlefucks' prizes, so they count as prize variables:
  a player whose story holds the world's counter and who holds none of a prize gets it. Each
  carries a `note`.

### prize_switches

The switches of prizes handed out once, such as the Medal King's one-of-a-kind exchanges, which
the rewards hold as rewards of the switch on. A prize row with such a switch among its marks gives
when the player's own story is past it and they hold none of the prize, as for `prize_variables`.
A new table of 2026-10-28 (`Relay/core/story_catchup.js`, `CatchupTables.PrizeSwitches`), by the
user's decision "once anyone buys, distributed to everyone".

| | Rows |
|---|---|
| Written (`Relay/seed/story/prize_switches.json`) | 5 |

The rows were read in the data: common event 140 (the Medal King's exchange) gives each of these
prizes and turns on its switch right after (commands 541 and 542, 573 and 574, 605 and 606, 637
and 638, 669 and 670); with the switch on he only answers that he handed the one item over
already, so once one player bought it nobody else can:

- **s2324** "Acquired Heinrich's Sword": weapon 112.
- **s2325** "Acquired Heinrich's Armor": armor 97.
- **s2326** "Acquired Heinrich's Helmet": armor 226.
- **s2327** "Acquired Heinrich's Shield": armor 321.
- **s2336** "Noble Orb Acquired": item 662.

Their rewards rows (common event 140, Part 1 step 13, marks 1001 at 13, 1090 at 3 and the switch,
`ran` true) are unchanged; the switches stay `shared` in `keys`. Each row carries a `note`.

### side_events

These are the events that give each side, Alice's or Ilias's, other skills or companions before
the Great Decision. Each row holds each side's rewards, whether the event is where the player
chooses a side, and the marks each of its pages leaves once it ran (`coop_story_rewards.rbx`
`GROUPS`). A Classic party member who catches up gets their side's rewards of such an event once
the leader's story is past it. Reviewed on 2026-10-28 against the game data of the TEST install.

| | Rows |
|---|---|
| Candidates (`fixtures/catchup/generated/side_events.json`) | 19 |
| Confirmed in bulk | 11 |
| Checked by hand | 8 |
| Fixed | 0 |
| Dropped | 0 |
| Added | 0 |
| Written (`Relay/seed/story/side_events.json`) | 19 |

### How the rows were checked

Running the Event Checker's `story_rewards.rb` over the TEST install gives exactly the 19
candidates. A separate script read every page of each row's event again:

- Each page has a side from its conditions (switch 4 or 5), from its map's name, such as "Middle
  Chapter Final Battle (Alice)", or from the one side switch it turns on.
- Branches on switch 4 or 5 split the page into each side's commands.
- Collected for each side: the skills Luka learns (code 318 for actor 1) and the companions who
  join. A companion joins by a party change (129), by their switch (1002 to 2000), or by
  `add_actor_ex`, `add_actor_ex_nc`, `add_stand_actor` or `set_actors`.

The rewards and `choice` of all 19 rows came out the same. Every page's marks are set by a page
of the same event, and none is undone later in the story. 11 rows passed with that. The other 8
were read by hand.

### Checked by hand and confirmed (8)

- **The six camps** (map:406:7, 523:7, 604:7, 711:7, 736:7 and 741:7): the night talks that teach
  Luka a skill by side. They leave no mark in the story, so their marks are empty. The game's
  co-op then hands them out once the leader holds a skill only that camp gives, as intended.
- **map:933:7** (Land of Night, the collaboration's world): on Alice's side the page brings
  companion 382 along. The row's mark is the page's own self switch A.
- **map:437:11** (Chaos Route Prologue, Strategy Conference): see below.

### Missing rows

A scan of every event of the game finds 4 more events whose sides differ. They are the Great
Decision (CE 380), its two resets (CE 267 and 268) and Lucifina's house on the Angelic
Dominion's moon (map:1010:6). All play at or after the Great Decision, which the table leaves out
by its rule. Nothing was added.

### Decided by the user (2026-10-28)

- **map:437:11** stays, as recommended.

The question as it stood:

- **map:437:11** is the Chaos route's opening conference, which plays after both route endings,
  so after the Great Decision. That puts it outside the table's own rule. The generator counts it
  because its map is below 1000 and its page reads no route variable. What it does is real,
  though. On Alice's side it brings back Ilias (26), 34, 36, 383 and 538, whom the Great Decision
  took away; on Ilias's side Alice (5) and 45. A Classic member on the Chaos route therefore gets
  their side's companions back once the leader's story passes it. Keep it, as written now, or
  drop it to keep the table to its rule?

## Keys

### keys

The story mapping's `keys` table says how a Raid World shares each switch and variable. A key
without a row is each player's own. Reviewed on 2026-10-28 against the game data of the TEST
install (untranslated 3.06). Every row carries a `note` that gives its reason. Seeding leaves
the notes out; the admin route keeps them.

| | Rows |
|---|---|
| Candidates (the Ruby rules of 422527f3, see below) | 6,028 keys |
| Confirmed in bulk | 3,213 |
| Checked by hand | 483 |
| Fixed (another kind than the Ruby rules gave) | 220 |
| Dropped (no row, see below) | 2,327 |
| Added (keys the first scan missed, see below) | 58 |
| Written (`Relay/seed/story/keys.json`) | 3,754 |

What was written, by kind: 2,179 `shared`, 1,053 `one_way` (806 of them affection with
`wholeWorld`, 125 with `routeReturnClears`), 273 `personal`, 227 `chest`, 21 `scene` and 1
`count`. 73 rows carry `defeatWrite`.

### The candidates

Until now a Raid World shared every key that an event wrote, unless a list made it personal. So
the candidates are every switch and variable that some event writes, plus every key the Ruby
constants name:

- `world_catchup_data.rbx`: `ONE_WAY_VARIABLES` (259), `SCENE_SWITCHES` (21), `DEFEAT_RETURNS`
  (v1062, v1339), `RETURN_CLEARED` (1144-1200, 1301-1500).
- `world_story.rbx`: the Queen's Cup (`CUP_VARIABLE` 1052, `CUP_STEPS`, `CUP_OPEN`,
  `CUP_PLACES`) and `BATTLE_SCENES` (v1075).
- `battles_raid_freeze_data.rbx`: `DEFEAT_WRITES` (56 switches, 17 variables).
- `story_state.rbx`: `PERSONAL_SWITCHES`, `RAID_PERSONAL_SWITCHES`, `PERSONAL_VARIABLES`,
  `RAID_PERSONAL_VARIABLES`, the side switches 4 and 5.
- `coop_choices.rbx` (now `ChoiceTable.cs`): the keys of every choice's outcomes, 29 switches
  and 7 variables.
- `coop_story_rewards.rbx` `CHEST_FLAGS` (196), in the reviewed form of `chest_flags.json` (227).
- `world_affection.rbx`: the affection of every main persona of actors 1 to 999 (917).
- `world_catchup.rbx` `COUNTS`: v1354, which plan question B4 makes a count the relay keeps.

These big ranges stay rules without rows, as before: the companions' party switches 1001-2000
(the game reads them from the party), the awakening switches 6000-6999, the monsters'
friendliness 2000-2999 and the companions' presents 4000-4999 (each player claims their own
gifts).

### How the rows were checked

The game data was read with a Ruby script with Marshal stubs, as the Event Checker does. It
collected every write and read of every switch and variable: map pages, common events, troop
pages, page conditions, scripts, the switch commands of Set Move Route (codes 27 and 28) and
scripts that write a range in a loop. The game's own scripts (Scripts.rvdata2) were searched for
writes too. They write only keys that are personal or have rows already: the casino's coins
(v7), the challenge's damage, friendliness and affection.

A "story writer" is a map event, a common event or a troop page that can run in a Raid World.
That leaves out the Reaper's reset of time and the collaboration's reset (common events 153,
155, which never run there), the load fix-ups (114), the player's own common events (2, 3, 5)
and the debug island (map 189). The route return (common event 154) clears whole ranges. A key
that only the route return writes gets no row, since nothing else ever sets it.

In bulk:

- **Shared (1,920 of the 2,179; 200 low keys and v1079 were checked by hand, 58 were added)**: every switch
  from 2001 on and every variable of 1001-1999 that a story writer sets, unless a rule below
  gives it another kind.
- **One-way (247, without affection)**: `ONE_WAY_VARIABLES` was derived again from the events by
  its own rule. Every write sets a number above 0 or adds to the value, and no list sets a lower
  number than it set before. The game over's returns on map 154 do not count. The result matches
  the 259 candidates exactly. That rule cannot see two lists that set different numbers in an
  order the player picks, so a second scan looked for one-way variables that two lists set to
  different numbers at the same story step (both under an equality check of 1001, 1141, 1142 or
  1143) without a check of the variable itself. Only v1079 came up (see Fixed).
- **routeReturnClears (125)**: common event 154 sets 0 for 839-858, 1140-1200 and 1301-1500. It
  clears every one-way variable in the `RETURN_CLEARED` ranges and none outside them.
- **Scene (21)**: derived again, with the same result. Every list that turns such a switch on
  turns it off again later, at the same indent or nearer the list's top.
- **Defeat writes (73)**: derived again by walking common event 3000 and every common event it
  calls (11, 112, 900, 902). The result matches the 56 switches and 17 variables exactly. Every
  one of the 73 is personal, since the defeat processing only writes battle, scene and Labyrinth
  state.
- **Chest (227)**: the reviewed `chest_flags.json`. A script checked again that only pages that
  give something turn each one on, and that only the route return turns one off.
- **Affection (806)**: v(3000 + id) for each named main persona of actors 1-999. Sub-personas
  share the main persona's affection, as the game does (the `<副人格:ID=n>` note tag and
  DataEx's original persona). All 23 affection variables that events write are among them.

### Checked by hand (482)

- **The keys below the story's ranges (428 rows)**: these are switches 1-1000 and variables
  1-1000 that a story writer sets. Each was checked by its name and by the events that write and
  read it. 200 are shared and 228 are personal. The groups:
  - Shared, as before or by the user's decisions: the opening flag (s1), Sonya Joined (s6), the
    job releases (s90-92), Forbidden Release (s444), the Second Accessory (s445, issue #62), the
    Dungeon Navi's first talks (s448, s450), the Grand Theater's stages (s601-700), the prize
    counters of the Survival course and the Battle Challenge (v83, v87), the Colosseum's rank and
    cups (v701, v703-728), the battlefucks (v801-858, v905, v907, all 2026-10-24 decisions) and
    the playthrough counts (v911, v912).
  - Personal: the existing personal lists; scratch keys (System Only s11-20, Event
    General-Purpose s31-39, General v10-18, Item General v6-7, Colosseum General Purpose v702);
    battle-time values of the battle common events and troops (s21, s96, s98, v20, v24-33, v37,
    v38, v51, v112); the battle settings set right before a fight (s82-86, s505-510); place
    states like the warp ban (s27 Party Edit Forbidden, s81 Companion Denial, s89 Encounter OFF,
    s449 In M.S. Fish, the camp's place v53-54); the Labyrinth of Chaos's run state (s42-80,
    s93, s148, s421-441, v121-157, v601-608, v910); the update fix-up markers of a save
    (s144-146, s149); a companion talk's own flag (s451, issue #48); and single options and
    scratch (s2, s7, s8, s25, v3, v28, v52, v58, v61, v114, v202).
- **The choices (36 rows)**: each switch and variable of `ChoiceTable` is written by its own area's
  events (Magistea, Navy Headquarters, Plansect, Succubus Village, the Secluded Lands, the
  Pyramid, Iliasville). All stay personal, as before. Seven of them (v1029, v1050, v1051, v1053,
  v1056, v1061, v1065) are also in `ONE_WAY_VARIABLES`. The choice wins, as it did.
- **v1052, the Queen's Cup** (`localSteps`): the sign-up (map 484 event 1, lobby, x 14) sets 3.
  The waiting room's event 12 (x 38) sets 4 and 5, and the Arena's event 86 (map 483) sets 6
  after the final. Map 383 event 4 sets 2 (`sharedAs`). The waiting-room events that read it
  (14, 19) stand east of x 30; the lobby's (7-13, 22) stand west of it. Hades (154) has no event
  that reads v1052. It stays a place because a lost match's game over passes through Hades;
  the data cannot show this.
- **v1075, the White Rabbit** (`battleScene`): Ilias Temple Ruins 3L, map 138 event 13, is an
  autorun page at v1075 ≥ 14. It sets 15, fights troop 868 (ソニアマズダ), sets 16 and fights
  troop 869 (ソニアマンユ). Their defeat events (3368-3370) set 12, map 138 event 32 sets 13 and
  map 727 event 5 sets 14. The main story is at 33 (map 390 event 7 sets it, maps 750 and 751
  set 34).
- **v1062 and v1339** (`defeatReturns`): derived again by `raid_data.rb`'s rule. Map 33 event 50
  sets v1062 to 4 before Gnosis (troops 672, 673), and her defeat events 3223 and 3224 set 3.
  Common event 9046 sets v1339 to 2 before troop 2157, and defeat event 3954 sets 1. v1140 came
  up too, but another list sets the same step, so it was rightly left out.
- **v1354** (`count` of 3101-3180): the 80 switches "親方発見" (Randolph found), counted by the
  relay as plan question B4 asks. It was in `ONE_WAY_VARIABLES` too. The route return clears the
  switches, so the count falls with them.
- **s2013, s2015** (the Pocket Castle's tour) and **v1002** (the game over's return point):
  personal, from the existing lists.
- **Story keys with scratch-like names (4 rows, shared)**: s2042 "Sonya Emerged Flag Temp
  Storage" (map 6 event 17 sets it, map 7 event 23 reads it and clears it), s2250 "General
  Mermaid Defeated" (a mermaid general), s2524 "Ashel Temporary Companion" (a story flag) and
  v1106 "Loop General Postscript" (common event 541 moves it from 1 to 7). All are real story
  values.
- **The Labyrinth of Chaos's keys in the story's ranges (5 rows, personal)**: s2147, s2333,
  s2335, v1049, v1095. Only the Labyrinth's maps (root 644) and its common events write them.
- **v1079 (shared)**: see Fixed.
- **Pickup counters (3 rows, personal)**: v1166 and v1351 count the Mitra seal castles'
  pedestal pickups (common events 427 and 9054). v1229 counts the Demon Castle Tour's chests
  still closed on each floor. The chest reviews made those pedestals and tour chests each
  player's own, so their counters are too. v1166 and v1351 were in `ONE_WAY_VARIABLES`.

### Fixed (220)

The rows below have another kind than the Ruby rules gave.

- **Shared before, personal now (183)**: the scratch, battle-time, battle-setting, place,
  Labyrinth, fix-up and option keys listed above, s2147, s2333, s2335, v1095 and v1229. Each
  one's value only matters while its own event, fight or Labyrinth run lasts. If they were
  shared, every event that touches them would land in the derived index, and its self switches
  would be shared. The hold on players behind would then also refuse those events.
- **Shared before, chest now (32)**: s2915 and s2927-2957, the Demon Castle Tour's chests, from
  the `chest_flags` review.
- **Chest before, shared now (1)**: s2914, from the `chest_flags` review. A gift of sake to the
  Sheep Girl turns it on, and that is no chest.
- **One-way before, personal now (3)**: v1049 (Labyrinth), v1166 and v1351 (the pickup
  counters).
- **One-way before, shared now (1)**: v1079 ("女王撃破後相手判定用"). It names the queen just beaten:
  Grand Noah 1 (map 383 event 4), San Ilia 2 (map 355 event 32 page 3), Grangold 3 (map 38 event
  29) and Sabasa 4 (map 378 event 7 page 5). All four fights stand at v1001 = 30, each behind its
  own variable (1070-1073 at 2), so the player picks the order. Common event 329, called right
  after each write, reads 1079 with == 1 to 4 once all four are beaten. One-way would keep a
  higher number from an earlier queen and play the wrong queen's scene. Raised by the rewards
  review and the sampling review.

s445 was personal in `PERSONAL_SWITCHES` at 422527f3. It is shared now by the issue #62
decision, which was already built for Raid Worlds, so it is not counted as a fix.

### Dropped (2,327)

- **2,214 keys that only resets, fix-ups or the player's own events write**: 1,428 are written
  only by the never-run resets, the load fix-ups, the player's own common events or the debug
  island. 786 are only cleared by the route return. Nothing in a Raid World's story sets them,
  so a row would change nothing.
- **111 affection variables of empty actor slots** (main personas without a name).
- **s2344 (Loop: Freedom Flag) and s2417 (Loop: Alma Elma's Reward)**: shared rows before. Only
  common event 541 writes them, and only to turn them off; no event reads them. A row changes
  nothing, so the rule under Added drops them.

Five keys of the personal lists are set by no story writer: s95, s447, v9, v200 and v201. They
stay personal without rows. This accounts for the rest of the 6,028 candidates.

### Added (58)

The first scan read only Control Switches and Control Variables (121, 122) and scripts that write
`$game_switches[N]` with a number. The sampling review found switches that the story writes in two
other ways; the scan now reads both.

- **Set by a story event's move route (4, shared)**: s2486 "Monster Lord's Castle Erubetie
  Battle" (map 331 event 17, commands 95 and 129), s2487 "Monster Lord's Castle Granberia
  Battle" (map 332 event 4, commands 388 and 514), s2906 "Novissa Departs" (map 867 event 8,
  command 29) and s2908 "Magatsu Conversation" (map 853 event 75, command 21). These are their
  only story writes. The pages after the battles ask for them (map 331 events 17-19 and map 332
  events 4, 14 and 15, page 2; map 576 events 110 and 111), and common events 508 and 511 read
  2906 and 2908. s2485, the Tamamo battle of the same castle, was shared already. Without a row
  the world never kept them: the rows marked by them could never pass (removals 9 and 10 by
  s2487, lessons 100 and 103 and class_levels 2068, 2069 and 2076 by s2908, the parts row of Part
  3 by s2486 and s2487), and a player on the world's story who missed the fight would meet the
  battle's autorun again. No event page's own move route writes a switch.
- **Library Flags turned on by a script loop (54, shared)**: s5372-5397 (the Intro, map 545
  event 1, and common event 207) and s5555-5582 (the Pocket Castle attack, map 475 event 8,
  command 78). Shared like the other Library Flags (decision 3).

A new rule came with the scan: a switch that no story event turns on and no event reads gets no
row. It keeps out ten Warp Flags that only map 475 event 8's loop clears (5043 "Missing Number"
and the unnamed 5076-5083 and 5090) and drops s2344 and s2417 (see Dropped).

After this, every row of every catch-up table names only keys the world keeps (shared, one-way,
count), choice outcomes or party switches, apart from the 32 rewards rows of the tour chests,
which the rewards review now drops (see the [rewards](#rewards) section).

### Left out on purpose

- **BEATEN** (`MGQ_MpRaidPool::BEATEN`) waits for plan question C4 and the Raid Designer
  redesign. It has no rows here.
- **s2719** ("Treasure Chest: Land-Dweller's Sealed Orb") stays shared: by the user's decision
  of 2026-10-28 it is the key of a world chest (the [chests](#chests) section), which the world's
  story keeps.

### Decided by the user (2026-10-28)

Every row stays as written; the user confirmed each recommendation:

1. **The 183 keys made personal** stay personal, the Labyrinth of Chaos's records and currency
   (v122, v156, v157, v910) among them: each player keeps their own Labyrinth.
2. **The Grand Theater's stages (s601-700)** stay shared, like the Colosseum's prizes.
3. **The Library Flags and the Warp Flags** stay shared.
4. **The playthrough counts v911 and v912** stay shared.
5. **The chest kinds taken from the chest reviews** stay: the 32 tour chest flags each player's
   own (`chest`), s2914 shared (the user: "global"), and the pickup counters v1166, v1351 and v1229
   personal (the [chest_flags](#chest_flags) and [party_chests](#party_chests) sections).
6. **s31-39** stay personal, not `scene`.

### Notes

- The rows come from the review scripts outside the repository (`rows-scratch/keys/build.rb`).
  They read the reviewed chest tables, so they must run again if those tables change.
- An admin applies the file in two slices of at most 2,000 edits: 0-1,999 and 2,000-3,753.
- Once the relay is seeded, the battle server derives the self-switch index from these rows. A
  rough estimate of it (the index's rule in Ruby) shares the self switches of about 18,100 of the
  69,922 map events and about 2,580 common events.

### events

The story mapping's `events` table holds the self switches that go against the derived index.
Without a row, an event's self switches are shared when the event reads or writes a shared key,
and each player's own otherwise. Reviewed on 2026-10-28 against the game data of the TEST
install (untranslated 3.06). Every row carries a `note` that gives its reason.

| | Rows |
|---|---|
| Candidates | 5,237 |
| Confirmed in bulk | 5,218 |
| Checked by hand | 19 |
| Fixed | 3 |
| Dropped | 1, and 5,077 chest rows by the user's decision |
| Added | 91 (by the user's decision) |
| Written (`Relay/seed/story/events.json`) | 251 |

What was written: 51 chests (`share` `personal`, `chest: true`), 95 world chests and the found
items' marks (`shared`, 96 in all), and 13 rows of the Navy's and the Pirates' lines
(`personal`). The review wrote 5,128 chest rows; by the user's decision of 2026-10-28 only the 51
whose event the derived index would otherwise share stay (see the decisions below). Decision 3
of the [party_chests](#party_chests) section added 80 chest rows (the 76 stage pay-outs and four
pick-ups whose event the index shares) and 11 world chests, so the file holds 131 chest rows and
106 world chests now.

### The candidates

- `world_catchup.rbx` `FOUND_MAP` 0 and `FOUND_LETTER` "F": the marks of the items unlocking a
  job or a race, and of the Makina, that a player of the world found.
- `coop_choices.rbx` `NAVY_MAPS` (11 maps) and `NAVY_SELF_SWITCHES` (map 376, event 53, A and B).
- `world_catchup_data.rbx` `CHESTS` (95): the chests of key items and unlock items, which open
  once for the whole world.
- `coop_story_rewards.rbx` `CHESTS` (5,223): every chest of the game, each player's own. The 95
  world chests are among them.

### How the rows were checked

The chest rows come from the reviewed `party_chests.json` and `chests.json` in this folder. A
script checked each key against the game data again:

- The event exists.
- One of its pages gives something (gold, items, weapons or armor).
- The same page turns that letter on.
- A world chest's page gives each listed item.

All 5,223 party chests and all 95 world chests passed. A world chest is `shared`. Every other
chest is a `chest` row.

The Navy's maps were confirmed by their names. They are the Grand Pirate's Cave of each route
(231-233, 703, 708, 709), Navy Headquarters under the pirates' attack (667, 680) and the MS
Fish's attack (685, 696, 701).

A rough estimate of the derived index (its rule in Ruby, over the reviewed `keys` rows) shows
that the rows are needed. Without them, 22 of the 95 world chests would be shared, and the
other 73 would be each player's own. 51 ordinary chests would be shared. Map 376 event 53 and 33
events of the Navy's maps would be shared too.

### Checked by hand (19)

- **ss0.\*.F** (shared): the game has no map 0, so only the mod writes these marks
  (`world_catchup.rbx` `gained`). They are the world's.
- **The 11 Navy maps** (`ss<map>.*.*`, personal): each player plays their own side, so one
  pirate's treasure taken does not empty the next player's chest.
- **ss376.53.A and ss376.53.B** (personal): the MS Fish 1F's Ashel. Page 1 turns A on. Page 3
  needs s2149 (Support Pirates), brings Ashel (actor 201) with `add_actor_ex(201)` and turns B on.
  This is the Pirates' outcome of `ChoiceTable`.
- **The chest rows the chest reviews changed (5)**:
  - ss51.23.B is the world chest of the Fortune Teller Permit, not A, which only marks the first
    talk.
  - ss1650.44.B is the world chest of the Sealed Orb of the Seeker, not A.
  - ss1650.14.C is the world chest of the Sealed Orb of the Warrior. ss1650.14.A stays a chest
    row: it shuts Saja's gift of four weapons.
  - ss885.25.A is dropped: the Sheep Girl's page takes a Yamatai Sake and gives nothing.

### Fixed (3)

- **ss51.23.A → ss51.23.B** and **ss1650.44.A → ss1650.44.B**: each was a world chest and a
  party chest under the wrong letter. Each is now one world chest row with the right letter.
- **ss1650.14.A → ss1650.14.C** as the world chest. A became a chest row.

### Dropped (1)

- **ss885.25.A**: not a chest, see above.

### Decided by the user (2026-10-28)

1. **Only the 51 chest rows that need one**, as recommended: saves stay local for now, so the
   player's own save keeps every other chest's self switches. The 51 were found by the real
   derivation, `SelfSwitchIndex.Derive` of `MGQOnline.Game` run over the reviewed `keys` and
   `events` rows and the TEST install's data (18,049 map events and 2,572 common events in the
   index): exactly the chest rows whose event it shares, the same 51 the review's estimate named.
   Among them are the 14 pedestals of map 1457 and two chests of Iliasville Indoors (ss6.50.A,
   ss6.55.A), whose pages ask for the shared switch 2019. The 5,077 others are dropped; without a row each of
   them is personal by the index, and the index is the same without them, since only the rows
   naming a whole event or map (`*`) change it. Each kept row's `note` gives this reason.
2. **The open questions of the chest reviews**, decided on 2026-10-28: the Purple Orb chest
   ss371.12.A stays a world chest (`shared` here), and s2719 is a world chest by its switch, which
   needs no row here.
3. **The loot pages that also move the story** (decision 3 of the
   [party_chests](#party_chests) section): a `chest` row for each new party chest whose event the
   derived index shares (all 76 stage pay-outs and 4 of the 5 pick-ups; the Chimera Dryads' gem
   is each player's own without one), and a `shared` row for each of the 11 new world chests. The
   real derivation over the new rows gives the same index as before. The rows were added to this
   file directly; `rows-scratch/keys/build.rb` does not know them yet.

### Notes

- The rows come from the review scripts outside the repository (`rows-scratch/keys/build.rb`),
  which read the reviewed chest tables. If those change, the scripts must run again.
- An admin applies the file in one batch (251 edits).
