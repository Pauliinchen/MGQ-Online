//----------------------------------------------------------------
//  QuestWalkTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the quest walk over a tiny game with Amira's objective, her two lists of side quests and
/// the Pocket Castle's board.
/// </summary>
/// <remarks>Each common event starts with the mark the game puts first in its list, as the events database keeps it.</remarks>
public sealed class QuestWalkTests
{
    /// <summary>
    /// Amira's objective: her opening and her network's hint stay out, the branch of the story's
    /// step counts with the event it calls and past the label it jumps to, and her lists of side
    /// quests are left to the side quests.
    /// </summary>
    private static readonly object[][] Objective =
    [
        At(999, 0, QuestWalk.ObjectiveEvent),
        .. Say(0, "Let's see, your current primary objective is..."),
        At(111, 0, 1, QuestWalk.NetworkVariable, 0, 1, 2), .. Say(1, "Give me some time."), At(115, 1), At(412, 0),
        At(111, 0, 1, 1001, 0, 10, 0), .. Say(1, "Cross the mountains."), At(117, 1, 120), At(119, 1, "tip"), .. Say(1, "Never told."),
        At(118, 1, "tip"), .. Say(1, "Buy golden equipment."), At(412, 0),
        At(111, 0, 1, 1143, 0, 20, 2), At(117, 1, 131), At(115, 1), At(412, 0),
        At(111, 0, 1, 1143, 0, 21, 1), At(117, 1, 135), At(412, 0),
    ];

    /// <summary>
    /// The event Amira's objective calls.
    /// </summary>
    private static readonly object[][] Called = [At(999, 0, 120), .. Say(0, "Then take the eastern pass.")];

    /// <summary>
    /// Amira's first list: an entry with a remark between, an entry behind an item not held and
    /// one behind her network.
    /// </summary>
    private static readonly object[][] FirstList =
    [
        At(999, 0, 131),
        .. Say(0, "I have some other information."),
        At(111, 0, 0, 2018, 1), Mark(1), .. Say(1, "Strange crying near Iliasville."), At(111, 1, 0, 6, 0), .. Say(2, "She sounds scary."),
        At(411, 1), .. Say(2, "Never told."), At(412, 1), At(412, 0),
        At(111, 0, 8, 151), At(411, 0), Mark(1), .. Say(1, "Iron ore in the Pornof mines."), At(412, 0),
        At(111, 0, 1, QuestWalk.NetworkVariable, 0, 3, 1), Mark(1), .. Say(1, "The engineer wants makina."), At(412, 0),
    ];

    /// <summary>
    /// Amira's second list, from the Chaos route's step 21.
    /// </summary>
    private static readonly object[][] SecondList = [At(999, 0, 135), Mark(0), .. Say(0, "Chaos errands.")];

    /// <summary>
    /// The board's page of requests: one behind a script's check, one behind a companion in the party.
    /// </summary>
    private static readonly object[][] Board =
    [
        At(111, 0, 12, "actor_class_level_over?(1, 151, 10)"), Mark(1), .. Say(1, "Homework."), At(412, 0),
        At(111, 0, 4, 56, 0), Mark(1), .. Say(1, "Take me to Harpy Village."), At(412, 0),
    ];

    /// <summary>
    /// Asserts that the walk tells what the game would show now, in each message's list and place,
    /// and names every message alike from the events database and from the game's own data.
    /// </summary>
    [Fact]
    public void Walk_TellsTheQuestsAsTheGameRunsThem_AlikeFromTheDatabaseAndTheGamesOwnData()
    {
        TinyGame game = Game();
        var state = new Values(new Dictionary<long, long> { [1001] = 10, [QuestWalk.NetworkVariable] = 3 }, [6], [56]);

        QuestPlaces own = QuestWalk.Walk(new GameDataSource(game.Data()), state);
        QuestPlaces stored = QuestWalk.Walk(EventDatabases.SourceOf(game), state);

        Assert.Equal(["Cross the mountains.", "Then take the eastern pass.", "Buy golden equipment."], own.Main.Select(TextOf));
        Assert.Equal([["Strange crying near Iliasville.", "She sounds scary."], ["Iron ore in the Pornof mines."], ["The engineer wants makina."]], own.Sides.Select(Texts));
        Assert.Equal([["Take me to Harpy Village."]], own.Companions.Select(Texts));
        Assert.Equal(ReplaySite.Page(QuestWalk.BoardMap, QuestWalk.BoardEvent, 1), own.Board);
        Assert.Equal(Flat(own), Flat(stored));
    }

