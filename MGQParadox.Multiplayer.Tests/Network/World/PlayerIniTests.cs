//----------------------------------------------------------------
//  PlayerIniTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers Player.ini as the DLL keeps it: the player key made once and never written over a file that cannot be read, the settings
/// changed in one write, the name the others see, and the topics the scripts reach it through.
/// </summary>
public sealed class PlayerIniTests : IDisposable
{
    /// <summary>
    /// A folder of the test's own.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"player ini test {Guid.NewGuid():N}");

    /// <summary>
    /// The Player.ini of the test.
    /// </summary>
    private readonly string _path;

    /// <summary>
    /// Who the worlds were told plays, in order.
    /// </summary>
    private readonly List<(string Key, string Name)> _shared = [];

    /// <summary>
    /// How many keys were made.
    /// </summary>
    private int _keysMade;

    /// <summary>
    /// Creates the test's folder.
    /// </summary>
    public PlayerIniTests()
    {
        Directory.CreateDirectory(_folder);
        _path = Path.Combine(_folder, PlayerIni.FileName);
    }

    /// <inheritdoc />
    public void Dispose() => Directory.Delete(_folder, true);

    /// <summary>
    /// Asserts that a missing Player.ini gets a key once, which the worlds are told with the name, and a file with a key keeps it.
    /// </summary>
    [Fact]
    public void Share_MakesTheKeyOnceAndTellsWhoPlays()
    {
        var player = Open();
        player.TellDiscordName("Disco");

        Assert.True(player.Share());
        Assert.True(player.Share());
        Assert.Equal(1, _keysMade);
        Assert.Equal("discord_name=Disco\nid=key1\n", File.ReadAllText(_path));
        Assert.Equal([("key1", "Disco"), ("key1", "Disco")], _shared);

        File.WriteAllText(_path, "id=abc\nname=Chosen\n");
        Assert.True(Open().Share());
        Assert.Equal(("abc", "Chosen"), _shared[^1]);
        Assert.Equal(1, _keysMade);
    }

    /// <summary>
    /// Asserts that a Player.ini that exists but cannot be read gets no new key and takes no setting, its notice comes once a write was
    /// turned down, and once it can be read again its key holds.
    /// </summary>
    [Fact]
    public void AFileThatCannotBeRead_IsNeverWritten()
    {
        Directory.CreateDirectory(_path);
        var player = Open();

        Assert.False(player.Readable);
        Assert.Null(player.Notice);
        Assert.False(player.Change([new("k", "v")]));
        Assert.False(player.Share());
        Assert.Equal(PlayerIni.UnreadableNotice, player.Notice);
        Assert.Equal(0, _keysMade);
        Assert.True(Directory.Exists(_path));
        Assert.False(File.Exists(_path + IniFile.TempSuffix));

        Directory.Delete(_path);
        File.WriteAllText(_path, "id=abc\n");
        Assert.True(player.Readable);
        Assert.Null(player.Notice);
        Assert.True(player.Change([new("k", "v")]));
        Assert.Equal("id=abc\nk=v\n", File.ReadAllText(_path));
    }

    /// <summary>
    /// Asserts that several settings change in one write, a setting kept moving to the end, and that the player key stays out of the
    /// settings the scripts see.
    /// </summary>
    [Fact]
    public void Change_KeepsAndRemovesInOneWrite()
    {
        File.WriteAllText(_path, "id=abc\nk=v\ngone=1\n");
        var player = Open();

        Assert.True(player.Change([new("z", "1"), new("k", "w"), new("gone", null)]));
        Assert.Equal("id=abc\nz=1\nk=w\n", File.ReadAllText(_path));
        Assert.Equal(["z", "k"], player.Settings.Select(pair => pair.Key));
    }

    /// <summary>
    /// Asserts the name the others see: the chosen one, cleaned, over Discord's; Discord's once the chosen one is cleared; and the last
    /// one Discord told while it tells none this session.
    /// </summary>
    [Fact]
    public void Name_PrefersTheChosenOneThenDiscordsThenTheOneKept()
    {
        var player = Open();
        player.TellDiscordName("Disco");

        player.ChooseName("  Lu\\ka\u0001 ");
        Assert.Equal("Luka", player.Name);

        player.ChooseName("   ");
        Assert.Equal("Disco", player.Name);
        Assert.DoesNotContain("name=", File.ReadAllText(_path).Split('\n').Select(line => line[..Math.Min(5, line.Length)]));

        Assert.Equal("Disco", Open().Name);
        Assert.Equal(new string('ä', 32), PlayerIni.Cleaned(new string('ä', 40), "A friend"));
        Assert.Equal("A friend", PlayerIni.Cleaned("\\\t", "A friend"));
    }

    /// <summary>
    /// Asserts that the topics answer the settings as they stand and refuse a change of the player key.
    /// </summary>
    [Fact]
    public void Topics_AnswerTheSettingsAndKeepTheKeyToTheDll()
    {
        File.WriteAllText(_path, "id=abc\nname=X\n");
        var context = new BridgeContext(1, new NoLog());
        SettingsTopics.Register(context, Open());

        var changed = Call(context, SettingsTopics.ChangeTopic, new RubyHash { { "k", "v" }, { "name", RubyNil.Value } });
        var refused = Call(context, SettingsTopics.ChangeTopic, new RubyHash { { "id", "evil" } });

        Assert.Equal(new RubyHash { { "k", "v" } }, ((RubyHash)changed["value"])["values"]);
        Assert.Equal(RubyBool.True, ((RubyHash)changed["value"])["written"]);
        Assert.Equal(BridgeEnvelope.BadRequest, refused["error"].AsText());
        Assert.Equal("id=abc\nk=v\n", File.ReadAllText(_path));
    }

    /// <summary>
    /// Opens the test's Player.ini afresh, as a new session does.
    /// </summary>
    /// <returns>The Player.ini.</returns>
    private PlayerIni Open() => new(_path, () => $"key{++_keysMade}", (key, name) =>
    {
        _shared.Add((key, name));
        return true;
    });

    /// <summary>
    /// Calls a topic as the scripts do.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The reply's envelope.</returns>
    private static RubyHash Call(BridgeContext context, string topic, RubyValue request)
    {
        var reply = new byte[4096];
        var length = context.Call(System.Text.Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), reply);
        return (RubyHash)RubyMarshal.Read(reply.AsSpan(0, length));
    }

    /// <summary>
    /// A bridge log that keeps nothing.
    /// </summary>
    private sealed class NoLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
