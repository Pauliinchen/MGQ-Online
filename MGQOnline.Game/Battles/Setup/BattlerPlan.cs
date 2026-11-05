//----------------------------------------------------------------
//  BattlerPlan.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// What the factory gives a battler it builds, see <see cref="BattlerSetup"/>.
/// </summary>
/// <param name="Hp">The HP it starts with, <see langword="null"/> for the full HP of its build.</param>
/// <param name="Mp">The MP it starts with, <see langword="null"/> for the full MP of its build.</param>
/// <param name="Start">Whether it gets the game's own battle start now.</param>
/// <param name="Hide">Whether the enemy stands hidden.</param>
/// <param name="LayDown">Whether the enemy stands fallen.</param>
public sealed record BattlerPlan(long? Hp, long? Mp, bool Start, bool Hide, bool LayDown);
