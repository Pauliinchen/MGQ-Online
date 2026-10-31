//----------------------------------------------------------------
//  Gives.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Frozen;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// A script of a list that adds to or takes from what a player holds.
/// </summary>
/// <param name="Idx">The place of the command that runs it.</param>
/// <param name="Adds">Whether it adds.</param>
internal readonly record struct HoldingScript(int Idx, bool Adds);

/// <summary>
/// Finds what the commands of the map pages and common events do to what a player holds: items,
/// gold, companions, skills, levels, experience, classes and medals ("Issue 73 chest effects.md",
/// "Gives"); the lists that add to it give.
/// </summary>
internal static partial class Gives
{
    /// <summary>
    /// The commands that change what a player holds: gold, items, weapons, armors, party members,
    /// experience, levels, skills and classes.
    /// </summary>
    private static readonly FrozenSet<int> HoldingCodes = new[]
    {
        EventCodes.ChangeGold, EventCodes.ChangeItems, EventCodes.ChangeWeapons, EventCodes.ChangeArmors, EventCodes.ChangePartyMember,
        ChangeExp, ChangeLevel, ChangeSkills, ChangeClass,
    }.ToFrozenSet();

    /// <summary>
    /// Change EXP, whose third parameter is 0 to raise.
    /// </summary>
    private const int ChangeExp = 315;

    /// <summary>
    /// Change Level, whose third parameter is 0 to raise.
    /// </summary>
    private const int ChangeLevel = 316;

    /// <summary>
    /// Change Skills, whose third parameter is 0 to learn.
    /// </summary>
    private const int ChangeSkills = 318;

    /// <summary>
    /// Change Class, which always sets one.
    /// </summary>
    private const int ChangeClass = 321;

    /// <summary>
    /// Finds the scripts of a list that touch what a player holds, by the methods their roots reach.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>The scripts, in their order.</returns>
    public static IReadOnlyList<HoldingScript> ScriptsOf(IReadOnlyList<RawCommand> list) =>
        [.. ScriptRoots.At(list)
            .Select(script => (script.Idx, Methods: script.Roots.Select(root => root[(root.LastIndexOf('.') + 1)..]).ToList()))
            .Where(script => script.Methods.Exists(method => Touching().IsMatch(method)))
            .Select(script => new HoldingScript(script.Idx, script.Methods.Exists(method => Adding().IsMatch(method))))];

    /// <summary>
    /// Tells whether a command changes what a player holds.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    public static bool Touches(EventCommand command) => HoldingCodes.Contains(command.Code);

    /// <summary>
    /// Tells whether a command adds to what a player holds: gold, items, weapons or armors gained, a
    /// member added, experience or levels raised, a skill learned, or a class set.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    public static bool Adds(EventCommand command) => command.Code switch
    {
        EventCodes.ChangeGold => command.Number(0) == 0,
        EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors or EventCodes.ChangePartyMember => command.Number(1) == 0,
        ChangeExp or ChangeLevel or ChangeSkills => command.Number(2) == 0,
        ChangeClass => true,
        _ => false,
    };

    /// <summary>
    /// Finds the map pages and common events that give: they, or a common event they call, add to
    /// what a player holds.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <returns>The lists, by id.</returns>
    public static IReadOnlyList<GivesRow> Of(BuiltGame game)
    {
        static bool OwnAdds(BuiltList list) => list.Commands.Any(Adds) || list.HoldingScripts.Any(script => script.Adds);
        IReadOnlySet<long> giving = Reaching(game, OwnAdds);
        return [.. Replayable(game).Where(list => OwnAdds(list) || BuiltGame.CallsOf(list).Any(giving.Contains)).Select(list => new GivesRow(list.Site.ListId))];
    }

    /// <summary>
    /// Finds the common events that touch what a player holds, themselves or by a common event they call.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <returns>Their ids.</returns>
    public static IReadOnlySet<long> TouchingCommons(BuiltGame game) =>
        Reaching(game, list => list.Commands.Any(Touches) || list.HoldingScripts.Count > 0);

    /// <summary>
    /// Lists the map pages and common events, the lists a run starts with or calls.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <returns>The lists, in their order.</returns>
    public static IEnumerable<BuiltList> Replayable(BuiltGame game) => game.Lists.Where(list => list.Site.Kind is ListKind.Page or ListKind.Common);

    /// <summary>
    /// Finds the common events that do something themselves or call one that does, through any
    /// number of calls.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="own">Tells whether a list does it itself.</param>
    /// <returns>The common events' ids.</returns>
    private static HashSet<long> Reaching(BuiltGame game, Func<BuiltList, bool> own)
    {
        var found = new HashSet<long>(game.CommonIds.Where(id => game.CommonListOf(id) is { } list && own(list)));
        var next = new Queue<long>(found);
        while (next.TryDequeue(out long id))
        {
            foreach (long caller in game.CallersOf(id).Where(found.Add))
            {
                next.Enqueue(caller);
            }
        }

        return found;
    }

    /// <summary>
    /// Matches the methods that change what a player holds.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("^(gain|lose|add|remove)_")]
    private static partial Regex Touching();

    /// <summary>
    /// Matches the methods that add to what a player holds.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("^(gain|add)_")]
    private static partial Regex Adding();
}
