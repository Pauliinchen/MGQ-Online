//----------------------------------------------------------------
//  EventBuilderTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Expected the fingerprint of format 2, which counts entries by what they hold and the two skills the game appends
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers <see cref="EventBuilder"/> over a tiny game, read back from the database it writes.
/// </summary>
public sealed class EventBuilderTests
{
    /// <summary>
    /// Asserts that a common event's list starts with exactly one mark carrying the id its object
    /// holds, however many marks the file had, and counts its commands as the game runs them.
    /// </summary>
    [Fact]
    public void CommonEvent_StartsWithExactlyOneMark()
    {
        TinyGame game = new TinyGame()
            .Common(1, C(401, "Hello."))
            .Common(2, C(999, 2), C(121, 3, 3, 0))
            .Common(3, C(999, 1), C(999, 2), C(999, 3), C(117, 1))
            .Common(4, C(121, 3, 3, 0))
            .CommonOwnId(4, 0);

        using EventStore store = StoreOf(game);

        foreach ((int id, int marks, int mark) in new[] { (1, 0, 1), (2, 1, 2), (3, 3, 3), (4, 0, 0) })
        {
            ListRow list = store.CommonList(id)!.Value;
            IReadOnlyList<CommandRow> commands = store.Commands(list.ListId);
            Assert.Equal((999, (long)mark, 0), (commands[0].Code, commands[0].P0, commands[0].Idx));
            Assert.Single(commands, command => command.Code == 999);
            Assert.Equal(3, list.CountAll);
            Assert.Equal(marks, store.Common(id)!.Value.LeadingMarks);
        }
    }

