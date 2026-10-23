//----------------------------------------------------------------
//  ParkingSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers turning other mods off over a game session: entering a world through a restart, the start
/// after it, the way back to the title screen, saving, and a world that turns other mods off now.
/// </summary>
public sealed class ParkingSessionTests : IDisposable
{
    /// <summary>
    /// The world entered.
    /// </summary>
    private const string World = "w1";

    /// <summary>
    /// Another world.
    /// </summary>
    private const string OtherWorld = "w9";

    /// <summary>
    /// The mods of a world that keeps only Level Cap.
    /// </summary>
    private const string LevelCapOnly = "!Level Cap";

    /// <summary>
    /// The game folder.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The parkings made, disposed with the test.
    /// </summary>
    private readonly List<ModParking> _parkings = [];

    /// <summary>
    /// The restarts with the mods parked asked for: the world and whether it is entered.
    /// </summary>
    private readonly List<(string World, bool Rejoin)> _parkedRestarts = [];

    /// <summary>
    /// The plain restarts asked for.
    /// </summary>
    private int _restarts;

    /// <summary>
    /// Whether a restart starts.
    /// </summary>
    private bool _restartWorks = true;

    /// <summary>
    /// The personal mods' keys, <see langword="null"/> while the catalog is unknown.
    /// </summary>
    private IReadOnlyCollection<string>? _personal = ["victoryscreen"];

    /// <summary>
    /// The directory the open world is checked against.
    /// </summary>
    private readonly FakeDirectory _directory = new();

