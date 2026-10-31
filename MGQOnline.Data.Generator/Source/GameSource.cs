//----------------------------------------------------------------
//  GameSource.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Read the game's scripts
//      Paulinchen  2026-10-30: Read whether each entry holds anything instead of whether it has a name
//      Paulinchen  2026-10-28: Read the entries of the named parts and the names of switches and variables
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Source;

/// <summary>
/// The game's data as the generator reads it, every file whole and once, and what it read: each
/// file's path, SHA-256 and size.
/// </summary>
/// <param name="files">Where the files come from.</param>
internal sealed class GameSource(IGameDataFiles files)
{
    /// <summary>
    /// The cache of the analysed database the game writes next to its data; the same lists saved
    /// back, which the build never reads but notes.
    /// </summary>
    public const string DataExPath = "Data/DataEx.rvdata2";

    /// <summary>
    /// Where the game keeps its scripts.
    /// </summary>
    public const string ScriptsPath = "Data/Scripts.rvdata2";

    /// <summary>
    /// The named parts of the database, in the order of the game's fingerprint.
    /// </summary>
    public static readonly IReadOnlyList<(string Part, string Path)> NamedParts =
    [
        ("actors", "Data/Actors.rvdata2"),
        ("classes", "Data/Classes.rvdata2"),
        ("skills", "Data/Skills.rvdata2"),
        ("items", "Data/Items.rvdata2"),
        ("weapons", "Data/Weapons.rvdata2"),
        ("armors", "Data/Armors.rvdata2"),
        ("enemies", "Data/Enemies.rvdata2"),
        ("states", "Data/States.rvdata2"),
    ];

    /// <summary>
    /// Each file read so far by path: its SHA-256 and size.
    /// </summary>
    private readonly SortedDictionary<string, (string Sha256, int Bytes)> _read = new(StringComparer.Ordinal);

    /// <summary>
    /// The entries of each named part read so far, by file.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<SourceEntry?>> _entries = new(StringComparer.Ordinal);

    /// <summary>
    /// Lists the files read so far, one line each: path, SHA-256 and size; and whether the game's
    /// analysed cache is present.
    /// </summary>
    /// <returns>The lines, by path.</returns>
    public string InputHashes()
    {
        IEnumerable<string> lines = _read.Select(file => string.Create(CultureInfo.InvariantCulture, $"{file.Key} {file.Value.Sha256} {file.Value.Bytes}"));
        return string.Join("\n", lines.Append($"{DataExPath} {(files.Exists(DataExPath) ? "present" : "absent")}"));
    }

    /// <summary>
    /// Reads the map lists of Data and of each Data/Map folder after it, as the game's MapInfos does.
    /// </summary>
    /// <returns>Every map, by id.</returns>
    public IReadOnlyList<SourceMapInfo> ReadMapInfos()
    {
        var maps = new List<SourceMapInfo>();
        for (int folder = 0; folder == 0 || files.Exists(GameDataPaths.MapInfos(folder)); folder++)
        {
            if (Read(GameDataPaths.MapInfos(folder)) is not RubyHash infos)
            {
                continue;
            }

            var entries = new Dictionary<int, SourceMapEntry>();
            foreach (KeyValuePair<RubyValue, RubyValue> pair in infos)
            {
                entries[SourcePruner.Int(pair.Key)] = SourcePruner.Content<SourceMapEntry>(pair.Value) ?? new SourceMapEntry(string.Empty, 0);
            }

            int offset = folder * GameDataPaths.MapsPerFolder;
            foreach ((int number, SourceMapEntry entry) in entries)
            {
                maps.Add(new SourceMapInfo(offset + number, folder, number, entry.ParentId > 0 ? offset + entry.ParentId : 0, RootName(entries, number)));
            }
        }

        return [.. maps.OrderBy(map => map.Id)];
    }

    /// <summary>
    /// Reads a map's file.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <returns>The map, <see langword="null"/> for a map without a file.</returns>
    public SourceMap? ReadMap(int id)
    {
        string path = GameDataPaths.Map(id);
        if (id <= 0 || !files.Exists(path) || Read(path) is not RubyObject map)
        {
            return null;
        }

        var events = new SortedDictionary<int, SourceEvent>();
        if (map["events"] is RubyHash hash)
        {
            foreach ((_, RubyValue value) in hash)
            {
                SourceEvent found = SourcePruner.Content<SourceEvent>(value) ?? throw new System.IO.InvalidDataException($"Map {id} holds {value.KindName} among its events.");
                events[found.Id] = found;
            }
        }

        return new SourceMap(SourcePruner.Int(map["tileset_id"]), SourcePruner.ItemsOf<SourceEncounter>(map["encounter_list"]), events);
    }

