//----------------------------------------------------------------
//  ScreenTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that the World and Game data panels open list box lines of their own
//                            - Covered the list's search and filters together, in the list's order
//                            - Checked that a refresh that brings nothing new tells the scripts nothing
//      Paulinchen  2026-11-08: Checked a world's mods by its creator's versions too
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Covered a world on this PC that names no directory id, and finding one world of the list
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//      Paulinchen  2026-10-23: Marked a favourite through the lists, whose topic the DLL dropped
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Worlds;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Tests.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the world screen's model as the scripts call it: the list joined from the directory and
/// this PC, a world's details, choices and list box lines, and the refresh while the screen is open.
/// </summary>
public sealed class ScreenTopicsTests : IDisposable
{
    /// <summary>
    /// A world code the tests enter.
    /// </summary>
    private const string Code = "mgqmp2;abcdefghjkmnpqrs;r1;8";

    /// <summary>
    /// The player's id.
    /// </summary>
    private const string Me = "me";

    /// <summary>
    /// The mod folder under test, which holds Player.ini and the worlds.
    /// </summary>
    private readonly TempFolder _mod = new();

    /// <summary>
    /// The game folder under test.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The directory's worlds the list hands out.
    /// </summary>
    private readonly List<ListedWorld> _listed = [];

    /// <summary>
    /// How often the list was fetched, with the hidden worlds asked for each time.
    /// </summary>
    private readonly List<IReadOnlyList<string>> _refreshes = [];

    /// <summary>
    /// How the directory's action stands.
    /// </summary>
    private string _action = "idle";

    /// <summary>
    /// The directory list's revision.
    /// </summary>
    private long _revision;

    /// <summary>
    /// How the directory's list stands.
    /// </summary>
    private string _state = "ready";

    /// <summary>
    /// The model under test.
    /// </summary>
    private WorldScreen? _screen;

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// The hidden worlds added and the favourites under test.
    /// </summary>
    private readonly WorldLists _lists;

    /// <summary>
    /// Creates the topics over empty folders and a directory the test fills.
    /// </summary>
    public ScreenTopicsTests()
    {
        PlayerIni player = new(Path.Combine(_mod.Path, PlayerIni.FileName));
        _lists = new WorldLists(player, _mod.Path, () => 0);
        _topics = new TopicCaller(context =>
        {
            WorldServices services = new(player, new WorldChanges(context), () => WorldDirectory.Current, () => PatchScripts.List(_game.Path), new DirectoryTickets(() => "idle", () => { }));
            LocalWorldTopics.Kept local = LocalWorldTopics.Register(context, services, new LocalWorlds(Path.Combine(_mod.Path, "Worlds"), "Worlds", () => 1_000), _lists);
            _screen = new WorldScreen(new WorldScreenSources(
                () => (_state, null, false, _listed),
                id => ("ready", _listed.FirstOrDefault(world => world.Id == id)),
                added => _refreshes.Add(added),
                () => _action,
                local,
                () => Me,
                () => [],
                (_, _, _) => [],
                (_, _, _, _) => "Mod settings: the creator's own",
                _ => []));
            ScreenTopics.Register(context, _screen, services.Changes, () => _revision);
        });
    }

    /// <summary>
    /// Asserts that the list joins the directory's worlds with the worlds on this PC: a favourite
    /// first, a world the directory no longer has last and pale, each with its row's texts.
    /// </summary>
    [Fact]
    public void List_JoinsTheDirectoryWithTheWorldsOnThisPc()
    {
        _listed.Add(World("a", "Alpha", Me));
        _listed.Add(World("b", "Beta", "c"));
        _topics.Call(LocalWorldTopics.Found, new RubyHash { { "code", Code }, { "name", "Mine" }, { "world", "gone1" }, { "type", "raid" } });
        _lists.Favour("b", null);

        RubyHash list = _topics.Call(ScreenTopics.List)!.AsHash();
        RubyArray rows = list["rows"].AsArray();

        Assert.Equal(["b", "a", "gone1"], rows.Select(row => row.AsHash()["key"].AsText()));
        Assert.Equal(["* Beta", "Alpha", "Mine"], rows.Select(row => row.AsHash()["text"].AsText()));
        Assert.Equal(["favourite", "normal", "raid"], rows.Select(row => row.AsHash()["color"].AsText()));
        Assert.Equal([false, false, true], rows.Select(row => row.AsHash()["dim"].AsBool()));
        Assert.Equal("1/4", rows[0].AsHash()["count"].AsText());
        Assert.True(rows[2].AsHash()["count"].IsNil);
        Assert.Equal("Mine", rows[2].AsHash()["local"].AsHash()["name"].AsText());
        Assert.Equal([["c", true, "Cora"]], rows[0].AsHash()["listed"].AsHash()["members"].AsArray().Select(member => member.AsArray().Select(part => part is RubyBool flag ? (object)flag.Flag : part.AsText()).ToArray()));
    }

