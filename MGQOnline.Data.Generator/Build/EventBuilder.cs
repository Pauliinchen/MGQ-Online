//----------------------------------------------------------------
//  EventBuilder.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Derived the flags, the chests and the raid tables after the lists
//                            - Took the translations' names of the cutscene roots too
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Source;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// What a build is told about the game it reads.
/// </summary>
/// <param name="GameVersion">The game's version.</param>
/// <param name="Source">Which copy of the game it is.</param>
internal sealed record BuildOptions(string GameVersion = BuildOptions.DefaultGameVersion, string Source = BuildOptions.DefaultSource)
{
    /// <summary>
    /// The game's version the shipped file is made from.
    /// </summary>
    public const string DefaultGameVersion = "3.06";

    /// <summary>
    /// The copy of the game the shipped file is made from.
    /// </summary>
    public const string DefaultSource = "untranslated";
}

/// <summary>
/// Reads a game's data into the rows of its events database, in a fixed order so the same data
/// always gives the same rows: the maps' pages by map, event and page, the common events by id, the
/// troops' pages by troop and page.
/// </summary>
internal static class EventBuilder
{
    /// <summary>
    /// The generator's version, which grows with each change of what it writes.
    /// </summary>
    public const int Version = 1;

    /// <summary>
    /// The command that marks a common event, which the game puts first in every common event's list.
    /// </summary>
    public const int CommonEventMark = 999;

    /// <summary>
    /// The names of the map tree roots whose maps are cutscene maps: the untranslated game's, and
    /// those the translations give the main folder's and the one of the maps from 1000 on.
    /// </summary>
    public static readonly IReadOnlySet<string> SceneRoots = new HashSet<string>(["イベント", "Events", "Event"], System.StringComparer.Ordinal);

    /// <summary>
    /// Reads a game's data into rows.
    /// </summary>
    /// <param name="files">The game's data files.</param>
    /// <param name="options">What the build is told about the game.</param>
    /// <returns>The rows.</returns>
    public static EventRows Build(IGameDataFiles files, BuildOptions options) => Read(files, options).Rows;

    /// <summary>
    /// Reads a game's data into rows, keeping the lists read for the rules that walk them.
    /// </summary>
    /// <param name="files">The game's data files.</param>
    /// <param name="options">What the build is told about the game.</param>
    /// <returns>The rows and the game as the derived rows read it.</returns>
    public static (EventRows Rows, BuiltGame Game) Read(IGameDataFiles files, BuildOptions options)
    {
        var source = new GameSource(files);
        var rows = new EventRows(new EventBuildInfo(Version, options.GameVersion, options.Source, string.Empty, string.Empty));
        var lists = new List<BuiltList>();

        IReadOnlyList<SourceMapInfo> maps = source.ReadMapInfos();
        foreach (SourceMapInfo info in maps)
        {
            AddMap(rows, lists, info, source.ReadMap(info.Id));
        }

        IReadOnlyList<SourceCommon?> commons = source.ReadCommonEvents();
        var normalised = new List<RawCommand>?[commons.Count];
        foreach (SourceCommon common in commons.OfType<SourceCommon>())
        {
            normalised[common.Id] = Normalise(common, out int leadingMarks);
            var site = new ListRow(lists.Count + 1, ListKind.Common, null, null, null, common.Id, null, null, 0, 0, 0);
            lists.Add(ListBuild.Add(rows, site, normalised[common.Id]!, null, common.Trigger != 0 ? common.SwitchId : null));
            rows.CommonEvents.Add(new CommonEventRow(common.Id, site.ListId, common.Trigger, common.SwitchId, false, leadingMarks, false, false, false));
        }

        IReadOnlyList<SourceTroop?> troops = source.ReadTroops();
        foreach (SourceTroop troop in troops.OfType<SourceTroop>())
        {
            AddTroop(rows, lists, troop);
        }

        rows.FingerprintParts.AddRange(GameFingerprint.Parts(PartIds(source, troops, normalised, maps, out int actors)));
        BuiltGame game = DerivedBuild.Derive(rows, lists, source, commons, actors);
        rows.Counts["actors"] = actors;
        rows.Counts["switches"] = rows.Switches.Count + 1;
        rows.Counts["variables"] = rows.Variables.Count + 1;
        rows.Counts["common_slots"] = commons.Count;
        rows.Counts["troops"] = troops.Count;
        rows.Counts["maps"] = maps.Count;
        rows.Counts["events"] = rows.MapEvents.Count;
        rows.Counts["pages"] = rows.Pages.Count;
        rows.Counts["lists"] = rows.Lists.Count;
        rows.Counts["commands_all"] = rows.Lists.Sum(list => (long)list.CountAll);
        rows.Counts["commands_kept"] = rows.Commands.Count;
        rows.Build = rows.Build with { Fingerprint = GameFingerprint.Text(rows.FingerprintParts), InputHashes = source.InputHashes() };
        return (rows, game);
    }

