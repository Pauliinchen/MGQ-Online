//----------------------------------------------------------------
//  BuildTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Dropped the hero of a replaced Luka
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Actors;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Actors;

/// <summary>
/// Walks characters' builds from the scripts of one game to the scripts of another: the facts one
/// game's scripts hand over, written by C# into a co-op battle's join or a duel's team and carried
/// in a battle message, reach the other game's scripts as the same facts, and another game's text
/// reads only within the rules.
/// </summary>
public sealed class BuildTopicsTests
{
    /// <summary>
    /// Asserts that a player's builds, with every kind of equipment among them,
    /// written into the join a guest sends the host, reach the host's scripts as the same facts.
    /// </summary>
    [Fact]
    public void CoopJoin_ReachesTheHostAsTheSameFacts()
    {
        TopicContext guest = Game();
        TopicContext host = Game();
        var actors = new RubyArray { Actor(1), Actor(2) };

        RubyValue builds = guest.Value(BuildTopics.Write, new RubyHash { { "actors", actors } });
        RubyValue body = guest.Value(WireTopics.Write, new RubyArray { builds, new RubyArray { new RubyArray { 300, 40 } }, 8 });
        RubyValue message = guest.Value(MessageTopics.Write, new RubyHash { { "fields", new RubyHash { { "battle", "join" }, { "bid", "b1" } } }, { "body", body } });
        RubyValue taken = host.Value(WireTopics.Read, host.Value(MessageTopics.Read, message).AsHash()["body"]).AsArray()[0];

        Assert.Equal(actors, host.Value(BuildTopics.Read, new RubyHash { { "text", taken }, { "limit", 14 } }));
    }

    /// <summary>
    /// Asserts that a player's PvP team, written with their rule of the Backline into the body of a
    /// duel's message, tells the other game's handshake the rule and reaches its scripts as the
    /// same facts.
    /// </summary>
    [Fact]
    public void DuelTeam_ReachesTheOtherGameWithItsRule()
    {
        TopicContext challenger = Game();
        TopicContext other = Game();
        var actors = new RubyArray { Actor(3) };
        RubyValue fingerprint = challenger.Value(BuildTopics.Game, new RubyArray { 3, 201, 101 });

        RubyValue team = challenger.Value(BuildTopics.Write, new RubyHash { { "actors", actors }, { "backline", true } });
        RubyValue body = challenger.Value(WireTopics.Write, new RubyArray { fingerprint, team });
        RubyValue message = challenger.Value(MessageTopics.Write, new RubyHash { { "fields", new RubyHash { { "duel", "accept" } } }, { "body", body } });
        RubyArray taken = other.Value(WireTopics.Read, other.Value(MessageTopics.Read, message).AsHash()["body"]).AsArray();

        Assert.Equal("3:3,201,101", taken[0].AsText());
        Assert.True(BuildText.HasBackline(taken[1].AsText()));
        Assert.Equal(actors, other.Value(BuildTopics.Read, new RubyHash { { "text", taken[1] }, { "limit", 20 } }));
    }

    /// <summary>
    /// Asserts that a text another game sent reads only within the rules: levels and counters held
    /// in range, slots and characters cut at their most, an item and a line that do not read left
    /// out and logged.
    /// </summary>
    [Fact]
    public void ForeignText_ReadsOnlyWithinTheRules()
    {
        TopicContext game = Game();
        string text = "backline=0\n"
            + "member=4;0;7;;7:5000,x:3;1;9,9,8;2:5.x;;w1,a2,ew3.bad,,,,,,w9,w9;100;950;-5,2;0,6\n"
            + "nobody\n"
            + "member=5;1" + new string(';', BuildText.FieldCount - 2) + "\n"
            + "member=6;1" + new string(';', BuildText.FieldCount - 2);

        RubyArray read = game.Value(BuildTopics.Read, new RubyHash { { "text", text }, { "limit", 2 } }).AsArray();

        RubyHash first = read[0].AsHash();
        Assert.Equal(
            new RubyValue[] { 4, 1, 7, RubyNil.Value, new RubyArray { new RubyArray { 7, 999 } }, new RubyArray { 9, 8 }, new RubyArray { new RubyArray { 2, new RubyArray { 5 } } } },
            new[] { first["actor"], first["level"], first["class"], first["tribe"], first["levels"], first["skills"], first["abilities"] });
        Assert.Equal(8, first["equips"].AsArray().Count);
        Assert.True(first["equips"].AsArray()[2].IsNil);
        Assert.Equal(new RubyArray { 0, 2, 0, 0, 0, 0, 0 }, first["counters"]);
        Assert.Equal(new RubyArray { 6 }, first["switches"]);
        Assert.Equal(new[] { 4, 5 }, read.Select(member => member.AsHash()["actor"].AsInt()));
        Assert.Contains(game.Log.Lines, line => line.Contains("left out equipment ew3.bad: unreadable", System.StringComparison.Ordinal));
        Assert.Contains(game.Log.Lines, line => line.Contains("left out an unreadable member: nobody", System.StringComparison.Ordinal));
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
    /// Writes a character's facts as the scripts hand them over and as they get them back: a
    /// weapon of the database, a socket armor and an enchanted weapon equipped, its rates as Floats.
    /// </summary>
    /// <param name="actorId">The actor's id.</param>
    /// <returns>The facts.</returns>
    private static RubyHash Actor(int actorId) => new()
    {
        { "actor", actorId },
        { "level", 30 },
        { "class", 92 },
        { "tribe", 151 },
        { "levels", new RubyArray { new RubyArray { 92, 5 }, new RubyArray { 151, 3 } } },
        { "param_plus", new RubyArray { 1, 0, 0, 2, 0, 0, 0, 0 } },
        { "skills", new RubyArray { 10, 11 } },
        { "abilities", new RubyArray { new RubyArray { 1, new RubyArray { 12, 13 } } } },
        { "equip_abilities", new RubyArray() },
        {
            "equips", new RubyArray
            {
                new RubyHash { { "base", Kind("weapon", 4) } },
                new RubyHash { { "base", Kind("armor", 7) }, { "gems", new RubyArray { 3, 0 } } },
                new RubyHash
                {
                    { "base", Kind("weapon", 9) },
                    { "gems", new RubyArray { 0 } },
                    {
                        "enchant", new RubyHash
                        {
                            { "rarity", 2 }, { "plus", 1 }, { "sockets", 1 }, { "variance", 40 }, { "enchants", new RubyArray { 3, 5 } },
                            { "stats", new RubyArray(Enumerable.Repeat<RubyValue>(Kind("float", "1.05"), ItemText.StatRollCount)) },
                            { "traits", new RubyArray { new RubyArray { 3, 1, 2, Kind("float", "0.5") } } },
                        }
                    },
                },
                RubyNil.Value,
            }
        },
        { "params", new RubyArray { 300, 40, 20, 20, 20, 20, 20, 20 } },
        { "rates", new RubyArray { Kind("float", "0.95"), Kind("float", "0.05"), Kind("float", "0.04"), Kind("float", "0.0"), Kind("float", "0.125") } },
        { "counters", new RubyArray { 4, 0, 1, 0, 0, 0, 7 } },
        { "switches", new RubyArray { 31 } },
    };

    /// <summary>
    /// Writes a value of a kind as the scripts hand it over.
    /// </summary>
    /// <param name="kind">The kind, such as "float".</param>
    /// <param name="content">What it holds.</param>
    /// <returns>A Hash of one key.</returns>
    private static RubyHash Kind(string kind, RubyValue content) => new() { { kind, content } };
}
