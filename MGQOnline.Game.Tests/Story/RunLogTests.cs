//----------------------------------------------------------------
//  RunLogTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Covered dropping the steps a save passed on the world's track
//                            - Logged a Raid World run of the own track with no claim, as the scripts hand it, claimed once its own entry came back
//      Paulinchen  2026-11-05: Gave a common event's entry a variable's value as the tracks write it
//      Paulinchen  2026-10-31: Covered a step of the own track claimed again on the world's track
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers a save's log of the steps its game took: claims by site once in each stream, resets,
/// the start place, the runs it still owes and the steps it passed.
/// </summary>
public sealed class RunLogTests
{
    /// <summary>
    /// The stream of a Raid World's own track.
    /// </summary>
    private const string WorldStream = "raid:w1:world";

    /// <summary>
    /// The Makina chest's page, 215:27 page 1.
    /// </summary>
    private static readonly ReplaySite Chest = ReplaySite.Parse("map:215:27:1");

    /// <summary>
    /// Asserts that a save drops a battle's drops and a replay the world's track handed at or below
    /// its cursor, while it keeps a drop not handed back yet, which still makes that entry done when
    /// it comes above the cursor, and a step of the player's own track, which the world's entry of
    /// its site still claims; a log kept without track numbers loads and keeps its steps.
    /// </summary>
    [Fact]
    public void DropPassed_DropsWhatTheWorldsTrackPassedAndStillGuardsTheRest()
    {
        RunLog log = RunLog.Begin(null);
        log.Ran(ReplaySite.Drop, new Dictionary<StoryKey, string>(), WorldStream, "d1");
        ReplayEntry ownDrop = Drop("d1", 3);
        ReplayEntry replayed = Entry("e4", WorldStream) with { Number = 4 };
        log.Queue(ownDrop);
        log.Queue(replayed);
        Assert.True(log.Claims(ownDrop));
        Assert.False(log.Claims(replayed));
        log.Replayed(replayed, Before(("ss215.27.A", "0")));
        log.Ran(ReplaySite.Parse("map:218:21:1"), Before(("ss218.21.A", "0")), null, null);
        Assert.True(log.Claims(Entry("own", "raid:w1:t3", site: "map:218:21:1") with { Number = 2 }));
        log.Ran(ReplaySite.Drop, new Dictionary<StoryKey, string>(), WorldStream, "d2");
        RubyHash old = log.Write();
        old["steps"] = new RubyArray(old["steps"].AsArray().Select(step => (RubyValue)new RubyArray { step.AsArray()[0], step.AsArray()[1], step.AsArray()[2] }));

        int dropped = log.DropPassed();
        RunLog saved = RunLog.Read(log.Write());
        ReplayEntry laterDrop = Drop("d2", 6);
        saved.Queue(laterDrop);
        RunLog oldSave = RunLog.Read(old);

        Assert.Equal((2, 2), (dropped, saved.Steps.Count));
        Assert.True(saved.Claims(laterDrop));
        Assert.True(saved.Claims(Entry("w7", WorldStream, site: "map:218:21:1") with { Number = 7 }));
        Assert.Equal((0, 4), (oldSave.DropPassed(), oldSave.Steps.Count));
        Assert.True(oldSave.Claims(ownDrop));
    }

    /// <summary>
    /// Asserts that an entry claims a standing step of its site once in its stream, so a second
    /// entry of that stream replays, while an entry of the same site in another stream claims the
    /// step again.
    /// </summary>
    [Fact]
    public void Claims_TakeAStepOnceInEachStream()
    {
        RunLog log = RunLog.Begin(null);
        log.Ran(Chest, Before(("ss215.27.A", "0")), null, null);

        Assert.True(log.Claims(Entry("e1", "party:1")));
        Assert.False(log.Claims(Entry("e2", "party:1")));
        Assert.True(log.Claims(Entry("e3", "world")));
    }

