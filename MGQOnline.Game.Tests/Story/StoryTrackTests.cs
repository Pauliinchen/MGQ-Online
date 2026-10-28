//----------------------------------------------------------------
//  StoryTrackTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked whose ended telling the game waits for the take of
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the player's side of the story tracks against frames as the relay writes them
/// (Relay/README.md "Story tracks").
/// </summary>
public sealed class StoryTrackTests
{
    /// <summary>
    /// Asserts that entering syncs with the level, that the relay's need of a seed waits for the
    /// scripts' story, and that a new game's sync places the player anew by it.
    /// </summary>
    [Fact]
    public void Enter_SyncsAndHandsTheSeedTheRelayNeeds()
    {
        var host = new Host();
        var track = new StoryTrack(host, () => "t1");
        track.Enter(true, new StoryLevel(12, null));
        track.Connection(true);
        track.Receive("""{"t":"need","what":"seed"}""");
        bool needed = track.NeedsSeed;
        track.Seed(new Dictionary<string, string> { ["v1001"] = "n0" });

        Assert.True(needed);
        Assert.Equal("""{"t":"sync","level":{"best":12,"cap":null},"fresh":true}""", host.Sent[0]);
        Assert.Equal("""{"t":"sync","level":{"best":12,"cap":null},"fresh":true,"seed":{"v1001":"n0"}}""", host.Sent[1]);
    }

    /// <summary>
    /// Asserts that writes before the relay placed the player wait, then go numbered after the last
    /// batch the relay took, and that the state waits for the scripts' take.
    /// </summary>
    [Fact]
    public void State_SendsTheWritesThatWaitedAfterTheLastBatch()
    {
        var host = new Host();
        StoryTrack track = Synced(host, seq: 41);
        StoryTake? take = track.Take();

        Assert.Equal("""{"t":"write","seq":42,"track":"world","writes":[["s7096","1","map:7:39:1"]]}""", host.Sent.Last());
        Assert.NotNull(take);
        Assert.Equal(("sync", "world", "n12", true), (take.State!.Why, take.State.Track, take.State.Keys["v1001"], take.State.Held.Contains("s7096")));
        Assert.Null(track.Take());
    }

    /// <summary>
    /// Asserts that a value pushed for a key the player's own unanswered request wrote is dropped,
    /// and that the answer's own value of a refused request is taken in its place.
    /// </summary>
    [Fact]
    public void Push_HoldsBackTheKeysOfTheOwnUnansweredRequests()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Take();
        track.Write([new StoryWrite("v1001", "n13", "map:7:39:1")]);
        track.Receive("""{"t":"push","track":"world","rev":6,"prev":5,"keys":{"v1001":"n11","v50":"n2"}}""");
        StoryTake? during = track.Take();
        track.Receive("""{"t":"answer","seq":1,"revs":{"world":6},"mapping":7,"keys":{}}""");
        track.Receive("""{"t":"answer","seq":2,"revs":{"world":6},"mapping":7,"keys":{"v1001":{"code":"one_way","value":"n14"}}}""");
        StoryTake? after = track.Take();

