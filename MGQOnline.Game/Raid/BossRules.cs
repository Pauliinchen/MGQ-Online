//----------------------------------------------------------------
//  BossRules.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Shared the refusal of a Hades rematch and a Colosseum battle with a lost battle's defeat
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The rules of the raid bosses, as battles_raid_pool.rbx and battles_raid_tiers.rbx decided them:
/// which story boss battles fight a Raid World's pool or a boss at its tier outside one, why one does
/// not (one refusal chain for both), what a battle about to be set up is, whether the story beat a
/// milestone, and whether a troop's pools are empty and its bar shows.
/// </summary>
public static class BossRules
{
    /// <summary>
    /// The switch the Colosseum's battles turn on.
    /// </summary>
    public const int ColosseumSwitch = 87;

    /// <summary>
    /// The switch the Hades rematches turn on around their battles.
    /// </summary>
    public const int HadesSwitch = 97;

    /// <summary>
    /// The map of the Hades rematch hall, whose events start the rematches before they turn
    /// <see cref="HadesSwitch"/> on.
    /// </summary>
    public const int HadesMap = 576;

    /// <summary>
    /// Why a battle fights no pool and keeps its boss while the game handed fewer story values than
    /// the rules read (<see cref="RaidFacts.Complete"/>).
    /// </summary>
    public const string ShortFacts = "the game handed fewer story values than the rules read";

    /// <summary>
    /// Gets the switches the rules read: the sides', those of the beaten markers, the Colosseum's
    /// and the Hades rematches'.
    /// </summary>
    public static IReadOnlyList<int> ReadSwitches { get; } = [.. BossTable.ReadSwitches.Append(ColosseumSwitch).Append(HadesSwitch).Distinct().Order()];

    /// <summary>
    /// Gets the variables the rules read.
    /// </summary>
    public static IReadOnlyList<int> ReadVariables => BossTable.ReadVariables;

    /// <summary>
    /// Tells whether a troop is the last phase of its boss fight, reading the side's switch where
    /// that decides it, and never on the map of a skirmish.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The game.</param>
    /// <returns>Whether it is, false for a troop that is no boss.</returns>
    public static bool LastPhase(int troop, RaidFacts facts)
    {
        RaidBoss? boss = BossTable.At(troop);
        return boss is not null && BossTable.SkirmishMap(troop) != facts.Map && (boss.LastSwitch < 0 || (boss.LastSwitch > 0 && facts.Switch(boss.LastSwitch)));
    }

    /// <summary>
    /// Tells whether the player is at a Hades rematch: its switch is on, or the player stands in the
    /// rematch hall.
    /// </summary>
    /// <param name="facts">The game.</param>
    /// <returns>Whether they are.</returns>
    public static bool Hades(RaidFacts facts) => facts.Switch(HadesSwitch) || facts.Map == HadesMap;

    /// <summary>
    /// Finds why a battle fights no story at all: a Hades rematch or a Colosseum battle runs.
    /// </summary>
    /// <param name="facts">The game.</param>
    /// <returns>Why, null for none.</returns>
    public static string? ArenaRefusal(RaidFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        return Hades(facts) ? "a Hades rematch" : facts.Switch(ColosseumSwitch) ? "a Colosseum battle" : null;
    }

    /// <summary>
    /// Tells whether a story beat a boss's milestone, by its marker.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <param name="facts">The story.</param>
    /// <returns>Whether it did; false for a milestone without a marker.</returns>
    public static bool Beaten(RaidBoss boss, RaidFacts facts) => BossTable.MarkerFor(boss)?.Met(facts) == true;

    /// <summary>
    /// Tells whether a story beat a troop's milestone.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The story.</param>
    /// <returns>Whether it did; false for a troop that is no boss.</returns>
    public static bool Beaten(int troop, RaidFacts facts) => BossTable.At(troop) is { } boss && Beaten(boss, facts);

    /// <summary>
    /// Lists the level caps of the milestones a story beat, which a story write names for the
    /// world's catch-up experience.
    /// </summary>
    /// <remarks>The milestone after the last cap has none, which the script's sort failed on.</remarks>
    /// <param name="facts">The story.</param>
    /// <returns>Each cap once, lowest first.</returns>
    public static IReadOnlyList<int> BeatenCaps(RaidFacts facts) =>
        [.. BossTable.BeatenMarkers.Where(marker => marker.Cap is not null && marker.Met(facts)).Select(marker => marker.Cap!.Value).Distinct().Order()];

    /// <summary>
    /// Finds why a story boss battle fights no pool (<see cref="RaidMode.Pools"/>) or keeps its boss
    /// as the game has it (<see cref="RaidMode.Tiers"/>).
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The game.</param>
    /// <param name="mode">Whose rules.</param>
    /// <param name="beaten">Whether a milestone the story beat refuses too.</param>
    /// <returns>Why, null when it fights.</returns>
    public static string? Refusal(int troop, RaidFacts facts, RaidMode mode, bool beaten = true)
    {
        RaidBoss? boss = BossTable.At(troop);
        if (boss is null && mode == RaidMode.Tiers)
        {
            return "it is no raid boss";
        }

        if (!facts.Complete)
        {
            return ShortFacts;
        }

        if (!LastPhase(troop, facts))
        {
            return "an earlier phase of its fight";
        }

        if (BossTable.Unpooled(troop) is { } unpooled)
        {
            return mode == RaidMode.Pools ? unpooled : $"a fight raid bosses leave out: {unpooled}";
        }

        if (ArenaRefusal(facts) is { } arena)
        {
            return arena;
        }

        if (mode == RaidMode.Pools && BossTable.KeyOf(troop) is null)
        {
            return "its key is none the relay takes";
        }

        if (beaten && Beaten(boss!, facts))
        {
            return $"the story beat {boss!.Milestone} already";
        }

        return mode == RaidMode.Tiers && BossTable.Tier(troop) is null ? "it has no tier" : null;
    }

