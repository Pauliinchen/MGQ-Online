//----------------------------------------------------------------
//  PageFlags.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Moved the values of a new game into their own class
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Reads the flags of the map pages: each page's kind in a new game of a Classic party with its
/// chest letter, whether it shows only during a scene, runs nothing, fades the screen in or sets
/// random encounters.
/// </summary>
internal static class PageFlags
{
    /// <summary>
    /// The command that turns random encounters off (its first parameter 0) or on.
    /// </summary>
    private const int ChangeEncounter = 136;

    /// <summary>
    /// The commands a page holds when it runs nothing: its end and comments.
    /// </summary>
    private static readonly int[] QuietCodes = [0, 108, 408];

    /// <summary>
    /// Sets the derived flags of every map page and adds a chest row for each chest page.
    /// </summary>
    /// <remarks>
    /// The kinds are a new game's: no live page may be sorted by them, since the switches and
    /// variables a page's branches read change as the story goes on.
    /// </remarks>
    /// <param name="rows">The rows, whose pages get their flags.</param>
    /// <param name="game">The game.</param>
    /// <param name="classic">A Classic party's table, which tells the player's own switches and variables.</param>
    /// <param name="sceneSwitches">The switches the game's post-defeat processing writes, whose pages show only during a scene.</param>
    public static void Derive(EventRows rows, BuiltGame game, StoryTable classic, IReadOnlySet<int> sceneSwitches)
    {
        var sorter = new EventSorter(game);
        var state = new ClassicGameState(classic);
        for (int index = 0; index < rows.Pages.Count; index++)
        {
            PageRow page = rows.Pages[index];
            BuiltList list = game.Lists[page.ListId - 1];
            EventKind kind = sorter.KindOfPage(BuiltGame.PageOf(list, page), state);
            string? letter = kind == EventKind.Chest ? EventSorter.ChestLetter(list.Commands) : null;
            rows.Pages[index] = page with
            {
                KindNewGame = (int)kind,
                ChestLetter = letter,
                ScenePage = new[] { page.CondSwitch1, page.CondSwitch2 }.Any(id => id is { } found && sceneSwitches.Contains(found)),
                RunsNothing = list.Commands.All(command => QuietCodes.Contains(command.Code)),
                HasFadeIn = CommonFlags.FadesIn(list.Commands),
                SetsEncounters = SetsEncounters(list.Commands),
            };
            if (letter is not null)
            {
                rows.Chests.Add(new ChestRow(page.MapId, page.EventId, page.PageNo, letter, page.ListId));
            }
        }
    }

    /// <summary>
    /// Tells how a list sets random encounters.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <returns>Whether its last change turns them on; <see langword="null"/> for a list that changes them nowhere.</returns>
    private static bool? SetsEncounters(EventCommand[] commands) =>
        commands.LastOrDefault(command => command.Code == ChangeEncounter) is { Code: ChangeEncounter } last ? last.Number(0) != 0 : null;
}
