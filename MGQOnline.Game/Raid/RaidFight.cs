//----------------------------------------------------------------
//  RaidFight.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Kept whether the battle is a side battle and its count of enemies, for the battle server
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// A battle that fights a raid boss's pools, as battles_raid_pool.rbx fought it: at each moment
/// of the battle the script hands its own enemies over; what each enemy lost since its HP was last
/// taken or reported goes to the relay, and each enemy takes its pool's HP. A host, a player alone
/// or one who took the battle over reports; a co-op guest keeps its host's HP.
/// </summary>
public sealed class RaidFight
{
    /// <summary>
    /// The least milliseconds between two reports as the battle's actions end; a command phase and
    /// the battle's end report at once. Keeps a player's reports within the relay's two a second
    /// (Relay/core/bosses.js) for a boss of up to four enemies.
    /// </summary>
    public const long ReportMs = 2_000;

    /// <summary>
    /// The milliseconds between two takes of the pools' HP while the battle waits for its players' commands.
    /// </summary>
    public const long WaitSyncMs = 5_000;

    /// <summary>
    /// The smallest share of a pool's max a report carries.
    /// </summary>
    public const double MinDelta = 1e-12;

    /// <summary>
    /// Whether the DLL refused a report of the battle, logged once.
    /// </summary>
    private bool _refusedLogged;

    /// <summary>
    /// Initializes a fight nothing was reported of yet.
    /// </summary>
    /// <param name="world">The world, which the reports name.</param>
    /// <param name="battle">The battle's id, under which the relay counts its reports once.</param>
    /// <param name="keys">The pools' keys of the troop's own enemies, by their place in the troop.</param>
    /// <param name="guest">Whether a host's stream governs the battle.</param>
    /// <param name="side">Whether it is a side battle, the player's own or a host's they join.</param>
    public RaidFight(string world, string battle, IReadOnlyList<string> keys, bool guest, bool side = false)
    {
        ArgumentNullException.ThrowIfNull(keys);
        World = world ?? throw new ArgumentNullException(nameof(world));
        Battle = battle ?? throw new ArgumentNullException(nameof(battle));
        Members = keys.Select((key, index) => new RaidMember(key, index)).ToList();
        Guest = guest;
        Side = side;
        Own = Members.Count;
    }

    /// <summary>
    /// Gets the world.
    /// </summary>
    public string World { get; }

    /// <summary>
    /// Gets the battle's id.
    /// </summary>
    public string Battle { get; }

    /// <summary>
    /// Gets the troop's own enemies, each with its pool.
    /// </summary>
    public IReadOnlyList<RaidMember> Members { get; }

    /// <summary>
    /// Gets whether the battle is a side battle.
    /// </summary>
    public bool Side { get; }

    /// <summary>
    /// Gets how many enemies the troop's setup made, which the battle server is handed; as many as
    /// the members unless the script names it.
    /// </summary>
    public long Own { get; init; }

    /// <summary>
    /// Gets the number of the battle's last report, which the relay counts once.
    /// </summary>
    public long Seq { get; private set; }

    /// <summary>
    /// Gets whether a host's stream governed the battle when last looked at.
    /// </summary>
    public bool Guest { get; private set; }

    /// <summary>
    /// Gets when the battle last reported, in milliseconds; <see langword="null"/> before.
    /// </summary>
    public long? ReportedAt { get; private set; }

    /// <summary>
    /// Gets when the battle last took the pools' HP at a command phase or while it waited for
    /// commands, in milliseconds; <see langword="null"/> before.
    /// </summary>
    public long? SyncedAt { get; private set; }

