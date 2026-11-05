//----------------------------------------------------------------
//  BattlerOrder.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// A battler the factory builds, see <see cref="BattlerSetup"/>.
/// </summary>
/// <param name="Kind">Whether it is another player's character or an enemy.</param>
/// <param name="Started">Whether the game's battle start already ran in this game.</param>
/// <param name="Hp">The HP its owner sent, <see langword="null"/> for none.</param>
/// <param name="Mp">The MP its owner sent, <see langword="null"/> for none.</param>
/// <param name="Mark">An enemy's mark from the host's troop, see <see cref="BattlerSetup.Shown"/>.</param>
public sealed record BattlerOrder(BattlerKind Kind, bool Started, long? Hp, long? Mp, long Mark);
