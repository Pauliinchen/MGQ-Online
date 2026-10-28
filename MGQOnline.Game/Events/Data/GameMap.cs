//----------------------------------------------------------------
//  GameMap.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Told the scratch switches and variables by their names
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// A map's events, as its MapNNN.rvdata2 holds them.
/// </summary>
/// <param name="Id">The map's id, from 1000 on for the maps of the Data/Map folders.</param>
/// <param name="Events">Its events by id.</param>
public sealed record GameMap(int Id, IReadOnlyDictionary<int, MapEvent> Events);

/// <summary>
/// One event of a map with its pages.
/// </summary>
/// <param name="Id">The event's id on its map.</param>
/// <param name="Name">Its name in the editor, such as "EV012".</param>
/// <param name="Pages">Its pages, in the editor's order; the game shows the last whose conditions hold.</param>
public sealed record MapEvent(int Id, string Name, IReadOnlyList<EventPage> Pages);

/// <summary>
/// A common event of CommonEvents.rvdata2.
/// </summary>
/// <param name="Id">Its id.</param>
/// <param name="Name">Its name in the editor.</param>
/// <param name="Trigger">How it starts by itself: 0 never, 1 autorun, 2 parallel, each while <paramref name="SwitchId"/> is on.</param>
/// <param name="SwitchId">The switch it starts by itself on.</param>
/// <param name="List">Its commands.</param>
public sealed record CommonEvent(int Id, string Name, int Trigger, int SwitchId, IReadOnlyList<EventCommand> List);

/// <summary>
/// A troop of Troops.rvdata2 with its battle event pages.
/// </summary>
/// <param name="Id">Its id.</param>
/// <param name="Name">Its name in the editor.</param>
/// <param name="Pages">The commands of each of its battle event pages.</param>
public sealed record Troop(int Id, string Name, IReadOnlyList<IReadOnlyList<EventCommand>> Pages);

/// <summary>
/// A map as MapInfos.rvdata2 lists it.
/// </summary>
/// <param name="Id">The map's id, from 1000 on for the maps of the Data/Map folders.</param>
/// <param name="Name">Its name in the editor.</param>
/// <param name="ParentId">The map above it in the editor's tree, 0 for none.</param>
public sealed record MapInfo(int Id, string Name, int ParentId);

/// <summary>
/// The names System.rvdata2 gives the switches and variables, by id; index 0 is empty, as in the game.
/// </summary>
/// <param name="Switches">The switch names.</param>
/// <param name="Variables">The variable names.</param>
public sealed partial record GameSystemNames(IReadOnlyList<string> Switches, IReadOnlyList<string> Variables)
{
    /// <summary>
    /// Gets a switch's name.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Its name, empty for one the game does not name.</returns>
    public string Switch(long id) => id >= 0 && id < Switches.Count ? Switches[(int)id] : string.Empty;

    /// <summary>
    /// Gets a variable's name.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its name, empty for one the game does not name.</returns>
    public string Variable(long id) => id >= 0 && id < Variables.Count ? Variables[(int)id] : string.Empty;

    /// <summary>
    /// Reports whether a switch's name marks it as scratch the game uses while an event runs.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it does.</returns>
    public bool IsScratchSwitch(long id) => ScratchName().IsMatch(Switch(id));

    /// <summary>
    /// Reports whether a variable's name marks it as scratch the game uses while an event runs.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Whether it does.</returns>
    public bool IsScratchVariable(long id) => ScratchName().IsMatch(Variable(id));

    /// <summary>
    /// Names of switches and variables the game uses as scratch, in the translation's words and the
    /// untranslated game's.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("general|temp|system only|汎用|一時", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex ScratchName();
}
