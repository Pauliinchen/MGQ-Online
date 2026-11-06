//----------------------------------------------------------------
//  Emotes.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.World;

/// <summary>
/// An emote of the emote wheel.
/// </summary>
/// <param name="Name">What it is, shown below the wheel's ring.</param>
/// <param name="Balloon">The game's balloon it shows, <see langword="null"/> for a jump.</param>
public sealed record Emote(string Name, int? Balloon);

/// <summary>
/// The rules of the emotes, which ui_emotes.rbx draws and plays: the wheel's emotes, how soon the
/// player may play the next, and which emotes of other players their ghosts play.
/// </summary>
public sealed class Emotes
{
    /// <summary>
    /// Frames between two emotes of the player, so nobody floods the others with them.
    /// </summary>
    public const int CooldownFrames = 30;

    /// <summary>
    /// The frame of the player's last emote, <see langword="null"/> before the first.
    /// </summary>
    private long? _last;

    /// <summary>
    /// Gets the wheel's emotes, clockwise from the top, one per direction: a jump, then the game's
    /// balloons in Balloon.png's rows.
    /// </summary>
    public static IReadOnlyList<Emote> All { get; } =
    [
        new("Jump", null), new("Surprise", 1), new("Question", 2), new("Music", 3),
        new("Heart", 4), new("Anger", 5), new("Sweat", 6), new("Idea", 9),
    ];

    /// <summary>
    /// Plays an emote of the player unless the last was too soon, and counts the cooldown from it.
    /// </summary>
    /// <param name="index">The emote's place in <see cref="All"/>.</param>
    /// <param name="frame">The bridge's frame.</param>
    /// <returns>Why it may not play, <see langword="null"/> when it plays.</returns>
    public string? Play(int index, long frame)
    {
        if (index < 0 || index >= All.Count)
        {
            return $"no emote {index}";
        }

        if (frame - _last is { } elapsed && elapsed < CooldownFrames)
        {
            return $"{All[index].Name}: only {elapsed} of {CooldownFrames} frames since the last emote";
        }

        _last = frame;
        return null;
    }

    /// <summary>
    /// Tells why another player's ghost does not play their emote here.
    /// </summary>
    /// <param name="index">The emote's place in <see cref="All"/>, <see langword="null"/> for no number.</param>
    /// <param name="map">The map they played it on.</param>
    /// <param name="ownMap">The player's map.</param>
    /// <param name="ghost">Whether their ghost is on the player's map.</param>
    /// <returns>Why, <see langword="null"/> when their ghost plays it.</returns>
    public static string? Ignored(long? index, long map, long ownMap, bool ghost)
    {
        if (index is not { } place || place < 0 || place >= All.Count)
        {
            return $"emote {index?.ToString(System.Globalization.CultureInfo.InvariantCulture) ?? "nil"}: no such emote";
        }

        string name = All[(int)place].Name;
        if (!ghost)
        {
            return $"{name}: no ghost of theirs on this map";
        }

        return map == ownMap ? null : $"{name}: played on map {map}, the player is on {ownMap}";
    }
}
