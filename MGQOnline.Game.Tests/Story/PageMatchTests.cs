//----------------------------------------------------------------
//  PageMatchTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Named the choices by their code and number, without the shapes of the receiver's lists
//      Paulinchen  2026-11-01: Covered a choice whose answers differ only in what they take
//                            - Covered finding a choice by its place among the kept commands, after a text and in a list of another shape, and answers that jump
//      Paulinchen  2026-10-31: Covered whether a page gives and which choices the receiver is asked
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Data.Events;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the page a receiver's game shows for a run handed to it, over the events database of a
/// tiny game: the last page whose conditions hold, a sibling page that writes the step's keys, and
/// a run that waits; and the keys a run carries the start values of.
/// </summary>
public sealed class PageMatchTests
{
    /// <summary>
    /// A chest on map 1: page 1 gives and turns switch 40 on, page 2 shows once switch 5 is on and
    /// calls common event 20, which turns switch 40 on too, page 3 shows once its self switch A is on;
    /// an event beside it that shows only once switch 5 is on; two choices, the first one's
    /// answers turning on switch 10 or 11, the second one's switch 1001 or 1002, each with switch 10;
    /// two trades, the first one's "Pay" taking 100 G and item 3 for nothing the receiver keeps,
    /// the second one's taking 100 G for item 4; a choice a text of two lines sets up, whose second
    /// answer turns on switch 4; and a challenge whose first answer jumps to the battle, which turns
    /// on switch 2090 after the choice, and whose second answer leaves.
    /// </summary>
    private static readonly EventStore Store = EventDatabases.Of(new TinyGame()
        .MapEvent(1, 7, 0, 0,
            new TinyPage([C(126, 5, 0, 0, 1), C(121, 40, 40, 0), C(123, "A", 0)]),
            new TinyPage([C(117, 20)], Switch1: 5),
            new TinyPage([C(111, 1, 1001, 0, 7, 0)], SelfSwitch: "A"))
        .MapEvent(1, 8, 1, 0, new TinyPage([C(121, 40, 40, 0)], Switch1: 5))
        .MapEvent(1, 9, 2, 0, new TinyPage([
            C(102, "Yes", 2), C(402, 0, "Yes"), At(121, 1, 10, 10, 0), At(0, 1), C(402, 1, "No"), At(121, 1, 11, 11, 0), At(0, 1), C(404),
            C(102, "Yes", 2), C(402, 0, "Yes"), At(121, 1, 1001, 1001, 0), At(121, 1, 10, 10, 0), At(0, 1),
            C(402, 1, "No"), At(121, 1, 1002, 1002, 0), At(121, 1, 10, 10, 0), At(0, 1), C(404)]))
        .MapEvent(1, 10, 3, 0, new TinyPage([
            C(102, "Pay", 2), C(402, 0, "Pay"), At(125, 1, 1, 0, 100), At(126, 1, 3, 1, 0, 1), At(0, 1), C(402, 1, "No"), At(0, 1), C(404),
            C(102, "Pay", 2), C(402, 0, "Pay"), At(125, 1, 1, 0, 100), At(126, 1, 4, 0, 0, 1), At(0, 1), C(402, 1, "No"), At(0, 1), C(404)]))
        .MapEvent(1, 11, 4, 0, new TinyPage([
            C(101, "", 0, 0, 2), C(401, "Take her along?"), C(401, "She waits."), C(102, "Reconsider", 1),
            C(402, 0, "Reconsider"), At(0, 1), C(402, 1, "Take her along"), At(121, 1, 4, 4, 0), At(0, 1), C(404)]))
        .MapEvent(1, 12, 5, 0, new TinyPage([
            C(102, "Challenge her", 1), C(402, 0, "Challenge her"), At(119, 1, "Battle"), At(0, 1), C(402, 1, "Leave"), At(115, 1), At(0, 1), C(404),
            C(115), C(118, "Battle"), C(121, 2090, 2090, 0)]))
        .Common(20, C(111, 1, 1020, 0, 2, 0), C(121, 40, 40, 0))
        .Files());

    /// <summary>
    /// The receiver's pages read from <see cref="Store"/>.
    /// </summary>
    private readonly PageMatch _match = new(Store);

    /// <summary>
    /// The keys of the step of a run of page 1: its self switch A and switch 40.
    /// </summary>
    private static readonly StoryKey[] Step = [StoryKey.SelfSwitch(1, 7, "A"), StoryKey.Switch(40)];

    /// <summary>
    /// Asserts that the receiver's game replays the run's page while it is the last page whose
    /// conditions hold, and a sibling page that writes a key of the step, through a common event too.
    /// </summary>
    [Fact]
    public void Pick_ReplaysThePageOrASiblingThatWritesTheStep()
    {
        ReplaySite chest = ReplaySite.Page(1, 7, 0);

        Assert.Equal(new PagePick(PickResult.Replay, 0), _match.Pick(chest, new State(), Step));
        Assert.Equal(new PagePick(PickResult.Sibling, 1), _match.Pick(chest, new State("s5"), Step));
    }

    /// <summary>
    /// Asserts that a run waits when the page shown writes no key of the step, as a chest the
    /// receiver opened shows, or when no page shows.
    /// </summary>
    [Fact]
    public void Pick_WaitsWhenNoPageFits()
    {
        Assert.Equal(new PagePick(PickResult.OtherPage, 2), _match.Pick(ReplaySite.Page(1, 7, 0), new State("ss1.7.A"), Step));
        Assert.Equal(PickResult.NoPage, _match.Pick(ReplaySite.Page(1, 8, 0), new State(), Step).Result);
    }

