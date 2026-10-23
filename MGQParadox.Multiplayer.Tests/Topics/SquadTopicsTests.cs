//----------------------------------------------------------------
//  SquadTopicsTests.cs
//
//  Changelog:
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
/// Covers the squad topics both hosts answer against the golden cases recorded from the scripts
/// (fixtures/squad/squad.json), which the script tests answer from too.
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
    /// Asserts that the settings of a Raid World that names none are those the world's rules name.
    /// </summary>
    [Fact]
    public void Default_AnswersTheDefaultSettings() =>
        Assert.Equal(new RubyHash { { "luka", false }, { "formation", 4L }, { "front", 1L }, { "raid_front", 1L } }, _topics.Call(SquadTopics.Default));

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
}
