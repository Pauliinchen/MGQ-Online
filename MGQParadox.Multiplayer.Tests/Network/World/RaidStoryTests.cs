//----------------------------------------------------------------
//  RaidStoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Covered keyed stories: changed keys alone, the first writer, pushes laid over the story held the move from a sealed story and the affection
//      Paulinchen  2026-10-12: Covered the level caps of story writes
//                            - Covered a write sent again after a route lock
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers a Raid World's story at a relay inside this process: fetching, writing, conflicts,
/// checkpoints, the route lock, shared companions, the story entry every game's inbox gets, and the
/// counters and the seal the story travels with.
/// </summary>
public sealed class RaidStoryTests
{
    /// <summary>
    /// A story as the game script packs it, with a text outside ASCII among its variables.
    /// </summary>
    private static readonly string Story = Packed("s=5", "sf=6", "v=1001:n18,20:s44Ki44Oq44K5", "ss=12.3.A", "ssf=12.3.B", "a=5:2173");

    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(8);

    /// <summary>
    /// Asserts that a world nobody wrote a story for tells revision 0 and no text.
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

        Assert.Equal(("0", "0", "1", "none", string.Empty), (state["rev"], state["p"], state["part"], state["route"], state.Team));
        Assert.Equal(IdOf(code), state["world"]);
    }

    /// <summary>
    /// Asserts that a write is accepted, every game in the world hears of it, and another player
    /// fetches the same story unsealed.
    /// </summary>
    [Fact]
    public void Post_OnTheCurrentRevision_IsAcceptedAndHeard()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var creator = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);

        Assert.True(creator.Post(IdOf(code), 0, "p=18;r1141=0;r1142=0;r1143=0;end=2,148,243", Story));
        var posted = Await(creator, "post", "accepted");
        Assert.Equal(("1", "1", "18", "2,148,243"), (posted["rev"], posted["post_rev"], posted["p"], posted["end"]));
        Assert.Equal(KeysOf(Story), KeysOf(posted.Team));

        var heard = AwaitEntry(session, "story");
        Assert.Equal("1", heard["rev"]);
        session.Close();

        Assert.True(other.Fetch(IdOf(code)));
        var fetched = Await(other, "fetch", "done");
        Assert.Equal("1", fetched["rev"]);
        Assert.Equal(KeysOf(Story), KeysOf(fetched.Team));
        Assert.Equal(1, relay.StoryWrites);
    }

    /// <summary>
    /// Asserts that the headers alone leave the story's text out.
    /// </summary>
    [Fact]
    public void Describe_WithoutText_TellsTheHeadersAlone()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);

        Assert.True(story.Post(IdOf(code), 0, "p=5;r1141=0;r1142=0;r1143=0", Story));
        Await(story, "post", "accepted");
        var headers = Message.Decode(story.Describe(withText: false));

        Assert.Equal(("accepted", "1", "5", string.Empty), (headers["post"], headers["rev"], headers["p"], headers.Team));
    }

    /// <summary>
    /// Asserts that a story which does not open with the world's token is kept without its text, so
    /// the game still learns its revision.
    /// </summary>
    [Fact]
    public void Fetch_StoryThatDoesNotOpen_IsKeptWithoutItsText()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);
        new DirectoryClient(relay.Address).PostStory(IdOf(code), CreatorKey, WorldKeys.AuthKeyOf(code.Token), 0, StoryCounters.Parse("p=5;r1141=0;r1142=0;r1143=0")!, "QUJD");

        Assert.True(story.Fetch(IdOf(code)));
        var fetched = Await(story, "fetch", "done");

        Assert.Equal(("1", "5", string.Empty), (fetched["wrev"], fetched["p"], fetched.Team));
    }

    /// <summary>
    /// Asserts that a write on an older revision is refused and hands over the world's story instead.
    /// </summary>
    [Fact]
    public void Post_OnAnOlderRevision_TakesTheWorldsStory()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var creator = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);

        Assert.True(creator.Post(IdOf(code), 0, "p=5;r1141=0;r1142=0;r1143=0", Story));
        Await(creator, "post", "accepted");

        Assert.True(other.Post(IdOf(code), 0, "p=6;r1141=0;r1142=0;r1143=0", Packed("v=1001:n6")));
        var refused = Await(other, "post", "conflict");
        Assert.Equal(("rev", "1", "5"), (refused["post_code"], refused["rev"], refused["p"]));
        Assert.Equal(KeysOf(Story), KeysOf(refused.Team));
    }

    /// <summary>
    /// Asserts that a write sent again after a route lock moved the story on is found already
    /// accepted with the revision of the write itself, not the revision of the lock.
    /// </summary>
    [Fact]
    public void Post_SentAgainAfterALock_IsFoundWithItsOwnRevision()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var creator = NewStory(relay, CreatorKey, code);
        var id = IdOf(code);

        Assert.True(creator.Post(id, 0, "p=39;r1141=0;r1142=0;r1143=0", Story));
        Assert.Equal("1", Await(creator, "post", "accepted")["post_rev"]);
        Assert.True(creator.LockRoute(id, "ad"));
        Assert.Equal("2", Await(creator, "lock", "locked")["rev"]);

        Assert.True(creator.Post(id, 0, "p=39;r1141=0;r1142=0;r1143=0", Story));
        var found = Await(creator, "post", "accepted");
        Assert.Equal(("1", "2", "1"), (found["post_rev"], found["rev"], found["wrev"]));
    }

    /// <summary>
    /// Asserts that a write moving the world into a later part leaves the story before it as that
    /// part's checkpoint, and that a part without one says so.
    /// </summary>
    [Fact]
    public void FetchCheckpoint_AfterAPartEnded_GivesTheStoryBeforeIt()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);
        var id = IdOf(code);

        Assert.Equal(string.Empty, story.DescribeCheckpoint());
        var before = Packed("v=1001:n18,30:n1");
        Assert.True(story.Post(id, 0, "p=18;r1141=0;r1142=0;r1143=0", before));
        Await(story, "post", "accepted");
        Assert.True(story.Post(id, 1, "p=19;r1141=0;r1142=0;r1143=0", Story));
        Assert.Equal(("2", "1"), (Await(story, "post", "accepted")["part"], Await(story, "post", "accepted")["checkpoints"]));

        Assert.True(story.FetchCheckpoint(id, "1"));
        var checkpoint = AwaitCheckpoint(story, "done");
        Assert.Equal(("1", "18"), (checkpoint["part"], checkpoint["p"]));
        Assert.Equal(KeysOf(before), KeysOf(checkpoint.Team));

        Assert.True(story.FetchCheckpoint(id, "2"));
        Assert.Equal("2", AwaitCheckpoint(story, "none")["part"]);
        Assert.False(story.FetchCheckpoint(id, "4"));
    }

    /// <summary>
    /// Asserts that the first route locked wins, and a write on the story from before the lock is still taken.
    /// </summary>
    [Fact]
    public void LockRoute_FirstWins_AndAWriteFromBeforeIsTaken()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var creator = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);
        var id = IdOf(code);

        Assert.True(creator.Post(id, 0, "p=39;r1141=0;r1142=0;r1143=0", Story));
        Await(creator, "post", "accepted");

        Assert.True(creator.LockRoute(id, "ad"));
        Assert.Equal(("ad", "2"), (Await(creator, "lock", "locked")["route"], Await(creator, "lock", "locked")["rev"]));
        Assert.True(other.LockRoute(id, "mr"));
        Assert.Equal(("route", "ad"), (Await(other, "lock", "taken")["lock_code"], Await(other, "lock", "taken")["route"]));
        Assert.False(other.LockRoute(id, "none"));

        Assert.True(creator.Post(id, 1, "p=40;r1141=1;r1142=0;r1143=0", Story));
        var started = Await(creator, "post", "accepted");
        Assert.Equal(("3", "ad", "3"), (started["rev"], started["part"], started["checkpoints"]));
    }

    /// <summary>
    /// Asserts that a request in another world forgets the story of the world before, so the game
    /// script never reads it as the new world's.
    /// </summary>
    [Fact]
    public void Fetch_InAnotherWorld_ForgetsTheStoryOfTheWorldBefore()
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

        Assert.True(story.Post(IdOf(first), 0, "p=20;r1141=0;r1142=0;r1143=0", Story));
        Assert.Equal(IdOf(first), Await(story, "post", "accepted")["world"]);

        Assert.True(story.Fetch(IdOf(second)));
        Assert.NotEqual(IdOf(first), Message.Decode(story.Describe())["world"]);
        var fetched = Await(story, "fetch", "done");
        Assert.Equal((IdOf(second), "0", "0", string.Empty), (fetched["world"], fetched["rev"], fetched["p"], fetched.Team));
    }

    /// <summary>
    /// Asserts that a write sends only the keys it changed, and that of two writes on the same
    /// revision the first keeps the key both changed, which the second hears of as a conflict that
    /// hands it the world's story with its own other key in it.
    /// </summary>
    [Fact]
    public void Post_SameKeyAsAnother_TheFirstKeepsIt()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var creator = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);
        var id = IdOf(code);
        const string Counters = "p=18;r1141=0;r1142=0;r1143=0";

        Assert.True(creator.Post(id, 0, Counters, Packed("v=1001:n18,50:n1,60:n1")));
        Await(creator, "post", "accepted");
        Assert.True(other.Fetch(id));
        Await(other, "fetch", "done");

        Assert.True(creator.Post(id, 1, Counters, Packed("v=1001:n18,50:n2,60:n1")));
        Assert.Equal("2", Await(creator, "post", "accepted")["post_rev"]);
        Assert.True(other.Post(id, 1, Counters, Packed("v=1001:n18,50:n3,60:n4")));
        var merged = Await(other, "post", "conflict");

        Assert.Equal(("rev", "3"), (merged["post_code"], merged["rev"]));
        Assert.Equal(new Dictionary<string, string> { ["v1001"] = "n18", ["v50"] = "n2", ["v60"] = "n4" }, KeysOf(merged.Team));
    }

    /// <summary>
    /// Asserts that the relay's push of what a write changed lays the change over the story another
    /// game holds, whose next fetch then answers at once.
    /// </summary>
    [Fact]
    public void TakePush_ChangeOfTheStoryHeld_IsLaidOverIt()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var other = NewStory(relay, OtherKey, code);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other"), Story = other };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var creator = NewStory(relay, CreatorKey, code);
        var id = IdOf(code);

        Assert.True(creator.Post(id, 0, "p=18;r1141=0;r1142=0;r1143=0", Packed("v=1001:n18,50:n1")));
        Await(creator, "post", "accepted");
        Assert.True(other.Fetch(id));
        Await(other, "fetch", "done");
        AwaitEntry(session, "story");

        Assert.True(creator.Post(id, 1, "p=19;r1141=0;r1142=0;r1143=0", Packed("s=7", "v=1001:n19,50:n1")));
        Await(creator, "post", "accepted");
        Assert.Equal("2", AwaitEntry(session, "story")["rev"]);
        var pushed = Message.Decode(other.Describe());
        session.Close();

        Assert.Equal(("2", "19", "2"), (pushed["rev"], pushed["p"], pushed["part"]));
        Assert.Equal(new Dictionary<string, string> { ["s7"] = "1", ["v1001"] = "n19", ["v50"] = "n1" }, KeysOf(pushed.Team));
        Assert.True(other.Fetch(id));
        Assert.Equal("2", Await(other, "fetch", "done")["rev"]);
        Assert.False(other.TakePush(id, "{\"rev\": 9}"));
        Assert.False(other.TakePush(id, "not json"));
    }

    /// <summary>
    /// Asserts that a sealed story this game opens moves to keys, which the relay keeps from then on,
    /// turning away a sealed write.
    /// </summary>
    [Fact]
    public void Fetch_SealedStory_MovesItToKeys()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);
        var other = NewStory(relay, OtherKey, code);
        var id = IdOf(code);
        var client = new DirectoryClient(relay.Address);
        var counters = StoryCounters.Parse("p=18;r1141=0;r1142=0;r1143=0")!;
        Assert.True(client.PostStory(id, CreatorKey, WorldKeys.AuthKeyOf(code.Token), 0, counters, StorySeal.Seal(code.Token, Story)).Taken);

        Assert.True(story.Fetch(id));
        var fetched = Await(story, "fetch", "done");
        Assert.Equal(KeysOf(Story), KeysOf(fetched.Team));
        WaitUntil(() => Message.Decode(story.Describe(withText: false))["rev"] == "2", "the story moved to keys");

        Assert.True(other.Fetch(id));
        Assert.Equal(KeysOf(Story), KeysOf(Await(other, "fetch", "done").Team));
        var sealedWrite = client.PostStory(id, CreatorKey, WorldKeys.AuthKeyOf(code.Token), 2, counters, StorySeal.Seal(code.Token, Story));
        Assert.Equal((false, "update"), (sealedWrite.Taken, sealedWrite.State.Code));
    }

    /// <summary>
    /// Asserts that a story's lists round-trip through the game script's packed text and the
    /// relay's lists, and that a change lists only what differs.
    /// </summary>
    [Fact]
    public void StoryLists_PackedAndChanged()
    {
        var story = StoryLists.FromPacked(Story);
        Assert.Equal(KeysOf(Story), KeysOf(story.ToPacked()));
        Assert.Equal(7, story.Count);

        var changed = story.ChangesIn(StoryLists.FromPacked(Packed("s=5,8", "v=1001:n19")));
        Assert.Equal(new Dictionary<string, string> { ["s8"] = "1", ["v1001"] = "n19" }, changed.Keys.ToDictionary(pair => pair.Key, pair => pair.Value));
        Assert.Equal("n19", story.With(changed).Keys["v1001"]);
        Assert.False(story.With(changed).Without(["s8"]).Keys.ContainsKey("s8"));
        Assert.True(story.SameAs(StoryLists.FromPacked(story.ToPacked())));
        Assert.Throws<InvalidDataException>(() => StoryLists.FromPacked("not base64!"));
    }

    /// <summary>
    /// Asserts that shared companions are added and told with the story.
    /// </summary>
    [Fact]
    public void AddCompanions_GrowsTheSharedList()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);

        Assert.True(story.AddCompanions(IdOf(code), "382, 5,382"));
        Assert.Equal("5,382", Await(story, "companions", "done")["comps"]);
        Assert.False(story.AddCompanions(IdOf(code), "5,x"));
        Assert.False(story.AddCompanions(IdOf(code), string.Empty));
    }

    /// <summary>
    /// Asserts that the level caps a write names reach the relay and come back with the story, never lost by a later write without them.
    /// </summary>
    [Fact]
    public void Post_TellsTheLevelCaps()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Raid);
        var story = NewStory(relay, CreatorKey, code);

        Assert.True(story.Post(IdOf(code), 0, "p=7;r1141=0;r1142=0;r1143=0;caps=15,10", Story));
        Assert.Equal("10,15", Await(story, "post", "accepted")["caps"]);

        Assert.True(story.Post(IdOf(code), 1, "p=8;r1141=0;r1142=0;r1143=0", Story));
        Await(story, "post", "accepted");
        Assert.True(story.Fetch(IdOf(code)));
        Assert.Equal("10,15", Await(story, "fetch", "done")["caps"]);
    }

    /// <summary>
    /// Asserts that a Classic world keeps no story, which the fetch fails with.
    /// </summary>
    [Fact]
    public void Fetch_ClassicWorld_Fails()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, WorldType.Classic);
        var story = NewStory(relay, CreatorKey, code);

        Assert.True(story.Fetch(IdOf(code)));
        Assert.Equal("The relay keeps no story of this world.", Await(story, "fetch", "failed")["fetch_error"]);
    }

    /// <summary>
    /// Asserts that nothing starts outside the world, nor a write with counters or a story that are not as they should be.
    /// </summary>
    [Fact]
    public void Post_OutsideTheWorldOrBadInput_DoesNotStart()
    {
        using var relay = new TestRelay();
        var code = new WorldCode("abcdefghjkmnpqrs", Relays.Current, 4);
        var story = NewStory(relay, CreatorKey, code);
        var id = IdOf(code);
        const string Counters = "p=1;r1141=0;r1142=0;r1143=0";

        Assert.False(story.Fetch("0".PadLeft(32, '0')));
        Assert.False(story.Post("0".PadLeft(32, '0'), 0, Counters, Story));
        Assert.False(story.Post(id, 0, "p=1", Story));
        Assert.False(story.Post(id, -1, Counters, Story));
        Assert.False(story.Post(id, 0, Counters, string.Empty));
        Assert.False(story.Post(id, 0, Counters, new string('a', StorySeal.MaxStoryBytes + 1)));
        Assert.Equal(string.Empty, story.Describe());
    }

    /// <summary>
    /// Asserts that the counters are read with every key the relay takes, and refused when not as they should be.
    /// </summary>
    [Fact]
    public void StoryCounters_Parse_ReadsAndRefuses()
    {
        var counters = StoryCounters.Parse(" p=40; r1141=0;r1142=3;r1143=0;clear=mr,ad;end=544,12,30 ")!;
        Assert.Equal((40, 3, new StoryEnd(544, 12, 30), false), (counters.P, counters.R1142, counters.End, counters.KeepEnd));
        Assert.Equal(["ad", "mr"], counters.Clear);
        Assert.True(StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0")!.KeepEnd);
        Assert.Equal((null, false), (StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;end=")!.End, StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;end=")!.KeepEnd));

        Assert.Null(StoryCounters.Parse("p=1;r1141=0;r1142=0"));
        Assert.Null(StoryCounters.Parse("p=-1;r1141=0;r1142=0;r1143=0"));
        Assert.Null(StoryCounters.Parse("p=1;r1141=2;r1142=3;r1143=0"));
        Assert.Null(StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;clear=xy"));
        Assert.Null(StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;clear=ad,ad"));
        Assert.Null(StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;end=0,1,2"));
        Assert.Null(StoryCounters.Parse("p=1;r1141=0;r1142=0;r1143=0;mood=1"));
        Assert.Null(StoryCounters.Parse("p=1;p=2;r1141=0;r1142=0;r1143=0"));
    }

    /// <summary>
    /// Asserts that the level caps are read each once and lowest first, written only when there are any, and refused when not as they should be.
    /// </summary>
    [Fact]
    public void StoryCounters_Caps_ReadsWritesAndRefuses()
    {
        Assert.Equal([10, 15, 18], StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=18,10,15,10")!.Caps);
        Assert.Empty(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=")!.Caps);
        Assert.Contains("\"caps\":[10,15]", JsonOf(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=15,10")!), StringComparison.Ordinal);
        Assert.DoesNotContain("caps", JsonOf(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0")!), StringComparison.Ordinal);

        Assert.Null(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=0"));
        Assert.Null(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=10000"));
        Assert.Null(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=-5"));
        Assert.Null(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=ten"));
        Assert.Null(StoryCounters.Parse("p=7;r1141=0;r1142=0;r1143=0;caps=" + string.Join(',', Enumerable.Range(1, StoryCounters.MaxCaps + 1))));
    }

    /// <summary>
    /// Writes counters as the JSON object the relay reads.
    /// </summary>
    /// <param name="counters">The counters.</param>
    /// <returns>The JSON.</returns>
    private static string JsonOf(StoryCounters counters)
    {
        using var stream = new MemoryStream();

        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            counters.Write(writer);
            writer.WriteEndObject();
        }

        return Encoding.UTF8.GetString(stream.ToArray());
    }

    /// <summary>
    /// Asserts that a sealed story opens again with the same token only.
    /// </summary>
    [Fact]
    public void StorySeal_OpensWithTheSameTokenOnly()
    {
        var sealedStory = StorySeal.Seal("abcdefghjkmnpqrs", Story);

        Assert.Equal(Story, StorySeal.Open("abcdefghjkmnpqrs", sealedStory));
        Assert.Throws<InvalidDataException>(() => StorySeal.Open("abcdefghjkmnpqrt", sealedStory));
        Assert.Throws<InvalidDataException>(() => StorySeal.Open("abcdefghjkmnpqrs", "not base64!"));
        Assert.Throws<InvalidDataException>(() => StorySeal.Open("abcdefghjkmnpqrs", "QUJD"));
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
    /// Packs lists as the game script does: each on a line of its own, deflated, in base64.
    /// </summary>
    /// <param name="lines">The lists, each "name=entries".</param>
    /// <returns>The packed story.</returns>
    private static string Packed(params string[] lines)
    {
        using var output = new MemoryStream();

        using (var deflater = new ZLibStream(output, CompressionLevel.Optimal, leaveOpen: true))
        {
            var bytes = Encoding.UTF8.GetBytes(string.Join('\n', lines));
            deflater.Write(bytes, 0, bytes.Length);
        }

        return Convert.ToBase64String(output.ToArray());
    }

    /// <summary>
    /// Reads the keys of a packed story.
    /// </summary>
    /// <param name="packed">The story.</param>
    /// <returns>Its keys and their values.</returns>
    private static Dictionary<string, string> KeysOf(string packed) =>
        StoryLists.FromPacked(packed).Keys.ToDictionary(pair => pair.Key, pair => pair.Value);

    /// <summary>
    /// Tells a world's id.
    /// </summary>
    /// <param name="code">The world's code.</param>
    /// <returns>The id.</returns>
    private static string IdOf(WorldCode code) => Relays.WorldRoomOf(code.Token);

    /// <summary>
    /// Makes one player's Raid World story, reaching only the test relay and in the given world.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="code">The world the player is in.</param>
    /// <returns>The story.</returns>
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
    /// <param name="story">The player's story.</param>
    /// <param name="kind">The kind: fetch, post, lock or companions.</param>
    /// <param name="state">The state.</param>
    /// <returns>The story as the game script reads it.</returns>
    private static Message Await(RaidStory story, string kind, string state)
    {
        Message? described = null;
        WaitUntil(() => (described = Message.Decode(story.Describe()))[kind] is { Length: > 0 } now && now != "busy", $"the {kind}");
        Assert.True(described![kind] == state, $"{kind} is {described[kind]}: {story.Describe()}");
        return described;
    }

    /// <summary>
    /// Waits until the checkpoint fetch reaches a state.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="state">The state.</param>
    /// <returns>The checkpoint as the game script reads it.</returns>
    private static Message AwaitCheckpoint(RaidStory story, string state)
    {
        Message? described = null;
        WaitUntil(() => (described = Message.Decode(story.DescribeCheckpoint()))["state"] is { Length: > 0 } now && now != "busy", "the checkpoint");
        Assert.Equal(state, described!["state"]);
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
