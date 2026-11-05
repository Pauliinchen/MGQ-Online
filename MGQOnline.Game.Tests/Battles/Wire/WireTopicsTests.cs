//----------------------------------------------------------------
//  WireTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Battles.Wire;

/// <summary>
/// Walks a live battle's lines from the scripts of one game to the scripts of another: the values
/// one game's scripts hand over, written into a battle message by C#, reach the other game's
/// scripts as the same values.
/// </summary>
public sealed class WireTopicsTests
{
    /// <summary>
    /// Asserts that a battle message whose body the sender's scripts handed over as values, every
    /// kind a line carries among them, reaches the receiver's scripts as those values.
    /// </summary>
    [Fact]
    public void BattleMessage_ReachesTheOtherGameAsTheSameValues()
    {
        TopicContext sender = Game();
        TopicContext receiver = Game();
        var values = new RubyArray
        {
            RubyNil.Value, true, 12, "tab\tand \\ and アリス",
            Kind("float", "0.25"), Kind("symbol", "hp_damage"), Kind("battler", "e1"), Kind("action", "count"),
            Kind("skill", 5), Kind("base_item", Kind("armor", 7)), Kind("color", new RubyArray { 255, 128, 0, 255 }),
            Kind("result", new RubyArray { new RubyArray { "hp_damage", 30 }, new RubyArray { "added_states", new RubyArray { Kind("state", 2) } } }),
            new RubyArray { new RubyArray { "skill", 5, 0 }, new RubyArray() },
        };

        RubyValue body = sender.Value(WireTopics.Write, values);
        RubyValue message = sender.Value(MessageTopics.Write, new RubyHash { { "fields", new RubyHash { { "battle", "commands" }, { "bid", "b1" } } }, { "body", body } });
        RubyValue taken = receiver.Value(MessageTopics.Read, message).AsHash()["body"];

        Assert.Equal(values, receiver.Value(WireTopics.Read, taken));
    }

    /// <summary>
    /// Asserts that what the host records of its battle, an event and a battler's values handed
    /// over as values, reaches the guest's playback as those values through the host's stream.
    /// </summary>
    [Fact]
    public void HostStream_ReachesTheGuestsPlaybackAsTheSameValues()
    {
        TopicContext host = Game();
        TopicContext guest = Game();
        var call = new RubyArray
        {
            "call", "log", "display_damage", 4711, Kind("battler", "a0"),
            new RubyArray { new RubyArray { Kind("battler", "e0"), Kind("result", new RubyArray { new RubyArray { "hp_damage", 30 }, new RubyArray { "critical", true } }) } },
            Kind("battler", "e0"), Kind("skill", 5),
        };
        var battlerValues = new RubyArray { 100, 10, 0, new RubyArray { 4 }, new RubyArray { 2 }, new RubyArray { 0, 0 }, 0 };

        host.Value(LiveTopics.Record, new RubyHash { { "op", "start" } });
        host.Value(LiveTopics.Record, new RubyHash { { "op", "values" }, { "battlers", new RubyArray { new RubyArray { 1, "a0", battlerValues } } }, { "full", true } });
        host.Value(LiveTopics.Record, new RubyHash { { "op", "event" }, { "values", call } });
        RubyValue send = host.Value(LiveTopics.Record, new RubyHash { { "op", "flush" } }).AsHash()["sends"].AsArray()[0];
        var lists = new RubyHash { { "log", new RubyArray() }, { "picture", new RubyArray() }, { "screen", new RubyArray() }, { "audio", new RubyArray() }, { "scene_calls", new RubyArray() }, { "log_calls", new RubyArray { "display_damage" } } };
        guest.Value(LiveTopics.GuestSetup, new RubyHash { { "names", RubyNil.Value }, { "own", new RubyArray { new RubyArray(), new RubyArray() } }, { "name_box", true }, { "lists", lists }, { "animations", 0 } });
        RubyHash taken = guest.Value(LiveTopics.TakeStream, new RubyHash { { "body", send }, { "seat", 2 } }).AsHash();

        var values = new RubyArray { "values", Kind("battler", "a0") };
        foreach (RubyValue value in battlerValues)
        {
            values.Add(value);
        }

        Assert.Equal(new RubyArray { values, call }, taken["lines"]);
    }

    /// <summary>
    /// Makes one game's topics.
    /// </summary>
    /// <returns>The game's context.</returns>
    private static TopicContext Game()
    {
        var game = new TopicContext();
        SharedTopics.Register(game.Context);
        return game;
    }

    /// <summary>
    /// Writes a value of a kind as the scripts hand it over.
    /// </summary>
    /// <param name="kind">The kind, such as "float".</param>
    /// <param name="content">What it holds.</param>
    /// <returns>A Hash of one key.</returns>
    private static RubyHash Kind(string kind, RubyValue content) => new() { { kind, content } };
}
