//----------------------------------------------------------------
//  PartEndTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Covered a script write read from the events database
//                            - Followed the chains over an event source alone
//                            - Covered a chain that transfers inside the folder of its map
//                            - Read the events through an event source
//                            - Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers which events a player behind the world's story may start (issue #48): only one that
/// would move their story past the end of their part is held.
/// </summary>
public sealed class PartEndTests
{
    /// <summary>
    /// Asserts that pages writing switches and variables the part does not follow run, as the race
    /// machine and a companion talk do, while a page that sets the main story's progress to the end
    /// of the part is held, also through a common event it calls.
    /// </summary>
    [Fact]
    public void Leaving_HoldsOnlyAWriteThatEndsThePart()
    {
        var source = new GameDataSource(new TinyGame()
            .Event(1, C(121, 7069, 7084, 0), C(122, 1124, 1126, 0, 0, 2), C(117, 20))
            .Event(2, C(101, "", 0, 0, 2), C(121, 451, 451, 0))
            .Event(3, C(122, 1001, 1001, 0, 0, 19))
            .Event(4, C(117, 21))
            .Common(20, C(121, 7129, 7129, 0))
            .Common(21, C(122, 1001, 1001, 0, 0, 34))
            .Data());

        Assert.Null(Leaving(source, 1, "1"));
        Assert.Null(Leaving(source, 2, "1"));
        Assert.Equal(new PartLeave(1001, 19, "1"), Leaving(source, 3, "1"));
        Assert.Null(Leaving(source, 3, "2"));
        Assert.Equal("it sets variable 1001 to 34, which leaves Part 2", Leaving(source, 4, "2")?.Why());
    }

    /// <summary>
    /// Asserts the routes' rule: the first route under way is the part, so in a route a later route
    /// and the main story's progress move nothing, while an earlier route and the route's own end do.
    /// </summary>
    [Fact]
    public void Leaving_FollowsTheFirstRouteUnderWay()
    {
        Assert.Null(PartEnd.Leaving("mr", [new VariableSet(1001, 1001, 40), new VariableSet(1143, 1143, 5)], _ => true));
        Assert.Equal(1141, PartEnd.Leaving("mr", [new VariableSet(1141, 1141, 1)], _ => true)?.Variable);
        Assert.Equal(1142, PartEnd.Leaving("mr", [new VariableSet(1140, 1200, 0)], _ => true)?.Variable);
        Assert.Equal(1142, PartEnd.Leaving("3", [new VariableSet(1142, 1142, 1)], _ => true)?.Variable);
        Assert.Null(PartEnd.Leaving("3", [new VariableSet(1140, 1200, 0)], _ => true));
    }

    /// <summary>
    /// Asserts that a value known only as the event runs, or a part the relay has yet to name, holds
    /// any write of the part's variables, and that a variable each player keeps as their own never does.
    /// </summary>
    [Fact]
    public void Leaving_HoldsWhatItCannotTell_ButNeverAPersonalVariable()
    {
        var source = new GameDataSource(new TinyGame()
            .Event(1, C(355, "$game_variables[1001] = $game_variables[5]"))
            .Event(2, C(122, 1001, 1001, 1, 0, 1))
            .Event(3, C(122, 1001, 1001, 0, 0, 5))
            .Data());

        Assert.Equal(new PartLeave(1001, null, "1"), Leaving(source, 1, "1"));
        Assert.Equal(new PartLeave(1001, null, "1"), Leaving(source, 2, "1"));
        Assert.Equal("it sets variable 1001 to 5, which leaves the part the relay has yet to name", Leaving(source, 3, null)?.Why());
        Assert.Null(PartEnd.Leaving("1", new EventCommandIndex(source).VariableSetsOf(source.Page(1, 2, 0)!.List), variable => variable != 1001));
    }

    /// <summary>
    /// Asserts that a script write of the main story's progress is held when the page is read from
    /// the events database, whose commands carry no script keys, both alone and as a chain's start.
    /// </summary>
    [Fact]
    public void Leaving_HoldsAScriptWriteReadFromTheEventsDatabase()
    {
        EventStoreSource source = EventDatabases.SourceOf(new TinyGame().Event(1, C(355, "$game_variables[1001] = $game_variables[5]")));
        ListKeys keys = source.PageKeys(1, 1, 0)!;
        var commands = new EventCommandIndex(source);

        Assert.Equal(new PartLeave(1001, null, "1"), PartEnd.Leaving("1", commands.VariableSetsOf(keys), _ => true));
        Assert.Equal(new PartLeave(1001, null, "1"), PartEnd.Leaving("1", new EventChain(source, commands).VariableSetsOf(keys, 1, 1, new Behind(0)), _ => true));
    }