    /// <summary>
    /// Runs a moment of the battle.
    /// </summary>
    /// <param name="moment">The moment.</param>
    /// <param name="reporter">Whether the player's game reports the battle now: not a co-op guest.</param>
    /// <param name="enemies">The troop's enemies at the members' places, as the battle has them.</param>
    /// <param name="relay">The host's way to the pools.</param>
    /// <param name="now">The time in milliseconds.</param>
    /// <param name="log">Writes a line of the log.</param>
    /// <returns>What the script applies.</returns>
    public FightTurn Turn(FightMoment moment, bool reporter, IReadOnlyDictionary<int, FightEnemy> enemies, IRaidRelay relay, long now, Action<string> log)
    {
        ArgumentNullException.ThrowIfNull(enemies);
        ArgumentNullException.ThrowIfNull(relay);
        ArgumentNullException.ThrowIfNull(log);
        var turn = new TurnState(enemies, relay, now, log);
        switch (moment)
        {
            case FightMoment.Start:
                Sync(turn, false);
                break;
            case FightMoment.Phase when Reporting(turn, reporter):
                Report(turn);
                SyncedAt = now;
                Sync(turn, false);
                break;
            case FightMoment.Action when Reporting(turn, reporter) && !(ReportedAt is { } reported && now - reported < ReportMs):
                Report(turn);
                break;
            case FightMoment.Wait when Reporting(turn, reporter):
                SyncedAt ??= now;
                if (now - SyncedAt >= WaitSyncMs)
                {
                    SyncedAt = now;
                    Sync(turn, false);
                }

                break;
            case FightMoment.TurnEnd when Reporting(turn, reporter):
                Sync(turn, true);
                break;
            case FightMoment.End when Reporting(turn, reporter):
                Report(turn);
                break;
            case FightMoment.TakeOver:
            case FightMoment.Role:
                Reporting(turn, reporter);
                break;
        }

        return new FightTurn(turn.Actions, turn.Killed, turn.Reported, Guest, turn.TookOver, turn.Rebuilt,
            ReportedAt is { } at ? Math.Max(0, at + ReportMs - now) : null, SyncedAt is { } synced ? Math.Max(0, synced + WaitSyncMs - now) : null);
    }

    /// <summary>
    /// Finds an enemy's HP for a share of its max HP: at least 1 while any is left.
    /// </summary>
    /// <param name="left">The share.</param>
    /// <param name="max">Its max HP.</param>
    /// <returns>The HP.</returns>
    public static long HpOf(double left, long max) => left > 0 ? Math.Max((long)Math.Ceiling(left * max), 1) : 0;

    /// <summary>
    /// Tells whether the player's game reports the battle now, noting whether a host's stream
    /// governs it. The first time a battle a host governed is the player's to report, as the player
    /// takes it over, every enemy's base becomes its HP at that moment, since the host reported what
    /// came before.
    /// </summary>
    /// <param name="turn">The moment's state.</param>
    /// <param name="reporter">Whether the player's game reports the battle now.</param>
    /// <returns>Whether it does.</returns>
    private bool Reporting(TurnState turn, bool reporter)
    {
        if (!reporter)
        {
            Guest = true;
            return false;
        }

        if (!Guest)
        {
            return true;
        }

        Guest = false;
        foreach (RaidMember member in Members)
        {
            if (turn.Enemies.TryGetValue(member.Index, out FightEnemy enemy))
            {
                Rebase(member, enemy.Hp, enemy.Id);
            }

            member.Held = false;
        }

        turn.TookOver = true;
        return true;
    }

    /// <summary>
    /// Gives the battle's own enemies the HP of their pools, and kills those whose pool is empty.
    /// An enemy that is dead keeps its death; one whose pool the relay told nothing of, or whose last
    /// report was refused, keeps its HP. A guest's enemies keep the HP of their host's stream.
    /// </summary>
    /// <param name="turn">The moment's state.</param>
    /// <param name="onlyKill">Whether only enemies whose pool is empty change.</param>
    private void Sync(TurnState turn, bool onlyKill)
    {
        if (Guest)
        {
            return;
        }

        foreach (RaidMember member in Members)
        {
            if (!turn.Enemies.TryGetValue(member.Index, out FightEnemy enemy))
            {
                continue;
            }

            PoolView? pool = turn.Relay.Ledger.Pool(member.Key);
            if (pool is null || enemy.Dead)
            {
                // Taken only once, since a later base would swallow what the battle dealt since its last report.
                if (member.Base is null && !onlyKill)
                {
                    Rebase(member, enemy.Hp, enemy.Id);
                }

                continue;
            }

            if (onlyKill && pool.Left > 0)
            {
                continue;
            }

            long target = HpOf(pool.Left, enemy.Mhp);
            if (target <= 0)
            {
                turn.Actions.Add(new FightAction(member.Index, 0));
                turn.Killed = true;
                Rebase(member, 0, enemy.Id);
            }
            else if (member.Held)
            {
                continue;
            }
            else
            {
                if (enemy.Hp != target)
                {
                    turn.Actions.Add(new FightAction(member.Index, target));
                }

                Rebase(member, target, enemy.Id);
            }
        }
    }

