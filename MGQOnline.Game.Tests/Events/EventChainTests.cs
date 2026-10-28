//----------------------------------------------------------------
//  EventChainTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Followed the chains over an event source alone
//                            - Read the events through an event source
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the chain a list starts across maps over a tiny game: the transfers it follows and the
/// pages it takes in.
/// </summary>
public sealed class EventChainTests
{
    /// <summary>
    /// Asserts that a list takes in the page that runs by itself on the map it transfers to, and on
    /// the map that page transfers to, while one whose self switch ended it counts nothing.
    /// </summary>
    [Fact]
    public void VariableSetsOf_FollowsTransfersIntoThePagesTheMapsShow()
    {
        var source = new GameDataSource(new TinyGame()
            .Event(1, C(201, 0, 2, 5, 5, 2, 0))
            .Event(2, C(201, 0, 4, 5, 5, 2, 0))
            .Autorun(2, 1, null, C(121, 7, 7, 0), C(201, 0, 3, 5, 5, 2, 0))
            .Autorun(3, 1, null, C(122, 1001, 1001, 0, 0, 34))
            .Autorun(4, 1, "A", C(122, 1001, 1001, 0, 0, 34), C(123, "A", 0))
            .Data());
        var ending = new[] { new VariableSet(1001, 1001, 34) };

        Assert.Equal(ending, SetsOf(source, 1));
        Assert.Equal(ending, SetsOf(source, 2));
        Assert.Empty(SetsOf(source, 2, (4, 1, "A")));
    }

    /// <summary>
    /// Lists the variables an event of map 1 and the chain it starts set.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="selfSwitchesOn">The self switches on, by map, event and letter.</param>
    /// <returns>The variables set.</returns>
    private static IReadOnlyList<VariableSet> SetsOf(IEventSource source, int eventId, params (int Map, int Event, string Letter)[] selfSwitchesOn) =>
        new EventChain(source, new EventCommandIndex(source)).VariableSetsOf(source.Page(1, eventId, 0)!.List, 1, eventId, new SelfSwitchesOn(selfSwitchesOn));

    /// <summary>
    /// A game whose switches are off and variables 0, with some self switches on.
    /// </summary>
    /// <param name="on">The self switches on.</param>
    private sealed class SelfSwitchesOn((int Map, int Event, string Letter)[] on) : IPageState
    {
        /// <inheritdoc />
        public bool Switch(long id) => false;

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;

        /// <inheritdoc />
        public bool SelfSwitch(int map, int eventId, string letter) => on.Contains((map, eventId, letter));
    }
}
