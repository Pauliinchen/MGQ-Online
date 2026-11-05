//----------------------------------------------------------------
//  DataFingerprintTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Tests of the game data's fingerprint the scripts have C# write of the ids they read.
/// </summary>
public sealed class DataFingerprintTests
{
    /// <summary>
    /// Asserts that the ids the scripts hand over give the fingerprint the scripts wrote with
    /// Ruby's <c>Zlib.crc32</c> of each part's ids joined by commas, and that it compares as the
    /// same game's data; a request of another number of parts is refused.
    /// </summary>
    [Fact]
    public void Topic_WritesTheFingerprintOfTheIdsTheScriptsRead()
    {
        var topics = new TopicContext();
        DataFingerprint.Register(topics.Context);
        long[][] ids = [[1, 2], [1], [1, 2, 3], [1, 2], [1], [1], [1], [1], [1], [1], [1, 2, 488, 1001]];
        var request = new RubyArray(ids.Select(part => (RubyValue)new RubyArray(part.Select(id => (RubyValue)id))));

        string written = topics.Call(DataFingerprint.Topic, request)!["value"].AsText();

        Assert.Equal("2:2b0e6c9b.83dcefb7.11894deb.2b0e6c9b.83dcefb7.83dcefb7.83dcefb7.83dcefb7.83dcefb7.83dcefb7.e46b3f4c", written);
        Assert.Empty(GameDataCompare.Differing(written, written)!);
        Assert.False(topics.Call(DataFingerprint.Topic, new RubyArray { new RubyArray { 1 } })!["ok"].AsBool());
    }
}
