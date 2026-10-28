//----------------------------------------------------------------
//  TinyGame.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Wrote troops, named database entries, further map folders and common event ids unlike their places
//                            - Wrote events with pages of their own on any map, names of switches, variables and common events, and entries with fields
//                            - Wrote events of other maps that run by themselves
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// A page of a tiny game's map event.
/// </summary>
/// <param name="Commands">Its commands.</param>
/// <param name="Trigger">How it starts: 0 by the action button, 3 by itself.</param>
/// <param name="Switch1">The switch it needs on, <see langword="null"/> for none.</param>
/// <param name="SelfSwitch">The self switch it needs on, <see langword="null"/> for none.</param>
internal sealed record TinyPage(object[][] Commands, int Trigger = 0, int? Switch1 = null, string? SelfSwitch = null);

/// <summary>
/// A game of a few events and common events, written as the game's RPG objects in Marshal, for the
/// tests that need no game folder.
/// </summary>
internal sealed class TinyGame : IGameDataFiles
{
    /// <summary>
    /// The data files by path.
    /// </summary>
    private readonly Dictionary<string, byte[]> _files = new(StringComparer.Ordinal);

    /// <summary>
    /// The events of each map with a file, by map and id: where each stands and its pages.
    /// </summary>
    private readonly SortedDictionary<int, SortedDictionary<int, (int X, int Y, TinyPage[] Pages)>> _maps = new() { [1] = [] };

    /// <summary>
    /// The names of the switches and variables by id.
    /// </summary>
    private readonly (SortedDictionary<int, string> Switches, SortedDictionary<int, string> Variables) _systemNames = (new() { [2] = "Temp flag" }, []);

    /// <summary>
    /// The names of the common events where they have one, by id.
    /// </summary>
    private readonly Dictionary<int, string> _commonNames = [];

    /// <summary>
    /// The entries of database files written with fields, by file: class and fields by id.
    /// </summary>
    private readonly SortedDictionary<string, (string ClassName, SortedDictionary<int, (string Field, object Value)[]> Entries)> _entries = new(StringComparer.Ordinal);

    /// <summary>
    /// The common events, by id.
    /// </summary>
    private readonly SortedDictionary<int, object[][]> _commons = [];

    /// <summary>
    /// The ids the common events' objects hold where they differ from their places, by place.
    /// </summary>
    private readonly Dictionary<int, int> _ownIds = [];

    /// <summary>
    /// The troops by id: their enemies and their one page's commands.
    /// </summary>
    private readonly SortedDictionary<int, (int[] Enemies, object[][] Commands)> _troops = [];

    /// <summary>
    /// The names of the entries of named parts of the database, by file: class and names by id from 1.
    /// </summary>
    private readonly SortedDictionary<string, (string ClassName, string[] Names)> _named = new(StringComparer.Ordinal);

    /// <summary>
    /// The maps the map lists name by id: their names and the maps above them.
    /// </summary>
    private readonly SortedDictionary<int, (string Name, int ParentId)> _mapInfos = new() { [1] = ("Field", 0) };

    /// <summary>
    /// Writes a command: code, then its parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="parameters">Its parameters: whole numbers, texts and flags.</param>
    /// <returns>The command as the builder takes it.</returns>
    public static object[] C(int code, params object[] parameters) => [code, 0, parameters];

    /// <summary>
    /// Writes a command at an indent.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">Its parameters.</param>
    /// <returns>The command as the builder takes it.</returns>
    public static object[] At(int code, int indent, params object[] parameters) => [code, indent, parameters];

    /// <summary>
    /// Adds an event of map 1 with one page.
    /// </summary>
    /// <param name="id">The event.</param>
    /// <param name="commands">The page's commands.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Event(int id, params object[][] commands) => MapEvent(1, id, 0, 0, new TinyPage(commands));

