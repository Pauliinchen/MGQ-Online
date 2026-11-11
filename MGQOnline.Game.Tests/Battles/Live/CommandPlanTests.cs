//----------------------------------------------------------------
//  CommandPlanTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Checked that the host takes only gold a party holds from a guest
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the host's plan of a guest's commands: a chain cut to its length, a random target and the
/// gold sent with them.
/// </summary>
public sealed class CommandPlanTests
{
    /// <summary>
    /// Asserts that a chain of 17 skills is cut to 16.
    /// </summary>
    [Fact]
    public void Plan_ChainOfSeventeen_TakesSixteen()
    {
        WireValue[] chain = Enumerable.Range(20, 17).Select(id => (WireValue)new WireList("skill", id, 0)).ToArray();
        string body = WireWriter.Line(new WireList(new WireList(new WireList("skill", 5, 0, new WireList(chain)))));

        List<List<PlannedCommand?>?>? plan = CommandPlan.Plan(Encoding.UTF8.GetBytes(body), null, false, [null], _ => null, 200, 50);

        Assert.Equal(Enumerable.Range(20, CommandPlan.MaxChain), Assert.Single(Assert.Single(plan!)!)!.Chain!.Select(link => link.Id));
    }

    /// <summary>
    /// Asserts that a target of -1, a random one, is read, and -2 is not.
    /// </summary>
    [Fact]
    public void Plan_TargetMinusOne_IsARandomTarget()
    {
        string body = WireWriter.Line(new WireList(new WireList(new WireList("skill", 5, -1), new WireList("skill", 5, -2))));

        List<PlannedCommand?> commands = CommandPlan.Plan(Encoding.UTF8.GetBytes(body), 2, false, [null], _ => null, 200, 50)![0]!;

        Assert.Equal(-1, commands[0]!.Target);
        Assert.Null(commands[1]);
    }

    /// <summary>
    /// Asserts that the gold a guest sends is read, and that text or more gold than a party holds is
    /// not, since the host's conversion of damage into gold would fail on it.
    /// </summary>
    [Fact]
    public void Gold_SentWithTheCommands_TakesOnlyGoldAPartyHolds()
    {
        static int? GoldOf(WireValue gold) =>
            CommandPlan.Gold(Encoding.UTF8.GetBytes(WireWriter.Line(new WireList(), WireNil.Value, gold)));

        Assert.Equal(100_000, GoldOf(new WireInteger(100_000)));
        Assert.Null(GoldOf(new WireString("100000")));
        Assert.Null(GoldOf(new WireInteger(CommandPlan.MaxGold + 1L)));
    }
}
