//----------------------------------------------------------------
//  SceneQueueTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Recorded the queue from SceneQueue, the script that recorded it being gone
//                            - Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Scene;

namespace MGQOnline.Game.Tests.Scene;

/// <summary>
/// Covers the teller's queue of scene changes.
/// </summary>
public sealed class SceneQueueTests
{
    /// <summary>
    /// Asserts that while the player holds the game's skip the changes go out only every
    /// <see cref="SceneQueue.SkipSendFrames"/> frames, but at once once the skip is let go or the
    /// story stopped, and that a frame count that went back counts as passed.
    /// </summary>
    [Fact]
    public void Due_ThrottlesOnlyWhileSkipping()
    {
        var queue = new SceneQueue();
        queue.Add("screen.start_fadein", [new WireInteger(30)], 7, true, true);
        queue.Flush(100);

        Assert.False(queue.Due(105, skipHeld: true, playing: true));
        Assert.True(queue.Due(110, skipHeld: true, playing: true));
        Assert.True(queue.Due(105, skipHeld: false, playing: true));
        Assert.True(queue.Due(105, skipHeld: true, playing: false));
        Assert.True(queue.Due(50, skipHeld: true, playing: true));
    }
}
