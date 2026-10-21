//----------------------------------------------------------------
//  DamageFormulaParityTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Formulas;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Repeats the cases of the designer's old DamageFormula tests (RaidDesigner.Tests/RuleFormulaTests.cs)
/// with the same stats, so the grammar keeps what the old reader accepted and refused.
/// </summary>
public sealed class DamageFormulaParityTests
{
    /// <summary>
    /// Computes the formulas the old reader computed, to the same values.
    /// </summary>
    /// <param name="formula">The formula.</param>
    /// <param name="expected">The old reader's value.</param>
    [Theory]
    [InlineData("a.atk * 4 - b.def * 2", 300)]
    [InlineData("a.atk * 2 * 1.5 - b.def / 2", 275)]
    [InlineData("7 / 2", 3)]
    [InlineData("7 / 2.0", 3.5)]
    [InlineData("-7 / 2", -4)]
    [InlineData("7 % 3", 1)]
    [InlineData("-7 % 3", 2)]
    [InlineData("(a.mat + b.mdf) * 2", 220)]
    [InlineData("[a.atk, b.def].max", 100)]
    [InlineData("[a.atk - 200, 0, 5].min", -100)]
    [InlineData("-(a.level) + +3", -27)]
    [InlineData("a.hp / 4 + b.mhp", 2000)]
    [InlineData("-a.atk + 5", -95)]
    [InlineData("(-b.def) * 2", -100)]
    [InlineData("a.atk * -1", -100)]
    [InlineData("a.atk*-1", -100)]
    [InlineData("a.atk-b.def", 50)]
    [InlineData("5 -2", 3)]
    [InlineData("(a.atk) -1", 99)]
    [InlineData("[a.atk, 1].max - 1", 99)]
    [InlineData("0.5 * a.atk + 0", 50)]
    public void ComputesWhatTheOldReaderComputed(string formula, double expected)
    {
        FormulaParse parse = FormulaParser.Parse(formula);

        Assert.True(parse.IsValid, parse.ErrorCode);
        Assert.Equal(expected, FormulaEvaluator.Evaluate(parse.Root, FormulaCorpus.User, FormulaCorpus.Target));
    }

    /// <summary>
    /// Refuses what the old reader refused, the power operator and nesting included.
    /// </summary>
    /// <param name="formula">The formula.</param>
    [Theory]
    [InlineData("")]
    [InlineData("a.atk * 2 if true")]
    [InlineData("system('calc')")]
    [InlineData("`calc`")]
    [InlineData("a.send(:exit)")]
    [InlineData("a.atk ** 2")]
    [InlineData("v[1] * 2")]
    [InlineData("a.atk +")]
    [InlineData("(1 + 2")]
    [InlineData("a.foo")]
    [InlineData("1; 2")]
    [InlineData("eval(\"1\")")]
    [InlineData("a.atk > 5 ? 1 : 2")]
    [InlineData("[1, 2].sum")]
    [InlineData("Kernel.exit")]
    [InlineData("a.atk * rand(3)")]
    public void RefusesWhatTheOldReaderRefused(string formula)
    {
        FormulaParse parse = FormulaParser.Parse(formula);

        Assert.False(parse.IsValid);
        Assert.False(string.IsNullOrEmpty(parse.ErrorCode));
        Assert.True(parse.Index >= 0);
    }

    /// <summary>
    /// Refuses an operator Ruby reads as an argument at the same index the old reader named.
    /// </summary>
    /// <param name="formula">The formula.</param>
    /// <param name="index">Where the operator stands.</param>
    [Theory]
    [InlineData("a.atk -b.def", 6)]
    [InlineData("a.atk *2", 6)]
    [InlineData("b.def /2", 6)]
    [InlineData("[a.atk,1].max -1", 14)]
    [InlineData("a.atk %2", 6)]
    [InlineData("a.atk * 4 - b.def +2", 18)]
    public void RefusesOperatorsRubyReadsAsArguments(string formula, int index)
    {
        FormulaParse parse = FormulaParser.Parse(formula);

        Assert.Equal((FormulaErrors.ArgumentSpace, index), (parse.ErrorCode, parse.Index));
    }

    /// <summary>
    /// Refuses whole numbers with a leading 0, which Ruby reads as octal or not at all.
    /// </summary>
    /// <param name="formula">The formula.</param>
    [Theory]
    [InlineData("012 + 0")]
    [InlineData("09 + 1")]
    [InlineData("01.5 * 2")]
    [InlineData("a.atk * 007")]
    public void RefusesLeadingZeros(string formula) =>
        Assert.Equal(FormulaErrors.LeadingZero, FormulaParser.Parse(formula).ErrorCode);

    /// <summary>
    /// Refuses the old test's deep nesting, now by its length.
    /// </summary>
    [Fact]
    public void RefusesDeepNesting() =>
        Assert.False(FormulaParser.Parse(new string('(', 200) + "1" + new string(')', 200)).IsValid);

    /// <summary>
    /// Gives 0 where the old reader gave no value: the plan makes a division by zero the whole formula 0.
    /// </summary>
    [Fact]
    public void GivesZeroWhereTheOldReaderGaveNoValue()
    {
        Assert.Equal(0, FormulaEvaluator.Evaluate(FormulaParser.Parse("a.atk / 0").Root!, FormulaCorpus.User, FormulaCorpus.Target));
        Assert.Equal(0, FormulaEvaluator.Evaluate(FormulaParser.Parse("a.atk / 0.0").Root!, FormulaCorpus.User, FormulaCorpus.Target));
    }
}
