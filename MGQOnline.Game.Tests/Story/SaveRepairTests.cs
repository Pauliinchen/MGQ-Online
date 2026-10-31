//----------------------------------------------------------------
//  SaveRepairTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the one-time repair of saves the 0.6.9.2 chest path left stuck: a save whose chest is shut
/// and whose switch is off gets the switch, a save the plain game made stays as it is, and in a
/// world only the player's own keys count.
/// </summary>
public sealed class SaveRepairTests
{
    /// <summary>
    /// The Makina chest 215:23, whose A proves 2045, and Ragnarok's 1081:52, whose A proves 2750.
    /// </summary>
    private static readonly RepairPairRow[] Pairs = [new(215, 23, 0, "A", 2045), new(1081, 52, 0, "A", 2750)];

    /// <summary>
    /// Asserts that a stuck save, its Makina chest shut and 2045 off, gets 2045.
    /// </summary>
    [Fact]
    public void Switches_TurnOnTheSwitchOfAShutChest()
    {
        Assert.Equal([2045], SaveRepair.Switches(Pairs, _ => true, On("ss215.23.A")));
    }

    /// <summary>
    /// Asserts that a save the plain game made stays as it is: a chest still open, or a chest shut
    /// with its switch on, and a save without any pair's chest shut.
    /// </summary>
    [Fact]
    public void Switches_LeaveAPlainSaveAsItIs()
    {
        Assert.Empty(SaveRepair.Switches(Pairs, _ => true, On("ss215.23.A", "s2045", "s2750")));
        Assert.Empty(SaveRepair.Switches(Pairs, _ => true, On("s2750")));
        Assert.Empty(SaveRepair.Switches([], _ => true, On("ss1649.14.A")));
    }

    /// <summary>
    /// Asserts that in a world the repair reads and turns on only keys the player owns: a world
    /// chest's pair is left to the world.
    /// </summary>
    [Fact]
    public void Switches_InAWorldTouchOnlyThePlayersOwnKeys()
    {
        bool Own(StoryKey key) => key != StoryKey.SelfSwitch(1081, 52, "A");

        Assert.Equal(["ss215.23.A", "s2045"], SaveRepair.Keys(Pairs, Own).Select(key => key.ToString()));
        Assert.Equal([2045], SaveRepair.Switches(Pairs, Own, On("ss215.23.A", "ss1081.52.A")));
    }

    /// <summary>
    /// Reads keys as on when named.
    /// </summary>
    /// <param name="names">The keys that are on.</param>
    /// <returns>The test.</returns>
    private static System.Func<StoryKey, bool> On(params string[] names)
    {
        var on = new HashSet<string>(names);
        return key => on.Contains(key.ToString());
    }
}
