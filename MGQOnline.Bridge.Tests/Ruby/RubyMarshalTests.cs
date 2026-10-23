//----------------------------------------------------------------
//  RubyMarshalTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Checked a pruned read of game data
//                            - Expected Integer Hash keys to cross and an Array key to be refused
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Numerics;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge.Tests.Ruby;

/// <summary>
/// Covers the Marshal codec against the dumps Ruby 3.3 wrote: plain values both ways, the refusals of
/// strict mode and game data in full mode.
/// </summary>
public sealed class RubyMarshalTests
{
    /// <summary>
    /// Asserts that every plain value Ruby wrote reads and writes back to the same bytes.
    /// </summary>
    /// <param name="name">The fixture.</param>
    [Theory]
    [InlineData("scalars")]
    [InlineData("integers")]
    [InlineData("fixnum_borders")]
    [InlineData("bignums")]
    [InlineData("strings")]
    [InlineData("nested")]
    [InlineData("repeated_keys")]
    [InlineData("integer_keys")]
    public void ReadThenWrite_GivesTheBytesRubyWrote(string name)
    {
        byte[] golden = Fixtures.Codec(name);

        Assert.Equal(golden, RubyMarshal.Write(RubyMarshal.Read(golden)));
    }

    /// <summary>
    /// Asserts that the numbers around the Fixnum range of RGSS3 and past 64 bits read as Ruby wrote them.
    /// </summary>
    [Fact]
    public void Read_KeepsNumbersAroundTheFixnumBordersAndPast64Bits()
    {
        RubyArray borders = RubyMarshal.Read(Fixtures.Codec("fixnum_borders")).AsArray();
        RubyArray bignums = RubyMarshal.Read(Fixtures.Codec("bignums")).AsArray();

        Assert.Equal(new[] { (1L << 30) - 1, 1L << 30, -(1L << 30), -(1L << 30) - 1 }, borders.Select(number => number.AsLong()));
        Assert.Equal(BigInteger.Pow(2, 100), ((RubyInteger)bignums[^1]).Value);
        Assert.Equal(-BigInteger.Pow(2, 64) - 1, ((RubyInteger)bignums[5]).Value);
    }

    /// <summary>
    /// Asserts that a String keeps the encoding Ruby marked it with: UTF-8, US-ASCII from Integer#to_s, or binary.
    /// </summary>
    [Fact]
    public void Read_KeepsTheEncodingOfEachString()
    {
        RubyArray strings = RubyMarshal.Read(Fixtures.Codec("strings")).AsArray();

        Assert.Equal(
            new[] { RubyEncoding.Utf8, RubyEncoding.Utf8, RubyEncoding.Utf8, RubyEncoding.UsAscii, RubyEncoding.Binary },
            strings.Select(text => ((RubyString)text).Encoding));
        Assert.Equal("ルカ é", strings[1].AsText());
        Assert.Equal("42", strings[3].AsText());
        Assert.Equal("\0\xFF raw"u8.ToArray()[..1], strings[4].AsBytes().ToArray()[..1]);
        Assert.Throws<RubyValueException>(() => strings[4].AsText());
    }

    /// <summary>
    /// Asserts that a Hash keeps its order and a value Ruby linked twice reads twice.
    /// </summary>
    [Fact]
    public void Read_KeepsHashOrderAndFollowsLinks()
    {
        RubyHash value = RubyMarshal.Read(Fixtures.Codec("nested")).AsHash()["value"].AsHash();
        RubyArray shared = RubyMarshal.Read(Fixtures.Codec("shared_value")).AsArray();

        Assert.Equal(new[] { "seat", "names", "empty", "list" }, value.Keys.Select(key => key.AsText()));
        Assert.Equal("Ilias", value["names"].AsArray()[1].AsText());
        Assert.Equal(new[] { "same", "same" }, shared.Select(item => item.AsText()));
    }

