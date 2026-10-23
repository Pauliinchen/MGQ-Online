//----------------------------------------------------------------
//  EventSorterTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Checked that a page calling a battlefuck event is the player's own
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the event sorter against the golden cases of coop_events.rbx: every list its tests
/// sorted, and a few hundred of the game's pages and common events in two states.
/// </summary>
public sealed class EventSorterTests
{
    /// <summary>
    /// Asserts that every list the script tests sorted sorts as the scripts' sorter did.
    /// </summary>
    [Fact]
    public void ScriptCases_SortAsTheScriptsDid()
    {
        var mismatches = new List<string>();
        IReadOnlyList<JsonElement> cases = SorterCases.Read("script_cases.json");
        foreach ((JsonElement found, int index) in cases.Select((found, index) => (found, index)))
        {
            Dictionary<long, EventCommand[]> commons = SorterCases.CommonsOf(found);
            var sorter = new EventSorter(id => commons.GetValueOrDefault(id), SorterCases.NamesOf(found));
            string answer = SorterCases.Answer(sorter, found, SorterCases.CommandsOf(found.GetProperty("list")));
            if (answer != SorterCases.Expected(found))
            {
                mismatches.Add($"case {index}: {answer} (expected {SorterCases.Expected(found)})");
            }
        }

        Assert.True(cases.Count > 50);
        Assert.Empty(mismatches);
    }

    /// <summary>
    /// Asserts that a page that can now call a battlefuck event is the player's own, though it moves
    /// the story on, while a quest page whose battlefuck waits in another step's branch stays story.
    /// </summary>
    [Fact]
    public void KindOf_SortsAPageThatCallsABattlefuckAsThePlayersOwn()
    {
        var sorter = new EventSorter(_ => null, new GameSystemNames([], []));
        var state = new QuietState();
        EventCommand[] battlefuck = [Command(EventCodes.ShowText, 0, "", 0, 0, 2), Command(EventCodes.ControlSwitches, 0, 60, 60, 0), Command(EventCodes.CallCommonEvent, 0, 7001)];
        EventCommand[] other = [Command(EventCodes.CallCommonEvent, 0, 6998), Command(EventCodes.ControlSwitches, 0, 60, 60, 0)];
        EventCommand[] questStep =
        [
            Command(EventCodes.Branch, 0, 1, 1028, 0, 4, 0), Command(EventCodes.CallCommonEvent, 1, 7001), Command(0, 1), Command(EventCodes.BranchEnd, 0),
            Command(EventCodes.ShowText, 0, "", 0, 0, 2), Command(EventCodes.ControlVariables, 0, 1028, 1028, 0, 0, 6),
        ];

        Assert.Equal(EventKind.Own, sorter.KindOf(battlefuck, state));
        Assert.Equal(EventKind.Story, sorter.KindOf(other, state));
        Assert.Equal(EventKind.Story, sorter.KindOf(questStep, state));
    }

    /// <summary>
    /// Asserts that the game's pages and common events sort as the scripts' sorter did, of those
    /// whose commands the game folder holds as the recording's did.
    /// </summary>
    [Fact]
    public void GameCases_SortAsTheScriptsDid()
    {
        GameData data = GameFolder.DataOrSkip();
        var sorter = new EventSorter(id => data.CommonEvent(id)?.List, data.System);
        var maps = new Dictionary<int, GameMap?>();
        var mismatches = new List<string>();
        int compared = 0;
        foreach (JsonElement found in SorterCases.Read("game_cases.json"))
        {
            string site = found.GetProperty("site").GetString()!;
            if (ListOf(data, maps, site) is not { } list || ShapeOf(data, list, found) != found.GetProperty("shape").GetString())
            {
                continue;
            }

            compared++;
            string answer = SorterCases.Answer(sorter, found, list);
            if (answer != SorterCases.Expected(found))
            {
                mismatches.Add($"{site} ({found.GetProperty("state").GetString()}): {answer} (expected {SorterCases.Expected(found)})");
            }
        }

        Assert.True(compared > 0, "no case's commands match the game folder's");
        Assert.Empty(mismatches);
    }

    /// <summary>
    /// Makes a command of plain parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">The parameters, numbers and texts.</param>
    /// <returns>The command.</returns>
    private static EventCommand Command(int code, int indent, params object[] parameters) =>
        new(code, indent, new RubyArray(parameters.Select(parameter => parameter is string text ? (RubyValue)text : (RubyValue)(long)(int)parameter)));

    /// <summary>
    /// Finds the commands of a site.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="maps">The maps read so far.</param>
    /// <param name="site">"map:&lt;map&gt;:&lt;event&gt;:&lt;page&gt;", pages from 1, or "ce:&lt;id&gt;".</param>
    /// <returns>The commands, <see langword="null"/> when the folder lacks them.</returns>
    private static IReadOnlyList<EventCommand>? ListOf(GameData data, Dictionary<int, GameMap?> maps, string site)
    {
        string[] parts = site.Split(':');
        if (parts[0] == "ce")
        {
            return data.CommonEvent(long.Parse(parts[1], CultureInfo.InvariantCulture))?.List;
        }

        int mapId = int.Parse(parts[1], CultureInfo.InvariantCulture);
        if (!maps.TryGetValue(mapId, out GameMap? map))
        {
            maps[mapId] = map = data.ReadMap(mapId);
        }

        int page = int.Parse(parts[3], CultureInfo.InvariantCulture) - 1;
        return map is not null && map.Events.TryGetValue(int.Parse(parts[2], CultureInfo.InvariantCulture), out MapEvent? mapEvent) && page < mapEvent.Pages.Count
            ? mapEvent.Pages[page].List
            : null;
    }

    /// <summary>
    /// Live values that hold nothing: every switch off, every variable 0, nothing personal.
    /// </summary>
    private sealed class QuietState : IEventState
    {
        /// <inheritdoc />
        public bool Switch(long id) => false;

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;
    }

    /// <summary>
    /// Finds the shape of a case's commands as the recording wrote it: each code and indent of the
    /// list and of the common events it followed.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="list">The list.</param>
    /// <param name="found">The case.</param>
    /// <returns>The shape's hash, its first 16 hexadecimal digits.</returns>
    private static string ShapeOf(GameData data, IReadOnlyList<EventCommand> list, JsonElement found)
    {
        IEnumerable<string> commons = Ids(found, "commons").Select(id => FormattableString.Invariant($"{id}={Shape(data.CommonEvent(id)?.List ?? [])}"));
        IEnumerable<string> names = Ids(found, "named_s").Select(id => FormattableString.Invariant($"s{id}={data.System.Switch(id)}"))
            .Concat(Ids(found, "named_v").Select(id => FormattableString.Invariant($"v{id}={data.System.Variable(id)}")));
        byte[] hash = SHA256.HashData(Encoding.UTF8.GetBytes(Shape(list) + "|" + string.Join("|", commons) + "|" + string.Join("|", names)));
        return Convert.ToHexStringLower(hash)[..16];
    }

    /// <summary>
    /// Reads a list of ids of a case.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <param name="field">The list's field.</param>
    /// <returns>The ids, none where the case has no such list.</returns>
    private static IEnumerable<long> Ids(JsonElement found, string field) =>
        found.TryGetProperty(field, out JsonElement ids) ? ids.EnumerateArray().Select(id => id.GetInt64()) : [];

    /// <summary>
    /// Writes each code and indent of commands.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>Such as "101:0,401:0,0:0".</returns>
    private static string Shape(IReadOnlyList<EventCommand> list) =>
        string.Join(",", list.Select(command => FormattableString.Invariant($"{command.Code}:{command.Indent}")));
}
