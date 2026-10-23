//----------------------------------------------------------------
//  RaidSquad.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;

namespace MGQOnline.Game.Squads;

/// <summary>
/// A Raid World's squad settings: whether Luka may be replaced, its formation size and how many
/// characters fight in the frontline of regular fights and of raids. Outside the relay's JSON they
/// are text, four whole numbers separated by spaces in that order, Luka 1 or 0, such as <c>0 4 1 1</c>.
/// </summary>
public static class RaidSquad
{
    /// <summary>
    /// The settings' name in the relay's JSON, and the word that starts the relay's text frame telling
    /// them, as Relay/README.md names it.
    /// </summary>
    public const string Name = "squad";

    /// <summary>
    /// The formation size that keeps the game's own.
    /// </summary>
    public const int OriginalFormation = 0;

    /// <summary>
    /// What the forms and the details call <see cref="OriginalFormation"/>.
    /// </summary>
    public const string OriginalFormationName = "Original";

    /// <summary>
    /// The settings of a Raid World that names none: Luka fixed, a team of four and one character
    /// in the frontline of regular fights and of raids.
    /// </summary>
    public const string Default = "0 4 1 1";

    /// <summary>
    /// The smallest formation size besides the game's own.
    /// </summary>
    public const int MinFormation = 4;

    /// <summary>
    /// The largest formation size.
    /// </summary>
    public const int MaxFormation = 8;

    /// <summary>
    /// The fewest characters in a frontline.
    /// </summary>
    public const int MinFront = 1;

    /// <summary>
    /// The most characters in a frontline.
    /// </summary>
    public const int MaxFront = 4;

    /// <summary>
    /// How many numbers the text holds.
    /// </summary>
    private const int Count = 4;

    /// <summary>
    /// The formation sizes a Raid World may set, in the order the forms offer them: the game's own,
    /// then from <see cref="MinFormation"/> to <see cref="MaxFormation"/>.
    /// </summary>
    public static IEnumerable<int> Formations => [OriginalFormation, .. Enumerable.Range(MinFormation, MaxFormation - MinFormation + 1)];

    /// <summary>
    /// The frontline sizes a Raid World may set, in the order the forms offer them.
    /// </summary>
    public static IEnumerable<int> Fronts => Enumerable.Range(MinFront, MaxFront - MinFront + 1);

    /// <summary>
    /// Tells whether a text holds valid settings.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it does.</returns>
    public static bool IsValid(string text) => Normalize(text) != null;

    /// <summary>
    /// Reads settings from text and writes them as this class does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The settings as text, <see langword="null"/> when the text holds no valid settings.</returns>
    public static string? Normalize(string text) => TryParse(text, out var luka, out var formation, out var front, out var raidFront) ? TextOf(luka, formation, front, raidFront) : null;

    /// <summary>
    /// Writes valid settings as the relay's JSON object.
    /// </summary>
    /// <param name="writer">The writer, inside the object that holds the settings.</param>
    /// <param name="text">The settings as text.</param>
    /// <exception cref="ArgumentException">The text holds no valid settings.</exception>
    public static void Write(Utf8JsonWriter writer, string text)
    {
        if (!TryParse(text, out var luka, out var formation, out var front, out var raidFront))
        {
            throw new ArgumentException($"'{text}' are no squad settings", nameof(text));
        }

        writer.WriteStartObject(Name);
        writer.WriteBoolean("luka", luka);
        writer.WriteNumber("formation", formation);
        writer.WriteNumber("front", front);
        writer.WriteNumber("raidFront", raidFront);
        writer.WriteEndObject();
    }

    /// <summary>
    /// Reads settings from the relay's JSON object.
    /// </summary>
    /// <param name="squad">The object.</param>
    /// <returns>The settings as text, empty when the object holds no valid settings.</returns>
    public static string TextOf(JsonElement squad)
    {
        if (squad.ValueKind != JsonValueKind.Object
            || !squad.TryGetProperty("luka", out var luka) || luka.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !NumberOf(squad, "formation", out var formation) || !NumberOf(squad, "front", out var front) || !NumberOf(squad, "raidFront", out var raidFront)
            || !InRange(formation, front, raidFront))
        {
            return string.Empty;
        }

        return TextOf(luka.GetBoolean(), formation, front, raidFront);
    }

    /// <summary>
    /// Reads settings from text.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="luka">Whether Luka may be replaced.</param>
    /// <param name="formation">The formation size, <see cref="OriginalFormation"/> for the game's own.</param>
    /// <param name="front">How many characters fight in the frontline of regular fights.</param>
    /// <param name="raidFront">How many characters fight in the frontline of raids.</param>
    /// <returns>Whether the text holds valid settings.</returns>
    public static bool TryParse(string text, out bool luka, out int formation, out int front, out int raidFront)
    {
        var words = text.Split(' ');
        var numbers = new int[Count];
        (luka, formation, front, raidFront) = (false, 0, 0, 0);

        if (words.Length != Count)
        {
            return false;
        }

        for (var index = 0; index < Count; index++)
        {
            if (!int.TryParse(words[index], NumberStyles.None, CultureInfo.InvariantCulture, out numbers[index]))
            {
                return false;
            }
        }

        (luka, formation, front, raidFront) = (numbers[0] == 1, numbers[1], numbers[2], numbers[3]);
        return numbers[0] is 0 or 1 && InRange(formation, front, raidFront);
    }

    /// <summary>
    /// Reads a whole number of the relay's JSON object.
    /// </summary>
    /// <param name="squad">The object.</param>
    /// <param name="name">The number's name.</param>
    /// <param name="value">The number.</param>
    /// <returns>Whether the object holds it as a whole number.</returns>
    private static bool NumberOf(JsonElement squad, string name, out int value)
    {
        value = 0;
        return squad.TryGetProperty(name, out var number) && number.ValueKind == JsonValueKind.Number && number.TryGetInt32(out value);
    }

    /// <summary>
    /// Tells whether the numbers of settings are in range.
    /// </summary>
    /// <param name="formation">The formation size.</param>
    /// <param name="front">How many characters fight in the frontline of regular fights.</param>
    /// <param name="raidFront">How many characters fight in the frontline of raids.</param>
    /// <returns>Whether they are.</returns>
    private static bool InRange(int formation, int front, int raidFront) =>
        formation is OriginalFormation or (>= MinFormation and <= MaxFormation) && front is >= MinFront and <= MaxFront && raidFront is >= MinFront and <= MaxFront;

    /// <summary>
    /// Writes settings as text.
    /// </summary>
    /// <param name="luka">Whether Luka may be replaced.</param>
    /// <param name="formation">The formation size.</param>
    /// <param name="front">How many characters fight in the frontline of regular fights.</param>
    /// <param name="raidFront">How many characters fight in the frontline of raids.</param>
    /// <returns>The text.</returns>
    public static string TextOf(bool luka, int formation, int front, int raidFront) =>
        string.Create(CultureInfo.InvariantCulture, $"{(luka ? 1 : 0)} {formation} {front} {raidFront}");
}
