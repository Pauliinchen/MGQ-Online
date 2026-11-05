//----------------------------------------------------------------
//  RawListShape.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The <see cref="ListShape"/> of a list as the game holds it, which the generator writes into the
/// events database and the DLL compares a player's own map with.
/// </summary>
public static class RawListShape
{
    /// <summary>
    /// Finds the shape of a list.
    /// </summary>
    /// <param name="list">The commands as the game runs them, their parameters whole.</param>
    /// <returns>The shape.</returns>
    public static int Of(IReadOnlyList<RawCommand> list)
    {
        int shape = 0;
        foreach (RawCommand command in list)
        {
            shape = ListShape.AddCommand(shape, command.Code, command.Indent, IntegersOf(command.Parameters));
        }

        return shape;
    }

    /// <summary>
    /// Picks the parameters that are Integers in Ruby, as the shape hashes them; one too large for 64
    /// bits by the low bits the shape keeps of it.
    /// </summary>
    /// <param name="parameters">The parameters.</param>
    /// <returns>The whole numbers, in order.</returns>
    private static long[] IntegersOf(RubyArray parameters)
    {
        var integers = new List<long>(parameters.Count);
        foreach (RubyValue value in parameters)
        {
            if (value is RubyInteger integer)
            {
                integers.Add(integer.Value >= long.MinValue && integer.Value <= long.MaxValue ? (long)integer.Value : (long)(integer.Value & ListShape.Mask));
            }
        }

        return [.. integers];
    }
}
