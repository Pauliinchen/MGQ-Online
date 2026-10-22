//----------------------------------------------------------------
//  SimulationVector.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Took the main target in the log hash
//      Paulinchen  2026-10-21: Played the reference battle through the arena's casting part and rule engine
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Tools.AotProbe;

/// <summary>
/// Plays the arena tests' reference battle through the arena's casting part and rule engine and
/// prints its battle log hash.
/// </summary>
internal static class SimulationVector
{
    /// <summary>
    /// The SHA-256 of the reference battle's log, as the arena tests hold it.
    /// </summary>
    public const string LogSha256 = "ee11af59261cbd8140ef6389f678a811f2fca44917804d16ac3ad541202ab046";

    /// <summary>
    /// The embedded reference design, the arena tests' fixture.
    /// </summary>
    private const string DesignResource = "referenceDesign.json";

    /// <summary>
    /// The cells of the reference battle's units.
    /// </summary>
    private static readonly GridCell[] Cells = [new(0, 0), new(2, 1), new(4, 2), new(6, 3), new(8, 0), new(10, 1), new(12, 2), new(14, 3)];

    /// <summary>
    /// Plays the reference battle, prints its log hash and checks it.
    /// </summary>
    /// <returns>Whether the hash matches the tests' golden one.</returns>
    public static bool Print()
    {
        using Stream stream = typeof(SimulationVector).Assembly.GetManifestResourceStream(DesignResource)
            ?? throw new InvalidOperationException("The reference design is not embedded.");
        RuntimeDesign design = JsonSerializer.Deserialize(stream, ArenaJsonContext.Default.RuntimeDesign)!;
        BattleSetup setup = new(
            "Test",
            null,
            [.. Cells.Select(cell => new PartyUnitSetup(cell, 1000, new FormulaStats(1000, 100, 50, 50, 50, 50, 50, 50, 1000, 100, 10), CharacterKind.Female, 1000, new Dictionary<int, double>(), new Dictionary<int, double>()))],
            10,
            new HashSet<int>(),
            88,
            42);
        SimulationReport report = SimulationRunner.Run(new BattleSimulator(design), setup, 8, PartyPolicies.PartyAttack(50, HitKind.Physical, PartyPolicies.RandomStep(1)));
        Console.WriteLine($"simulation events {report.Log.Count} outcome {report.Outcome} log sha256 {report.LogSha256}");
        return report.LogSha256 == LogSha256;
    }
}
