//----------------------------------------------------------------
//  ChoiceTable.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the story's ids from StoryIds
//                            - Left the self switches of the Navy's and the Pirates' lines to the reviewed key list
//                            - Put the Spider Princess's choice at point 31, where the game offers her join
//      Paulinchen  2026-11-01: Took the outcomes of the branch events from the walk of the game's data
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Story.Choices;

/// <summary>
/// A self switch's key: its map, event and letter.
/// </summary>
/// <param name="Map">The map.</param>
/// <param name="Event">The event.</param>
/// <param name="Letter">The letter.</param>
public readonly record struct SelfSwitchKey(int Map, int Event, string Letter);

/// <summary>
/// Where an outcome puts the ship on the field.
/// </summary>
/// <param name="Map">The map.</param>
/// <param name="X">The x.</param>
/// <param name="Y">The y.</param>
public readonly record struct ShipPlace(int Map, int X, int Y);

/// <summary>
/// What an outcome of the Great Decision names: its route, the side's switch, where a game over
/// returns the player and the route's first map, the last three only for the two first routes.
/// </summary>
/// <param name="Route">The route, its place in <see cref="StoryIds.Routes"/>.</param>
/// <param name="Side">The switch of the side the route takes, <see langword="null"/> for the third way.</param>
/// <param name="Return">Where a game over returns the player, <see langword="null"/> for the third way.</param>
/// <param name="Map">The route's first map, <see langword="null"/> for the third way.</param>
public sealed record DecisionRoute(int Route, int? Side, int? Return, int? Map);

/// <summary>
/// What the walk of the game's data found an outcome of a branch event writes (see
/// ChoiceTable.Outcomes.cs and Tools/choice_outcomes.rb of the event checker).
/// </summary>
/// <param name="Branch">The choice's key.</param>
/// <param name="Sign">The values that tell the outcome apart, such as <c>v1061=3</c> or <c>s2280 s2281</c>.</param>
/// <param name="Switches">The switches it sets, on or off, in order.</param>
/// <param name="Variables">The variables it sets, in order.</param>
/// <param name="Least">The variables it raises to a value at least, in order.</param>
/// <param name="SelfSwitches">The self switches it turns on.</param>
/// <param name="Joins">The companions it brings.</param>
/// <param name="Leaves">The companions it sends away on the first playthrough.</param>
/// <param name="LaterLeaves">The companions it sends away on a later playthrough.</param>
/// <param name="Ship">Where it puts the ship, <see langword="null"/> for nowhere.</param>
public sealed record WalkedOutcome(string Branch, string Sign, IReadOnlyList<KeyValuePair<int, bool>> Switches, IReadOnlyList<KeyValuePair<int, int>> Variables,
    IReadOnlyList<KeyValuePair<int, int>> Least, IReadOnlyList<SelfSwitchKey> SelfSwitches, IReadOnlyList<int> Joins, IReadOnlyList<int> Leaves, IReadOnlyList<int> LaterLeaves,
    ShipPlace? Ship);

/// <summary>
/// The switches and variables a branch event's outcomes write that only its events write, which
/// are each player's own as the choice's (see <see cref="StoryChoices.Personal"/>).
/// </summary>
/// <param name="Branch">The choice's key.</param>
/// <param name="Switches">The switches.</param>
/// <param name="Variables">The variables.</param>
public sealed record WalkedKeys(string Branch, IReadOnlyList<int> Switches, IReadOnlyList<int> Variables);

