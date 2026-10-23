//----------------------------------------------------------------
//  OverviewText.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Overview;

/// <summary>
/// The World overview's texts of the story and the title: a player's place in the story as a code
/// ("part", "part:side" or "part:route") and as the overview writes it, the world's place, and what
/// follows the world's name in the title.
/// </summary>
public static class OverviewText
{
    /// <summary>
    /// The part every route of the final chapter belongs to.
    /// </summary>
    public const string RoutePart = "3";

    /// <summary>
    /// What the World page says of the world's story before the relay told it.
    /// </summary>
    public const string StoryUntold = "Not told yet";

    /// <summary>
    /// What the World page says of a world that sets no difficulty, whose players keep their own.
    /// </summary>
    public const string PerPlayer = "Per player";

    /// <summary>
    /// What joins the world's name, its type and its difficulty in the title.
    /// </summary>
    public const string TitleJoint = " | ";

    /// <summary>
    /// The routes as the overview names them, in the order a player's own route is looked for.
    /// </summary>
    public static readonly IReadOnlyList<string> Routes = ["chaos", "destroyer", "judgment"];

    /// <summary>
    /// The sides as the overview names them, in the order they are looked for.
    /// </summary>
    public static readonly IReadOnlyList<string> Sides = ["ilias", "alice"];

    /// <summary>
    /// The overview's name of each route of <see cref="StoryParts.Routes"/>, by the variable that
    /// counts it: 1141 the Angelic Dominion's, 1142 the Monster Realm's, 1143 the Chaos route's.
    /// </summary>
    private static readonly IReadOnlyList<string> WorldRoutes = ["destroyer", "judgment", "chaos"];

    /// <summary>
    /// What the overview calls each side and route.
    /// </summary>
    private static readonly Dictionary<string, string> Names = new(StringComparer.Ordinal)
    {
        ["ilias"] = "Ilias side",
        ["alice"] = "Alice side",
        ["chaos"] = "Chaos route",
        ["destroyer"] = "Destroyer route",
        ["judgment"] = "Judgment route",
    };

    /// <summary>
    /// Finds a player's place in the story: the part, and the side chosen or, in Part 3, the route
    /// played.
    /// </summary>
    /// <param name="progress">The story's progress, variable 1001.</param>
    /// <param name="routes">How far each route of <see cref="Routes"/> is, by its name; a missing one counts as 0.</param>
    /// <param name="sides">Whether each side of <see cref="Sides"/> was chosen, by its name; a missing one counts as not.</param>
    /// <returns>The code, such as "1", "2:alice" or "3:destroyer".</returns>
    public static string StoryCode(long progress, IReadOnlyDictionary<string, long> routes, IReadOnlyDictionary<string, bool> sides)
    {
        string part = StoryParts.Of(progress, []);
        string? route = part == RoutePart ? Routes.FirstOrDefault(name => routes.TryGetValue(name, out long value) && value > 0) : null;
        string? chosen = route ?? Sides.FirstOrDefault(name => sides.TryGetValue(name, out bool on) && on);
        return chosen == null ? part : $"{part}:{chosen}";
    }

    /// <summary>
    /// Writes a place in the story the way the overview shows it.
    /// </summary>
    /// <param name="code">The code, see <see cref="StoryCode"/>; <see langword="null"/> while unknown.</param>
    /// <returns>Such as "Part 2: Alice side", empty while unknown.</returns>
    public static string StoryText(string? code)
    {
        string[] parts = (code ?? "").Split(':', 2);
        if (parts[0].Length == 0)
        {
            return "";
        }

        return parts.Length > 1 && Names.TryGetValue(parts[1], out string? name) ? $"Part {parts[0]}: {name}" : $"Part {parts[0]}";
    }

    /// <summary>
    /// Finds the world's place in the story from its part as the relay counts it, a route named as
    /// the player's own is; the side is each player's own, so the world has none.
    /// </summary>
    /// <param name="part">The part, see <see cref="StoryParts.Of"/>; <see langword="null"/> or empty before the relay told the story.</param>
    /// <returns>The code, such as "2" or "3:chaos"; empty before the relay told the story.</returns>
    public static string WorldStoryCode(string? part)
    {
        int route = part == null ? -1 : IndexOf(StoryParts.Routes, part);
        return route >= 0 ? $"{RoutePart}:{WorldRoutes[route]}" : part ?? "";
    }

    /// <summary>
    /// Writes the world's place in the story the way the World page shows it.
    /// </summary>
    /// <param name="part">The part, see <see cref="WorldStoryCode"/>.</param>
    /// <returns>Such as "Part 3: Chaos route", <see cref="StoryUntold"/> before the relay told the story.</returns>
    public static string WorldStoryText(string? part)
    {
        string code = WorldStoryCode(part);
        return code.Length == 0 ? StoryUntold : StoryText(code);
    }

    /// <summary>
    /// Writes what follows the world's name in the title: its type, and its difficulty when it sets one.
    /// </summary>
    /// <param name="raid">Whether it is a Raid World.</param>
    /// <param name="difficulty">The difficulty's name as the game's own choice names it, <see langword="null"/> while the players keep their own.</param>
    /// <returns>Such as " | Raid | Hard".</returns>
    public static string TitleTail(bool raid, string? difficulty) =>
        string.Concat(TitleParts(raid, difficulty).Select(part => TitleJoint + part));

    /// <summary>
    /// Writes the World page's note of the world: its type and its difficulty, or that each player keeps their own.
    /// </summary>
    /// <param name="raid">Whether it is a Raid World.</param>
    /// <param name="difficulty">The difficulty's name, see <see cref="TitleTail"/>.</param>
    /// <returns>Such as "Raid | Per player".</returns>
    public static string Note(bool raid, string? difficulty) =>
        string.Join(TitleJoint, TypeName(raid), difficulty == null ? PerPlayer : Capitalized(difficulty));

    /// <summary>
    /// Lists the title's parts after the name.
    /// </summary>
    /// <param name="raid">Whether it is a Raid World.</param>
    /// <param name="difficulty">The difficulty's name, see <see cref="TitleTail"/>.</param>
    /// <returns>The type, then the difficulty in plain case when there is one.</returns>
    private static IEnumerable<string> TitleParts(bool raid, string? difficulty)
    {
        yield return TypeName(raid);
        if (difficulty != null)
        {
            yield return Capitalized(difficulty);
        }
    }

    /// <summary>
    /// Names a world's type.
    /// </summary>
    /// <param name="raid">Whether it is a Raid World.</param>
    /// <returns>"Raid" or "Classic".</returns>
    private static string TypeName(bool raid) => raid ? "Raid" : "Classic";

    /// <summary>
    /// Writes a name in plain case as Ruby 1.9's <c>capitalize</c> does: the first letter upper case, the
    /// others lower case, ASCII letters only.
    /// </summary>
    /// <param name="name">The name, such as "VERY EASY".</param>
    /// <returns>Such as "Very easy".</returns>
    private static string Capitalized(string name) =>
        string.Concat(name.Select((character, index) => character is >= 'a' and <= 'z' && index == 0 ? (char)(character - 32)
            : character is >= 'A' and <= 'Z' && index > 0 ? (char)(character + 32) : character));

    /// <summary>
    /// Finds a text in a list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="text">The text.</param>
    /// <returns>Its index, -1 when the list lacks it.</returns>
    private static int IndexOf(IReadOnlyList<string> list, string text)
    {
        for (int index = 0; index < list.Count; index++)
        {
            if (list[index] == text)
            {
                return index;
            }
        }

        return -1;
    }
}
