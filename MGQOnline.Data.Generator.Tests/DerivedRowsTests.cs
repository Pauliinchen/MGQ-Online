//----------------------------------------------------------------
//  DerivedRowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered the story replay's gate and the roots of a script
//                            - Covered the pairs the one-time repair of stuck saves completes
//                            - Covered the lists that give and the branches of each choice
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Data.Sqlite;
using MGQOnline.Game.Events;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers the rows the build derives once the lists are read, over a tiny game, read back from
/// the database it writes.
/// </summary>
public sealed class DerivedRowsTests
{
    /// <summary>
    /// Asserts that a switch named as scratch is scratch outside the story's band only, a variable
    /// named so is scratch, and the affection variables count one per actor.
    /// </summary>
    [Fact]
    public void SwitchesAndVariables_TakeTheirFlagsFromTheirNames()
    {
        TinyGame game = new TinyGame()
            .SwitchName(5, "汎用スイッチ")
            .SwitchName(7, "Door opened")
            .SwitchName(1005, "汎用")
            .VariableName(9, "一時変数")
            .VariableName(3003, "Something")
            .Named("Data/Actors.rvdata2", "RPG::Actor", "Luka", "Alice");

        using EventStore store = StoreOf(game);

        Assert.Equal((true, true, false), Flags(store.SwitchFlags(5)!.Value));
        Assert.Equal((true, false, false), Flags(store.SwitchFlags(7)!.Value));
        Assert.Equal((true, false, true), Flags(store.SwitchFlags(1005)!.Value));
        Assert.True(store.VariableFlags(9)!.Value.Scratch);
        Assert.Equal([true, false], new[] { 3002, 3003 }.Select(id => store.VariableFlags(id)!.Value.Affection));

        static (bool Named, bool Scratch, bool StoryBand) Flags(SwitchRow row) => (row.Named, row.Scratch, row.StoryBand);
    }

    /// <summary>
    /// Asserts that an item of the key item type is a key item, that the untranslated tags and the
    /// translation's tell the job or race an item unlocks, and that an enemy's note tells its level.
    /// </summary>
    [Fact]
    public void ItemsAndEnemies_TakeTheirFlagsFromTheirTexts()
    {
        TinyGame game = new TinyGame()
            .Entry("Data/Items.rvdata2", "RPG::Item", 1, ("name", "Seal"), ("itype_id", 2), ("description", "【貴重品】神の封印"))
            .Entry("Data/Items.rvdata2", "RPG::Item", 2, ("name", "Permit"), ("itype_id", 1), ("description", "【転職用】所持していれば「商人」に転職できる"))
            .Entry("Data/Items.rvdata2", "RPG::Item", 3, ("name", "Orb"), ("itype_id", 1), ("description", "［種族］"))
            .Entry("Data/Weapons.rvdata2", "RPG::Weapon", 1, ("name", "Badge"), ("description", "[Job] Allows access to the Merchant job."))
            .Entry("Data/Enemies.rvdata2", "RPG::Enemy", 1, ("name", "Slime"), ("note", "<逃走レベル 12>"))
            .Entry("Data/Enemies.rvdata2", "RPG::Enemy", 2, ("name", "Bat"), ("note", string.Empty));

        using EventStore store = StoreOf(game);

        Assert.Equal(
            [(true, UnlockClass.None), (false, UnlockClass.Job), (false, UnlockClass.Race)],
            new[] { 1, 2, 3 }.Select(id => store.Item(ItemKind.Item, id)!.Value).Select(item => (item.KeyItem, item.UnlockClass)));
        Assert.Equal(UnlockClass.Job, store.Item(ItemKind.Weapon, 1)!.Value.UnlockClass);
        Assert.Equal([12, 0], new[] { 1, 2 }.Select(id => store.Enemy(id)!.Value.Level));
    }