    /// <summary>
    /// Asserts that the search, the type and the players online filter the list together, any case
    /// and in the list's order, a favourite first, and that a list they empty says so.
    /// </summary>
    [Fact]
    public void List_FiltersBySearchTypeAndPlayersOnline()
    {
        _listed.Add(World("a", "Sunset Keep", "c") with { Type = WorldType.Raid });
        _listed.Add(World("b", "Sunrise", "c"));
        _listed.Add(World("c", "Sunken Raid", "c") with { Type = WorldType.Raid, Online = 0 });
        _listed.Add(World("d", "Moonfall", "c") with { Type = WorldType.Raid });
        _listed.Add(World("e", "Old Sun", "c") with { Type = WorldType.Raid });
        _lists.Favour("e", null);

        RubyHash all = _topics.Call(ScreenTopics.List)!.AsHash();
        RubyHash raid = _topics.Call(ScreenTopics.List, new RubyHash { { "search", " SUN " }, { "type", "raid" }, { "online", true } })!.AsHash();
        RubyHash none = _topics.Call(ScreenTopics.List, new RubyHash { { "search", "moon" }, { "type", "classic" }, { "online", false } })!.AsHash();

        static string[] Shown(RubyHash list) => [.. list["rows"].AsArray().Select(row => row.AsHash()).Where(row => row["shown"].AsBool()).Select(row => row["key"].AsText())];
        Assert.Equal(5, Shown(all).Length);
        Assert.Equal(["e", "a"], Shown(raid));
        Assert.Equal(5, raid["rows"].AsArray().Count);
        Assert.Equal((true, true), (all["empty"].IsNil, raid["empty"].IsNil));
        Assert.Equal([], Shown(none));
        Assert.Equal(WorldScreenModel.NoMatch, none["empty"].AsText());
    }

    /// <summary>
    /// Asserts that a world's details, choices and list box lines come from the model by its row's
    /// key, and a key the list lacks answers nothing.
    /// </summary>
    [Fact]
    public void DetailsActionsAndBox_AnswerByTheRowsKey()
    {
        _listed.Add(World("a", "Alpha", Me));

        RubyHash details = _topics.Call(ScreenTopics.Details, "a")!.AsHash();
        RubyArray actions = _topics.Call(ScreenTopics.Actions, "a")!.AsArray();
        RubyArray players = _topics.Call(ScreenTopics.Box, new RubyHash { { "key", "a" }, { "kind", "players" } })!.AsArray();
        RubyArray world = _topics.Call(ScreenTopics.Box, new RubyHash { { "key", "a" }, { "kind", "world" } })!.AsArray();
        RubyArray data = _topics.Call(ScreenTopics.Box, new RubyHash { { "key", "a" }, { "kind", "data" } })!.AsArray();

        Assert.Equal("Alpha", details["title"].AsText());
        Assert.Equal("You", details["panels"].AsArray()[0].AsHash()["rows"].AsArray()[0].AsArray()[0].AsHash()["text"].AsText());
        Assert.Contains("edit_world", actions.Select(action => action.AsArray()[1].AsText()));
        Assert.Equal("Online (1)", players[0].AsArray()[1].AsText());
        Assert.Equal(["world", "data", "players"], details["panels"].AsArray().Select(panel => panel.AsHash()["target"].AsText()));
        Assert.Equal("Creator: You", world[0].AsArray()[1].AsText());
        Assert.DoesNotContain("Mod settings: the creator's own", world.Select(line => line.AsArray()[1].AsText()));
        Assert.Equal(["Mods (0)", "Settings", "Mod settings: the creator's own", "Other mods: allowed"], data.Select(line => line.AsArray()[1].AsText()));
        Assert.Null(_topics.Call(ScreenTopics.Details, "nowhere"));
    }