    /// <summary>
    /// Asserts that a run carries the start values of the keys any page of its event can read:
    /// page conditions, branches, a called common event's reads and the event's self switches, of
    /// the scopes asked for.
    /// </summary>
    [Fact]
    public void ReadKeys_CoverEveryPageOfTheEvent()
    {
        IReadOnlyList<StoryKey> keys = _match.ReadKeys(ReplaySite.Page(1, 7, 0), key => key != StoryKey.SelfSwitch(1, 7, "D"));

        Assert.Equal("s5,ss1.7.A,ss1.7.B,ss1.7.C,v1001,v1020", string.Join(",", [.. Names(keys)]));
    }

    /// <summary>
    /// Asserts that a page gives when it or a common event it calls adds to what a player holds, or
    /// writes a key a player keeps.
    /// </summary>
    [Fact]
    public void Gives_WhenThePageAddsToHoldingsOrWritesAKeyAPlayerKeeps()
    {
        Assert.True(_match.Gives(ReplaySite.Page(1, 7, 0), _ => false));
        Assert.False(_match.Gives(ReplaySite.Page(1, 7, 1), _ => false));
        Assert.True(_match.Gives(ReplaySite.Page(1, 7, 1), key => key == StoryKey.Switch(40)));
    }

    /// <summary>
    /// Asserts that a choice is the receiver's when its answers do different things to the keys the
    /// receiver keeps, and the opener's when they differ only in keys the world keeps.
    /// </summary>
    [Fact]
    public void IsReceivers_WhenTheAnswersDifferInTheReceiversOwnKeys()
    {
        Func<StoryKey, bool> own = key => key.Kind == StoryKeyKind.Switch && key.Id < 1000;
        ReplaySite site = ReplaySite.Page(1, 9, 0);

        Assert.True(_match.IsReceivers(site, "map:1:9:1@102:0", own));
        Assert.False(_match.IsReceivers(site, "map:1:9:1@102:1", own));
    }

    /// <summary>
    /// Asserts that a choice whose answers differ only in what they take is the opener's, since a
    /// replay takes nothing, and one whose answers differ in what they give the receiver's.
    /// </summary>
    [Fact]
    public void IsReceivers_NotWhenTheAnswersDifferOnlyInWhatTheyTake()
    {
        ReplaySite site = ReplaySite.Page(1, 10, 0);

        Assert.False(_match.IsReceivers(site, "map:1:10:1@102:0", _ => false));
        Assert.True(_match.IsReceivers(site, "map:1:10:1@102:1", _ => false));
    }

    /// <summary>
    /// Asserts that a choice a text sets up is found by its number among the list's Show Choices,
    /// and asked; a command that is no choice finds nothing, so the opener's answer stands.
    /// </summary>
    [Fact]
    public void ChoiceOf_FindsTheChoiceByItsNumberAmongTheShowChoices()
    {
        ReplaySite site = ReplaySite.Page(1, 11, 0);
        Func<StoryKey, bool> own = key => key == StoryKey.Switch(4);

        Assert.Equal((Store.Page(1, 11, 0)!.Value.ListId, 3), _match.ChoiceOf("map:1:11:1@102:0"));
        Assert.True(_match.IsReceivers(site, "map:1:11:1@102:0", own));
        Assert.Null(_match.ChoiceOf("map:1:11:1@101:0"));
    }

    /// <summary>
    /// Asserts that a choice whose answer jumps to a label does what follows the label, so a
    /// challenge whose battle stands after the choice is the receiver's.
    /// </summary>
    [Fact]
    public void IsReceivers_FollowsAnAnswerThatJumpsToALabel()
    {
        ReplaySite site = ReplaySite.Page(1, 12, 0);

        Assert.True(_match.IsReceivers(site, "map:1:12:1@102:0", key => key == StoryKey.Switch(2090)));
        Assert.False(_match.IsReceivers(site, "map:1:12:1@102:0", _ => false));
    }

    /// <summary>
    /// Names keys in order.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <returns>Their names, sorted.</returns>
    private static SortedSet<string> Names(IEnumerable<StoryKey> keys)
    {
        var names = new SortedSet<string>(System.StringComparer.Ordinal);
        foreach (StoryKey key in keys)
        {
            names.Add(key.ToString());
        }

        return names;
    }

    /// <summary>
    /// Asserts that the page that closes a chest is the one that turns its self switch on as a chest,
    /// or for a chest the game shuts by a switch the page that turns the switch on; none for a key no
    /// page closes.
    /// </summary>
    [Fact]
    public void ChestPage_FindsThePageThatClosesTheChest()
    {
        Assert.Equal(ReplaySite.Page(1, 7, 0), _match.ChestPage(StoryKey.SelfSwitch(1, 7, "A")));
        Assert.Equal(ReplaySite.Page(1, 7, 0), _match.ChestPage(StoryKey.Switch(40)));
        Assert.Null(_match.ChestPage(StoryKey.SelfSwitch(1, 8, "B")));
    }

    /// <summary>
    /// The receiver's values: the switches and self switches named are on, every variable 0.
    /// </summary>
    /// <param name="on">The keys that are on.</param>
    private sealed class State(params string[] on) : IReplayState
    {
        /// <summary>
        /// The keys that are on.
        /// </summary>
        private readonly HashSet<string> _on = [.. on];

        /// <inheritdoc />
        public bool Switch(long id) => _on.Contains(string.Create(CultureInfo.InvariantCulture, $"s{id}"));

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;

        /// <inheritdoc />
        public bool SelfSwitch(int map, int eventId, string letter) => _on.Contains(string.Create(CultureInfo.InvariantCulture, $"ss{map}.{eventId}.{letter}"));

        /// <inheritdoc />
        public bool HasItem(int item) => false;

        /// <inheritdoc />
        public bool InParty(int actor) => false;
    }
}