    /// <summary>
    /// Asserts that a step the player's own track claimed with their own entry is claimed again by
    /// the first entry of its site on the world's track, once.
    /// </summary>
    [Fact]
    public void Claims_TakeAStepOfTheOwnTrackAgainOnTheWorldsTrack()
    {
        RunLog log = RunLog.Begin(null);
        log.Ran(Chest, Before(("v1001", "n5")), "t3", "own");

        Assert.Equal((true, true, false), (log.Claims(Entry("own", "t3")), log.Claims(Entry("w1", "world")), log.Claims(Entry("w2", "world"))));
    }

    /// <summary>
    /// Asserts that an entry never reaches its own opener, and that the same entry handed again
    /// is done.
    /// </summary>
    [Fact]
    public void Claims_KnowTheOpenersOwnEntryAndOneTakenBefore()
    {
        RunLog log = RunLog.Begin(null);
        log.Ran(Chest, Before(("ss215.27.A", "0")), "party:1", "own");
        log.Replayed(Entry("e1", "party:1", site: "map:218:21:1"), Before(("ss218.21.A", "0")));

        Assert.Equal((true, true, true), (log.Claims(Entry("own", "party:1")), log.Claims(Entry("e1", "party:1", site: "map:218:21:1")), log.Claims(Entry("e9", "world"))));
    }

    /// <summary>
    /// Asserts that a later write of a step's key that is no reset leaves it standing, while a
    /// range reset that moves a key back ends it.
    /// </summary>
    [Fact]
    public void Reset_EndsAStepOnlyWhenItMovesAKeyBack()
    {
        RunLog log = RunLog.Begin(null);
        log.Ran(Chest, Before(("v1020", "n2"), ("ss215.27.A", "0")), null, null);

        log.Reset(new RunReset(StoryKeyKind.Variable, 1010, 1030, "n5"));
        Assert.Single(log.Steps);
        log.Reset(new RunReset(StoryKeyKind.SelfSwitch, 215, 215, "0"));
        Assert.Empty(log.Steps);
    }

    /// <summary>
    /// Asserts that an entry whose place lies behind the start place counts as claimed, and that a
    /// route reset lowers the start place.
    /// </summary>
    [Fact]
    public void StartPlace_CountsEntriesBehindItAsClaimedUntilARouteResetLowersIt()
    {
        RunLog log = RunLog.Begin(new RunPlace([30, 4, 0, 0]));

        Assert.True(log.Claims(Entry("e1", "world", place: [30, 2, 0, 0])));
        Assert.False(log.Claims(Entry("e2", "world", place: [30, 4, 0, 0])));
        log.Reset(new RunReset(StoryKeyKind.Variable, 1140, 1200, "n0"));
        Assert.Equal([30L, 0, 0, 0], log.StartPlace!.Markers);
        Assert.False(log.Claims(Entry("e3", "world", place: [30, 2, 0, 0])));
    }

    /// <summary>
    /// Asserts that a pending run is due once a thing of the receiver it read changed, which puts it
    /// first in the queue again, and that a reset of its step's keys drops it.
    /// </summary>
    [Fact]
    public void Pending_IsDueWhenAReadChangesAndDroppedByAReset()
    {
        RunLog log = RunLog.Begin(null);
        log.Queue(Entry("e3", "party:1"));
        log.Pend(Entry("e1", "party:1"), new Dictionary<string, string> { ["unlock_level"] = "0" });
        log.Pend(Entry("e2", "party:1", site: "map:419:24:1"), new Dictionary<string, string> { ["unlock_level"] = "0" });

        Assert.Empty(log.Due(_ => "0"));
        log.Reset(new RunReset(StoryKeyKind.SelfSwitch, 419, 419, "0"));
        Assert.Equal(["e1"], log.Due(_ => "1").Select(entry => entry.Id));
        Assert.Empty(log.Pending);
        Assert.Equal(["e1", "e3"], log.Queued.Select(entry => entry.Id));
    }

    /// <summary>
    /// Asserts that a run handed to the player waits in the queue once, until it is taken.
    /// </summary>
    [Fact]
    public void Queue_KeepsARunOnceUntilItIsTaken()
    {
        RunLog log = RunLog.Begin(null);
        log.Queue(Entry("e1", "party:1"));
        log.Queue(Entry("e1", "party:1"));
        log.Queue(Entry("e2", "party:1"));

        log.Taken(Entry("e1", "party:1"));

        Assert.Equal(["e2"], log.Queued.Select(entry => entry.Id));
    }