/// <summary>
/// An outcome of a choice: the label and the note the decision screen shows, and the frozen rows of
/// what it sets and brings, which only a choice from before the save's log applies (see
/// <see cref="StoryChoices.Logged"/>).
/// </summary>
/// <param name="Sign">The values that tell a walked outcome apart, empty for one of the side or the Great Decision.</param>
/// <param name="Label">What the screen calls it.</param>
/// <param name="Note">What it brings, for the screen's line below it.</param>
/// <param name="Switches">The switches it sets, on or off, in order.</param>
/// <param name="Variables">The variables it sets, in order.</param>
/// <param name="Least">The variables it raises to a value at least, in order.</param>
/// <param name="SelfSwitches">The self switches it turns on.</param>
/// <param name="Joins">The companions it brings.</param>
/// <param name="Leaves">The companions it sends away on the first playthrough.</param>
/// <param name="LaterLeaves">The companions it sends away on a later playthrough.</param>
/// <param name="Ship">Where it puts the ship, <see langword="null"/> for nowhere.</param>
/// <param name="Decision">What it names as an outcome of the Great Decision, <see langword="null"/> for another choice's.</param>
public sealed record ChoiceOutcome(string Sign, string Label, string Note, IReadOnlyList<KeyValuePair<int, bool>> Switches, IReadOnlyList<KeyValuePair<int, int>> Variables,
    IReadOnlyList<KeyValuePair<int, int>> Least, IReadOnlyList<SelfSwitchKey> SelfSwitches, IReadOnlyList<int> Joins, IReadOnlyList<int> Leaves, IReadOnlyList<int> LaterLeaves,
    ShipPlace? Ship, DecisionRoute? Decision)
{
    /// <summary>
    /// Lists the companions it sends away on a playthrough.
    /// </summary>
    /// <param name="playthrough">The playthrough's count (variable 912), 0 on the first.</param>
    /// <returns>The companions.</returns>
    public IReadOnlyList<int> LeavesOn(int playthrough) => playthrough == 0 ? Leaves : LaterLeaves;
}

/// <summary>
/// A choice of the story and its outcomes.
/// </summary>
/// <param name="Key">Its name.</param>
/// <param name="Title">What the screen calls it.</param>
/// <param name="Point">The main story's progress (variable 1001) from which it can be made.</param>
/// <param name="Hint">What the lines at the top say while the cursor is on it.</param>
/// <param name="Outcomes">Its outcomes.</param>
public sealed record ChoiceBranch(string Key, string Title, int Point, string Hint, IReadOnlyList<ChoiceOutcome> Outcomes);

/// <summary>
/// The story's choices a player makes for themselves, whatever the leader or the world chose: each
/// choice's labels, notes and hints for the decision screen, the frozen rows of its outcomes for
/// history from before the save's log, what Succubus Village brings by who is with the player, the
/// companions only a player's own outcome brings, and the routes of the Great Decision. The rows of
/// the branch events come from the walk of the game's data in ChoiceTable.Outcomes.cs.
/// </summary>
public static partial class ChoiceTable
{
    /// <summary>
    /// The key of the choice of Alice or Ilias.
    /// </summary>
    public const string Side = "side";

    /// <summary>
    /// The key of the choice of Magistea Village.
    /// </summary>
    public const string Magistea = "magistea";

    /// <summary>
    /// The key of the choice of the Navy or the Pirates.
    /// </summary>
    public const string Navy = "navy";

    /// <summary>
    /// The key of the choice of Plansect.
    /// </summary>
    public const string Plansect = "plansect";

    /// <summary>
    /// The key of the choice of Succubus Village.
    /// </summary>
    public const string Succubus = "succubus";

    /// <summary>
    /// The key of the Great Decision.
    /// </summary>
    public const string Decision = "decision";

    /// <summary>
    /// Frames an offer of the leader stands, a minute.
    /// </summary>
    public const int OfferFrames = 3600;

    /// <summary>
    /// The companions Magistea Village's outcomes bring: Lily and Lucia.
    /// </summary>
    public const int Lily = 163;
    public const int Lucia = 167;

    /// <summary>
    /// The Sphinx, whom her choice may bring.
    /// </summary>
    public const int Sphinx = 153;

    /// <summary>
    /// The switches that tell the world cleared the two first routes, which open the third way in a
    /// Raid World.
    /// </summary>
    public static readonly IReadOnlyList<int> RouteClears = [.. StoryIds.ClearSwitches.Take(2)];

