//----------------------------------------------------------------
//  WorldFieldsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Covers reading and writing messages, which the golden scenarios only pass through.
/// </summary>
public sealed class WorldFieldsTests
{
    /// <summary>
    /// Asserts that a message reads as the scripts read it: a line without "=" skipped, a later field
    /// in the earlier one's place, the body after the first empty line.
    /// </summary>
    [Fact]
    public void Parse_ReadsAsTheScriptsDo()
    {
        WorldFields fields = WorldFields.Parse("a=1\nnothing\nb=x=y\na=2\n\nthe\n\nbody", out string body);

        Assert.Equal([new("a", "2"), new("b", "x=y")], fields.ToList());
        Assert.Equal("the\n\nbody", body);
    }

    /// <summary>
    /// Asserts that a value's line breaks are written as spaces, so it cannot end the fields.
    /// </summary>
    [Fact]
    public void Encode_TurnsLineBreaksIntoSpaces()
    {
        var fields = new WorldFields();
        fields.Set("chat", "one\r\ntwo");

        Assert.Equal("chat=one  two\n\nbody", fields.Encode("body"));
    }
}
