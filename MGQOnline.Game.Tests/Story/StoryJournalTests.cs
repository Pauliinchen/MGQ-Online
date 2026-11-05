//----------------------------------------------------------------
//  StoryJournalTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-05: Checked that the scripts hear a mark gone unknown as an overflow
//      Paulinchen  2026-10-31: Called the topics through TopicContext
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the frozen fights' write journal through its topics.
/// </summary>
public sealed class StoryJournalTests
{
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
}
