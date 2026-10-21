//----------------------------------------------------------------
//  FormulaJsonTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Tests that formula trees go through the runtime model's JSON context.
/// </summary>
public sealed class FormulaJsonTests
{
    /// <summary>
    /// Writes every node kind with its type name and reads it back equal.
    /// </summary>
    [Fact]
    public void RoundTripsEveryNodeKind()
    {
        FormulaNode formula = FormulaParser.Parse("-[a.atk, clamp(b.luk, 0, 5)].max * 2.50 + (a.mat % 3).to_f.abs - max(1)").Root!;

        string json = JsonSerializer.Serialize(formula, ArenaJsonContext.Default.FormulaNode);
        FormulaNode? read = JsonSerializer.Deserialize(json, ArenaJsonContext.Default.FormulaNode);

        Assert.Equal(formula, read);
        foreach (string type in new[] { "number", "stat", "negate", "binary", "method", "extreme", "clamp" })
        {
            Assert.Contains($"\"type\":\"{type}\"", json, System.StringComparison.Ordinal);
        }
    }

    /// <summary>
    /// Writes a number as the text typed, so a float keeps its point and digits.
    /// </summary>
    [Fact]
    public void WritesNumbersAsTyped() =>
        Assert.Equal("{\"type\":\"number\",\"text\":\"1.50\"}", JsonSerializer.Serialize<FormulaNode>(new FormulaNumber("1.50"), ArenaJsonContext.Default.FormulaNode));

    /// <summary>
    /// Writes a formula with its printed text and its tree, enums as lowerCamel names.
    /// </summary>
    [Fact]
    public void WritesTheTextBesideTheTree()
    {
        FormulaNode root = FormulaParser.Parse("(a.atk / 3).to_i").Root!;

        string json = JsonSerializer.Serialize(new FormulaSpec(RubyPrinter.Print(root), root), ArenaJsonContext.Default.FormulaSpec);

        Assert.Equal(
            "{\"text\":\"(a.atk / 3).to_i\",\"ast\":{\"type\":\"method\",\"method\":\"toInteger\",\"target\":{\"type\":\"binary\",\"operator\":\"divide\",\"left\":{\"type\":\"stat\",\"subject\":\"user\",\"stat\":\"atk\"},\"right\":{\"type\":\"number\",\"text\":\"3\"}}}}",
            json);
    }
}
