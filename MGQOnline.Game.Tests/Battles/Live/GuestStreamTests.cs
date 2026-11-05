//----------------------------------------------------------------
//  GuestStreamTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Set the lists the guest lets in and dropped the recorded sends
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the guest's intake of the host's stream: what it leaves out, what it swaps and what it cuts.
/// </summary>
public sealed class GuestStreamTests
{
    /// <summary>
    /// Asserts that a picture number past the screen's pictures is left out with its reason.
    /// </summary>
    [Fact]
    public void Take_PictureNumberOutOfRange_IsLeftOutWithItsReason()
    {
        var stream = new GuestStream();
        stream.Setup(Setup());

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("picture.show", 101, "cutin", 0, 0, 0, 100, 100, 255, 0)), 1);

        Assert.Empty(taken.Lines);
        Assert.Equal("left out the host's picture call show with the arguments [101, \"cutin\", 0, 0, 0, 100, 100, 255, 0]: no such change or picture", Assert.Single(taken.Logs).Text);
    }

    /// <summary>
    /// Asserts that the host's names are swapped longest first and a speaker's name box keeps its name.
    /// </summary>
    [Fact]
    public void Take_Message_SwapsNamesButNotTheNameBox()
    {
        var stream = new GuestStream();
        IReadOnlyList<LiveLogLine> logs = stream.Setup(Setup(WireWriter.Line(new WireList("Alice (Host)", "Alice"), new WireList()), ["Ann", "Al"]));

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("message", WireNil.Value, "", 0, 0, 2, @"\n<Alice>Alice (Host) and Alice")), 1);

        Assert.Equal("the host names 2 party and 0 troop characters; swapping Alice (Host) -> Ann, Alice -> Al", Assert.Single(logs).Text);
        Assert.Equal(@"\n<Alice>Ann and Al", ((WireString)WireReader.Parse(Assert.Single(taken.Lines), NoGame)![6]).Text);
    }

    /// <summary>
    /// Asserts that a wait longer than ten seconds is cut to them.
    /// </summary>
    [Fact]
    public void Take_LongWait_IsCutToTenSeconds()
    {
        var stream = new GuestStream();
        stream.Setup(Setup());

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("scene.wait", 3000)), 1);

        Assert.Equal(WireWriter.Line("scene.wait", GuestStream.MaxWait), Assert.Single(taken.Lines));
    }

    /// <summary>
    /// What a test knows of the game when it reads a line: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Makes a setup that lets the host's picture shows in, as the guest's game names them.
    /// </summary>
    /// <param name="names">The host's names line, nil for none.</param>
    /// <param name="ownParty">The guest's names of the host's party.</param>
    /// <returns>The setup.</returns>
    private static StreamSetup Setup(string? names = null, string[]? ownParty = null) =>
        new(names is null ? null : Encoding.UTF8.GetBytes(names), ownParty ?? [], [], true, new HashSet<string>(), new HashSet<string>(StringComparer.Ordinal) { "show" },
            new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), new HashSet<string>(), 10);
}
