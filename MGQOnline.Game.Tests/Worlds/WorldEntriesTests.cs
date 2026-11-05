//----------------------------------------------------------------
//  WorldEntriesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the world screen's entries.
/// </summary>
public sealed class WorldEntriesTests
{
    /// <summary>
    /// Asserts that only ASCII letters fold, as in the game's Ruby.
    /// </summary>
    [Fact]
    public void AsciiLower_LeavesOtherLettersAlone() => Assert.Equal("élise and Élise", WorldEntries.AsciiLower("éLISE AND Élise"));
}
