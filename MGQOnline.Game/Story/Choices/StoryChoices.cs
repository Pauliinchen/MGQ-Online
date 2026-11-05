//----------------------------------------------------------------
//  StoryChoices.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the story's ids from StoryIds
//                            - Left the self switches of the Navy's and the Pirates' lines to the reviewed key list
//      Paulinchen  2026-11-01: Took Succubus Village's outcomes and notes from the walk of the game's data
//      Paulinchen  2026-10-31: Left every choice a stream hands the run of to the replay
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Story.Choices;

/// <summary>
/// The values of a story the rules read: which of <see cref="ChoiceTable.ReadSwitches"/> are on,
/// the <see cref="ChoiceTable.ReadVariables"/>, and which of <see cref="ChoiceTable.ReadRoster"/>
/// are in the player's roster.
/// </summary>
/// <param name="SwitchesOn">The switches on.</param>
/// <param name="Variables">The variables, 0 for one never set.</param>
/// <param name="Roster">The companions in the roster.</param>
public sealed record ChoiceValues(IReadOnlySet<int> SwitchesOn, IReadOnlyDictionary<int, int> Variables, IReadOnlySet<int> Roster)
{
    /// <summary>
    /// Reads a switch.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is on.</returns>
    public bool Switch(int id) => SwitchesOn.Contains(id);

    /// <summary>
    /// Reads a variable.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its value, 0 for one never set.</returns>
    public int Variable(int id) => Variables.TryGetValue(id, out int value) ? value : 0;
}

/// <summary>
/// What the rules read of the game beside a story's values: whether a Raid World is open, the
/// install's endings, the route a Raid World took at the Great Decision and the routes it may still
/// take.
/// </summary>
/// <param name="Raid">Whether a Raid World is open.</param>
/// <param name="Values">The story's values.</param>
/// <param name="Ending1">Whether the install cleared the first ending.</param>
/// <param name="Ending2">Whether the install cleared the second ending.</param>
/// <param name="RaidRoute">The route a Raid World took as it carried the player past the decision, <see langword="null"/> for none waiting.</param>
/// <param name="WorldRoutes">The routes a Raid World may still take, <see langword="null"/> while unknown.</param>
/// <param name="Start">Where the stream that hands the player runs began: a Raid World's log start, or where a Classic member started keeping the leader's story; <see langword="null"/> for none.</param>
public sealed record ChoiceContext(bool Raid, ChoiceValues Values, bool Ending1, bool Ending2, int? RaidRoute, IReadOnlyList<int>? WorldRoutes, RunPlace? Start);

/// <summary>
/// What an outcome sets and brings, as the scripts write it into the story they play.
/// </summary>
/// <param name="Title">The choice's title.</param>
/// <param name="Label">The outcome's label.</param>
/// <param name="Switches">The switches, on or off.</param>
/// <param name="Variables">The variables.</param>
/// <param name="Least">The variables raised to a value at least.</param>
/// <param name="SelfSwitches">The self switches turned on.</param>
/// <param name="Joins">The companions it brings.</param>
/// <param name="Leaves">The companions it sends away.</param>
/// <param name="Ship">Where it puts the ship.</param>
public sealed record ChoiceWrites(string Title, string Label, IReadOnlyList<KeyValuePair<int, bool>> Switches, IReadOnlyList<KeyValuePair<int, int>> Variables,
    IReadOnlyList<KeyValuePair<int, int>> Least, IReadOnlyList<SelfSwitchKey> SelfSwitches, IReadOnlyList<int> Joins, IReadOnlyList<int> Leaves, ShipPlace? Ship);

/// <summary>
/// The switches and variables that are the player's own as choices' outcomes. The self switches of
/// the Navy's and the Pirates' lines are each Raid World player's own by the reviewed key list.
/// </summary>
/// <param name="Switches">The switches.</param>
/// <param name="Variables">The variables.</param>
public sealed record PersonalChoiceKeys(IReadOnlyList<int> Switches, IReadOnlyList<int> Variables);

/// <summary>
/// The rules of the story's choices a player makes for themselves (see
/// <see cref="ChoiceTable"/>): which a story carries them past, which the screen offers and what
/// each outcome brings and sets, which keys are their own, and the leader's offers to sync a story.
/// A choice a stream hands the run of is asked by the replay of that run ("Issue 73 chest effects.md",
/// rule 4), so only history from before the log is asked here and gets the frozen outcome rows.
/// </summary>
public static class StoryChoices
{
    /// <summary>
    /// Why the catch-up leaves out a choice's companion.
    /// </summary>
    private const string CompanionSkip = "a choice's companion, who comes with the player's own outcome";

