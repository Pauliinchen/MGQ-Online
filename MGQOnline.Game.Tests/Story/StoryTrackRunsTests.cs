//----------------------------------------------------------------
//  StoryTrackRunsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the run entries the player's side of the story tracks sends and walks (Relay/README.md
/// "Story tracks", "Run entries").
/// </summary>
public sealed class StoryTrackRunsTests
{
    /// <summary>
    /// The site every entry of these tests ran at.
    /// </summary>
    private static readonly ReplaySite Site = ReplaySite.Page(7, 39, 0);

    /// <summary>
    /// Asserts that a run goes to the relay in the batch after its writes, named as a stream of the
    /// world's track it is sent on, with its opener.
    /// </summary>
    [Fact]
    public void Hand_SendsTheRunAfterItsWritesAsAStreamOfTheTrack()
    {
        var host = new Host();
        var track = new StoryTrack(host, () => "t1");
        track.Enter(false, null, "w1");
        track.Connection(true);
        track.Write([new StoryWrite("v50", "n1", "map:7:39:1")]);
        track.Hand(Entry("gift", "story"), "Ana");
        Sync(track);

        using JsonDocument sent = JsonDocument.Parse(host.Sent.Last());
        JsonElement run = sent.RootElement.GetProperty("run");
        ReplayEntry wired = ReplayWire.Read(run.GetProperty("wire").GetString()!);
        Assert.Equal("v50", sent.RootElement.GetProperty("writes")[0][0].GetString());
        Assert.Equal(("gift", "map:7:39:1", "v50", 10, "Ana"), (run.GetProperty("id").GetString(), run.GetProperty("site").GetString(), run.GetProperty("keys")[0].GetString(),
            run.GetProperty("place")[0].GetInt32(), run.GetProperty("opener").GetString()));
        Assert.Equal("raid:w1:world", wired.Stream);
    }

    /// <summary>
    /// Asserts that the entries of the track are handed in their order, each once, the next only
    /// after the game took the one before, which the relay hears; and that an entry pushed while
    /// earlier ones are still to come waits for them.
    /// </summary>
    [Fact]
    public void NextRun_HandsTheEntriesInOrderAndEachOnce()
    {
        var host = new Host();
        StoryTrack track = Placed(host, last: 4);
        track.Receive(Page("world", true, Run(1, "one"), Run(2, "two")));
        track.Receive(Live("world", Run(2, "two")));
        track.Receive(Live("world", Run(4, "four")));

        var handed = new List<string?> { track.NextRun(true, [])?.Id, track.NextRun(true, ["one"])?.Id, track.NextRun(true, [])?.Id, track.NextRun(true, [])?.Id };
        string asked = host.Sent.Last();
        track.Receive(Page("world", false, Run(3, "three")));
        handed.AddRange([track.NextRun(true, [])?.Id, track.NextRun(true, [])?.Id, track.NextRun(true, [])?.Id]);

        Assert.Equal(["one", null, "two", null, "three", "four", null], handed);
        Assert.Equal("""{"t":"runs","track":"world","after":2}""", asked);
        Assert.Equal([1, 2, 3, 4], host.Sent.Where(frame => frame.Contains("\"took\"")).Select(frame => JsonDocument.Parse(frame).RootElement.GetProperty("n").GetInt32()));
    }

    /// <summary>
    /// Asserts that nothing is handed while the player is not free, as in a battle, and that the
    /// walk goes on after it.
    /// </summary>
    [Fact]
    public void NextRun_WaitsWhileThePlayerIsNotFree()
    {
        var host = new Host();
        StoryTrack track = Placed(host, last: 1);
        track.Receive(Page("world", false, Run(1, "gift")));

        ReplayEntry? inBattle = track.NextRun(false, []);
        ReplayEntry? after = track.NextRun(true, []);

        Assert.Null(inBattle);
        Assert.Equal(("gift", "Ana"), (after?.Id, after?.Opener));
    }

    /// <summary>
    /// Asserts that a player who played an event on their own track and then reached the world's
    /// track is handed the world's entry of it too, which their log claims a step for in each
    /// stream.
    /// </summary>
    [Fact]
    public void NextRun_HandsBothStreamsOfAPlayerWhoReachedTheWorldsTrack()
    {
        var host = new Host();
        StoryTrack track = Placed(host, last: 1, on: "t1");
        track.Receive(Page("t1", false, Run(1, "own", "raid:w1:t1")));
        ReplayEntry? own = track.NextRun(true, []);
        track.Receive(State("world", cursor: 0, last: 1));
        track.Receive(Page("world", false, Run(1, "world", "raid:w1:world")));
        ReplayEntry? world = track.NextRun(true, []);
        RunLog log = RunLog.Begin(null);
        log.Ran(Site, new Dictionary<StoryKey, string> { [Key("v50")] = "n0" }, "story", "ran");

        Assert.Equal(("raid:w1:t1", "raid:w1:world"), (own?.Stream, world?.Stream));
        Assert.True(log.Claims(own!));
        Assert.True(log.Claims(world!));
    }

