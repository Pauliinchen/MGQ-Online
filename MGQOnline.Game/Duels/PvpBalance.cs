//----------------------------------------------------------------
//  PvpBalance.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Duels;

/// <summary>
/// The balance of a PvP battle, which battles_balance_pvp.rbx applies: skills deal what they deal
/// in a monster's hands, every character has more HP, one action takes only a part of a
/// character's HP however strong it is, and what kept a character from all harm keeps it from
/// most of it. The automatic skills of both teams fire by their characters' speed.
/// </summary>
/// <remarks>
/// The game balances a character against monsters, so between two players the first hit or an
/// untouchable team would decide the battle.
/// </remarks>
public static class PvpBalance
{
    /// <summary>
    /// Whether a skill deals what it deals in a monster's hands; most skills carry a second formula
    /// for monsters, which the game balanced against a character's HP.
    /// </summary>
    public const bool MonsterFormulas = true;

    /// <summary>
    /// How many times its max HP a character has.
    /// </summary>
    public const int HpRate = 4;

    /// <summary>
    /// The share of a character's max HP up to which one action's damage or healing counts in full.
    /// </summary>
    public const double DamageKnee = 0.2;

    /// <summary>
    /// The share of a character's max HP that one action's damage or healing stays below, however
    /// large it is.
    /// </summary>
    /// <remarks>
    /// A late-game hit deals millions of times its target's HP, which no amount of added HP makes up for.
    /// </remarks>
    public const double DamageLimit = 0.6;

    /// <summary>
    /// The highest chance a character evades or reflects a hit with.
    /// </summary>
    public const double AvoidCeiling = 0.75;

    /// <summary>
    /// The lowest share of an attack's damage its elements leave, for a character that takes none
    /// of an element or absorbs it.
    /// </summary>
    public const double ElementFloor = 0.25;

    /// <summary>
    /// The lowest share of a hit a character takes, for one whose states or abilities let it take
    /// no physical, magical or sure-hit damage at all.
    /// </summary>
    public const double DamageRateFloor = 0.25;

    /// <summary>
    /// The share of its max HP a character's defense wall takes off one hit.
    /// </summary>
    public const double WallShare = 0.25;

    /// <summary>
    /// Works out what a hit deals or heals: up to <see cref="DamageKnee"/> of the target's max HP
    /// counts in full, beyond that ever less, and the hits of one action on one target count
    /// together, so a skill of many hits takes no more than one strong hit.
    /// </summary>
    /// <param name="maxHp">The target's max HP in the battle, above 0.</param>
    /// <param name="before">What the action's earlier hits on the target dealt or healed as the game
    /// works them out.</param>
    /// <param name="value">What this hit deals or heals as the game works it out, without its sign.</param>
    /// <returns>What it deals or heals in the battle, without its sign.</returns>
    public static double Hit(double maxHp, double before, double value) =>
        maxHp * (Share((before + value) / maxHp) - Share(before / maxHp));

    /// <summary>
    /// Works out what gets through a defense wall that took a whole hit as the game works it out:
    /// the wall takes <see cref="WallShare"/> of the character's max HP off it.
    /// </summary>
    /// <param name="maxHp">The character's max HP in the battle.</param>
    /// <param name="damage">The hit before the wall.</param>
    /// <returns>What gets through.</returns>
    public static double Wall(long maxHp, double damage) => Math.Max(damage - Math.Truncate(maxHp * WallShare), 0);

    /// <summary>
    /// Orders queued automatic skills by their characters' speed, the fastest first, each character
    /// rolling the speed the game rolls for its turn: its agility plus up to a quarter of it and 4.
    /// </summary>
    /// <remarks>
    /// The game queues the party's before the troop's, so the host's team would always act first.
    /// </remarks>
    /// <param name="owners">Each skill's character, by a key and its agility, in the queue's order.</param>
    /// <param name="random">The randomness the speeds are rolled with.</param>
    /// <returns>The skills' places in the queue, a faster character's before a slower one's.</returns>
    public static IReadOnlyList<int> BySpeed(IReadOnlyList<(long Key, long Agility)> owners, Random random)
    {
        ArgumentNullException.ThrowIfNull(owners);
        ArgumentNullException.ThrowIfNull(random);
        Dictionary<long, long> speeds = [];
        foreach ((long key, long agility) in owners)
        {
            if (!speeds.ContainsKey(key))
            {
                speeds[key] = agility + random.Next((int)(5 + Math.Floor(agility / 4.0)));
            }
        }

        return [.. Enumerable.Range(0, owners.Count).OrderBy(place => -speeds[owners[place].Key]).ThenBy(place => place)];
    }

    /// <summary>
    /// Works out the share of max HP an action takes or gives for the share it would without the
    /// balance.
    /// </summary>
    /// <param name="raw">The share without the balance, which may be many times the max HP.</param>
    /// <returns>The share in the battle, below <see cref="DamageLimit"/>.</returns>
    private static double Share(double raw) =>
        raw <= DamageKnee ? raw : DamageKnee + ((DamageLimit - DamageKnee) * (1.0 - (1.0 / (1.0 + Math.Log10(raw / DamageKnee)))));
}
