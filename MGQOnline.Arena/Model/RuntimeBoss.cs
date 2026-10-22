//----------------------------------------------------------------
//  RuntimeBoss.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Fought one event battle with its starting enemies and a reserve in place of the troop phases
//                            - Gave every enemy of a fight its own slot with its own action list
//                            - Added the boss's start debris
//      Paulinchen  2026-10-22: Added the boss's own normal attacks per turn
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A raid boss fight, every value resolved.
/// </summary>
/// <param name="Id">The boss entity id.</param>
/// <param name="Key">The boss key, which is also its pool key.</param>
/// <param name="Name">The boss's name.</param>
/// <param name="Title">The title below its HP gauge, resolved.</param>
/// <param name="Order">The story order within its tier.</param>
/// <param name="Removed">Whether the design took it out of the catalog; its battle fights as a normal one.</param>
/// <param name="Optional">Whether it is a one-time boss outside the story.</param>
/// <param name="Origin">Where it comes from.</param>
/// <param name="Event">The event battle it is fought in.</param>
/// <param name="Enemies">The starting line-up, in its order.</param>
/// <param name="Actions">The action list per enemy slot, the reserve's included.</param>
/// <param name="NormalAttack">The normal attack.</param>
/// <param name="Traits">The tier's and the boss's traits, merged.</param>
/// <param name="Skills">Every skill the boss uses, by skill key.</param>
/// <param name="Rules">The rules the boss's presets are lowered to, and its advanced rules.</param>
/// <param name="MarkReactions">The mark reactions as set, for the logs.</param>
/// <param name="BattleMaps">The maps the boss is fought on, its own first.</param>
/// <param name="Tier">The tier, or null for none.</param>
/// <param name="NormalAttacks">The most normal attacks each enemy rolls per turn, or null for its tier's.</param>
/// <param name="Reserve">The slots a rule may only bring in by a join or a transform, or null for none.</param>
/// <param name="StartDebris">The random debris its battles start with, resolved over the game rule's, its type the boss's own; null for the game rule's.</param>
public sealed record RuntimeBoss(
    string Id,
    string Key,
    string Name,
    string Title,
    int Order,
    bool Removed,
    bool Optional,
    BossOrigin Origin,
    BattleEventRef Event,
    IReadOnlyList<RuntimeEnemy> Enemies,
    IReadOnlyDictionary<string, IReadOnlyList<RuntimeAction>> Actions,
    RuntimeNormalAttack NormalAttack,
    TraitBlock Traits,
    IReadOnlyDictionary<string, RuntimeSkill> Skills,
    IReadOnlyList<RuleSpec> Rules,
    IReadOnlyList<MarkReactionSpec> MarkReactions,
    IReadOnlyList<BattleMapRef> BattleMaps,
    int? Tier = null,
    int? NormalAttacks = null,
    IReadOnlyList<ReserveEnemy>? Reserve = null,
    RandomDebris? StartDebris = null);

/// <summary>
/// The event command that starts a boss's battle.
/// </summary>
/// <param name="Command">The command's index in the page's or the common event's list, from 0.</param>
/// <param name="Map">The map of a map event, or null for a common event.</param>
/// <param name="Event">The map event's id, or null for a common event.</param>
/// <param name="Page">The event page's index, from 0, or null for a common event.</param>
/// <param name="CommonEvent">The common event's id, or null for a map event.</param>
public sealed record BattleEventRef(int Command, int? Map = null, int? Event = null, int? Page = null, int? CommonEvent = null)
{
    /// <summary>
    /// Gets the key that names the battle command: <c>m{map}e{event}p{page}c{command}</c> for a map event,
    /// <c>ce{commonEvent}c{command}</c> for a common event.
    /// </summary>
    [JsonIgnore]
    public string Key => CommonEvent is int common
        ? string.Create(CultureInfo.InvariantCulture, $"ce{common}c{Command}")
        : string.Create(CultureInfo.InvariantCulture, $"m{Map}e{Event}p{Page}c{Command}");
}

/// <summary>
/// An enemy slot of a boss's starting line-up.
/// </summary>
/// <param name="Index">Its place in the starting line-up.</param>
/// <param name="Slot">The slot's item id, which names its action list.</param>
/// <param name="EnemyId">The enemy id.</param>
/// <param name="Stats">Its stats, resolved by the designer.</param>
/// <param name="Ap">The action points it spends per turn before its features.</param>
/// <param name="RaidBoss">Whether its HP is in the shared raid pool.</param>
public sealed record RuntimeEnemy(int Index, string Slot, int EnemyId, EnemyStats Stats, int Ap, bool RaidBoss = false);

/// <summary>
/// An enemy slot that only joins a boss's battle or is transformed into by a rule.
/// </summary>
/// <param name="Slot">The slot's item id, which names its action list.</param>
/// <param name="EnemyId">The enemy id.</param>
/// <param name="Stats">Its stats, resolved by the designer.</param>
/// <param name="Ap">The action points it spends per turn before its features.</param>
/// <param name="RaidBoss">Whether its HP is in the shared raid pool when it joins.</param>
public sealed record ReserveEnemy(string Slot, int EnemyId, EnemyStats Stats, int Ap, bool RaidBoss = false);

/// <summary>
/// An enemy's base stats.
/// </summary>
/// <param name="Mhp">The max HP.</param>
/// <param name="Mmp">The max MP.</param>
/// <param name="Atk">The attack.</param>
/// <param name="Def">The defense.</param>
/// <param name="Mat">The magic attack.</param>
/// <param name="Mdf">The magic defense.</param>
/// <param name="Agi">The agility.</param>
/// <param name="Luk">The luck.</param>
public sealed record EnemyStats(long Mhp, long Mmp, int Atk, int Def, int Mat, int Mdf, int Agi, int Luk);

/// <summary>
/// A boss's normal attack.
/// </summary>
/// <param name="ByEnemy">The skill each enemy then counts as its attack.</param>
/// <param name="AttackTimes">The extra attack times per enemy.</param>
/// <param name="Override">The design's normal attack, or null for the game's.</param>
/// <param name="Tag">The note tag that sets it, with placeholders, or null.</param>
public sealed record RuntimeNormalAttack(
    IReadOnlyDictionary<int, SkillRef> ByEnemy,
    IReadOnlyDictionary<int, int> AttackTimes,
    SkillRef? Override = null,
    string? Tag = null);

/// <summary>
/// A map a boss is fought on.
/// </summary>
/// <param name="Map">The map id.</param>
/// <param name="RematchRoom">Whether it is a rematch room.</param>
public sealed record BattleMapRef(int Map, bool RematchRoom);