    /// <summary>
    /// Asserts that a chest is sorted as one in a new game with its letter, that a switch only
    /// chests turn on is a chest flag, which keeps the chest that turns it on a chest, and that a
    /// switch the story turns on too is none, whose chest moves the story on.
    /// </summary>
    [Fact]
    public void Chests_AreSortedAsInANewGameWithTheChestFlags()
    {
        TinyGame game = new TinyGame()
            .SwitchName(50, "Ruins opened")
            .Event(1, C(126, 5, 0, 0, 1), C(123, "A", 0))
            .Event(2, C(126, 6, 0, 0, 1), C(121, 40, 40, 0), C(123, "B", 0))
            .Event(3, C(126, 7, 0, 0, 1), C(121, 41, 41, 0), C(123, "A", 0))
            .Event(4, C(101, "", 0, 0, 2), C(121, 41, 41, 0), C(122, 50, 50, 0, 0, 1));

        using EventStore store = StoreOf(game);

        Assert.Equal([(1, "A"), (2, "B")], store.Chests(1).Select(chest => (chest.EventId, chest.Letter)));
        Assert.Equal([EventKind.Chest, EventKind.Chest, EventKind.Story], new[] { 1, 2, 3 }.Select(id => (EventKind)store.Page(1, id, 0)!.Value.KindNewGame!.Value));
        Assert.Equal([true, false], new[] { 40, 41 }.Select(id => store.SwitchFlags(id)!.Value.ChestFlag));
    }

    /// <summary>
    /// Asserts the common events' flags: the player's own, the battlefuck events from the count of
    /// a win through its callers to the scenes only they call, the Final Chapter's by name, id and
    /// route branch, and a fade-in.
    /// </summary>
    [Fact]
    public void CommonEvents_TakeTheirFlags()
    {
        TinyGame game = new TinyGame()
            .Common(2, C(121, 3, 3, 0))
            .Common(6999, C(117, 11), C(117, 12))
            .Common(10, C(117, 6999))
            .Common(11, C(121, 3, 3, 0))
            .Common(12, C(121, 3, 3, 0))
            .Event(1, C(117, 12))
            .Common(20, C(121, 3, 3, 0))
            .CommonName(20, "大いなる決断")
            .Common(21, C(111, 1, 1142, 0, 1, 1), C(412))
            .Common(22, C(222))
            .Common(9000, C(121, 3, 3, 0));

        using EventStore store = StoreOf(game);

        Assert.Equal([2], Ids(store, row => row.Own));
        Assert.Equal([10, 11, 6999], Ids(store, row => row.Battlefuck));
        Assert.Equal([20, 21, 9000], Ids(store, row => row.FinalChapter));
        Assert.Equal([22], Ids(store, row => row.FadesIn));
    }

    /// <summary>
    /// Asserts the pages' flags: a page of a switch the post-defeat processing writes shows only
    /// during a scene, a page of comments runs nothing, and fade-ins and encounter changes.
    /// </summary>
    [Fact]
    public void Pages_TakeTheirFlags()
    {
        TinyGame game = new TinyGame()
            .Common(3000, C(121, 31, 33, 1), C(117, 11))
            .Common(11, C(122, 902, 902, 0, 0, 1))
            .MapEvent(1, 1, 0, 0, new TinyPage([C(101, "", 0, 0, 2)], Switch1: 32))
            .Event(2, C(108, "A figure."))
            .Event(3, C(222))
            .Event(4, C(136, 1))
            .Event(5, C(136, 0));

        using EventStore store = StoreOf(game);
        PageRow[] pages = [.. Enumerable.Range(1, 5).Select(id => store.Page(1, id, 0)!.Value)];

        Assert.Equal([true, false, false, false, false], pages.Select(page => page.ScenePage));
        Assert.Equal([false, true, false, false, false], pages.Select(page => page.RunsNothing));
        Assert.Equal([false, false, true, false, false], pages.Select(page => page.HasFadeIn));
        Assert.Equal([null, null, null, true, false], pages.Select(page => page.SetsEncounters));
    }