    /// <summary>
    /// The switches each side of the Navy or the Pirates turns on as the player takes it in their own
    /// play: once one is on, only that side's outcome is offered.
    /// </summary>
    public static readonly IReadOnlyList<int> NavySides = [2148, 2149];

    /// <summary>
    /// The outcomes the walk of the game's data found, by the choice's key and the values that tell
    /// each apart.
    /// </summary>
    internal static readonly IReadOnlyDictionary<(string Branch, string Sign), WalkedOutcome> WalkedRows =
        WalkedOutcomes().ToDictionary(outcome => (outcome.Branch, outcome.Sign));

    /// <summary>
    /// The switches and variables each branch event's outcomes write that only its events write,
    /// by the choice's key.
    /// </summary>
    private static readonly IReadOnlyDictionary<string, WalkedKeys> WalkedKeysRows = WalkedBranchKeys().ToDictionary(keys => keys.Branch);

    /// <summary>
    /// The companions the choices bring, which come only with the player's own outcome, never as
    /// the leader holds them.
    /// </summary>
    public static readonly IReadOnlyList<int> ChoiceCompanions = [.. WalkedRows.Values.SelectMany(outcome => outcome.Joins).Distinct()];

    /// <summary>
    /// The choices a later build added, which saves from earlier builds are past without having made
    /// them.
    /// </summary>
    public static readonly IReadOnlyList<string> LaterBranches = [Navy];

    /// <summary>
    /// The routes' names, by the Great Decision's outcome.
    /// </summary>
    public static readonly IReadOnlyList<string> RouteNames = ["Angelic Dominion route", "Monster Realm route", "Chaos route"];

    /// <summary>
    /// The companions each outcome of the Great Decision changes on a first playthrough, by outcome.
    /// </summary>
    public static readonly IReadOnlyList<string> RouteParties =
    [
        "Alice, Alicetroemeria and Morrigan join; Ilias's companions leave.",
        "Ilias, Micaela-chan, Lucifina-chan, Eden and Heinrich join; Alice's companions leave.",
        string.Empty,
    ];

    /// <summary>
    /// The switches, variables and companions the rules read of a story, in the order a request
    /// names them.
    /// </summary>
    public static readonly IReadOnlyList<int> ReadSwitches = [.. StoryIds.SideSwitches, 2090, 2096, 2097, 2148, 2149, 2210, 2211, 2212, 2213, 2280, 2281, .. RouteClears];
    public static readonly IReadOnlyList<int> ReadVariables = [StoryIds.Playthrough, StoryIds.MainProgress, 1050, 1051, 1061];
    public static readonly IReadOnlyList<int> ReadRoster = [153, 163, 167];