    /// <summary>
    /// Tells whether a troop's boss has pools the player may fight: the last phase of a story boss
    /// the story has not beaten, which the relay takes a key of.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The game.</param>
    /// <returns>Whether it has; false while the facts are not <see cref="RaidFacts.Complete"/>.</returns>
    public static bool Pooled(int troop, RaidFacts facts) =>
        facts.Complete && BossTable.At(troop) is { } boss && LastPhase(troop, facts) && BossTable.Unpooled(troop) is null && !Beaten(boss, facts) && BossTable.KeyOf(troop) is not null;

    /// <summary>
    /// Tells whether a story boss battle refights a boss the story beat already, which it wins at
    /// once as one whose pools are all empty.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The game.</param>
    /// <returns>Whether it does.</returns>
    public static bool StoryWon(int troop, RaidFacts facts) => Beaten(troop, facts) && Refusal(troop, facts, RaidMode.Pools, beaten: false) is null;

    /// <summary>
    /// Finds the pools of a troop's own enemies.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="own">How many enemies the troop's setup makes.</param>
    /// <returns>The keys, none for a troop without a key.</returns>
    public static IReadOnlyList<string> Keys(int troop, int own) => BossTable.KeyOf(troop) is { } key ? BossTable.MemberKeys(key, own) : [];

    /// <summary>
    /// Tells whether every pool of a troop's own enemies is empty, as the ledger knows them now.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="own">How many enemies the troop's setup makes.</param>
    /// <param name="ledger">The pools.</param>
    /// <returns>Whether it is; false for a troop without pools or one the relay told nothing of.</returns>
    public static bool Defeated(int troop, int own, PoolLedger ledger)
    {
        IReadOnlyList<string> keys = Keys(troop, own);
        return keys.Count > 0 && keys.All(key => ledger.Pool(key) is { } pool && pool.Left <= 0);
    }

    /// <summary>
    /// Tells whether a troop's battle shows a bar in a Raid World: the last phase of a raid boss
    /// with pools the relay keeps, or whose milestone the story has not beaten, outside the Hades
    /// rematches.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The game.</param>
    /// <param name="own">How many enemies the troop's setup makes.</param>
    /// <param name="ledger">The pools.</param>
    /// <returns>Whether it does.</returns>
    public static bool Shown(int troop, RaidFacts facts, int own, PoolLedger ledger)
    {
        if (!LastPhase(troop, facts) || BossTable.Unpooled(troop) is not null || Hades(facts))
        {
            return false;
        }

        IReadOnlyList<string> keys = Keys(troop, own);
        return keys.Count > 0 && (Pooled(troop, facts) || keys.Any(key => ledger.Pool(key) is not null));
    }

    /// <summary>
    /// Decides how a battle about to be set up, or just set up, fights a pool or its boss at its tier.
    /// </summary>
    /// <param name="ask">The battle and what the scripts know of it.</param>
    /// <param name="facts">The game.</param>
    /// <returns>The answer.</returns>
    public static BattleKind Kind(BattleAsk ask, RaidFacts facts)
    {
        ArgumentNullException.ThrowIfNull(ask);
        bool story = ask.AtCommand && ask.InMap && ask.Active && BossTable.IsBoss(ask.Troop);
        string? refusal = story ? Refusal(ask.Troop, facts, ask.Mode) : null;
        string? why = story ? refusal ?? (ask.Event ? null : "a common event of its own started it") : null;
        string? kind = ask.Mode == RaidMode.Pools ? PoolKind(ask, story && ask.Event && refusal is null) : TierKind(ask, story && ask.Event && refusal is null);
        bool won = ask.Mode == RaidMode.Pools && kind is null && story && ask.Event && StoryWon(ask.Troop, facts);
        return new BattleKind(kind, kind is null ? why : null, won);
    }

    /// <summary>
    /// Finds how a battle fights a pool in a Raid World.
    /// </summary>
    /// <param name="ask">The battle.</param>
    /// <param name="story">Whether it is an event's story boss battle that fights one.</param>
    /// <returns>"side", "guest" or "event"; a retry the lost battle's kind; null for none.</returns>
    private static string? PoolKind(BattleAsk ask, bool story)
    {
        if (ask.Retry is { } lost && lost.Troop == ask.Troop)
        {
            return lost.Side ? "side" : "event";
        }

        if (ask.Side == ask.Troop)
        {
            return "side";
        }

        if (ask.Invited is { } invited && invited.Troop == ask.Troop)
        {
            return "guest";
        }

        return story ? "event" : null;
    }

    /// <summary>
    /// Finds how a battle fights its boss at its tier outside a Raid World.
    /// </summary>
    /// <param name="ask">The battle.</param>
    /// <param name="story">Whether it is an event's story boss battle that fights at its tier.</param>
    /// <returns>"retry", "invited" or "event"; null for none, always in a Raid World.</returns>
    private static string? TierKind(BattleAsk ask, bool story)
    {
        if (ask.Raid)
        {
            return null;
        }

        if (ask.Retry is { } lost && lost.Troop == ask.Troop)
        {
            return "retry";
        }

        if (ask.Invited is { } invited && invited.Troop == ask.Troop)
        {
            return "invited";
        }

        return story ? "event" : null;
    }
}
