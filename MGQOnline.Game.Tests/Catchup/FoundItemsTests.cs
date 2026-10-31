//----------------------------------------------------------------
//  FoundItemsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Covered a key item an event used up leaving every save that holds it, with the Yggdrasil Fruit the Queen Harpy takes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers what a player gets of the key items and the items unlocking a job or a race any player
/// found or used up: each save gets each once, keeps one of each item unlocking a job or a race,
/// and loses a copy for each use by another player's event.
/// </summary>
public sealed class FoundItemsTests
{
    /// <summary>
    /// The use of the Yggdrasil Fruit (item 508) by the Queen Harpy event (map 88, event 4, page 1,
    /// command 63), as the scripts mark it.
    /// </summary>
    private const string QueenHarpyUse = "508.U1se3r6i";

    /// <summary>
    /// The use of the Yggdrasil Fruit by Lucretia's page of the same event (page 2, command 18).
    /// </summary>
    private const string LucretiaUse = "508.U1yrbb1o";

    /// <summary>
    /// Asserts that a found item the save never held is given, one the save held before is not,
    /// though an event took it, and that every item held counts as held.
    /// </summary>
    [Fact]
    public void Plan_GivesEachFoundItemOncePerSave()
    {
        var held = new Dictionary<long, long> { [610] = 0, [502] = 0, [503] = 2 };

        FoundItems plan = FoundItems.Plan([610, 502], [502], held, _ => false, [], []);

        Assert.Equal([610L], plan.Gives);
        Assert.Empty(plan.Trims);
        Assert.Equal([502L, 503L, 610L], plan.Got);
    }

    /// <summary>
    /// Asserts that an item unlocking a job or a race held more than once is held once, an ore
    /// keeps its count, and an item the game lacks is left alone.
    /// </summary>
    [Fact]
    public void Plan_KeepsOneOfEachItemUnlockingAJob()
    {
        var held = new Dictionary<long, long> { [616] = 2, [151] = 5 };

        FoundItems plan = FoundItems.Plan([616, 151, 999], [], held, id => id == 616, [], []);

        Assert.Equal([(616L, 1L)], plan.Trims);
        Assert.Empty(plan.Gives);
    }

    /// <summary>
    /// Asserts that a save holding the Yggdrasil Fruit another player's find gave loses it once that
    /// player gave theirs to the Queen Harpy, so Lucretia's page, which takes a held one, stays shut,
    /// and loses the next one at Lucretia's page, each use once.
    /// </summary>
    [Fact]
    public void Plan_TakesTheYggdrasilFruitEachTimeAnotherPlayerUsedItUp()
    {
        FoundItems harpy = FoundItems.Plan([508], [508], new Dictionary<long, long> { [508] = 1 }, _ => false, [QueenHarpyUse], []);
        FoundItems again = FoundItems.Plan([508], harpy.Got, new Dictionary<long, long> { [508] = 0 }, _ => false, [QueenHarpyUse], harpy.Spent);
        FoundItems lucretia = FoundItems.Plan([508], again.Got, new Dictionary<long, long> { [508] = 1 }, _ => false, [QueenHarpyUse, LucretiaUse], again.Spent);

        Assert.Equal([508L], harpy.Takes);
        Assert.Equal([QueenHarpyUse], harpy.Spent);
        Assert.Empty(again.Takes);
        Assert.Empty(again.Gives);
        Assert.Equal([508L], lucretia.Takes);
        Assert.Equal([QueenHarpyUse, LucretiaUse], lucretia.Spent);
    }

    /// <summary>
    /// Asserts that a use the save counted, its own among them, takes nothing, that a save lacking
    /// the item loses nothing yet counts the use, and that a used up item goes to no save that never
    /// held it.
    /// </summary>
    [Fact]
    public void Plan_TakesACopyOnlyForANewUseOfAHeldItem()
    {
        var held = new Dictionary<long, long> { [502] = 2, [503] = 0, [610] = 1 };

        FoundItems plan = FoundItems.Plan([503], [], held, _ => false, ["502.Ua", "502.Ub", "503.Uc", "610.Ud"], ["610.Ud"]);

        Assert.Equal([502L, 502L], plan.Takes);
        Assert.Empty(plan.Gives);
        Assert.Equal(["502.Ua", "502.Ub", "503.Uc", "610.Ud"], plan.Spent);
    }

    /// <summary>
    /// Asserts that the topic of a Classic party's found items reads and answers as the scripts
    /// hand and read it.
    /// </summary>
    [Fact]
    public void Check_AnswersWhatTheScriptsCarryOut()
    {
        var request = new RubyHash
        {
            { "found", new RubyArray { 610, 616 } }, { "got", new RubyArray { 502 } },
            { "held", new RubyHash { { 610, 0 }, { 616, 3 }, { 508, 1 } } }, { "keeps_one", new RubyArray { 616 } },
            { "used", new RubyArray { QueenHarpyUse } }, { "spent", new RubyArray() },
        };

        RubyHash answer = FoundItems.Check(request);

        Assert.Equal(new RubyArray { 610 }, answer["give"]);
        Assert.Equal(new RubyArray { new RubyArray { 616, 2 } }, answer["trim"]);
        Assert.Equal(new RubyArray { 508 }, answer["take"]);
        Assert.Equal(new RubyArray { 502, 508, 610, 616 }, answer["got"]);
        Assert.Equal(new RubyArray { QueenHarpyUse }, answer["spent"]);
    }
}
