//----------------------------------------------------------------
//  FormulaParserTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Tests what the formula grammar accepts, the trees it reads and what it refuses.
/// </summary>
public sealed class FormulaParserTests
{
    /// <summary>
    /// Reads every formula the format-1 fixture's boss and the compile2 golden use.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="value">Its value.</param>
    /// <param name="isInteger">Whether the value is an integer.</param>
    /// <param name="printed">Its printed text.</param>
    [Theory]
    [MemberData(nameof(FormulaCorpus.FixtureFormulas), MemberType = typeof(FormulaCorpus))]
    public void AcceptsTheFixtureFormulas(string text, double value, bool isInteger, string printed) =>
        AssertAccepted(text, value, isInteger, printed);

    /// <summary>
    /// Reads the accepted corpus.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="value">Its value.</param>
    /// <param name="isInteger">Whether the value is an integer.</param>
    /// <param name="printed">Its printed text.</param>
    [Theory]
    [MemberData(nameof(FormulaCorpus.Accepted), MemberType = typeof(FormulaCorpus))]
    public void AcceptsTheCorpus(string text, double value, bool isInteger, string printed) =>
        AssertAccepted(text, value, isInteger, printed);

    /// <summary>
    /// Refuses the refused corpus with its code at its index.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="code">The error code expected.</param>
    /// <param name="index">The index expected.</param>
    [Theory]
    [MemberData(nameof(FormulaCorpus.Refused), MemberType = typeof(FormulaCorpus))]
    public void RefusesTheCorpus(string text, string code, int index)
    {
        FormulaParse parse = FormulaParser.Parse(text);

        Assert.False(parse.IsValid);
        Assert.Null(parse.Root);
        Assert.Equal((code, index), (parse.ErrorCode, parse.Index));
    }

    /// <summary>
    /// Refuses a missing formula as empty.
    /// </summary>
    [Fact]
    public void RefusesNull() => Assert.Equal(FormulaErrors.Empty, FormulaParser.Parse(null).ErrorCode);

    /// <summary>
    /// Reads Ruby's precedence into the tree: products before sums, left to right.
    /// </summary>
    [Fact]
    public void ReadsThePrecedence()
    {
        FormulaNode expected = new FormulaBinary(
            FormulaOperator.Subtract,
            new FormulaBinary(FormulaOperator.Multiply, new FormulaStat(FormulaSubject.User, FormulaStatName.Atk), new FormulaNumber("4")),
            new FormulaBinary(FormulaOperator.Multiply, new FormulaStat(FormulaSubject.Target, FormulaStatName.Def), new FormulaNumber("2")));

        Assert.Equal(expected, FormulaParser.Parse("a.atk * 4 - b.def * 2").Root);
    }

    /// <summary>
    /// Reads a minus as a negation, drops a plus, and reads calls and lists as one node kind.
    /// </summary>
    [Fact]
    public void ReadsSignsCallsAndLists()
    {
        Assert.Equal(new FormulaNegate(new FormulaNumber("2")), FormulaParser.Parse("-2").Root);
        Assert.Equal(new FormulaNumber("3"), FormulaParser.Parse("+3").Root);
        Assert.Equal(FormulaParser.Parse("[1, 2.0].max").Root, FormulaParser.Parse("max(1, 2.0)").Root);
        Assert.NotEqual(FormulaParser.Parse("[1, 2].max").Root, FormulaParser.Parse("[1, 2].min").Root);
        Assert.Equal(
            new FormulaClamp(new FormulaStat(FormulaSubject.User, FormulaStatName.Luk), new FormulaNumber("0"), new FormulaNumber("10")),
            FormulaParser.Parse("clamp(a.luk, 0, 10)").Root);
        Assert.Equal(
            new FormulaMethod(FormulaMethodName.ToInteger, new FormulaMethod(FormulaMethodName.ToFloat, new FormulaNumber("2"))),
            FormulaParser.Parse("2.to_f.to_i").Root);
    }

    /// <summary>
    /// Accepts formulas right at each limit and refuses them one past it.
    /// </summary>
    [Fact]
    public void HoldsTheLimits()
    {
        string longest = new string(' ', FormulaLimits.MaxLength - 1) + "1";
        string deepest = new string('-', FormulaLimits.MaxDepth - 1) + "1";
        string widest = "[" + string.Join(", ", Enumerable.Repeat("1", FormulaLimits.MaxNodes - 1)) + "].max";

        Assert.True(FormulaParser.Parse(longest).IsValid);
        Assert.True(FormulaParser.Parse(deepest).IsValid);
        Assert.True(FormulaParser.Parse(string.Join(" + ", Enumerable.Repeat("1", FormulaLimits.MaxDepth))).IsValid);
        Assert.True(FormulaParser.Parse(widest).IsValid);
    }

    /// <summary>
    /// Refuses a deep nesting by its tree's height, not by its brackets, which make no node.
    /// </summary>
    [Fact]
    public void CountsNodesNotBrackets()
    {
        Assert.True(FormulaParser.Parse(new string('(', 60) + "1" + new string(')', 60)).IsValid);
        Assert.Equal(FormulaErrors.TooLong, FormulaParser.Parse(new string('(', 200) + "1" + new string(')', 200)).ErrorCode);
    }

    /// <summary>
    /// Checks a formula the grammar accepts: its value, kind and printed text.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="value">Its value.</param>
    /// <param name="isInteger">Whether the value is an integer.</param>
    /// <param name="printed">Its printed text.</param>
    private static void AssertAccepted(string text, double value, bool isInteger, string printed)
    {
        FormulaParse parse = FormulaParser.Parse(text);
        Assert.True(parse.IsValid, $"{parse.ErrorCode} at {parse.Index}");
        Assert.Equal((null, -1), (parse.ErrorCode, parse.Index));

        Assert.True(FormulaEvaluator.TryEvaluate(parse.Root, FormulaCorpus.User, FormulaCorpus.Target, out FormulaValue result));
        Assert.Equal((value, isInteger), (result.AsDouble, result.IsInteger));
        Assert.Equal(printed, RubyPrinter.Print(parse.Root));
    }
}
