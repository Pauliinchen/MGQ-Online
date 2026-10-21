//----------------------------------------------------------------
//  Format1Goldens.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text.Json.Nodes;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Grids;

/// <summary>
/// Reads the golden fixtures of the designer's old rules and turns their format-1 inputs into the arena's model.
/// </summary>
/// <remarks>
/// The old targeting modes map to the new names (GameRoll to random character, Character to picked
/// character, Cluster to most hit), and the old random kind to the telegraphed strikes the game rule
/// makes of it: a single hit at a random character, aimed anew each pulse.
/// </remarks>
internal static class Format1Goldens
{
    /// <summary>
    /// Gets the shape limits of the old designer's largest grid, 16 x 10.
    /// </summary>
    public static ShapeLimits Limits { get; } = new(new GridSize(16, 10));

    /// <summary>
    /// Reads a golden fixture.
    /// </summary>
    /// <param name="name">The fixture's name without extension.</param>
    /// <param name="source">This file's path, filled in by the compiler.</param>
    /// <returns>The fixture's root object.</returns>
    public static JsonObject Load(string name, [CallerFilePath] string source = "")
    {
        string path = Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(source))!, "Fixtures", "golden", name + ".json");
        return JsonNode.Parse(File.ReadAllText(path))!.AsObject();
    }

    /// <summary>
    /// Lists a fixture's cases, optionally only those of a kind.
    /// </summary>
    /// <param name="fixture">The fixture.</param>
    /// <param name="kind">The kind, null for the cases without one.</param>
    /// <returns>The cases.</returns>
    /// <exception cref="InvalidOperationException">The fixture has no such case, so a test would check nothing.</exception>
    public static IReadOnlyList<JsonObject> Cases(JsonObject fixture, string? kind = null)
    {
        List<JsonObject> cases = fixture["cases"]!.AsArray().Select(node => node!.AsObject()).Where(node => (string?)node["kind"] == kind).ToList();
        return cases.Count > 0 ? cases : throw new InvalidOperationException($"The fixture has no cases of kind {kind ?? "(none)"}.");
    }

    /// <summary>
    /// Builds the game rule the fixtures assume: the sample rule with the old largest grid and the free cells per unit.
    /// </summary>
    /// <param name="freeCellsPerCharacter">The free cells per unit.</param>
    /// <returns>The rule.</returns>
    public static GameRules Rules(int freeCellsPerCharacter = 2) => Samples.GameRules with
    {
        Grid = Samples.GameRules.Grid with { Max = new GridSize(16, 10) },
        Debris = Samples.GameRules.Debris with { FreeCellsPerCharacter = freeCellsPerCharacter },
    };

    /// <summary>
    /// Reads a grid size [cols, rows].
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The size.</returns>
    public static GridSize Size(JsonNode? node) => new((int)node![0]!, (int)node[1]!);

    /// <summary>
    /// Reads a cell [x, y].
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The cell.</returns>
    public static GridCell Cell(JsonNode? node) => new((int)node![0]!, (int)node[1]!);

    /// <summary>
    /// Reads a cell that may be null.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The cell, or null.</returns>
    public static GridCell? CellOrNull(JsonNode? node) => node is null ? null : Cell(node);

    /// <summary>
    /// Reads a list of cells.
    /// </summary>
    /// <param name="node">The node, null for none.</param>
    /// <returns>The cells.</returns>
    public static IReadOnlyList<GridCell> Cells(JsonNode? node) => node is null ? [] : node.AsArray().Select(Cell).ToList();

    /// <summary>
    /// Reads a format-1 shape.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The shape; an absent fit clips.</returns>
    public static ShapeSpec Shape(JsonNode? node)
    {
        JsonObject shape = node!.AsObject();
        return new ShapeSpec(
            Parse<ShapeType>(shape["type"]),
            shape["fit"] is null ? ShapeFit.Clip : Parse<ShapeFit>(shape["fit"]),
            (int?)shape["size"],
            (int?)shape["width"],
            (int?)shape["height"],
            (int?)shape["radius"],
            (int?)shape["arm"],
            (int?)shape["thickness"],
            shape["direction"] is null ? null : Parse<LineDirection>(shape["direction"]),
            (int?)shape["length"],
            shape["metric"] is null ? null : Parse<DistanceMetric>(shape["metric"]),
            shape["offsets"] is null ? null : Cells(shape["offsets"]));
    }

    /// <summary>
    /// Reads a format-1 zone.
    /// </summary>
    /// <param name="node">The node, null for the whole grid.</param>
    /// <returns>The zone.</returns>
    public static ZoneSpec? Zone(JsonNode? node)
    {
        if (node is null)
        {
            return null;
        }

        JsonObject zone = node.AsObject();
        return new ZoneSpec((int?)zone["frontRows"], (int?)zone["backRows"], (int?)zone["middleColumns"], zone["cells"] is null ? null : Cells(zone["cells"]));
    }

    /// <summary>
    /// Reads a format-1 targeting under the new mode names.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The targeting.</returns>
    public static TargetSpec Targeting(JsonNode? node)
    {
        JsonObject targeting = node!.AsObject();
        TargetMode mode = (string?)targeting["mode"] switch
        {
            "RandomCell" => TargetMode.RandomCell,
            "Character" => TargetMode.PickedCharacter,
            "Cluster" => TargetMode.MostHit,
            _ => TargetMode.RandomCharacter,
        };
        return new TargetSpec(
            mode,
            (bool?)targeting["newTargetEachPulse"] ?? false,
            targeting["pick"] is null ? null : Parse<TargetPick>(targeting["pick"]),
            Zone(targeting["zone"]));
    }

    /// <summary>
    /// Reads a format-1 resolved skill.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <param name="targeting">The targeting that replaces the skill's, null to keep it.</param>
    /// <returns>The skill.</returns>
    public static RuntimeSkill Skill(JsonNode? node, JsonNode? targeting = null)
    {
        JsonObject skill = node!.AsObject();
        JsonObject spread = skill["spread"]!.AsObject();
        JsonObject falloff = skill["falloff"]!.AsObject();
        string kind = (string)skill["kind"]!;
        bool strikes = kind == "Random";
        TargetSpec target = Targeting(targeting ?? skill["targeting"]);
        if (strikes)
        {
            target = target with { Mode = TargetMode.RandomCharacter, NewTargetEachPulse = true };
        }

        SkillDebrisSpec? debris = skill["debris"] is JsonObject leaves && (string?)leaves["where"] != "None"
            ? new SkillDebrisSpec(Parse<DebrisPlace>(leaves["where"]), (int?)leaves["turns"] ?? 0, (int?)leaves["hits"] ?? 0, (int?)leaves["count"])
            : null;
        return new RuntimeSkill(
            SkillRef.OfGame((int)skill["skillId"]!),
            strikes ? SkillKind.Single : Parse<SkillKind>(skill["kind"]),
            Shape(skill["shape"]),
            (int)skill["pulses"]!,
            1,
            0,
            false,
            target,
            new DamageSpec((double)skill["damage"]!["percent"]!),
            new SpreadSpec(
                Parse<SpreadMode>(spread["mode"]),
                (int?)spread["range"] ?? (int)skill["shareRange"]!,
                (int?)spread["maxSharers"] ?? (int)skill["shareMax"]!,
                (double?)spread["percent"] ?? 50,
                spread["metric"] is null ? DistanceMetric.Chebyshev : Parse<DistanceMetric>(spread["metric"]),
                spread["statesLandOn"] is null ? StateLanding.EveryoneHit : Parse<StateLanding>(spread["statesLandOn"]),
                spread["shape"] is null ? null : Shape(spread["shape"]),
                spread["rings"] is null ? null : Doubles(spread["rings"])),
            new FalloffSpec(Parse<DistanceMetric>(falloff["metric"]), Doubles(falloff["rings"]), (bool)skill["falloffApplies"]!),
            Samples.SupportSkill.Presentation,
            Samples.SupportSkill.Payload with { Damage = (bool)skill["hasDamage"]! },
            Samples.SupportSkill.Facts,
            debris);
    }

    /// <summary>
    /// Reads a format-1 sample party member as a unit with the normal target rate.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The unit.</returns>
    public static GridUnit Unit(JsonNode? node)
    {
        long maxHp = (long)node!["maxHp"]!;
        long hp = (long)Math.Round((double)node["hpRate"]! * maxHp, MidpointRounding.AwayFromZero);
        return new GridUnit((int)node["seat"]!, Cell(node["cell"]), hp, maxHp, (long)node["atk"]!, (long)node["mat"]!, 1000, []);
    }

    /// <summary>
    /// Reads a format-1 sample party.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The units in party order.</returns>
    public static IReadOnlyList<GridUnit> Party(JsonNode? node) => node!.AsArray().Select(Unit).ToList();

    /// <summary>
    /// Reads a list of numbers.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The numbers.</returns>
    public static IReadOnlyList<double> Doubles(JsonNode? node) => node!.AsArray().Select(value => (double)value!).ToList();

    /// <summary>
    /// Reads a format-1 debris cell list as written by the capture.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The debris field.</returns>
    public static DebrisField DebrisCells(JsonNode? node) =>
        DebrisField.Of(node!.AsArray().Select(entry => new DebrisCell(
            Cell(entry!["cell"]),
            Parse<DebrisOrigin>(entry["origin"]),
            entry["skill"] is null ? null : SkillRef.OfGame((int)entry["skill"]!),
            (int)entry["hits"]!,
            (int)entry["turns"]!,
            null)
        {
            MaxHits = (int)entry["maxHits"]!,
            PlacedThisTurn = (bool)entry["placedThisTurn"]!,
        }));

    /// <summary>
    /// Writes a debris field as the capture writes it, for comparison.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>One line per cell.</returns>
    public static IReadOnlyList<string> DebrisLines(DebrisField field) =>
        field.Cells.Select(debris => $"{debris.Cell.X},{debris.Cell.Y} {debris.Origin} {debris.Skill?.Game} {debris.Hits}/{debris.MaxHits} t{debris.Turns} {debris.PlacedThisTurn} {debris.Cracks}").ToList();

    /// <summary>
    /// Writes the format-1 debris list of a golden as <see cref="DebrisLines"/> does.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>One line per cell.</returns>
    public static IReadOnlyList<string> GoldenDebrisLines(JsonNode? node) =>
        node!.AsArray().Select(entry => $"{(int)entry!["cell"]![0]!},{(int)entry["cell"]![1]!} {(string)entry["origin"]!} {(int?)entry["skill"]} {(int)entry["hits"]!}/{(int)entry["maxHits"]!} t{(int)entry["turns"]!} {(bool)entry["placedThisTurn"]!} {(string)entry["cracks"]!}").ToList();

    /// <summary>
    /// Gives a battle's random streams for a fixture's seed.
    /// </summary>
    /// <param name="seed">The fixture's seed.</param>
    /// <returns>The streams.</returns>
    public static RandomStreams Streams(int seed) => new((ulong)seed);

    /// <summary>
    /// Writes cells for a failure message.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <returns>Such as "[0,0] [1,2]".</returns>
    public static string Text(IEnumerable<GridCell> cells) => string.Join(" ", cells.Select(cell => $"[{cell.X},{cell.Y}]"));

    /// <summary>
    /// Parses an enum value case-insensitively.
    /// </summary>
    /// <typeparam name="T">The enum.</typeparam>
    /// <param name="node">The node holding the name.</param>
    /// <returns>The value.</returns>
    public static T Parse<T>(JsonNode? node)
        where T : struct, Enum => Enum.Parse<T>((string)node!, ignoreCase: true);
}