    /// <summary>
    /// Asserts that strict mode refuses what is no plain value and names it.
    /// </summary>
    /// <param name="name">The fixture.</param>
    /// <param name="message">The refusal expected.</param>
    [Theory]
    [InlineData("object", "RPG::Item cannot cross the bridge.")]
    [InlineData("symbol", "The Symbol :seat cannot cross the bridge.")]
    [InlineData("float", "The Float 1.5 cannot cross the bridge.")]
    [InlineData("user_data", "Table cannot cross the bridge.")]
    [InlineData("shift_jis", "A String in Shift_JIS cannot cross the bridge.")]
    [InlineData("array_key", "An Array as a Hash key cannot cross the bridge.")]
    [InlineData("holds_itself", "An Array that holds itself cannot cross the bridge.")]
    [InlineData("hash_default", "A Hash with a default value cannot cross the bridge.")]
    public void Read_RefusesWhatIsNoPlainValue(string name, string message)
    {
        var refusal = Assert.Throws<RubyValueException>(() => RubyMarshal.Read(Fixtures.Codec(name)));

        Assert.Equal(message, refusal.Message);
    }

    /// <summary>
    /// Asserts that strict mode refuses a String marked UTF-8 whose bytes are not UTF-8.
    /// </summary>
    [Fact]
    public void Read_RefusesAUtf8StringWithBrokenBytes()
    {
        byte[] dump = [4, 8, (byte)'I', (byte)'"', 6, 0xFF, 6, (byte)':', 6, (byte)'E', (byte)'T'];

        var refusal = Assert.Throws<RubyValueException>(() => RubyMarshal.Read(dump));

        Assert.Equal("A String marked UTF-8 with bytes outside it cannot cross the bridge.", refusal.Message);
    }

    /// <summary>
    /// Asserts that data cut short, followed by more bytes or of another version is broken.
    /// </summary>
    /// <param name="dump">The bytes.</param>
    [Theory]
    [InlineData(new byte[] { 4, 8, (byte)'[', 7, (byte)'T' })]
    [InlineData(new byte[] { 4, 8, (byte)'T', (byte)'T' })]
    [InlineData(new byte[] { 4, 9, (byte)'T' })]
    public void Read_RefusesBrokenData(byte[] dump)
    {
        var broken = Assert.Throws<RubyValueException>(() => RubyMarshal.Read(dump));

        Assert.StartsWith("Broken Marshal data: ", broken.Message);
    }

    /// <summary>
    /// Asserts that the writer refuses what only game data holds.
    /// </summary>
    [Fact]
    public void Write_RefusesWhatIsNoPlainValue()
    {
        var value = new RubyArray { 1, new RubyHash { { "mode", new RubySymbol("auto") } } };

        var refusal = Assert.Throws<RubyValueException>(() => RubyMarshal.Write(value));

        Assert.Equal("The Symbol :auto cannot cross the bridge.", refusal.Message);
        Assert.False(value.IsPlain(out string? reason));
        Assert.Equal(refusal.Message, reason);
    }

    /// <summary>
    /// Asserts that a value built in C# reads back equal, with an ASCII key found under either encoding.
    /// </summary>
    [Fact]
    public void WriteThenRead_GivesTheSameValue()
    {
        var value = new RubyHash
        {
            { "id", 7 },
            { "names", new RubyArray { "Alice", RubyString.Binary([0, 1, 2]) } },
            { "big", BigInteger.Pow(2, 70) },
            { "none", RubyNil.Value },
        };

        RubyHash read = RubyMarshal.Read(RubyMarshal.Write(value)).AsHash();

        Assert.Equal(value, read);
        Assert.Equal(7, read[new RubyString("id"u8.ToArray(), RubyEncoding.UsAscii)].AsInt());
    }

