//----------------------------------------------------------------
//  StoryParts.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Story;

/// <summary>
/// The parts of the game's story, as the relay's <c>partOf</c> (Relay/core/story.js) counts them:
/// the route under way, else Part 1 before Tartarus Escape, Part 2 before the Middle Chapter's
/// epilogue, else Part 3.
/// </summary>
public static class StoryParts
{
    /// <summary>
    /// The main story's progress, variable 1001, from which Part 2 runs, set by Tartarus Escape.
    /// </summary>
    public const long PartTwo = 19;

    /// <summary>
    /// The main story's progress from which Part 3 runs, set by the Middle Chapter's epilogue.
    /// </summary>
    public const long PartThree = 34;

    /// <summary>
    /// The routes as the relay names them, in the order of their variables 1141 to 1143 and of the
    /// Great Decision's outcomes.
    /// </summary>
    public static readonly IReadOnlyList<string> Routes = ["ad", "mr", "chaos"];

    /// <summary>
    /// Every part a story can be in: the three parts, then the routes.
    /// </summary>
    public static readonly IReadOnlyList<string> All = ["1", "2", "3", .. Routes];

    /// <summary>
    /// Finds the part a story is in.
    /// </summary>
    /// <param name="progress">The main story's progress, variable 1001.</param>
    /// <param name="routes">How far each route is, variables 1141 to 1143 in the order of <see cref="Routes"/>; fewer count as 0.</param>
    /// <returns>"1", "2", "3", or the first route under way.</returns>
    public static string Of(long progress, IReadOnlyList<long> routes)
    {
        for (int route = 0; route < Routes.Count && route < routes.Count; route++)
        {
            if (routes[route] > 0)
            {
                return Routes[route];
            }
        }

        return progress < PartTwo ? "1" : progress < PartThree ? "2" : "3";
    }
}
