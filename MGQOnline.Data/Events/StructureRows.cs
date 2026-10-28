//----------------------------------------------------------------
//  StructureRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Data.Events;

/// <summary>
/// What a list of event commands belongs to.
/// </summary>
public enum ListKind
{
    /// <summary>A page of a map event.</summary>
    Page = 0,

    /// <summary>A common event.</summary>
    Common = 1,

    /// <summary>A page of a troop's battle events.</summary>
    TroopPage = 2,
}

/// <summary>
/// A map of the game (table maps).
/// </summary>
/// <param name="Id">The map's id, a thousand per map folder.</param>
/// <param name="Folder">Its map folder, 0 for the first.</param>
/// <param name="Number">Its number inside the folder.</param>
/// <param name="ParentId">The map above it in the editor's tree, 0 for none.</param>
/// <param name="TilesetId">Its tileset.</param>
/// <param name="HasFile">Whether the game has its map file.</param>
/// <param name="Cutscene">Whether it hangs under the folder's tree of scene maps.</param>
public readonly record struct MapRow(int Id, int Folder, int Number, int ParentId, int TilesetId, bool HasFile, bool Cutscene);

/// <summary>
/// A troop a map's random encounters may meet (table map_encounters).
/// </summary>
/// <param name="MapId">The map.</param>
/// <param name="Ord">The encounter's place in the map's list.</param>
/// <param name="TroopId">The troop.</param>
/// <param name="Weight">How often it comes against the others.</param>
public readonly record struct MapEncounterRow(int MapId, int Ord, int TroopId, int Weight);

/// <summary>
/// An event of a map (table map_events).
/// </summary>
/// <param name="MapId">The map.</param>
/// <param name="EventId">The event.</param>
/// <param name="X">Where it starts across.</param>
/// <param name="Y">Where it starts down.</param>
/// <param name="PageCount">How many pages it has.</param>
public readonly record struct MapEventRow(int MapId, int EventId, int X, int Y, int PageCount);

/// <summary>
/// One list of event commands: a map event's page, a common event or a troop's page (table lists).
/// </summary>
/// <param name="ListId">The list's id, given in a fixed order: map pages, common events, troop pages.</param>
/// <param name="Kind">What it belongs to.</param>
/// <param name="MapId">The map of a page, else <see langword="null"/>.</param>
/// <param name="EventId">The event of a page, else <see langword="null"/>.</param>
/// <param name="PageNo">The page's place from 0, else <see langword="null"/>.</param>
/// <param name="CommonId">The common event, else <see langword="null"/>.</param>
/// <param name="TroopId">The troop of a troop page, else <see langword="null"/>.</param>
/// <param name="TroopPageNo">The troop page's place from 0, else <see langword="null"/>.</param>
/// <param name="CountAll">How many commands the game runs, text lines and the closing command included.</param>
/// <param name="CountKept">How many of them the database keeps.</param>
/// <param name="Shape">The <see cref="ListShape"/> of the kept commands.</param>
public readonly record struct ListRow(
    int ListId,
    ListKind Kind,
    int? MapId,
    int? EventId,
    int? PageNo,
    int? CommonId,
    int? TroopId,
    int? TroopPageNo,
    int CountAll,
    int CountKept,
    int Shape);

/// <summary>
/// A page of a map event: when it shows, how it starts and what the generator found in it (table pages).
/// </summary>
/// <param name="ListId">Its list.</param>
/// <param name="MapId">The map.</param>
/// <param name="EventId">The event.</param>
/// <param name="PageNo">The page's place, from 0.</param>
/// <param name="Trigger">How it starts: 0 action button, 1 player touch, 2 event touch, 3 autorun, 4 parallel.</param>
/// <param name="CondSwitch1">The first switch that must be on, <see langword="null"/> for none.</param>
/// <param name="CondSwitch2">The second switch that must be on, <see langword="null"/> for none.</param>
/// <param name="CondVariable">The variable that must be at least <paramref name="CondValue"/>, <see langword="null"/> for none.</param>
/// <param name="CondValue">The least value of <paramref name="CondVariable"/>.</param>
/// <param name="CondSelfSwitch">The self switch that must be on, such as "A", <see langword="null"/> for none.</param>
/// <param name="CondItem">The item the party must hold, <see langword="null"/> for none.</param>
/// <param name="CondActor">The actor who must be in the party, <see langword="null"/> for none.</param>
/// <param name="MoveType">How the event moves by itself.</param>
/// <param name="KindNewGame">How the sorter sorts the page in a new game, by MGQOnline.Game's EventKind; <see langword="null"/> before it is derived.</param>
/// <param name="ChestLetter">The self switch a chest page turns on, else <see langword="null"/>.</param>
/// <param name="ScenePage">Whether a scene switch is among its conditions.</param>
/// <param name="RunsNothing">Whether it runs only commands that change nothing.</param>
/// <param name="HasFadeIn">Whether it fades the screen in.</param>
/// <param name="SetsEncounters">Whether it turns random encounters on (<see langword="true"/>) or off; <see langword="null"/> when it leaves them.</param>
public readonly record struct PageRow(
    int ListId,
    int MapId,
    int EventId,
    int PageNo,
    int Trigger,
    int? CondSwitch1,
    int? CondSwitch2,
    int? CondVariable,
    long CondValue,
    string? CondSelfSwitch,
    int? CondItem,
    int? CondActor,
    int MoveType,
    int? KindNewGame,
    string? ChestLetter,
    bool ScenePage,
    bool RunsNothing,
    bool HasFadeIn,
    bool? SetsEncounters);

