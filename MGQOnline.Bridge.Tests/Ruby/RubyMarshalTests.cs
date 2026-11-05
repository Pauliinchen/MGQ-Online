//----------------------------------------------------------------
//  RubyMarshalTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks of recorded dumps
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
/// Covers the Marshal codec: plain values both ways, the refusals of strict mode and a pruned read.
/// </summary>
public sealed class RubyMarshalTests
{
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
}
