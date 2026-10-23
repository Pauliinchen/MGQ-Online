//----------------------------------------------------------------
//  StoryKey.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;

namespace MGQOnline.Game.Story;

/// <summary>
/// What a key of the story names.
/// </summary>
public enum StoryKeyKind
{
    /// <summary>A switch, <c>s&lt;id&gt;</c>.</summary>
    Switch,

    /// <summary>A variable, <c>v&lt;id&gt;</c>.</summary>
    Variable,

    /// <summary>A self switch, <c>ss&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;</c>.</summary>
    SelfSwitch,

    /// <summary>A frozen raid boss fight by its troop, <c>f&lt;troop&gt;</c>.</summary>
    Freeze,
}

/// <summary>
/// A key of the story as the relay's tracks name it (Relay/core/story_tracks.js <c>KEY</c>): a
/// switch, a variable or a frozen fight by id, or a self switch by map, event and letter, without
/// leading zeros.
/// </summary>
/// <param name="Kind">What it names.</param>
/// <param name="Id">The switch's, variable's or troop's id; the self switch's map.</param>
/// <param name="Event">The self switch's event, 0 for the other kinds.</param>
/// <param name="Letter">The self switch's letter, empty for the other kinds.</param>
public readonly record struct StoryKey(StoryKeyKind Kind, int Id, int Event = 0, string Letter = "")
{
    /// <summary>
    /// The highest id of a switch, variable, troop or self switch's map a key names.
    /// </summary>
    public const int MaxId = 99_999;

    /// <summary>
    /// The highest event of a self switch a key names.
    /// </summary>
    public const int MaxEvent = 999_999;

    /// <summary>
    /// The longest letter of a self switch a key names.
    /// </summary>
    public const int MaxLetter = 8;

    /// <summary>
    /// Makes a switch's key.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>The key.</returns>
    public static StoryKey Switch(int id) => new(StoryKeyKind.Switch, id);

    /// <summary>
    /// Makes a variable's key.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>The key.</returns>
    public static StoryKey Variable(int id) => new(StoryKeyKind.Variable, id);

    /// <summary>
    /// Makes a self switch's key.
    /// </summary>
    /// <param name="map">The map, 0 for the found items' self switches.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="letter">The letter.</param>
    /// <returns>The key.</returns>
    public static StoryKey SelfSwitch(int map, int eventId, string letter) => new(StoryKeyKind.SelfSwitch, map, eventId, letter);

    /// <summary>
    /// Reads a key as the tracks write it.
    /// </summary>
    /// <param name="text">The key, such as "s12", "v1001", "ss7.39.A" or "f868".</param>
    /// <param name="key">Receives the key.</param>
    /// <returns>Whether the text is a key.</returns>
    public static bool TryParse(string? text, out StoryKey key)
    {
        key = default;
        if (string.IsNullOrEmpty(text))
        {
            return false;
        }

        if (text.StartsWith("ss", StringComparison.Ordinal))
        {
            string[] parts = text[2..].Split('.');
            if (parts.Length != 3 || !TryId(parts[0], true, MaxId, out int map) || !TryId(parts[1], false, MaxEvent, out int eventId) || !IsLetter(parts[2]))
            {
                return false;
            }

            key = SelfSwitch(map, eventId, parts[2]);
            return true;
        }

        StoryKeyKind? kind = text[0] switch
        {
            's' => StoryKeyKind.Switch,
            'v' => StoryKeyKind.Variable,
            'f' => StoryKeyKind.Freeze,
            _ => null,
        };
        if (kind is null || !TryId(text[1..], false, MaxId, out int id))
        {
            return false;
        }

        key = new StoryKey(kind.Value, id);
        return true;
    }

    /// <summary>
    /// Writes the key as the tracks name it.
    /// </summary>
    /// <returns>Such as "s12" or "ss7.39.A".</returns>
    public override string ToString() => Kind switch
    {
        StoryKeyKind.Switch => string.Create(CultureInfo.InvariantCulture, $"s{Id}"),
        StoryKeyKind.Variable => string.Create(CultureInfo.InvariantCulture, $"v{Id}"),
        StoryKeyKind.Freeze => string.Create(CultureInfo.InvariantCulture, $"f{Id}"),
        _ => string.Create(CultureInfo.InvariantCulture, $"ss{Id}.{Event}.{Letter}"),
    };

    /// <summary>
    /// Reads an id without leading zeros.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <param name="zero">Whether 0 is an id, as the found items' map is.</param>
    /// <param name="most">The highest id.</param>
    /// <param name="id">Receives the id.</param>
    /// <returns>Whether the text is such an id.</returns>
    private static bool TryId(string text, bool zero, int most, out int id)
    {
        id = 0;
        if (text.Length == 0 || text.Length > 6 || (text[0] == '0' && (text.Length > 1 || !zero)))
        {
            return false;
        }

        foreach (char digit in text)
        {
            if (digit is < '0' or > '9')
            {
                return false;
            }

            id = (id * 10) + (digit - '0');
        }

        return id <= most;
    }

    /// <summary>
    /// Reports whether a text is a self switch's letter: 1 to <see cref="MaxLetter"/> ASCII letters,
    /// digits or underscores.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsLetter(string text)
    {
        if (text.Length == 0 || text.Length > MaxLetter)
        {
            return false;
        }

        foreach (char letter in text)
        {
            if (!(letter is (>= 'A' and <= 'Z') or (>= 'a' and <= 'z') or (>= '0' and <= '9') or '_'))
            {
                return false;
            }
        }

        return true;
    }
}
