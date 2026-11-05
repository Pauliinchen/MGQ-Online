//----------------------------------------------------------------
//  SquadTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Checked the squad math's topics with the requests the scripts send
//      Paulinchen  2026-10-30: Dropped the default settings, which WorldTopicsTests checks
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the squad topics both hosts answer, against the golden cases recorded from the scripts
/// (fixtures/squad/squad.json) and with the requests the scripts send.
/// </summary>
public sealed class SquadTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(SharedTopics.Register);

    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "squad", "squad.json"))).RootElement;

    /// <summary>
    /// Asserts that a served battle's settings fill in the defaults as battles_served.rbx did.
    /// </summary>
    [Fact]
    public void Served_FillsInTheDefaults()
    {
        foreach (JsonElement entry in _cases.GetProperty("served").EnumerateArray())
        {
            Assert.Equal(JsonValues.RubyOf(entry.GetProperty("squad")), _topics.Call(SquadTopics.Served, JsonValues.RubyOf(entry.GetProperty("list"))) ?? RubyNil.Value);
        }
    }

    /// <summary>
    /// Asserts that a served battle's settings out of range, which the scripts once passed on, are
    /// none, and that a pair that is no pair is left out.
    /// </summary>
    [Fact]
    public void Served_AnswersNothingForSettingsOutOfRange()
    {
        Assert.Null(_topics.Call(SquadTopics.Served, new RubyArray { new RubyArray { "formation", 3L } }));
        Assert.Null(_topics.Call(SquadTopics.Served, new RubyArray { new RubyArray { "front", 1L << 40 } }));
        Assert.Equal(_topics.Call(SquadTopics.Default), _topics.Call(SquadTopics.Served, new RubyArray { "front", new RubyArray { "luka", false } }));
    }

    /// <summary>
    /// Asserts that the squad math answers the requests as the scripts send them: a party's shares
    /// and order, a Raid World's squads by the defaults when the world names no rules, a battle's
    /// players arranged and the companions a team past its cap leaves out.
    /// </summary>
    [Fact]
    public void Math_AnswersTheScriptsRequests()
    {
        Assert.Equal(new RubyArray { new RubyArray { 2, 2 }, new RubyArray { 1, 1 }, new RubyArray { 1, 1 } },
                     _topics.Call(SquadTopics.Shares, new RubyHash { { "count", 3 }, { "max", 8 } }));
        Assert.Equal(new RubyArray { "friend", "me" }, _topics.Call(SquadTopics.Rank, new RubyArray { new RubyArray { "me", false }, new RubyArray { "friend", true } }));
        Assert.Equal(new RubyHash { { "regular", new RubyArray { 1, 2 } }, { "raid", new RubyArray { 1, 2 } }, { "largest", 3 } },
                     _topics.Call(SquadTopics.Raid, new RubyHash { { "rules", RubyNil.Value }, { "max", 8 } }));

        var players = new RubyArray { new RubyArray { "b-friend", false, 8, 4 }, new RubyArray { "id-me", true, 8, 4 } };
        Assert.Equal(new RubyArray { new RubyArray { 1, 2, 0 }, new RubyArray { 0, 2, 0 } },
                     _topics.Call(SquadTopics.Arrange, new RubyHash { { "rules", RubyNil.Value }, { "raid", false }, { "backline", false }, { "players", players } }));
        Assert.Equal(new RubyArray { 5, 6 },
                     _topics.Call(SquadTopics.PastCap, new RubyHash { { "team", new RubyArray { 2, 3, 4, 5, 1, 6 } }, { "luka", new RubyArray { 1 } }, { "cap", 4 }, { "keep_luka", true } }));
    }
}
