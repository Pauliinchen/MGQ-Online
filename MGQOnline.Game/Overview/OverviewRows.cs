//----------------------------------------------------------------
//  OverviewRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Overview;

/// <summary>
/// The World overview's lists of players and the party box's, from the world room's players and
/// the player's party and what the player tells the others.
/// </summary>
/// <remarks>
/// Every order names a player's seat last, so players of the same name keep one order on every frame.
/// </remarks>
public static class OverviewRows
{
    /// <summary>
    /// What the Players page's heading says for the maps the game names nowhere.
    /// </summary>
    public const string UnnamedPlace = "Unnamed place";

    /// <summary>
    /// What follows the player's own name on the Players page.
    /// </summary>
    public const string OwnMark = " (you)";

    /// <summary>
    /// Builds every list for a frame.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="name">The player's name.</param>
    /// <returns>The lists.</returns>
    public static OverviewRowSet All(WorldRoom room, OverviewState state, string name)
    {
        IReadOnlyList<OverviewRow> players = Players(room, state, name);
        return new OverviewRowSet(players, Lines(players), Party(room, state, name, false), Party(room, state, name, true), Map(room, state, name));
    }

    /// <summary>
    /// Lists the players of the world online, the player first, then the others who told a name in
    /// their seats' order.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="name">The player's name.</param>
    /// <returns>The players.</returns>
    public static IReadOnlyList<OverviewRow> Players(WorldRoom room, OverviewState state, string name)
    {
        ArgumentNullException.ThrowIfNull(room);
        return [Own(room, state, name + OwnMark, state.Level), .. Named(room.Peers).Select(peer => Of(room, peer, peer.State["lv"]))];
    }

    /// <summary>
    /// Lists the player's party for the party box: the leader first, then the others by name.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="name">The player's name.</param>
    /// <param name="front">Whether each player shows their Frontline's highest level, as in a Raid World.</param>
    /// <returns>The players, the player included; none outside a party of two or more.</returns>
    public static IReadOnlyList<OverviewRow> Party(WorldRoom room, OverviewState state, string name, bool front)
    {
        ArgumentNullException.ThrowIfNull(room);
        if (!room.InWorld || room.Party.SizeOf(room.Party.Id) < 2)
        {
            return [];
        }

        List<OverviewRow> party = [Own(room, state, name, front ? state.Front : state.Level), .. room.Party.Members.Select(peer => Of(room, peer, peer.State[front ? "flv" : "lv"]))];
        return [.. party.OrderBy(row => row.Badge is { Leads: true } ? 0 : 1).ThenBy(row => RubyAscii.Downcase(row.Name), StringComparer.Ordinal).ThenBy(row => row.Seat)];
    }

    /// <summary>
    /// Lists everyone on the player's map for the map box: the party's members first, its leader
    /// before the others by name, then the other players by name, each with their Frontline's
    /// highest level. Only the party's members keep a badge.
    /// </summary>
    /// <remarks>
    /// In a Raid World everyone on the map counts, elsewhere only the party's members, as the world's
    /// scope shares the map with them.
    /// </remarks>
    /// <param name="room">The world's room.</param>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="name">The player's name.</param>
    /// <returns>The players, the player included; none while nobody else is on the map.</returns>
    public static IReadOnlyList<OverviewRow> Map(WorldRoom room, OverviewState state, string name)
    {
        ArgumentNullException.ThrowIfNull(room);
        if (!room.InWorld || (!room.Raid && room.Party.Id is null))
        {
            return [];
        }

        List<Peer> here = [.. Named(room.Peers.Where(peer => peer.Present && WorldFields.ToI(peer.State["map"]) == room.OwnMap && (room.Raid || peer.Member)))];
        if (here.Count == 0)
        {
            return [];
        }

        List<OverviewRow> rows = [Own(room, state, name, state.Front), .. here.Select(peer => Of(room, peer, peer.State["flv"]))];
        return [.. rows.Select(row => row.Member ? row : row with { Badge = null })
            .OrderBy(row => row.Member ? 0 : 1).ThenBy(row => row.Badge is { Leads: true } ? 0 : 1)
            .ThenBy(row => RubyAscii.Downcase(row.Name), StringComparer.Ordinal).ThenBy(row => row.Seat)];
    }