    /// <summary>
    /// Adds an event with pages of its own to a map, which gets a file.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="id">The event.</param>
    /// <param name="x">Where it stands across.</param>
    /// <param name="y">Where it stands down.</param>
    /// <param name="pages">Its pages.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame MapEvent(int map, int id, int x, int y, params TinyPage[] pages)
    {
        if (!_maps.TryGetValue(map, out SortedDictionary<int, (int X, int Y, TinyPage[] Pages)>? events))
        {
            _maps[map] = events = [];
            _mapInfos.TryAdd(map, ($"MAP{map:000}", 0));
        }

        events[id] = (x, y, pages);
        return this;
    }

    /// <summary>
    /// Names a switch.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame SwitchName(int id, string name)
    {
        _systemNames.Switches[id] = name;
        return this;
    }

    /// <summary>
    /// Names a variable.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame VariableName(int id, string name)
    {
        _systemNames.Variables[id] = name;
        return this;
    }

    /// <summary>
    /// Names a common event.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame CommonName(int id, string name)
    {
        _commonNames[id] = name;
        return this;
    }

    /// <summary>
    /// Adds an entry with fields to a database file, such as an item with its type and description.
    /// </summary>
    /// <param name="path">The file, such as "Data/Items.rvdata2".</param>
    /// <param name="className">The entries' class, such as "RPG::Item".</param>
    /// <param name="id">The entry.</param>
    /// <param name="fields">Its fields without "@": whole numbers, texts and flags.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Entry(string path, string className, int id, params (string Field, object Value)[] fields)
    {
        if (!_entries.TryGetValue(path, out var file))
        {
            _entries[path] = file = (className, []);
        }

        file.Entries[id] = fields;
        return this;
    }

    /// <summary>
    /// Adds a common event.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <param name="commands">Its commands.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Common(int id, params object[][] commands)
    {
        _commons[id] = commands;
        return this;
    }

    /// <summary>
    /// Adds an event of another map than 1 that runs by itself.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="id">The event.</param>
    /// <param name="endedBy">A self switch that, once on, shows a second page that runs nothing; <see langword="null"/> for none.</param>
    /// <param name="commands">The commands of the page that runs by itself.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Autorun(int map, int id, string? endedBy, params object[][] commands) =>
        endedBy is null
            ? MapEvent(map, id, 0, 0, new TinyPage(commands, Trigger: 3))
            : MapEvent(map, id, 0, 0, new TinyPage(commands, Trigger: 3), new TinyPage([], SelfSwitch: endedBy));

    /// <summary>
    /// Gives a common event's object another id than its place, as the editor leaves some.
    /// </summary>
    /// <param name="id">The common event's place.</param>
    /// <param name="ownId">The id its object holds.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame CommonOwnId(int id, int ownId)
    {
        _ownIds[id] = ownId;
        return this;
    }

    /// <summary>
    /// Adds a troop with one battle event page.
    /// </summary>
    /// <param name="id">The troop.</param>
    /// <param name="enemies">Its enemies, none for a troop the editor left empty.</param>
    /// <param name="commands">Its page's commands.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Troop(int id, int[] enemies, params object[][] commands)
    {
        _troops[id] = (enemies, commands);
        return this;
    }

    /// <summary>
    /// Adds the entries of a named part of the database, such as the actors.
    /// </summary>
    /// <param name="path">Its file, such as "Data/Actors.rvdata2".</param>
    /// <param name="className">The entries' class, such as "RPG::Actor".</param>
    /// <param name="names">The entries' names by id from 1; empty for an entry without a name.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame Named(string path, string className, params string[] names)
    {
        _named[path] = (className, names);
        return this;
    }

    /// <summary>
    /// Names a map in its folder's map list; it has a file only once it has events.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <param name="name">Its name.</param>
    /// <param name="parentId">The map above it in the folder, by its id; 0 for none.</param>
    /// <returns>The game, for more.</returns>
    public TinyGame FolderMap(int id, string name, int parentId = 0)
    {
        _mapInfos[id] = (name, parentId);
        return this;
    }

    /// <summary>
    /// Writes the files and opens their data.
    /// </summary>
    /// <returns>The data.</returns>
    public GameData Data() => new(Files());

