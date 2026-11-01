//----------------------------------------------------------------
//  HudTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Asked for the arrows without the strip at the top and the player's sprite
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of the map's and the battle's display over a room nobody else is in: a tier's
/// bar on the map with its numbers and share written, no arrow without players, and no topic left
/// that lays out an arrow, which the Mod Framework's markers do.
/// </summary>
public sealed class HudTopicsTests
{
    /// <summary>
    /// The topics over a room of their own and empty raid pools.
    /// </summary>
    private readonly TopicCaller _caller = new(context =>
        HudTopics.Register(context, WorldRoomTopics.Register(context, new WorldSession(), _ => { }).Room, new PoolLedger(() => 0)));

    /// <summary>
    /// Asserts that a tier's bar on the map shows each enemy whole at its raid max HP, lettered.
    /// </summary>
    [Fact]
    public void MapBar_AnswersATiersBarWithItsNumbers()
    {
        RubyArray bar = _caller.Call(HudTopics.MapBarTopic, new RubyHash
        {
            { "title", "Archangel" },
            { "keys", RubyNil.Value },
            { "enemies", new RubyArray([new RubyArray(["Seraph", 40_000L]), new RubyArray(["Seraph", 40_000L])]) },
            { "factor", 50L },
            { "letters", RubyNil.Value },
        })!.AsArray();

        Assert.Equal("Archangel", bar[0].AsText());
        RubyArray first = bar[1].AsArray()[0].AsArray();
        Assert.Equal("Seraph A", first[0].AsText());
        Assert.Equal(2_000_000, first[2].AsLong());
        Assert.Equal("2,000,000 / 2,000,000", first[3].AsText());
        Assert.Equal("100.0%", first[4].AsText());
    }

    /// <summary>
    /// Asserts that no arrow points anywhere while nobody else is in the room.
    /// </summary>
    [Fact]
    public void Arrows_AnswersNoneWithoutPlayers()
    {
        RubyArray arrows = _caller.Call(HudTopics.ArrowsTopic, new RubyHash
        {
            { "reason", RubyNil.Value },
            { "screen", new RubyArray([640L, 480L]) },
            { "ghosts", new RubyHash() },
        })!.AsArray();

        Assert.Equal(0, arrows.Count);
    }

    /// <summary>
    /// Asserts that the arrows' pictures are no topic of the HUD's any more.
    /// </summary>
    [Fact]
    public void ArrowPicture_IsNoTopic()
    {
        Assert.Equal(BridgeEnvelope.UnknownTopic, _caller.Refusal("hud.arrow_picture", new RubyArray([0L, 40L])));
    }
}