    /// <summary>
    /// Asserts that the log keeps, for each stream, the number of the last entry of a track it took,
    /// which the save keeps with it; an earlier entry handed again lowers nothing.
    /// </summary>
    [Fact]
    public void Queue_KeepsTheCursorOfEachStreamInTheSave()
    {
        RunLog log = RunLog.Begin(null);
        log.Queue(Entry("e4", "raid:w1:world") with { Number = 4 });
        log.Queue(Entry("e2", "raid:w1:world") with { Number = 2 });
        log.Queue(Entry("p1", "party:1"));

        RunLog read = RunLog.Read(log.Write());

        Assert.Equal(new Dictionary<string, long> { ["raid:w1:world"] = 4 }, read.Cursors);
    }

    /// <summary>
    /// Asserts that a receiver who opens a chest that waits for them makes the pending run done.
    /// </summary>
    [Fact]
    public void Pending_IsDoneOnceTheReceiverRunsTheSite()
    {
        RunLog log = RunLog.Begin(null);
        log.Pend(Entry("e1", "party:1"), new Dictionary<string, string> { ["unlock_level"] = "0" });

        log.Ran(Chest, Before(("ss215.27.A", "0")), null, null);

        Assert.Empty(log.Pending);
        Assert.False(log.Claims(Entry("e2", "party:1")));
    }

    /// <summary>
    /// Asserts that the log reads back as the save keeps it.
    /// </summary>
    [Fact]
    public void Write_ReadsBackAsTheSaveKeepsIt()
    {
        RunLog log = RunLog.Begin(new RunPlace([12, 0, 0, 0]));
        log.Ran(Chest, Before(("ss215.27.A", "0"), ("s2045", "0")), "party:1", "own");
        log.Pend(Entry("e1", "world", site: "ce:129"), new Dictionary<string, string> { ["g"] = "40" });
        log.Queue(Entry("e2", "party:1"));

        RunLog read = RunLog.Read(log.Write());

        Assert.Equal(log.Write(), read.Write());
        Assert.Equal(("ce:129", "40"), (read.Pending[0].Entry.Site.ToString(), read.Pending[0].Reads["g"]));
        Assert.Equal("e2", read.Queued.Single().Id);
    }

    /// <summary>
    /// Makes the keys of a step with their values before it.
    /// </summary>
    /// <param name="keys">Each key and its value.</param>
    /// <returns>The keys.</returns>
    private static Dictionary<StoryKey, string> Before(params (string Key, string Value)[] keys) =>
        keys.ToDictionary(pair => StoryKey.TryParse(pair.Key, out StoryKey key) ? key : default, pair => pair.Value);

    /// <summary>
    /// Makes the entry of a battle's drops the world's track handed.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="number">The number the track keeps it under.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry Drop(string id, long number) =>
        new(id, ReplaySite.Drop, WorldStream, StoryScope.World, "Ana", new Dictionary<StoryKey, string>(), null, new Dictionary<StoryKey, string>(), [], false)
        {
            Number = number,
            Found = true,
            Drops = [new KeyValuePair<int, int>(613, 1)],
        };

    /// <summary>
    /// Makes an entry of a run that opened the Makina chest.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="stream">Its stream.</param>
    /// <param name="site">Its site, the chest's unless given.</param>
    /// <param name="place">Its place, none unless given.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry Entry(string id, string stream, string? site = null, long[]? place = null)
    {
        ReplaySite at = site is null ? Chest : ReplaySite.Parse(site);
        (StoryKey key, string before) = at.IsCommon ? (StoryKey.Variable(57), "n0") : (StoryKey.SelfSwitch(at.MapId, at.EventId, "A"), "0");
        return new ReplayEntry(id, at, stream, StoryScope.Party, "Ana", new Dictionary<StoryKey, string> { [key] = before },
            place is null ? null : new RunPlace(place), new Dictionary<StoryKey, string>(), [], false);
    }
}
