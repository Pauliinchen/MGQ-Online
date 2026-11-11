//----------------------------------------------------------------
//  CommandPlan.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Read the gold a co-op guest sends with its commands
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// Turns a guest's commands into the host's plan for the command phase, as battles_sync.rbx's
/// Commands.apply checked them: which places of the guest's side the guest commands, and of each
/// command whether it names a skill or item of the game's tables and a target the host's turn
/// reads, with the skills chained after it. The script makes the game's actions of the plan,
/// asking the game how many actions each character takes and whether it may use each skill.
/// </summary>
public static class CommandPlan
{
    /// <summary>
    /// The highest target index a command may name, -1 being a random target. A larger number would
    /// fail the host's own turn, which reads it as a place.
    /// </summary>
    public const int MaxTargetIndex = 255;

    /// <summary>
    /// The most skills chained after one action, far more than any skill type's chain of the game allows.
    /// </summary>
    public const int MaxChain = 16;

    /// <summary>
    /// The most gold a party holds, the game's NWConst::Party::MAX_MONEY.
    /// </summary>
    public const int MaxGold = 999_999_999;

    /// <summary>
    /// What the host knows of the game when it reads commands: nothing, since commands name kinds,
    /// ids and targets alone.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Plans the guest's commands.
    /// </summary>
    /// <param name="body">The commands: per place of the guest's side its list, then the order of the
    /// guest's places.</param>
    /// <param name="seat">The guest's seat, <see langword="null"/> for the other player of a duel.</param>
    /// <param name="several">Whether the host takes commands from several guests, who command only their own places.</param>
    /// <param name="owners">The seat of each place's owner, by place, <see langword="null"/> for a place no player owns.</param>
    /// <param name="heirOf">Who commands the characters of a player who left.</param>
    /// <param name="skills">The size of the game's skills table, its entry 0 counted.</param>
    /// <param name="items">The size of the game's items table, its entry 0 counted.</param>
    /// <returns>Per place: <see langword="null"/> where the computer's actions stay, an empty list
    /// where the guest takes them away, else each command checked, <see langword="null"/> for one the
    /// host cannot read; <see langword="null"/> for commands that do not read.</returns>
    public static List<List<PlannedCommand?>?>? Plan(ReadOnlySpan<byte> body, int? seat, bool several, IReadOnlyList<int?> owners,
        Func<int, int?> heirOf, int skills, int items)
    {
        ArgumentNullException.ThrowIfNull(owners);
        ArgumentNullException.ThrowIfNull(heirOf);
        if (WireReader.Parse(body, NoGame) is not { Count: > 0 } values || values[0] is not WireList commands)
        {
            return null;
        }

        var plan = new List<List<PlannedCommand?>?>();
        for (int place = 0; place < owners.Count; place++)
        {
            bool commanded = !several || (owners[place] is int owner && seat is int guest && (owner == guest || heirOf(owner) == guest));
            plan.Add(commanded && place < commands.Items.Count && commands.Items[place] is WireList list
                ? list.Items.Select(command => Checked(command, skills, items)).ToList()
                : null);
        }

        return plan;
    }

    /// <summary>
    /// Reads the gold a co-op guest sent with its commands for a turn that converts damage into gold.
    /// </summary>
    /// <remarks>The host's game converts against it; anything but a whole number the game's party can
    /// hold would break the host's battle for every player.</remarks>
    /// <param name="body">The commands: their list, the order of the guest's places, then the gold.</param>
    /// <returns>The gold, from 0 to <see cref="MaxGold"/>; <see langword="null"/> when none came or it
    /// is no such number.</returns>
    public static int? Gold(ReadOnlySpan<byte> body) =>
        WireReader.Parse(body, NoGame) is { Count: > 2 } values && values[2] is WireInteger { Value: var gold } && gold >= 0 && gold <= MaxGold
            ? (int)gold
            : null;

    /// <summary>
    /// Checks one command and the skills chained after it, the chain cut at its first link that is no
    /// skill or names none, and after <see cref="MaxChain"/> links.
    /// </summary>
    /// <param name="command">The command: "skill" or "item", the id and the target's index, then its chain's commands.</param>
    /// <param name="skills">The size of the skills table.</param>
    /// <param name="items">The size of the items table.</param>
    /// <returns>The command, <see langword="null"/> for one the host cannot read.</returns>
    private static PlannedCommand? Checked(WireValue command, int skills, int items)
    {
        if (Plain(command, skills, items) is not { } first)
        {
            return null;
        }

        if (command is not WireList { Items.Count: > 3 } full || full.Items[3] is not WireList links)
        {
            return first;
        }

        var chain = new List<PlannedCommand>();
        foreach (WireValue link in links.Items.Take(MaxChain))
        {
            if (link is not WireList { Items.Count: > 0 } linked || linked.Items[0] is not WireString { Text: "skill" } || Plain(link, skills, items) is not { } next)
            {
                break;
            }

            chain.Add(next);
        }

        return first with { Chain = chain };
    }

    /// <summary>
    /// Checks a command without its chain: a list of a kind, a whole id within its table and a whole
    /// target from -1 to <see cref="MaxTargetIndex"/>.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="skills">The size of the skills table.</param>
    /// <param name="items">The size of the items table.</param>
    /// <returns>The command without a chain, <see langword="null"/> for one the host cannot read.</returns>
    private static PlannedCommand? Plain(WireValue command, int skills, int items)
    {
        if (command is not WireList list)
        {
            return null;
        }

        WireValue At(int index) => index < list.Items.Count ? list.Items[index] : WireNil.Value;
        if (At(1) is not WireInteger id || At(2) is not WireInteger target || target.Value < -1 || target.Value > MaxTargetIndex)
        {
            return null;
        }

        int size = At(0) switch
        {
            WireString { Text: "skill" } => skills,
            WireString { Text: "item" } => items,
            _ => 0,
        };
        return id.Value > 0 && id.Value < size ? new PlannedCommand(((WireString)At(0)).Text, (int)id.Value, (int)target.Value, null) : null;
    }
}
