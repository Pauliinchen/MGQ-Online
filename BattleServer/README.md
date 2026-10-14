# Battle server

Runs Monster Girl Quest Paradox battles without Game.exe: plain Ruby 3.3 loads the game's own
316 scripts and the mods in `Patch/`, stubs out everything that draws, plays sound or reads
keys, and plays battles with the game's own `Scene_Battle`. Clients talk to it over TCP, one
JSON object per line each way.

## Run

The server needs a game folder with only the game's `Data` folder and a `Patch` folder of the mods
that change the game's rules (never the client-only ones such as MGQ Online or Discord RPC), named
by `BATTLE_GAME_DIR`. The game's files never go into this repository.

```
set BATTLE_GAME_DIR=<game folder>
ruby -W0 BattleServer erver.rb          # listens on 127.0.0.1:8095 (BATTLE_PORT)
ruby BattleServer	oolsient.rb 1481 1:120
ruby BattleServerTestsun.rb          # the tests; those playing battles need BATTLE_GAME_DIR
```

`-W0` silences the game scripts' warnings about constants defined twice. The tools take their file
paths before the boot, which moves into the game folder.

## Requests

| Request | Answer |
|---|---|
| `{"op":"ping"}` | boot time, battles so far, whether a battle runs |
| `{"op":"battle","troop":1,"party":[[1,10]],"seed":1,"switches":{},"variables":{}}` | the whole battle, played by the game's auto battle: `result`, `turns`, `log`, `party`, `troop`, `ms` |
| the same with `"save":"<save file in base64>"` instead of `"party"` | the battle with the save's party, inventory, HP, switches and variables |
| `{"op":"start", ...same fields}` | the first event of a battle played turn by turn |
| `{"op":"answer","commands":{"1":[{"skill":2433,"target":0}]}}` | the next event |
| `{"op":"answer","choice":0}` | the next event |

Events: `commands` (the actors due, with their usable skills and the enemies alive), `choice`
(an ero offer, a grab, any event choice), `end` (`victory`, `defeat`, `escape`, `turn_limit`,
`given_up`) or
`error`. Each event carries the battle log lines since the last one. A command per action is
`skill`, `item`, `attack` or `guard`, with `target`; an actor without commands uses auto battle.

## Layout

```
server.rb          the TCP server: a child per connection on Linux, one battle at a time elsewhere
lib/compat.rb      what Ruby 1.9.2 (RGSS3) had and Ruby 3.3 dropped (Fixnum, Object#=~, ...)
lib/rgss.rb        RGSS3's built-in classes: Table, Color, Tone, Rect real; Bitmap, Window, Sprite,
                   Graphics, Input, Audio, Win32API as stand-ins that show nothing
lib/rpg.rb         the RPG module: the database's classes as the RGSS3 reference defines them
lib/boot.rb        loads the scripts in order and the database; turns the game's saves off
lib/battle.rb      runs one battle: commands, choices and the log instead of windows and keys
lib/session.rb     one battle played turn by turn in a thread, waiting for the client's answers
lib/save.rb        reads the game's save files; classes of mods the server lacks become stand-ins
lib/save_check.rb  refuses a save naming anything but the game's classes, before Marshal reads it
lib/sandbox.rb     closes a battle's child in on Linux: no network, game folder only, no writes
tools/             try_boot, try_battle, sweep (many troops), client, load_test, show_save,
                   security_test, compare, find_variable, and dump_scripts, which writes the
                   game's scripts to a folder for reading
game_side/         the game's half of a comparison with Game.exe (see below)
Tests/             the tests (run.rb); fixtures/ holds shuffle and sample picks recorded in Game.exe
```


## Linux

On Linux the server forks: the parent loads the game once (about 7 s, 714 MB shared) and each
connection gets a child of its own, which plays its battles and ends with the connection. A
child that crashes or is killed ends only its own battle. `BATTLE_CHILDREN` caps the children
(64), each child may use 120 CPU seconds, and `BATTLE_FORK=0` turns forking off. Windows has no
fork, so there it plays one battle at a time.

To run it in WSL: `ruby3.3` from apt, the folder copied to `/opt/mgq-battle` without write
access for others (`rsync -a --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r`), then as root
`ruby -W0 BattleServer/server.rb` and `ruby BattleServer/tools/load_test.rb <battles> <think s> <level>`.

## Measured (2026-10-14)

- Boot: about 7 s, 830 MB (Windows) or 714 MB (Linux, after `Process.warmup`).
- 330 troops (every 10th) against a level 120 Luka: no errors, 72 victories, 258 defeats;
  0.13 s per battle and 0.055 s per turn on average. The battle log's pauses take one frame
  each: with the game's full pauses (`BATTLE_FULL_WAITS=1`) a turn takes 0.14 s, and all 330
  battle logs are the same either way.
- Linux, 20 battles at once with 1 s think time: 18 children, 1.5 GB for parent and children
  together, first answer after 230 ms (fork, new game and battle start), answers per turn
  45 ms (median) to 290 ms.
