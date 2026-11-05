//----------------------------------------------------------------
//  EventDecisionTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Covered a page that asks by the game's extended choices
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the one decision of how an event runs and whom a telling takes along with the pages of
/// the bug reports, read from the events database the mod ships.
/// </summary>
public sealed class EventDecisionTests : IDisposable
{
    /// <summary>
    /// The shipped events database below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The events database the mod ships.
    /// </summary>
    private readonly EventStore _store = EventStore.Open(Path.Combine(Repository.Root, ShippedPath));

    /// <summary>
    /// The game's events as the DLL reads them.
    /// </summary>
    private readonly EventStoreSource _source;

    /// <summary>
    /// The sorter over the shipped events.
    /// </summary>
    private readonly EventSorter _sorter;

    /// <summary>
    /// Initializes the decision over the shipped database.
    /// </summary>
    public EventDecisionTests()
    {
        _source = new EventStoreSource(_store);
        _sorter = new EventSorter(_source);
    }

    /// <summary>
    /// Asserts that Promestein's race machine (228:51, calling common event 231) and the maid's
    /// party saves (228:23, calling 111) are talks each player has alone, which no command of them
    /// turns into story: the machine was held for a player behind the world (issue #48), and a
    /// member's talk with the maid was ended as story (issue #53). The same machine off the castle's
    /// maps is story, as its unlock switches are.
    /// </summary>
    [Fact]
    public void PocketCastleServices_AreTalksNoCommandTurnsIntoStory()
    {
        EventPage machine = Page(228, 51, 0);
        EventPage maid = Page(228, 23, 0);

        Assert.Equal((EventKind.Talk, false), KindAndTell(machine, Site(228, machine)));
        Assert.Equal((EventKind.Talk, false), KindAndTell(maid, Site(228, maid)));
        Assert.DoesNotContain(true, Enumerable.Range(0, machine.List.Count).Select(index => _sorter.DecideCommand(machine.List, index, Site(228, machine), new NewGame())));
        Assert.DoesNotContain(true, Enumerable.Range(0, maid.List.Count).Select(index => _sorter.DecideCommand(maid.List, index, Site(228, maid), new NewGame())));
        Assert.Equal(EventKind.Story, _sorter.Decide(machine.List, Site(1, machine), new NewGame()).Kind);
    }

    /// <summary>
    /// Asserts that a castle page whose first speaker shows an affection the player keeps, as a
    /// companion's talk does, is a talk whatever it sets, while the same page whose speaker shows an
    /// affection nobody keeps is sorted by its commands (228:25, story in a new game).
    /// </summary>
    [Fact]
    public void CompanionTalkInTheCastle_IsATalkByItsSpeaker()
    {
        EventPage page = Page(228, 25, 0);
        var site = new EventSite(228, null, page.Trigger, new PageTexts([3005], false));

        Assert.Equal(EventKind.Talk, _sorter.Decide(page.List, site, new NewGame(personalVariables: [3005])).Kind);
        Assert.Equal(EventKind.Story, _sorter.Decide(page.List, site, new NewGame()).Kind);
    }

    /// <summary>
    /// Asserts that the Pocket Castle call another player started from the menu (common event 3) and
    /// a battlefuck at the Angelic Dominion's smithy (1887:35, which took a player at the blacksmith
    /// along to its door, issue #58) run in the player's own game alone, so their telling takes
    /// nobody along; so does any story page while the Library replays a scene.
    /// </summary>
    [Fact]
    public void OwnEvents_TakeNobodyAlong()
    {
        EventPage battlefuck = Page(1887, 35, 0);
        EventPage breaker = Page(1019, 3, 0);

        Assert.Equal(EventKind.Own, _sorter.Decide(_source.CommonList(3)!, new EventSite(228, 3, null, PageTexts.None), new NewGame()).Kind);
        Assert.Equal(EventKind.Own, _sorter.Decide(battlefuck.List, Site(1887, battlefuck), new NewGame()).Kind);
        Assert.Equal(EventKind.Story, _sorter.Decide(breaker.List, Site(1019, breaker), new NewGame()).Kind);
        Assert.Equal(EventKind.Own, _sorter.Decide(breaker.List, Site(1019, breaker), new NewGame(switches: [EventSorter.LibraryReplaySwitch])).Kind);
    }

