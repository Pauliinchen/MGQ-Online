//----------------------------------------------------------------
//  RuleTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Called each topic once, since the rules' golden cases cover the rules
//      Paulinchen  2026-10-23: Covered the story's part
//                            - Covered the mod keys
//                            - Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics through which the scripts ask the game's rules, as the scripts call them.
/// </summary>
public sealed class RuleTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(RuleTopics.Register);

    /// <summary>
    /// Asserts that each topic reads the request as the scripts send it and answers as they read it;
    /// MGQOnline.Game.Tests covers the rules themselves.
    /// </summary>
    [Fact]
    public void Topics_ReadTheScriptsRequests()
    {
        Assert.Equal(new RubyInteger(10), _topics.Call(RuleTopics.CatchupTarget, new RubyArray([15L, 10L, 10L])));
        Assert.Equal(new RubyHash { { "exp", 580L }, { "cexp", 232L }, { "factor", "x5.8" } },
            _topics.Call(RuleTopics.CatchupGrow, new RubyHash { { "target", 10L }, { "level", 6L }, { "exp", 100L }, { "cexp", 40L } }));
        Assert.Equal(RubyString.Utf8("x4"), _topics.Call(RuleTopics.CatchupFactor, new RubyHash { { "target", 40L }, { "level", 30L } }));
        Assert.Equal(new RubyArray(["levelcap", "lukareplacer"]), _topics.Call(RuleTopics.ModKeys, new RubyArray(["Level_Cap.rb", "Luka Replacer"])));
        Assert.Equal(RubyString.Utf8("mr"), _topics.Call(RuleTopics.StoryPart, new RubyHash { { "p", 40L }, { "routes", new RubyArray([0L, 2L, 0L]) } }));
    }

    /// <summary>
    /// Asserts that a request without a level is refused, so the script keeps the experience as it is.
    /// </summary>
    [Fact]
    public void CatchupGrow_RefusesARequestWithoutALevel() =>
        Assert.Equal(BridgeEnvelope.BadRequest, _topics.Refusal(RuleTopics.CatchupGrow, new RubyHash { { "target", 10L }, { "exp", 100L } }));
}