    /// <summary>
    /// Writes the files.
    /// </summary>
    /// <returns>The game, whose files are written.</returns>
    public TinyGame Files()
    {
        foreach (IGrouping<int, KeyValuePair<int, (string Name, int ParentId)>> folder in _mapInfos.GroupBy(map => map.Key / GameDataPaths.MapsPerFolder))
        {
            var maps = new SortedDictionary<int, (string Name, int ParentId)>(folder.ToDictionary(map => map.Key % GameDataPaths.MapsPerFolder, map => map.Value));
            _files[GameDataPaths.MapInfos(folder.Key)] = Dump(w => w.HashOf(maps, (_, map) => w.Object(
                "RPG::MapInfo",
                ("name", () => w.Text(map.Name)),
                ("parent_id", () => w.Int(map.ParentId % GameDataPaths.MapsPerFolder)))));
        }

        foreach ((int map, SortedDictionary<int, (int X, int Y, TinyPage[] Pages)> events) in _maps)
        {
            _files[GameDataPaths.Map(map)] = Dump(w => w.Object("RPG::Map", ("events", () => w.HashOf(events, (id, found) => WriteEvent(w, id, found.X, found.Y, found.Pages)))));
        }

        int last = _commons.Count == 0 ? 0 : _commons.Keys.Max();
        _files[GameDataPaths.CommonEvents] = Dump(w => w.Array(last + 1, id => _commons.TryGetValue(id, out object[][]? commands)
            ? WriteCommon(w, _ownIds.GetValueOrDefault(id, id), _commonNames.GetValueOrDefault(id, string.Empty), commands)
            : w.Nil()));
        _files[GameDataPaths.System] = Dump(w => w.Object(
            "RPG::System",
            ("switches", () => w.Array(Math.Max(3, _systemNames.Switches.Keys.Max() + 1), id => w.Text(_systemNames.Switches.GetValueOrDefault(id, string.Empty)))),
            ("variables", () => w.Array(_systemNames.Variables.Count == 0 ? 1 : _systemNames.Variables.Keys.Max() + 1, id => w.Text(_systemNames.Variables.GetValueOrDefault(id, string.Empty))))));
        foreach ((string path, (string className, SortedDictionary<int, (string Field, object Value)[]> entries)) in _entries)
        {
            _files[path] = Dump(w => w.Array(entries.Keys.Max() + 1, id => entries.TryGetValue(id, out var fields)
                ? w.Object(className, [.. fields.Select(field => (field.Field, (Action)(() => w.Value(field.Value))))])
                : w.Nil()));
        }

        int lastTroop = _troops.Count == 0 ? 0 : _troops.Keys.Max();
        _files[GameDataPaths.Troops] = Dump(w => w.Array(lastTroop + 1, id => _troops.TryGetValue(id, out var troop) ? WriteTroop(w, id, troop.Enemies, troop.Commands) : w.Nil()));
        foreach ((string path, (string className, string[] names)) in _named)
        {
            _files[path] = Dump(w => w.Array(names.Length + 1, id => id == 0 ? w.Nil() : w.Object(className, ("name", () => w.Text(names[id - 1])))));
        }

        return this;
    }

    /// <summary>
    /// Writes a map event.
    /// </summary>
    /// <param name="w">The writer.</param>
    /// <param name="id">The event.</param>
    /// <param name="x">Where it stands across.</param>
    /// <param name="y">Where it stands down.</param>
    /// <param name="pages">Its pages.</param>
    private static void WriteEvent(Writer w, int id, int x, int y, TinyPage[] pages) => w.Object(
        "RPG::Event",
        ("id", () => w.Int(id)),
        ("name", () => w.Text($"EV{id:000}")),
        ("x", () => w.Int(x)),
        ("y", () => w.Int(y)),
        ("pages", () => w.Array(pages.Length, place => w.Object(
            "RPG::Event::Page",
            ("condition", () => w.Object(
                "RPG::Event::Page::Condition",
                ("switch1_valid", () => w.Bool(pages[place].Switch1 is not null)),
                ("switch1_id", () => w.Int(pages[place].Switch1 ?? 1)),
                ("self_switch_valid", () => w.Bool(pages[place].SelfSwitch is not null)),
                ("self_switch_ch", () => w.Text(pages[place].SelfSwitch ?? "A")))),
            ("trigger", () => w.Int(pages[place].Trigger)),
            ("list", () => w.List(pages[place].Commands))))));

