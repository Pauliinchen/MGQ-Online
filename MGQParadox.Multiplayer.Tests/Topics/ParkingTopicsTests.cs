//----------------------------------------------------------------
//  ParkingTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of turning other mods off as the scripts call them.
/// </summary>
public sealed class ParkingTopicsTests : IDisposable
{
    /// <summary>
    /// The game folder.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The parking of the game folder.
    /// </summary>
    private readonly ModParking _parking;

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// Creates the topics over a game folder with two mods.
    /// </summary>
    public ParkingTopicsTests()
    {
        Directory.CreateDirectory(Path.Combine(_game.Path, "Patch"));
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"), "# Level Cap\n");
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Invasions.rb"), "# Invasions\n");
        _parking = new ModParking(_game.Path);
        var session = new ParkingSession(_parking, new PlayerIni(Path.Combine(_game.Path, "Player.ini"), () => "key"), () => [], (_, _) => false, () => false, new NoDirectory());
        _topics = new TopicCaller(context => ParkingTopics.Register(context, session, new WorldChanges(context)));
    }

    /// <summary>
    /// Asserts that a world that turns other mods off answers its plan with the question to ask.
    /// </summary>
    [Fact]
    public void Change_AnswersThePlanAndTheQuestion()
    {
        RubyHash change = _topics.Call(ParkingTopics.Change, new RubyHash { { "world", "w1" }, { "mods", "!Level Cap" }, { "off", true }, { "name", "Strict" } })!.AsHash();

        Assert.Equal(("plan", new RubyArray(["Patch/Invasions.rb"])), (change["kind"].AsText(), change["plan"]));
        Assert.Equal(ParkingTexts.Confirm("Strict", ["Patch/Invasions.rb"]), change["text"].AsText());
    }

    /// <summary>
    /// Asserts that a park whose restart fails answers why, with the scripts back.
    /// </summary>
    [Fact]
    public void Join_AnswersWhyTheWorldWasNotEntered()
    {
        RubyHash join = _topics.Call(ParkingTopics.Join, new RubyHash { { "world", "w1" }, { "name", "Strict" }, { "plan", new RubyArray(["Patch/Invasions.rb"]) } })!.AsHash();

        Assert.Equal(("failed", ParkingTexts.RestartFailed("Strict"), true), (join["result"].AsText(), join["text"].AsText(), join["moved"].AsBool()));
        Assert.Empty(_parking.Parked().Files);
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _parking.Dispose();
        _game.Dispose();
    }

    /// <summary>
    /// A directory that never lists.
    /// </summary>
    private sealed class NoDirectory : IParkingDirectory
    {
        /// <inheritdoc />
        public bool Listing => false;

        /// <inheritdoc />
        public void Refresh()
        {
        }

        /// <inheritdoc />
        public (bool OtherModsOff, string Mods)? RuleOf(string world) => null;
    }
}
