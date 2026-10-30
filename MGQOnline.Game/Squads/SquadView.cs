//----------------------------------------------------------------
//  SquadView.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Squads;

/// <summary>
/// The player's squad as the scripts read it each frame: their share of the Frontline and the
/// Backline, how followers show, and whether their characters split into a squad and the cut ones.
/// </summary>
/// <param name="Share">The player's squad, <see langword="null"/> outside a party in a Classic world.</param>
/// <param name="Mode">How followers show: <see cref="SquadView.ActiveFrontline"/> or <see cref="SquadView.LeadersOnly"/>.</param>
/// <param name="Squads">Whether the player's characters split into a squad and the cut ones: in a party, and always in a Raid World.</param>
public sealed record SquadViewState(SquadShare? Share, int Mode, bool Squads);

/// <summary>
/// Reads the player's squad from the party and the squad rules, as coop_squad.rbx did: in a Raid
/// World the world's rules size it for the fight, in a party of a Classic world the party's places
/// split between its players, the leader first; and followers show as the party's leader chose.
/// </summary>
public static class SquadView
{
    /// <summary>
    /// How followers show: each player's own share of the Frontline walks behind them.
    /// </summary>
    public const int ActiveFrontline = 0;

    /// <summary>
    /// How followers show: the players walk alone.
    /// </summary>
    public const int LeadersOnly = 1;

    /// <summary>
    /// Reads the player's squad.
    /// </summary>
    /// <param name="room">The world the party plays in.</param>
    /// <param name="max">The player's party_member_max, Frontline and Backline together.</param>
    /// <param name="ownMode">The player's own choice of followers, which counts while they lead or play outside a party.</param>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="raidFight">Whether the battle running is a raid.</param>
    /// <param name="rules">The Raid World's squad rules.</param>
    /// <returns>The squad.</returns>
    public static SquadViewState Of(WorldRoom room, int max, int ownMode, bool raid, bool raidFight, SquadRules rules)
    {
        ArgumentNullException.ThrowIfNull(room);
        bool inParty = room.InWorld && room.Party.InParty;
        PartyLeader? leader = inParty ? room.Party.Leader : null;
        string? chosen = leader is { Peer: { } peer } ? peer.State.Text("follow") : null;
        int mode = (chosen is null ? ownMode == LeadersOnly : chosen == "1") ? LeadersOnly : ActiveFrontline;
        SquadShare? share = raid ? SquadMath.RaidShare(rules, max, raidFight) : inParty ? PartyShare(room, leader, max) : null;
        return new SquadViewState(share, mode, raid || inParty);
    }

    /// <summary>
    /// Reads the player's share of their party's places, which split between its players ordered as
    /// every member's game orders them.
    /// </summary>
    /// <param name="room">The world the party plays in.</param>
    /// <param name="leader">The party's leader.</param>
    /// <param name="max">The player's party_member_max.</param>
    /// <returns>The share.</returns>
    private static SquadShare PartyShare(WorldRoom room, PartyLeader? leader, int max)
    {
        List<(string Id, bool First)> players = [(room.OwnId, leader is { IsMe: true })];
        players.AddRange(room.Party.Members.Select(peer => (peer.Id, leader is { } lead && lead.Peer == peer)));
        int position = Array.IndexOf(SquadMath.Ranked(players), 0);
        SquadShare[] shares = SquadMath.Shares(players.Count, max);
        return position < shares.Length ? shares[position] : new SquadShare(0, 0);
    }
}
