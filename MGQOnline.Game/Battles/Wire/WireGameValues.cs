//----------------------------------------------------------------
//  WireGameValues.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// The tables of the game's database a token names an entry of, each with its token's kind.
/// </summary>
public enum WireTable
{
    /// <summary>
    /// <c>$data_skills</c>, "k".
    /// </summary>
    Skills,

    /// <summary>
    /// <c>$data_items</c>, "t".
    /// </summary>
    Items,

    /// <summary>
    /// <c>$data_states</c>, "z".
    /// </summary>
    States,

    /// <summary>
    /// <c>$data_weapons</c>, "w".
    /// </summary>
    Weapons,

    /// <summary>
    /// <c>$data_armors</c>, "a".
    /// </summary>
    Armors,
}

/// <summary>
/// A battler ("@a0"), by the reference the host's recorder gave it.
/// </summary>
/// <param name="Ref">The reference, such as "a0" for the party's first or "e3" for the troop's fourth.</param>
public sealed record WireBattler(string Ref) : WireValue;

/// <summary>
/// An action ("xcount"), by its kind, which is all the game's display code reads of it.
/// </summary>
/// <param name="Symbol">The kind's symbol text, <see langword="null"/> for an action without one or
/// one this game lacks.</param>
public sealed record WireAction(string? Symbol) : WireValue;

/// <summary>
/// An entry of the database ("k12"), by its table and id.
/// </summary>
/// <param name="Table">The table.</param>
/// <param name="Id">The entry's id.</param>
public sealed record WireDatabaseItem(WireTable Table, int Id) : WireValue;

/// <summary>
/// An equipped or stolen item ("gk12"), the game's <c>Game_BaseItem</c>, by the entry it holds.
/// </summary>
/// <param name="Item">The entry, <see langword="null"/> for an empty one ("g~").</param>
public sealed record WireBaseItem(WireDatabaseItem? Item) : WireValue;

/// <summary>
/// A <c>Color</c> ("c255,128,0,255"), written as whole numbers and read as any numbers.
/// </summary>
/// <remarks>
/// The game's <c>Color</c> clamps its channels to 0-255 once Ruby makes one; the line itself does not.
/// </remarks>
/// <param name="Red">The red channel.</param>
/// <param name="Green">The green channel.</param>
/// <param name="Blue">The blue channel.</param>
/// <param name="Alpha">The opacity.</param>
public sealed record WireColor(double Red, double Green, double Blue, double Alpha) : WireValue;

/// <summary>
/// A <c>Tone</c> ("n-255,0,10,0"), written as whole numbers and read as any numbers.
/// </summary>
/// <remarks>
/// The game's <c>Tone</c> clamps its channels once Ruby makes one; the line itself does not.
/// </remarks>
/// <param name="Red">The red channel.</param>
/// <param name="Green">The green channel.</param>
/// <param name="Blue">The blue channel.</param>
/// <param name="Gray">The gray level.</param>
public sealed record WireTone(double Red, double Green, double Blue, double Gray) : WireValue;