- Linux, 40 battles at once: 34 children, 2.5 GB together, answers per turn 51 ms (median) to
  211 ms. A child's own memory grows with its battle's length, about 70 to 380 MB.
- A battle ends after 300 turns as `turn_limit`: Chrome Doll Mk.I (troop 1446) has about 10^29
  HP and never falls.

## What a battle needs from the game state

A fresh new game is not enough, since battles read the story's switches and variables:

- Variable 150 (enchantment rarity) is 0 in a new game and breaks enchanted drops.
- The difficulty variables (41 onward) are 0 until common event 112 "Difficulty Application"
  runs, which leaves enemies at 1 HP; the server runs it before every troop of a fresh game.
  A battle from a save keeps the save's own values, as the Chaos Labyrinth sets them its own way.

From a save (2026-10-14): the four saves of a test install load in 0.04 to 0.4 s, with every
party member's levels, job, equipment, HP and skills. Every 10th troop against Save02 (late
game): 330 victories, 1.35 s per battle, slowest 7.5 s; characters with 1000 to 2300 skills cost
far more than a fresh one. Against Save09 (level 13): 19 victories, 311 defeats, 0.44 s.

A battle needs only part of a save: the party's actors, the party (inventory), switches,
variables and system. That is 646 KB (136 KB compressed) for Save02 and 75 KB (7 KB) for Save09,
against 2.7 MB and 0.6 MB for the whole save.

## Same as Game.exe

24 battles played in the real game and on the server with the same save, system save, troop
and seed came out the same line for line (2026-10-14): every damage number, choice, state, turn
and HP. They span eight saves from the early to the late game, parties of 4 to 16,
ero offers and a 170-line late-game fight.

What it took:

- **Ruby 1.9.2's shuffle and sample** (`compat.rb`): both Rubies draw the same numbers from a
  seed, but 3.3 picks with them differently. Checked against 3500 picks from the game.
- **Ruby 1.9.2's define_method** (`compat.rb`): after a `private` in the class body, 3.3 makes
  such methods private. The damage formulas read `a.atk` through them (DamageEvalBattler), and
  private they skipped the skills' stat additions, such as a magic-to-attack bonus.
- **The system save** (`system` in a request): the library's lifetime counts (battles,
  defeats, ...) raise some damage (`booster_ex_count`), so a battle needs the player's own.
- **Seeds at two points:** right before the troop's setup and as the battle scene starts
  (seed + 1), since the game draws random numbers in its other scenes.
- Variable 150 at 0, as some saves have it, crashes the game itself on an enchanted drop; the
  comparison sets it to 1 on both sides.

`game_side/` holds the game's half: `zz_TestDriver.rb` (goes into the game's Patch folder),
`compare.rb`, `trace.rb` (every random draw), `damage_probe.rb` (every hit's factors) and
`game_battles.ps1`. They go into a test install only for a comparison and come out after it.
`tools/compare.rb <the game's TestDriver/out> <save:troop:seed:name>...` plays the server's half
with the saves of `BATTLE_SAVES` (default `saves`, the same files the game got) and compares (`TRACE=1` holds the random draws against each other too).

## Security

A save from a player is untrusted, and Marshal can run code chosen by its sender. Two layers:

- **SaveCheck** (`lib/save_check.rb`) walks the save's bytes before Marshal reads them and
  refuses any class but the game's own (those defined after Ruby's own, as `SaveCheck.snapshot`
  notes) and Ruby's plain values. Classes of mods the server lacks become empty stand-ins, never
  inside one of Ruby's modules. 14 saves of the test installs passed in 0.07 to 0.47 s.
- **The sandbox** (`lib/sandbox.rb`, Linux as root): the game's data itself holds code (damage
  formulas, notes some plugins evaluate, event script commands), so each battle's child gets a
  network namespace of its own (only its own connection works), a chroot into the game folder,
  no file writes, limits on memory, files and processes, and runs as nobody. Its output reaches
  the server's log through a pipe, capped at 256 KB per child.

The game folder must not be writable by others than root (`chmod -R go-w`); the server warns
at startup when it is. Whatever the game or a mod writes (the temporary picture of a large
bitmap, errors.txt, the mods' logs) is discarded, so a battle never fails over a file.

`tools/security_test.rb <save>` tries both: saves naming Gem::Requirement, Set, Process::Tms,
new classes inside Kernel or Process, cut saves, non-Marshal bytes and 2000-deep nesting are
refused; inside the sandbox connecting anywhere, writing a file, reading outside the game
folder, starting a program and becoming root again all fail, while the maps still load.

## Not done yet

- Sending only the battle's part of a save instead of the whole file.
- Late-game battles are slow (up to 0.9 s per turn); worth profiling.
- MGQ Online's own battle rules (level sync, raid pools, squads) are not loaded, since they
  live in the client-only Multiplayer scripts.
- The sweeps' numbers above were measured before the define_method fix; late-game battles may
  run differently (and stronger) now.
