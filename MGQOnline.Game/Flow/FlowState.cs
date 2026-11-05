//----------------------------------------------------------------
//  FlowState.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Frozen;
using System.Collections.Generic;

namespace MGQOnline.Game.Flow;

/// <summary>
/// What the game's flow leaves of the screen, the player's character, the party and the bans at one
/// moment, as the scripts read it: the part of the game the mod's cuts of an event may leave behind.
/// </summary>
/// <param name="Map">The map the player stands on.</param>
/// <param name="Brightness">The screen's brightness, 0 for black to 255 for none dimmed.</param>
/// <param name="FadingIn">Whether the screen fades in now.</param>
/// <param name="Tone">The screen's tint.</param>
/// <param name="Hidden">Whether the player's character is hidden.</param>
/// <param name="Followers">Whether the player's followers show.</param>
/// <param name="TempParty">Whether a story's temporary party plays.</param>
/// <param name="Music">The music that plays, <see langword="null"/> for none known.</param>
/// <param name="Bans">The bans on now, by their names in <see cref="FlowBans"/>.</param>
/// <param name="Route">Whether a forced move route moves the player's character.</param>
/// <param name="Pictures">The numbers of the pictures the map's screen shows.</param>
public sealed record FlowState(
    int Map, int Brightness, bool FadingIn, FlowTone Tone, bool Hidden, bool Followers, bool TempParty, FlowMusic? Music,
    IReadOnlySet<string> Bans, bool Route, IReadOnlySet<int> Pictures)
{
    /// <summary>
    /// The brightness of a screen nothing dims.
    /// </summary>
    public const int FullBrightness = 255;

    /// <summary>
    /// Gets a value indicating whether the screen is dimmed and nothing fades it in.
    /// </summary>
    public bool Dark => Brightness < FullBrightness && !FadingIn;
}

/// <summary>
/// A tint of the screen, as the game's Tone holds it.
/// </summary>
/// <param name="Red">Its red, -255 to 255.</param>
/// <param name="Green">Its green, -255 to 255.</param>
/// <param name="Blue">Its blue, -255 to 255.</param>
/// <param name="Gray">Its gray, 0 to 255.</param>
public readonly record struct FlowTone(double Red, double Green, double Blue, double Gray)
{
    /// <summary>
    /// The tint of a screen with none.
    /// </summary>
    public static readonly FlowTone None = new(0, 0, 0, 0);

    /// <summary>
    /// The largest difference between two values that still counts as the same tint, since the game
    /// steps a tone change in fractions.
    /// </summary>
    private const double Tolerance = 0.5;

    /// <summary>
    /// Tells whether two tints look the same.
    /// </summary>
    /// <param name="other">The other tint.</param>
    /// <returns>Whether each value lies within <see cref="Tolerance"/> of the other's.</returns>
    public bool Looks(FlowTone other) =>
        Math.Abs(Red - other.Red) < Tolerance && Math.Abs(Green - other.Green) < Tolerance && Math.Abs(Blue - other.Blue) < Tolerance && Math.Abs(Gray - other.Gray) < Tolerance;
}

/// <summary>
/// A piece of music as the game plays it.
/// </summary>
/// <param name="Name">Its file, without the folder.</param>
/// <param name="Volume">Its volume.</param>
/// <param name="Pitch">Its pitch.</param>
public sealed record FlowMusic(string Name, int Volume, int Pitch);

/// <summary>
/// The bans the game's events set and lift, by the names the scripts read and lift them by.
/// </summary>
public static class FlowBans
{
    /// <summary>The game's menu is shut (Change Menu Access).</summary>
    public const string Menu = "menu";

    /// <summary>Saving is shut (Change Save Access).</summary>
    public const string Save = "save";

    /// <summary>No random encounter starts (Change Encounter).</summary>
    public const string Encounter = "encounter";

    /// <summary>The menu's Formation is shut (Change Formation Access).</summary>
    public const string Formation = "formation";

    /// <summary>The escape spell and its items are shut, a switch the places that ban them turn on.</summary>
    public const string Escape = "escape";

    /// <summary>
    /// The bans that belong to the place the player stands in, which the game lifts as the player
    /// walks out of it.
    /// </summary>
    public static readonly IReadOnlySet<string> OfPlace = new HashSet<string> { Escape }.ToFrozenSet();
}