    /// <summary>
    /// Reports what each of the battle's own enemies lost since its HP was last taken or reported,
    /// as a share of its max HP, and its death. A report the host refuses is added to the next.
    /// </summary>
    /// <param name="turn">The moment's state.</param>
    private void Report(TurnState turn)
    {
        ReportedAt = turn.Now;
        foreach (RaidMember member in Members)
        {
            if (member.Killed || !turn.Enemies.TryGetValue(member.Index, out FightEnemy enemy))
            {
                continue;
            }

            // An enemy built anew since its HP was last taken, such as a troop rebuilt from its host's,
            // reports nothing, so its full HP never counts as healing the pool; the next sync gives it the pool's.
            if (member.EnemyId is { } known && known != enemy.Id)
            {
                Rebase(member, enemy.Hp, enemy.Id);
                turn.Rebuilt.Add(member.Index);
                continue;
            }

            long max = enemy.Mhp;
            if (max <= 0)
            {
                continue;
            }

            // A base above the max HP now is a max the game lowered since, which took the HP down with it;
            // an HP above it is a max lowered without taking the HP down, which the game's next change cuts.
            long baseHp = Math.Min(member.Base ?? max, max);
            long hp = Math.Min(enemy.Hp, max);
            double delta = Math.Clamp((double)(baseHp - hp) / max, -1.0, 1.0);
            if (!enemy.Dead && Math.Abs(delta) < MinDelta)
            {
                continue;
            }

            long seq = Seq + 1;
            string text = $"{seq}\t{delta.ToString("F10", CultureInfo.InvariantCulture)}\t{max}\t{(enemy.Dead ? 1 : 0)}";
            if (!turn.Relay.Report(World, member.Key, Battle, text))
            {
                member.Held = true;
                if (!_refusedLogged)
                {
                    _refusedLogged = true;
                    turn.Log($"the DLL took no report of battle {Battle}: what it dealt goes with the next");
                }

                continue;
            }

            Seq = seq;
            Rebase(member, hp, enemy.Id);
            member.Killed = enemy.Dead;
            member.Held = false;
            turn.Reported = true;
            turn.Log($"battle {Battle} reports {member.Key} #{seq}: {delta.ToString("F6", CultureInfo.InvariantCulture)} of {max}{(enemy.Dead ? ", killed" : string.Empty)}");
        }
    }

    /// <summary>
    /// Takes an enemy's HP as the base its next report counts from.
    /// </summary>
    /// <param name="member">The enemy's place in the battle.</param>
    /// <param name="hp">The HP.</param>
    /// <param name="enemy">The id of the enemy whose HP it is.</param>
    private static void Rebase(RaidMember member, long hp, long enemy)
    {
        member.Base = hp;
        member.EnemyId = enemy;
    }

    /// <summary>
    /// What one moment of the battle saw and did.
    /// </summary>
    /// <param name="Enemies">The troop's enemies at the members' places.</param>
    /// <param name="Relay">The host's way to the pools.</param>
    /// <param name="Now">The time in milliseconds.</param>
    /// <param name="Log">Writes a line of the log.</param>
    private sealed record TurnState(IReadOnlyDictionary<int, FightEnemy> Enemies, IRaidRelay Relay, long Now, Action<string> Log)
    {
        /// <summary>
        /// Gets the HP the script sets, in order.
        /// </summary>
        public List<FightAction> Actions { get; } = [];

        /// <summary>
        /// Gets the places of the enemies built anew since their HP was last taken.
        /// </summary>
        public List<int> Rebuilt { get; } = [];

        /// <summary>
        /// Gets or sets whether an empty pool killed an enemy.
        /// </summary>
        public bool Killed { get; set; }

        /// <summary>
        /// Gets or sets whether a report went out.
        /// </summary>
        public bool Reported { get; set; }

