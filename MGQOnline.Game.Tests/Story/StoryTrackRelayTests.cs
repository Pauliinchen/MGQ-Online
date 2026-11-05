//----------------------------------------------------------------
//  StoryTrackRelayTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Checked the keys and values one game's scripts hand over reaching the other game's scripts as the same values, in the track and in a run
//      Paulinchen  2026-10-31: Checked a run one game hands over reaching the other through the relay's walk, once
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Plays two games' tracks against the relay's own story tracks, run by Node through
/// fixtures/story/track_harness.mjs, so the frames both sides write are the ones the other reads.
/// Skipped where Node is not installed.
/// </summary>
public sealed class StoryTrackRelayTests : IDisposable
{
    /// <summary>
    /// The relay's tracks in Node.
    /// </summary>
    private readonly Process? relay;

    /// <summary>
    /// The games by their player's id.
    /// </summary>
    private readonly Dictionary<string, (StoryTrack Track, Game Host)> games = [];

    /// <summary>
    /// Starts the relay's tracks, when Node is there.
    /// </summary>
    public StoryTrackRelayTests()
    {
        string? root = RepositoryRoot();
        if (root is null)
        {
            return;
        }

        try
        {
            relay = Process.Start(new ProcessStartInfo("node", $"\"{Path.Combine(root, "fixtures", "story", "track_harness.mjs")}\"")
            {
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                WorkingDirectory = root,
            });
        }
        catch (System.ComponentModel.Win32Exception)
        {
            relay = null;
        }
    }

    /// <inheritdoc />
    public void Dispose()
    {
        if (relay is null)
        {
            return;
        }

        relay.StandardInput.Close();
        relay.WaitForExit(5000);
        relay.Dispose();
    }

