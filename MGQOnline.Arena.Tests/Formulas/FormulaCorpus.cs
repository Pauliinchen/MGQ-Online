//----------------------------------------------------------------
//  FormulaCorpus.cs
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
/// The formulas the grammar accepts and refuses, with what they give and print.
/// </summary>
internal static class FormulaCorpus
{
    /// <summary>
    /// The user's stats: mhp 5000, atk 100, def 60, mat 80, mdf 40, agi 50, luk 20, level 30.
    /// </summary>
    public static readonly FormulaStats User = new(5000, 300, 100, 60, 80, 40, 50, 20, 4000, 200, 30);

    /// <summary>
    /// The target's stats: mhp 1000, atk 70, def 50, mat 60, mdf 30, agi 40, luk 10, level 10.
    /// </summary>
    public static readonly FormulaStats Target = new(1000, 100, 70, 50, 60, 30, 40, 10, 1000, 100, 10);

    /// <summary>
    /// Gets the game formulas of the skills the format-1 fixture's boss (Morrigan: skills 1515, 3038,
    /// 3764 and 6159) uses, with their enemy formulas, read from the Test install's Skills.rvdata2,
    /// and the formulas of the compile2 golden; the fixture itself overrides no formula. Each case is
    /// the text, its value with <see cref="User"/> and <see cref="Target"/>, whether the value is an
    /// integer and the printed Ruby text.
    /// </summary>
    public static TheoryData<string, double, bool, string> FixtureFormulas => new()
    {
        { "a.mat * 2 * 3.0 - b.mdf", (80 * 2 * 3.0) - 30, false, "a.mat * 2 * 3.0 - b.mdf" },
        { "a.mat * 2 * 1.4 - b.mdf / 2", (80 * 2 * 1.4) - (30 / 2), false, "a.mat * 2 * 1.4 - b.mdf / 2" },
        { "[a.mat, a.agi].max * 2 * 2.5 - b.mdf", (80 * 2 * 2.5) - 30, false, "[a.mat, a.agi].max * 2 * 2.5 - b.mdf" },
        { "a.mat * 2 * 1.3 - b.mdf / 2", (80 * 2 * 1.3) - (30 / 2), false, "a.mat * 2 * 1.3 - b.mdf / 2" },
        { "a.luk * 2 * 1.0 - (b.def + b.mdf) / 4", (20 * 2 * 1.0) - ((50 + 30) / 4), false, "a.luk * 2 * 1.0 - (b.def + b.mdf) / 4" },
        { "[a.atk, a.luk, a.mat].max * 2 * 7.0 - (b.def + b.mdf) / 2", (100 * 2 * 7.0) - ((50 + 30) / 2), false, "[a.atk, a.luk, a.mat].max * 2 * 7.0 - (b.def + b.mdf) / 2" },
        { "a.luk * 2 * 1.6 - (b.def + b.mdf) / 4", (20 * 2 * 1.6) - ((50 + 30) / 4), false, "a.luk * 2 * 1.6 - (b.def + b.mdf) / 4" },
        { "a.atk * 2 * 1.0 - b.def / 2", (100 * 2 * 1.0) - (50 / 2), false, "a.atk * 2 * 1.0 - b.def / 2" },
        { "a.atk * 3", 300, true, "a.atk * 3" },
    };

