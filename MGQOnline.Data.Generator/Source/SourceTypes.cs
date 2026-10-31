//----------------------------------------------------------------
//  SourceTypes.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the switches an enemy's actions ask for and a skill's or item's damage formula
//      Paulinchen  2026-10-30: Kept whether an entry holds a note, features or effects instead of whether it has a name
//      Paulinchen  2026-10-28: Kept common event names, item descriptions and enemy notes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Source;

/// <summary>
/// The conditions of a map event's page, the ids only of those it checks.
/// </summary>
/// <param name="Switch1">The first switch that must be on, <see langword="null"/> for none.</param>
/// <param name="Switch2">The second switch that must be on, <see langword="null"/> for none.</param>
/// <param name="Variable">The variable that must be at least <paramref name="VariableValue"/>, <see langword="null"/> for none.</param>
/// <param name="VariableValue">The least value of <paramref name="Variable"/>.</param>
/// <param name="SelfSwitch">The self switch that must be on, such as "A", <see langword="null"/> for none.</param>
/// <param name="Item">The item the party must hold, <see langword="null"/> for none.</param>
/// <param name="Actor">The actor who must be in the party, <see langword="null"/> for none.</param>
internal sealed record SourceCondition(int? Switch1, int? Switch2, int? Variable, long VariableValue, string? SelfSwitch, int? Item, int? Actor)
{
    /// <summary>
    /// The conditions of a page that checks nothing.
    /// </summary>
    public static readonly SourceCondition None = new(null, null, null, 0, null, null, null);

    /// <summary>
    /// Gets the conditions the rules read: the switches, the variable and the self switch.
    /// </summary>
    public PageCondition ForRules => new(Switch1, Switch2, Variable, VariableValue, SelfSwitch);
}

/// <summary>
/// One page of a map event as its map file holds it.
/// </summary>
/// <param name="Condition">When it shows.</param>
/// <param name="Trigger">How it starts.</param>
/// <param name="MoveType">How the event moves by itself.</param>
/// <param name="List">Its commands, the parameters of those no rule reads left out.</param>
internal sealed record SourcePage(SourceCondition Condition, int Trigger, int MoveType, IReadOnlyList<RawCommand> List);

/// <summary>
/// One event of a map.
/// </summary>
/// <param name="Id">Its id on the map.</param>
/// <param name="X">Where it starts across.</param>
/// <param name="Y">Where it starts down.</param>
/// <param name="Pages">Its pages, in order.</param>
internal sealed record SourceEvent(int Id, int X, int Y, IReadOnlyList<SourcePage> Pages);

/// <summary>
/// A troop a map's random encounters may meet.
/// </summary>
/// <param name="TroopId">The troop.</param>
/// <param name="Weight">How often it comes against the others.</param>
internal readonly record struct SourceEncounter(int TroopId, int Weight);

/// <summary>
/// A map as its MapNNN.rvdata2 holds it.
/// </summary>
/// <param name="TilesetId">Its tileset.</param>
/// <param name="Encounters">Its random encounters, in order.</param>
/// <param name="Events">Its events by id.</param>
internal sealed record SourceMap(int TilesetId, IReadOnlyList<SourceEncounter> Encounters, IReadOnlyDictionary<int, SourceEvent> Events);

/// <summary>
/// A map as the map lists name it.
/// </summary>
/// <param name="Id">Its id, a thousand per map folder.</param>
/// <param name="Folder">Its map folder, 0 for Data itself.</param>
/// <param name="Number">Its number in the folder.</param>
/// <param name="ParentId">The map above it in the editor's tree, 0 for none.</param>
/// <param name="RootName">The name of its tree's root in the folder's list, its own when it is a root.</param>
internal sealed record SourceMapInfo(int Id, int Folder, int Number, int ParentId, string RootName);