    /// <summary>
    /// Asserts that two pages that differ only in their text lines share a shape and differ in
    /// count, that a branch on another switch changes the shape, and that kept commands count
    /// their place among the kept apart from their place in the list.
    /// </summary>
    [Fact]
    public void Shape_LeavesTextOutButNotABranchSwitch()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(101, "Actor1", 0, 0, 2), C(401, "Hello."), C(111, 0, 5, 0), At(121, 1, 3, 3, 0), C(412))
            .Event(2, C(101, "Actor1", 0, 0, 2), C(401, "Good"), C(401, "day."), C(111, 0, 5, 0), At(121, 1, 3, 3, 0), C(412))
            .Event(3, C(101, "Actor1", 0, 0, 2), C(401, "Hello."), C(111, 0, 6, 0), At(121, 1, 3, 3, 0), C(412));

        using EventStore store = StoreOf(game);
        ListRow first = store.ListOf(1, 1, 0)!.Value;
        ListRow split = store.ListOf(1, 2, 0)!.Value;
        ListRow other = store.ListOf(1, 3, 0)!.Value;

        Assert.Equal(first.Shape, split.Shape);
        Assert.Equal((6, 7), (first.CountAll, split.CountAll));
        Assert.NotEqual(first.Shape, other.Shape);
        CommandRow branch = store.Commands(split.ListId).Single(command => command.Code == 111);
        Assert.Equal((1, 3), (branch.Ord, branch.Idx));
    }

    /// <summary>
    /// Asserts that a jump names the ord of its label, and a jump to no label -1.
    /// </summary>
    [Fact]
    public void Jump_NamesItsLabelsOrd()
    {
        TinyGame game = new TinyGame().Event(1, C(401, "Before."), C(118, "Top"), C(401, "Again."), C(119, "Top"), C(119, "Nowhere"));

        using EventStore store = StoreOf(game);
        IReadOnlyList<CommandRow> commands = store.Commands(store.ListOf(1, 1, 0)!.Value.ListId);

        Assert.Equal([(118, 1L), (119, 0L), (119, -1L)], commands.Select(command => (command.Code, command.P0)));
    }

    /// <summary>
    /// Asserts that each kind of script keeps the kind the sorter tells it by, a choice its variable.
    /// </summary>
    [Fact]
    public void Script_KeepsItsKind()
    {
        TinyGame game = new TinyGame().Event(
            1,
            C(355, "present_start"),
            C(355, "forced_transfer(1, 2, 3)"),
            C(355, "unlimited_choices(42, [\"Yes\", \"No\"])"),
            C(355, "call_novel_scene(3)"),
            C(355, "p 1"));

        using EventStore store = StoreOf(game);
        IReadOnlyList<CommandRow> commands = store.Commands(store.ListOf(1, 1, 0)!.Value.ListId);

        Assert.Equal([(1, 0L), (2, 0L), (3, 42L), (4, 0L), (5, 0L)], commands.Select(command => (command.TextKind, command.P0)));
    }

    /// <summary>
    /// Asserts that a script that adds to a variable reads it once and writes it once, by script,
    /// and that a continuation line's write belongs to its script command.
    /// </summary>
    [Fact]
    public void Script_ReadsAndWritesWhatItAssigns()
    {
        TinyGame game = new TinyGame().Event(1, C(355, "$game_variables[5] += 1"), C(655, "$game_switches[7] = true"));

        using EventStore store = StoreOf(game);
        ListRowSet rows = store.RowsOf(store.ListOf(1, 1, 0)!.Value.ListId);

        Assert.Equal([new ListReadRow(rows.Reads[0].ListId, KeyKind.Switch, 7, ReadSources.Script), new ListReadRow(rows.Reads[0].ListId, KeyKind.Variable, 5, ReadSources.Script)], rows.Reads);
        Assert.Equal([(0, 0, KeyKind.Switch, 7, true), (0, 0, KeyKind.Variable, 5, true)], rows.Writes.Select(write => (write.Ord, write.Idx, write.Kind, write.FromId, write.ByScript)));
    }

    /// <summary>
    /// Asserts that Control Switches to on turns its range on and to off does not.
    /// </summary>
    [Fact]
    public void ControlSwitches_TurnsOnOnlyToOn()
    {
        TinyGame game = new TinyGame().Event(1, C(121, 3, 4, 0), C(121, 6, 6, 1));

        using EventStore store = StoreOf(game);
        ListRowSet rows = store.RowsOf(store.ListOf(1, 1, 0)!.Value.ListId);

        Assert.Equal([(3, 4, true), (6, 6, false)], rows.Writes.Select(write => (write.FromId, write.ToId, write.TurnsOn)));
    }

    /// <summary>
    /// Asserts that Control Variables keeps the value it sets only when it sets a constant.
    /// </summary>
    [Fact]
    public void ControlVariables_KeepsOnlyAConstantSet()
    {
        TinyGame game = new TinyGame().Event(1, C(122, 1001, 1001, 0, 0, 34), C(122, 5, 5, 1, 0, 2), C(122, 6, 6, 0, 1, 7));

        using EventStore store = StoreOf(game);
        ListRowSet rows = store.RowsOf(store.ListOf(1, 1, 0)!.Value.ListId);

        Assert.Equal([(1001, (int?)34), (5, null), (6, null)], rows.Writes.Select(write => (write.FromId, write.Value)));
    }

    /// <summary>
    /// Asserts that a battle in a branch on side switch 4 gets that side and its preamble, and that
    /// a battle against the troop a variable names counts on after it without a side.
    /// </summary>
    [Fact]
    public void Battle_GetsItsSideAndPreamble()
    {
        TinyGame game = new TinyGame().Event(
            1,
            C(111, 0, 4, 0),
            At(132, 1),
            At(121, 1, 22, 22, 0),
            At(301, 1, 0, 12, true, false),
            C(412),
            C(301, 1, 30, false, true));

        using EventStore store = StoreOf(game);
        IReadOnlyList<ListBattleRow> battles = store.RowsOf(store.ListOf(1, 1, 0)!.Value.ListId).Battles;

        Assert.Equal(
            [(0, 12, false, true, false, 1, 1, (int?)4), (1, 30, true, false, true, 0, 5, null)],
            battles.Select(battle => (battle.BattleNo, battle.TroopId, battle.ByVariable, battle.CanEscape, battle.CanLose, battle.Indent, battle.PreambleIdx, battle.SideSwitch)));
    }

    /// <summary>
    /// Asserts that a map page's transfer lands in its map's folder, while a common event's keeps
    /// the number, which the map that runs it resolves.
    /// </summary>
    [Fact]
    public void Transfer_LandsInTheFolderOfItsMapPage()
    {
        TinyGame game = new TinyGame()
            .FolderMap(1001, "Field2")
            .MapEvent(1001, 1, 0, 0, new TinyPage([C(201, 0, 5, 3, 4, 2)]))
            .Common(1, C(201, 0, 5, 6, 7, 0));

        using EventStore store = StoreOf(game);

        Assert.Equal([store.ListOf(1001, 1, 0)!.Value.ListId], store.TransfersInto(1005).Select(transfer => transfer.ListId));
        Assert.Equal([store.CommonList(1)!.Value.ListId], store.TransfersInto(5).Select(transfer => transfer.ListId));
    }

    /// <summary>
    /// Asserts that a troop keeps its enemies and its page's list, and that the maps under a root
    /// the untranslated game names イベント are cutscene maps.
    /// </summary>
    [Fact]
    public void Structure_KeepsTroopsAndCutsceneMaps()
    {
        TinyGame game = new TinyGame()
            .Troop(3, [10, 11], C(121, 2, 2, 0))
            .FolderMap(1001, "イベント")
            .FolderMap(1002, "Scene", 1001)
            .FolderMap(1003, "Field2");

        EventRows rows = EventBuilder.Build(game.Files(), new BuildOptions());
        using EventStore store = StoreOf(rows);

        Assert.Equal([10, 11], store.TroopMembers(3).Select(member => member.EnemyId));
        Assert.Equal(1, store.TroopPage(3, 0)!.Value.CountKept);
        Assert.Equal(4, store.Meta!.Counts["troops"]);
        Assert.Equal([(1, false), (1001, true), (1002, true), (1003, false)], rows.Maps.Select(map => (map.Id, map.Cutscene)));
    }

    /// <summary>
    /// Asserts that the fingerprint is the one world.rbx's rule writes for the tiny game, its golden
    /// string computed once with Ruby's Zlib.crc32 over the ids that exist of each part: an entry
    /// holding a note, features or effects whatever its name, and the two skills the game appends.
    /// </summary>
    [Fact]
    public void Fingerprint_MatchesTheScriptsRule()
    {
        const string golden = "2:5c095c0d.00000000.11894deb.00000000.00000000.00000000.00000000.00000000.83dcefb7.5c095c0d.98b1fb33";
        TinyGame game = new TinyGame()
            .Holding("Data/Actors.rvdata2", "RPG::Actor", "note", string.Empty, "features")
            .Holding("Data/Skills.rvdata2", "RPG::Skill", "effects")
            .Troop(1, [5])
            .Troop(2, [])
            .Common(1, C(121, 1, 1, 0))
            .Common(3)
            .FolderMap(1001, "イベント")
            .Files();

        Assert.Equal(golden, GameFingerprint.Text(EventBuilder.Fingerprint(game)));
        Assert.Equal(golden, EventBuilder.Build(game, new BuildOptions()).Build.Fingerprint);
    }

    /// <summary>
    /// Asserts that two builds of the same game write the same bytes.
    /// </summary>
    [Fact]
    public void Build_WritesTheSameBytesTwice()
    {
        string folder = Path.Combine(Path.GetTempPath(), $"mgq-generator-{Guid.NewGuid():N}");
        try
        {
            byte[][] builds = new byte[2][];
            for (int build = 0; build < builds.Length; build++)
            {
                TinyGame game = new TinyGame().Event(1, C(355, "$game_variables[5] += 1"), C(301, 0, 12, true, false)).Common(2, C(117, 2)).Troop(1, [5]);
                string path = Path.Combine(folder, $"events{build}.db");
                EventDatabaseWriter.Write(EventBuilder.Build(game.Files(), new BuildOptions()), path);
                builds[build] = File.ReadAllBytes(path);
            }

            Assert.Equal(builds[0], builds[1]);
        }
        finally
        {
            Directory.Delete(folder, true);
        }
    }

    /// <summary>
    /// Builds a tiny game's database in memory.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The store over it.</returns>
    private static EventStore StoreOf(TinyGame game) => StoreOf(EventBuilder.Build(game.Files(), new BuildOptions()));

    /// <summary>
    /// Writes rows to a database in memory.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>The store over it.</returns>
    private static EventStore StoreOf(EventRows rows)
    {
        EventStore store = EventStore.Over(EventDatabaseWriter.Build(rows));
        Assert.Null(store.Problem);
        return store;
    }
}