    /// <summary>
    /// Asserts that full mode reads game data: objects and their fields, a page linked twice, floats,
    /// symbols, a Struct, a Table's bytes and a String in another encoding.
    /// </summary>
    [Fact]
    public void Read_InFullMode_ReadsGameData()
    {
        RubyArray data = RubyMarshal.Read(Fixtures.Codec("game_data"), MarshalMode.Full).AsArray();
        var table = (RubyUserData)RubyMarshal.Read(Fixtures.Codec("user_data"), MarshalMode.Full);

        var gameEvent = (RubyObject)data[0];
        RubyArray pages = gameEvent["pages"].AsArray();
        var page = (RubyObject)pages[0];
        var command = (RubyObject)page["list"].AsArray()[0];
        var point = (RubyObject)data[1];

        Assert.Equal("RPG::Event", gameEvent.ClassName);
        Assert.Equal("Chest", gameEvent["name"].AsText());
        Assert.Same(page, pages[1]);
        Assert.Equal(0.5, ((RubyFloat)page["move_speed"]).Value);
        Assert.Equal(new RubySymbol("auto"), page["graphic"].AsHash()[new RubySymbol("mode")]);
        Assert.Equal(101, command["code"].AsInt());
        Assert.Equal("face", command["parameters"].AsArray()[0].AsText());
        Assert.True(point.IsStruct);
        Assert.Equal(2, point["y"].AsInt());
        Assert.Equal("Shift_JIS", ((RubyString)data[2]).EncodingName);
        Assert.Equal("Table", table.ClassName);
        Assert.Equal(24, table.Data.Length);
    }

    /// <summary>
    /// Asserts that a pruned read leaves out the fields its pruner drops, hands a link the value the
    /// pruner built, and still finds the objects after a value it left out.
    /// </summary>
    [Fact]
    public void Read_WithAPruner_LeavesOutFieldsAndKeepsWhatItBuilt()
    {
        RubyArray data = RubyMarshal.Read(Fixtures.Codec("game_data"), new PageNames()).AsArray();

        var gameEvent = (RubyObject)data[0];
        RubyArray pages = gameEvent["pages"].AsArray();

        Assert.Equal("page of Chest", ((RubyBox<string>)pages[0]).Content);
        Assert.Same(pages[0], pages[1]);
        Assert.Same(RubySkipped.Value, gameEvent["name"]);
        Assert.Equal(2, ((RubyObject)data[1])["y"].AsInt());
        Assert.Equal("Shift_JIS", ((RubyString)data[2]).EncodingName);
    }

    /// <summary>
    /// Asserts that a read lets go of a sealed object's contents: a link past them still finds its
    /// object, a link into them reads as left out.
    /// </summary>
    [Fact]
    public void Read_WithASealingPruner_FindsLinksPastTheSealedContents()
    {
        // [#<S @a="x">, "y", (link to "y"), (link to "x")]
        byte[] dump = [4, 8, (byte)'[', 9, (byte)'o', (byte)':', 6, (byte)'S', 6, (byte)':', 7, (byte)'@', (byte)'a', (byte)'"', 6, (byte)'x', (byte)'"', 6, (byte)'y', (byte)'@', 8, (byte)'@', 7];

        RubyArray data = RubyMarshal.Read(dump, new SealsEverything()).AsArray();

        Assert.Equal((byte)'x', ((RubyObject)data[0])["a"].AsBytes().Span[0]);
        Assert.Same(data[1], data[2]);
        Assert.Same(RubySkipped.Value, data[3]);
    }

    /// <summary>
    /// Seals every object.
    /// </summary>
    private sealed class SealsEverything : MarshalPruner
    {
        /// <inheritdoc />
        public override bool Seals(RubyObject value) => true;
    }

    /// <summary>
    /// Builds a text of each event page and leaves out the events' names.
    /// </summary>
    private sealed class PageNames : MarshalPruner
    {
        /// <inheritdoc />
        public override bool Keeps(RubyObject owner, string field) => !(owner.ClassName == "RPG::Event" && field == "name");

        /// <inheritdoc />
        public override RubyValue Finish(RubyObject value) =>
            value.ClassName == "RPG::Event::Page" ? new RubyBox<string>("page of Chest") : value;
    }
}
