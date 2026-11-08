//----------------------------------------------------------------
//  AllyStep.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// One step of building another player's character, see <see cref="BattlerSetup.AllySteps"/>.
/// </summary>
/// <param name="Changer">The game's changer it applies.</param>
/// <param name="Values">What it hands the changer: a job's or race's id and level, a level, skill
/// ids, a stat's id and growth, ability ids, or a slot.</param>
public sealed record AllyStep(AllyChanger Changer, IReadOnlyList<long> Values);
