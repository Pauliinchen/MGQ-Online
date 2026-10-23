//----------------------------------------------------------------
//  StoryTrackRelayTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
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
        track.Enter(fresh, new StoryLevel(10, null));
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