    /// <summary>
    /// The choices, in story order.
    /// </summary>
    public static readonly IReadOnlyList<ChoiceBranch> Branches =
    [
        new(Side, "Alice or Ilias", 7, "Iliasville: whom Luka takes along on his journey, his side until the Great Decision.",
        [
            Outcome("Take Alice along", "Alice joins.", [On(StoryIds.SideSwitches[0]), Off(StoryIds.SideSwitches[1])], joins: [5]),
            Outcome("Take Ilias along", "Ilias joins.", [Off(StoryIds.SideSwitches[0]), On(StoryIds.SideSwitches[1])], joins: [26]),
        ]),
        new(Magistea, "Magistea Village", 17, "Magistea Village: whom Luka defeats, Lily or Lucia. The other joins.",
        [
            Walked(Magistea, "s2096", "Defeat Lily", "Lucia joins."),
            Walked(Magistea, "s2097", "Defeat Lucia", "Lily joins."),
        ]),
        new(Navy, "Navy or Pirates", 22, "Navy Headquarters: whether Luka helps the Navy catch the Fishy Pirates or sails with them. Either side gives him a ship.",
        [
            Walked(Navy, "s2148", "Cooperate with the Navy", "Bonnie and Ashel are caught. Tatsuko and Stacy join, and the Navy's ship is yours."),
            Walked(Navy, "s2149", "Aid the Fishy Pirates", "Ashel and Bonnie join, and the MS Fish and the Dark Saber are yours."),
        ]),
        new(Plansect, "Plansect", 24, "Plansect: whose side Luka takes, the plants' Priestess or the insects' Queen Bee, or whether he makes peace between them.",
        [
            Walked(Plansect, "v1061=1", "Side with the Priestess", "The Queen Bee is defeated. The Priestess joins."),
            Walked(Plansect, "v1061=2", "Side with the Queen Bee", "The Priestess is defeated. Miria, the Queen Bee, joins."),
            Walked(Plansect, "v1061=3", "Make peace between them", "The Priestess and Miria, the Queen Bee, both join."),
        ]),
        new(Succubus, "Succubus Village", 27, "Succubus Village: whom Luka allies with. Who joins depends on Lily or Lucia.",
        [
            Outcome("Ally with Natasha", string.Empty, []),
            Outcome("Ally with the mayor", string.Empty, []),
        ]),
        new("spider", "The Spider Princess", 31, "The Secluded Lands: whose side Luka takes, the Spider Princess or the Queen Ants.",
        [
            Walked("spider", "s2280", "Side with the Spider Princess", "The Spider Princess joins. On a first playthrough, Miria and Antine Ann leave."),
            Walked("spider", "s2280 s2281", "Side with the Queen Ants", "The Spider Princess still joins. On a first playthrough, Miria and Antine Ann leave."),
        ]),
        new("sphinx", "The Sphinx", 31, "The Pyramid: Luka challenges the Sphinx, who joins once defeated.",
        [
            Walked("sphinx", "s2090", "Challenge her", "The Sphinx is defeated and joins."),
        ]),
        new(Decision, "The Great Decision", StoryIds.GreatDecision, "The Monster Lord's Castle: whose side Luka takes, which decides the route of the Final Chapter.",
        [
            Outcome("Side with the Dark Goddess (World Breaker)", string.Empty, [], decision: new DecisionRoute(0, StoryIds.SideSwitches[0], StoryIds.ReturnPoints[0], StoryIds.DecisionMaps[0])),
            Outcome("Side with the Goddess Ilias (Judgement)", string.Empty, [], decision: new DecisionRoute(1, StoryIds.SideSwitches[1], StoryIds.ReturnPoints[1], StoryIds.DecisionMaps[1])),
            Outcome("Search for a third way (Chaos)", string.Empty, [], decision: new DecisionRoute(2, null, null, null)),
        ]),
    ];

    /// <summary>
    /// The outcomes of Succubus Village, by the side taken (0 Natasha's, 1 the mayor's) and whether
    /// Lily (with Natasha) or Lucia (with the mayor) is with the player, which the game's own
    /// branch reads.
    /// </summary>
    public static readonly IReadOnlyDictionary<(int Side, bool With), ChoiceOutcome> SuccubusOutcomes = new Dictionary<(int, bool), ChoiceOutcome>
    {
        [(0, true)] = Walked(Succubus, "s2210", "Ally with Natasha", "Natasha joins, as Lily is with you."),
        [(0, false)] = Walked(Succubus, "s2211", "Ally with Natasha", "Nobody joins: Natasha joins only while Lily is with you."),
        [(1, true)] = Walked(Succubus, "s2212", "Ally with the mayor", "The mayor joins, as Lucia is with you."),
        [(1, false)] = Walked(Succubus, "s2213", "Ally with the mayor", "Nobody joins: the mayor joins only while Lucia is with you."),
    };

    /// <summary>
    /// Finds a choice by its name.
    /// </summary>
    /// <param name="key">Its name.</param>
    /// <returns>The choice, <see langword="null"/> for none.</returns>
    public static ChoiceBranch? Branch(string key)
    {
        foreach (ChoiceBranch branch in Branches)
        {
            if (branch.Key == key)
            {
                return branch;
            }
        }

        return null;
    }

