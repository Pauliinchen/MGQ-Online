//----------------------------------------------------------------
//  CommonFlags.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Reads the flags of common events as story_rewards.rb does: the battlefuck events and the Final
/// Chapter's events.
/// </summary>
internal static partial class CommonFlags
{
    /// <summary>
    /// The first common event of the Chaos route, a part of the Final Chapter.
    /// </summary>
    public const int ChaosRouteEvents = 9000;

    /// <summary>
    /// The command that fades the screen in.
    /// </summary>
    public const int FadeIn = 222;

    /// <summary>
    /// The game's common events that count a battlefuck's win (6999) and its loss (7000), which
    /// every battlefucker's own events call.
    /// </summary>
    private static readonly long[] BattlefuckEndings = [6999, 7000];

    /// <summary>
    /// The variables of the routes after the Great Decision; a list that branches on one plays in
    /// the Final Chapter.
    /// </summary>
    private static readonly long[] RouteVariables = [1141, 1142, 1143];

    /// <summary>
    /// Finds the battlefuck events: those that count a battlefuck's win or loss, those that call one
    /// of those, again and again up to each battlefucker's talk, and the common events only those
    /// call, such as a battlefucker's scenes.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>Their ids.</returns>
    public static SortedSet<long> Battlefucks(BuiltGame game)
    {
        Dictionary<long, long[]> calls = game.CommonIds.ToDictionary(id => id, id => BuiltGame.CallsOf(game.CommonListOf(id)!).ToArray());
        var found = new HashSet<long>(BattlefuckEndings);
        while (calls.Where(pair => !found.Contains(pair.Key) && pair.Value.Any(found.Contains)).Select(pair => pair.Key).ToList() is { Count: > 0 } more)
        {
            found.UnionWith(more);
        }

        IEnumerable<long> elsewhere = calls.Where(pair => !found.Contains(pair.Key)).SelectMany(pair => pair.Value)
            .Concat(game.Lists.Where(list => list.Site.Kind != ListKind.Common).SelectMany(BuiltGame.CallsOf));
        IEnumerable<long> scenes = found.SelectMany(id => calls.GetValueOrDefault(id) ?? []).Except(found).Except(elsewhere);
        return [.. found.Concat(scenes)];
    }

    /// <summary>
    /// Tells whether a common event plays in the Final Chapter: the Great Decision and its resets
    /// by their names, the Chaos route's by their ids, and every one that branches on a route's
    /// progress.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <param name="name">Its name.</param>
    /// <param name="list">Its commands.</param>
    /// <returns>Whether it does.</returns>
    public static bool IsFinalChapter(int id, string name, IReadOnlyList<EventCommand> list) =>
        GreatDecision().IsMatch(name) || id >= ChaosRouteEvents
        || list.Any(command => command.Code == EventCodes.Branch && command.Number(0) == 1 && RouteVariables.Contains(command.Number(1)));

    /// <summary>
    /// Tells whether a list fades the screen in.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>Whether it does.</returns>
    public static bool FadesIn(IReadOnlyList<EventCommand> list) => list.Any(command => command.Code == FadeIn);

    /// <summary>
    /// The names of the common events of the Great Decision and its resets, in the translation and
    /// the untranslated game (大いなる決断).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("Great Decision|大いなる決断", RegexOptions.CultureInvariant)]
    private static partial Regex GreatDecision();
}
