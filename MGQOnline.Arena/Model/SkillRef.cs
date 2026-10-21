//----------------------------------------------------------------
//  SkillRef.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Names a skill: a skill of the game's database or a custom skill of the design.
/// </summary>
/// <remarks>Dictionaries and logs use <see cref="Key"/>, never the struct, so a key stays a plain string in JSON.</remarks>
/// <param name="Game">The game skill id, or null for a custom skill.</param>
/// <param name="Custom">The custom skill's 32 lowercase hex id, or null for a game skill.</param>
[JsonConverter(typeof(SkillRefJsonConverter))]
public readonly record struct SkillRef(int? Game, string? Custom)
{
    /// <summary>
    /// The prefix of a game skill's key.
    /// </summary>
    public const string GamePrefix = "game:";

    /// <summary>
    /// The prefix of a custom skill's key.
    /// </summary>
    public const string CustomPrefix = "custom:";

    /// <summary>
    /// The length of a custom skill id.
    /// </summary>
    public const int CustomIdLength = 32;

    /// <summary>
    /// Gets whether the reference names exactly one skill with a well-formed id.
    /// </summary>
    public bool IsValid => Game is int game ? game > 0 && Custom is null : Custom is not null && IsCustomId(Custom);

    /// <summary>
    /// Gets the key form, "game:1515" or "custom:" with the 32 hex id.
    /// </summary>
    /// <exception cref="InvalidOperationException">The reference is not valid.</exception>
    public string Key => IsValid
        ? Game is int game ? GamePrefix + game.ToString(CultureInfo.InvariantCulture) : CustomPrefix + Custom
        : throw new InvalidOperationException("The skill reference names no skill.");

    /// <summary>
    /// Makes a reference to a game skill.
    /// </summary>
    /// <param name="id">The game skill id, at least 1.</param>
    /// <returns>The reference.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The id is below 1.</exception>
    public static SkillRef OfGame(int id)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(id, 1);
        return new SkillRef(id, null);
    }

    /// <summary>
    /// Makes a reference to a custom skill.
    /// </summary>
    /// <param name="id">The custom skill's 32 lowercase hex id.</param>
    /// <returns>The reference.</returns>
    /// <exception cref="ArgumentException">The id is not 32 lowercase hex characters.</exception>
    public static SkillRef OfCustom(string id)
    {
        if (!IsCustomId(id))
        {
            throw new ArgumentException("A custom skill id is 32 lowercase hex characters.", nameof(id));
        }

        return new SkillRef(null, id);
    }

    /// <summary>
    /// Reads a key form.
    /// </summary>
    /// <param name="key">"game:" with a positive id, or "custom:" with a 32 hex id.</param>
    /// <returns>The reference.</returns>
    /// <exception cref="FormatException">The key is not a skill key.</exception>
    public static SkillRef Parse(string key) =>
        TryParse(key, out SkillRef skill) ? skill : throw new FormatException($"\"{key}\" is not a skill key.");

    /// <summary>
    /// Reads a key form without throwing.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="skill">The reference, or default when the key is not a skill key.</param>
    /// <returns>Whether the key is a skill key.</returns>
    public static bool TryParse(string? key, out SkillRef skill)
    {
        skill = default;
        if (key is null)
        {
            return false;
        }

        if (key.StartsWith(GamePrefix, StringComparison.Ordinal))
        {
            string digits = key[GamePrefix.Length..];
            if (digits.Length is 0 or > 9 || digits[0] == '0' || !IsDigits(digits))
            {
                return false;
            }

            skill = new SkillRef(int.Parse(digits, NumberStyles.None, CultureInfo.InvariantCulture), null);
            return true;
        }

        if (key.StartsWith(CustomPrefix, StringComparison.Ordinal) && IsCustomId(key[CustomPrefix.Length..]))
        {
            skill = new SkillRef(null, key[CustomPrefix.Length..]);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Tells whether a text is a custom skill id.
    /// </summary>
    /// <param name="id">The text.</param>
    /// <returns>Whether it is 32 lowercase hex characters.</returns>
    public static bool IsCustomId(string? id)
    {
        if (id is null || id.Length != CustomIdLength)
        {
            return false;
        }

        foreach (char character in id)
        {
            if (character is not (>= '0' and <= '9' or >= 'a' and <= 'f'))
            {
                return false;
            }
        }

        return true;
    }

    /// <inheritdoc />
    public override string ToString() => IsValid ? Key : "invalid skill";

    /// <summary>
    /// Tells whether a text holds only the digits 0 to 9.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether every character is an ASCII digit.</returns>
    private static bool IsDigits(string text)
    {
        foreach (char character in text)
        {
            if (character is not (>= '0' and <= '9'))
            {
                return false;
            }
        }

        return true;
    }
}
