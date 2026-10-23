//----------------------------------------------------------------
//  TinyGame.cs
//
//  Changelog:
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
    /// The events of map 1, by id.
    /// </summary>
    private readonly SortedDictionary<int, object[][]> _events = [];

    /// <summary>
    /// The common events, by id.
    /// </summary>
    private readonly SortedDictionary<int, object[][]> _commons = [];

    /// <summary>
    /// Writes a command: code, then its parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="parameters">Its parameters: whole numbers and texts.</param>
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
    public TinyGame Event(int id, params object[][] commands)
    {
        _events[id] = commands;
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
    /// Writes the files and opens their data.
    /// </summary>
    /// <returns>The data.</returns>
    public GameData Data()
    {
        _files[GameDataPaths.MapInfos(0)] = Dump(w => w.Hash(1, () => w.Object("RPG::MapInfo", ("name", () => w.Text("Field")), ("parent_id", () => w.Int(0)))));
        _files[GameDataPaths.Map(1)] = Dump(w => w.Object("RPG::Map", ("events", () => w.HashOf(_events, (id, commands) => WriteEvent(w, id, commands)))));
        int last = _commons.Count == 0 ? 0 : _commons.Keys.Max();
        _files[GameDataPaths.CommonEvents] = Dump(w => w.Array(last + 1, id => _commons.TryGetValue(id, out object[][]? commands) ? WriteCommon(w, id, commands) : w.Nil()));
        _files[GameDataPaths.System] = Dump(w => w.Object("RPG::System", ("switches", () => w.Array(3, id => w.Text(id == 2 ? "Temp flag" : ""))), ("variables", () => w.Array(1, _ => w.Text("")))));
        return new GameData(this);
    }

    /// <summary>
    /// Writes a map event with one page that checks nothing and starts by the action button.
    /// </summary>
    /// <param name="w">The writer.</param>
    /// <param name="id">The event.</param>
    /// <param name="commands">The page's commands.</param>
    private static void WriteEvent(Writer w, int id, object[][] commands) => w.Object(
        "RPG::Event",
        ("id", () => w.Int(id)),
        ("name", () => w.Text($"EV{id:000}")),
        ("pages", () => w.Array(1, _ => w.Object(
            "RPG::Event::Page",
            ("condition", () => w.Object("RPG::Event::Page::Condition", ("switch1_valid", () => w.Bool(false)))),
            ("trigger", () => w.Int(0)),
            ("list", () => w.List(commands))))));

    /// <summary>
    /// Writes a common event that never starts by itself.
    /// </summary>
    /// <param name="w">The writer.</param>
    /// <param name="id">The common event.</param>
    /// <param name="commands">Its commands.</param>
    /// <returns>Nothing; a value for the conditional writes.</returns>
    private static bool WriteCommon(Writer w, int id, object[][] commands) => w.Object(
        "RPG::CommonEvent",
        ("id", () => w.Int(id)),
        ("name", () => w.Text(string.Empty)),
        ("trigger", () => w.Int(0)),
        ("switch_id", () => w.Int(0)),
        ("list", () => w.List(commands)));

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
                ("parameters", () => Array(((object[])command[2]).Length, item => Parameter(((object[])command[2])[item]))));
        });

        /// <summary>
        /// Gets the bytes written.
        /// </summary>
        /// <returns>The bytes.</returns>
        public byte[] ToArray() => _stream.ToArray();

        /// <summary>
        /// Writes a parameter: a whole number or a text.
        /// </summary>
        /// <param name="value">The parameter.</param>
        private void Parameter(object value)
        {
            switch (value)
            {
                case int number:
                    Int(number);
                    break;
                case string text:
                    Text(text);
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
