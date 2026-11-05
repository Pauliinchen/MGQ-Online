//----------------------------------------------------------------
//  CoopFacts.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Told whether the player types in the chat box, which keeps an invite waiting
//      Paulinchen  2026-10-30: Told whether the player is in a battle, also under a screen its party command called
//                            - Told the player's step, the co-op party, a late join and the running battles the player asked to join or gave up on
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Coop;

/// <summary>
/// What only the game can tell of the player for the co-op battles' matchmaking, as the scripts
/// hand it over with each call.
/// </summary>
/// <param name="Map">The player's map.</param>
/// <param name="X">The player's tile x.</param>
/// <param name="Y">The player's tile y.</param>
/// <param name="Role">The player's role in a live battle, "host" or "guest", <see langword="null"/> for none.</param>
/// <param name="BattleId">The live battle's id, <see langword="null"/> for none.</param>
/// <param name="Seats">The live battle's seats of the other games.</param>
/// <param name="Coop">Whether the live battle is a co-op battle.</param>
/// <param name="Running">Whether a multiplayer battle's rules run.</param>
/// <param name="Kind">The kind of multiplayer battle whose rules run, such as "coop", <see langword="null"/> for none.</param>
/// <param name="Pvp">Whether a PvP battle runs.</param>
/// <param name="Memory">Whether the battle set up is a Library replay.</param>
/// <param name="BattleScene">Whether the scene is a battle's.</param>
/// <param name="Interpreter">Whether an event of the map runs.</param>
/// <param name="Trading">Whether the player takes part in a trade.</param>
/// <param name="Coming">Whether the leader's story is about to bring the player over.</param>
/// <param name="Transfer">Whether the player is about to move to another place.</param>
/// <param name="Moving">Whether the player walks a step.</param>
/// <param name="Active">Whether a co-op battle's party stands in for the player's.</param>
/// <param name="Late">Whether the player joins a running battle late, which sends its roster at its next command phase.</param>
/// <param name="OwnTroop">Whether the player joins a running battle late for their own encounter.</param>
/// <param name="HotAsk">The host and battle the player asks to take their encounter in, <see langword="null"/> for none.</param>
/// <param name="GaveUp">The host and battle the player stopped waiting for after asking to join it, <see langword="null"/> for none.</param>
/// <param name="Fronting">Whether the player started a battle the battle server hosts and passes requests to join it on.</param>
/// <param name="Story">Whether the invite that waits for the player belongs to the story that calls them over.</param>
/// <param name="InBattle">Whether the player is in a battle: in its scene, or in a screen its party command called.</param>
/// <param name="Typing">Whether the player types in the chat box.</param>
public sealed record CoopFacts(
    long Map,
    long X,
    long Y,
    string? Role,
    string? BattleId,
    IReadOnlyList<int> Seats,
    bool Coop,
    bool Running,
    string? Kind,
    bool Pvp,
    bool Memory,
    bool BattleScene,
    bool Interpreter,
    bool Trading,
    bool Coming,
    bool Transfer = false,
    bool Moving = false,
    bool Active = false,
    bool Late = false,
    bool OwnTroop = false,
    (int Seat, string BattleId)? HotAsk = null,
    (int Seat, string BattleId)? GaveUp = null,
    bool Fronting = false,
    bool Story = false,
    bool InBattle = false,
    bool Typing = false)
{
    /// <summary>
    /// Gets the facts of a player on no map, in no battle.
    /// </summary>
    public static CoopFacts None { get; } = new(0, 0, 0, null, null, [], false, false, null, false, false, false, false, false, false);

    /// <summary>
    /// Gets a value indicating whether the player is free on the map to join a battle: no event of
    /// theirs runs, they neither move to another place nor walk a step, nor type in the chat box.
    /// </summary>
    public bool Free => !Interpreter && !Transfer && !Moving && !Typing;
}
