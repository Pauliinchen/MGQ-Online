//----------------------------------------------------------------
//  TeamSides.cs
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
/// A team duel's sides, as battles_team.rbx kept them: the players of this game's side and of the
/// other, whether this game's side is the host's, and who commands the characters of each player
/// who left, the first player of their side still in the duel.
/// </summary>
public sealed class TeamSides
{
    /// <summary>
    /// What the guest knows of the game when it reads the host's heirs: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// The seats of this game's side.
    /// </summary>
    private List<int> _own = [];

    /// <summary>
    /// The seats of the other side.
    /// </summary>
    private List<int> _other = [];

    /// <summary>
    /// Who commands the characters of each player who left, <see langword="null"/> once their side is
    /// gone, in the order they left.
    /// </summary>
    private List<KeyValuePair<int, int?>> _heirs = [];

    /// <summary>
    /// Gets a value indicating whether this game's side is the host's.
    /// </summary>
    public bool SameSide { get; private set; }

    /// <summary>
    /// Gets who commands the characters of each player who left, in the order they left.
    /// </summary>
    public IReadOnlyList<KeyValuePair<int, int?>> Heirs => _heirs;

    /// <summary>
    /// Gets the seats of both sides, this game's first.
    /// </summary>
    public IEnumerable<int> Players => _own.Concat(_other);

    /// <summary>
    /// Keeps the sides of the duel about to start, nobody's characters taken over.
    /// </summary>
    /// <param name="own">The seats of this game's side.</param>
    /// <param name="other">The seats of the other side.</param>
    /// <param name="sameSide">Whether this game's side is the host's.</param>
    public void Prepare(IEnumerable<int> own, IEnumerable<int> other, bool sameSide)
    {
        _own = own.ToList();
        _other = other.ToList();
        SameSide = sameSide;
        _heirs = [];
    }

    /// <summary>
    /// Reports whether a guest stands on the host's side. Asked by the host.
    /// </summary>
    /// <param name="seat">The guest's seat.</param>
    /// <returns>Whether they do.</returns>
    public bool SameSideAsHost(int? seat) => seat is int guest && _own.Contains(guest);

    /// <summary>
    /// Finds who commands the characters of a player who left.
    /// </summary>
    /// <param name="seat">The seat of the player who left.</param>
    /// <returns>The seat of who took them over, <see langword="null"/> for nobody.</returns>
    public int? HeirOf(int seat) => _heirs.FirstOrDefault(heir => heir.Key == seat).Value;

    /// <summary>
    /// Reports whether every player of the other side left. Asked by the host.
    /// </summary>
    /// <param name="host">The host's own seat.</param>
    /// <param name="guestsIn">The guests still in the duel.</param>
    /// <returns>Whether they did.</returns>
    public bool OtherSideGone(int host, IReadOnlyCollection<int> guestsIn) => Staying(_other, host, guestsIn).Count == 0;

    /// <summary>
    /// As host, hands the characters of the players who left to the first player of their side still
    /// in the duel.
    /// </summary>
    /// <param name="host">The host's own seat.</param>
    /// <param name="guestsIn">The guests still in the duel.</param>
    /// <returns>Whether who commands them changed, which the guests are then told.</returns>
    public bool Settle(int host, IReadOnlyCollection<int> guestsIn)
    {
        bool changed = false;
        foreach (List<int> side in new[] { _own, _other })
        {
            List<int> staying = Staying(side, host, guestsIn);
            int? heir = staying.Count > 0 ? staying[0] : null;
            foreach (int seat in side)
            {
                int known = _heirs.FindIndex(pair => pair.Key == seat);
                if (staying.Contains(seat) || (known >= 0 ? _heirs[known].Value : null) == heir)
                {
                    continue;
                }

                if (known >= 0)
                {
                    _heirs[known] = new KeyValuePair<int, int?>(seat, heir);
                }
                else
                {
                    _heirs.Add(new KeyValuePair<int, int?>(seat, heir));
                }

                changed = true;
            }
        }

        return changed;
    }

    /// <summary>
    /// Writes who commands the characters of who left, as the host tells its guests: pairs of seats
    /// in one list, leaving out those whose side is gone.
    /// </summary>
    /// <returns>The message's body.</returns>
    public string HeirsLine() =>
        WireWriter.Line(new WireList(_heirs.Where(pair => pair.Value is not null).SelectMany(pair => new WireValue[] { pair.Key, (long)pair.Value!.Value }).ToArray()));

    /// <summary>
    /// As guest, takes who commands the characters of who left, as the host told: only whole pairs of
    /// seats, a later pair of a seat changing the earlier one.
    /// </summary>
    /// <param name="body">The host's message.</param>
    /// <returns>Whether the message held anything but pairs of seats, which the guest logs once.</returns>
    public bool TakeHeirs(ReadOnlySpan<byte> body)
    {
        IReadOnlyList<WireValue>? values = WireReader.Parse(body, NoGame);
        IReadOnlyList<WireValue> listed = values is { Count: > 0 } ? values[0] switch
        {
            WireList list => list.Items,
            WireNil => [],
            var single => [single],
        } : [];
        var heirs = new List<KeyValuePair<int, int?>>();
        bool broken = values is null;
        for (int at = 0; at + 1 < listed.Count; at += 2)
        {
            if (listed[at] is not WireInteger seat || listed[at + 1] is not WireInteger heir || !Fits(seat) || !Fits(heir))
            {
                broken = true;
                continue;
            }

            int known = heirs.FindIndex(pair => pair.Key == (int)seat.Value);
            var pair = new KeyValuePair<int, int?>((int)seat.Value, (int)heir.Value);
            if (known >= 0)
            {
                heirs[known] = pair;
            }
            else
            {
                heirs.Add(pair);
            }
        }

        _heirs = heirs;
        return broken;
    }

    /// <summary>
    /// Reports whether a seat a peer sent fits a seat of the battle.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>Whether it does.</returns>
    private static bool Fits(WireInteger seat) => seat.Value >= int.MinValue && seat.Value <= int.MaxValue;

    /// <summary>
    /// Lists the players of a side still in the duel: the host and the guests who did not leave.
    /// </summary>
    /// <param name="side">The side's seats.</param>
    /// <param name="host">The host's own seat.</param>
    /// <param name="guestsIn">The guests still in the duel.</param>
    /// <returns>Their seats, in the side's order.</returns>
    private static List<int> Staying(List<int> side, int host, IReadOnlyCollection<int> guestsIn) =>
        side.Where(seat => seat == host || guestsIn.Contains(seat)).ToList();
}
