//----------------------------------------------------------------
//  ListShape.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Data.Events;

/// <summary>
/// The shape of a list of event commands: a 24-bit hash over the code, the indent and every whole
/// number parameter of its kept commands, which a translation of its texts leaves alone.
/// </summary>
/// <remarks>
/// The scripts compute the same hash on the game's Ruby 1.9.2, where 24 bits keep every step a
/// Fixnum.
/// </remarks>
public static class ListShape
{
    /// <summary>
    /// The bits a shape keeps.
    /// </summary>
    public const int Mask = 0xFFFFFF;

    /// <summary>
    /// What a shape is multiplied by before each value is added.
    /// </summary>
    public const int Multiplier = 31;

    /// <summary>
    /// Adds one value to a shape.
    /// </summary>
    /// <param name="shape">The shape so far, 0 for an empty list.</param>
    /// <param name="value">The value.</param>
    /// <returns>The new shape.</returns>
    public static int Add(int shape, long value) => (int)(unchecked(((long)shape * Multiplier) + value) & Mask);

    /// <summary>
    /// Adds one command to a shape when the database keeps its code.
    /// </summary>
    /// <param name="shape">The shape so far.</param>
    /// <param name="code">The command's code.</param>
    /// <param name="indent">Its indent.</param>
    /// <param name="integers">Its parameters that are whole numbers, in order; texts, flags, lists and nil left out.</param>
    /// <returns>The new shape, the same for a command the database does not keep.</returns>
    public static int AddCommand(int shape, int code, int indent, ReadOnlySpan<long> integers)
    {
        if (!EventSchema.Keeps(code))
        {
            return shape;
        }

        shape = Add(Add(shape, code), indent);
        foreach (long value in integers)
        {
            shape = Add(shape, value);
        }

        return shape;
    }
}