    /// <summary>
    /// Asserts that the first game starts the world's story from its seed, that the second plays on
    /// the world's track with the seed's values dropped, that a write reaches the other game as a
    /// push, that a one-way key the writer lowers comes back as the relay's value, that a key without
    /// a row stays the writer's own, and that a telling the other watches reaches it.
    /// </summary>
    [Fact]
    public void TwoGames_PlayOneStoryOnTheRelaysTracks()
    {
        Assert.SkipWhen(relay is null, "Node is not installed.");
        StoryTrack alice = Join("a1", 0, true, new Dictionary<string, string> { ["v1001"] = "n5", ["s7096"] = "0", ["s8000"] = "1" });
        StoryTrack bob = Join("b2", 1, false, new Dictionary<string, string> { ["v1001"] = "n3" });
        TrackState started = alice.Take()!.State!;
        TrackState placed = bob.Take()!.State!;

        alice.Write([new StoryWrite("v1001", "n6", "map:7:39:1"), new StoryWrite("s8000", "0", "map:7:39:1")]);
        Pump();
        StoryTake pushed = bob.Take()!;
        alice.Write([new StoryWrite("v1001", "n4", "map:7:39:1")]);
        Pump();
        StoryTake answered = alice.Take()!;
        StoryRefusal[] refusals = [.. alice.TakeRefusals()];

        alice.Tell("map:7:39:1", 7);
        Pump();
        bob.Watch(0);
        Pump();
        alice.Tell(null, 7);
        Pump();

        Assert.Equal(("started", "n5", false), (started.Why, started.Keys["v1001"], started.Keys.ContainsKey("s8000")));
        Assert.Equal(("sync", StoryTrack.WorldTrack, "n5"), (placed.Why, placed.Track, placed.Keys["v1001"]));
        Assert.Equal([new("v1001", "n6")], pushed.Keys);
        Assert.Equal([new("v1001", "n6")], answered.Keys);
        Assert.Equal(["s8000 personal", "v1001 one_way"], refusals.Select(refusal => $"{refusal.Key} {refusal.Code}"));
        Assert.Equal((true, 0, alice.TrackRev), (alice.TellingGranted is null, bob.Tellings.Count, bob.Told[0]));
        Assert.Contains(games["b2"].Host.Received, frame => frame.Contains("\"t\":\"watch\"", StringComparison.Ordinal) && frame.Contains("\"watching\":true", StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts that a run one game hands over after its writes reaches the other game's walk with its
    /// opener, and its own too, and that the same run of a second opener, whose writes changed
    /// nothing, reaches nobody.
    /// </summary>
    [Fact]
    public void TwoGames_HandARunOverThroughTheRelaysTrack()
    {
        Assert.SkipWhen(relay is null, "Node is not installed.");
        StoryTrack alice = Join("a1", 0, true, new Dictionary<string, string> { ["v1001"] = "n5" });
        StoryTrack bob = Join("b2", 1, false, new Dictionary<string, string> { ["v1001"] = "n5" });
        StoryKey.TryParse("v1001", out StoryKey key);
        ReplayEntry Run(string id) => new(id, ReplaySite.Page(7, 39, 0), "story", StoryScope.World, null, new Dictionary<StoryKey, string> { [key] = "n5" },
            new RunPlace([5, 0, 0, 0]), new Dictionary<StoryKey, string>(), [], false);

        alice.Write([new StoryWrite("v1001", "n6", "map:7:39:1")]);
        alice.Hand(Run("gift"), "Ana");
        bob.Write([new StoryWrite("v1001", "n6", "map:7:39:1")]);
        bob.Hand(Run("again"), "Bo");
        Pump();
        ReplayEntry? received = bob.NextRun(true, []);
        ReplayEntry? own = alice.NextRun(true, []);
        ReplayEntry? after = bob.NextRun(true, []);
        Pump();

        Assert.Equal(("gift", "Ana", "raid:w1:world"), (received?.Id, received?.Opener, received?.Stream));
        Assert.Equal("gift", own?.Id);
        Assert.Null(after);
        Assert.Contains(games["b2"].Host.Received, frame => frame.Contains("\"id\":\"again\",\"n\":null", StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts that the keys and values one game's scripts stage (a switch, a self switch, a whole
    /// number, a text, a Float and a frozen fight) reach the other game's scripts through the relay's
    /// track as the same values, and that a run handed over after them reaches the other game's replay with the
    /// same keys and start values.
    /// </summary>
    [Fact]
    public void TwoGames_CarryTheScriptsKeysAndValuesThroughTheRelaysTrack()
    {
        Assert.SkipWhen(relay is null, "Node is not installed.");
        StoryTrack alice = Join("a1", 0, true, StoryPlain.TextsOf(new RubyArray { new RubyArray { 1, 1001, 5 } }).ToDictionary(pair => pair.Key.ToString(), pair => pair.Value));
        StoryTrack bob = Join("b2", 1, false, []);
        alice.Take();
        bob.Take();
        RubyArray rows =
        [
            new RubyArray { 0, 7096, true }, new RubyArray { 2, new RubyArray { 231, 5, "B" }, true }, new RubyArray { 1, 1001, 6 },
            new RubyArray { 1, 1052, "アリス" }, new RubyArray { 1, 1062, new RubyHash { { "float", "2.5" } } },
            new RubyArray
            {
                3, 868, new RubyHash
                {
                    { "troop", 868 }, { "site", new RubyArray { "map", 138, 13, 1 } }, { "outer", new RubyArray { "map", 138, 13, 1 } }, { "scene", false },
                    { "tableau", new RubyArray { 138, new RubyArray { new RubyArray { 13, 32, 8, 2, 1, "$Sonya", 0, 0, 255, 0, 1, 1, 1 } }, new RubyArray() } },
                    { "spot", new RubyArray { 138, 30, 10, 8 } }, { "held", new RubyArray { new RubyArray { 1, 1075, 14 } } },
                }
            },
        ];
        RubyArray before = [new RubyArray { 0, 7096, false }, new RubyArray { 1, 1001, 5 }];
        RubyArray start = [new RubyArray { 1, 1052, "ルカ" }];

        alice.Write(StoryPlain.WritesOf(new RubyArray(rows.Select(row => (RubyValue)new RubyArray { row.AsArray()[0], row.AsArray()[1], row.AsArray()[2], new RubyArray { "map", 7, 39, 1 } }))));
        alice.Hand(ReplayEntry.Read(new RubyHash
        {
            { "id", "gift" }, { "site", new RubyArray { "map", 7, 39, 1 } }, { "stream", "story" }, { "scope", "world" }, { "opener", RubyNil.Value }, { "keys", before },
            { "place", new RubyArray { 5, 0, 0, 0 } }, { "start", start }, { "inputs", new RubyArray() }, { "derived", false },
        }), "Ana");
        Pump();
        RubyHash pushed = StoryPlain.TakeOf(bob.Take()!);
        RubyHash run = bob.NextRun(true, [])!.Write();

        Assert.Equal(Sorted(rows), Sorted(pushed["keys"].AsArray()));
        Assert.Equal((Sorted(before), start), (Sorted(run["keys"].AsArray()), run["start"]));
    }

    /// <summary>
    /// Finds the repository's root folder above the tests.
    /// </summary>
    /// <returns>The folder, <see langword="null"/> when it is not found.</returns>
    private static string? RepositoryRoot()
    {
        for (DirectoryInfo? folder = new(AppContext.BaseDirectory); folder is not null; folder = folder.Parent)
        {
            if (File.Exists(Path.Combine(folder.FullName, "Relay", "core", "story_tracks.js")))
            {
                return folder.FullName;
            }
        }

        return null;
    }

    /// <summary>
    /// Orders rows by what they hold, as the relay may push them in another order.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>The rows in order.</returns>
    private static RubyArray Sorted(RubyArray rows) => new(rows.OrderBy(row => row.ToString(), StringComparer.Ordinal));

    /// <summary>
    /// Lets a game enter the world room, sync and hand the seed the relay asks for.
    /// </summary>
    /// <param name="player">The player's id.</param>
    /// <param name="seat">The game's seat.</param>
    /// <param name="fresh">Whether the game starts afresh.</param>
    /// <param name="seed">Its story.</param>
    /// <returns>The game's track.</returns>
    private StoryTrack Join(string player, int seat, bool fresh, Dictionary<string, string> seed)
    {
        var host = new Game(player);
        var track = new StoryTrack(host, () => $"{player}t");
        games[player] = (track, host);
        Step(new { op = "enter", player, seat });
        track.Enter(fresh, new StoryLevel(10, null), "w1");
        track.Connection(true);
        Pump();
        Assert.True(track.NeedsSeed);
        track.Seed(seed);
        Pump();
        return track;
    }

    /// <summary>
    /// Hands the relay the frames the games sent, and the games the relay's answers, until none is left.
    /// </summary>
    private void Pump()
    {
        for (int round = 0; round < 20; round++)
        {
            (string Player, string Text)[] sent = [.. games.Values.SelectMany(game => game.Host.TakeSent().Select(text => (game.Host.Player, text)))];
            if (sent.Length == 0)
            {
                return;
            }

            foreach ((string player, string text) in sent)
            {
                Step(new { op = "frame", player, text = $"track {text}" });
            }
        }
    }

    /// <summary>
    /// Runs one step of the relay and hands each game the frames the relay sent it.
    /// </summary>
    /// <param name="step">The step.</param>
    private void Step(object step)
    {
        relay!.StandardInput.WriteLine(JsonSerializer.Serialize(step, step.GetType(), JsonSerializerOptions.Default));
        relay.StandardInput.Flush();
        while (relay.StandardOutput.ReadLine() is { } line)
        {
            using JsonDocument document = JsonDocument.Parse(line);
            JsonElement reply = document.RootElement;
            if (reply.TryGetProperty("done", out _))
            {
                return;
            }

            string player = reply.GetProperty("player").GetString()!;
            string text = reply.GetProperty("text").GetString()!;
            string json = text["track ".Length..];
            games[player].Host.Received.Add(json);
            games[player].Track.Receive(json);
        }
    }

    /// <summary>
    /// A game's side towards the relay: the frames its track sends, which the next pump hands over.
    /// </summary>
    /// <param name="player">The player's id.</param>
    private sealed class Game(string player) : IStoryTrackHost
    {
        /// <summary>
        /// The frames sent since the last pump.
        /// </summary>
        private readonly List<string> sent = [];

        /// <summary>
        /// Gets the player's id.
        /// </summary>
        public string Player { get; } = player;

        /// <summary>
        /// Gets the frames the relay sent the game.
        /// </summary>
        public List<string> Received { get; } = [];

        /// <inheritdoc />
        public bool Send(string json)
        {
            sent.Add(json);
            return true;
        }

        /// <inheritdoc />
        public void Log(string line)
        {
        }

        /// <summary>
        /// Takes the frames sent since the last time.
        /// </summary>
        /// <returns>The frames, oldest first.</returns>
        public string[] TakeSent()
        {
            string[] taken = [.. sent];
            sent.Clear();
            return taken;
        }
    }
}
