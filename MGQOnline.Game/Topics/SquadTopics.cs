//----------------------------------------------------------------
//  SquadTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Shared writing squad settings with the local worlds
//                            - Answered the squad math and the team fit
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Squads;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a Raid World's squad settings, see <see cref="RaidSquad"/>, which both
/// hosts answer through <see cref="SharedTopics"/>.
/// </summary>
public static class SquadTopics
{
    /// <summary>
    /// Reads squad settings from their text: the text in; <c>luka</c>, <c>formation</c>,
    /// <c>front</c> and <c>raid_front</c> out, nil for a text of no valid settings.
    /// </summary>
    public const string Read = "squad.read";

    /// <summary>
    /// Writes squad settings as their text: the settings as <see cref="Read"/> answers them in; the
    /// text out, nil for settings out of range.
    /// </summary>
    public const string Write = "squad.write";

    /// <summary>
    /// Hands out the settings of a Raid World that names none: nothing in, the settings as
    /// <see cref="Read"/> answers them out.
    /// </summary>
    public const string Default = "squad.default";

    /// <summary>
    /// Reads the settings a battle the battle server hosts was handed: the setup's [name, value]
    /// pairs in, by the names <see cref="Read"/> answers; the settings with the defaults for the
    /// names the pairs lack out, nil when no pair names a setting or the settings are out of range.
    /// </summary>
    /// <remarks>
    /// A pair of another name, or whose value is of the wrong kind, is left out.
    /// </remarks>
    public const string Served = "squad.served";

    /// <summary>
    /// Splits a party's places between its players, see <see cref="SquadMath.Shares"/>:
    /// <c>count</c> and <c>max</c> in; each player's [front, bench] out, the leader first.
    /// </summary>
    public const string Shares = "squad.shares";

    /// <summary>
    /// Orders players, see <see cref="SquadMath.Ranked"/>: [id, first] pairs in, the ids in order out.
    /// </summary>
    public const string Rank = "squad.rank";

    /// <summary>
    /// Tells a player's squad in a Raid World, see <see cref="SquadMath.RaidShare"/>: <c>rules</c>
    /// (as <see cref="Read"/> answers them, nil for the defaults) and <c>max</c> in; <c>regular</c>
    /// and <c>raid</c> ([front, bench] each) and <c>largest</c> (<see cref="SquadMath.LargestSquad"/>) out.
    /// </summary>
    public const string Raid = "squad.raid";

    /// <summary>
    /// Arranges a battle's players, see <see cref="SquadMath.Arrange"/>: <c>rules</c> (nil outside a
    /// Raid World), <c>raid</c>, <c>backline</c> and <c>players</c> ([id, first, max, count] each) in;
    /// [index, front, bench] per player out, in order.
    /// </summary>
    public const string Arrange = "squad.arrange";

