//----------------------------------------------------------------
//  CatchupSettings.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Catchup;

/// <summary>
/// How the one catch-up engine runs in a world type: a Raid World's catch-up, or the one catch-up
/// of a Classic party's member who starts keeping the leader's story from behind it.
/// </summary>
/// <remarks>
/// The Classic values keep what a Classic member got before the engine took the Classic catch-up
/// over, but a used-up key item, which every world type takes (user answer 2026-11-01).
/// </remarks>
/// <param name="RaidWorld">Whether the outcomes of a choice are each player's own as a Raid World keeps them, else as a Classic party keeps them.</param>
/// <param name="LevelGates">Whether a companion the catch-up brings waits for the join's level and comes raised to it; otherwise they join at once at their own level.</param>
/// <param name="TakesCompanionsAway">Whether a companion leaves once a story carried the player past a lasting removal of theirs.</param>
/// <param name="ChoiceCompanionsFromRows">Whether the companions of a story choice come by the rows; otherwise only by the player's own answer to the choice.</param>
/// <param name="MedalKingFromRows">Whether the Medal King's prizes come by their rows too; otherwise by <see cref="MedalKingGift"/> alone.</param>
/// <param name="ChestsPastOwnStep">Whether a world chest the other story opened comes though the player's own story is past the chest's step.</param>
/// <param name="TakesUsedUpKeyItems">Whether a key item a row past uses up is taken.</param>
/// <param name="SideFromSwitches">Whether the side the player took along is read from their story's side switches while the save notes none; otherwise from the save's note alone.</param>
/// <param name="KeyItemsByPartyChests">Whether the key items the player lacks are owed once per row and come by the party chests that gave them first (<see cref="ClassicParty"/>).</param>
/// <param name="ActorChanges">Whether the story's actor changes run.</param>
/// <param name="SettlesValues">Whether the player's own values and the companions' story values follow the rows.</param>
/// <param name="UnlockItems">Whether the items unlocking a job or race come by their rows.</param>
public sealed record CatchupSettings(
    bool RaidWorld,
    bool LevelGates,
    bool TakesCompanionsAway,
    bool ChoiceCompanionsFromRows,
    bool MedalKingFromRows,
    bool ChestsPastOwnStep,
    bool TakesUsedUpKeyItems,
    bool SideFromSwitches,
    bool KeyItemsByPartyChests,
    bool ActorChanges,
    bool SettlesValues,
    bool UnlockItems)
{
    /// <summary>
    /// The catch-up of a Raid World.
    /// </summary>
    public static readonly CatchupSettings Raid = new(
        RaidWorld: true, LevelGates: true, TakesCompanionsAway: true, ChoiceCompanionsFromRows: true, MedalKingFromRows: true, ChestsPastOwnStep: true,
        TakesUsedUpKeyItems: true, SideFromSwitches: true, KeyItemsByPartyChests: false, ActorChanges: true, SettlesValues: true, UnlockItems: true);

    /// <summary>
    /// The catch-up of a Classic party's member who starts keeping the leader's story from behind it.
    /// </summary>
    public static readonly CatchupSettings Classic = new(
        RaidWorld: false, LevelGates: false, TakesCompanionsAway: false, ChoiceCompanionsFromRows: false, MedalKingFromRows: false, ChestsPastOwnStep: false,
        TakesUsedUpKeyItems: true, SideFromSwitches: false, KeyItemsByPartyChests: true, ActorChanges: false, SettlesValues: false, UnlockItems: false);
}