    /// <summary>
    /// Lists the switches and variables that are a choice's own, each once, in order: for a branch
    /// event those its outcomes write that only its events write, for the side every switch and
    /// variable an outcome sets.
    /// </summary>
    /// <param name="branch">The choice.</param>
    /// <returns>The switches, then the variables.</returns>
    public static (IReadOnlyList<int> Switches, IReadOnlyList<int> Variables) KeysOf(ChoiceBranch branch)
    {
        if (branch.Key == Decision)
        {
            return ([], []);
        }

        if (WalkedKeysRows.TryGetValue(branch.Key, out WalkedKeys? walked))
        {
            return (walked.Switches, walked.Variables);
        }

        var switches = new List<int>();
        var variables = new List<int>();
        foreach (ChoiceOutcome outcome in branch.Outcomes)
        {
            foreach (KeyValuePair<int, bool> pair in outcome.Switches)
            {
                if (!switches.Contains(pair.Key))
                {
                    switches.Add(pair.Key);
                }
            }

            foreach (KeyValuePair<int, int> pair in outcome.Variables)
            {
                if (!variables.Contains(pair.Key))
                {
                    variables.Add(pair.Key);
                }
            }
        }

        return (switches, variables);
    }

    /// <summary>
    /// Makes an outcome of a branch event from what the walk of the game's data found it writes; an
    /// outcome the walk no longer finds writes nothing, which ChoiceTableTests catch.
    /// </summary>
    /// <param name="branch">The choice's key.</param>
    /// <param name="sign">The values that tell the outcome apart.</param>
    /// <param name="label">What the screen calls it.</param>
    /// <param name="note">What it brings.</param>
    /// <returns>The outcome.</returns>
    private static ChoiceOutcome Walked(string branch, string sign, string label, string note) =>
        WalkedRows.TryGetValue((branch, sign), out WalkedOutcome? walked)
            ? new(sign, label, note, walked.Switches, walked.Variables, walked.Least, walked.SelfSwitches, walked.Joins, walked.Leaves, walked.LaterLeaves, walked.Ship, null)
            : new(sign, label, note, [], [], [], [], [], [], [], null, null);

    /// <summary>
    /// Makes an outcome.
    /// </summary>
    /// <param name="label">What the screen calls it.</param>
    /// <param name="note">What it brings.</param>
    /// <param name="switches">The switches it sets.</param>
    /// <param name="variables">The variables it sets.</param>
    /// <param name="least">The variables it raises to a value at least.</param>
    /// <param name="selfSwitches">The self switches it turns on.</param>
    /// <param name="joins">The companions it brings.</param>
    /// <param name="ship">Where it puts the ship.</param>
    /// <param name="decision">What it names as an outcome of the Great Decision.</param>
    /// <returns>The outcome.</returns>
    private static ChoiceOutcome Outcome(string label, string note, KeyValuePair<int, bool>[] switches, KeyValuePair<int, int>[]? variables = null, KeyValuePair<int, int>[]? least = null,
        SelfSwitchKey[]? selfSwitches = null, int[]? joins = null, ShipPlace? ship = null, DecisionRoute? decision = null) =>
        new(string.Empty, label, note, switches, variables ?? [], least ?? [], selfSwitches ?? [], joins ?? [], [], [], ship, decision);

    /// <summary>
    /// A switch turned on.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>The pair.</returns>
    private static KeyValuePair<int, bool> On(int id) => new(id, true);

    /// <summary>
    /// A switch turned off.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>The pair.</returns>
    private static KeyValuePair<int, bool> Off(int id) => new(id, false);

    /// <summary>
    /// A variable set to a value.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="value">The value.</param>
    /// <returns>The pair.</returns>
    private static KeyValuePair<int, int> Set(int id, int value) => new(id, value);
}
