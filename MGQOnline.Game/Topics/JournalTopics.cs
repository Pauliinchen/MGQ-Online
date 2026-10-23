//----------------------------------------------------------------
//  JournalTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the frozen raid boss fights' write journal, see <see cref="StoryJournal"/>,
/// one journal per context.
/// </summary>
public static class JournalTopics
{
    /// <summary>
    /// Keeps the writes the scripts noted: <c>entries</c> (each <c>[seq, kind, key, before]</c>) and
    /// <c>keep</c> (the oldest live mark, nil for none) in, nothing out.
    /// </summary>
    public const string JournalTopic = "freeze.journal";

    /// <summary>
    /// Lists the keys written since a mark: the mark in; <c>rows</c> (each <c>[kind, key, before]</c>)
    /// and <c>overflow</c> (true when the journal dropped entries the mark needs, the rows then empty) out.
    /// </summary>
    public const string SinceTopic = "freeze.since";

    /// <summary>
    /// Registers the topics on a context, with a journal of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The journal, for tests.</returns>
    public static StoryJournal Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        StoryJournal journal = new();
        context.Register(JournalTopic, (_, request) => Take(journal, request.AsHash()));
        context.Register(SinceTopic, (_, request) => Since(journal, request.AsLong()));
        return journal;
    }

    /// <summary>
    /// Answers <see cref="JournalTopic"/>.
    /// </summary>
    /// <param name="journal">The journal.</param>
    /// <param name="request">The request.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    /// <exception cref="BridgeRequestException">An entry is no <c>[seq, kind, key, before]</c>.</exception>
    private static RubyValue? Take(StoryJournal journal, RubyHash request)
    {
        var entries = new List<StoryJournal.Entry>();
        foreach (RubyValue item in request["entries"].AsArray())
        {
            RubyArray entry = item.AsArray();
            if (entry.Count != 4 || entry[1].AsInt() is < 0 or > 2)
            {
                throw new BridgeRequestException("A journal entry is [seq, kind, key, before], kind 0 to 2.");
            }

            entries.Add(new StoryJournal.Entry(entry[0].AsLong(), entry[1].AsInt(), entry[2], entry[3]));
        }

        RubyValue keep = request["keep"];
        journal.Take(entries, keep.IsNil ? null : keep.AsLong());
        return null;
    }

    /// <summary>
    /// Answers <see cref="SinceTopic"/>.
    /// </summary>
    /// <param name="journal">The journal.</param>
    /// <param name="mark">The mark.</param>
    /// <returns>The rows and whether the mark overflowed.</returns>
    private static RubyHash Since(StoryJournal journal, long mark)
    {
        IReadOnlyList<StoryJournal.Entry>? found = journal.Since(mark);
        var rows = new RubyArray();
        foreach (StoryJournal.Entry entry in found ?? [])
        {
            rows.Add(new RubyArray { entry.Kind, entry.Key, entry.Before });
        }

        return new RubyHash { { "rows", rows }, { "overflow", found is null } };
    }
}