    /// <summary>
    /// Finds the game data's fingerprint alone.
    /// </summary>
    /// <param name="files">The game's data files.</param>
    /// <returns>The fingerprint's parts.</returns>
    public static List<FingerprintPart> Fingerprint(IGameDataFiles files)
    {
        var source = new GameSource(files);
        List<RawCommand>?[] commons = [.. source.ReadCommonEvents().Select(common => common is null ? null : Normalise(common, out _))];
        return GameFingerprint.Parts(PartIds(source, source.ReadTroops(), commons, source.ReadMapInfos(), out _));
    }

    /// <summary>
    /// Puts a common event's list in the form the game runs it in: the game's database analysis
    /// (145 - Module.rb) drops the marks the list starts with and puts one mark with the id the
    /// event's object holds first.
    /// </summary>
    /// <param name="common">The common event as the file holds it.</param>
    /// <param name="leadingMarks">How many marks the file's list started with.</param>
    /// <returns>The list the game runs.</returns>
    public static List<RawCommand> Normalise(SourceCommon common, out int leadingMarks)
    {
        leadingMarks = common.List.TakeWhile(command => command.Code == CommonEventMark).Count();
        return [new RawCommand(CommonEventMark, 0, [new RubyInteger(common.OwnId)]), .. common.List.Skip(leadingMarks)];
    }

    /// <summary>
    /// Lists the ids that exist of each part of the fingerprint, as world.rbx's <c>ids</c> does in the
    /// running game: after the common events got their marks and the skills the two the game appends.
    /// </summary>
    /// <param name="source">The game's data, which the named parts are read from.</param>
    /// <param name="troops">The troops.</param>
    /// <param name="commons">The common events' lists as the game runs them.</param>
    /// <param name="maps">The maps.</param>
    /// <param name="actors">How many entries the actors' list holds, its empty first one included.</param>
    /// <returns>The ids, per part in the fingerprint's order.</returns>
    private static List<IReadOnlyList<int>> PartIds(
        GameSource source,
        IReadOnlyList<SourceTroop?> troops,
        IReadOnlyList<List<RawCommand>?> commons,
        IReadOnlyList<SourceMapInfo> maps,
        out int actors)
    {
        actors = 0;
        var ids = new List<IReadOnlyList<int>>();
        foreach ((string part, string path) in GameSource.NamedParts)
        {
            IReadOnlyList<bool?> named = source.ReadNamed(path);
            actors = part == "actors" ? named.Count : actors;
            if (part == "skills")
            {
                named = [.. named, .. Enumerable.Repeat((bool?)false, GameFingerprint.AppendedSkills)];
            }

            ids.Add(GameFingerprint.Existing(named, hasName => hasName == true));
        }

        ids.Add(GameFingerprint.Existing(troops, troop => troop.Members.Count > 0));
        ids.Add(GameFingerprint.Existing(commons, list => list.Count > 1));
        ids.Add([.. maps.Select(map => map.Id)]);
        return ids;
    }