    /// <summary>
    /// Gets further formulas the grammar accepts: every operator, method, call and the Ruby rules of
    /// integers and floats. Each case is as in <see cref="FixtureFormulas"/>.
    /// </summary>
    public static TheoryData<string, double, bool, string> Accepted => new()
    {
        { "a.atk * 4 - b.def * 2", 300, true, "a.atk * 4 - b.def * 2" },
        { "7 / 2", 3, true, "7 / 2" },
        { "-7 / 2", -4, true, "-7 / 2" },
        { "7 / -2", -4, true, "7 / -2" },
        { "7 / 2.0", 3.5, false, "7 / 2.0" },
        { "-7 % 3", 2, true, "-7 % 3" },
        { "7 % -3", -2, true, "7 % -3" },
        { "-a.atk % 7", 5, true, "-a.atk % 7" },
        { "7.5 % 2", 1.5, false, "7.5 % 2" },
        { "-7.5 % 2", 0.5, false, "-7.5 % 2" },
        { "0.0 + 7 / 2", 3.0, false, "0.0 + 7 / 2" },
        { "1.50 * 2", 3.0, false, "1.50 * 2" },
        { "1 - 2 - 3", -4, true, "1 - 2 - 3" },
        { "1 - (2 - 3)", 2, true, "1 - (2 - 3)" },
        { "2 * (3 + 4)", 14, true, "2 * (3 + 4)" },
        { "(2 * 3) + 4", 10, true, "2 * 3 + 4" },
        { "8 / (4 / 2)", 4, true, "8 / (4 / 2)" },
        { "100 / 7 * 7", 98, true, "100 / 7 * 7" },
        { "- -3", 3, true, "-(-3)" },
        { "--3", 3, true, "-(-3)" },
        { "-(a.atk - b.def)", -50, true, "-(a.atk - b.def)" },
        { "+a.atk", 100, true, "a.atk" },
        { "a.atk\t*\t2", 200, true, "a.atk * 2" },
        { "a.atk*2-b.def", 150, true, "a.atk * 2 - b.def" },
        { "a .atk + b. def", 150, true, "a.atk + b.def" },
        { "a.mhp + a.mmp + a.hp + a.mp + a.level", 9530, true, "a.mhp + a.mmp + a.hp + a.mp + a.level" },
        { "b.atk + b.def + b.mat + b.mdf + b.agi + b.luk", 260, true, "b.atk + b.def + b.mat + b.mdf + b.agi + b.luk" },
        { "(a.atk / 3.0).floor", 33, true, "(a.atk / 3.0).floor" },
        { "(-a.atk / 3.0).floor", -34, true, "(-a.atk / 3.0).floor" },
        { "(a.atk / 3.0).ceil", 34, true, "(a.atk / 3.0).ceil" },
        { "(7 / 2.0).round", 4, true, "(7 / 2.0).round" },
        { "(-7 / 2.0).round", -4, true, "(-7 / 2.0).round" },
        { "2.5.ceil", 3, true, "(2.5).ceil" },
        { "- 2.5.floor", -2, true, "-(2.5).floor" },
        { "(-2.5).to_i", -2, true, "(-2.5).to_i" },
        { "(10 / 4.0).to_i", 2, true, "(10 / 4.0).to_i" },
        { "a.atk.to_f / 3", 100 / 3.0, false, "(a.atk).to_f / 3" },
        { "a.atk.abs", 100, true, "(a.atk).abs" },
        { "(b.def - a.atk).abs", 50, true, "(b.def - a.atk).abs" },
        { "(-3.5).abs", 3.5, false, "(-3.5).abs" },
        { "(5).round", 5, true, "(5).round" },
        { "a.atk.to_f.floor.abs", 100, true, "(((a.atk).to_f).floor).abs" },
        { "[a.atk, b.def].max", 100, true, "[a.atk, b.def].max" },
        { "[a.atk - 200, 0, 5].min", -100, true, "[a.atk - 200, 0, 5].min" },
        { "[3, 3.0].max", 3, true, "[3, 3.0].max" },
        { "[3.0, 3].max", 3.0, false, "[3.0, 3].max" },
        { "[2, 2.5].max", 2.5, false, "[2, 2.5].max" },
        { "[a.atk, 1].max.floor", 100, true, "([a.atk, 1].max).floor" },
        { "-[1, 2].max", -2, true, "-[1, 2].max" },
        { "max(a.atk, b.def * 3)", 150, true, "[a.atk, b.def * 3].max" },
        { "min(a.atk, 5)", 5, true, "[a.atk, 5].min" },
        { "max (1)", 1, true, "[1].max" },
        { "clamp(a.atk, 0, 50)", 50, true, "[[a.atk, 0].max, 50].min" },
        { "clamp(b.def - a.atk, 0, 999)", 0, true, "[[b.def - a.atk, 0].max, 999].min" },
        { "clamp(a.luk, 30, 10)", 10, true, "[[a.luk, 30].max, 10].min" },
        { "clamp(a.luk * 1.5, 0, 100)", 30.0, false, "[[a.luk * 1.5, 0].max, 100].min" },
        { "a.atk * 2 + clamp(a.luk - b.luk, 0, 20).to_f / 4", 202.5, false, "a.atk * 2 + ([[a.luk - b.luk, 0].max, 20].min).to_f / 4" },
        { "0", 0, true, "0" },
        { "9223372036854775807", 9223372036854775807, true, "9223372036854775807" },
    };

