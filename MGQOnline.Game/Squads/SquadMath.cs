//----------------------------------------------------------------
//  SquadMath.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MGQOnline.Game.Squads;

/// <summary>
/// A Raid World's squad settings as numbers, see <see cref="RaidSquad"/>.
/// </summary>
/// <param name="Luka">Whether Luka may leave the team.</param>
/// <param name="Formation">The team's size, <see cref="RaidSquad.OriginalFormation"/> for the game's own.</param>
/// <param name="Front">The Frontline's places in regular fights.</param>
/// <param name="RaidFront">The Frontline's places in raids.</param>
public readonly record struct SquadRules(bool Luka, int Formation, int Front, int RaidFront)
{
    /// <summary>
    /// Gets the settings of a Raid World that names none.
    /// </summary>
    public static SquadRules Default
    {
        get
        {
            RaidSquad.TryParse(RaidSquad.Default, out bool luka, out int formation, out int front, out int raidFront);
            return new SquadRules(luka, formation, front, raidFront);
        }
    }
}

/// <summary>
/// A player's squad: their places of the Frontline and of the Backline.
/// </summary>
/// <param name="Front">The Frontline's places.</param>
/// <param name="Bench">The Backline's places.</param>
public readonly record struct SquadShare(int Front, int Bench)
{
    /// <summary>
    /// Gets the places together.
    /// </summary>
    public int Total => Front + Bench;
}

/// <summary>
/// A player of a co-op battle or team duel to arrange, see <see cref="SquadMath.Arrange"/>.
/// </summary>
/// <param name="Id">The player's id, which orders the players.</param>
/// <param name="First">Whether the player comes first: the party's leader, or the host of a Raid World's co-op battle.</param>
/// <param name="Max">The player's party_member_max.</param>
/// <param name="Count">How many characters the player brings.</param>
public readonly record struct SquadPlayer(string Id, bool First, int Max, int Count);

/// <summary>
/// A player as <see cref="SquadMath.Arrange"/> places them.
/// </summary>
/// <param name="Index">The player's place in the list arranged.</param>
/// <param name="Share">The player's places in the battle.</param>
public readonly record struct ArrangedPlayer(int Index, SquadShare Share);

/// <summary>
/// How the places of the Frontline and the Backline split between a party's players, and a Raid
/// World's squads by its rules: the math of coop_squad.rbx and of arrange in battles_coop.rbx,
/// which the player's game and the battle server both run.
/// </summary>
/// <remarks>
/// Every division sees values of 0 or more, so it floors as Ruby's does.
/// </remarks>
public static class SquadMath
{
    /// <summary>
    /// The places of the Frontline, the game's battle members.
    /// </summary>
    public const int Frontline = 4;

    /// <summary>
    /// Splits places between players, one more each for the first ones while some are left over.
    /// </summary>
    /// <param name="total">The places; fewer than none count as none.</param>
    /// <param name="count">The players.</param>
    /// <returns>Each player's places in the players' order, none for fewer than one player.</returns>
    public static int[] Split(int total, int count)
    {
        if (count < 1)
        {
            return [];
        }

        int places = Math.Max(total, 0);
        return Enumerable.Range(0, count).Select(position => (places / count) + (position < places % count ? 1 : 0)).ToArray();
    }

    /// <summary>
    /// Tells every player's squad in a party: their share of the Frontline and of the Backline.
    /// </summary>
    /// <param name="count">The players.</param>
    /// <param name="max">The party_member_max the places are split by, Frontline and Backline together.</param>
    /// <returns>Each player's share, the leader first.</returns>
    public static SquadShare[] Shares(int count, int max)
    {
        int[] fronts = Split(Frontline, count);
        int[] benches = Split(max - Frontline, count);
        return fronts.Select((front, position) => new SquadShare(front, benches[position])).ToArray();
    }

    /// <summary>
    /// Splits a team into its Frontline and its Backline: the Frontline as large as it may be, the
    /// Backline what is left but the last place, which is cut while a place is left over; with the
    /// game's own size nothing is cut.
    /// </summary>
    /// <param name="front">The Frontline's places the rules give.</param>
    /// <param name="size">The team's size.</param>
    /// <param name="original">Whether the team keeps the game's own size.</param>
    /// <returns>The Frontline's and the Backline's places.</returns>
    public static SquadShare Layout(int front, int size, bool original)
    {
        int fighting = Math.Max(Math.Min(front, size), 1);
        return new SquadShare(fighting, original ? size - fighting : Math.Max(size - fighting - 1, 0));
    }

    /// <summary>
    /// Tells a player's squad in a Raid World for a fight: the Frontline the rules give for it and
    /// the Backline the team leaves.
    /// </summary>
    /// <param name="rules">The world's squad rules.</param>
    /// <param name="max">The player's party_member_max.</param>
    /// <param name="raid">Whether the fight is a raid.</param>
    /// <returns>The squad.</returns>
    public static SquadShare RaidShare(SquadRules rules, int max, bool raid)
    {
        bool original = rules.Formation == RaidSquad.OriginalFormation;
        int size = original ? max : Math.Min(max, rules.Formation);
        return Layout(raid ? rules.RaidFront : rules.Front, size, original);
    }