    /// <summary>
    /// Asserts that from the Chaos route's step 21 the side quests come from Amira's second list.
    /// </summary>
    [Fact]
    public void Walk_TakesTheSecondListFromTheChaosRoutesStep()
    {
        var state = new Values(new Dictionary<long, long> { [1143] = QuestWalk.ChaosSideStep }, [], []);

        QuestPlaces places = QuestWalk.Walk(new GameDataSource(Game().Data()), state);

        Assert.Equal([["Chaos errands."]], places.Sides.Select(Texts));
    }

    /// <summary>
    /// Builds the tiny game.
    /// </summary>
    /// <returns>The game.</returns>
    private static TinyGame Game() => new TinyGame()
        .Common(QuestWalk.ObjectiveEvent, Objective).Common(120, Called).Common(QuestWalk.SideEvents[0], FirstList).Common(QuestWalk.SideEvents[1], SecondList)
        .MapEvent(QuestWalk.BoardMap, QuestWalk.BoardEvent, 0, 0, new TinyPage([]), new TinyPage(Board));

    /// <summary>
    /// Writes a message: the command that shows a face, then its line.
    /// </summary>
    /// <param name="indent">Its indent.</param>
    /// <param name="text">Its line.</param>
    /// <returns>The two commands.</returns>
    private static object[][] Say(int indent, string text) => [At(101, indent, "amira_fc1", 0, 0, 2), At(401, indent, text)];

    /// <summary>
    /// Writes the mark at the start of a quest.
    /// </summary>
    /// <param name="indent">Its indent.</param>
    /// <returns>The command.</returns>
    private static object[] Mark(int indent) => At(122, indent, QuestWalk.QuestCount, QuestWalk.QuestCount, 0, 0, 1);

    /// <summary>
    /// Looks a message up as the scripts do: the line after the kept command at its place.
    /// </summary>
    /// <param name="message">The message.</param>
    /// <returns>Its line.</returns>
    private static string TextOf(QuestMessage message)
    {
        object[][] list = message.Site.IsCommon
            ? message.Site.CommonId switch { QuestWalk.ObjectiveEvent => Objective, 120 => Called, 131 => FirstList, _ => SecondList }
            : Board;
        List<int> kept = [.. Enumerable.Range(0, list.Length).Where(index => EventSchema.Keeps((int)list[index][0]))];
        return (string)((object[])list[kept[message.Place] + 1][2])[0];
    }

    /// <summary>
    /// Looks a quest's messages up.
    /// </summary>
    /// <param name="quest">The quest.</param>
    /// <returns>Their lines.</returns>
    private static string[] Texts(IReadOnlyList<QuestMessage> quest) => [.. quest.Select(TextOf)];

    /// <summary>
    /// Lists every message of a walk, the objective's first.
    /// </summary>
    /// <param name="places">The walk.</param>
    /// <returns>The messages.</returns>
    private static QuestMessage[] Flat(QuestPlaces places) => [.. places.Main, .. places.Sides.SelectMany(quest => quest), .. places.Companions.SelectMany(quest => quest)];

    /// <summary>
    /// A game's live values: variables, the switches on and the party's characters; the party holds no item.
    /// </summary>
    /// <param name="variables">The variables set, the others 0.</param>
    /// <param name="switches">The switches on.</param>
    /// <param name="party">The party's characters.</param>
    private sealed class Values(Dictionary<long, long> variables, long[] switches, long[] party) : IQuestState
    {
        /// <inheritdoc />
        public bool Switch(long id) => switches.Contains(id);

        /// <inheritdoc />
        public long? Variable(long id) => variables.GetValueOrDefault(id);

        /// <inheritdoc />
        public bool InParty(long actor) => party.Contains(actor);

        /// <inheritdoc />
        public bool Holds(long item) => false;
    }
}
