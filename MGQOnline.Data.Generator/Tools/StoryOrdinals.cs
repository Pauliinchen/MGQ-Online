//----------------------------------------------------------------
//  StoryOrdinals.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// Rewrites the <c>index</c> of the relay's catch-up rows (joins and removals) from a command's place
/// in a copy of the game's list into its <c>ord</c> in the events database, the place among the list's
/// kept commands, which a translation leaves. The place is the one in the game's data file, so a
/// common event's counts the marks the file had before the one the game puts first; a script's
/// continuation line stands for its script, the command the database keeps. A command is matched by
/// its code and first two numbers, as the nth such command of its list.
/// </summary>
/// <remarks>
/// Rows of one companion never share a script, so a continuation line read as its script orders
/// every join and removal as before.
/// </remarks>
internal static partial class StoryOrdinals
{
    /// <summary>
    /// The code of a script command, whose continuation lines the database folds into it.
    /// </summary>
    private const int ScriptCode = 355;

    /// <summary>
    /// The settings that write a batch's rows as the relay's seed files hold them, texts unescaped.
    /// </summary>
    private static readonly JsonSerializerOptions BatchJson = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// Rewrites the rows of a seed file, a list of admin edits one a line, leaving every line but its
    /// index as it was.
    /// </summary>
    /// <param name="text">The seed file.</param>
    /// <param name="copy">The rows built from the copy of the game the indexes were read from.</param>
    /// <param name="database">The events database.</param>
    /// <param name="unresolved">Takes a line for each row whose command was not found, which keeps its index.</param>
    /// <returns>The seed file with the indexes rewritten.</returns>
    public static string RewriteSeed(string text, EventRows copy, EventStore database, List<string> unresolved)
    {
        var lists = new CopyLists(copy);
        var lines = text.Split('\n');
        for (int line = 0; line < lines.Length; line++)
        {
            string trimmed = lines[line].Trim().TrimEnd(',');
            if (!trimmed.StartsWith('{') || JsonNode.Parse(trimmed)?["row"] is not JsonObject row || row["index"] is null)
            {
                continue;
            }

            if (OrdOfRow(row, lists, database, unresolved) is { } ord)
            {
                lines[line] = IndexField().Replace(lines[line], string.Create(CultureInfo.InvariantCulture, $"\"index\":{ord}"), 1);
            }
        }

        return string.Join('\n', lines);
    }

    /// <summary>
    /// Writes the batch that rewrites a table's rows as the relay's admin route lists them
    /// (<c>GET /v1/admin/story/&lt;table&gt;</c>), for <c>POST /v1/admin/story/edit</c>: a change of each
    /// row whose index moves, at the listing's revision.
    /// </summary>
    /// <param name="listing">The admin route's answer: <c>rev</c>, <c>table</c> and <c>rows</c>, each with <c>id</c> and <c>row</c>.</param>
    /// <param name="copy">The rows built from the copy of the game the indexes were read from.</param>
    /// <param name="database">The events database.</param>
    /// <param name="unresolved">Takes a line for each row whose command was not found, which the batch leaves out.</param>
    /// <returns>The batch, its edits one a line.</returns>
    /// <exception cref="FormatException">The listing is not one of the admin route.</exception>
    public static string Batch(string listing, EventRows copy, EventStore database, List<string> unresolved)
    {
        JsonObject answer = JsonNode.Parse(listing) as JsonObject ?? throw new FormatException("the listing is no JSON object");
        string table = answer["table"]?.GetValue<string>() ?? throw new FormatException("the listing names no table");
        var lists = new CopyLists(copy);
        var edits = new List<string>();
        foreach (JsonNode? entry in answer["rows"] as JsonArray ?? throw new FormatException("the listing holds no rows"))
        {
            if (entry?["row"] is not JsonObject row || entry["id"] is not { } id || OrdOfRow(row, lists, database, unresolved) is not { } ord || ord == row["index"]!.GetValue<int>())
            {
                continue;
            }

            JsonObject changed = row.DeepClone().AsObject();
            changed["index"] = ord;
            var edit = new JsonObject { ["table"] = table, ["op"] = "change", ["id"] = id.DeepClone(), ["row"] = changed };
            edits.Add("    " + edit.ToJsonString(BatchJson));
        }

        var batch = new StringBuilder();
        batch.Append(CultureInfo.InvariantCulture, $"{{\n  \"rev\": {answer["rev"]?.ToJsonString() ?? "null"},\n  \"edits\": [\n");
        batch.Append(string.Join(",\n", edits));
        batch.Append("\n  ]\n}\n");
        return batch.ToString();
    }

    /// <summary>
    /// Finds the ord of the command a row names.
    /// </summary>
    /// <param name="row">The row: <c>site</c> and <c>index</c>.</param>
    /// <param name="copy">The copy's lists.</param>
    /// <param name="database">The events database.</param>
    /// <param name="unresolved">Takes a line when the command is not found.</param>
    /// <returns>The ord, <see langword="null"/> when not found.</returns>
    private static int? OrdOfRow(JsonObject row, CopyLists copy, EventStore database, List<string> unresolved)
    {
        string site = row["site"]?.GetValue<string>() ?? "";
        int index = row["index"]!.GetValue<int>();
        int? ord = SiteOf(site) is { } named && copy.Commands(named) is { } copied && DatabaseCommands(database, named) is { } stored
            ? OrdOf(copied, stored, index + copy.PlaceShift(named))
            : null;
        if (ord is null)
        {
            unresolved.Add(string.Create(CultureInfo.InvariantCulture, $"{site} #{index}: no such command in both copies"));
        }

        return ord;
    }