    /// <summary>
    /// Lays the Players page out: a heading per place, the player's own first and the others by
    /// name, each followed by its players by name, the player first.
    /// </summary>
    /// <param name="rows">The players, the player first, see <see cref="Players"/>.</param>
    /// <returns>The lines.</returns>
    public static IReadOnlyList<OverviewLine> Lines(IReadOnlyList<OverviewRow> rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        if (rows.Count == 0)
        {
            return [];
        }

        string own = rows[0].Place;
        return [.. rows.GroupBy(row => row.Place, StringComparer.Ordinal)
            .OrderBy(group => group.Key == own ? 0 : 1).ThenBy(group => RubyAscii.Downcase(group.Key), StringComparer.Ordinal).ThenBy(group => group.Key, StringComparer.Ordinal)
            .SelectMany(group => new[] { new OverviewLine(group.Key.Length == 0 ? UnnamedPlace : group.Key, null) }
                .Concat(group.OrderBy(row => row.Seat == OverviewRow.Me ? 0 : 1).ThenBy(row => RubyAscii.Downcase(row.Name), StringComparer.Ordinal).ThenBy(row => row.Seat)
                    .Select(row => new OverviewLine(null, row))))];
    }

    /// <summary>
    /// Writes a level the way the lists show it.
    /// </summary>
    /// <param name="level">The level.</param>
    /// <returns>Such as "Lv 30", empty while unknown.</returns>
    public static string LevelText(long level) => level > 0 ? "Lv " + level.ToString(CultureInfo.InvariantCulture) : string.Empty;

    /// <summary>
    /// Builds the player's own row.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="name">The name it shows.</param>
    /// <param name="level">The level it shows.</param>
    /// <returns>The row.</returns>
    private static OverviewRow Own(WorldRoom room, OverviewState state, string name, int? level) =>
        new(OverviewRow.Me, name, state.Place, LevelText(level ?? 0), OverviewText.StoryText(state.Story), room.Ping?.ToString(CultureInfo.InvariantCulture) ?? string.Empty,
            string.Empty, room.Party.Members.Any(), Badge(room, room.Party.Id, null));

    /// <summary>
    /// Builds another player's row from what they last told.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="peer">The player.</param>
    /// <param name="level">The level it shows, as they told it.</param>
    /// <returns>The row.</returns>
    private static OverviewRow Of(WorldRoom room, Peer peer, string? level) =>
        new(peer.Seat, peer.State.Text("name"), peer.State.Text("place"), LevelText(WorldFields.ToI(level)), OverviewText.StoryText(peer.State["progress"]),
            peer.State.Text("ping"), peer.State.Text("scene"), peer.Member, Badge(room, peer.State["party"], peer));

    /// <summary>
    /// Finds a player's badge: their party's size and whether they lead it.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="party">The party's id.</param>
    /// <param name="peer">The player, <see langword="null"/> for the player.</param>
    /// <returns>The badge, <see langword="null"/> outside a party of two or more.</returns>
    private static OverviewBadge? Badge(WorldRoom room, string? party, Peer? peer)
    {
        int size = room.Party.SizeOf(party);
        return size >= 2 ? new OverviewBadge($"{size} / {World.Party.MaxPlayers}", room.Party.Leads(peer)) : null;
    }

    /// <summary>
    /// Lists the other players who told a name.
    /// </summary>
    /// <param name="peers">The players.</param>
    /// <returns>Those who did, in their order.</returns>
    private static IEnumerable<Peer> Named(IEnumerable<Peer> peers) => peers.Where(peer => peer.State.Has("name"));
}
