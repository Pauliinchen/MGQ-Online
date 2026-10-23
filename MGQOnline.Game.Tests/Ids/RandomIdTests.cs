//----------------------------------------------------------------
//  RandomIdTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Game.Ids;

namespace MGQOnline.Game.Tests.Ids;

/// <summary>
/// Covers the ids the scripts make up.
/// </summary>
public sealed class RandomIdTests
{
    /// <summary>
    /// Asserts that an id has exactly the digits asked for, leading zeros included, written as Ruby
    /// writes the base.
    /// </summary>
    [Fact]
    public void Of_WritesExactlyTheDigitsOfTheBase()
    {
        Random random = new(1);
        string[] battles = Enumerable.Range(0, 200).Select(_ => RandomId.Of(random, 8, 36)).ToArray();
        string trade = RandomId.Of(random, 24, 16);

        Assert.All(battles, id => Assert.Matches("^[0-9a-z]{8}$", id));
        Assert.Matches("^[0-9a-f]{24}$", trade);
        Assert.Equal(battles.Length, battles.Distinct(StringComparer.Ordinal).Count());
        Assert.Contains(battles, id => id.StartsWith('0'));
    }

    /// <summary>
    /// Asserts that a length or base out of range is refused.
    /// </summary>
    [Fact]
    public void Of_RefusesALengthOrBaseOutOfRange()
    {
        Random random = new(1);

        Assert.Throws<ArgumentOutOfRangeException>(() => RandomId.Of(random, 0, 36));
        Assert.Throws<ArgumentOutOfRangeException>(() => RandomId.Of(random, RandomId.MaxLength + 1, 36));
        Assert.Throws<ArgumentOutOfRangeException>(() => RandomId.Of(random, 8, 37));
        Assert.Throws<ArgumentOutOfRangeException>(() => RandomId.Of(random, 8, 1));
    }
}
