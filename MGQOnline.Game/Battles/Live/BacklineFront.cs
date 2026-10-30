//----------------------------------------------------------------
//  BacklineFront.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// The Frontlines two games of a PvP battle with the Backline tell each other, as
/// battles_pvp_backline.rbx checked them: the other side's Frontline the other game tells fits its
/// team when it holds as many characters as the troop, each one of the team once; and a game tells
/// its own Frontline once it changed since it last told it.
/// </summary>
public sealed class BacklineFront
{
    /// <summary>
    /// What a game knows of the game when it reads a Frontline: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// The actor ids of the other side's team, <see langword="null"/> outside a battle with the Backline.
    /// </summary>
    private HashSet<int>? _team;

    /// <summary>
    /// The actor ids of this game's Frontline as it last told it, by place.
    /// </summary>
    private List<int>? _told;

    /// <summary>
    /// Gets a value indicating whether the running PvP battle has the Backline.
    /// </summary>
    public bool On => _team is not null;

    /// <summary>
    /// Starts the Backline for a PvP battle.
    /// </summary>
    /// <param name="team">The actor ids of every character of the other side.</param>
    /// <param name="front">The actor ids of this game's Frontline, by place, which the other game knows.</param>
    public void Begin(IEnumerable<int> team, IEnumerable<int> front)
    {
        _team = team.ToHashSet();
        _told = front.ToList();
    }

    /// <summary>
    /// Ends the Backline with its battle.
    /// </summary>
    public void Finish()
    {
        _team = null;
        _told = null;
    }

    /// <summary>
    /// Checks the other side's Frontline the other game told.
    /// </summary>
    /// <param name="line">The Frontline's actor ids, by place, as the first value of a line.</param>
    /// <param name="troop">The actor ids of the other side's Frontline now, by place.</param>
    /// <returns>The new Frontline; <see langword="null"/> when it stays, with the reason when it does
    /// not fit the team.</returns>
    public (List<int>? Front, string? Unfit) Take(ReadOnlySpan<byte> line, IReadOnlyList<int> troop)
    {
        ArgumentNullException.ThrowIfNull(troop);
        IReadOnlyList<WireValue>? values = WireReader.Parse(line, NoGame);
        if (_team is null || values is not { Count: > 0 } || values[0] is not WireList ids)
        {
            return (null, null);
        }

        List<int?> front = ids.Items.Select(id => id is WireInteger number && number.Value >= int.MinValue && number.Value <= int.MaxValue && _team.Contains((int)number.Value)
            ? (int?)(int)number.Value : null).ToList();
        if (front.Count != troop.Count || front.Contains(null) || front.Distinct().Count() != front.Count)
        {
            return (null, $"left out a Frontline that does not fit the other side's team: {RubyText.Inspect(ids)}");
        }

        List<int> taken = front.Select(id => id!.Value).ToList();
        return taken.SequenceEqual(troop) ? (null, null) : (taken, null);
    }

    /// <summary>
    /// Tells whether this game tells the other its Frontline, once the round's commands came: when it
    /// changed since it last told it.
    /// </summary>
    /// <param name="front">The actor ids of this game's Frontline now, by place.</param>
    /// <returns>The Frontline to tell, <see langword="null"/> for none.</returns>
    public List<int>? Settle(IEnumerable<int> front)
    {
        if (_team is null)
        {
            return null;
        }

        List<int> ids = front.ToList();
        if (_told is not null && _told.SequenceEqual(ids))
        {
            return null;
        }

        _told = ids;
        return ids;
    }
}
