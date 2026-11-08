//----------------------------------------------------------------
//  LocalWorld.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Text;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.Squads;

namespace MGQOnline.Multiplayer.Network.World;

/// <summary>
/// A world on this PC as its world.ini describes it: its name, world code, the directory's id of
/// it, its type, how a Raid World shares companions, its difficulty and squad rules, whether a
/// Classic world fights raid bosses, and when it was made and last played.
/// </summary>
/// <param name="Id">Its folder's id, see <see cref="WorldCode.IdOf"/>.</param>
/// <param name="Name">Its name.</param>
/// <param name="Code">Its world code, which lets its holder in.</param>
/// <param name="DirectoryId">The directory's id of it, <see langword="null"/> when world.ini names none.</param>
/// <param name="Created">When it was made, in seconds since 1970.</param>
/// <param name="PlayedAt">When it was played last, in seconds since 1970; <see langword="null"/> before.</param>
/// <param name="Type">Its type, see <see cref="WorldType"/>; <see langword="null"/> when world.ini names none, which counts as Classic.</param>
/// <param name="Share">How a Raid World shares companions, see <see cref="CompanionSharing"/>; <see langword="null"/> when world.ini names none.</param>
/// <param name="Difficulty">The difficulty a Raid World sets for every player, <see langword="null"/> when world.ini names none.</param>
/// <param name="Squad">The squad rules a Raid World sets as text (<see cref="RaidSquad"/>), <see langword="null"/> when world.ini names none.</param>
/// <param name="RaidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
internal sealed record LocalWorld(string Id, string Name, string Code, string? DirectoryId, long Created, long? PlayedAt, string? Type, string? Share, int? Difficulty, string? Squad, bool RaidBosses)
{
    /// <summary>
    /// The file inside a world's folder that describes it.
    /// </summary>
    public const string FileName = "world.ini";

    /// <summary>
    /// The name a world takes whose world.ini names none.
    /// </summary>
    public const string NoName = "?";

    /// <summary>
    /// What a name cleaned of everything stands in with, as the scripts' names do.
    /// </summary>
    public const string CleanedFallback = "A friend";

    /// <summary>
    /// Gets how many players the world seats at once, which its code tells; 0 for a code that tells none.
    /// </summary>
    public int Seats => WorldCode.Parse(Code)?.Seats ?? 0;

    /// <summary>
    /// Gets whether the world is a Raid World, as world.ini keeps it.
    /// </summary>
    public bool Raid => Type == WorldType.Raid;

    /// <summary>
    /// Reads a world from its world.ini.
    /// </summary>
    /// <param name="id">Its folder's id.</param>
    /// <param name="values">The values of its world.ini.</param>
    /// <returns>The world, <see langword="null"/> when they hold no world code of the folder.</returns>
    public static LocalWorld? Of(string id, IReadOnlyDictionary<string, string> values) =>
        values.TryGetValue("code", out string? code) && WorldCode.Parse(code) is { } parsed && WorldCode.IdOf(parsed.Token) == id ? Read(id, values) : null;

    /// <summary>
    /// Reads a world from its world.ini's values, as the scripts read them: a name of nothing but
    /// white space as <see cref="NoName"/>, numbers as Ruby's <c>to_i</c> reads them, and a
    /// difficulty or squad rules out of their ranges as none.
    /// </summary>
    /// <param name="id">Its folder's id.</param>
    /// <param name="values">The values.</param>
    /// <returns>The world.</returns>
    public static LocalWorld Read(string id, IReadOnlyDictionary<string, string> values)
    {
        string? name = values.GetValueOrDefault("name");
        return new LocalWorld(
            id,
            string.IsNullOrEmpty(RubyStrip(name ?? "")) ? NoName : PlayerIni.Cleaned(name, CleanedFallback),
            values.GetValueOrDefault("code") ?? "",
            values.GetValueOrDefault("world"),
            ToI(values.GetValueOrDefault("created")),
            values.TryGetValue("played", out string? played) ? ToI(played) : null,
            values.GetValueOrDefault("type"),
            values.GetValueOrDefault("share"),
            DifficultyOf(values.GetValueOrDefault("difficulty")),
            values.GetValueOrDefault("squad") is { } squad ? RaidSquad.Normalize(squad) : null,
            values.GetValueOrDefault("raid_bosses") == "1");
    }