    /// <summary>
    /// Reports whether a story made a choice already.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="values">The story's values.</param>
    /// <returns>Whether it did.</returns>
    public static bool Made(string key, ChoiceValues values) => key switch
    {
        ChoiceTable.Side => values.Switch(4) || values.Switch(5),
        ChoiceTable.Magistea => values.Switch(2096) || values.Switch(2097),
        ChoiceTable.Navy => values.Variable(1050) >= 9 || values.Variable(1051) >= 5,
        ChoiceTable.Plansect => values.Variable(1061) >= 1,
        ChoiceTable.Succubus => ChoiceTable.SuccubusOutcomes.Values.Any(outcome => Holds(outcome.Sign, values)),
        "spider" => values.Switch(2280) || values.Switch(2281),
        "sphinx" => values.Switch(2090) || values.Roster.Contains(ChoiceTable.Sphinx),
        ChoiceTable.Decision => values.Variable(StoryIds.MainProgress) >= StoryIds.GreatDecision,
        _ => false,
    };

    /// <summary>
    /// Reports whether a stream hands the player the run of a choice: one does, and the choice's
    /// point lies past the main story's progress where it began, which a story there had passed.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="start">Where the stream began, <see langword="null"/> for none.</param>
    /// <returns>Whether it does.</returns>
    public static bool Logged(string key, RunPlace? start) =>
        start is not null && ChoiceTable.Branch(key)!.Point > start.Markers[0];

    /// <summary>
    /// Lists the choices a catch-up from one point of the main story to another carries the player
    /// past, which they have not made in their own story and no stream hands the run of.
    /// </summary>
    /// <param name="from">The player's main story progress.</param>
    /// <param name="to">The progress they are brought to.</param>
    /// <param name="values">The player's own story.</param>
    /// <param name="start">Where the stream that hands the player runs began, <see langword="null"/> for none.</param>
    /// <returns>The choices, in story order.</returns>
    public static IReadOnlyList<string> Passed(int from, int to, ChoiceValues values, RunPlace? start) =>
        [.. ChoiceTable.Branches.Where(branch => from < branch.Point && to >= branch.Point && !Made(branch.Key, values) && !Logged(branch.Key, start)).Select(branch => branch.Key)];

    /// <summary>
    /// Lists the choices a part of a story the player plays carries them past, to ask their own
    /// outcome of: those passed but the side (which a Raid World's story nobody chose it in asks
    /// too) and the Great Decision, and those a change resolved, less those asked already and those
    /// a stream hands the run of.
    /// </summary>
    /// <param name="from">The main story's progress before.</param>
    /// <param name="to">The progress after.</param>
    /// <param name="changed">The switches and variables that changed, besides.</param>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="values">The player's own story.</param>
    /// <param name="waiting">The choices asked already.</param>
    /// <param name="start">Where the stream that hands the player runs began, <see langword="null"/> for none.</param>
    /// <returns>The choices to ask, in story order.</returns>
    public static IReadOnlyList<string> Prompts(int from, int to, IReadOnlyCollection<int> changed, bool raid, ChoiceValues values, IReadOnlyCollection<string> waiting, RunPlace? start)
    {
        var keys = new List<string>(Passed(from, to, values, start));
        keys.Remove(ChoiceTable.Decision);
        if (!raid)
        {
            keys.Remove(ChoiceTable.Side);
        }

        foreach (ChoiceBranch branch in ChoiceTable.Branches)
        {
            if (branch.Key is ChoiceTable.Side or ChoiceTable.Decision || keys.Contains(branch.Key) || Made(branch.Key, values))
            {
                continue;
            }

            (IReadOnlyList<int> switches, IReadOnlyList<int> variables) = ChoiceTable.KeysOf(branch);
            if (switches.Concat(variables).Any(changed.Contains))
            {
                keys.Add(branch.Key);
            }
        }

        return [.. keys.Where(key => !waiting.Contains(key) && !Logged(key, start))];
    }

    /// <summary>
    /// Lists the choices a later build added that a Raid World's story is past while the player's
    /// own save never made them, less those asked already and those a stream hands the run of.
    /// </summary>
    /// <param name="progress">The main story's progress of the story laid over the player's.</param>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="values">The player's story.</param>
    /// <param name="waiting">The choices asked already.</param>
    /// <param name="start">Where the stream that hands the player runs began, <see langword="null"/> for none.</param>
    /// <returns>The choices to ask.</returns>
    public static IReadOnlyList<string> Missed(int progress, bool raid, ChoiceValues values, IReadOnlyCollection<string> waiting, RunPlace? start) =>
        raid
            ? [.. ChoiceTable.LaterBranches.Where(key => progress >= ChoiceTable.Branch(key)!.Point && !Made(key, values) && !waiting.Contains(key) && !Logged(key, start))]
            : [];

