//----------------------------------------------------------------
//  RuleTopicsTests.cs
//
//  Changelog:
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
    /// Asserts that the target comes from the caps and is nil before the story raised one.
    /// </summary>
    [Fact]
    public void CatchupTarget_AnswersTheCapBeforeTheLatest()
    {
        Assert.Equal(new RubyInteger(10), _topics.Call(RuleTopics.CatchupTarget, new RubyArray([15L, 10L, 10L])));
        Assert.Null(_topics.Call(RuleTopics.CatchupTarget, new RubyArray()));
    }

    /// <summary>
    /// Asserts that a character below the target gets its grown experience and the factor, and one
    /// at the target no reply.
    /// </summary>
    [Fact]
    public void CatchupGrow_GrowsBelowTheTargetOnly()
    {
        RubyHash below = new() { { "target", 10L }, { "level", 6L }, { "exp", 100L }, { "cexp", 40L } };
        RubyHash at = new() { { "target", 10L }, { "level", 10L }, { "exp", 100L }, { "cexp", 40L } };

        Assert.Equal(new RubyHash { { "exp", 580L }, { "cexp", 232L }, { "factor", "x5.8" } }, _topics.Call(RuleTopics.CatchupGrow, below));
        Assert.Null(_topics.Call(RuleTopics.CatchupGrow, at));
    }

    /// <summary>
    /// Asserts that the factor reads as the Unlocks page shows it, 1 without a target.
    /// </summary>
    [Fact]
    public void CatchupFactor_WritesTheFactor()
    {
        Assert.Equal(RubyString.Utf8("x4"), _topics.Call(RuleTopics.CatchupFactor, new RubyHash { { "target", 40L }, { "level", 30L } }));
        Assert.Equal(RubyString.Utf8("x1"), _topics.Call(RuleTopics.CatchupFactor, new RubyHash { { "target", RubyNil.Value }, { "level", 30L } }));
    }

    /// <summary>
    /// Asserts that names get their keys in the order asked.
    /// </summary>
    [Fact]
    public void ModKeys_AnswersEachNamesKey() =>
        Assert.Equal(new RubyArray(["levelcap", "lukareplacer"]), _topics.Call(RuleTopics.ModKeys, new RubyArray(["Level_Cap.rb", "Luka Replacer"])));

    /// <summary>
    /// Asserts that a story is in the part its route or its progress tells.
    /// </summary>
    [Fact]
    public void StoryPart_FindsThePart()
    {
        Assert.Equal(RubyString.Utf8("mr"), _topics.Call(RuleTopics.StoryPart, new RubyHash { { "p", 40L }, { "routes", new RubyArray([0L, 2L, 0L]) } }));
        Assert.Equal(RubyString.Utf8("2"), _topics.Call(RuleTopics.StoryPart, new RubyHash { { "p", 19L }, { "routes", new RubyArray([0L, 0L, 0L]) } }));
    }

    /// <summary>
    /// Asserts that a request without a level is refused, so the script keeps the experience as it is.
    /// </summary>
    [Fact]
    public void CatchupGrow_RefusesARequestWithoutALevel() =>
        Assert.Equal(BridgeEnvelope.BadRequest, _topics.Refusal(RuleTopics.CatchupGrow, new RubyHash { { "target", 10L }, { "exp", 100L } }));
}
