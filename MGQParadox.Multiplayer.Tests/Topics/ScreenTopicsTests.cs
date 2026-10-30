//----------------------------------------------------------------
//  ScreenTopicsTests.cs
//
//  Changelog:
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
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

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
                () => ("ready", null, false, _listed),
                id => ("ready", _listed.FirstOrDefault(world => world.Id == id)),
                added => _refreshes.Add(added),
                () => _action,
                local,
                () => Me,
                () => [],
                (_, _) => [],
                (_, _, _, _) => "Mod settings: the creator's own",
                _ => []));
            ScreenTopics.Register(context, _screen, services.Changes, () => 0);
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

        Assert.Equal("Alpha", details["title"].AsText());
        Assert.Equal("You", details["panels"].AsArray()[0].AsHash()["rows"].AsArray()[0].AsArray()[0].AsHash()["text"].AsText());
        Assert.Contains("edit_world", actions.Select(action => action.AsArray()[1].AsText()));
        Assert.Equal("Online (1)", players[0].AsArray()[1].AsText());
        Assert.Null(_topics.Call(ScreenTopics.Details, "nowhere"));
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
        screen.Tick(100 + WorldScreen.RefreshFrames - 1);
        _action = "busy";
        screen.Tick(100 + WorldScreen.RefreshFrames);
        _action = "idle";
        screen.Tick(100 + WorldScreen.RefreshFrames + 1);
        screen.Close();
        screen.Tick(100 + (WorldScreen.RefreshFrames * 3));

        Assert.Equal(2, _refreshes.Count);
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
