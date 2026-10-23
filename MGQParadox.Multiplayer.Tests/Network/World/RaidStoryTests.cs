//----------------------------------------------------------------
//  RaidStoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Covered the frames queued just before the world is closed
//      Paulinchen  2026-10-23: Covered the shared companions alone and the story tracks' frames over the world room
//      Paulinchen  2026-10-17: Covered the frozen raid boss fights of keyed stories and the end of one
//      Paulinchen  2026-10-15: Covered keyed stories: changed keys alone, the first writer, pushes laid over the story held the move from a sealed story and the affection
//      Paulinchen  2026-10-12: Covered the level caps of story writes
//                            - Covered a write sent again after a route lock
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers what a Raid World keeps beside its story tracks at a relay inside this process: the shared
/// companions fetched and added, the story entry every game's inbox gets, and the story tracks'
/// frames both ways over the world room.
/// </summary>
public sealed class RaidStoryTests
{
    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(8);

    /// <summary>
    /// Asserts that a world nobody wrote for tells revision 0 and shares no companion.
    /// </summary>
    [Fact]
    public void Fetch_NothingWritten_TellsRevisionZero()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);

        Assert.Equal(string.Empty, story.Describe());
        Assert.True(story.Fetch(IdOf(code)));
        var state = Await(story, "fetch", "done");

        Assert.Equal((IdOf(code), "0", string.Empty), (state["world"], state["rev"], state["comps"]));
    }

    /// <summary>
    /// Asserts that companions added grow the shared list, every game in the world hears of the
    /// change, and another player fetches the list.
    /// </summary>
    [Fact]
    public void AddCompanions_GrowsTheSharedListAndIsHeard()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var story = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);

        Assert.True(story.AddCompanions(IdOf(code), "382, 5,382"));
        Assert.Equal("5,382", Await(story, "companions", "done")["comps"]);
        Assert.Equal("1", AwaitEntry(session, "story")["rev"]);
        session.Close();
        Assert.True(other.Fetch(IdOf(code)));
        Assert.Equal("5,382", Await(other, "fetch", "done")["comps"]);
        Assert.False(story.AddCompanions(IdOf(code), "5,x"));
        Assert.False(story.AddCompanions(IdOf(code), string.Empty));
    }

    /// <summary>
    /// Asserts that a fetch in another world forgets the state of the world before.
    /// </summary>
    [Fact]
    public void Fetch_InAnotherWorld_ForgetsTheStateOfTheWorldBefore()
    {
        using var relay = new TestRelay();
        var first = MakeWorld(relay, WorldType.Raid);
        var second = MakeWorld(relay, WorldType.Raid);
        var story = new RaidStory
        {
            RelayAddress = _ => relay.Address,
            Playing = () => (CreatorKey, "Player"),
            WorldOf = id => id == IdOf(first) ? first : id == IdOf(second) ? second : null,
            RetryDelays = [TimeSpan.FromMilliseconds(50)],
        };

        Assert.True(story.AddCompanions(IdOf(first), "5"));
        Assert.Equal(IdOf(first), Await(story, "companions", "done")["world"]);
        Assert.True(story.Fetch(IdOf(second)));
        var fetched = Await(story, "fetch", "done");

        Assert.Equal((IdOf(second), "0", string.Empty), (fetched["world"], fetched["rev"], fetched["comps"]));
    }

    /// <summary>
    /// Asserts that a Classic world keeps no story, which the fetch fails with, and that nothing
    /// starts outside the world.
    /// </summary>
    [Fact]
    public void Fetch_ClassicWorldOrOutsideIt_Fails()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Classic);
        var story = NewStory(relay, CreatorKey, code);

        Assert.False(story.Fetch("0".PadLeft(32, '0')));
        Assert.True(story.Fetch(IdOf(code)));
        Assert.Equal("The relay keeps no story of this world.", Await(story, "fetch", "failed")["fetch_error"]);
    }

    /// <summary>
    /// Asserts that a story tracks' frame goes to the relay over the open world room, one the relay
    /// sends waits for the DLL's story apart from the inbox, and each connection is counted.
    /// </summary>
    [Fact]
    public void TrackFrames_TravelBothWaysOverTheWorldRoom()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };

        Assert.False(session.SendTrack("""{"t":"sync"}"""));
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        Assert.True(session.SendTrack("""{"t":"sync"}"""));
        WaitUntil(() => relay.TrackFrames.Length == 1, "the frame at the relay");
        relay.Tell(IdOf(code), """track {"t":"need","what":"seed"}""");
        string? frame = null;
        WaitUntil(() => (frame = session.TakeTrackFrame()) is not null, "the relay's frame");
        session.Close();

        Assert.Equal((WorldKeys.PlayerIdOf(OtherKey), """{"t":"sync"}"""), relay.TrackFrames.Single());
        Assert.Equal("""{"t":"need","what":"seed"}""", frame);
        Assert.Equal(1, session.Connections);
    }

    /// <summary>
    /// Asserts that the frames queued just before the world is closed still reach the relay, in
    /// their order: the close waits for the writer.
    /// </summary>
    [Fact]
    public void FramesQueuedJustBeforeTheClose_StillGoOut()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };
        var frames = Enumerable.Range(1, 50).Select(number => $$"""{"t":"write","n":{{number}}}""").ToArray();

        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        Assert.All(frames, frame => Assert.True(session.SendTrack(frame)));
        session.Close();

        WaitUntil(() => relay.TrackFrames.Length == frames.Length, "every frame at the relay");
        Assert.Equal(frames, relay.TrackFrames.Select(frame => frame.Json));
    }

    /// <summary>
    /// Makes a world of a type with the creator.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="type">The world's type.</param>
    /// <returns>The world's code.</returns>
    private static WorldCode MakeWorld(TestRelay relay, string type)
    {
        var made = Act(NewDirectory(relay, CreatorKey, "Creator"), directory => directory.Create("Raid", "secret", 4, false, false, [], null, type));
        return WorldCode.Parse(made["code"])!;
    }

    /// <summary>
    /// Tells a world's id.
    /// </summary>
    /// <param name="code">The world's code.</param>
    /// <returns>The id.</returns>
    private static string IdOf(WorldCode code) => Relays.WorldRoomOf(code.Token);

    /// <summary>
    /// Makes one player's Raid World state, reaching only the test relay and in the given world.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="code">The world the player is in.</param>
    /// <returns>The state.</returns>
    private static RaidStory NewStory(TestRelay relay, string key, WorldCode code) => new()
    {
        RelayAddress = _ => relay.Address,
        Playing = () => (key, "Player"),
        WorldOf = id => IdOf(code) == id ? code : null,
        RetryDelays = [TimeSpan.FromMilliseconds(50)],
    };

    /// <summary>
    /// Waits until a kind of request reaches a state.
    /// </summary>
    /// <param name="story">The player's state.</param>
    /// <param name="kind">The kind: fetch or companions.</param>
    /// <param name="state">The state.</param>
    /// <returns>The state as the game script reads it.</returns>
    private static Message Await(RaidStory story, string kind, string state)
    {
        Message? described = null;
        WaitUntil(() => (described = Message.Decode(story.Describe()))[kind] is { Length: > 0 } now && now != "busy", $"the {kind}");
        Assert.True(described![kind] == state, $"{kind} is {described[kind]}: {story.Describe()}");
        return described;
    }

    /// <summary>
    /// Waits for an inbox entry of a kind, taking the others before it.
    /// </summary>
    /// <param name="session">The connection to the world.</param>
    /// <param name="kind">The kind.</param>
    /// <returns>The entry.</returns>
    private static Message AwaitEntry(WorldSession session, string kind)
    {
        Message? found = null;

        WaitUntil(() =>
        {
            while (session.PeekMessage() is { } entry)
            {
                session.TakeMessage(entry);

                if (Message.Decode(entry)["kind"] == kind)
                {
                    found = Message.Decode(entry);
                    return true;
                }
            }

            return false;
        }, $"a {kind} entry");

        return found!;
    }

    /// <summary>
    /// Waits until a condition holds.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is awaited, for the timeout's message.</param>
    private static void WaitUntil(Func<bool> condition, string what)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (condition())
            {
                return;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"Never reached {what}.");
    }
}
