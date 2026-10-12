# Raid Worlds

A Raid World plays one story for the whole world, and everyone on a map shares it, in a party or not. Everyone starts from the beginning, on the difficulty the creator set. Everyone on a map watches its scenes, battles pull in the nearest players, each story boss is one fight the whole world wears down, and a player behind catches up as they level.

What every world shares, such as the world screen, the chat, parties, co-op battles, duels and trading, is in the [Player guide](GUIDE.md). For the other world type, see [Classic Worlds](CLASSIC_WORLDS.md).

- [Creating a Raid World](#creating-a-raid-world)
- [On the map](#on-the-map)
- [The story](#the-story)
- [Behind the world's story](#behind-the-worlds-story)
- [The Great Decision](#the-great-decision)
- [World overview](#world-overview)
- [Battles](#battles)
- [Raid bosses](#raid-bosses)
- [Every raid boss](#every-raid-boss)

## Creating a Raid World

Pick *Raid* as the *World type* in the create form (see [Creating a world](GUIDE.md#creating-a-world)). A Raid World is red in the list of worlds, above every other.

- **Everyone starts from the beginning:** *Shared save* and *Player's choice* aren't offered.
- **Difficulty:** the difficulty every player plays on. The game's own difficulty choice and the Reaper's change set this one instead of the one picked. The Labyrinth of Chaos, the Colosseum and the bosses with their own difficulty keep theirs, and a battle you join fights with its host's. The creator can change it later with *Edit the world*, and the new difficulty reaches the players in the world at once; a Raid World made without one shows *Per player* there until a difficulty is picked.
- **Sharing companions:** *Off*: everyone recruits their own companions. *Story companions*: once any player has a companion the story brings, every other player gets them on reaching that companion's level. *Story + battle recruits*: the same, also for companions recruited after a battle. Nobody gets back a companion they had, or one their own story took away for good. Fixed once created.
- **Turn off other mods** is ticked at first, until you untick it (see [Turning off other mods](GUIDE.md#turning-off-other-mods)).

## On the map

- **Everyone is fully visible**, in a party or not, and everyone on your map gets an arrow at the screen's edge while off the screen, the nearest eight at most.
- **The map box:** outside a party, while anyone else is on your map, the party box becomes the map box: everyone there by name in white, each with their icon, the level of their Frontline character and their ping, without a place. Its title says how many are on the map ("Map 4"). It grows up to 10 lines; with more players the last line says "+3 more". **Tab** makes it small too. In a party, the party box lists your party wherever its members are, each with their Frontline level, and below it, under "Map 2", the other players on your map, a line each.
- **Your squad:** everyone has a squad, in a party or not and whatever the party's size: one Frontline and two Backline characters. The fourth character of your team is cut: the formation screens show them in black and white below the line, and they fight in no battle, your own and duels included. Your team holds four at most; a companion who joins a full team waits in the Pocket Castle.
- **No followers:** nobody walks behind anyone on the map.
- **NPCs:** everyone on a map sees the same NPCs, moved as in the game of whoever entered the map first.
- **Chests** are your own: a party shares no loot. The chests that hold the story's key items are the world's (see [The story](#the-story)).

## The story

- **One story:** the relay keeps the world's story, and whoever moves it on moves it on for everyone. Your game takes the world's story when you enter the world, load a save or start a new game, and whenever another player's story moved on, once you're free on the map. Your saves hold the world's story as it was then. Nobody plays a party leader's story here.
- **What stays yours:** your party, companions and affection, your side (Alice or Ilias), your own answers to the story's choices, and your chests. The chests that hold the story's key items are the world's: each opens once, for everyone.
- **Key items:** every key item the world's story gives or takes reaches every player, whatever part of the story they're in.
- **Ores and blacksmiths:** the forging ores (Lump of Iron to Meteorite, and the Final Chapter's Scarletite to Final Ore) count as key items: once anyone in the world finds one, every player holds it, so every town's blacksmith and Papi forge the same for everyone. Papi's training and the Final Chapter's forge levels are part of the world's story.
- **Randolphs:** the Randolphs anyone found count for everyone; your count always matches the Randolphs the world found.
- **Makina:** each Makina comes to you once your level reaches the level of the area where it can be found, such as level 6 for the three in Tartarus I299387 ("Your level brought you Makina: Auto Crossbow."). You hold one of each; a chest of one you already have gives no second. Only your actual level counts, never the level cap of another mod: a character held at a cap below a Makina's level doesn't bring it. Whenever you enter the world or load a save, everything your level has reached comes at once: Makina, companions, and the story's skills and items that wait for it.
- **Telling the story:** a story event starts only while nobody else on your map tells one; otherwise you read "\<name> is telling the story here." Everyone on the map whose story stands where the teller's stood watches the scene, its dialogue, pictures and fades, and stands still while it plays, though not while the teller fights the story's battle. A player whose story stands elsewhere sees the NPCs move, but not the scene.
- **Two at once:** when two players on one map start a story event at the same moment, the one who came onto the map first goes on. The other's event waits a second at its start and usually stops before it changed anything; on a slow connection it can stop part-way. That second's wait comes before every story event while a player who came onto the map before you is on it.
- **Following the story:** when the story moves its teller to another map, the players watching it come along at once. Everyone else who was on that map, a player behind the world's story included, reads "\<name>'s story moved on to \<place>. Follow?" in the notification box: **Y** follows, **N** dismisses it. The offer stands while that story is still being told, for a minute at most.
- **Teleport to the story** on your own row of the World overview takes you where the world's story was last told, once you're free on the map. It's closed while you're behind.

## Behind the world's story

When your story is in an earlier part than the world's (Part 1, Part 2, Part 3 or a route), such as on your first entry into a world that played on without you, you're behind. In the world's own part you simply take the world's story, however far behind you were in it.

- **Your part's end:** you see the world as it was just before the end of your part and play on there ("The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 25 to move on."). Story events don't start and say "Reach level 25 to continue the story."; side events, talks, shops, chests and battles work as usual.
- **Level gates:** once the highest base level among your characters reaches your part's gate, you move on ("Level 25 reached: catching up to Part 2."): Part 1 at 25, Part 2 at 55, Part 3 at 65, the Angelic Dominion and Monster Realm routes at 120, Chaos at 300. Each gate takes you to the next part the world played, one part at a time, until you're in the world's story. You never play a part's ending yourself. If another mod's level cap holds you below the gate, you move on once you're at the cap, but the story's skills and items that move carries you past wait until your actual level reaches the gate. While you're behind, you learn no skill of the world's story past your part's checkpoint.
- **Finished routes:** behind in Part 3 or earlier, you never catch up through a route the world already finished. At your part's gate you move straight into the world's current route, and you still get the finished route's story skills, key items and rewards; its companions join once you reach each one's level.
- **What the story carried you past:** its skills and items come to you with a notice. Its companions join once your actual level reaches the level they joined at ("\<name> joins you once you reach level 40."), and the companions it took away for good leave. The story's choices you were carried past are asked on the screen of choices, each with your own answer.
- **Your own changes stay:** side events and anything else you did while behind are kept when you move on; only what the world's story itself changed since then overrides them.
- **Loading and entering again** while behind keeps you behind until your level reaches your part's gate.

## The Great Decision

- **The first route chosen is the world's.** The first player to choose a route at the Great Decision chooses it for the whole world: from then on the choice offers only that route until the world finished it, and says "The whole world plays this route." A player who chose another route at the same moment reads "The world took the \<route> route first." and is taken to the story.
- **Carried past it:** a player the world's story carries past the Great Decision confirms the world's route on the screen of choices, which plays their own side's part of it.
- **Back to the Great Decision:** a finished route's credits take the world back to the Great Decision, and every player still on that route follows; the next route is chosen there, among those the world hasn't finished. The third way (Chaos) shows only once the world finished both others.
- **No reset:** the Reaper can't turn back time in a Raid World ("Time cannot be reset in a Raid World."), since one player would take the whole world back.

## World overview

The [World overview](GUIDE.md#world-overview) shows more in a Raid World. Its title names the world's difficulty ("World | Raid | Hard").

**The World page** also shows:

- **Where the world's story stands** ("Part 2: Alice side", *Not told yet* before anyone moved it).
- **The objective:** what to do next, as Amira would tell you when you ask her for information, also before her information network is ready.
- **The raid bosses,** grouped under a heading per part of the story in the order the story meets them: *Part 1*, *Part 2*, *Part 3*, *Angelic Dominion*, *Monster Realm*, *Chaos route* and *Chaos Domain*. Only the parts the world's story has reached show, and any part with a boss someone has fought already. Each boss shows its name, its tier, a thin gauge of the HP the world has left of it with the share ("68%"), *Defeated* once it fell, and who last hurt it. A boss nobody has fought yet is full. See [Every raid boss](#every-raid-boss) for the whole list.

**The Levels page** shows what catching up gives you by level, and only what the world has unlocked already:

- **Your level**, the highest base level among your characters, which catching up goes by.
- Under a heading per level ("Level 25"): moving on from a part of the story the world is past (*Story*), the companions whose joins the world's story has got past or the world shares (*Companion*), and every Makina (*Makina*).
- A row you already have is dimmed and says *Done*; one your level has reached says *Due* and comes within a moment. A *Story* row also says *Due* once another mod's level cap holds you below its level, as such a cap lets you move on. **Up** and **Down** scroll the page.

## Battles

A Raid World's battles take the players on the map, party or not. The rules every co-op battle follows are under [Co-op battles](GUIDE.md#co-op-battles); these change:

- **Whoever meets the enemies hosts the battle,** with their own difficulty and mods; nobody asks the leader. It invites the nearest free players within 20 tiles, your party's members first, up to four players, you included, and a busy party member is waited for as in any co-op battle. Players who watch the story you tell join its boss battle too.
- **Your squad fights:** every player brings one Frontline and two Backline characters.
- **No Level Sync:** everyone fights with their own levels.
- **Fewer encounters:** any player within 20 tiles makes your steps to the next random encounter longer, not only your party's members.
- **Random encounters join a running battle:** when you meet enemies within 20 tiles of another player who hosts a battle that isn't a boss battle, an event's battle included, your game asks that battle to take you in. You, your enemies and the players you'd bring along join it at its next turn ("Joining \<host>'s battle at its next turn...", with "Up to 75 s" and the seconds waited below it): as many of them as it has room for, up to four players and eight enemies, so a crowded battle still takes you. When it is full or doesn't answer within 3 seconds, your encounter starts as a battle of its own, which invites those players; anyone it doesn't invite walks on.
- **Joining by choice:** within 3 steps of a player in a battle that takes players in, "Press J to join battle" shows below your character. **J** asks its host, and you join at its next turn, an event's battle and a boss battle too. A battle that can't take you says why in the notification box, such as "Cannot join \<host>'s battle: it is full."
- **Your party and a battle outside it:** when you join the battle of a player outside your party, by an encounter or with **J**, your party members near you are asked in the notification box. With room for you all it says "Join battle with \<you>?", and **Y** brings them in after you. Without that room, your encounter asks "Start battle with \<you>?" and waits up to 8 seconds: if someone says yes, you all fight your encounter apart; if not, you join the other battle alone. Party members who aren't near don't hold you up.
- A battle stays joinable, and shows as a battle, while its player has the Library or Config open from the battle's party command.

## Raid bosses

Each story boss is one fight the whole world shares, and so are the six one-time bosses of the Chaos Domain (the Chaos' Phantoms). Its HP is kept on the relay, and every battle against it wears down the same HP, so a boss usually takes many battles, by many players, to fall.

- **Raid HP:** the boss has many times its usual max HP, and the strongest bosses more defense and magic defense too, by its tier (see [Tiers](#tiers)). Both come on top of the world's difficulty.
- **Shared damage:** your battle tells the world what it dealt every couple of seconds, also in the middle of a long turn. While you choose your commands, and at the start of every round, the boss's HP is set to what the world has left of it, so damage dealt in other battles shows up there every few seconds.
- **It heals slowly:** a boss gets back 3% of its max HP a minute, also while it's being fought. A boss nobody fights fills up again in a little over half an hour.
- **Losing is fine:** a lost battle is an ordinary defeat, and the damage you dealt stays. A retry fights the boss with the HP the world has left.
- **The boss falls once its HP runs out,** whoever deals the last blow: every battle still fighting it wins at its next round, with the usual rewards. Everyone in the world reads "\<boss> is defeated for the whole world." The story goes on through the battle of the player who started it, and moves on for the whole world. A boss stays defeated for good; a battle that starts against it is won at once.
- **Bosses of several enemies,** such as Kagetsumugi and her dolls, have HP for each one. The bar shows a name and a gauge for each of them, side by side under one title, and the battle is won once all of them are down.
- **Watching the story:** players on the map who watch the scene leading up to the boss are invited to its battle too. A player who arrives while the boss battle already runs can move freely and join it with **J** next to the player fighting it.
- **Side battles:** when a boss battle near you, a side battle included, is full or won't take you in, the prompt below your character says "Press J to fight \<boss> alongside". Press **J** to fight the same boss in a battle of your own, so every player can fight a boss at the same time. It starts at once, invites and holds nobody, and other players near it can join it with **J**. It shares the same HP, plays no story scene and none of the boss's battle events, and losing it is a defeat like losing the boss's own battle. You can't start one against a boss your own story has beaten already, or against a defeated one.
- **Side battle rewards:** the first side battle you win against a boss gives its EXP, gold and drops; later side battles against the same boss give none. The boss's own story battle still gives them. This holds for players who join a side battle too.
- **Hades rematches** fight the bosses as the game has them, never their raid HP, and the rematch hall shows no boss bars.

### Tiers

Every raid boss has a tier, from 9 for the story's first bosses to 0 for Chaos alone. The tier multiplies the boss's stats as the table says, on top of the world's difficulty; every other stat stays as the game has it, and every tier heals the same 3% of its max HP a minute. [Every raid boss](#every-raid-boss) lists each boss with its tier.

| Tier | Max HP | Defense and magic defense | Bosses |
|---|---|---|---|
| 0 | 50 times | 5 times | 1 |
| 1 | 45 times | 4.33 times | 27 |
| 2 | 40 times | 3.67 times | 15 |
| 3 | 35 times | 3 times | 4 |
| 4 | 30 times | 2.33 times | 23 |
| 5 | 25 times | 1.67 times | 14 |
| 6 | 20 times | as in the game | 7 |
| 7 | 15 times | as in the game | 13 |
| 8 | 10 times | as in the game | 4 |
| 9 | 5 times | as in the game | 3 |

### The HP bars

- **In battle**, the top of the screen shows the boss's title (such as *Archangel*, *Phenomenon of Ruin* or *Tier 6 Raid Boss*), its name, and a big bar with its HP and the share left inside ("3,412,880 / 5,000,000  (68.3%)"). Very large HP is shortened, keeping at least 7 digits, such as "236,167 B / 1,009,500 B". A boss of several enemies, such as the Three Nobles of Black, gets a name and a bar for each of them, side by side under the one title, the three sharing the width. The bar hides while a message shows at the top of the screen. **Tab** shrinks it to the bars alone, without the title and the names, and back; a hint on the strip names the hotkey, and the game remembers your choice.
- **HP just lost** stays visible for 2 seconds as a darker part of the bar behind the HP left, then drains away, so you see each hit, yours and the other battles'.
- **On the map**, the boss's title and name with a thin bar above its event show its HP as the world has it right now, full while nobody has fought it yet; a boss of several enemies gets a wider bar with a name and a thin bar for each of them. When the boss's event can't be seen, the battle's bar runs across the top of the screen instead, and the notification box and the party box move down below it, unless you moved the bar or them elsewhere (see [Interface](GUIDE.md#interface)).

## Every raid boss

Every raid boss, listed as the World overview's World page lists them: by part of the story, in the order the story meets them, each with its tier and what its tier multiplies. Where the story meets a boss more than once, its name carries the level cap of that fight, such as *Tamamo (cap 61)*. A fight of several phases or enemies is one raid boss. The lists name bosses from the whole story, so each part stays closed until you open it.

<details>
<summary><b>Part 1</b> (10 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Four bandits | Tier 9 | 5 times | as in the game |
| Queen Harpy | Tier 9 | 5 times | as in the game |
| Morrigan | Tier 7 | 15 times | as in the game |
| Chrome and Frederica | Tier 8 | 10 times | as in the game |
| Sylph | Tier 7 | 15 times | as in the game |
| Sphinx | Tier 5 | 25 times | 1.67 times |
| Sara | Tier 8 | 10 times | as in the game |
| Astaroth | Tier 7 | 15 times | as in the game |
| Gnome | Tier 7 | 15 times | as in the game |
| Adramelech | Tier 5 | 25 times | 1.67 times |

</details>

<details>
<summary><b>Part 2</b> (25 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Bonnie and Ashel | Tier 9 | 5 times | as in the game |
| Alma Elma, then Granberia | Tier 7 | 15 times | as in the game |
| Mephisto | Tier 8 | 10 times | as in the game |
| Tezcatlipoca | Tier 7 | 15 times | as in the game |
| Gnosis | Tier 6 | 20 times | as in the game |
| Zion | Tier 6 | 20 times | as in the game |
| Undine | Tier 7 | 15 times | as in the game |
| Lilith | Tier 7 | 15 times | as in the game |
| Queen Ant | Tier 7 | 15 times | as in the game |
| Salamander | Tier 7 | 15 times | as in the game |
| Queen Fairy | Tier 6 | 20 times | as in the game |
| Queen Elf | Tier 6 | 20 times | as in the game |
| Queen Alraune, then Aži Dahāka | Tier 7 | 15 times | as in the game |
| Queen Mermaid | Tier 6 | 20 times | as in the game |
| Spider Princess | Tier 6 | 20 times | as in the game |
| Carmilla | Tier 7 | 15 times | as in the game |
| Elizabeth | Tier 7 | 15 times | as in the game |
| Queen Vampire | Tier 6 | 20 times | as in the game |
| La Croix's zombies | Tier 8 | 10 times | as in the game |
| Black Dahlia, Black Mamba and Black Rose (cap 55) | Tier 5 | 25 times | 1.67 times |
| Black Alice (cap 65) | Tier 5 | 25 times | 1.67 times |
| Eden | Tier 5 | 25 times | 1.67 times |
| Sonya Mazda | Tier 5 | 25 times | 1.67 times |
| Sonya Mainyu | Tier 5 | 25 times | 1.67 times |
| Sonya Chaos | Tier 4 | 30 times | 2.33 times |

</details>

<details>
<summary><b>Part 3</b> (7 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Garuda | Tier 5 | 25 times | 1.67 times |
| Erubetie (cap 60) | Tier 5 | 25 times | 1.67 times |
| Black Dahlia, Black Mamba and Black Rose (cap 60) | Tier 5 | 25 times | 1.67 times |
| Tamamo (cap 61) | Tier 5 | 25 times | 1.67 times |
| Erubetie (cap 62) | Tier 5 | 25 times | 1.67 times |
| Granberia | Tier 5 | 25 times | 1.67 times |
| Great Decision | Tier 5 | 25 times | 1.67 times |

</details>

<details>
<summary><b>Angelic Dominion</b> (14 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Heaven's Gate | Tier 4 | 30 times | 2.33 times |
| Gabriela | Tier 4 | 30 times | 2.33 times |
| Uriela, Sabiriel and Fernandez | Tier 4 | 30 times | 2.33 times |
| Sariela | Tier 4 | 30 times | 2.33 times |
| Laplace | Tier 4 | 30 times | 2.33 times |
| Metatronne and Sandalphone | Tier 4 | 30 times | 2.33 times |
| Zion (three fights) | Tier 4 | 30 times | 2.33 times |
| Cosmos (cap 90) | Tier 4 | 30 times | 2.33 times |
| Aži Dahāka | Tier 4 | 30 times | 2.33 times |
| Marcellus and Black Alice | Tier 4 | 30 times | 2.33 times |
| Doppel Lukas and Lucifina | Tier 4 | 30 times | 2.33 times |
| Micaela | Tier 4 | 30 times | 2.33 times |
| Ilias | Tier 3 | 35 times | 3 times |
| Chaos Ilias | Tier 3 | 35 times | 3 times |

</details>

<details>
<summary><b>Monster Realm</b> (12 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Queen Eva | Tier 4 | 30 times | 2.33 times |
| Malboro Girl, then Kanon | Tier 4 | 30 times | 2.33 times |
| Kanade (cap 75) | Tier 4 | 30 times | 2.33 times |
| Tamamo (cap 80) | Tier 4 | 30 times | 2.33 times |
| Tamamo (cap 83) | Tier 4 | 30 times | 2.33 times |
| Minagi and Alipheese the 10th | Tier 4 | 30 times | 2.33 times |
| Kagetsumugi and her dolls (cap 90) | Tier 4 | 30 times | 2.33 times |
| Hiruko (cap 95) | Tier 4 | 30 times | 2.33 times |
| Kagetsumugi and Magatsu-Karura, then Black Alice | Tier 4 | 30 times | 2.33 times |
| Saja (cap 105) | Tier 4 | 30 times | 2.33 times |
| Alipheese | Tier 3 | 35 times | 3 times |
| Chaos Alipheese | Tier 3 | 35 times | 3 times |

</details>

<details>
<summary><b>Chaos route</b> (37 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Kagetsumugi and her dolls (cap 125) | Tier 2 | 40 times | 3.67 times |
| Angolmois (cap 130) | Tier 2 | 40 times | 3.67 times |
| Greedy Papi, Gob, Teeny and Vanilla | Tier 2 | 40 times | 3.67 times |
| Gabriela and Kanon | Tier 2 | 40 times | 3.67 times |
| Uriela | Tier 2 | 40 times | 3.67 times |
| Kanade (cap 140) | Tier 2 | 40 times | 3.67 times |
| Hiruko (cap 140) | Tier 2 | 40 times | 3.67 times |
| Magatsu-Omikami | Tier 2 | 40 times | 3.67 times |
| Apiro Lagos | Tier 2 | 40 times | 3.67 times |
| Zion and Laplace | Tier 2 | 40 times | 3.67 times |
| Sigrdrifa | Tier 2 | 40 times | 3.67 times |
| Metatronne and Sandalphone, then Singularity | Tier 2 | 40 times | 3.67 times |
| Sisel, EX-Kyubi, Frere and Bloody Dragon | Tier 2 | 40 times | 3.67 times |
| Saja (cap 168) | Tier 2 | 40 times | 3.67 times |
| World Drown | Tier 2 | 40 times | 3.67 times |
| Cosmos (cap 180) | Tier 1 | 45 times | 4.33 times |
| No Life King | Tier 1 | 45 times | 4.33 times |
| Angolmois (cap 190) | Tier 1 | 45 times | 4.33 times |
| Hiruko, Kanon and Kanade | Tier 1 | 45 times | 4.33 times |
| Baal Zebub | Tier 1 | 45 times | 4.33 times |
| Seven Deadly Sins vessels | Tier 1 | 45 times | 4.33 times |
| Greedy, Envious and Slothful Eva | Tier 1 | 45 times | 4.33 times |
| Seven Deadly Sins | Tier 1 | 45 times | 4.33 times |
| The All-Knowing | Tier 1 | 45 times | 4.33 times |
| Agaliarept | Tier 1 | 45 times | 4.33 times |
| Echidna Queen | Tier 1 | 45 times | 4.33 times |
| Cthulhu | Tier 1 | 45 times | 4.33 times |
| Dimensional Eroder | Tier 1 | 45 times | 4.33 times |
| Star Eater | Tier 1 | 45 times | 4.33 times |
| Black Alice (cap 245) | Tier 1 | 45 times | 4.33 times |
| Idea Lukas | Tier 1 | 45 times | 4.33 times |
| EX Sonya | Tier 1 | 45 times | 4.33 times |
| Koron | Tier 1 | 45 times | 4.33 times |
| Goddess, Demon and Fiend | Tier 1 | 45 times | 4.33 times |
| World Breaker and Judgement | Tier 1 | 45 times | 4.33 times |
| Deus Ex Machina | Tier 1 | 45 times | 4.33 times |
| Chaos | Tier 0 | 50 times | 5 times |

</details>

<details>
<summary><b>Chaos Domain</b> (6 bosses)</summary>

| Boss | Tier | Max HP | Defense and magic defense |
|---|---|---|---|
| Fourth Law | Tier 1 | 45 times | 4.33 times |
| Null Lilith | Tier 1 | 45 times | 4.33 times |
| Fifth Law - Nirvana | Tier 1 | 45 times | 4.33 times |
| Void Image of Paradise | Tier 1 | 45 times | 4.33 times |
| Chaos Maria | Tier 1 | 45 times | 4.33 times |
| Fifth Law - Fallen Angel | Tier 1 | 45 times | 4.33 times |

</details>
