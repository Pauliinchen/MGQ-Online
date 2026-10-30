//----------------------------------------------------------------
//  LiveTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers what the live battle's topics add to the classes they answer from: what the kinds of live
/// battle decide the same way, the plan's heirs and the check of other games' messages.
/// </summary>
public sealed class LiveTopicsTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the live battle's topics.
    /// </summary>
    public LiveTopicsTests()
    {
        LiveTopics.Register(_context);
    }

    /// <summary>
    /// Asserts that a team duel answers from its sides: who stands on the host's side, the players
    /// of both sides, who took over a leaver's characters and whether the other side is gone.
    /// </summary>
    [Fact]
    public void Mode_TeamDuel_AnswersFromItsSides()
    {
        Join("host", "pvp", true, [2, 5, 6]);
        Ask(LiveTopics.Team, new RubyHash { { "op", "prepare" }, { "own", Seats(0, 2) }, { "other", Seats(5, 6) }, { "same_side", true } });
        Ask(LiveTopics.Players, new RubyHash { { "op", "left" }, { "seat", 5 } });
        Ask(LiveTopics.Team, new RubyHash { { "op", "settle" }, { "host", 0 } });

        Assert.Equal((true, false), (Decided("same_side", "seat", 2).AsBool(), Decided("same_side", "seat", 5).AsBool()));
        Assert.Equal([0, 2, 5, 6], Decided("players").AsArray().Select(seat => seat.AsInt()));
        Assert.Equal(6, Decided("heir", "seat", 5).AsInt());
        Assert.False(Decided("gone", "host", 0).AsBool());
        Assert.Equal(["team_heirs"], Decided("kinds").AsArray().Select(kind => kind.AsText()));
    }

    /// <summary>
    /// Asserts that a duel answers nothing of sides, and names the Frontline's message only while
    /// it has the Backline.
    /// </summary>
    [Fact]
    public void Mode_Duel_NamesTheFrontlineWithTheBacklineAlone()
    {
        Join("host", "pvp", false, [2]);
        bool sameSide = Decided("same_side", "seat", 2).AsBool();
        int kinds = Decided("kinds").AsArray().Count;
        Ask(LiveTopics.Backline, new RubyHash { { "op", "begin" }, { "team", Seats(5, 6, 7) }, { "front", Seats(1, 2) } });

        Assert.Equal((false, 0), (sameSide, kinds));
        Assert.Equal(["pvp_front"], Decided("kinds").AsArray().Select(kind => kind.AsText()));
        Assert.Empty(Decided("players").AsArray());
    }

    /// <summary>
    /// <summary>
    /// Asserts that a co-op battle after a team duel gives nobody the characters of a player who
    /// left the duel.
    /// </summary>
    [Fact]
    public void Plan_CoopAfterTeamDuel_KeepsNoHeirs()
    {
        Join("host", "pvp", true, [2, 3]);
        Ask(LiveTopics.Team, new RubyHash { { "op", "prepare" }, { "own", Seats(2, 3) }, { "other", Seats(5) }, { "same_side", true } });
        Ask(LiveTopics.Players, new RubyHash { { "op", "left" }, { "seat", 3 } });
        Ask(LiveTopics.Team, new RubyHash { { "op", "settle" }, { "host", 0 } });
        Join("host", "coop", false, [2, 3]);

        RubyValue plan = Ask(LiveTopics.Plan, new RubyHash
        {
            { "body", "[\t[\t[\tsskill\ti7\ti1\t]\t]\t[\t[\tsskill\ti8\ti2\t]\t]\t]" },
            { "seat", 2 }, { "several", true }, { "owners", Seats(2, 3) }, { "skills", 200 }, { "items", 50 },
        });

        Assert.True(plan.AsHash()["places"].AsArray()[1].IsNil);
    }

    /// <summary>
    /// Asserts that a message of the battle is taken with false, and one for another battle is left
    /// out even when its kind and battle id are no text.
    /// </summary>
    [Fact]
    public void Admit_OtherBattle_LeavesOutWhatIsNoText()
    {
        Join("host", "coop", false, [2]);
        RubyValue taken = Ask(LiveTopics.Admit, new RubyHash { { "channel", false }, { "bid", "b1" }, { "kind", "commands" }, { "who", "Ann (seat 2)" } });
        RubyValue refused = Ask(LiveTopics.Admit, new RubyHash
        {
            { "channel", false }, { "bid", 7 }, { "kind", RubyString.Binary([0xff, 0x41]) }, { "who", RubyNil.Value },
        });

        Assert.False(taken.AsBool());
        Assert.Contains("it is for another battle", refused.AsArray()[1].AsText());
    }

    /// Joins a live battle.
    /// </summary>
    /// <param name="role">"host" or "guest".</param>
    /// <param name="kind">"coop" or "pvp".</param>
    /// <param name="team">Whether the duel is a team duel.</param>
    /// <param name="seats">The other games' seats.</param>
    private void Join(string role, string kind, bool team, int[] seats)
    {
        Ask(LiveTopics.Join, new RubyHash
        {
            { "role", role }, { "bid", "b1" }, { "seats", Seats(seats) }, { "player", "the party" }, { "kind", kind }, { "team", team }, { "served", false },
        });
        Ask(LiveTopics.Change, new RubyHash { { "op", "start" } });
    }

    /// <summary>
    /// Asks what the kinds of live battle decide the same way.
    /// </summary>
    /// <param name="op">What.</param>
    /// <param name="field">The field it needs, <see langword="null"/> for none.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The answer, nil for none.</returns>
    private RubyValue Decided(string op, string? field = null, int value = 0)
    {
        var request = new RubyHash { { "op", op } };
        if (field is not null)
        {
            request[field] = value;
        }

        return Ask(LiveTopics.Mode, request);
    }

    /// <summary>
    /// Asks a topic.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer, nil for none.</returns>
    private RubyValue Ask(string topic, RubyValue request) => _context.Ask(topic, request) ?? RubyNil.Value;

    /// <summary>
    /// Writes seats as the scripts hand them over.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>The list.</returns>
    private static RubyArray Seats(params int[] seats) => new(seats.Select(seat => (RubyValue)seat));

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