    /// <summary>
    /// Tells how many characters a player's squad in a Raid World holds at most, in a regular fight
    /// or in a raid, either of which a co-op battle's host may hold.
    /// </summary>
    /// <param name="rules">The world's squad rules.</param>
    /// <param name="max">The player's party_member_max.</param>
    /// <returns>The characters.</returns>
    public static int LargestSquad(SquadRules rules, int max) => Math.Max(RaidShare(rules, max, false).Total, RaidShare(rules, max, true).Total);

    /// <summary>
    /// Tells a player's squad in a co-op battle: in a Raid World their squad for the fight, with as
    /// much of its Frontline as the battle's places split between the players leave them, but always
    /// their first character, and the rest of the squad on the Backline; else their share in the
    /// party.
    /// </summary>
    /// <param name="rules">The world's squad rules, <see langword="null"/> outside a Raid World.</param>
    /// <param name="position">The player's place among the players, the first first.</param>
    /// <param name="count">The players.</param>
    /// <param name="max">The player's party_member_max.</param>
    /// <param name="raid">Whether the fight is a raid.</param>
    /// <returns>The squad.</returns>
    public static SquadShare BattleShare(SquadRules? rules, int position, int count, int max, bool raid)
    {
        if (rules is not { } world)
        {
            return Shares(count, max)[position];
        }

        SquadShare squad = RaidShare(world, max, raid);
        int fighting = Math.Min(squad.Front, Math.Max(Split(Frontline, count)[position], 1));
        return new SquadShare(fighting, squad.Total - fighting);
    }

    /// <summary>
    /// Orders players as every member's game does: the first one first, then by their ids, compared
    /// byte by byte as Ruby compares texts.
    /// </summary>
    /// <param name="players">Each player's id and whether they come first.</param>
    /// <returns>The players' places in the list given, in order.</returns>
    public static int[] Ranked(IReadOnlyList<(string Id, bool First)> players)
    {
        ArgumentNullException.ThrowIfNull(players);
        byte[][] ids = players.Select(player => Encoding.UTF8.GetBytes(player.Id)).ToArray();
        return Enumerable.Range(0, players.Count)
            .OrderBy(index => players[index].First ? 0 : 1)
            .ThenBy(index => ids[index], ByteOrder.Instance)
            .ToArray();
    }

    /// <summary>
    /// Arranges the players of a co-op battle or a team duel: orders them (see <see cref="Ranked"/>)
    /// and tells each one's places in the battle, no more than the characters they bring.
    /// </summary>
    /// <param name="rules">The world's squad rules, <see langword="null"/> outside a Raid World.</param>
    /// <param name="raid">Whether the fight is a raid.</param>
    /// <param name="backline">Whether the players bring a share of the Backline, which a team duel's do not.</param>
    /// <param name="players">The players.</param>
    /// <returns>The players in order, each with their places; a team duel's split as in a Classic world.</returns>
    public static ArrangedPlayer[] Arrange(SquadRules? rules, bool raid, bool backline, IReadOnlyList<SquadPlayer> players)
    {
        ArgumentNullException.ThrowIfNull(players);
        int[] order = Ranked(players.Select(player => (player.Id, player.First)).ToArray());
        return order.Select((index, position) =>
        {
            SquadPlayer player = players[index];
            SquadShare share = backline ? BattleShare(rules, position, players.Count, player.Max, raid) : Shares(players.Count, player.Max)[position];
            int front = Math.Min(share.Front, player.Count);
            int bench = backline ? Math.Min(share.Bench, player.Count - front) : 0;
            return new ArrangedPlayer(index, new SquadShare(front, bench));
        }).ToArray();
    }

    /// <summary>
    /// Picks the companions a team of a size leaves out: those past its first places, Luka kept when
    /// he stays.
    /// </summary>
    /// <param name="team">The team's character ids in order.</param>
    /// <param name="luka">The ids that are Luka.</param>
    /// <param name="size">The team's size.</param>
    /// <param name="keepLuka">Whether Luka stays in the team.</param>
    /// <returns>The ids left out, in the team's order.</returns>
    public static int[] PastCap(IReadOnlyList<int> team, IReadOnlySet<int> luka, int size, bool keepLuka)
    {
        ArgumentNullException.ThrowIfNull(team);
        ArgumentNullException.ThrowIfNull(luka);
        List<int> kept = keepLuka ? team.Where(luka.Contains).Take(Math.Max(size, 0)).ToList() : [];
        foreach (int id in team)
        {
            if (kept.Count < size && !kept.Contains(id))
            {
                kept.Add(id);
            }
        }

        return team.Where(id => !kept.Contains(id)).ToArray();
    }

    /// <summary>
    /// Compares texts' bytes as Ruby's <c>String#&lt;=&gt;</c> does.
    /// </summary>
    private sealed class ByteOrder : IComparer<byte[]>
    {
        /// <summary>
        /// The one comparer.
        /// </summary>
        public static readonly ByteOrder Instance = new();

        /// <inheritdoc />
        public int Compare(byte[]? x, byte[]? y) => x.AsSpan().SequenceCompareTo(y);
    }
}
