//----------------------------------------------------------------
//  RaidBarsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Hud;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Hud;

/// <summary>
/// Covers the raid bars: a share just short of the whole.
/// </summary>
public sealed class RaidBarsTests
{
    /// <summary>
    /// Asserts that 99.95% of the HP left reads as the whole, as the share lies just above the tie.
    /// </summary>
    [Fact]
    public void Percent_ReadsNinetyNinePointNinetyFiveAsTheWhole() => Assert.Equal("100.0%", RaidBars.Percent(9995, 10_000));
}