        Assert.Equal([new("v50", "n2")], during!.Keys);
        Assert.Equal([new("v1001", "n14")], after!.Keys);
        Assert.Equal(new StoryRefusal("v1001", "one_way", "n14"), track.TakeRefusals().Single());
    }

    /// <summary>
    /// Asserts that the player's own newer write drops a value that waits for the same key.
    /// </summary>
    [Fact]
    public void Write_DropsTheValueThatWaitsForTheSameKey()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Take();
        track.Receive("""{"t":"answer","seq":1,"keys":{}}""");
        track.Receive("""{"t":"push","track":"world","rev":6,"prev":5,"keys":{"v50":"n2"}}""");
        track.Write([new StoryWrite("v50", "n3", "ce:20")]);

        Assert.Null(track.Take());
    }

    /// <summary>
    /// Asserts that a push that skips a revision of the player's track asks for the whole track,
    /// while a player behind takes the world's pushes as they come.
    /// </summary>
    [Fact]
    public void Push_AsksForTheWholeTrackAfterAGap()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Take();
        host.Sent.Clear();
        track.Receive("""{"t":"push","track":"world","rev":9,"prev":8,"keys":{"v50":"n2"}}""");
        var behind = new StoryTrack(new Host(), () => "t1");
        behind.Enter(false, null);
        behind.Connection(true);
        behind.Receive("""{"t":"state","why":"behind","track":"t3","rev":2,"part":"1","gate":25,"world":{"rev":40,"part":"2","route":"none","done":[],"checkpoints":["1"]},"mapping":7,"seq":0,"keys":{},"chests":{},"tellings":[]}""");
        behind.Take();
        behind.Receive("""{"t":"push","track":"world","rev":44,"prev":43,"keys":{"v3005":"n9"}}""");

        Assert.Equal("""{"t":"sync"}""", host.Sent.Single());
        Assert.Null(track.Take());
        Assert.Equal([new("v3005", "n9")], behind.Take()!.Keys);
        Assert.Equal(44L, behind.World!.Rev);
    }

    /// <summary>
    /// Asserts that a batch the relay answers with sync goes again after the next state, one it took
    /// already asks for the whole track, and one it found wrong is dropped.
    /// </summary>
    [Fact]
    public void Answer_SendsAgainOrDropsTheBatchesTheRelayDidNotTake()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Receive("""{"t":"answer","seq":1,"code":"sync"}""");
        Sync(track);
        string again = host.Sent.Last();
        track.Receive("""{"t":"answer","seq":1,"code":"seen","revs":{"world":5}}""");
        string asked = host.Sent.Last();
        track.Write([new StoryWrite("s9", "1", "game")]);
        track.Receive("""{"t":"answer","seq":2,"code":"bad","error":"no","index":0}""");

        Assert.Equal("""{"t":"write","seq":1,"track":"world","writes":[["s7096","1","map:7:39:1"]]}""", again);
        Assert.Equal("""{"t":"sync"}""", asked);
        Assert.Equal(0, track.Unanswered);
    }

    /// <summary>
    /// Asserts that a new connection syncs again and then sends the batches it may not have taken and
    /// the player's telling, but none twice over the same connection.
    /// </summary>
    [Fact]
    public void Connection_SendsTheUntakenBatchesAndTheTellingAfterTheNextSync()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Tell("map:7:39:1", 7);
        track.Connection(false);
        track.Connection(true);
        host.Sent.Clear();
        Sync(track);
        Sync(track);

        Assert.Equal(
            ["""{"t":"write","seq":1,"track":"world","writes":[["s7096","1","map:7:39:1"]]}""", """{"t":"tell","telling":"t1","map":7,"event":"map:7:39:1"}""",
             """{"t":"tell","telling":"t1","map":7,"event":"map:7:39:1"}"""],
            host.Sent);
    }

    /// <summary>
    /// Asserts that a telling keeps its id on another map and ends with told, and that watching a
    /// teller waits for the relay to tell of their telling.
    /// </summary>
    [Fact]
    public void Tell_KeepsTheTellingAcrossMapsAndWatchesOnceTold()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        host.Sent.Clear();
        track.Tell("map:7:39:1", 7);
        track.Tell("map:7:39:1", 8);
        track.Tell(null, 8);
        track.Watch(2);
        track.Receive("""{"t":"telling","telling":"x9","teller":2,"map":8,"event":"ce:30","track":"world"}""");
        track.Receive("""{"t":"told","telling":"x9","teller":2,"map":8,"track":"world","rev":9,"why":"ended"}""");

        Assert.Equal(
            ["""{"t":"tell","telling":"t1","map":7,"event":"map:7:39:1"}""", """{"t":"tell","telling":"t1","map":8,"event":"map:7:39:1"}""",
             """{"t":"told","telling":"t1"}""", """{"t":"watch","teller":2,"telling":"x9"}"""],
            host.Sent);
        Assert.Equal((9L, 0), (track.Told[2], track.Tellings.Count));
    }

    /// <summary>
    /// Asserts that another teller's telling that ended at a revision not taken yet names a seat to
    /// wait for while something waits to be taken, and that the player's own telling's end never does.
    /// </summary>
    [Fact]
    public void Told_NamesTheTellerWhoseRevisionWaitsButNeverTheOwn()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        track.Take();
        track.Receive("""{"t":"push","track":"world","rev":6,"prev":5,"keys":{"v50":"n2"}}""");
        track.Receive("""{"t":"told","telling":"x9","teller":2,"map":7,"track":"world","rev":6,"why":"ended"}""");
        int? waiting = track.AwaitingSeat;
        track.Take();
        int? taken = track.AwaitingSeat;
        track.Tell("map:7:39:1", 7);
        track.Tell(null, 7);
        track.Receive("""{"t":"push","track":"world","rev":7,"prev":6,"keys":{"v51":"n3"}}""");
        track.Receive("""{"t":"told","telling":"t1","teller":9,"map":7,"track":"world","rev":7,"why":"ended"}""");

        Assert.Equal((2, null, null, true), (waiting, taken, track.AwaitingSeat, track.Pending));
    }

    /// <summary>
    /// Asserts that a write the relay would refuse a whole batch for is left out, and that a frame of
    /// more writes than one batch takes goes as several.
    /// </summary>
    [Fact]
    public void Write_LeavesOutWhatTheRelayRefusesAndSplitsLargeFrames()
    {
        var host = new Host();
        StoryTrack track = Synced(host);
        host.Sent.Clear();
        track.Write([new StoryWrite("v5", "fInfinity", "game"), new StoryWrite("s5", "1", "map:0:1:1"), new StoryWrite("x5", "1", "game")]);
        int left = host.Sent.Count;
        track.Write([.. Enumerable.Range(1, StoryTrack.MaxWrites + 1).Select(id => new StoryWrite($"s{id}", "1", "ce:154"))]);

        Assert.Equal(0, left);
        Assert.Equal([StoryTrack.MaxWrites, 1], host.Sent.Select(frame => JsonDocument.Parse(frame).RootElement.GetProperty("writes").GetArrayLength()));
    }

    /// <summary>
    /// Enters a track, connects it, records a write and takes the relay's state.
    /// </summary>
    /// <param name="host">The host.</param>
    /// <param name="seq">The last batch the relay took.</param>
    /// <returns>The track.</returns>
    private static StoryTrack Synced(Host host, long seq = 0)
    {
        var track = new StoryTrack(host, () => "t1");
        track.Enter(false, null);
        track.Connection(true);
        track.Write([new StoryWrite("s7096", "1", "map:7:39:1")]);
        Sync(track, seq);
        return track;
    }

    /// <summary>
    /// Hands a track the relay's state of the world's track at revision 5.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <param name="seq">The last batch the relay took.</param>
    private static void Sync(StoryTrack track, long seq = 0) =>
        track.Receive($$"""{"t":"state","why":"sync","track":"world","rev":5,"part":"1","gate":null,"world":{"rev":5,"part":"1","route":"none","done":[],"checkpoints":[]},"mapping":7,"seq":{{seq}},"keys":{"v1001":"n12","s7096":"0"},"chests":{},"tellings":[]}""");

    /// <summary>
    /// Keeps the frames a track sends.
    /// </summary>
    private sealed class Host : IStoryTrackHost
    {
        /// <summary>
        /// Gets the frames sent, in order.
        /// </summary>
        public List<string> Sent { get; } = [];

        /// <inheritdoc />
        public bool Send(string json)
        {
            Sent.Add(json);
            return true;
        }

        /// <inheritdoc />
        public void Log(string line)
        {
        }
    }
}