    /// <summary>
    /// Reads a difficulty as world.ini or the list writes it: an optional minus and one digit.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The difficulty, <see langword="null"/> for none, another text or one out of range.</returns>
    public static int? DifficultyOf(string? text)
    {
        if (text is not ({ Length: 1 } or { Length: 2 }) || (text.Length == 2 && text[0] != '-') || !char.IsAsciiDigit(text[^1]))
        {
            return null;
        }

        int value = int.Parse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture);
        return WorldDifficulty.IsValid(value) ? value : null;
    }

    /// <summary>
    /// Writes the world's world.ini, in the order the scripts wrote it.
    /// </summary>
    /// <returns>The values by key.</returns>
    public IEnumerable<KeyValuePair<string, string>> Values()
    {
        yield return new("name", Name);
        yield return new("code", Code);
        yield return new("created", Created.ToString(CultureInfo.InvariantCulture));
        if (DirectoryId != null)
        {
            yield return new("world", DirectoryId);
        }

        if (Type != null)
        {
            yield return new("type", Type);
        }

        if (Share != null)
        {
            yield return new("share", Share);
        }

        if (Difficulty is { } difficulty)
        {
            yield return new("difficulty", difficulty.ToString(CultureInfo.InvariantCulture));
        }

        if (Squad != null)
        {
            yield return new("squad", Squad);
        }

        if (RaidBosses)
        {
            yield return new("raid_bosses", "1");
        }

        if (PlayedAt is { } at)
        {
            yield return new("played", at.ToString(CultureInfo.InvariantCulture));
        }
    }

    /// <summary>
    /// Takes the world's name, directory id, seats, type, companion sharing, difficulty, squad rules
    /// and raid bosses, as the directory says them.
    /// </summary>
    /// <param name="about">What the directory says; each <see langword="null"/> keeps what world.ini says.</param>
    /// <returns>The world described anew.</returns>
    public LocalWorld Described(LocalWorldAbout about)
    {
        string code = Code;
        if (about.Seats is { } seats and >= WorldCode.MinSeats and <= WorldCode.MaxSeats && WorldCode.Parse(Code) is { } parsed)
        {
            code = (parsed with { Seats = seats }).ToText();
        }

        return this with
        {
            Name = PlayerIni.Cleaned(about.Name, CleanedFallback),
            DirectoryId = about.DirectoryId,
            Code = code,
            Type = about.Type ?? Type,
            Share = about.Share ?? Share,
            Difficulty = about.Difficulty ?? Difficulty,
            Squad = about.Squad ?? Squad,
            RaidBosses = about.RaidBosses ?? RaidBosses,
        };
    }

    /// <summary>
    /// Strips a text as Ruby's <c>strip</c> does: ASCII white space and NUL.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The stripped text.</returns>
    private static string RubyStrip(string text) => text.Trim([' ', '\t', '\n', '\v', '\f', '\r', '\0']);

    /// <summary>
    /// Reads a number as Ruby's <c>to_i</c> does, 0 for none.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number, cut to a long.</returns>
    private static long ToI(string? text)
    {
        System.Numerics.BigInteger value = RubyNumbers.ToI(Encoding.UTF8.GetBytes(text ?? ""));
        return value > long.MaxValue ? long.MaxValue : value < long.MinValue ? long.MinValue : (long)value;
    }
}

/// <summary>
/// What the directory says of a world on this PC, which <see cref="LocalWorld.Described"/> takes.
/// </summary>
/// <param name="Name">Its name.</param>
/// <param name="DirectoryId">The directory's id of it.</param>
/// <param name="Seats">How many players it seats now, <see langword="null"/> to keep what the code tells.</param>
/// <param name="Type">Its type, <see langword="null"/> to keep what world.ini says.</param>
/// <param name="Share">How a Raid World shares companions, <see langword="null"/> to keep what world.ini says.</param>
/// <param name="Difficulty">A Raid World's difficulty, <see langword="null"/> to keep what world.ini says.</param>
/// <param name="Squad">A Raid World's squad rules as text, <see langword="null"/> to keep what world.ini says.</param>
/// <param name="RaidBosses">Whether a Classic world fights raid bosses, <see langword="null"/> to keep what world.ini says.</param>
internal sealed record LocalWorldAbout(string Name, string? DirectoryId, int? Seats, string? Type, string? Share, int? Difficulty, string? Squad, bool? RaidBosses);