/// <summary>
/// A common event (table common_events).
/// </summary>
/// <param name="Id">The common event.</param>
/// <param name="ListId">Its list.</param>
/// <param name="Trigger">How it starts: 0 by a call, 1 autorun, 2 parallel.</param>
/// <param name="SwitchId">The switch that starts it, 0 for none.</param>
/// <param name="Own">Whether every player runs it as their own.</param>
/// <param name="LeadingMarks">How many marks the game's file had before the one the game puts first.</param>
/// <param name="Battlefuck">Whether it is a battlefuck.</param>
/// <param name="FinalChapter">Whether it belongs to the Final Chapter.</param>
/// <param name="FadesIn">Whether it fades the screen in.</param>
public readonly record struct CommonEventRow(
    int Id,
    int ListId,
    int Trigger,
    int SwitchId,
    bool Own,
    int LeadingMarks,
    bool Battlefuck,
    bool FinalChapter,
    bool FadesIn);

/// <summary>
/// A troop (table troops).
/// </summary>
/// <param name="Id">The troop.</param>
/// <param name="MemberCount">How many enemies it holds.</param>
/// <param name="PageCount">How many battle event pages it has.</param>
public readonly record struct TroopRow(int Id, int MemberCount, int PageCount);

/// <summary>
/// An enemy of a troop (table troop_members).
/// </summary>
/// <param name="TroopId">The troop.</param>
/// <param name="Position">The member's place, from 0.</param>
/// <param name="EnemyId">The enemy.</param>
/// <param name="X">Where it stands across.</param>
/// <param name="Y">Where it stands down.</param>
/// <param name="Hidden">Whether it appears only later.</param>
public readonly record struct TroopMemberRow(int TroopId, int Position, int EnemyId, int X, int Y, bool Hidden);

/// <summary>
/// A page of a troop's battle events with its conditions (table troop_pages).
/// </summary>
/// <param name="ListId">Its list.</param>
/// <param name="TroopId">The troop.</param>
/// <param name="PageNo">The page's place, from 0.</param>
/// <param name="Span">How often it runs: 0 once per battle, 1 per turn, 2 per moment.</param>
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
public readonly record struct TroopPageRow(
    int ListId,
    int TroopId,
    int PageNo,
    int Span,
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
    int SwitchId);

/// <summary>
/// One kept command of a list, numbers only (table commands).
/// </summary>
/// <param name="ListId">Its list.</param>
/// <param name="Ord">Its place among the list's kept commands, which a translation leaves.</param>
/// <param name="Idx">Its place in the list the game runs.</param>
/// <param name="Code">Its code.</param>
/// <param name="Indent">How deep in branches it stands.</param>
/// <param name="P0">Its first number: a self switch's letter as 1 to 4, a label as a number unique in its list, a jump as the <paramref name="Ord"/> of its label (-1 for none).</param>
/// <param name="P1">Its second number.</param>
/// <param name="P2">Its third number.</param>
/// <param name="P3">Its fourth number.</param>
/// <param name="P4">Its fifth number.</param>
/// <param name="P5">Its sixth number.</param>
/// <param name="TextKind">What a script does, by MGQOnline.Game's TextKind: 0 none, 1 talk, 2 travel, 3 choice, 4 novel, 5 other.</param>
public readonly record struct CommandRow(
    int ListId,
    int Ord,
    int Idx,
    int Code,
    int Indent,
    long P0,
    long P1,
    long P2,
    long P3,
    long P4,
    long P5,
    int TextKind)
{
    /// <summary>
    /// Reads a number by its place.
    /// </summary>
    /// <param name="index">The place, from 0.</param>
    /// <returns>The number, 0 past the sixth.</returns>
    public long Number(int index) => index switch
    {
        0 => P0,
        1 => P1,
        2 => P2,
        3 => P3,
        4 => P4,
        5 => P5,
        _ => 0,
    };
}