    /// <summary>
    /// Asserts over the game folder's data that a player behind in Part 2 starts Promestein's race
    /// machine and Lime's talk, while the events that set the end of Part 1 and Part 2 are held.
    /// </summary>
    [Fact]
    public void Leaving_RunsTheRaceMachineAndLimesTalkOfTheGame()
    {
        var source = new GameDataSource(GameFolder.DataOrSkip());

        Assert.Null(Leaving(source, 51, "2", map: 228));
        Assert.Null(Leaving(source, 25, "2", map: 228));
        Assert.Equal(new PartLeave(1001, 19, "1"), Leaving(source, 1, "1", map: 634));
        Assert.Equal(new PartLeave(1001, 34, "2"), Leaving(source, 12, "2", map: 750));
    }

    /// <summary>
    /// Asserts over the game folder's data that a player behind is held at the event that starts the
    /// chain to their part's end, which closes on a map without exits: Alice's final battle in the
    /// Ilias Temple Ruins in Part 2 and the touch in the Administrator's Tower that leads to the
    /// Tartarus escape in Part 1. The race machine and Lime's talk still run.
    /// </summary>
    [Fact]
    public void Leaving_HoldsTheChainToThePartEndOfTheGameWhereItStarts()
    {
        var source = new GameDataSource(GameFolder.DataOrSkip());

        Assert.Equal(new PartLeave(1001, 34, "2"), Chained(source, 138, 13, "2", 33));
        Assert.Equal(new PartLeave(1001, 19, "1"), Chained(source, 619, 2, "1", 18));
        Assert.Null(Chained(source, 228, 51, "2", 33));
        Assert.Null(Chained(source, 228, 25, "2", 33));
    }

    /// <summary>
    /// Asserts that an event on a map of the Data/Map folder is held by the part's end on the map
    /// its transfer names in that folder, as the game moves there, never by the one on the map of
    /// that number in Data.
    /// </summary>
    [Fact]
    public void Leaving_HoldsTheChainOnTheMapItTransfersToInsideItsFolder()
    {
        var source = new GameDataSource(new TinyGame()
            .MapEvent(1001, 1, 0, 0, new TinyPage([C(201, 0, 2, 5, 5, 2, 0)]))
            .MapEvent(1001, 2, 0, 0, new TinyPage([C(201, 0, 3, 5, 5, 2, 0)]))
            .Autorun(1002, 1, null, C(121, 7, 7, 0))
            .Autorun(2, 1, null, C(122, 1001, 1001, 0, 0, 34))
            .Autorun(1003, 1, null, C(122, 1001, 1001, 0, 0, 34))
            .Autorun(3, 1, null, C(121, 7, 7, 0))
            .Data());

        Assert.Equal(new PartLeave(1001, 34, "2"), Chained(source, 1001, 2, "2", 33));
        Assert.Null(Chained(source, 1001, 1, "2", 33));
    }

    /// <summary>
    /// Finds the write of an event's first page and the chain it starts that leaves a part, every
    /// variable kept, for a player whose progress stands just before the part's end.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="map">The event's map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="part">The part.</param>
    /// <param name="progress">The main story's progress.</param>
    /// <returns>The write, <see langword="null"/> for none.</returns>
    private static PartLeave? Chained(IEventSource source, int map, int eventId, string part, long progress) =>
        PartEnd.Leaving(part, new EventChain(source, new EventCommandIndex(source)).VariableSetsOf(source.Page(map, eventId, 0)!.List, map, eventId, new Behind(progress)), _ => true);

    /// <summary>
    /// Finds the write of an event's first page that leaves a part, every variable kept.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="part">The part, <see langword="null"/> for one not known.</param>
    /// <param name="map">The event's map.</param>
    /// <returns>The write, <see langword="null"/> for none.</returns>
    private static PartLeave? Leaving(IEventSource source, int eventId, string? part, int map = 1) =>
        PartEnd.Leaving(part, new EventCommandIndex(source).VariableSetsOf(source.Page(map, eventId, 0)!.List), _ => true);

    /// <summary>
    /// A story at a progress of the main story with no other switch, variable or self switch set.
    /// </summary>
    /// <param name="progress">The main story's progress.</param>
    private sealed class Behind(long progress) : IPageState
    {
        /// <inheritdoc />
        public bool Switch(long id) => false;

        /// <inheritdoc />
        public long? Variable(long id) => id == PartEnd.MainProgress ? progress : 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;

        /// <inheritdoc />
        public bool SelfSwitch(int map, int eventId, string letter) => false;
    }
}