    /// <summary>
    /// Writes the scripts of a player with a few mods.
    /// </summary>
    public ParkingSessionTests()
    {
        foreach (string script in new[] { "Patch/Level_Cap.rb", "Patch/Invasions.rb", "Patch/Victory_Screen.rb", "Patch/Sub/Extra.rb", "Patch/Multiplayer.rb" })
        {
            string path = Path.Combine(_game.Path, script);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, "# " + script + "\n");
        }
    }

    /// <summary>
    /// Asserts that entering a world parks what it turns off and starts again into it, and that the
    /// same session may not enter again, since it still runs the mods.
    /// </summary>
    [Fact]
    public void Join_ParksTheScriptsAndStartsAgainIntoTheWorld()
    {
        var (session, player, parking) = Session();
        session.TitleStarted();
        ParkingChange change = session.Change(World, LevelCapOnly, true);

        Assert.Equal(ParkingKind.Plan, change.Kind);
        Assert.Equal(["Patch/Invasions.rb", "Patch/Sub/Extra.rb"], change.Plan);
        Assert.Equal(JoinResult.Restarting, session.Join(World, change.Plan));
        Assert.Equal((World, 2), (parking.Parked().World, parking.Parked().Files.Count));
        Assert.Equal([(World, true)], _parkedRestarts);
        Assert.Equal(World, Setting(player, ParkingSession.RejoinSetting));
        Assert.Equal(ParkingKind.Restart, session.Change(World, LevelCapOnly, true).Kind);
    }

    /// <summary>
    /// Asserts that a game that cannot start again puts the scripts back and forgets the world.
    /// </summary>
    [Fact]
    public void Join_WhenTheGameCannotStartAgain_PutsTheScriptsBack()
    {
        var (session, player, parking) = Session();
        session.TitleStarted();
        _restartWorks = false;

        Assert.Equal(JoinResult.Failed, session.Join(World, session.Change(World, LevelCapOnly, true).Plan));
        Assert.Empty(parking.Parked().Files);
        Assert.Equal(string.Empty, Setting(player, ParkingSession.RejoinSetting));
    }

    /// <summary>
    /// Asserts that the scripts parked for another world are parked for this one when it turns off the
    /// same, moving nothing, and that the mods parked for the world stay while the catalog is unknown.
    /// </summary>
    [Fact]
    public void Claim_ParksTheSameScriptsForTheWorldEntered()
    {
        Parked(OtherWorld, LevelCapOnly, rejoin: true);
        var (session, _, parking) = Session();
        session.TitleStarted();

        Assert.True(session.Claim(World, LevelCapOnly, true));
        Assert.Equal((World, ParkingKind.None), (parking.Parked().World, session.Change(World, LevelCapOnly, true).Kind));
        _personal = null;
        Assert.Equal((ParkingKind.None, ParkingKind.Unknown), (session.Change(World, LevelCapOnly, true).Kind, session.Change(OtherWorld, LevelCapOnly, true).Kind));
    }

    /// <summary>
    /// Asserts that the start after the restart holds the scripts for the world, and that giving up on
    /// it puts them back and has the title screen start the game again with the reason.
    /// </summary>
    [Fact]
    public void TitleStarted_HoldsTheScriptsForTheWorldEnteredAgain()
    {
        Parked(World, LevelCapOnly, rejoin: true);
        var (session, _, parking) = Session();

        session.TitleStarted();
        session.TitleLeft(false);
        Assert.Equal((true, 2), (session.Holding, parking.Parked().Files.Count));

        session.GiveUp("Strict is full right now.");
        Assert.Equal((false, "Strict is full right now. " + ParkingTexts.Leave), (session.Holding, session.Due));
        Assert.Empty(parking.Parked().Files);
        Assert.True(session.RestartNow());
        Assert.Equal(1, _restarts);
    }

    /// <summary>
    /// Asserts that the scripts a closed game left parked come back with a restart, but never twice in
    /// a row.
    /// </summary>
    [Fact]
    public void TitleStarted_PutsBackWhatAClosedGameLeftParked()
    {
        Parked(OtherWorld, LevelCapOnly);
        var (session, player, parking) = Session();
        session.TitleStarted();

        Assert.Equal((ParkingTexts.Recovered, 0), (session.Due, parking.Parked().Files.Count));

        CloseGames();
        Parked(OtherWorld, LevelCapOnly);
        player.Change([new(ParkingSession.RestartedSetting, "1")]);
        var (again, againPlayer, _) = Session();
        again.TitleStarted();
        Assert.Equal((null, ParkingTexts.RestartByHand, string.Empty), (again.Due, again.Notice, Setting(againPlayer, ParkingSession.RestartedSetting)));
    }

    /// <summary>
    /// Asserts that leaving a world puts the scripts back and tells how many went to the conflicts
    /// folder, and that the session saves nothing outside a world afterwards.
    /// </summary>
    [Fact]
    public void TitleLeft_PutsTheScriptsBackAsTheWorldIsLeft()
    {
        var (session, _, parking) = Session();
        session.TitleStarted();
        session.Join(World, session.Change(World, LevelCapOnly, true).Plan);
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Invasions.rb"), "# another copy\n");

        session.TitleStarted();
        session.TitleLeft(true);

        Assert.Equal(ParkingTexts.WithConflicts(ParkingTexts.Leave, 1), session.Due);
        Assert.Empty(parking.Parked().Files);
        Assert.False(session.SavingOff);
    }

    /// <summary>
    /// Asserts that a session started with scripts parked saves nothing, also once they are back.
    /// </summary>
    [Fact]
    public void SavingOff_StaysForASessionThatStartedWithoutTheMods()
    {
        Parked(World, LevelCapOnly, rejoin: true);
        var (session, _, _) = Session();
        session.TitleStarted();
        session.GiveUp(null);

        Assert.True(session.SavingOff);
    }

    /// <summary>
    /// Asserts that while another game of this folder holds the parked scripts, leaving the world says
    /// so and starts nothing again.
    /// </summary>
    [Fact]
    public void TitleLeft_WhileAnotherGameHoldsTheScripts_SaysSo()
    {
        var (first, _, _) = Session();
        first.TitleStarted();
        first.Join(World, first.Change(World, LevelCapOnly, true).Plan);
        var (second, _, _) = Session();
        second.TitleStarted();
        second.TitleStarted();

        second.TitleLeft(true);

        Assert.Equal((null, ParkingTexts.Held), (second.Due, second.Notice));
    }

    /// <summary>
    /// Asserts that the restart for downloaded mods starts plainly with nothing parked, and opens the
    /// lock of a world that parks scripts first.
    /// </summary>
    [Fact]
    public void RestartForMods_StartsAgainForTheDownloads()
    {
        var (session, player, _) = Session();
        session.TitleStarted();

        Assert.Equal(ModsRestart.Unlock, session.RestartForMods(World, (true, LevelCapOnly), false).Result);
        Assert.Equal(ModsRestart.Restarting, session.RestartForMods(World, (false, LevelCapOnly), true).Result);
        Assert.Equal((1, World), (_restarts, Setting(player, ParkingSession.RejoinSetting)));
    }

    /// <summary>
    /// Asserts that the game stays open while scripts parked for another world cannot be kept for this
    /// one, since a plain restart would leave them to the watchdog.
    /// </summary>
    [Fact]
    public void RestartForMods_KeepsTheGameOpenWhileScriptsCannotBeKept()
    {
        Parked(OtherWorld, LevelCapOnly);
        var (session, _, _) = Session();
        _personal = null;

        Assert.Equal(ModsRestart.NotKept, session.RestartForMods(World, (true, LevelCapOnly), true).Result);
        Assert.Equal((0, 0), (_restarts, _parkedRestarts.Count));
    }

    /// <summary>
    /// Asserts that the relay's word sends a player who runs mods the world turns off to the title
    /// screen, and leaves the others in it.
    /// </summary>
    [Fact]
    public void Rule_TellsAPlayerWhoseModsTheWorldTurnsOff()
    {
        var (session, _, _) = Session();
        session.TitleStarted();

        Assert.Equal((false, null), session.Rule("2", LevelCapOnly, true, World, "Strict"));
        Assert.Equal((true, null), session.Rule("0", LevelCapOnly, true, World, "Strict"));
        Assert.Equal((true, null), session.Rule("1", "Level Cap; Invasions; Sub", true, World, "Strict"));
        Assert.Equal((true, ParkingTexts.NowOff("Strict")), session.Rule("1", LevelCapOnly, true, World, "Strict"));
    }

    /// <summary>
    /// Asserts that while the catalog is unknown the player stays, and the world is checked again once
    /// a list fetched for it arrived.
    /// </summary>
    [Fact]
    public void Frame_ChecksTheWorldAgainOnceTheListArrived()
    {
        var (session, _, _) = Session();
        session.TitleStarted();
        _personal = null;
        Assert.Equal((true, null), session.Rule("1", LevelCapOnly, true, World, "Strict"));

        _personal = ["victoryscreen"];
        Frames(session, ParkingSession.RecheckStep);
        Assert.Equal(1, _directory.Refreshes);
        _directory.Listing = true;
        Frames(session, ParkingSession.RecheckStep);
        _directory.Listing = false;

        Assert.True(Frames(session, ParkingSession.RecheckStep));
        Assert.Equal(ParkingTexts.NowOff("Strict"), session.TakeKick());
        Assert.Null(session.TakeKick());
    }

    /// <summary>
    /// Asserts that a world entered from an older list is checked against the list fetched after it.
    /// </summary>
    [Fact]
    public void Entered_ChecksTheWorldAgainstTheListFetchedAfterIt()
    {
        var (session, _, _) = Session();
        session.TitleStarted();
        _directory.Rule = (true, LevelCapOnly);

        session.Entered(World, "Strict");
        Frames(session, ParkingSession.RecheckStep * 2);

        Assert.Equal(ParkingTexts.NowOff("Strict"), session.TakeKick());
    }

    /// <summary>
    /// Asserts that the world to enter again is taken once.
    /// </summary>
    [Fact]
    public void TakeRejoin_TakesTheWorldOnce()
    {
        var (session, player, _) = Session();
        player.Change([new(ParkingSession.RejoinSetting, World)]);

        Assert.Equal((World, null), (session.TakeRejoin(), session.TakeRejoin()));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        CloseGames();
        _game.Dispose();
    }

    /// <summary>
    /// Closes the games of the sessions made, which frees their locks.
    /// </summary>
    private void CloseGames()
    {
        foreach (ModParking parking in _parkings)
        {
            parking.Dispose();
        }

        _parkings.Clear();
    }

    /// <summary>
    /// Makes a session of a game of the folder.
    /// </summary>
    /// <returns>The session, its Player.ini and its parking.</returns>
    private (ParkingSession Session, PlayerIni Player, ModParking Parking) Session()
    {
        var parking = new ModParking(_game.Path);
        _parkings.Add(parking);
        var player = new PlayerIni(Path.Combine(_game.Path, "Player.ini"), () => "key");
        var session = new ParkingSession(parking, player, () => _personal, (world, rejoin) =>
        {
            _parkedRestarts.Add((world, rejoin));
            return _restartWorks;
        }, () =>
        {
            _restarts++;
            return _restartWorks;
        }, _directory);
        return (session, player, parking);
    }

    /// <summary>
    /// Leaves scripts parked for a world as a game that closed would, its lock freed.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="mods">The world's mods.</param>
    /// <param name="rejoin">Whether the next start enters the world again.</param>
    private void Parked(string world, string mods, bool rejoin = false)
    {
        using (var parking = new ModParking(_game.Path))
        {
            var facts = new ParkingFacts([.. parking.Listed()!.Patch], [], _personal, string.Empty, [], false);
            parking.Park(ParkingRules.Plan(facts, mods, true)!, world);
        }

        new PlayerIni(Path.Combine(_game.Path, "Player.ini"), () => "key").Change([new(ParkingSession.RejoinSetting, rejoin ? world : null)]);
    }

    /// <summary>
    /// Runs frames of the session.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="count">How many.</param>
    /// <returns>Whether a frame found the player must leave.</returns>
    private static bool Frames(ParkingSession session, int count)
    {
        bool kicked = false;
        for (int frame = 0; frame < count; frame++)
        {
            kicked |= session.Frame();
        }

        return kicked;
    }

    /// <summary>
    /// Reads a setting of Player.ini.
    /// </summary>
    /// <param name="player">The Player.ini.</param>
    /// <param name="key">The setting.</param>
    /// <returns>Its value, empty when missing.</returns>
    private static string Setting(PlayerIni player, string key) => player.Settings.FirstOrDefault(setting => setting.Key == key).Value ?? string.Empty;

    /// <summary>
    /// A directory whose list a test sets.
    /// </summary>
    private sealed class FakeDirectory : IParkingDirectory
    {
        /// <inheritdoc />
        public bool Listing { get; set; }

        /// <summary>
        /// Gets how often the list was fetched.
        /// </summary>
        public int Refreshes { get; private set; }

        /// <summary>
        /// Gets or sets the world's rule in the list, <see langword="null"/> when it lacks the world.
        /// </summary>
        public (bool OtherModsOff, string Mods)? Rule { get; set; }

        /// <inheritdoc />
        public void Refresh() => Refreshes++;

        /// <inheritdoc />
        public (bool OtherModsOff, string Mods)? RuleOf(string world) => Rule;
    }
}
