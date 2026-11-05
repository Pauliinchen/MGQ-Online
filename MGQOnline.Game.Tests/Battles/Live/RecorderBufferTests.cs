//----------------------------------------------------------------
//  RecorderBufferTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Live;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the host's recording.
/// </summary>
public sealed class RecorderBufferTests
{
    /// <summary>
    /// Asserts that values that did not change are recorded once, and every battler's again on a full recording.
    /// </summary>
    [Fact]
    public void Values_RecordedOnlyWhenChanged()
    {
        var recorder = new RecorderBuffer();
        recorder.Start();

        recorder.Values([(1, "a0", "i1"), (2, "a1", "i2")], false);
        recorder.Values([(1, "a0", "i1"), (2, "a1", "i3")], false);
        int changed = recorder.Waiting;
        recorder.Values([(1, "a0", "i1"), (2, "a1", "i3")], true);

        Assert.Equal(3, changed);
        Assert.Equal(5, recorder.Waiting);
    }
}