    /// <summary>
    /// Reports whether both endings are cleared, which the third way of the Great Decision asks: the
    /// player's own save's, as the game's own event does; in a Raid World the world's two first
    /// routes, by its clear switches.
    /// </summary>
    /// <param name="context">The game.</param>
    /// <returns>Whether they are.</returns>
    public static bool BothEndings(ChoiceContext context) =>
        context.Raid ? ChoiceTable.RouteClears.All(context.Values.Switch) : context.Ending1 && context.Ending2;

    /// <summary>
    /// Lists the outcomes the screen offers for a choice: the third way only with both endings
    /// cleared; in a Raid World the routes of <see cref="DecisionRoutes"/>; of the Navy or the
    /// Pirates the side the player's own play took, see <see cref="NavySides"/>.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="context">The game.</param>
    /// <returns>The outcomes' labels, and each one's place in the choice's outcomes.</returns>
    public static (IReadOnlyList<string> Labels, IReadOnlyList<int> Outcomes) Offered(string key, ChoiceContext context)
    {
        IReadOnlyList<ChoiceOutcome> outcomes = ChoiceTable.Branch(key)!.Outcomes;
        IReadOnlyList<int> offered = key switch
        {
            ChoiceTable.Decision when context.Raid => DecisionRoutes(context),
            ChoiceTable.Navy => NavySides(context.Values),
            ChoiceTable.Decision when !BothEndings(context) => [0, 1],
            _ => [.. Enumerable.Range(0, outcomes.Count)],
        };
        return ([.. offered.Select(index => outcomes[index].Label)], offered);
    }

    /// <summary>
    /// Lists the outcomes of the Navy or the Pirates the player may still take: only the side their
    /// own play took at Navy Headquarters, whose companions joined them already, else both.
    /// </summary>
    /// <param name="values">The player's story.</param>
    /// <returns>The outcomes, by their place in the choice's outcomes.</returns>
    public static IReadOnlyList<int> NavySides(ChoiceValues values)
    {
        for (int side = 0; side < ChoiceTable.NavySides.Count; side++)
        {
            if (values.Switch(ChoiceTable.NavySides[side]))
            {
                return [side];
            }
        }

        return [0, 1];
    }

    /// <summary>
    /// Lists the Great Decision's outcomes the screen offers in a Raid World: the route the world
    /// took when it carried the player past the decision, else those the world may still take, else
    /// the two first routes, the third with both cleared.
    /// </summary>
    /// <param name="context">The game.</param>
    /// <returns>The outcomes, by their place in the decision's outcomes.</returns>
    public static IReadOnlyList<int> DecisionRoutes(ChoiceContext context)
    {
        if (context.RaidRoute is { } route)
        {
            return [route];
        }

        return context.WorldRoutes ?? (BothEndings(context) ? [0, 1, 2] : [0, 1]);
    }

    /// <summary>
    /// Writes what an outcome brings, for the screen's line below it.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="index">The outcome, its place among the labels offered.</param>
    /// <param name="answers">The answers given so far, by choice.</param>
    /// <param name="leaderRoute">The leader's route, its place in <see cref="StoryIds.Routes"/>, <see langword="null"/> before the Great Decision.</param>
    /// <param name="leaderName">The leader's name.</param>
    /// <param name="context">The game.</param>
    /// <returns>The line.</returns>
    public static string Note(string key, int index, IReadOnlyDictionary<string, int> answers, int? leaderRoute, string leaderName, ChoiceContext context)
    {
        switch (key)
        {
            case ChoiceTable.Succubus:
                return SuccubusOutcome(index, answers, context.Values).Note;
            case ChoiceTable.Decision:
                if (context.Raid)
                {
                    IReadOnlyList<int> routes = DecisionRoutes(context);
                    return Join(DecisionTexts(index < routes.Count ? routes[index] : index, context.Values), "The whole world plays this route.");
                }

                string follow = index == leaderRoute ? $"You follow {leaderName}'s route." : $"Not {leaderName}'s route: you start it and play it on your own.";
                return Join(DecisionTexts(index, context.Values), follow);
            default:
                IReadOnlyList<ChoiceOutcome> outcomes = ChoiceTable.Branch(key)!.Outcomes;
                return outcomes[OutcomeIndex(key, index, context.Values)].Note;
        }
    }

