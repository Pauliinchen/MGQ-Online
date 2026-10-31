//----------------------------------------------------------------
//  OverviewRow.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Overview;

/// <summary>
/// A player of the World overview's lists and the party box, as the player's game knows them.
/// </summary>
/// <param name="Seat">Their game's seat, <see cref="Me"/> for the player.</param>
/// <param name="Name">Their name.</param>
/// <param name="Place">Where they are.</param>
/// <param name="Level">Their highest level as the list shows it, such as "Lv 30"; empty while unknown.</param>
/// <param name="Story">Their place in the story as the overview writes it, empty while unknown.</param>
/// <param name="Ping">Their ping in milliseconds as told, empty while unknown.</param>
/// <param name="Scene">What they do, a key of the overworld's state icons; empty for nothing.</param>
/// <param name="Member">Whether they are in the player's party; for the player, whether they are in a party at all.</param>
/// <param name="Badge">Their party's badge, <see langword="null"/> outside a party of two or more.</param>
public sealed record OverviewRow(int Seat, string Name, string Place, string Level, string Story, string Ping, string Scene, bool Member, OverviewBadge? Badge)
{
    /// <summary>
    /// The seat that stands for the player.
    /// </summary>
    public const int Me = -1;
}