/// <summary>
/// A common event as CommonEvents.rvdata2 holds it, before the game puts its mark first.
/// </summary>
/// <param name="Id">Its id: its place in the file's list, by which the game finds it.</param>
/// <param name="OwnId">The id its object holds, which the game's mark carries; the editor leaves it unlike the place for some.</param>
/// <param name="Name">Its name in the editor, which the build reads flags from and never writes.</param>
/// <param name="Trigger">How it starts by itself: 0 never, 1 autorun, 2 parallel.</param>
/// <param name="SwitchId">The switch it starts by itself on.</param>
/// <param name="List">Its commands as the file holds them.</param>
internal sealed record SourceCommon(int Id, int OwnId, string Name, int Trigger, int SwitchId, IReadOnlyList<RawCommand> List);

/// <summary>
/// An enemy of a troop.
/// </summary>
/// <param name="EnemyId">The enemy.</param>
/// <param name="X">Where it stands across.</param>
/// <param name="Y">Where it stands down.</param>
/// <param name="Hidden">Whether it appears only later.</param>
internal readonly record struct SourceMember(int EnemyId, int X, int Y, bool Hidden);

/// <summary>
/// The conditions of a troop's battle event page.
/// </summary>
/// <param name="TurnEnding">Whether it waits for the turn's end.</param>
/// <param name="TurnValid">Whether it checks the turn.</param>
/// <param name="TurnA">The turn's first number.</param>
/// <param name="TurnB">The turn's repeat.</param>
/// <param name="EnemyValid">Whether it checks an enemy's HP.</param>
/// <param name="EnemyIndex">The enemy's place in the troop.</param>
/// <param name="EnemyHp">The enemy's HP percent at most.</param>
/// <param name="ActorValid">Whether it checks an actor's HP.</param>
/// <param name="ActorId">The actor.</param>
/// <param name="ActorHp">The actor's HP percent at most.</param>
/// <param name="SwitchValid">Whether it checks a switch.</param>
/// <param name="SwitchId">The switch that must be on.</param>
internal sealed record SourceTroopCondition(
    bool TurnEnding,
    bool TurnValid,
    int TurnA,
    int TurnB,
    bool EnemyValid,
    int EnemyIndex,
    int EnemyHp,
    bool ActorValid,
    int ActorId,
    int ActorHp,
    bool SwitchValid,
    int SwitchId)
{
    /// <summary>
    /// The conditions of a page that checks nothing.
    /// </summary>
    public static readonly SourceTroopCondition None = new(false, false, 0, 0, false, 0, 0, false, 0, 0, false, 0);
}

/// <summary>
/// A troop's battle event page.
/// </summary>
/// <param name="Condition">When it runs.</param>
/// <param name="Span">How often it runs: 0 once per battle, 1 per turn, 2 per moment.</param>
/// <param name="List">Its commands.</param>
internal sealed record SourceTroopPage(SourceTroopCondition Condition, int Span, IReadOnlyList<RawCommand> List);

/// <summary>
/// A troop with its enemies and battle event pages.
/// </summary>
/// <param name="Id">Its id: its place in the file's list, by which the game finds it.</param>
/// <param name="Members">Its enemies, in order.</param>
/// <param name="Pages">Its battle event pages, in order.</param>
internal sealed record SourceTroop(int Id, IReadOnlyList<SourceMember> Members, IReadOnlyList<SourceTroopPage> Pages);

/// <summary>
/// An entry of a named part of the database, such as an actor or an item: whether it holds
/// anything, and the texts the build reads flags from and never writes.
/// </summary>
/// <param name="InUse">Whether it holds a note, features or effects.</param>
/// <param name="ItemType">An item's type, 2 for a key item; 0 for any other entry.</param>
/// <param name="Description">An item's, weapon's or armor's description; empty for any other entry.</param>
/// <param name="Note">Its note.</param>
/// <param name="Formula">A skill's or item's damage formula; empty for any other entry.</param>
/// <param name="ActionSwitches">The switches an enemy's actions ask to be on; none for any other entry.</param>
internal sealed record SourceEntry(bool InUse, int ItemType, string Description, string Note, string Formula, IReadOnlyList<int> ActionSwitches);

/// <summary>
/// A map as its folder's MapInfos.rvdata2 lists it.
/// </summary>
/// <param name="Name">Its name in the editor.</param>
/// <param name="ParentId">The number of the map above it in the folder, 0 for none.</param>
internal sealed record SourceMapEntry(string Name, int ParentId);
