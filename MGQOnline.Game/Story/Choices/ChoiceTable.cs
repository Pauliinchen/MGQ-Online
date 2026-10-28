//----------------------------------------------------------------
//  ChoiceTable.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

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
/// <param name="Route">The route, its place in <see cref="ChoiceTable.Routes"/>.</param>
/// <param name="Side">The switch of the side the route takes, <see langword="null"/> for the third way.</param>
/// <param name="Return">Where a game over returns the player, <see langword="null"/> for the third way.</param>
/// <param name="Map">The route's first map, <see langword="null"/> for the third way.</param>
public sealed record DecisionRoute(int Route, int? Side, int? Return, int? Map);

/// <summary>
/// An outcome of a choice: what it sets and brings.
/// </summary>
/// <param name="Label">What the screen calls it.</param>
/// <param name="Note">What it brings, for the screen's line below it.</param>
/// <param name="Switches">The switches it sets, on or off, in order.</param>
/// <param name="Variables">The variables it sets, in order.</param>
/// <param name="Least">The variables it raises to a value at least, in order.</param>
/// <param name="SelfSwitches">The self switches it turns on.</param>
/// <param name="Joins">The companions it brings.</param>
/// <param name="Ship">Where it puts the ship, <see langword="null"/> for nowhere.</param>
/// <param name="Decision">What it names as an outcome of the Great Decision, <see langword="null"/> for another choice's.</param>
public sealed record ChoiceOutcome(string Label, string Note, IReadOnlyList<KeyValuePair<int, bool>> Switches, IReadOnlyList<KeyValuePair<int, int>> Variables,
    IReadOnlyList<KeyValuePair<int, int>> Least, IReadOnlyList<SelfSwitchKey> SelfSwitches, IReadOnlyList<int> Joins, ShipPlace? Ship, DecisionRoute? Decision);

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
/// The story's choices a player makes for themselves, whatever the leader or the world chose, as
/// coop_choices.rbx kept them: each choice's outcomes, what Succubus Village brings by who is with
/// the player, the companions only a player's own outcome brings, and the routes of the Great
/// Decision.
/// </summary>
public static class ChoiceTable
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
    /// The key of the choice of Succubus Village.
    /// </summary>
    public const string Succubus = "succubus";

    /// <summary>
    /// The key of the Great Decision.
    /// </summary>
    public const string Decision = "decision";

    /// <summary>
    /// The main story's progress the Great Decision sets.
    /// </summary>
    public const int GreatDecision = 40;

    /// <summary>
    /// Frames an offer of the leader stands, a minute.
    /// </summary>
    public const int OfferFrames = 3600;

    /// <summary>
    /// The variable of the first playthrough, 0 while it is one.
    /// </summary>
    public const int Playthrough = 912;

    /// <summary>
    /// The variable of the main story's progress.
    /// </summary>
    public const int Progress = 1001;

    /// <summary>
    /// The variable Succubus Village's outcomes set.
    /// </summary>
    public const int SuccubusStep = 1065;

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
    /// The routes' progress variables, by the Great Decision's outcome.
    /// </summary>
    public static readonly IReadOnlyList<int> Routes = [1141, 1142, 1143];

    /// <summary>
    /// Where the Great Decision's third way takes the player: map, x, y and direction.
    /// </summary>
    public static readonly IReadOnlyList<int> ChaosStart = [437, 12, 12, 0];

    /// <summary>
    /// The switches that tell the world cleared the two first routes, which open the third way in a
    /// Raid World.
    /// </summary>
    public static readonly IReadOnlyList<int> RouteClears = [7096, 7097];

    /// <summary>
    /// The switches each side of the Navy or the Pirates turns on as the player takes it in their own
    /// play: once one is on, only that side's outcome is offered.
    /// </summary>
    public static readonly IReadOnlyList<int> NavySides = [2148, 2149];

    /// <summary>
    /// The maps of the Navy's and the Pirates' lines, whose self switches are each Raid World
    /// player's own, since each plays their own side.
    /// </summary>
    public static readonly IReadOnlyList<int> NavyMaps = [231, 232, 233, 667, 680, 685, 696, 701, 703, 708, 709];

    /// <summary>
    /// The self switches of the MS Fish's Ashel, each Raid World player's own.
    /// </summary>
    public static readonly IReadOnlyList<SelfSwitchKey> NavySelfSwitches = [new(376, 53, "A"), new(376, 53, "B")];

    /// <summary>
    /// Every switch the outcomes of Succubus Village set, which each of them sets on or off.
    /// </summary>
    public static readonly IReadOnlyList<int> SuccubusSwitches = [2210, 2211, 2212, 2213, 7007, 7008];

    /// <summary>
    /// The companions the choices bring, which come only with the player's own outcome, never as
    /// the leader holds them.
    /// </summary>
    public static readonly IReadOnlyList<int> ChoiceCompanions = [163, 167, 288, 287, 153, 241, 245, 334, 201, 202, 203, 204];

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
    public static readonly IReadOnlyList<int> ReadSwitches = [4, 5, 2090, 2096, 2097, 2148, 2149, 2210, 2211, 2212, 2213, 2280, 2281, 7096, 7097];
    public static readonly IReadOnlyList<int> ReadVariables = [912, 1001, 1050, 1051, 1061];
    public static readonly IReadOnlyList<int> ReadRoster = [153, 163, 167];

    /// <summary>
    /// The choices, in story order.
    /// </summary>
    public static readonly IReadOnlyList<ChoiceBranch> Branches =
    [
        new(Side, "Alice or Ilias", 7, "Iliasville: whom Luka takes along on his journey, his side until the Great Decision.",
        [
            Outcome("Take Alice along", "Alice joins.", [On(4), Off(5)], joins: [5]),
            Outcome("Take Ilias along", "Ilias joins.", [Off(4), On(5)], joins: [26]),
        ]),
        new(Magistea, "Magistea Village", 17, "Magistea Village: whom Luka defeats, Lily or Lucia. The other joins.",
        [
            Outcome("Defeat Lily", "Lucia joins.", [On(2096), On(7017), On(2095), Off(2097), Off(7016), Off(2094), On(2138), Off(2137)], [Set(1029, 6)], joins: [Lucia]),
            Outcome("Defeat Lucia", "Lily joins.", [On(2097), On(7016), On(2094), Off(2096), Off(7017), Off(2095), On(2137), Off(2138)], [Set(1029, 6)], joins: [Lily]),
        ]),
        new(Navy, "Navy or Pirates", 22, "Navy Headquarters: whether Luka helps the Navy catch the Fishy Pirates or sails with them. Either side gives him a ship.",
        [
            Outcome("Cooperate with the Navy", "Bonnie and Ashel are caught. Tatsuko and Stacy join, and the Navy's ship is yours.",
                [On(2148), Off(2149), On(2168), Off(2169), On(7001), On(7068)], [Set(1050, 9), Set(1051, 0), Set(1053, 0)], [Set(56, 2)], joins: [203, 204], ship: new ShipPlace(2, 334, 240)),
            Outcome("Aid the Fishy Pirates", "Ashel and Bonnie join, and the MS Fish and the Dark Saber are yours.",
                [On(2149), Off(2148), On(2168), On(2169), Off(7001), On(7068), On(2150)], [Set(1050, 6), Set(1051, 5), Set(1053, 0)], [Set(56, 2)],
                [new(709, 6, "A"), new(709, 15, "A"), new(376, 53, "A"), new(376, 53, "B")], [201, 202], new ShipPlace(2, 21, 211)),
        ]),
        new("plansect", "Plansect", 24, "Plansect: whose side Luka takes, the plants' Priestess or the insects' Queen Bee.",
        [
            Outcome("Side with the Priestess", "The Queen Bee is defeated. The Priestess joins.", [On(7003), Off(2154), Off(7002)], [Set(1061, 1), Set(1056, 6)], joins: [241]),
            Outcome("Side with the Queen Bee", "The Priestess is defeated. Miria, the Queen Bee, joins.", [On(2154), On(7002), Off(7003)], [Set(1061, 2), Set(1056, 6)], joins: [245]),
        ]),
        new(Succubus, "Succubus Village", 27, "Succubus Village: whom Luka allies with. Who joins depends on Lily or Lucia.",
        [
            Outcome("Ally with Natasha", string.Empty, []),
            Outcome("Ally with the mayor", string.Empty, []),
        ]),
        new("spider", "The Spider Princess", 30, "The Secluded Lands: whose side Luka takes, the Spider Princess or the Queen Ants.",
        [
            Outcome("Side with the Spider Princess", "The Spider Princess joins.", [On(2280), Off(2281)], joins: [334]),
            Outcome("Side with the Queen Ants", "Nobody joins.", [On(2281), Off(2280)]),
        ]),
        new("sphinx", "The Sphinx", 31, "The Pyramid: whether Luka challenges the Sphinx or invites her along.",
        [
            Outcome("Challenge her", "The Sphinx is defeated. Nobody joins.", [On(2090)]),
            Outcome("Invite her", "The Sphinx joins.", [], joins: [Sphinx]),
        ]),
        new(Decision, "The Great Decision", GreatDecision, "The Monster Lord's Castle: whose side Luka takes, which decides the route of the Final Chapter.",
        [
            Outcome("Side with the Dark Goddess (World Breaker)", string.Empty, [], decision: new DecisionRoute(0, 4, 111, 430)),
            Outcome("Side with the Goddess Ilias (Judgement)", string.Empty, [], decision: new DecisionRoute(1, 5, 112, 431)),
            Outcome("Search for a third way (Chaos)", string.Empty, [], decision: new DecisionRoute(2, null, null, null)),
        ]),
    ];

    /// <summary>
    /// The outcomes of Succubus Village, by the side taken (0 Natasha's, 1 the mayor's) and whether
    /// Lily (with Natasha) or Lucia (with the mayor) is with the player: the switches turned on and
    /// the companion who joins.
    /// </summary>
    public static readonly IReadOnlyDictionary<(int Side, bool With), (IReadOnlyList<int> On, IReadOnlyList<int> Joins)> SuccubusOutcomes = new Dictionary<(int, bool), (IReadOnlyList<int>, IReadOnlyList<int>)>
    {
        [(0, true)] = ([2210, 7007], [288]),
        [(0, false)] = ([2211, 7007], []),
        [(1, true)] = ([2212, 7008], [287]),
        [(1, false)] = ([2213, 7008], []),
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
    /// Lists every switch and variable an outcome of a choice sets, each once, in order.
    /// </summary>
    /// <param name="branch">The choice.</param>
    /// <returns>The switches, then the variables.</returns>
    public static (IReadOnlyList<int> Switches, IReadOnlyList<int> Variables) KeysOf(ChoiceBranch branch)
    {
        if (branch.Key == Succubus)
        {
            return (SuccubusSwitches, [SuccubusStep]);
        }

        if (branch.Key == Decision)
        {
            return ([], []);
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
        new(label, note, switches, variables ?? [], least ?? [], selfSwitches ?? [], joins ?? [], ship, decision);

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
