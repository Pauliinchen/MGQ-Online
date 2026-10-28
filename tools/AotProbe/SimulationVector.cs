//----------------------------------------------------------------
//  SimulationVector.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Took the stage start and turn events in the reference log hashes
//      Paulinchen  2026-10-24: Took the turn row ids of the battle plan in the reference log hashes
//      Paulinchen  2026-10-23: Took the hazard reference battle's hash of the battlefield arena
//      Paulinchen  2026-10-22: Played the hazard reference battle too
//                            - Took the seats of rule fires in the log hash
//                            - Took the main target in the log hash
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
/// Plays the arena tests' reference battles through the arena's casting part and rule engine and
/// prints their battle log hashes.
/// </summary>
internal static class SimulationVector
{
    /// <summary>
    /// The SHA-256 of the reference battle's log, as the arena tests hold it.
    /// </summary>
    public const string LogSha256 = "50257b81cd45aabfff09bfe4638c4356e50d71f0f1ae72f9e25fb412a1983e13";

    /// <summary>
    /// The SHA-256 of the hazard reference battle's log, as the arena tests hold it.
    /// </summary>
    public const string HazardLogSha256 = "1b2255b5684f4561e41d0dcbbdb700b1d68c6af3d60d7bfe6be38b677be283f7";

    /// <summary>
    /// The embedded reference design, the arena tests' fixture.
    /// </summary>
    private const string DesignResource = "referenceDesign.json";

    /// <summary>
    /// The embedded hazard reference design, the arena tests' fixture.
    /// </summary>
    private const string HazardDesignResource = "hazardDesign.json";

    /// <summary>
    /// The cells of the reference battle's units.
    /// </summary>
    private static readonly GridCell[] Cells = [new(0, 0), new(2, 1), new(4, 2), new(6, 3), new(8, 0), new(10, 1), new(12, 2), new(14, 3)];

    /// <summary>
    /// Plays the reference battles, prints their log hashes and checks them.
    /// </summary>
    /// <returns>Whether both hashes match the tests' golden ones.</returns>
    public static bool Print() => Play("simulation", DesignResource, LogSha256) & Play("hazards", HazardDesignResource, HazardLogSha256);

    /// <summary>
    /// Plays one reference battle, prints its log hash and checks it.
    /// </summary>
    /// <param name="label">The line's label.</param>
    /// <param name="resource">The embedded design.</param>
    /// <param name="expected">The tests' golden hash.</param>
    /// <returns>Whether the hash matches.</returns>
    private static bool Play(string label, string resource, string expected)
    {
        using Stream stream = typeof(SimulationVector).Assembly.GetManifestResourceStream(resource)
            ?? throw new InvalidOperationException($"The design {resource} is not embedded.");
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
        Console.WriteLine($"{label} events {report.Log.Count} outcome {report.Outcome} log sha256 {report.LogSha256}");
        return report.LogSha256 == expected;
    }
}
