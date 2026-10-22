//----------------------------------------------------------------
//  RuntimeBoss.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the boss's own normal attacks per turn
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A raid boss fight, every value resolved.
/// </summary>
/// <param name="Id">The boss entity id.</param>
/// <param name="Key">The boss key, which is also its pool key.</param>
/// <param name="Name">The boss's name.</param>
/// <param name="Title">The title below its HP gauge, resolved.</param>
/// <param name="Order">The story order within its tier.</param>
/// <param name="Removed">Whether the design took it out of the catalog; its troops fight as normal battles.</param>
/// <param name="Optional">Whether it is a one-time boss outside the story.</param>
/// <param name="Origin">Where it comes from.</param>
/// <param name="Troops">Its troops in phase order, the earlier phases first.</param>
/// <param name="Last">The troop the challenge picker fights and whose HP the pool shares.</param>
/// <param name="Enemies">The members of every troop in phase order.</param>
/// <param name="Actions">The action list per enemy id.</param>
/// <param name="NormalAttack">The normal attack.</param>
/// <param name="Traits">The tier's and the boss's traits, merged.</param>
/// <param name="Skills">Every skill the boss uses, by skill key.</param>
/// <param name="Rules">The rules the boss's presets are lowered to, and its advanced rules.</param>
/// <param name="MarkReactions">The mark reactions as set, for the logs.</param>
/// <param name="BattleMaps">The maps the boss is fought on, its own first.</param>
/// <param name="Tier">The tier, or null for none.</param>
/// <param name="NormalAttacks">The most normal attacks each enemy rolls per turn, or null for its tier's.</param>
public sealed record RuntimeBoss(
    string Id,
    string Key,
    string Name,
    string Title,
    int Order,
    bool Removed,
    bool Optional,
    BossOrigin Origin,
    IReadOnlyList<TroopPhase> Troops,
    int Last,
    IReadOnlyList<RuntimeEnemy> Enemies,
    IReadOnlyDictionary<int, IReadOnlyList<RuntimeAction>> Actions,
    RuntimeNormalAttack NormalAttack,
    TraitBlock Traits,
    IReadOnlyDictionary<string, RuntimeSkill> Skills,
    IReadOnlyList<RuleSpec> Rules,
    IReadOnlyList<MarkReactionSpec> MarkReactions,
    IReadOnlyList<BattleMapRef> BattleMaps,
    int? Tier = null,
    int? NormalAttacks = null);

/// <summary>
/// One troop of a boss fight.
/// </summary>
/// <param name="Troop">The troop id.</param>
/// <param name="Last">Whether the troop always ends the fight.</param>
/// <param name="Milestone">The story milestone, or null.</param>
/// <param name="Cap">The milestone's level cap, or null.</param>
/// <param name="LastSwitch">The switch while which it ends the fight, or null.</param>
/// <param name="LeadsInto">The fight troop this earlier phase's battle leads into, or null.</param>
/// <param name="SkirmishMap">The map where the story fights it before the fight that defeats it, or null.</param>
/// <param name="Unpooled">Why its last phase never has a pool, or null when it may.</param>
public sealed record TroopPhase(
    int Troop,
    bool Last,
    string? Milestone = null,
    int? Cap = null,
    int? LastSwitch = null,
    int? LeadsInto = null,
    int? SkirmishMap = null,
    string? Unpooled = null);

/// <summary>
/// A member of a boss's troop.
/// </summary>
/// <param name="Troop">The troop id.</param>
/// <param name="Index">Its place in the troop.</param>
/// <param name="EnemyId">The enemy id.</param>
/// <param name="Stats">Its stats with the tier factors applied.</param>
/// <param name="Ap">The action points it spends per turn before its features.</param>
public sealed record RuntimeEnemy(int Troop, int Index, int EnemyId, EnemyStats Stats, int Ap);

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
