//----------------------------------------------------------------
//  StoryJournalTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Checked that the scripts hear a mark gone unknown as an overflow
//      Paulinchen  2026-10-31: Called the topics through TopicContext
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the frozen fights' write journal through its topics, against the cases the old
/// whole-story diff gave (fixtures/freeze/journal.json).
/// </summary>
public sealed class StoryJournalTests
{
    /// <summary>
    /// Asserts that the journal answers each key written since the mark once, with its value before
    /// its first write since it, as the cases recorded.
    /// </summary>
    [Fact]
    public void Since_AnswersTheKeysWrittenSinceTheMarkWithTheirFirstValues()
    {
        foreach (JsonElement entry in Fixtures.Read("freeze", "journal.json").GetProperty("cases").EnumerateArray())
        {
            var topics = new TopicContext();
            JournalTopics.Register(topics.Context);
            long mark = entry.GetProperty("mark").GetInt64();
            topics.Value(JournalTopics.JournalTopic, new RubyHash { { "entries", ValueOf(entry.GetProperty("entries")) }, { "keep", mark } });

            RubyHash answer = topics.Value(JournalTopics.SinceTopic, mark).AsHash();

            Assert.Equal(ValueOf(entry.GetProperty("rows")), answer["rows"]);
            Assert.Equal(RubyBool.False, answer["overflow"]);
        }
    }

    /// <summary>
    /// Asserts that a mark the journal no longer holds every entry after reads as unknown: one below
    /// the oldest live mark, one before every mark died, one whose entries the cap dropped.
    /// </summary>
    [Fact]
    public void Since_TellsAMarkWhoseEntriesWentUnknown()
    {
        var journal = new StoryJournal();
        journal.Take([new StoryJournal.Entry(1, 0, new RubyInteger(5), RubyNil.Value), new StoryJournal.Entry(2, 0, new RubyInteger(6), RubyNil.Value)], 1);

        Assert.Null(journal.Since(0));
        Assert.Single(journal.Since(1)!);

        journal.Take([], null);
        Assert.Null(journal.Since(1));
        Assert.Empty(journal.Since(2)!);

        journal.Take(Enumerable.Range(3, StoryJournal.MaxEntries + 1).Select(seq => new StoryJournal.Entry(seq, 1, new RubyInteger(seq), RubyNil.Value)), 2);
        Assert.Equal(StoryJournal.MaxEntries, journal.Count);
        Assert.Null(journal.Since(2));
        Assert.Equal(StoryJournal.MaxEntries, journal.Since(3)!.Count);
    }

    /// <summary>
    /// Asserts that the scripts hear a mark whose entries went unknown as an overflow without rows.
    /// </summary>
    [Fact]
    public void SinceTopic_TellsTheScriptsOfAMarkGoneUnknown()
    {
        var topics = new TopicContext();
        JournalTopics.Register(topics.Context);
        topics.Value(JournalTopics.JournalTopic, new RubyHash { { "entries", new RubyArray { new RubyArray { 1, 0, 5, RubyNil.Value } } }, { "keep", 1 } });

        Assert.Equal(new RubyHash { { "rows", new RubyArray() }, { "overflow", true } }, topics.Value(JournalTopics.SinceTopic, 0));
    }

    /// <summary>
    /// Reads a value of a case as the scripts hand it over: whole numbers, true, false and nil as
    /// they are, self switch keys as Arrays, and any other value wrapped as the scripts wrap a dump.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value.</returns>
    private static RubyValue ValueOf(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => RubyBool.True,
        JsonValueKind.False => RubyBool.False,
        JsonValueKind.Number when value.TryGetInt64(out long number) => number,
        JsonValueKind.Array => new RubyArray(value.EnumerateArray().Select(ValueOf)),
        JsonValueKind.String when value.GetString() is { Length: 1 } letter => letter,
        _ => new RubyArray { RubyString.Binary(System.Text.Encoding.UTF8.GetBytes(value.GetRawText())) },
    };
}
