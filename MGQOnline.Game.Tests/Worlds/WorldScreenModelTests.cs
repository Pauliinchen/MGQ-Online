//----------------------------------------------------------------
//  WorldScreenModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Read no game data comparison into the facts, which the details no longer make
//                            - Dropped the comparison of the screen texts with their copy in screen.json
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers what the world screen shows of the list.
/// </summary>
public sealed class WorldScreenModelTests
{
    /// <summary>
    /// Asserts that the list's state is told only while it is fetched or failed.
    /// </summary>
    [Fact]
    public void ListText_TellsLoadingAndFailingOnly()
    {
        Assert.Equal("The list is being fetched . . .", WorldScreenModel.ListText("loading", null));
        Assert.Equal("The list could not be fetched: down", WorldScreenModel.ListText("failed", "down"));
        Assert.Null(WorldScreenModel.ListText("ready", null));
    }
}