    /// <summary>
    /// Asserts that a world on this PC whose world.ini names no directory id is listed by its folder,
    /// without a description or list box lines, and that one world of the list is found by its id.
    /// </summary>
    [Fact]
    public void FolderWithoutDirectoryId_IsListedByItsFolder()
    {
        _listed.Add(World("a", "Alpha", Me));
        string folder = _topics.Call(LocalWorldTopics.Found, new RubyHash { { "code", Code }, { "name", "Kept" } })!.AsHash()["id"].AsText();

        RubyHash row = _topics.Call(ScreenTopics.List)!.AsHash()["rows"].AsArray().Select(each => each.AsHash()).Single(each => each["name"].AsText() == "Kept");
        Assert.Equal(("folder:" + folder, true, true), (row["key"].AsText(), row["id"].IsNil, row["gone"].AsBool()));
        Assert.True(_topics.Call(ScreenTopics.Details, row["key"])!.AsHash()["description"].IsNil);
        Assert.Null(_topics.Call(ScreenTopics.Box, new RubyHash { { "key", row["key"] }, { "kind", "mods" } }));
        Assert.Equal("Alpha", _topics.Call(ScreenTopics.World, "a")!.AsHash()["listed"].AsHash()["name"].AsText());
        Assert.True(_topics.Call(ScreenTopics.World, "nowhere")!.AsHash()["listed"].IsNil);
    }

    /// <summary>
    /// Asserts that an open screen fetches the list at once and every ten seconds, never while a
    /// directory action runs, and a closed one never.
    /// </summary>
    [Fact]
    public void Tick_RefreshesOnlyWhileOpenAndIdle()
    {
        WorldScreen screen = _screen!;
        screen.Open(100);
        screen.Tick(100 + WorldScreen.RefreshFrames - 1, 0);
        _action = "busy";
        screen.Tick(100 + WorldScreen.RefreshFrames, 0);
        _action = "idle";
        screen.Tick(100 + WorldScreen.RefreshFrames + 1, 0);
        screen.Close();
        screen.Tick(100 + (WorldScreen.RefreshFrames * 3), 0);

        Assert.Equal(2, _refreshes.Count);
    }

    /// <summary>
    /// Asserts that a refresh whose list shows the same tells the scripts nothing, also while it
    /// runs, and one that changed what a world shows tells them once.
    /// </summary>
    [Fact]
    public void Tick_TellsTheScriptsOnlyOfAListThatChanged()
    {
        WorldScreen screen = _screen!;
        _listed.Add(World("a", "Alpha", "c"));
        screen.Open(0);
        screen.Tick(1, ++_revision);
        long opened = screen.Revision;

        _state = "loading";
        screen.Tick(2, ++_revision);
        _state = "ready";
        _listed[0] = World("a", "Alpha", "c");
        screen.Tick(3, ++_revision);
        long unchanged = screen.Revision;
        _listed[0] = World("a", "Alpha", "c") with { Online = 2 };
        screen.Tick(4, ++_revision);

        Assert.Equal((opened, opened + 1), (unchanged, screen.Revision));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _mod.Dispose();
        _game.Dispose();
    }

    /// <summary>
    /// Makes a Classic world of the directory with its creator online.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <param name="name">Its name.</param>
    /// <param name="creator">Its creator's id.</param>
    /// <returns>The world.</returns>
    private static ListedWorld World(string id, string name, string creator) =>
        new(id, name, 4, creator, "Cora", 1, 0, "none", false, false, false, false, new WorldAbout("", "", "", false), [new ListedMember(creator, "Cora", true)], WorldType.Classic, CompanionSharing.Off);
}