    /// <summary>
    /// Finds what an outcome sets, brings and sends away, as the scripts write it into the story they
    /// play: the frozen rows of a choice no stream hands the run of, with the departures of the
    /// player's playthrough; nothing for one a stream does, whose replay plays the game's own event.
    /// The side's outcome sets nothing here, as the scripts choose it through the party's story.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="index">The outcome, its place among the labels offered.</param>
    /// <param name="answers">The answers given, Magistea Village's among them.</param>
    /// <param name="context">The game.</param>
    /// <returns>The writes.</returns>
    public static ChoiceWrites Outcome(string key, int index, IReadOnlyDictionary<string, int> answers, ChoiceContext context)
    {
        ChoiceBranch branch = ChoiceTable.Branch(key)!;
        if (Logged(key, context.Start))
        {
            return new ChoiceWrites(branch.Title, Offered(key, context).Labels[index], [], [], [], [], [], [], null);
        }

        int playthrough = context.Values.Variable(StoryIds.Playthrough);
        if (key == ChoiceTable.Succubus)
        {
            ChoiceOutcome taken = SuccubusOutcome(index, answers, context.Values);
            return new ChoiceWrites(branch.Title, branch.Outcomes[index].Label, taken.Switches, taken.Variables, taken.Least, taken.SelfSwitches, taken.Joins, taken.LeavesOn(playthrough),
                taken.Ship);
        }

        ChoiceOutcome outcome = branch.Outcomes[OutcomeIndex(key, index, context.Values)];
        return new ChoiceWrites(branch.Title, Offered(key, context).Labels[index], outcome.Switches, outcome.Variables, outcome.Least, outcome.SelfSwitches, outcome.Joins,
            outcome.LeavesOn(playthrough), outcome.Ship);
    }

    /// <summary>
    /// Lists the switches and variables that are the player's own as choices' outcomes: in a Raid
    /// World every choice's; while a
    /// Classic party's member plays the leader's story, those of every choice their own story made,
    /// so the leader's story never overwrites them.
    /// </summary>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="own">The member's own story kept aside, <see langword="null"/> while they play their own.</param>
    /// <returns>The keys.</returns>
    public static PersonalChoiceKeys Personal(bool raid, ChoiceValues? own)
    {
        if (!raid && own is null)
        {
            return new PersonalChoiceKeys([], []);
        }

        var switches = new List<int>();
        var variables = new List<int>();
        foreach (ChoiceBranch branch in ChoiceTable.Branches)
        {
            if (!raid && !Made(branch.Key, own!))
            {
                continue;
            }

            (IReadOnlyList<int> found, IReadOnlyList<int> values) = ChoiceTable.KeysOf(branch);
            switches.AddRange(found.Where(id => !switches.Contains(id)));
            variables.AddRange(values.Where(id => !variables.Contains(id)));
        }

        return new PersonalChoiceKeys(switches, variables);
    }

    /// <summary>
    /// Tells why the catch-up leaves out a reward: a choice's companion, who comes with the player's
    /// own outcome.
    /// </summary>
    /// <param name="kind">The reward's kind: "skills", "actors" or "items".</param>
    /// <param name="id">The reward.</param>
    /// <returns>The reason, <see langword="null"/> to give it.</returns>
    public static string? SkipReason(string kind, int id) => kind == "actors" && ChoiceTable.ChoiceCompanions.Contains(id) ? CompanionSkip : null;

    /// <summary>
    /// Tells why a leader may not offer a member to bring their story up to the leader's: only one
    /// whose game tells its progress, who does not follow the leader's story yet and is behind it.
    /// </summary>
    /// <param name="name">The member's name.</param>
    /// <param name="theirs">How far the member's story is, <see langword="null"/> while their game tells none.</param>
    /// <param name="own">How far the leader's is.</param>
    /// <param name="follows">Whether the member follows the leader's story.</param>
    /// <returns>The reason, <see langword="null"/> when an offer is possible.</returns>
    public static string? OfferRefusal(string name, IReadOnlyList<int>? theirs, IReadOnlyList<int> own, bool follows)
    {
        if (theirs is null)
        {
            return $"{name}'s story is not known yet.";
        }

        if (follows)
        {
            return $"{name} follows your story already.";
        }

        if (theirs.SequenceEqual(own) || theirs.Where((value, index) => value > own[index]).Any())
        {
            return $"{name} is not behind you in the story.";
        }

        return null;
    }

