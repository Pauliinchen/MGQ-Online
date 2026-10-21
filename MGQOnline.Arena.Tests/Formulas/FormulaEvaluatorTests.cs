//----------------------------------------------------------------
//  FormulaEvaluatorTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Tests how formulas compute and how they fail whole.
/// </summary>
public sealed class FormulaEvaluatorTests
{
    /// <summary>
    /// Makes the whole formula 0 on a division or remainder by zero, a result that is not finite or an
    /// integer beyond 64 bits, also where a list or clamp would drop the failing part.
    /// </summary>
    /// <param name="text">The formula.</param>
    [Theory]
    [InlineData("a.atk / 0")]
    [InlineData("a.atk / 0.0")]
    [InlineData("a.atk % 0")]
    [InlineData("1.5 % 0")]
    [InlineData("5 + 0.0 % 0")]
    [InlineData("5 + 0 % 0.0")]
    [InlineData("5 + (a.atk - a.atk).to_f % 0")]
    [InlineData("0.0 / 0")]
    [InlineData("a.atk + 1 / (b.def - 50)")]
    [InlineData("[1 / 0, 5].max")]
    [InlineData("clamp(1 / 0.0, 0, 5)")]
    [InlineData("[a.atk / 0.0, 5].min")]
    [InlineData("a.mhp * a.mhp * a.mhp * a.mhp * a.mhp * a.mhp")]
    [InlineData("(-9223372036854775807 - 1).abs")]
    [InlineData("(-9223372036854775807 - 1) / -1")]
    [InlineData("-(-9223372036854775807 - 1)")]
    [InlineData("9223372036854775807 + 1")]
    [InlineData("(10000000000000000000.0).floor")]
    [InlineData("(10000000000000000000.0).to_i")]
    [InlineData("(-10000000000000000000.0).round")]
    public void FailsWholeToZero(string text)
    {
        FormulaNode formula = FormulaParser.Parse(text).Root!;

        Assert.False(FormulaEvaluator.TryEvaluate(formula, FormulaCorpus.User, FormulaCorpus.Target, out FormulaValue value));
        Assert.Equal(0, value.AsDouble);
        Assert.Equal(0, FormulaEvaluator.Evaluate(formula, FormulaCorpus.User, FormulaCorpus.Target));
    }

    /// <summary>
    /// Computes the formula vectors the AOT probe prints, to the same round-trip text, so the JIT on
    /// the test runners and NativeAOT on win-x86 and linux-x64 agree.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="expected">The value's round-trip text.</param>
    [Theory]
    [InlineData("a.atk * 2 * 1.5 - b.def / 2", "275")]
    [InlineData("a.mat * 2 * 1.4 - b.mdf / 2", "209")]
    [InlineData("(a.mat + 0.1) * 3 / 7.0", "34.32857142857143")]
    [InlineData("-7 / 2", "-4")]
    [InlineData("-7.5 % 2", "0.5")]
    [InlineData("6543.21 % 137", "104.21000000000004")]
    [InlineData("1.0 % 0.3", "0.10000000000000003")]
    [InlineData("(a.atk / 3.0).round", "33")]
    [InlineData("[a.atk / 7.0, b.def * 0.3].max", "15")]
    [InlineData("clamp(a.agi * 1.1, 0, 60)", "55.00000000000001")]
    [InlineData("a.atk / 0", "0")]
    [InlineData("(a.hp * 0.123456789).floor + a.mhp / 9.0", "1048.5555555555557")]
    public void ComputesTheProbeVectors(string text, string expected)
    {
        double value = FormulaEvaluator.Evaluate(FormulaParser.Parse(text).Root!, FormulaCorpus.User, FormulaCorpus.Target);

        Assert.Equal(expected, value.ToString("R", System.Globalization.CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Fails to 0 on a float product too large for a double.
    /// </summary>
    [Fact]
    public void FailsOnAnInfiniteProduct()
    {
        FormulaNumber huge = new("1" + new string('0', 200) + ".0");
        FormulaNode formula = new FormulaBinary(FormulaOperator.Multiply, huge, new FormulaBinary(FormulaOperator.Multiply, huge, huge));

        Assert.Equal(0, FormulaEvaluator.Evaluate(formula, FormulaCorpus.User, FormulaCorpus.Target));
    }

    /// <summary>
    /// Keeps a negative result, which the game raises to 0 later and the caller does here.
    /// </summary>
    [Fact]
    public void KeepsNegativeResults() =>
        Assert.Equal(-50, FormulaEvaluator.Evaluate(FormulaParser.Parse("b.def - a.atk").Root!, FormulaCorpus.User, FormulaCorpus.Target));

    /// <summary>
    /// Reads a by the user and b by the target.
    /// </summary>
    [Fact]
    public void ReadsUserAndTarget()
    {
        FormulaNode formula = FormulaParser.Parse("a.atk * 1000 + b.atk").Root!;

        Assert.Equal(100_070, FormulaEvaluator.Evaluate(formula, FormulaCorpus.User, FormulaCorpus.Target));
        Assert.Equal(70_100, FormulaEvaluator.Evaluate(formula, FormulaCorpus.Target, FormulaCorpus.User));
    }

    /// <summary>
    /// Fails to 0 on a tree no parser makes: a number that is not one, or an empty list.
    /// </summary>
    [Fact]
    public void FailsOnBrokenTrees()
    {
        Assert.Equal(0, FormulaEvaluator.Evaluate(new FormulaNumber("1e5"), FormulaCorpus.User, FormulaCorpus.Target));
        Assert.Equal(0, FormulaEvaluator.Evaluate(new FormulaNumber("-5"), FormulaCorpus.User, FormulaCorpus.Target));
        Assert.Equal(0, FormulaEvaluator.Evaluate(new FormulaExtreme(FormulaExtremeKind.Max, []), FormulaCorpus.User, FormulaCorpus.Target));
    }
}
