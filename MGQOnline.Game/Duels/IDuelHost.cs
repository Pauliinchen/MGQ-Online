//----------------------------------------------------------------
//  IDuelHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Duels;

/// <summary>
/// What the duel handshake tells the scripts: notices to show, what it needs of the player's
/// team, and the duels that wait to start from the map.
/// </summary>
public interface IDuelHost
{
    /// <summary>
    /// Shows the player a notice at the bottom left of the map, logged as the scripts log theirs.
    /// </summary>
    /// <param name="text">The notice.</param>
    void Notice(string text);

    /// <summary>
    /// Asks the scripts for what only the game can tell of a team, which they answer through
    /// <see cref="DuelHandshake.TakeAnswer"/>.
    /// </summary>
    /// <param name="need">What is needed.</param>
    void NeedTeam(DuelNeed need);

    /// <summary>
    /// Hands the scripts a duel that waits to start from the map.
    /// </summary>
    /// <param name="start">The duel.</param>
    void Start(DuelStart start);
}
