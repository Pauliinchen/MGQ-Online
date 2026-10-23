//----------------------------------------------------------------
//  SelfSwitchIndexTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the derived index of the story mapping and the event command index over a tiny game.
/// </summary>
public sealed class SelfSwitchIndexTests
{
    /// <summary>
    /// The mapping's keys of the cases: variable 1001 one-way, switch 60 shared, switch 61 personal.
    /// </summary>
    private static readonly StoryKeyRow[] Keys = [new("v1001", "one_way"), new("s60", "shared"), new("s61", "personal")];

    /// <summary>
    /// Asserts which events share their self switches: one that reads a shared key in a branch,
    /// sets one, or calls a common event that does, also through another; not one that touches only
    /// personal keys, or reaches a shared key only through the player's own transfer process.
    /// </summary>
    [Fact]
    public void Derive_SharesTheEventsThatReadOrWriteASharedKey()
    {
        GameData data = new TinyGame()
            .Event(1, C(111, 1, 1001, 0, 7, 0), At(123, 1, "A", 0), C(412))
            .Event(2, C(121, 55, 65, 0))
            .Event(3, C(117, 20))
            .Event(4, C(121, 61, 61, 0), C(123, "A", 0))
            .Event(5, C(117, 114))
            .Event(6, C(355, "$game_variables[1001] += 1"))
            .Common(20, C(117, 21))
            .Common(21, C(122, 1001, 1001, 1, 0, 1))
            .Common(114, C(111, 0, 60, 0))
            .Data();

        SelfSwitchIndex index = SelfSwitchIndex.Derive(data, Keys, []);

        Assert.Equal([(1, 1), (1, 2), (1, 3), (1, 6)], index.Events);
        Assert.Equal([20L, 21L], index.Commons);
    }

    /// <summary>
    /// Asserts that rows for whole maps, events and common events go against the rule, a map's
    /// before an event's, and that a row for one letter is left to whoever reads the rows.
    /// </summary>
    [Fact]
    public void Derive_AppliesTheRowsForWholeEvents()
    {
        GameData data = new TinyGame()
            .Event(1, C(121, 60, 60, 0))
            .Event(2, C(121, 60, 60, 0))
            .Event(3, C(101, "", 0, 0, 2))
            .Event(4, C(101, "", 0, 0, 2))
            .Common(20, C(121, 60, 60, 0))
            .Data();
        StoryEventRow[] rows = [new("ss1.*.*", "personal"), new("ss1.2.*", "shared"), new("ss1.4.A", "shared"), new("ce20.*", "personal"), new("ce30.*", "shared")];

        SelfSwitchIndex index = SelfSwitchIndex.Derive(data, Keys, rows);

        Assert.Equal([(1, 2)], index.Events);
        Assert.Equal([30L], index.Commons);
    }

    /// <summary>
    /// Asserts that the command index finds the troops a page fights through the common events it
    /// calls, in the order met, without the common events that turn a given switch on.
    /// </summary>
    [Fact]
    public void TroopsOf_FollowsTheCommonEventsInOrder()
    {
        GameData data = new TinyGame()
            .Common(20, C(301, 0, 7, 0, 0), C(117, 21), C(117, 20))
            .Common(21, C(301, 0, 8, 0, 0))
            .Common(22, C(121, 900, 900, 0), C(301, 0, 9, 0, 0))
            .Data();
        var index = new EventCommandIndex(data);
        EventCommand[] page = [Command(301, 0, 5), Command(117, 20), Command(117, 22), Command(301, 0, 5)];

        Assert.Equal([5L, 7L, 8L, 9L], index.TroopsOf(page));
        Assert.Equal([5L, 7L, 8L], index.TroopsOf(page, skipTurningOn: 900));
    }

    /// <summary>
    /// Asserts that the command index finds what a page sets through the common events it calls.
    /// </summary>
    [Fact]
    public void WritesOf_FollowsTheCommonEvents()
    {
        GameData data = new TinyGame().Common(20, C(122, 1075, 1075, 0, 0, 3), C(123, "B", 0)).Data();
        var index = new EventCommandIndex(data);
        EventCommand[] page = [Command(121, 61, 62, 0), Command(117, 20), Command(123, "A", 1)];

        (IReadOnlyList<KeyRange> keys, IReadOnlyList<string> selfSwitches) = index.WritesOf(page);

        Assert.Equal([new KeyRange(false, 61, 62), new KeyRange(true, 1075, 1075)], keys);
        Assert.Equal(["A", "B"], selfSwitches.Order());
    }

    /// <summary>
    /// Writes a command of whole number and text parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="parameters">Its parameters.</param>
    /// <returns>The command.</returns>
    private static EventCommand Command(int code, params object[] parameters) =>
        new(code, 0, new MGQOnline.Bridge.Ruby.RubyArray(parameters.Select(value => value is string text ? (MGQOnline.Bridge.Ruby.RubyValue)text : (int)value)));
}
