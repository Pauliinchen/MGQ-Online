//----------------------------------------------------------------
//  WorldTrafficTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Covered the cap on the kinds a line names
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers how a world session's messages are counted and logged as a line about every minute.
/// </summary>
public sealed class WorldTrafficTests
{
    /// <summary>
    /// When the counting starts.
    /// </summary>
    private static readonly DateTime Start = new(2026, 10, 7, 20, 0, 0, DateTimeKind.Utc);

    /// <summary>
    /// Asserts that messages within a minute write nothing, and the first one after it writes them all, by kind and direction.
    /// </summary>
    [Fact]
    public void Received_WritesOneLineOnceTheMinutePassed()
    {
        var now = Start;
        var lines = new List<string>();
        var traffic = new WorldTraffic(() => now, lines.Add);

        traffic.Received(2, "state=1\nx=3\n\n", 300);
        traffic.Received(0, "state=1\n\n", 400);
        traffic.Sent("chat=hi\nname=Me\n\n", 30);
        now = Start.AddSeconds(59);
        traffic.Received(2, "npcs=1\n\n", 50);
        Assert.Empty(lines);

        now = Start.AddSeconds(61);
        traffic.Sent("battle=x\n\n", 2000);

        Assert.Equal(["world traffic in 61 s: in 3 messages, 1 KB from seats 0, 2: npcs 1, state 2; out 2 messages, 2 KB: battle 1, chat 1"], lines);
    }

    /// <summary>
    /// Asserts that a flush writes what was counted so far, and nothing when nothing was.
    /// </summary>
    [Fact]
    public void Flush_WritesWhatWasCountedOnce()
    {
        var now = Start;
        var lines = new List<string>();
        var traffic = new WorldTraffic(() => now, lines.Add);

        traffic.Flush();
        traffic.Sent("state=1\n\n", 100);
        now = Start.AddSeconds(5);
        traffic.Flush();
        traffic.Flush();

        Assert.Equal(["world traffic in 5 s: in nothing; out 1 message, 1 KB: state 1"], lines);
    }

    /// <summary>
    /// Asserts that a message's kind is its first field, without the count of its fields.
    /// </summary>
    [Fact]
    public void KindOf_NamesTheFirstField()
    {
        Assert.Equal("duel", WorldTraffic.KindOf("duel=start\nbid=x\n\nbody"));
        Assert.Equal("no keys", WorldTraffic.KindOf("plain text"));
    }

    /// <summary>
    /// Asserts that the kinds past the cap are counted as "other", while the kinds named already go on counting.
    /// </summary>
    [Fact]
    public void Received_CountsKindsPastTheCapAsOther()
    {
        var lines = new List<string>();
        var traffic = new WorldTraffic(() => Start, lines.Add);

        for (var kind = 0; kind < WorldTraffic.MaxKinds + 5; kind++)
        {
            traffic.Received(1, $"k{kind:D2}=1\n\n", 10);
        }

        traffic.Received(1, "k00=1\n\n", 10);
        traffic.Flush();

        var line = Assert.Single(lines);
        Assert.Contains("k00 2, ", line);
        Assert.Contains($"k{WorldTraffic.MaxKinds - 1:D2} 1", line);
        Assert.DoesNotContain($"k{WorldTraffic.MaxKinds:D2}", line);
        Assert.Contains($"{WorldTraffic.OtherKind} 5", line);
    }
}