        /// <summary>
        /// Gets or sets whether the player took the battle over.
        /// </summary>
        public bool TookOver { get; set; }
    }
}

/// <summary>
/// One of the troop's own enemies in a battle that fights a raid boss's pools.
/// </summary>
/// <param name="key">Its pool's key at the relay.</param>
/// <param name="index">Its place in the troop.</param>
public sealed class RaidMember(string key, int index)
{
    /// <summary>
    /// Gets its pool's key.
    /// </summary>
    public string Key { get; } = key;

    /// <summary>
    /// Gets its place in the troop.
    /// </summary>
    public int Index { get; } = index;

    /// <summary>
    /// Gets or sets its HP as last taken from the pool or reported, <see langword="null"/> before.
    /// </summary>
    public long? Base { get; set; }

    /// <summary>
    /// Gets or sets whether its death was reported.
    /// </summary>
    public bool Killed { get; set; }

    /// <summary>
    /// Gets or sets whether its last report was refused, so its HP waits for the next instead of taking the pool's.
    /// </summary>
    public bool Held { get; set; }

    /// <summary>
    /// Gets or sets the id of the enemy whose HP <see cref="Base"/> is, <see langword="null"/> before.
    /// </summary>
    public long? EnemyId { get; set; }
}

/// <summary>
/// One of the battle's own enemies as the script hands it over.
/// </summary>
/// <param name="Hp">Its HP.</param>
/// <param name="Mhp">Its max HP, with its tier's factor.</param>
/// <param name="Dead">Whether it is dead.</param>
/// <param name="Id">The id of its object, which tells an enemy built anew apart.</param>
public readonly record struct FightEnemy(long Hp, long Mhp, bool Dead, long Id);

/// <summary>
/// A moment of a battle that fights a raid boss's pools.
/// </summary>
public enum FightMoment
{
    /// <summary>
    /// The battle starts fighting the pools, or a troop was built anew: its enemies take their pools' HP.
    /// </summary>
    Start,

    /// <summary>
    /// A command phase opens: the turn's damage is reported and the enemies take their pools' HP.
    /// </summary>
    Phase,

    /// <summary>
    /// An action ended: its damage is reported, at most every <see cref="RaidFight.ReportMs"/>.
    /// </summary>
    Action,

    /// <summary>
    /// The battle waits for its players' commands: the enemies take their pools' HP every <see cref="RaidFight.WaitSyncMs"/>.
    /// </summary>
    Wait,

    /// <summary>
    /// A turn ends: the enemies whose pool is empty die.
    /// </summary>
    TurnEnd,

    /// <summary>
    /// The battle ends: its last blows are reported, and the fight ends.
    /// </summary>
    End,

    /// <summary>
    /// The player took the battle over from its host.
    /// </summary>
    TakeOver,

    /// <summary>
    /// The player's role in the battle changed.
    /// </summary>
    Role,
}

/// <summary>
/// An HP the script sets on one of the battle's own enemies.
/// </summary>
/// <param name="Index">The enemy's place in the troop.</param>
/// <param name="Hp">The HP; 0 kills the enemy, with its collapse.</param>
public sealed record FightAction(int Index, long Hp);

/// <summary>
/// What a moment of the battle did, for the script to apply.
/// </summary>
/// <param name="Actions">The HP to set, in order.</param>
/// <param name="Killed">Whether an empty pool killed an enemy.</param>
/// <param name="Reported">Whether a report went out, after which the script reads the pools again.</param>
/// <param name="Guest">Whether a host's stream governs the battle.</param>
/// <param name="TookOver">Whether the player took the battle over in this moment.</param>
/// <param name="Rebuilt">The places of the enemies built anew since their HP was last taken.</param>
/// <param name="ReportIn">The milliseconds until an action's end may report again, <see langword="null"/> while it may at once.</param>
/// <param name="SyncIn">The milliseconds until the wait for commands takes the pools' HP again, <see langword="null"/> while it may at once.</param>
public sealed record FightTurn(IReadOnlyList<FightAction> Actions, bool Killed, bool Reported, bool Guest, bool TookOver, IReadOnlyList<int> Rebuilt, long? ReportIn, long? SyncIn);