    /// <summary>
    /// Picks the companions a team leaves out, see <see cref="SquadMath.PastCap"/>: <c>team</c> (its
    /// ids in order), <c>luka</c> (the ids that are Luka), <c>cap</c> and <c>keep_luka</c> in; the ids
    /// left out out.
    /// </summary>
    public const string PastCap = "squad.past_cap";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Read, (_, request) => ValueOf(request.AsText()));
        context.Register(Write, (_, request) => TextOf(request.AsHash()));
        context.Register(Default, (_, _) => ValueOf(RaidSquad.Default));
        context.Register(Served, (_, request) => ServedOf(request.AsArray()));
        context.Register(Shares, (_, request) => SharesOf(request.AsHash()));
        context.Register(Rank, (_, request) => RankOf(request.AsArray()));
        context.Register(Raid, (_, request) => RaidOf(request.AsHash()));
        context.Register(Arrange, (_, request) => ArrangeOf(request.AsHash()));
        context.Register(PastCap, (_, request) => PastCapOf(request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Shares"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>Each player's [front, bench].</returns>
    private static RubyArray SharesOf(RubyHash request) =>
        new(SquadMath.Shares(request["count"].AsInt(), request["max"].AsInt()).Select(share => (RubyValue)PairOf(share)));

    /// <summary>
    /// Answers <see cref="Rank"/>.
    /// </summary>
    /// <param name="request">The [id, first] pairs.</param>
    /// <returns>The ids in order.</returns>
    private static RubyArray RankOf(RubyArray request)
    {
        (string Id, bool First)[] players = request.Select(pair => (pair.AsArray()[0].AsText(), pair.AsArray()[1].AsBool())).ToArray();
        return new RubyArray(SquadMath.Ranked(players).Select(index => (RubyValue)players[index].Id));
    }

    /// <summary>
    /// Answers <see cref="Raid"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The squads of both fights and the larger one's size.</returns>
    private static RubyHash RaidOf(RubyHash request)
    {
        SquadRules rules = RulesOf(request["rules"]) ?? SquadRules.Default;
        int max = request["max"].AsInt();
        return new RubyHash
        {
            { "regular", PairOf(SquadMath.RaidShare(rules, max, false)) },
            { "raid", PairOf(SquadMath.RaidShare(rules, max, true)) },
            { "largest", SquadMath.LargestSquad(rules, max) },
        };
    }

    /// <summary>
    /// Answers <see cref="Arrange"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>[index, front, bench] per player, in order.</returns>
    private static RubyArray ArrangeOf(RubyHash request)
    {
        SquadPlayer[] players = request["players"].AsArray().Select(player =>
        {
            RubyArray fields = player.AsArray();
            return new SquadPlayer(fields[0].AsText(), fields[1].AsBool(), fields[2].AsInt(), fields[3].AsInt());
        }).ToArray();
        ArrangedPlayer[] arranged = SquadMath.Arrange(RulesOf(request["rules"]), request["raid"].AsBool(), request["backline"].AsBool(), players);
        return new RubyArray(arranged.Select(player => (RubyValue)new RubyArray { player.Index, player.Share.Front, player.Share.Bench }));
    }

    /// <summary>
    /// Answers <see cref="PastCap"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The ids left out.</returns>
    private static RubyArray PastCapOf(RubyHash request)
    {
        int[] team = request["team"].AsArray().Select(id => id.AsInt()).ToArray();
        HashSet<int> luka = request["luka"].AsArray().Select(id => id.AsInt()).ToHashSet();
        return new RubyArray(SquadMath.PastCap(team, luka, request["cap"].AsInt(), request["keep_luka"].AsBool()).Select(id => (RubyValue)id));
    }

    /// <summary>
    /// Reads squad rules as <see cref="Read"/> answers them.
    /// </summary>
    /// <param name="value">The rules, or nil.</param>
    /// <returns>The rules, <see langword="null"/> for nil.</returns>
    private static SquadRules? RulesOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        RubyHash rules = value.AsHash();
        return new SquadRules(rules["luka"].AsBool(), rules["formation"].AsInt(), rules["front"].AsInt(), rules["raid_front"].AsInt());
    }

    /// <summary>
    /// Writes a squad as the scripts read it.
    /// </summary>
    /// <param name="share">The squad.</param>
    /// <returns>[front, bench].</returns>
    private static RubyArray PairOf(SquadShare share) => new() { share.Front, share.Bench };

    /// <summary>
    /// Writes squad settings as the bridge hands them to the scripts.
    /// </summary>
    /// <param name="text">The settings' text.</param>
    /// <returns><c>luka</c>, <c>formation</c>, <c>front</c> and <c>raid_front</c>; <see langword="null"/> for a text of no valid settings.</returns>
    public static RubyHash? ValueOf(string text) =>
        RaidSquad.TryParse(text, out bool luka, out int formation, out int front, out int raidFront)
            ? new RubyHash { { "luka", luka }, { "formation", formation }, { "front", front }, { "raid_front", raidFront } }
            : null;

    /// <summary>
    /// Answers <see cref="Write"/>.
    /// </summary>
    /// <param name="squad">The settings.</param>
    /// <returns>Their text, <see langword="null"/> for settings out of range.</returns>
    public static RubyValue? TextOf(RubyHash squad)
    {
        string text = RaidSquad.TextOf(squad["luka"].AsBool(), squad["formation"].AsInt(), squad["front"].AsInt(), squad["raid_front"].AsInt());
        return RaidSquad.IsValid(text) ? text : null;
    }

    /// <summary>
    /// Answers <see cref="Served"/>.
    /// </summary>
    /// <param name="pairs">The setup's pairs.</param>
    /// <returns>The settings, <see langword="null"/> when no pair names one or they are out of range.</returns>
    private static RubyHash? ServedOf(RubyArray pairs)
    {
        RaidSquad.TryParse(RaidSquad.Default, out bool luka, out int formation, out int front, out int raidFront);
        bool named = false;
        foreach (RubyValue pair in pairs)
        {
            if (pair is not RubyArray { Count: 2 } entry || entry[0] is not RubyString)
            {
                continue;
            }

            switch (entry[0].AsText(), entry[1])
            {
                case ("luka", RubyBool flag):
                    luka = flag.Flag;
                    break;
                case ("formation", RubyInteger number):
                    formation = Clamped(number);
                    break;
                case ("front", RubyInteger number):
                    front = Clamped(number);
                    break;
                case ("raid_front", RubyInteger number):
                    raidFront = Clamped(number);
                    break;
                default:
                    continue;
            }

            named = true;
        }

        return named ? ValueOf(RaidSquad.TextOf(luka, formation, front, raidFront)) : null;
    }

    /// <summary>
    /// Reads a number of a setup, one beyond 32 bits as one out of every range.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The number, or -1 when it does not fit.</returns>
    private static int Clamped(RubyInteger number) => number.Value >= int.MinValue && number.Value <= int.MaxValue ? (int)number.Value : -1;
}
