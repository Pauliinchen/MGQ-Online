//----------------------------------------------------------------
//  BattlerSetup.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// Decides how battles_battlers.rbx builds a battler the game's troop setup or party never made:
/// another player's character in a co-op battle, an enemy of another game's troop, or the other
/// side's Backline in a PvP battle. Each is made as the game makes its own, then given the
/// game's own battle start where the game's start never reaches it.
/// </summary>
public static class BattlerSetup
{
    /// <summary>
    /// The mark of an enemy the host shows.
    /// </summary>
    public const long Shown = 0;

    /// <summary>
    /// The mark of an enemy the host hides.
    /// </summary>
    public const long Hidden = 1;

    /// <summary>
    /// The mark of an enemy that fell on the host, or that the host's game hid as it was eaten.
    /// </summary>
    public const long Fallen = 2;

    /// <summary>
    /// Plans a battler.
    /// </summary>
    /// <remarks>
    /// The game's battle start reaches only its own party and the troop's members, so another
    /// player's character and the Backline are always started here, a character after its HP, since
    /// a trait's states for low HP come only at the start.
    /// </remarks>
    /// <param name="order">The battler and the battle as the factory finds them.</param>
    /// <returns>What the factory gives it.</returns>
    public static BattlerPlan Plan(BattlerOrder order) => order.Kind switch
    {
        BattlerKind.Ally => new BattlerPlan(order.Hp is >= 0 ? order.Hp : null, order.Mp, Start: true, Hide: false, LayDown: false),
        BattlerKind.Reserve => new BattlerPlan(null, null, Start: true, Hide: false, LayDown: false),
        _ => new BattlerPlan(null, null, Start: order.Started, Hide: order.Mark == Hidden, LayDown: order.Mark == Fallen),
    };
}
