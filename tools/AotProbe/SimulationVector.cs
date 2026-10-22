//----------------------------------------------------------------
//  SimulationVector.cs
//
//  Changelog:
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
    public const string LogSha256 = "71e4be2607e864ea5f340ddc071c602395df50d297e3ed08da6de590575313d5";

    /// <summary>
    /// The SHA-256 of the hazard reference battle's log, as the arena tests hold it.
    /// </summary>
    public const string HazardLogSha256 = "3008288c6b077081788bac20b2b1a4f9215a38364507885fe95f233fc2eacfe4";

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
