//----------------------------------------------------------------
//  SessionModsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Tests.Mods;

/// <summary>
/// Covers which of the player's mods a world that turns other mods off lets load, and what the game
/// tells of them.
/// </summary>
public sealed class SessionModsTests
{
    /// <summary>
    /// Asserts that a session keeps the mods the world names, the personal ones and those every player
    /// has, and leaves out the rest, each mod once.
    /// </summary>
    [Fact]
    public void Of_KeepsNamedPersonalAndSharedModsAndLeavesOutTheRest()
    {
        SessionPlan? plan = SessionMods.Of(["Multiplayer", "Level_Cap", "Party_Sheet", "Invasions", "level cap"], "!Level Cap;Map Display", ["partysheet"]);

        Assert.Equal(["Multiplayer", "Level_Cap", "Party_Sheet"], plan!.Only);
        Assert.Equal(["Invasions"], plan.Off);
    }

    /// <summary>
    /// Asserts that a mod the world does not name leaves the session unknown while the catalog, which
    /// tells the personal mods, is unknown, and that a world naming every mod needs no catalog.
    /// </summary>
    [Fact]
    public void Of_IsUnknownWithoutTheCatalogOnlyForAModTheWorldDoesNotName()
    {
        Assert.Null(SessionMods.Of(["Multiplayer", "Invasions"], "Level Cap", null));
        Assert.Equal(["Multiplayer", "Level_Cap"], SessionMods.Of(["Multiplayer", "Level_Cap"], "?Level Cap", null)!.Only);
    }

    /// <summary>
    /// Asserts that the details count the scripts of each mod the world turns off, a folder's scripts
    /// as its mod's.
    /// </summary>
    [Fact]
    public void TurnedOff_GroupsTheScriptsByTheirMods()
    {
        string[] scripts = ["Patch/Invasions.rb", "Patch/Invasions/waves.rb", "Patch/Level_Cap.rb", "Patch/Luka_Replacer/heroes.rb"];

        Assert.Equal([("Invasions", 2), ("Luka_Replacer", 1)], SessionMods.TurnedOff(scripts, "!Level Cap", []));
        Assert.Null(SessionMods.TurnedOff(null, "", []));
    }

    /// <summary>
    /// Asserts that a world whose rule or mods changed sends a player out only for a mod their session
    /// runs that it turns off now.
    /// </summary>
    [Fact]
    public void NowTurnedOff_NamesOnlyRunningModsTheWorldTurnsOffNow()
    {
        Assert.Equal(["Invasions"], SessionMods.NowTurnedOff(true, ["Multiplayer", "Invasions", "Level_Cap"], "!Level Cap", []));
        Assert.Empty(SessionMods.NowTurnedOff(false, ["Invasions"], "", []));
        Assert.Empty(SessionMods.NowTurnedOff(true, ["Invasions"], "", null));
    }

    /// <summary>
    /// Asserts that entering tells the mods left out and those that stay on, since they run from the
    /// start of the game.
    /// </summary>
    [Fact]
    public void Entered_TellsTheModsLeftOutAndThoseThatStayOn()
    {
        Assert.Equal("Strict plays without your other mods: Invasions stays off until you leave it. Wide Text is part of the framework and stays on.",
            SessionMods.Entered("Strict", ["Invasions", "Wide Text"], ["Wide Text"]));
        Assert.Equal("Strict plays without your other mods: Invasions, Map Display, Party Sheet and 1 more stay off until you leave it.",
            SessionMods.Entered("Strict", ["Invasions", "Map Display", "Party Sheet", "Victory Screen"], []));
        Assert.Equal(string.Empty, SessionMods.Entered("Loose", [], []));
    }

    /// <summary>
    /// Asserts that a script belongs to the folder right under Patch it sits in, else to its own name.
    /// </summary>
    [Fact]
    public void OwnerName_NamesTheFolderOrTheScript()
    {
        Assert.Equal(["Luka_Replacer", "Sub", "Invasions", "Odd", "lower"],
            new[] { "Patch/Luka_Replacer/heroes.rb", "Patch\\Sub\\Deep\\x.rb", "Patch/Invasions.rb", "Patch/Odd.RB", "patch/lower/Mod.rb" }.Select(SessionMods.OwnerName));
    }
}