    /// <summary>
    /// Adds a map's rows: the map, its encounters, its events and their pages' lists.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="lists">The lists read so far, which the pages' lists are added to.</param>
    /// <param name="info">The map as the map lists name it.</param>
    /// <param name="map">Its file, <see langword="null"/> for a map without one.</param>
    private static void AddMap(EventRows rows, List<BuiltList> lists, SourceMapInfo info, SourceMap? map)
    {
        rows.Maps.Add(new MapRow(info.Id, info.Folder, info.Number, info.ParentId, map?.TilesetId ?? 0, map is not null, SceneRoots.Contains(info.RootName)));
        if (map is null)
        {
            return;
        }

        for (int ord = 0; ord < map.Encounters.Count; ord++)
        {
            rows.MapEncounters.Add(new MapEncounterRow(info.Id, ord, map.Encounters[ord].TroopId, map.Encounters[ord].Weight));
        }

        foreach ((int eventId, SourceEvent mapEvent) in map.Events)
        {
            rows.MapEvents.Add(new MapEventRow(info.Id, eventId, mapEvent.X, mapEvent.Y, mapEvent.Pages.Count));
            for (int pageNo = 0; pageNo < mapEvent.Pages.Count; pageNo++)
            {
                SourcePage page = mapEvent.Pages[pageNo];
                SourceCondition condition = page.Condition;
                var site = new ListRow(lists.Count + 1, ListKind.Page, info.Id, eventId, pageNo, null, null, null, 0, 0, 0);
                lists.Add(ListBuild.Add(rows, site, page.List, condition.ForRules, null));
                rows.Pages.Add(new PageRow(
                    site.ListId,
                    info.Id,
                    eventId,
                    pageNo,
                    page.Trigger,
                    condition.Switch1,
                    condition.Switch2,
                    condition.Variable,
                    condition.VariableValue,
                    condition.SelfSwitch,
                    condition.Item,
                    condition.Actor,
                    page.MoveType,
                    null,
                    null,
                    false,
                    false,
                    false,
                    null));
            }
        }
    }

    /// <summary>
    /// Adds a troop's rows: the troop, its enemies and its pages' lists.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="lists">The lists read so far, which the pages' lists are added to.</param>
    /// <param name="troop">The troop.</param>
    private static void AddTroop(EventRows rows, List<BuiltList> lists, SourceTroop troop)
    {
        rows.Troops.Add(new TroopRow(troop.Id, troop.Members.Count, troop.Pages.Count));
        for (int position = 0; position < troop.Members.Count; position++)
        {
            SourceMember member = troop.Members[position];
            rows.TroopMembers.Add(new TroopMemberRow(troop.Id, position, member.EnemyId, member.X, member.Y, member.Hidden));
        }

        for (int pageNo = 0; pageNo < troop.Pages.Count; pageNo++)
        {
            SourceTroopPage page = troop.Pages[pageNo];
            SourceTroopCondition condition = page.Condition;
            var site = new ListRow(lists.Count + 1, ListKind.TroopPage, null, null, null, null, troop.Id, pageNo, 0, 0, 0);
            PageCondition? reads = condition.SwitchValid ? new PageCondition(condition.SwitchId, null, null, 0, null) : null;
            lists.Add(ListBuild.Add(rows, site, page.List, reads, null));
            rows.TroopPages.Add(new TroopPageRow(
                site.ListId,
                troop.Id,
                pageNo,
                page.Span,
                condition.TurnEnding,
                condition.TurnValid,
                condition.TurnA,
                condition.TurnB,
                condition.EnemyValid,
                condition.EnemyIndex,
                condition.EnemyHp,
                condition.ActorValid,
                condition.ActorId,
                condition.ActorHp,
                condition.SwitchValid,
                condition.SwitchId));
        }
    }
}
