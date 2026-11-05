//----------------------------------------------------------------
//  EnterRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Checked the warning of a game whose data differs in place of the data's golden cases
//                            - Left out the golden cases of a world entered with mods parked
//                            - Checked entering a world whose data scan has another format
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the rules a world is entered by: the warning of a game whose data differs.
/// </summary>
public sealed class EnterRulesTests
{
    /// <summary>
    /// Asserts that a game whose data differs is warned in plain words, the first parts by name, and
    /// that one that matches or cannot be compared is not.
    /// </summary>
    [Fact]
    public void DataWarning_NamesWhatDiffersAndNothingElse()
    {
        Assert.Equal("Your game differs from the creator's of Haven. Some things may not work as in their game.",
            EnterRules.DataWarning("Haven", ["skills", "items", "states", "maps", "troops"]));
        Assert.Null(EnterRules.DataWarning("Haven", []));
        Assert.Null(EnterRules.DataWarning("Haven", null));
    }

    /// <summary>
    /// Asserts that a data scan of another format is told apart from an unknown one and from one
    /// that differs.
    /// </summary>
    [Fact]
    public void OtherFormat_TellsAScanOfAnotherFormat()
    {
        Assert.Equal([true, false, false, false], new[] { "1:a.b", "2:c.d", "", null }.Select(other => GameDataCompare.OtherFormat("2:a.b", other)));
        Assert.False(GameDataCompare.OtherFormat("", "1:a.b"));
    }
}