    /// <summary>
    /// Gets formulas the grammar refuses, with the error code and the index it names. The game's own
    /// formulas that use variables, conditions or other methods are refused the same way.
    /// </summary>
    public static TheoryData<string, string, int> Refused => new()
    {
        { "", FormulaErrors.Empty, 0 },
        { "   ", FormulaErrors.Empty, 0 },
        { new string('1', 201), FormulaErrors.TooLong, 200 },
        { "a.atk ** 2", FormulaErrors.Power, 6 },
        { "a.atk * 2 if true", FormulaErrors.Unexpected, 10 },
        { "system('calc')", FormulaErrors.Character, 7 },
        { "`calc`", FormulaErrors.Character, 0 },
        { "a.send(:exit)", FormulaErrors.Character, 7 },
        { "a.send", FormulaErrors.UnknownStat, 2 },
        { "v[1] * 2", FormulaErrors.UnknownName, 0 },
        { "a.atk +", FormulaErrors.UnexpectedEnd, 7 },
        { "(1 + 2", FormulaErrors.UnexpectedEnd, 6 },
        { "a.foo", FormulaErrors.UnknownStat, 2 },
        { "1; 2", FormulaErrors.Character, 1 },
        { "eval(\"1\")", FormulaErrors.Character, 5 },
        { "a.atk > 5 ? 1 : 2", FormulaErrors.Character, 6 },
        { "[1, 2].sum", FormulaErrors.ListMethod, 7 },
        { "[1, 2]", FormulaErrors.ListMethod, 6 },
        { "[1, 2] + 1", FormulaErrors.ListMethod, 7 },
        { "Kernel.exit", FormulaErrors.UnknownName, 0 },
        { "rand(3) * a.atk", FormulaErrors.UnknownName, 0 },
        { "A.atk", FormulaErrors.UnknownName, 0 },
        { "$game_variables[1]", FormulaErrors.Character, 0 },
        { "a.atk && 1", FormulaErrors.Character, 6 },
        { "a.atk * 2 # comment", FormulaErrors.Character, 10 },
        { "a.atk / b.def;", FormulaErrors.Character, 13 },
        { "a.atk\n- 5", FormulaErrors.Character, 5 },
        { "a.atk -b.def", FormulaErrors.ArgumentSpace, 6 },
        { "a.atk *2", FormulaErrors.ArgumentSpace, 6 },
        { "b.def /2", FormulaErrors.ArgumentSpace, 6 },
        { "[a.atk,1].max -1", FormulaErrors.ArgumentSpace, 14 },
        { "a.atk %2", FormulaErrors.ArgumentSpace, 6 },
        { "a.atk * 4 - b.def +2", FormulaErrors.ArgumentSpace, 18 },
        { "(a.atk).floor -1", FormulaErrors.ArgumentSpace, 14 },
        { "012 + 0", FormulaErrors.LeadingZero, 0 },
        { "09 + 1", FormulaErrors.LeadingZero, 0 },
        { "01.5 * 2", FormulaErrors.LeadingZero, 0 },
        { "a.atk * 007", FormulaErrors.LeadingZero, 8 },
        { "9223372036854775808", FormulaErrors.NumberTooLarge, 0 },
        { "-2.abs", FormulaErrors.SignedLiteralMethod, 0 },
        { "a.atk * -2.5.floor", FormulaErrors.SignedLiteralMethod, 8 },
        { "[1, -2.abs].max", FormulaErrors.SignedLiteralMethod, 4 },
        { "a.atk.max", FormulaErrors.UnknownMethod, 6 },
        { "(1).to_s", FormulaErrors.UnknownMethod, 4 },
        { "a.atk.", FormulaErrors.UnexpectedEnd, 6 },
        { "a.", FormulaErrors.UnexpectedEnd, 2 },
        { "a", FormulaErrors.UnexpectedEnd, 1 },
        { "a.1", FormulaErrors.Unexpected, 2 },
        { "1.", FormulaErrors.UnexpectedEnd, 2 },
        { ".5", FormulaErrors.Unexpected, 0 },
        { "1.5e3", FormulaErrors.Unexpected, 3 },
        { "clamp(1, 2)", FormulaErrors.ClampArguments, 0 },
        { "clamp(1, 2, 3, 4)", FormulaErrors.ClampArguments, 0 },
        { "max 1", FormulaErrors.Unexpected, 4 },
        { "max()", FormulaErrors.Unexpected, 4 },
        { "1 2", FormulaErrors.Unexpected, 2 },
        { "()", FormulaErrors.Unexpected, 1 },
        { "a.atk(1)", FormulaErrors.Unexpected, 5 },
        { "a.atk [1].max", FormulaErrors.Unexpected, 6 },
        { new string('-', 16) + "1", FormulaErrors.TooDeep, 0 },
        { string.Join(" + ", Enumerable.Repeat("1", 17)), FormulaErrors.TooDeep, 0 },
        { "[" + string.Join(", ", Enumerable.Repeat("1", 64)) + "].max", FormulaErrors.TooManyNodes, 0 },
    };
}