    /// <summary>
    /// Asserts that the World Breaker's scene after its battle (1019:3), which moves its teller to
    /// 1702 and sets only scratch switches, does not move the world's story on, so the others get an
    /// offer instead of a follow, while the scene that sets the Chaos route's step (1767:66) does
    /// until it has set it: the World Breaker's scene played once for each of four players
    /// (issue #61).
    /// </summary>
    [Fact]
    public void Telling_MovesTheWorldsStoryOnlyWhereItSetsTheProgress()
    {
        var progress = new WorldProgress(null);
        EventPage breaker = Page(1019, 3, 0);
        EventPage route = Page(1767, 66, 0);
        int write = route.List.ToList().FindIndex(command => command.Code == EventCodes.ControlVariables && command.Number(0) == 1141);

        Assert.False(progress.Ahead(_source, breaker.List, 0));
        Assert.True(progress.Ahead(_source, route.List, 0));
        Assert.False(progress.Ahead(_source, route.List, write + 1));
    }

    /// <summary>
    /// Asserts that a page that asks by the game's extended choices (77:13, whose script command
    /// shows them and whose first answer takes the player to another map) counts that window as a
    /// choice, as it does a Show Choices: the branches on its answer are the choice's, so the transfer
    /// behind one makes the page travel in a new game too, whose answer variable holds no answer.
    /// </summary>
    [Fact]
    public void ExtendedChoices_AreChoices()
    {
        EventPage page = Page(77, 13, 0);
        EventCommand shows = page.List.Single(command => command.Code == EventCodes.Script && command.TextKind == TextKind.Choice);

        Assert.Equal(9, shows.Number(0));
        Assert.Equal(EventKind.Travel, _sorter.Decide(page.List, Site(77, page), new NewGame()).Kind);
    }

    /// <inheritdoc />
    public void Dispose() => _store.Dispose();

    /// <summary>
    /// Reads a map event's page from the shipped database.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page, from 0.</param>
    /// <returns>The page; the test fails when the database lacks it.</returns>
    private EventPage Page(int map, int eventId, int page) =>
        _source.Page(map, eventId, page) ?? throw new InvalidOperationException($"The shipped events database lacks map:{map}:{eventId}:{page + 1}.");

    /// <summary>
    /// Names where a page runs, its texts telling nothing.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="page">The page.</param>
    /// <returns>The site.</returns>
    private static EventSite Site(long map, EventPage page) => new(map, null, page.Trigger, PageTexts.None);

    /// <summary>
    /// Decides a page in a new game's state.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="site">Where it runs.</param>
    /// <returns>Its kind and whether it may turn into story behind a choice.</returns>
    private (EventKind Kind, bool MayTell) KindAndTell(EventPage page, EventSite site)
    {
        EventDecision decision = _sorter.Decide(page.List, site, new NewGame());
        return (decision.Kind, decision.MayTell);
    }

    /// <summary>
    /// A new game's values: every switch off but those named, every variable 0, nothing the player's
    /// own but the variables named.
    /// </summary>
    /// <param name="switches">The switches on.</param>
    /// <param name="personalVariables">The variables the player keeps as their own.</param>
    private sealed class NewGame(IReadOnlyCollection<long>? switches = null, IReadOnlyCollection<long>? personalVariables = null) : IEventState
    {
        /// <inheritdoc />
        public bool Switch(long id) => switches?.Contains(id) == true;

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => personalVariables?.Contains(id) == true;
    }
}