    /// <summary>
    /// Asserts that the sync names the cursors of the save's log on the world's tracks, so the relay
    /// hands what the save never kept again, and that an entry handed carries its number.
    /// </summary>
    [Fact]
    public void Sync_NamesTheCursorsOfTheSavedLogAndEntriesCarryTheirNumber()
    {
        var host = new Host { Saved = new Dictionary<string, long> { ["raid:w1:world"] = 3, ["raid:w1:t2"] = 1, ["raid:w9:world"] = 7, ["party:1"] = 2 } };
        var track = new StoryTrack(host, () => "t1");
        track.Enter(false, null, "w1");
        track.Connection(true);
        using JsonDocument sync = JsonDocument.Parse(host.Sent.Single(frame => frame.Contains("\"sync\"")));
        track.Receive(State("world", cursor: 3, last: 4));
        track.Receive(Page("world", false, Run(4, "four")));

        Assert.Equal("""{"t2":1,"world":3}""", sync.RootElement.GetProperty("cursors").GetRawText());
        Assert.Equal(4, track.NextRun(true, [])?.Number);
    }

    /// <summary>
    /// Makes an entry of the test site.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="stream">Its stream.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry Entry(string id, string stream) =>
        new(id, Site, stream, StoryScope.World, null, new Dictionary<StoryKey, string> { [Key("v50")] = "n0" }, new RunPlace([10, 0, 0, 0]),
            new Dictionary<StoryKey, string>(), [], false);

    /// <summary>
    /// Reads a key.
    /// </summary>
    /// <param name="text">The key, such as "v50".</param>
    /// <returns>The key.</returns>
    private static StoryKey Key(string text) => StoryKey.TryParse(text, out StoryKey key) ? key : throw new KeyNotFoundException(text);

    /// <summary>
    /// Writes a run entry as the relay keeps it.
    /// </summary>
    /// <param name="n">Its number on the track.</param>
    /// <param name="id">Its id.</param>
    /// <param name="stream">The stream its packed replay names.</param>
    /// <returns>The entry's JSON.</returns>
    private static string Run(long n, string id, string stream = "raid:w1:world") =>
        $$"""{"id":"{{id}}","site":"map:7:39:1","keys":["v50"],"place":[10,0,0,0],"opener":"Ana","wire":"{{ReplayWire.Write(Entry(id, stream))}}","n":{{n}}}""";

    /// <summary>
    /// Writes the relay's page of a track's entries.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <param name="more">Whether later entries follow.</param>
    /// <param name="runs">The entries.</param>
    /// <returns>The frame.</returns>
    private static string Page(string track, bool more, params string[] runs) =>
        $$"""{"t":"runs","track":"{{track}}","runs":[{{string.Join(',', runs)}}],"more":{{(more ? "true" : "false")}}}""";

    /// <summary>
    /// Writes the relay's push of an entry the track kept.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <param name="run">The entry.</param>
    /// <returns>The frame.</returns>
    private static string Live(string track, string run) => $$"""{"t":"run","track":"{{track}}","run":{{run}}}""";

    /// <summary>
    /// Writes the relay's state of a track.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <param name="cursor">The player's cursor on it.</param>
    /// <param name="last">Its last entry's number.</param>
    /// <returns>The frame.</returns>
    private static string State(string track, long cursor, long last) =>
        $$"""{"t":"state","why":"sync","track":"{{track}}","rev":5,"part":"1","gate":null,"world":{"rev":5,"part":"1","route":"none","done":[],"checkpoints":[]},"mapping":7,"seq":0,"keys":{},"chests":{},"tellings":[],"cursor":{{cursor}},"last":{{last}}}""";

    /// <summary>
    /// Enters a world's story and takes the relay's state of a track.
    /// </summary>
    /// <param name="host">The host.</param>
    /// <param name="last">The track's last entry's number.</param>
    /// <param name="on">The track.</param>
    /// <returns>The track.</returns>
    private static StoryTrack Placed(Host host, long last, string on = "world")
    {
        var track = new StoryTrack(host, () => "t1");
        track.Enter(false, null, "w1");
        track.Connection(true);
        track.Receive(State(on, 0, last));
        return track;
    }

    /// <summary>
    /// Hands a track the relay's state of the world's track without entries.
    /// </summary>
    /// <param name="track">The track.</param>
    private static void Sync(StoryTrack track) => track.Receive(State("world", 0, 0));

    /// <summary>
    /// Keeps the frames a track sends.
    /// </summary>
    private sealed class Host : IStoryTrackHost
    {
        /// <summary>
        /// Gets the frames sent, in order.
        /// </summary>
        public List<string> Sent { get; } = [];

        /// <summary>
        /// Gets or sets the cursors of the save's log.
        /// </summary>
        public Dictionary<string, long> Saved { get; set; } = [];

        /// <inheritdoc />
        public IReadOnlyDictionary<string, long> Cursors() => Saved;

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