    /// <summary>
    /// Finds the database's ord of the command at a place of a copy's list, or of the script whose
    /// continuation line stands there: the nth command of the database's list with its code and first
    /// two numbers, as it is the nth such of the copy's.
    /// </summary>
    /// <param name="copy">The copy's kept commands of the list, in order.</param>
    /// <param name="database">The database's kept commands of the list, in order.</param>
    /// <param name="index">The place in the list the copy runs.</param>
    /// <returns>The ord, <see langword="null"/> when the copy keeps no command there or the database has no such.</returns>
    public static int? OrdOf(IReadOnlyList<CommandRow> copy, IReadOnlyList<CommandRow> database, int index)
    {
        int at = Enumerable.Range(0, copy.Count).LastOrDefault(place => copy[place].Idx <= index, -1);
        if (at < 0 || (copy[at].Idx != index && copy[at].Code != ScriptCode))
        {
            return null;
        }

        CommandRow command = copy[at];
        int nth = copy.Take(at).Count(other => Same(other, command));
        CommandRow[] matches = [.. database.Where(other => Same(other, command))];
        return nth < matches.Length ? matches[nth].Ord : null;
    }

    /// <summary>
    /// Tells whether two commands are the same kind: code and first two numbers.
    /// </summary>
    /// <param name="one">One.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether they are.</returns>
    private static bool Same(CommandRow one, CommandRow other) => one.Code == other.Code && one.P0 == other.P0 && one.P1 == other.P1;

    /// <summary>
    /// Reads a row's site.
    /// </summary>
    /// <param name="site">Such as "map:7:60:1" (the page from 1) or "ce:9141".</param>
    /// <returns>The map, event and page from 0, or the common event; <see langword="null"/> for another site.</returns>
    private static (int Map, int Event, int Page, int Common)? SiteOf(string site)
    {
        string[] parts = site.Split(':');
        return parts switch
        {
            ["map", string map, string eventId, string page] when int.TryParse(map, CultureInfo.InvariantCulture, out int m) && int.TryParse(eventId, CultureInfo.InvariantCulture, out int e) && int.TryParse(page, CultureInfo.InvariantCulture, out int p) && p > 0 => (m, e, p - 1, 0),
            ["ce", string common] when int.TryParse(common, CultureInfo.InvariantCulture, out int c) => (0, 0, 0, c),
            _ => null,
        };
    }

    /// <summary>
    /// Reads a site's kept commands from the database.
    /// </summary>
    /// <param name="database">The database.</param>
    /// <param name="site">The site, see <see cref="SiteOf"/>.</param>
    /// <returns>The commands, <see langword="null"/> for a list it lacks.</returns>
    private static IReadOnlyList<CommandRow>? DatabaseCommands(EventStore database, (int Map, int Event, int Page, int Common) site)
    {
        ListRow? list = site.Common > 0 ? database.CommonList(site.Common) : database.ListOf(site.Map, site.Event, site.Page);
        return list is { } found ? database.Commands(found.ListId) : null;
    }

    /// <summary>
    /// Finds a row's index field.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\"index\":\\d+")]
    private static partial Regex IndexField();

    /// <summary>
    /// The kept commands of a copy's lists, by site.
    /// </summary>
    /// <param name="rows">The copy's rows.</param>
    private sealed class CopyLists(EventRows rows)
    {
        /// <summary>
        /// The lists by site.
        /// </summary>
        private readonly Dictionary<(int Map, int Event, int Page, int Common), int> _lists = rows.Lists
            .Where(list => list.Kind != ListKind.TroopPage)
            .ToDictionary(list => (list.MapId ?? 0, list.EventId ?? 0, list.PageNo ?? 0, list.CommonId ?? 0), list => list.ListId);

        /// <summary>
        /// The kept commands by list, in order.
        /// </summary>
        private readonly ILookup<int, CommandRow> _commands = rows.Commands.OrderBy(command => command.Ord).ToLookup(command => command.ListId);

        /// <summary>
        /// How many marks each common event's file had before the one the game puts first, by id.
        /// </summary>
        private readonly Dictionary<int, int> _leadingMarks = rows.CommonEvents.ToDictionary(common => common.Id, common => common.LeadingMarks);

        /// <summary>
        /// Tells what turns a place in a site's list in the game's data file into the place in the list
        /// the game runs: a common event's list loses the marks its file had and starts with one of its own.
        /// </summary>
        /// <param name="site">The site.</param>
        /// <returns>What is added to the place.</returns>
        public int PlaceShift((int Map, int Event, int Page, int Common) site) =>
            site.Common > 0 && _leadingMarks.TryGetValue(site.Common, out int marks) ? 1 - marks : 0;

        /// <summary>
        /// Reads a site's kept commands.
        /// </summary>
        /// <param name="site">The site.</param>
        /// <returns>The commands, <see langword="null"/> for a list the copy lacks.</returns>
        public IReadOnlyList<CommandRow>? Commands((int Map, int Event, int Page, int Common) site) =>
            _lists.TryGetValue(site, out int list) ? [.. _commands[list]] : null;
    }
}
