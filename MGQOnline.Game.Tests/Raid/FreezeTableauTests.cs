//----------------------------------------------------------------
//  FreezeTableauTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers where a frozen fight waits on the map, which live events it keeps from starting, and how
/// a player without a record of their own starts it afresh.
/// </summary>
public sealed class FreezeTableauTests
{
    /// <summary>
    /// The switches the post-defeat processing writes itself.
    /// </summary>
    private static readonly HashSet<int> DefeatSwitches = [22, 31];

    /// <summary>
    /// The variables the post-defeat processing writes itself.
    /// </summary>
    private static readonly HashSet<int> DefeatVariables = [11];

    /// <summary>
    /// Asserts that a field fight's stand-ins stand in place and block its event and the map's
    /// other callers of its common event; a cutscene's boss stands where the player left the field
    /// for it, else at its first source, blocking the sources on that map; and a fight whose event
    /// moved the player away waits at that event on the map it started on.
    /// </summary>
    [Fact]
    public void Tableau_StandsWhereTheStoryReachesTheFight()
    {
        (int, int)[] callers = [(214, 43), (999, 7), (214, 42)];
        SceneSource[] sources = [new(138, 13, 32, 8), new(140, 2, 5, 5)];

        TableauPlace field = FreezeTableau.Place(new TableauAsk(false, false, 214, 42, null, null, [], callers));
        TableauPlace left = FreezeTableau.Place(new TableauAsk(true, false, 728, 12, (140, 6, 7), null, sources, []));
        TableauPlace first = FreezeTableau.Place(new TableauAsk(true, false, 728, 12, (2, 5, 5), null, sources, []));
        TableauPlace moved = FreezeTableau.Place(new TableauAsk(false, true, 138, 30, null, (40, 10), [], [(138, 31), (777, 30)]));

        Assert.Equal((214, false, 1), (field.Map, field.At.HasValue, field.Callers));
        Assert.Equal([42, 43], field.Blocked);
        Assert.Equal((140, (6, 7)), (left.Map, left.At!.Value));
        Assert.Equal([2], left.Blocked);
        Assert.Equal((138, (32, 8)), (first.Map, first.At!.Value));
        Assert.Equal([13], first.Blocked);
        Assert.Equal((138, (40, 10)), (moved.Map, moved.At!.Value));
        Assert.Equal([30, 31], moved.Blocked);
    }

    /// <summary>
    /// Asserts that the fight's own event is blocked and resumes the fight when the player presses
    /// or touches it while its stand-ins show, but not when it runs by itself or the stand-ins step
    /// aside; a page writing a held variable, switch or its own held self switch is blocked; and a
    /// page writing only the post-defeat processing's values or another event's self switch starts.
    /// </summary>
    [Fact]
    public void Blocker_KeepsTheFightsEventsAndTheWritersOfItsValuesFromStarting()
    {
        List<(int, RubyValue)> held = [(1, 1075), (0, 2307), (1, 11), (2, new RubyArray([138, 40, "A"]))];
        BlockingTableau shown = new(868, [13, 16], held, true);
        BlockingTableau aside = shown with { Shown = false };

        BlockedStart? pressed = Find(13, 0, [], shown);
        BlockedStart? autorun = Find(13, 3, [], shown);
        BlockedStart? watched = Find(16, 1, [], aside);

        Assert.Equal(new BlockedStart(868, "it is the fight's own event", true), pressed);
        Assert.False(autorun!.LeadsIn);
        Assert.False(watched!.LeadsIn);

        Assert.Equal("its page writes v1075, which the fight holds", Find(32, 0, [new(1, 1070, 1080, string.Empty)], shown)!.Reason);
        Assert.Equal("its page writes s2307, which the fight holds", Find(33, 0, [new(0, 2300, 2310, string.Empty)], shown)!.Reason);
        Assert.Equal("its page writes self switch 138.40.A, which the fight holds", Find(40, 0, [new(2, 0, 0, "A")], shown)!.Reason);
        Assert.Null(Find(41, 0, [new(2, 0, 0, "A")], shown));
        Assert.Null(Find(42, 0, [new(1, 11, 11, string.Empty), new(0, 22, 22, string.Empty)], shown));
    }

    /// <summary>
    /// Asserts that a cutscene entry takes the first cutscene whose side switch is on or that needs
    /// none, and refuses without one; a field entry starts from its event's tile for a touch, in
    /// front of it for the action button, where the player stands otherwise, and only while its
    /// event shows the entry's page on the player's map.
    /// </summary>
    [Fact]
    public void FreshStart_TakesTheSidesCutsceneOrTheSpotItsTriggerStartsFrom()
    {
        FreshScene[] scenes = [new(728, 12, 1, 4, [728, 0, 0, 0]), new(749, 13, 1, 5, [749, 1, 0, 0])];
        FreshPlan ilias = FreezeFresh.Plan(new FreshAsk(true, scenes, new HashSet<int> { 5 }, null, 138, null, null));
        FreshPlan noSide = FreezeFresh.Plan(new FreshAsk(true, scenes, new HashSet<int>(), null, 138, null, null));

        Assert.Equal(new FreshPlan(FreshStart.Scene, 749, 13, 1, scenes[1].Spot, null), ilias);
        Assert.Equal(FreshPlan.Refused("no cutscene of the player's side is known"), noSide);

        FreshStart Start(int map, int? shown, int? trigger) => FreezeFresh.Plan(new FreshAsk(false, [], new HashSet<int>(), (138, 13, 1), map, shown, trigger)).Start;

        Assert.Equal(
            [FreshStart.Touch, FreshStart.Touch, FreshStart.Action, FreshStart.Here, FreshStart.None, FreshStart.None],
            [Start(138, 0, 1), Start(138, 0, 2), Start(138, 0, 0), Start(138, 0, 3), Start(138, 1, 0), Start(154, null, null)]);
        Assert.Equal("[\"map\", 138, 13, 1] is not the page that shows here (map 154)", FreezeFresh.Plan(new FreshAsk(false, [], new HashSet<int>(), (138, 13, 1), 154, null, null)).Refusal);
    }

    /// <summary>
    /// Finds the fight that keeps an event of map 138 from starting.
    /// </summary>
    /// <param name="eventId">The event.</param>
    /// <param name="trigger">Its page's trigger.</param>
    /// <param name="writes">What its page writes.</param>
    /// <param name="tableau">The one fight of the map.</param>
    /// <returns>The blocked start, null when it may start.</returns>
    private static BlockedStart? Find(int eventId, int trigger, PageWrite[] writes, BlockingTableau tableau) =>
        FreezeBlocker.Find(new BlockerAsk(138, eventId, trigger, writes, [tableau]), DefeatSwitches, DefeatVariables);
}