    /// <summary>
    /// Asserts the views: a troop's battles on a page and in a common event, the map pages that
    /// reach a common event through another, and what the post-defeat processing writes.
    /// </summary>
    [Fact]
    public void Views_ListSitesCallersAndDefeatWrites()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(301, 0, 12, false, false))
            .Event(2, C(117, 7))
            .Event(3, C(117, 8))
            .Common(7, C(301, 0, 12, false, false), C(301, 1, 12, false, false))
            .Common(8, C(117, 7))
            .Common(3000, C(121, 31, 33, 1), C(117, 11))
            .Common(11, C(122, 902, 902, 0, 0, 1));

        using EventStore store = StoreOf(game);

        Assert.Equal([(1, (int?)null), (null, 7)], store.BattleSites(12).Select(site => (site.EventId, site.CommonId)));
        Assert.Equal([2, 3], store.SiteCallers(7).Select(caller => caller.EventId));
        Assert.Equal(
            [(11, (KeyKind?)KeyKind.Variable, (int?)902, (int?)902), (3000, KeyKind.Switch, 31, 33)],
            store.DefeatWrites().Select(row => (row.CommonId, row.Kind, row.FromId, row.ToId)));
    }

    /// <summary>
    /// Asserts that two troops fought on one page in branches of the two side switches are each
    /// other's alternatives, each with the side switch that picks the other.
    /// </summary>
    [Fact]
    public void Alternatives_PairTheSidesTroops()
    {
        TinyGame game = new TinyGame().Event(
            1,
            C(111, 0, 4, 0),
            At(301, 1, 0, 20, false, false),
            C(412),
            C(111, 0, 5, 0),
            At(301, 1, 0, 21, false, false),
            C(412),
            C(301, 0, 22, false, false));

        using EventStore store = StoreOf(game);

        Assert.Equal([(21, 5)], store.Alternatives(20).Select(other => (other.OtherTroopId, other.SideSwitch)));
        Assert.Equal([(20, 4)], store.Alternatives(21).Select(other => (other.OtherTroopId, other.SideSwitch)));
        Assert.Empty(store.Alternatives(22));
    }

    /// <summary>
    /// Asserts that a battle page of a cutscene map is entered from the field events whose
    /// transfers lead into its map, over another cutscene map too, each with the switch around its
    /// transfer, and from the first transfer into the map, a script's forced transfer among them.
    /// </summary>
    [Fact]
    public void SceneEntries_FollowTheTransfersIntoTheCutsceneMap()
    {
        TinyGame game = new TinyGame()
            .FolderMap(1001, "イベント")
            .FolderMap(1002, "Scene", 1001)
            .MapEvent(1002, 1, 0, 0, new TinyPage([C(301, 0, 40, false, false)]))
            .MapEvent(1001, 1, 0, 0, new TinyPage([C(201, 0, 2, 5, 6, 8)]))
            .MapEvent(1, 3, 7, 8, new TinyPage([C(111, 0, 60, 0), At(201, 1, 0, 1001, 3, 4, 2), C(412)]))
            .MapEvent(1, 4, 9, 10, new TinyPage([C(355, "forced_transfer(1002, 9, 9)")]));

        using EventStore store = StoreOf(game);

        Assert.Equal(
            [(1, 3, 7, 8, (int?)60, 1002, 9, 9, 0), (1, 4, 9, 10, null, 1002, 9, 9, 0)],
            store.SceneEntries(store.ListOf(1002, 1, 0)!.Value.ListId)
                .Select(entry => (entry.FieldMap, entry.FieldEvent, entry.X, entry.Y, entry.SideSwitch, entry.ToMap, entry.ToX, entry.ToY, entry.Direction)));
    }

    /// <summary>
    /// Asserts that the story replay's gate fails the build on a command code and a script root
    /// it does not class, naming where they stand, and leaves a troop's page alone.
    /// </summary>
    [Fact]
    public void ReplayGate_FailsTheBuildOnAnUnclassedCommandOrScriptRoot()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(126, 5, 0, 0, 1), C(355, "mystery_call(3)"))
            .Event(2, C(901));
        TinyGame troopOnly = new TinyGame().Troop(1, [1], C(901));

        InvalidDataException failure = Assert.Throws<InvalidDataException>(() => EventBuilder.Build(game.Files(), new BuildOptions()));

        Assert.Contains("command 901 in map:1:2:0", failure.Message, System.StringComparison.Ordinal);
        Assert.Contains("script root mystery_call in map:1:1:0", failure.Message, System.StringComparison.Ordinal);
        Assert.NotEmpty(EventBuilder.Build(troopOnly.Files(), new BuildOptions()).Lists);
    }

    /// <summary>
    /// Asserts that the gate fails on a closed command that writes a key the reviewed list does not
    /// mark as work: the transfer, which takes and clears v57.
    /// </summary>
    [Fact]
    public void ReplayGate_FailsOnAClosedCommandThatWritesAKeyThatIsNotWork()
    {
        BuiltGame game = EventBuilder.Read(new TinyGame().Event(1, C(201, 0, 2, 5, 6, 8)).Files(), new BuildOptions()).Game;

        Assert.Equal(["a closed command writes v57, which is no work key"], ReplayChannels.Problems(game, _ => false));
        Assert.Empty(ReplayChannels.Problems(game, key => key == "v57"));
    }

    /// <summary>
    /// Asserts the roots of a script: a global with how it is used, a constant with its member, a
    /// function and an instance variable, without local or loop variables, members of values,
    /// symbols, strings, regular expressions or comments.
    /// </summary>
    [Fact]
    public void ScriptRoots_AreWhatTheScriptReachesFirst()
    {
        string script = """
            actor = $game_actors[1]
            actor.change_class(5, :class)
            $game_variables[$game_variables[11]] = 3 # $game_party.lose_gold(9)
            SceneManager.call(Scene_Shop) if /a#b/i =~ v(2) / 2 && "$fake"
            [1, 2].each { |id| id.to_s }
            for i in [3] do i end
            @goods = []
            """;

        Assert.Equal(["$game_actors[]", "$game_variables[]=", "$game_variables[]", "SceneManager.call", "Scene_Shop", "v", "@goods="], ScriptRoots.Of(script));
    }

    /// <summary>
    /// Lists the common events of <see cref="CommonEvents_TakeTheirFlags"/> with a flag.
    /// </summary>
    /// <param name="store">The store.</param>
    /// <param name="flag">The flag.</param>
    /// <returns>Their ids.</returns>
    private static IEnumerable<int> Ids(EventStore store, System.Func<CommonEventRow, bool> flag) =>
        new[] { 2, 10, 11, 12, 20, 21, 22, 6999, 9000 }.Where(id => flag(store.Common(id)!.Value));

    /// <summary>
    /// Asserts that the repair's pairs are the switches a gift page surely turns on with its self
    /// switch: in the same block after it, and inside "if the switch is OFF" after it; a switch the
    /// game turns off elsewhere pairs only where that list resets the chest's map too.
    /// </summary>
    [Fact]
    public void RepairPairs_AreTheSwitchesAGiftPageSurelyTurnsOnWithItsSelfSwitch()
    {
        using EventStore store = StoreOf(new TinyGame()
            .MapEvent(1, 1, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 40, 40, 0)]))
            .MapEvent(1, 2, 0, 0, new TinyPage([C(123, "A", 0), C(126, 700, 0, 0, 1), C(111, 0, 41, 1), At(121, 1, 41, 41, 0), At(0, 1), C(412)]))
            .MapEvent(1, 3, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 45, 45, 0)]))
            .MapEvent(1, 4, 0, 0, new TinyPage([C(121, 45, 45, 1), C(355, "reset_selfswitch_map(1)")])));

        Assert.Equal([(1, "A", 40), (2, "A", 41), (3, "A", 45)], store.RepairPairs().Select(pair => (pair.EventId, pair.Letter, pair.SwitchId)));
    }

    /// <summary>
    /// Asserts that no pair is made where the save could hold the self switch on and the switch off
    /// in the plain game: the switch behind a variable's branch, the self switch set by another page
    /// too, the switch turned off without a reset of the chest's map, or a page that gives nothing.
    /// </summary>
    [Fact]
    public void RepairPairs_LeaveOutWhatThePlainGameMayLeaveApart()
    {
        using EventStore store = StoreOf(new TinyGame()
            .MapEvent(1, 3, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(111, 1, 1001, 0, 5, 1), At(121, 1, 42, 42, 0), At(0, 1), C(412), C(123, "A", 0)]))
            .MapEvent(1, 4, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 43, 43, 0)]), new TinyPage([C(123, "A", 0)], SelfSwitch: "B"))
            .MapEvent(1, 5, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 44, 44, 0)]))
            .MapEvent(1, 6, 0, 0, new TinyPage([C(121, 44, 44, 1)]))
            .MapEvent(1, 9, 0, 0, new TinyPage([C(123, "A", 0), C(121, 46, 46, 0)])));

        Assert.Empty(store.RepairPairs());
    }

    /// <summary>
    /// Asserts that a switch the game's scripts use as a switch makes no pair: by a constant, or in
    /// the awaken band of an actor that holds anything; while a number a script uses as another kind
    /// of id, or the awaken switch of a blank actor, still pairs.
    /// </summary>
    [Fact]
    public void RepairPairs_LeaveOutTheSwitchesTheScriptsUse()
    {
        const string Constants = "module NWConst\n  module Sw\n    AWAKEN_ID = 6000\n    WARP_BAN = 47\n  end\nend\n";
        const string Uses = "class Game_Actor\n  def awakened?\n    $game_switches[NWConst::Sw::AWAKEN_ID + id]\n  end\nend\n$game_switches[NWConst::Sw::WARP_BAN] = true\n$game_variables[48] = 1\n";
        using EventStore store = StoreOf(new TinyGame()
            .Scripts(Constants, Uses)
            .Holding("Data/Actors.rvdata2", "RPG::Actor", "note", string.Empty)
            .MapEvent(1, 1, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 6001, 6001, 0)]))
            .MapEvent(1, 2, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 6002, 6002, 0)]))
            .MapEvent(1, 3, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 47, 47, 0)]))
            .MapEvent(1, 4, 0, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0), C(121, 48, 48, 0)])));

        Assert.Equal([6002, 48], store.RepairPairs().Select(pair => pair.SwitchId));
    }

    /// <summary>
    /// Asserts that a page gives when it or a common event it calls adds to what a player holds, by
    /// a command or by a script's medal, and that a page that only takes gives nothing.
    /// </summary>
    [Fact]
    public void Gives_AreTheListsThatAddToWhatAPlayerHolds()
    {
        using EventStore store = StoreOf(new TinyGame()
            .Common(5, C(126, 7, 0, 0, 1))
            .MapEvent(1, 1, 0, 0, new TinyPage([C(126, 7, 1, 0, 1), C(125, 1, 0, 50), C(121, 40, 40, 0)]))
            .MapEvent(1, 2, 0, 0, new TinyPage([C(117, 5)]))
            .MapEvent(1, 3, 0, 0, new TinyPage([C(355, "gain_medal(3)")])));

        Assert.Equal([false, true, true], new[] { 1, 2, 3 }.Select(id => store.Gives(store.ListOf(1, id, 0)!.Value.ListId)));
        Assert.True(store.Gives(store.CommonList(5)!.Value.ListId));
    }

    /// <summary>
    /// Asserts that each answer of a choice names the commands it runs and what they do to what a
    /// player holds, through the common events it calls too, the cancel branch as answer 4.
    /// </summary>
    [Fact]
    public void ChoiceBranches_NameTheCommandsOfEachAnswerAndWhatTheyDoToHoldings()
    {
        using EventStore store = StoreOf(new TinyGame()
            .Common(5, C(125, 1, 0, 50))
            .MapEvent(1, 1, 0, 0, new TinyPage([
                C(102, "Yes", 2), C(402, 0, "Yes"), At(121, 1, 10, 10, 0), At(117, 1, 5), At(0, 1),
                C(402, 1, "No"), At(121, 1, 11, 11, 0), At(126, 1, 7, 0, 0, 1), At(0, 1),
                C(403, 6), At(0, 1), C(404)])));

        int list = store.ListOf(1, 1, 0)!.Value.ListId;

        Assert.Equal(
            [(0, 2, 4, "ce5"), (1, 6, 8, "126:7:0:0:1"), (4, 10, 10, string.Empty)],
            store.ChoiceBranches(list, 0).Select(branch => (branch.Branch, branch.FirstIdx, branch.LastIdx, branch.Holdings)));
    }

    /// <summary>
    /// Builds a tiny game's database in memory.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The store over it.</returns>
    private static EventStore StoreOf(TinyGame game)
    {
        SqliteConnection connection = EventDatabaseWriter.Build(EventBuilder.Build(game.Files(), new BuildOptions()));
        EventStore store = EventStore.Over(connection);
        Assert.Null(store.Problem);
        return store;
    }
}
