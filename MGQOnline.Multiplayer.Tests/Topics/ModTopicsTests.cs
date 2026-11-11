//----------------------------------------------------------------
//  ModTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Dropped the check of the installed scripts topic, which the DLL no longer has
//      Paulinchen  2026-11-08: Gave the topics no world directory, since the relay's mod catalog went
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//      Paulinchen  2026-10-23: Covered the mods text topic
//                            - Gave the topics the world directory too
//                            - Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics through which the scripts learn about the game's mods, as the scripts call them.
/// </summary>
public sealed class ModTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(ModTopics.Register);

    /// <summary>
    /// Asserts that a world's mods come back without their marks, the required ones first.
    /// </summary>
    [Fact]
    public void Text_ReadsTheMarks()
    {
        Assert.Equal(
            new RubyHash { { "names", new RubyArray(["Level Cap", "Data", "Other"]) }, { "required", new RubyArray(["Level Cap"]) }, { "essential", new RubyArray(["Data"]) } },
            _topics.Call(ModTopics.Text, "?Data; Other; !Level Cap"));
    }
}
