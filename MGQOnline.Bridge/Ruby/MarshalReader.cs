//----------------------------------------------------------------
//  MarshalReader.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read game data through a pruner that leaves fields out, builds its own values and seals objects
//                            - Took Integer Hash keys in strict mode
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Numerics;
using System.Text;
using System.Text.Unicode;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// Reads one Marshal 4.8 dump into a <see cref="RubyValue"/> tree.
/// </summary>
/// <remarks>
/// It builds values and never runs code from the data; nesting and every count are bounded by the
/// data, so broken data ends in a <see cref="RubyValueException"/> instead of a crash.
/// </remarks>
internal ref struct MarshalReader
{
    /// <summary>
    /// The largest capacity an Array or Hash reserves before its entries are read.
    /// </summary>
    private const int MaxReservedEntries = 4096;

    /// <summary>
    /// The instance variable that marks a String as UTF-8 (true) or US-ASCII (false).
    /// </summary>
    private const string EncodingFlag = "E";

    /// <summary>
    /// The instance variable that names a String's other encoding.
    /// </summary>
    private const string EncodingNameIvar = "encoding";

    /// <summary>
    /// The dump.
    /// </summary>
    private readonly ReadOnlySpan<byte> _data;

    /// <summary>
    /// Whether only plain values are taken.
    /// </summary>
    private readonly bool _strict;

    /// <summary>
    /// Shapes a full-mode read, <see langword="null"/> to keep everything.
    /// </summary>
    private readonly MarshalPruner? _pruner;

    /// <summary>
    /// The symbols read so far, which later ones may point back to.
    /// </summary>
    private readonly List<string> _symbols = [];

    /// <summary>
    /// The objects read so far, which later ones may point back to; <see langword="null"/> while an
    /// object that cannot be built before its contents is still being read.
    /// </summary>
    private readonly List<RubyValue?> _objects = [];

    /// <summary>
    /// The places in <see cref="_objects"/> of the Arrays and Hashes still being read.
    /// </summary>
    private readonly HashSet<int> _open = [];

    /// <summary>
    /// The runs of objects the read let go of inside sealed objects (see <see cref="MarshalPruner.Seals"/>),
    /// in the order of their places, which no longer stand in <see cref="_objects"/>.
    /// </summary>
    private readonly List<Forgotten> _forgotten = [];

    /// <summary>
    /// The objects of every run in <see cref="_forgotten"/>.
    /// </summary>
    private int _forgottenCount;

    /// <summary>
    /// The place of the next byte.
    /// </summary>
    private int _position;

    /// <summary>
    /// The nesting of the value being read.
    /// </summary>
    private int _depth;

    /// <summary>
    /// Starts reading.
    /// </summary>
    /// <param name="data">The dump.</param>
    /// <param name="strict">Whether only plain values are taken.</param>
    /// <param name="pruner">Shapes a full-mode read, <see langword="null"/> to keep everything.</param>
    public MarshalReader(ReadOnlySpan<byte> data, bool strict, MarshalPruner? pruner = null)
    {
        _data = data;
        _strict = strict;
        _pruner = strict ? null : pruner;
    }

    /// <summary>
    /// Reads the version and the one value of the dump.
    /// </summary>
    /// <returns>The value.</returns>
    public RubyValue ReadDump()
    {
        byte major = ReadByte();
        byte minor = ReadByte();
        if (major != RubyMarshal.MajorVersion || minor != RubyMarshal.MinorVersion)
        {
            throw Broken($"It is not Marshal 4.8 data (version {major}.{minor}).");
        }

        RubyValue value = ReadValue();
        return _position == _data.Length
            ? value
            : throw Broken($"It has {_data.Length - _position} bytes after its value.");
    }

    /// <summary>
    /// Makes the exception for broken data.
    /// </summary>
    /// <param name="what">What is wrong, as a sentence.</param>
    /// <returns>The exception.</returns>
    private static RubyValueException Broken(string what) => new("Broken Marshal data: " + what);

    /// <summary>
    /// Makes the exception for a value strict mode refuses.
    /// </summary>
    /// <param name="what">The value as the message names it, such as "RPG::Item".</param>
    /// <returns>The exception.</returns>
    private static RubyValueException Refused(string what) => new(RubyValue.Refusal(what));

    /// <summary>
    /// Reads the next value, one level deeper.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadValue()
    {
        if (++_depth > RubyValue.MaxDepth)
        {
            throw new RubyValueException(RubyValueException.TooDeep);
        }

        RubyValue value = ReadValueBody();
        _depth--;
        return value;
    }

    /// <summary>
    /// Reads the next value's type and contents.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadValueBody()
    {
        int start = _position;
        char type = (char)ReadByte();
        switch (type)
        {
            case '0': return RubyNil.Value;
            case 'T': return RubyBool.True;
            case 'F': return RubyBool.False;
            case 'i': return new RubyInteger(ReadLong());
            case 'l': return Register(ReadBignum());
            case '"': return Register(new RubyString(ReadBytes(), RubyEncoding.Binary));
            case 'I': return ReadWithIvars();
            case '[': return ReadArray();
            case '{': return ReadHash(withDefault: false);
            case '@': return Earlier(ReadCount());
            case ':': return Symbol(ReadSymbolBody());
            case ';': return Symbol(EarlierSymbol(ReadCount()));
            case '}':
                return _strict ? throw Refused("a Hash with a default value") : ReadHash(withDefault: true);
            case 'f':
                return Register(Float(Encoding.ASCII.GetString(ReadBytes())));
            case 'o':
            case 'S':
                return ReadObject(isStruct: type == 'S');
            case 'u':
                return ReadUserData();
            case 'U':
                return ReadUserObject();
            case '/':
                return ReadRegexp();
            case 'e':
                return ReadExtended();
            case 'C':
                return ReadUserClass();
            case 'c':
            case 'm':
            case 'M':
                return Module(Encoding.UTF8.GetString(ReadBytes()));
            default:
                throw Broken(string.Create(CultureInfo.InvariantCulture, $"It holds the unknown type '{type}' at byte {start}."));
        }
    }

    /// <summary>
    /// Reads a value followed by its instance variables: a String's encoding, an object's fields.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadWithIvars()
    {
        int place = _objects.Count;
        RubyValue value = ReadValue();
        int count = ReadCount();
        if (value is RubyString text)
        {
            text = ReadEncoding(text, count);
            if (place < _objects.Count && ReferenceEquals(_objects[place], value))
            {
                _objects[place] = text;
            }

            return text;
        }

        if (_strict)
        {
            throw Refused(value.KindName + " with instance variables");
        }

        for (int index = 0; index < count; index++)
        {
            string name = ReadSymbol();
            RubyValue field = ReadValue();
            if (value is RubyObject obj)
            {
                obj.Add(name.TrimStart('@'), field);
            }
        }

        return value;
    }

    /// <summary>
    /// Reads a String's instance variables and marks it with the encoding they name.
    /// </summary>
    /// <param name="text">The string read as binary.</param>
    /// <param name="count">The number of instance variables.</param>
    /// <returns>The string with its encoding.</returns>
    private RubyString ReadEncoding(RubyString text, int count)
    {
        RubyEncoding encoding = RubyEncoding.Binary;
        string? name = null;
        for (int index = 0; index < count; index++)
        {
            string ivar = ReadSymbol();
            RubyValue value = ReadValue();
            switch (ivar)
            {
                case EncodingFlag:
                    encoding = value is RubyBool { Flag: true } ? RubyEncoding.Utf8 : RubyEncoding.UsAscii;
                    break;
                case EncodingNameIvar:
                    encoding = RubyEncoding.Other;
                    name = value is RubyString encodingName ? encodingName.Text : "?";
                    break;
                default:
                    if (_strict)
                    {
                        throw Refused("a String with the instance variable " + ivar);
                    }

                    break;
            }
        }

        RubyString marked = text.Marked(encoding, name);
        if (_strict)
        {
            CheckText(marked);
        }

        return marked;
    }

    /// <summary>
    /// Refuses a String that is no UTF-8 or binary, or whose bytes break its encoding.
    /// </summary>
    /// <param name="text">The string.</param>
    private static void CheckText(RubyString text)
    {
        ReadOnlySpan<byte> bytes = text.Bytes.Span;
        bool valid = text.Encoding switch
        {
            RubyEncoding.Utf8 => Utf8.IsValid(bytes),
            RubyEncoding.UsAscii => Ascii.IsValid(bytes),
            RubyEncoding.Other => throw Refused(text.KindName),
            _ => true,
        };
        if (!valid)
        {
            throw Refused($"a String marked {text.EncodingName} with bytes outside it");
        }
    }

    /// <summary>
    /// Reads an Array.
    /// </summary>
    /// <returns>The Array.</returns>
    private RubyArray ReadArray()
    {
        int count = ReadCount(bytesEach: 1);
        var array = new RubyArray(Math.Min(count, MaxReservedEntries));
        int place = Register(array, open: true);
        for (int index = 0; index < count; index++)
        {
            array.Add(ReadValue());
        }

        _open.Remove(place);
        return array;
    }

    /// <summary>
    /// Reads a Hash; a key read twice keeps its first place and its last value, as in Ruby. Strict mode
    /// takes String and Integer keys only.
    /// </summary>
    /// <param name="withDefault">Whether a default value follows the pairs.</param>
    /// <returns>The Hash.</returns>
    private RubyHash ReadHash(bool withDefault)
    {
        int count = ReadCount(bytesEach: 2);
        var hash = new RubyHash(Math.Min(count, MaxReservedEntries));
        int place = Register(hash, open: true);
        for (int index = 0; index < count; index++)
        {
            RubyValue key = ReadValue();
            if (_strict && key is not (RubyString or RubyInteger))
            {
                throw Refused(key.KindName + " as a Hash key");
            }

            hash[key] = ReadValue();
        }

        if (withDefault)
        {
            hash.Default = ReadValue();
        }

        _open.Remove(place);
        return hash;
    }

    /// <summary>
    /// Reads an object with instance variables, or a Struct with its members.
    /// </summary>
    /// <param name="isStruct">Whether it is a Struct.</param>
    /// <returns>The object.</returns>
    private RubyValue ReadObject(bool isStruct)
    {
        string className = ReadSymbol();
        if (_strict)
        {
            throw Refused(className);
        }

        var obj = new RubyObject(className, isStruct);
        int place = Register(obj, open: false);
        int count = ReadCount(bytesEach: 2);
        for (int index = 0; index < count; index++)
        {
            string name = ReadSymbol();
            string field = isStruct ? name : name.TrimStart('@');
            if (_pruner is null || _pruner.Keeps(obj, field))
            {
                obj.Add(field, ReadValue());
            }
            else
            {
                SkipValue();
                obj.Add(field, RubySkipped.Value);
            }
        }

        if (_pruner is null)
        {
            return obj;
        }

        RubyValue finished = _pruner.Finish(obj);
        _objects[place] = finished;
        if (_pruner.Seals(obj))
        {
            ForgetFrom(place + 1);
        }

        return finished;
    }

    /// <summary>
    /// Lets go of every object read from a place on, the contents of a sealed object that just
    /// finished; a link into them reads as <see cref="RubySkipped"/>.
    /// </summary>
    /// <param name="place">The first place in <see cref="_objects"/> to let go of.</param>
    private void ForgetFrom(int place)
    {
        int inside = 0;
        while (_forgotten.Count > 0 && _forgotten[^1].After > place)
        {
            inside += _forgotten[^1].Count;
            _forgotten.RemoveAt(_forgotten.Count - 1);
        }

        int before = _forgottenCount - inside;
        int count = _objects.Count - place + inside;
        if (count == 0)
        {
            return;
        }

        _objects.RemoveRange(place, _objects.Count - place);
        _forgotten.Add(new Forgotten(place, place + before, count, before));
        _forgottenCount = before + count;
    }

    /// <summary>
    /// Reads an object its class dumped as bytes, such as a Table.
    /// </summary>
    /// <returns>The object.</returns>
    private RubyUserData ReadUserData()
    {
        string className = ReadSymbol();
        return _strict ? throw Refused(className) : Register(new RubyUserData(className, ReadBytes()));
    }

    /// <summary>
    /// Reads an object its class dumped as another value.
    /// </summary>
    /// <returns>The object.</returns>
    private RubyUserObject ReadUserObject()
    {
        string className = ReadSymbol();
        if (_strict)
        {
            throw Refused(className);
        }

        int place = _objects.Count;
        _objects.Add(null);
        var obj = new RubyUserObject(className, ReadValue());
        _objects[place] = obj;
        return obj;
    }

    /// <summary>
    /// Reads a Regexp.
    /// </summary>
    /// <returns>The Regexp.</returns>
    private RubyRegexp ReadRegexp()
    {
        if (_strict)
        {
            throw Refused("a Regexp");
        }

        var source = new RubyString(ReadBytes(), RubyEncoding.Binary);
        return Register(new RubyRegexp(source, ReadByte()));
    }

    /// <summary>
    /// Reads an object extended with a module, keeping the object only.
    /// </summary>
    /// <returns>The object.</returns>
    private RubyValue ReadExtended()
    {
        string module = ReadSymbol();
        return _strict ? throw Refused("an object extended with " + module) : ReadValue();
    }

    /// <summary>
    /// Reads a String, Array or Hash of a subclass, keeping the value only.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadUserClass()
    {
        string className = ReadSymbol();
        return _strict ? throw Refused(className) : ReadValue();
    }

    /// <summary>
    /// Takes a symbol read as a value.
    /// </summary>
    /// <param name="name">The symbol's name.</param>
    /// <returns>The symbol.</returns>
    private readonly RubySymbol Symbol(string name)
    {
        var symbol = new RubySymbol(name);
        return _strict ? throw Refused(symbol.KindName) : symbol;
    }

    /// <summary>
    /// Takes a Float read as text.
    /// </summary>
    /// <param name="text">Ruby's text of the number, such as "1.5", "inf" or "nan".</param>
    /// <returns>The Float.</returns>
    private readonly RubyFloat Float(string text)
    {
        if (_strict)
        {
            throw Refused("the Float " + text);
        }

        double value = text switch
        {
            "inf" => double.PositiveInfinity,
            "-inf" => double.NegativeInfinity,
            "nan" => double.NaN,
            _ => double.TryParse(text.Split('\0')[0], NumberStyles.Float, CultureInfo.InvariantCulture, out double number)
                ? number
                : throw Broken($"It holds the Float \"{text}\", which is no number."),
        };
        return new RubyFloat(value);
    }

    /// <summary>
    /// Takes a class or module reference.
    /// </summary>
    /// <param name="name">The class or module's name.</param>
    /// <returns>The reference.</returns>
    private RubyModule Module(string name)
    {
        var module = new RubyModule(name);
        return _strict ? throw Refused(module.KindName) : Register(module);
    }

    /// <summary>
    /// Walks past the next value without building it, one level deeper, keeping the places of the
    /// objects in it so later links still point where Ruby wrote them.
    /// </summary>
    private void SkipValue()
    {
        if (++_depth > RubyValue.MaxDepth)
        {
            throw new RubyValueException(RubyValueException.TooDeep);
        }

        SkipValueBody();
        _depth--;
    }

    /// <summary>
    /// Walks past the next value's type and contents, see <see cref="SkipValue"/>.
    /// </summary>
    private void SkipValueBody()
    {
        int start = _position;
        char type = (char)ReadByte();
        switch (type)
        {
            case '0':
            case 'T':
            case 'F':
                return;
            case 'i':
                ReadLong();
                return;
            case '@':
            case ';':
                ReadCount();
                return;
            case ':':
                ReadSymbolBody();
                return;
            case 'l':
                Skipped();
                ReadByte();
                Take(ReadCount(bytesEach: 2) * 2);
                return;
            case '"':
            case 'f':
            case 'c':
            case 'm':
            case 'M':
                Skipped();
                Take(ReadCount(bytesEach: 1));
                return;
            case '/':
                Skipped();
                Take(ReadCount(bytesEach: 1));
                ReadByte();
                return;
            case 'I':
                SkipValue();
                SkipFields();
                return;
            case '[':
                Skipped();
                SkipValues(ReadCount(bytesEach: 1));
                return;
            case '{':
            case '}':
                Skipped();
                SkipValues(ReadCount(bytesEach: 2) * 2);
                if (type == '}')
                {
                    SkipValue();
                }

                return;
            case 'o':
            case 'S':
                ReadSymbol();
                Skipped();
                SkipFields();
                return;
            case 'u':
                ReadSymbol();
                Skipped();
                Take(ReadCount(bytesEach: 1));
                return;
            case 'U':
                ReadSymbol();
                Skipped();
                SkipValue();
                return;
            case 'e':
            case 'C':
                ReadSymbol();
                SkipValue();
                return;
            default:
                throw Broken(string.Create(CultureInfo.InvariantCulture, $"It holds the unknown type '{type}' at byte {start}."));
        }
    }

    /// <summary>
    /// Walks past a count of values, see <see cref="SkipValue"/>.
    /// </summary>
    /// <param name="count">How many.</param>
    private void SkipValues(int count)
    {
        for (int index = 0; index < count; index++)
        {
            SkipValue();
        }
    }

    /// <summary>
    /// Walks past a count and that many named fields, see <see cref="SkipValue"/>.
    /// </summary>
    private void SkipFields()
    {
        int count = ReadCount(bytesEach: 2);
        for (int index = 0; index < count; index++)
        {
            ReadSymbol();
            SkipValue();
        }
    }

    /// <summary>
    /// Keeps the place of an object left out, which a later link reads as left out too.
    /// </summary>
    private readonly void Skipped() => _objects.Add(RubySkipped.Value);

    /// <summary>
    /// Reads a symbol where only a symbol may stand, such as a class name: new or one read before.
    /// </summary>
    /// <returns>The symbol's name.</returns>
    private string ReadSymbol()
    {
        char type = (char)ReadByte();
        switch (type)
        {
            case ':':
                return ReadSymbolBody();
            case ';':
                return EarlierSymbol(ReadCount());
            case 'I':
                string name = ReadSymbol();
                int count = ReadCount(bytesEach: 2);
                for (int index = 0; index < count; index++)
                {
                    ReadSymbol();
                    ReadValue();
                }

                return name;
            default:
                throw Broken(string.Create(CultureInfo.InvariantCulture, $"It holds '{type}' where a symbol belongs, at byte {_position - 1}."));
        }
    }

    /// <summary>
    /// Reads a new symbol's name and keeps it for later references.
    /// </summary>
    /// <returns>The name.</returns>
    private string ReadSymbolBody()
    {
        string name = Encoding.UTF8.GetString(ReadBytes());
        _symbols.Add(name);
        return name;
    }

    /// <summary>
    /// Reads a number too large for a packed integer.
    /// </summary>
    /// <returns>The number.</returns>
    private RubyInteger ReadBignum()
    {
        bool negative = ReadByte() == '-';
        int shorts = ReadCount(bytesEach: 2);
        BigInteger magnitude = new(Take(shorts * 2), isUnsigned: true, isBigEndian: false);
        return new RubyInteger(negative ? -magnitude : magnitude);
    }

    /// <summary>
    /// Reads a packed integer as Ruby's r_long does.
    /// </summary>
    /// <returns>The number.</returns>
    private long ReadLong()
    {
        sbyte head = (sbyte)ReadByte();
        if (head == 0)
        {
            return 0;
        }

        if (head > 4)
        {
            return head - 5;
        }

        if (head < -4)
        {
            return head + 5;
        }

        int length = Math.Abs(head);
        long value = head > 0 ? 0 : -1;
        for (int index = 0; index < length; index++)
        {
            value &= ~(0xFFL << (8 * index));
            value |= (long)ReadByte() << (8 * index);
        }

        return value;
    }

    /// <summary>
    /// Reads a count or a reference, and checks that the data left can hold what it counts.
    /// </summary>
    /// <param name="bytesEach">The fewest bytes each counted entry takes; 0 for a reference.</param>
    /// <returns>The count.</returns>
    private int ReadCount(int bytesEach = 0)
    {
        long count = ReadLong();
        if (count < 0 || count > int.MaxValue || count * bytesEach > _data.Length - _position)
        {
            throw Broken(string.Create(CultureInfo.InvariantCulture, $"It names {count} entries at byte {_position}, more than it holds."));
        }

        return (int)count;
    }

    /// <summary>
    /// Reads a length and that many bytes.
    /// </summary>
    /// <returns>A copy of the bytes.</returns>
    private byte[] ReadBytes() => Take(ReadCount(bytesEach: 1)).ToArray();

    /// <summary>
    /// Takes the next bytes.
    /// </summary>
    /// <param name="count">How many.</param>
    /// <returns>The bytes.</returns>
    private ReadOnlySpan<byte> Take(int count)
    {
        if (count > _data.Length - _position)
        {
            throw Broken("It ends inside a value.");
        }

        ReadOnlySpan<byte> bytes = _data.Slice(_position, count);
        _position += count;
        return bytes;
    }

    /// <summary>
    /// Reads the next byte.
    /// </summary>
    /// <returns>The byte.</returns>
    private byte ReadByte() => _position < _data.Length ? _data[_position++] : throw Broken("It ends inside a value.");

    /// <summary>
    /// Finds an object read before, which a reference points back to.
    /// </summary>
    /// <param name="place">The reference.</param>
    /// <returns>The object.</returns>
    private readonly RubyValue Earlier(int place)
    {
        int kept = KeptPlace(place);
        if (kept < 0)
        {
            return RubySkipped.Value;
        }

        if (kept >= _objects.Count || _objects[kept] is not RubyValue value)
        {
            throw Broken(string.Create(CultureInfo.InvariantCulture, $"It points to object {place}, which it does not hold yet."));
        }

        if (_strict && _open.Contains(kept))
        {
            throw Refused(value.KindName + " that holds itself");
        }

        return value;
    }

    /// <summary>
    /// Finds where an object stands in <see cref="_objects"/>, past the runs the read let go of.
    /// </summary>
    /// <param name="place">The object's place as the data counts it.</param>
    /// <returns>Its place in <see cref="_objects"/>, -1 for an object the read let go of.</returns>
    private readonly int KeptPlace(int place)
    {
        int low = 0;
        int high = _forgotten.Count - 1;
        while (low <= high)
        {
            int middle = (low + high) / 2;
            Forgotten run = _forgotten[middle];
            if (place < run.Start)
            {
                high = middle - 1;
            }
            else if (place >= run.Start + run.Count)
            {
                low = middle + 1;
            }
            else
            {
                return -1;
            }
        }

        return high < 0 ? place : place - _forgotten[high].Before - _forgotten[high].Count;
    }

    /// <summary>
    /// Finds a symbol read before, which a reference points back to.
    /// </summary>
    /// <param name="place">The reference.</param>
    /// <returns>The symbol's name.</returns>
    private readonly string EarlierSymbol(int place) =>
        place < _symbols.Count
            ? _symbols[place]
            : throw Broken(string.Create(CultureInfo.InvariantCulture, $"It points to symbol {place}, which it does not hold yet."));

    /// <summary>
    /// Keeps an object for later references.
    /// </summary>
    /// <typeparam name="T">The object's type.</typeparam>
    /// <param name="value">The object.</param>
    /// <returns>The object.</returns>
    private readonly T Register<T>(T value)
        where T : RubyValue
    {
        _objects.Add(value);
        return value;
    }

    /// <summary>
    /// Keeps an Array or Hash for later references before its contents are read.
    /// </summary>
    /// <param name="value">The container.</param>
    /// <param name="open">Whether it is still being read.</param>
    /// <returns>Its place.</returns>
    private readonly int Register(RubyValue value, bool open)
    {
        _objects.Add(value);
        int place = _objects.Count - 1;
        if (open)
        {
            _open.Add(place);
        }

        return place;
    }

    /// <summary>
    /// A run of objects the read let go of, see <see cref="ForgetFrom"/>.
    /// </summary>
    /// <param name="After">The place in <see cref="_objects"/> the run stood at, which the next kept object takes.</param>
    /// <param name="Start">The place the data counts the run's first object at.</param>
    /// <param name="Count">How many objects the run held.</param>
    /// <param name="Before">How many objects the runs before it held.</param>
    private readonly record struct Forgotten(int After, int Start, int Count, int Before);
}