    /// <summary>
    /// Lists the leader's offers that ran out: those standing <see cref="ChoiceTable.OfferFrames"/>
    /// or made before a loaded save's lower frame count.
    /// </summary>
    /// <param name="now">The frame.</param>
    /// <param name="offers">Each offer's member and the frame it was made at.</param>
    /// <returns>The members whose offers ran out, in order.</returns>
    public static IReadOnlyList<string> Lapsed(long now, IReadOnlyList<KeyValuePair<string, long>> offers) =>
        [.. offers.Where(offer => now - offer.Value >= ChoiceTable.OfferFrames || now < offer.Value).Select(offer => offer.Key)];

    /// <summary>
    /// Finds the outcome an answer picks, given as its place among the labels offered.
    /// </summary>
    /// <param name="key">The choice.</param>
    /// <param name="index">The answer.</param>
    /// <param name="values">The player's story.</param>
    /// <returns>The outcome's place in the choice's outcomes.</returns>
    private static int OutcomeIndex(string key, int index, ChoiceValues values)
    {
        if (key != ChoiceTable.Navy)
        {
            return index;
        }

        IReadOnlyList<int> sides = NavySides(values);
        return index < sides.Count ? sides[index] : index;
    }

    /// <summary>
    /// Picks the outcome of Succubus Village a side brings: whether its companion joins follows Lily
    /// or Lucia being with the player.
    /// </summary>
    /// <param name="side">The side, 0 Natasha's, 1 the mayor's.</param>
    /// <param name="answers">The answers given so far.</param>
    /// <param name="values">The player's story.</param>
    /// <returns>The outcome.</returns>
    private static ChoiceOutcome SuccubusOutcome(int side, IReadOnlyDictionary<string, int> answers, ChoiceValues values)
    {
        (bool lily, bool lucia) = MagisteaCompanions(answers, values);
        return ChoiceTable.SuccubusOutcomes[(side, side == 0 ? lily : lucia)];
    }

    /// <summary>
    /// Tells whether a story holds the values that tell a walked outcome apart, such as
    /// <c>s2280 s2281</c> or <c>v1061=3</c>.
    /// </summary>
    /// <param name="sign">The values.</param>
    /// <param name="values">The story.</param>
    /// <returns>Whether it does.</returns>
    private static bool Holds(string sign, ChoiceValues values) =>
        sign.Split(' ', System.StringSplitOptions.RemoveEmptyEntries).All(part => part.Split('=') switch
        {
            [string variable, string value] => values.Variable(int.Parse(variable[1..], System.Globalization.CultureInfo.InvariantCulture)) == int.Parse(value, System.Globalization.CultureInfo.InvariantCulture),
            [string key] => values.Switch(int.Parse(key[1..], System.Globalization.CultureInfo.InvariantCulture)),
            _ => false,
        });

    /// <summary>
    /// Reports whether Lily is with the player once Magistea Village is decided, by the screen's
    /// answer, else by their own story or roster, and whether Lucia is.
    /// </summary>
    /// <param name="answers">The answers given so far.</param>
    /// <param name="values">The player's story.</param>
    /// <returns>Whether Lily is with them, and whether Lucia is.</returns>
    private static (bool Lily, bool Lucia) MagisteaCompanions(IReadOnlyDictionary<string, int> answers, ChoiceValues values)
    {
        if (answers.TryGetValue(ChoiceTable.Magistea, out int answer))
        {
            return (answer == 1, answer == 0);
        }

        return (values.Switch(2097) || values.Roster.Contains(ChoiceTable.Lily), values.Switch(2096) || values.Roster.Contains(ChoiceTable.Lucia));
    }

    /// <summary>
    /// Names an outcome of the Great Decision and the companions it changes.
    /// </summary>
    /// <param name="index">The outcome.</param>
    /// <param name="values">The player's story.</param>
    /// <returns>The route, then the companions, empty when none change.</returns>
    private static string[] DecisionTexts(int index, ChoiceValues values) =>
        [ChoiceTable.RouteNames[index] + ".", values.Variable(StoryIds.Playthrough) > 0 ? string.Empty : ChoiceTable.RouteParties[index]];

    /// <summary>
    /// Joins the parts of a line, leaving the empty ones out.
    /// </summary>
    /// <param name="texts">The route and the companions.</param>
    /// <param name="last">The last part.</param>
    /// <returns>The line.</returns>
    private static string Join(string[] texts, string last) => string.Join(" ", texts.Append(last).Where(part => part.Length > 0));
}
