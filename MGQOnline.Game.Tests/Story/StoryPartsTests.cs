//----------------------------------------------------------------
//  StoryPartsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story's parts.
/// </summary>
public sealed class StoryPartsTests
{
    /// <summary>
    /// Asserts that a story whose route counters are left out is counted by its progress alone.
    /// </summary>
    [Fact]
    public void Of_CountsMissingRoutesAsNone() => Assert.Equal("2", StoryParts.Of(20, []));
}
