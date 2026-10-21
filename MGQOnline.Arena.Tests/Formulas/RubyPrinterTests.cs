//----------------------------------------------------------------
//  RubyPrinterTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Tests the canonical Ruby text of formula trees.
/// </summary>
public sealed class RubyPrinterTests
{
    /// <summary>
    /// Prints text that reads back to the same text and value, so printing is stable and keeps the
    /// meaning.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <param name="value">Its value.</param>
    /// <param name="isInteger">Whether the value is an integer.</param>
    /// <param name="printed">Its printed text.</param>
    [Theory]
    [MemberData(nameof(FormulaCorpus.Accepted), MemberType = typeof(FormulaCorpus))]
    [MemberData(nameof(FormulaCorpus.FixtureFormulas), MemberType = typeof(FormulaCorpus))]
    public void PrintsTextThatReadsBack(string text, double value, bool isInteger, string printed)
    {
        FormulaParse reread = FormulaParser.Parse(RubyPrinter.Print(FormulaParser.Parse(text).Root!));

        Assert.True(reread.IsValid, $"{text}: {reread.ErrorCode} at {reread.Index}");
        Assert.Equal(printed, RubyPrinter.Print(reread.Root));
        Assert.True(FormulaEvaluator.TryEvaluate(reread.Root, FormulaCorpus.User, FormulaCorpus.Target, out FormulaValue result));
        Assert.Equal((value, isInteger), (result.AsDouble, result.IsInteger));
    }

    /// <summary>
    /// Brackets what Ruby would otherwise read in another order, and nothing else.
    /// </summary>
    [Fact]
    public void BracketsOnlyWhereNeeded()
    {
        FormulaNumber one = new("1");
        FormulaNumber two = new("2");
        FormulaNumber three = new("3");

        Assert.Equal("1 - (2 - 3)", RubyPrinter.Print(new FormulaBinary(FormulaOperator.Subtract, one, new FormulaBinary(FormulaOperator.Subtract, two, three))));
        Assert.Equal("1 - 2 - 3", RubyPrinter.Print(new FormulaBinary(FormulaOperator.Subtract, new FormulaBinary(FormulaOperator.Subtract, one, two), three)));
        Assert.Equal("(1 + 2) * 3", RubyPrinter.Print(new FormulaBinary(FormulaOperator.Multiply, new FormulaBinary(FormulaOperator.Add, one, two), three)));
        Assert.Equal("1 / (2 * 3)", RubyPrinter.Print(new FormulaBinary(FormulaOperator.Divide, one, new FormulaBinary(FormulaOperator.Multiply, two, three))));
        Assert.Equal("-2 * 3", RubyPrinter.Print(new FormulaBinary(FormulaOperator.Multiply, new FormulaNegate(two), three)));
        Assert.Equal("-(2 * 3)", RubyPrinter.Print(new FormulaNegate(new FormulaBinary(FormulaOperator.Multiply, two, three))));
        Assert.Equal("(-2).abs", RubyPrinter.Print(new FormulaMethod(FormulaMethodName.Abs, new FormulaNegate(two))));
        Assert.Equal("-(2).abs", RubyPrinter.Print(new FormulaNegate(new FormulaMethod(FormulaMethodName.Abs, two))));
    }

    /// <summary>
    /// Prints a clamp as the lists Ruby has, and every stat and method by its Ruby name.
    /// </summary>
    [Fact]
    public void PrintsRubyNames()
    {
        FormulaNode clamp = new FormulaClamp(new FormulaStat(FormulaSubject.Target, FormulaStatName.Level), new FormulaNumber("1"), new FormulaStat(FormulaSubject.User, FormulaStatName.Mmp));

        Assert.Equal("[[b.level, 1].max, a.mmp].min", RubyPrinter.Print(clamp));
        Assert.Equal("(1.0).to_i", RubyPrinter.Print(new FormulaMethod(FormulaMethodName.ToInteger, new FormulaNumber("1.0"))));
        Assert.Equal("(1).to_f", RubyPrinter.Print(new FormulaMethod(FormulaMethodName.ToFloat, new FormulaNumber("1"))));
    }

    /// <summary>
    /// Refuses a number whose text the parser would not read, so a tree from JSON cannot carry other
    /// text into the game's eval.
    /// </summary>
    /// <param name="text">The number's text.</param>
    [Theory]
    [InlineData("")]
    [InlineData("1; system('x')")]
    [InlineData("01")]
    [InlineData("1.")]
    [InlineData(".5")]
    [InlineData("1.2.3")]
    [InlineData("-1")]
    [InlineData("1e5")]
    [InlineData("99999999999999999999")]
    public void RefusesNumbersOutsideTheGrammar(string text) =>
        Assert.Throws<System.ArgumentException>(() => RubyPrinter.Print(new FormulaBinary(FormulaOperator.Add, new FormulaNumber("1"), new FormulaNumber(text))));
}