    /// <summary>
    /// Reads the common events as the file holds them.
    /// </summary>
    /// <returns>The common events by id, <see langword="null"/> where the game has none; index 0 is empty.</returns>
    public IReadOnlyList<SourceCommon?> ReadCommonEvents() =>
        [.. ReadList<SourceCommon>(GameDataPaths.CommonEvents).Select((common, id) => common is null ? null : common with { Id = id })];

    /// <summary>
    /// Reads the troops.
    /// </summary>
    /// <returns>The troops by id, <see langword="null"/> where the game has none; index 0 is empty.</returns>
    public IReadOnlyList<SourceTroop?> ReadTroops() =>
        [.. ReadList<SourceTroop>(GameDataPaths.Troops).Select((troop, id) => troop is null ? null : troop with { Id = id })];

    /// <summary>
    /// Reads the entries of a named part, each file once.
    /// </summary>
    /// <param name="path">The part's file, such as "Data/Actors.rvdata2".</param>
    /// <returns>The entries by id, <see langword="null"/> where the game has none.</returns>
    public IReadOnlyList<SourceEntry?> ReadEntries(string path)
    {
        if (!_entries.TryGetValue(path, out IReadOnlyList<SourceEntry?>? entries))
        {
            _entries[path] = entries = ReadList<SourceEntry>(path);
        }

        return entries;
    }

    /// <summary>
    /// Reads the game's scripts, each inflated as one text.
    /// </summary>
    /// <returns>The scripts in their order; none when the game holds no scripts' file.</returns>
    public IReadOnlyList<string> ReadScripts()
    {
        if (Read(ScriptsPath) is not RubyArray scripts)
        {
            return [];
        }

        var texts = new List<string>();
        foreach (RubyValue script in scripts)
        {
            if (script is RubyArray { Count: >= 3 } fields && fields[2] is RubyString packed)
            {
                using var inflated = new System.IO.Compression.ZLibStream(new System.IO.MemoryStream(packed.Bytes.ToArray()), System.IO.Compression.CompressionMode.Decompress);
                using var text = new System.IO.StreamReader(inflated, System.Text.Encoding.UTF8);
                texts.Add(text.ReadToEnd().Replace("\r\n", "\n", StringComparison.Ordinal));
            }
        }

        return texts;
    }

    /// <summary>
    /// Reads whether each entry of a named part holds anything.
    /// </summary>
    /// <param name="path">The part's file, such as "Data/Actors.rvdata2".</param>
    /// <returns>Per id whether it holds a note, features or effects, <see langword="null"/> where the game has no entry.</returns>
    public IReadOnlyList<bool?> ReadInUse(string path) => [.. ReadEntries(path).Select(entry => entry?.InUse)];

    /// <summary>
    /// Reads the names of the switches and variables, which the build reads flags from and never writes.
    /// </summary>
    /// <returns>The names by id, each list with its empty first one.</returns>
    public (IReadOnlyList<string> Switches, IReadOnlyList<string> Variables) ReadSystemNames()
    {
        RubyObject? system = Read(GameDataPaths.System) as RubyObject;
        return (NamesOf(system?["switches"]), NamesOf(system?["variables"]));
    }

    /// <summary>
    /// Finds the name of a map's tree root in its folder's list.
    /// </summary>
    /// <param name="entries">The folder's maps by number.</param>
    /// <param name="number">The map's number.</param>
    /// <returns>The root's name.</returns>
    private static string RootName(Dictionary<int, SourceMapEntry> entries, int number)
    {
        var seen = new HashSet<int>();
        while (entries[number].ParentId is > 0 and int parent && entries.ContainsKey(parent) && seen.Add(number))
        {
            number = parent;
        }

        return entries[number].Name;
    }

    /// <summary>
    /// Reads an Array of names.
    /// </summary>
    /// <param name="value">The Array, nil for none.</param>
    /// <returns>Its names, empty for an entry that is no String.</returns>
    private static string[] NamesOf(RubyValue? value) => value is RubyArray array ? [.. array.Select(SourcePruner.TextOf)] : [];

    /// <summary>
    /// Reads a data file that lists objects by id, its first entry empty.
    /// </summary>
    /// <typeparam name="T">The objects.</typeparam>
    /// <param name="path">The file.</param>
    /// <returns>The objects by id.</returns>
    private T?[] ReadList<T>(string path)
        where T : class =>
        Read(path) is RubyArray list ? [.. list.Select(SourcePruner.Content<T>)] : [];

    /// <summary>
    /// Reads a data file through the pruner and notes it.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Its value, nil for a file that is not there.</returns>
    private RubyValue Read(string path)
    {
        if (!files.Exists(path))
        {
            return RubyNil.Value;
        }

        byte[] data = files.Read(path);
        _read[path] = (Convert.ToHexStringLower(SHA256.HashData(data)), data.Length);
        return RubyMarshal.Read(data, SourcePruner.Instance);
    }
}
