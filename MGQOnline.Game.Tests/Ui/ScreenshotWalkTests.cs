//----------------------------------------------------------------
//  ScreenshotWalkTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.Ui;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers the walk from a Bitmap's Ruby object to its pixels, as ui_bug_report.rbx walked it.
/// </summary>
public sealed class ScreenshotWalkTests
{
    /// <summary>
    /// Asserts that the walk reads the object's data 16 bytes in, the bitmap's 8 bytes in, and the
    /// pixels 16 bytes in, and that an empty pointer or no pixels on the way are refused.
    /// </summary>
    [Fact]
    public void PixelsOf_FollowsTheThreePointers()
    {
        var memory = new Dictionary<long, long> { [1016] = 2000, [2008] = 3000, [3016] = 4000 };
        var empty = new Dictionary<long, long> { [1016] = 0 };
        var none = new Dictionary<long, long> { [1016] = 2000, [2008] = 3000, [3016] = 0 };

        Assert.Equal(4000, ScreenshotWalk.PixelsOf(1000, at => memory[at]));
        Assert.Throws<InvalidOperationException>(() => ScreenshotWalk.PixelsOf(1000, at => empty[at]));
        Assert.Throws<InvalidOperationException>(() => ScreenshotWalk.PixelsOf(1000, at => none[at]));
        Assert.Equal([true, false, false], new[] { ScreenshotWalk.IsScreenSize(640, 480), ScreenshotWalk.IsScreenSize(0, 480), ScreenshotWalk.IsScreenSize(640, 4097) });
    }
}
