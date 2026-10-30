//----------------------------------------------------------------
//  LocalWorldTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//                            - Left the Mod Framework's loader out of the picker
//      Paulinchen  2026-10-23: Added and removed hidden worlds through the lists, whose topics the DLL dropped
//                            - Left the entries to the world screen's tests and read each mod's label and colour in the picker
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of the worlds on this PC, the player's lists of worlds and the mod picker, as
/// the scripts call them.
/// </summary>
public sealed class LocalWorldTopicsTests : IDisposable
{
    /// <summary>
    /// A world code the tests enter.
    /// </summary>
    private const string Code = "mgqmp2;abcdefghjkmnpqrs;r1;8";

    /// <summary>
    /// The mod folder under test, which holds Player.ini, the files of earlier versions and the worlds.
    /// </summary>
    private readonly TempFolder _mod = new();

    /// <summary>
    /// The game folder under test, whose Patch the mod picker lists.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// The hidden worlds added and the favourites under test.
    /// </summary>
    private readonly WorldLists _lists;

    /// <summary>
    /// Creates the topics over empty folders.
    /// </summary>
    public LocalWorldTopicsTests()
    {
        PlayerIni player = new(Path.Combine(_mod.Path, PlayerIni.FileName));
        _lists = new WorldLists(player, _mod.Path, () => 0);
        _topics = new TopicCaller(context =>
        {
            WorldServices services = new(player, new WorldChanges(context), () => WorldDirectory.Current, () => PatchScripts.List(_game.Path), new DirectoryTickets(() => "idle", () => { }));
            LocalWorldTopics.Register(context, services, new LocalWorlds(Path.Combine(_mod.Path, "Worlds"), "Worlds", () => 1_000), _lists);
            ModPickTopics.Register(context, services.Scripts);
        });
    }

    /// <summary>
    /// Asserts that the hidden worlds added keep the newest 50 and the old files move into Player.ini once.
    /// </summary>
    [Fact]
    public void Added_KeepsTheNewestAndTakesTheOldFiles()
    {
        File.WriteAllText(Path.Combine(_mod.Path, "Added.ini"), "old=1\n");
        foreach (int id in Enumerable.Range(1, WorldLists.MaxAdded))
        {
            _lists.Add($"w{id}");
        }

        RubyArray added = _topics.Call(LocalWorldTopics.Added)!.AsArray();
        Assert.Equal(WorldLists.MaxAdded, added.Count);
        Assert.Equal("w1", added[0].AsText());
        Assert.False(File.Exists(Path.Combine(_mod.Path, "Added.ini")));

        Assert.True(_lists.Remove("w1"));
        Assert.Equal("w2", _topics.Call(LocalWorldTopics.Added)!.AsArray()[0].AsText());
    }

    /// <summary>
    /// Asserts that an invite into the world open already is not kept, and another is taken once.
    /// </summary>
    [Fact]
    public void Invite_KeepsAnInviteIntoAnotherWorldOnce()
    {
        RubyHash taken = _topics.Call(LocalWorldTopics.Invite, new RubyHash { { "code", Code }, { "open", RubyNil.Value } })!.AsHash();
        Assert.True(taken["taken"].AsBool());
        Assert.False(_topics.Call(LocalWorldTopics.Invite, new RubyHash { { "code", Code }, { "open", taken["world"] } })!.AsHash()["taken"].AsBool());
        Assert.Null(_topics.Call(LocalWorldTopics.Invite, new RubyHash { { "code", "no code" }, { "open", RubyNil.Value } }));

        Assert.Equal(new RubyArray([taken["world"], Code]), _topics.Call(LocalWorldTopics.InviteTake));
        Assert.Null(_topics.Call(LocalWorldTopics.InviteTake));
    }

    /// <summary>
    /// Asserts that the game data compares only once this game's fingerprint is known.
    /// </summary>
    [Fact]
    public void DataDiffering_ComparesWithTheFingerprintHanded()
    {
        string mine = "1:" + string.Join(".", Enumerable.Range(1, 11).Select(part => part.ToString("x8", System.Globalization.CultureInfo.InvariantCulture)));
        string theirs = mine.Replace("00000003", "00000000", StringComparison.Ordinal);
        Assert.Null(_topics.Call(LocalWorldTopics.DataDiffering, theirs));

        _topics.Call(LocalWorldTopics.GameData, mine);
        Assert.Equal(new RubyArray(["skills"]), _topics.Call(LocalWorldTopics.DataDiffering, theirs));
    }

    /// <summary>
    /// Asserts that the picker lists the scripts in Patch without those every player has, and changes.
    /// </summary>
    [Fact]
    public void ModPick_ListsThePatchScriptsAndChanges()
    {
        Directory.CreateDirectory(Path.Combine(_game.Path, "Patch"));
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"), "");
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "0_ModConfigRemake.rb"), "");
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "!Mod_Framework.rb"), "");

        RubyHash opened = _topics.Call(ModPickTopics.Open, new RubyHash { { "text", "!Level Cap" } })!.AsHash();
        Assert.Equal(new RubyArray([new RubyArray(["Level_Cap", "required", true, "required", "bad"])]), opened["entries"]);

        RubyHash acted = _topics.Call(ModPickTopics.Act, new RubyHash { { "do", "add" }, { "name", "Other" } })!.AsHash();
        Assert.True(acted["answer"].IsNil);
        Assert.Equal("!Level_Cap; Other", acted["pick"].AsHash()["text"].AsText());
        Assert.Equal("bad_request", _topics.Refusal(ModPickTopics.Act, new RubyHash { { "do", "toggle" }, { "index", 9 } }));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _mod.Dispose();
        _game.Dispose();
    }
}
