//----------------------------------------------------------------
//  LocalWorldTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Named no other mod among the scripts every player has
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Covered a world found, changed and played, its latest save, and the picker's scripts in subfolders
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
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Tests.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

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
    /// The time a world is made or played at, in seconds since 1970, which a test moves on.
    /// </summary>
    private long _now = 1_000;

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
            LocalWorldTopics.Register(context, services, new LocalWorlds(Path.Combine(_mod.Path, "Worlds"), "Worlds", () => _now), _lists);
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
    /// Asserts that a world found keeps what the directory says of it, that a change and a play go
    /// into its world.ini, and that its latest save, an autosave too, is found by the files.
    /// </summary>
    [Fact]
    public void FoundChangedAndPlayed_KeepTheWorldOnThisPc()
    {
        RubyHash squad = new() { { "luka", true }, { "formation", 6 }, { "front", 2 }, { "raid_front", 3 } };
        RubyHash found = _topics.Call(LocalWorldTopics.Found, new RubyHash
        {
            { "code", Code }, { "name", "Raid Night" }, { "world", "r1" }, { "type", "raid" }, { "share", "story" }, { "difficulty", 1 }, { "squad", squad }, { "raid_bosses", RubyNil.Value },
        })!.AsHash();
        string id = found["id"].AsText();
        Assert.Equal(("Raid Night", "r1", "raid", "story", 1, 8), (found["name"].AsText(), found["world"].AsText(), found["type"].AsText(), found["share"].AsText(), found["difficulty"].AsInt(), found["seats"].AsInt()));
        Assert.Equal(squad, found["squad"]);
        Assert.True(found["played"].IsNil);
        Assert.Null(_topics.Call(LocalWorldTopics.Found, new RubyHash { { "code", "no code" }, { "name", "Raid Night" }, { "world", "r1" } }));
        Assert.Null(_topics.Call(LocalWorldTopics.LatestSave, id));

        _now = 2_000;
        RubyHash updated = _topics.Call(LocalWorldTopics.Update, new RubyHash { { "id", id }, { "difficulty", -2 }, { "raid_bosses", true }, { "played", true } })!.AsHash();
        Assert.True(updated["written"].AsBool());
        RubyHash listed = _topics.Call(LocalWorldTopics.Local)!.AsArray().Single().AsHash();
        Assert.Equal((-2, true, 2_000L, 1_000L), (listed["difficulty"].AsInt(), listed["raid_bosses"].AsBool(), listed["played"].AsLong(), listed["created"].AsLong()));
        Assert.Equal(squad, listed["squad"]);
        Assert.Null(_topics.Call(LocalWorldTopics.Update, new RubyHash { { "id", "nobody" }, { "played", true } }));

        string saves = Path.Combine(_mod.Path, "Worlds", id, LocalWorlds.SaveFolder);
        Directory.CreateDirectory(saves);
        File.WriteAllText(Path.Combine(saves, "Save01.rvdata2"), "");
        File.WriteAllText(Path.Combine(saves, "AutoSave02.rvdata2"), "");
        File.SetLastWriteTimeUtc(Path.Combine(saves, "Save01.rvdata2"), new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc));
        File.SetLastWriteTimeUtc(Path.Combine(saves, "AutoSave02.rvdata2"), new DateTime(2026, 1, 2, 0, 0, 0, DateTimeKind.Utc));
        Assert.Equal(new RubyArray(["02", $"Worlds/{id}/Save/AutoSave02.rvdata2"]), _topics.Call(LocalWorldTopics.LatestSave, id));
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
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "!Mod_Framework.rb"), "");

        RubyHash opened = _topics.Call(ModPickTopics.Open, new RubyHash { { "text", "!Level Cap" } })!.AsHash();
        Assert.Equal(new RubyArray([new RubyArray(["Level_Cap", "required", true, "required", "bad"])]), opened["entries"]);

        RubyHash acted = _topics.Call(ModPickTopics.Act, new RubyHash { { "do", "add" }, { "name", "Other" } })!.AsHash();
        Assert.True(acted["answer"].IsNil);
        Assert.Equal("!Level_Cap; Other", acted["pick"].AsHash()["text"].AsText());
        Assert.Equal("bad_request", _topics.Refusal(ModPickTopics.Act, new RubyHash { { "do", "toggle" }, { "index", 9 } }));
    }

    /// <summary>
    /// Asserts that the picker lists each script of Patch and its folders once by its key, sorted by
    /// name, without the scripts every player has.
    /// </summary>
    [Fact]
    public void ModPick_ListsEachScriptOnceWithoutTheSharedOnes()
    {
        string patch = Path.Combine(_game.Path, "Patch");
        Directory.CreateDirectory(Path.Combine(patch, "Sub"));
        foreach (string name in new[] { "Patch.rb", "Multiplayer.rb", "Zeta.rb", "Level_Cap.rb", "battle_dialogue.rb", Path.Combine("Sub", "Party Sheet.rb"), Path.Combine("Sub", "Level Cap.rb") })
        {
            File.WriteAllText(Path.Combine(patch, name), "");
        }

        RubyHash opened = _topics.Call(ModPickTopics.Open, new RubyHash { { "text", "" } })!.AsHash();
        Assert.Equal(["battle_dialogue", "Level_Cap", "Party Sheet", "Zeta"], opened["entries"].AsArray().Select(entry => entry.AsArray()[0].AsText()));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _mod.Dispose();
        _game.Dispose();
    }
}