    /// <summary>
    /// Writes a common event that never starts by itself.
    /// </summary>
    /// <param name="w">The writer.</param>
    /// <param name="id">The id its object holds.</param>
    /// <param name="name">Its name.</param>
    /// <param name="commands">Its commands.</param>
    /// <returns>Nothing; a value for the conditional writes.</returns>
    private static bool WriteCommon(Writer w, int id, string name, object[][] commands) => w.Object(
        "RPG::CommonEvent",
        ("id", () => w.Int(id)),
        ("name", () => w.Text(name)),
        ("trigger", () => w.Int(0)),
        ("switch_id", () => w.Int(0)),
        ("list", () => w.List(commands)));

    /// <summary>
    /// Writes a troop with one battle event page that checks nothing.
    /// </summary>
    /// <param name="w">The writer.</param>
    /// <param name="id">The troop.</param>
    /// <param name="enemies">Its enemies.</param>
    /// <param name="commands">Its page's commands.</param>
    /// <returns>Nothing; a value for the conditional writes.</returns>
    private static bool WriteTroop(Writer w, int id, int[] enemies, object[][] commands) => w.Object(
        "RPG::Troop",
        ("id", () => w.Int(id)),
        ("members", () => w.Array(enemies.Length, place => w.Object("RPG::Troop::Member", ("enemy_id", () => w.Int(enemies[place])), ("x", () => w.Int(100 * place)), ("y", () => w.Int(200)), ("hidden", () => w.Bool(false))))),
        ("pages", () => w.Array(1, _ => w.Object("RPG::Troop::Page", ("condition", () => w.Object("RPG::Troop::Page::Condition", ("turn_valid", () => w.Bool(false)))), ("span", () => w.Int(0)), ("list", () => w.List(commands))))));

    /// <inheritdoc />
    public bool Exists(string path) => _files.ContainsKey(path);

    /// <inheritdoc />
    public byte[] Read(string path) => _files.TryGetValue(path, out byte[]? bytes) ? bytes : throw new FileNotFoundException(path);

    /// <summary>
    /// Writes one Marshal dump.
    /// </summary>
    /// <param name="write">Writes its value.</param>
    /// <returns>The dump.</returns>
    private static byte[] Dump(Action<Writer> write)
    {
        var writer = new Writer();
        writer.Bytes(4, 8);
        write(writer);
        return writer.ToArray();
    }

    /// <summary>
    /// Writes Marshal values as Ruby does, each symbol in full.
    /// </summary>
    private sealed class Writer
    {
        /// <summary>
        /// The bytes written.
        /// </summary>
        private readonly MemoryStream _stream = new();

        /// <summary>
        /// Writes raw bytes.
        /// </summary>
        /// <param name="bytes">The bytes.</param>
        public void Bytes(params byte[] bytes) => _stream.Write(bytes);

        /// <summary>
        /// Writes nil.
        /// </summary>
        /// <returns>Nothing; a value for the conditional writes.</returns>
        public bool Nil()
        {
            Bytes((byte)'0');
            return true;
        }

        /// <summary>
        /// Writes true or false.
        /// </summary>
        /// <param name="flag">The value.</param>
        public void Bool(bool flag) => Bytes(flag ? (byte)'T' : (byte)'F');

        /// <summary>
        /// Writes a whole number.
        /// </summary>
        /// <param name="number">The number.</param>
        public void Int(long number)
        {
            Bytes((byte)'i');
            Long(number);
        }

        /// <summary>
        /// Writes a binary String.
        /// </summary>
        /// <param name="text">The text, as UTF-8.</param>
        public void Text(string text)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(text);
            Bytes((byte)'"');
            Long(bytes.Length);
            Bytes(bytes);
        }

        /// <summary>
        /// Writes an Array.
        /// </summary>
        /// <param name="count">Its length.</param>
        /// <param name="item">Writes each item by its place.</param>
        public void Array(int count, Func<int, bool> item)
        {
            Bytes((byte)'[');
            Long(count);
            for (int place = 0; place < count; place++)
            {
                item(place);
            }
        }

