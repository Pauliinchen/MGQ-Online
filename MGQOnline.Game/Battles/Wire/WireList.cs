//----------------------------------------------------------------
//  WireList.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// An Array ("[" … "]").
/// </summary>
/// <param name="Items">The values in their order.</param>
public sealed record WireList(IReadOnlyList<WireValue> Items) : WireValue
{
    /// <summary>
    /// Initializes a list of values.
    /// </summary>
    /// <param name="items">The values in their order.</param>
    public WireList(params WireValue[] items)
        : this((IReadOnlyList<WireValue>)items)
    {
    }

    /// <summary>
    /// Tells whether another list holds equal values in the same order.
    /// </summary>
    /// <param name="other">The other list.</param>
    /// <returns>Whether it does.</returns>
    public bool Equals(WireList? other) => other is not null && Items.SequenceEqual(other.Items);

    /// <inheritdoc />
    public override int GetHashCode()
    {
        var hash = default(HashCode);
        foreach (WireValue item in Items)
        {
            hash.Add(item);
        }

        return hash.ToHashCode();
    }
}

/// <summary>
/// A field of an action result: its name, without "@", and its value.
/// </summary>
/// <param name="Name">The field's name, such as "hp_damage".</param>
/// <param name="Value">Its value.</param>
public sealed record WireField(string Name, WireValue Value);

/// <summary>
/// An action result ("{" … "}"), the game's <c>Game_ActionResult</c>, by the fields that travel.
/// </summary>
/// <param name="Fields">The fields in their order; a name read twice is set twice.</param>
public sealed record WireResult(IReadOnlyList<WireField> Fields) : WireValue
{
    /// <summary>
    /// Initializes a result of fields.
    /// </summary>
    /// <param name="fields">The fields in their order.</param>
    public WireResult(params WireField[] fields)
        : this((IReadOnlyList<WireField>)fields)
    {
    }

    /// <summary>
    /// Tells whether another result holds equal fields in the same order.
    /// </summary>
    /// <param name="other">The other result.</param>
    /// <returns>Whether it does.</returns>
    public bool Equals(WireResult? other) => other is not null && Fields.SequenceEqual(other.Fields);

    /// <inheritdoc />
    public override int GetHashCode()
    {
        var hash = default(HashCode);
        foreach (WireField field in Fields)
        {
            hash.Add(field);
        }

        return hash.ToHashCode();
    }
}