        /// <summary>
        /// Writes an Array.
        /// </summary>
        /// <param name="count">Its length.</param>
        /// <param name="item">Writes each item by its place.</param>
        public void Array(int count, Action<int> item) => Array(count, place =>
        {
            item(place);
            return true;
        });

        /// <summary>
        /// Writes a Hash of one whole number key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">Writes the value.</param>
        public void Hash(int key, Action value)
        {
            Bytes((byte)'{');
            Long(1);
            Int(key);
            value();
        }

        /// <summary>
        /// Writes a Hash by whole number keys.
        /// </summary>
        /// <typeparam name="T">The values.</typeparam>
        /// <param name="entries">The entries.</param>
        /// <param name="value">Writes each value.</param>
        public void HashOf<T>(SortedDictionary<int, T> entries, Action<int, T> value)
        {
            Bytes((byte)'{');
            Long(entries.Count);
            foreach (var (key, entry) in entries)
            {
                Int(key);
                value(key, entry);
            }
        }

        /// <summary>
        /// Writes an object with its instance variables.
        /// </summary>
        /// <param name="className">Its class.</param>
        /// <param name="fields">Each field's name, without "@", and how to write its value.</param>
        /// <returns>Nothing; a value for the conditional writes.</returns>
        public bool Object(string className, params (string Name, Action Value)[] fields)
        {
            Bytes((byte)'o');
            Symbol(className);
            Long(fields.Length);
            foreach ((string name, Action value) in fields)
            {
                Symbol("@" + name);
                value();
            }

            return true;
        }

        /// <summary>
        /// Writes a list of commands as RPG::EventCommand objects, with the closing empty command.
        /// </summary>
        /// <param name="commands">Each command: code, indent and parameters.</param>
        public void List(object[][] commands) => Array(commands.Length + 1, place =>
        {
            object[] command = place < commands.Length ? commands[place] : [0, 0, System.Array.Empty<object>()];
            Object(
                "RPG::EventCommand",
                ("code", () => Int((int)command[0])),
                ("indent", () => Int((int)command[1])),
                ("parameters", () => Array(((object[])command[2]).Length, item => Value(((object[])command[2])[item]))));
        });

        /// <summary>
        /// Gets the bytes written.
        /// </summary>
        /// <returns>The bytes.</returns>
        public byte[] ToArray() => _stream.ToArray();

        /// <summary>
        /// Writes a parameter or a field: a whole number, a text or a flag.
        /// </summary>
        /// <param name="value">The value: a whole number, a text or a flag.</param>
        public void Value(object value)
        {
            switch (value)
            {
                case int number:
                    Int(number);
                    break;
                case string text:
                    Text(text);
                    break;
                case bool flag:
                    Bool(flag);
                    break;
                default:
                    throw new ArgumentException($"no parameter of {value.GetType().Name}", nameof(value));
            }
        }

        /// <summary>
        /// Writes a symbol in full.
        /// </summary>
        /// <param name="name">Its name.</param>
        private void Symbol(string name)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(name);
            Bytes((byte)':');
            Long(bytes.Length);
            Bytes(bytes);
        }

        /// <summary>
        /// Writes a packed whole number as Ruby's w_long does.
        /// </summary>
        /// <param name="number">The number, within 32 bits.</param>
        private void Long(long number)
        {
            if (number == 0)
            {
                Bytes(0);
            }
            else if (number is > 0 and < 123)
            {
                Bytes((byte)(number + 5));
            }
            else if (number is < 0 and > -124)
            {
                Bytes((byte)((number - 5) & 0xFF));
            }
            else
            {
                var bytes = new List<byte>();
                long rest = number;
                do
                {
                    bytes.Add((byte)(rest & 0xFF));
                    rest >>= 8;
                }
                while (rest != 0 && rest != -1);
                Bytes((byte)(number > 0 ? bytes.Count : -bytes.Count & 0xFF));
                Bytes([.. bytes]);
            }
        }
    }
}
