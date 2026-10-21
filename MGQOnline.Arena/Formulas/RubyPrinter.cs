//----------------------------------------------------------------
//  RubyPrinter.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Text;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// Writes a formula tree as the canonical Ruby text the game runs.
/// </summary>
/// <remarks>
/// Only this text reaches a compiled file, so nothing outside the grammar can reach the game's eval.
/// It spaces every operator, brackets every method's target and every negated operand that is not a
/// single value, so Ruby reads it exactly as the tree says.
/// </remarks>
public static class RubyPrinter
{
    /// <summary>
    /// The binding of a sum or difference.
    /// </summary>
    private const int SumBinding = 1;

    /// <summary>
    /// The binding of a product, quotient or remainder.
    /// </summary>
    private const int ProductBinding = 2;

    /// <summary>
    /// The binding of a negation.
    /// </summary>
    private const int NegateBinding = 3;

    /// <summary>
    /// The binding of a single value: a number, stat, method call or list.
    /// </summary>
    private const int ValueBinding = 4;

    /// <summary>
    /// Writes a formula.
    /// </summary>
    /// <param name="formula">The formula's tree.</param>
    /// <returns>The Ruby text.</returns>
    public static string Print(FormulaNode formula)
    {
        ArgumentNullException.ThrowIfNull(formula);
        StringBuilder text = new();
        Write(text, formula);
        return text.ToString();
    }

    /// <summary>
    /// Writes a node.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="node">The node.</param>
    private static void Write(StringBuilder text, FormulaNode node)
    {
        switch (node)
        {
            case FormulaNumber number:
                text.Append(IsGrammarNumber(number.Text) ? number.Text : throw new ArgumentException($"The number text {number.Text} is outside the grammar.", nameof(node)));
                break;
            case FormulaStat stat:
                text.Append(stat.Subject == FormulaSubject.User ? "a." : "b.").Append(StatName(stat.Stat));
                break;
            case FormulaNegate negate:
                text.Append('-');
                WriteBracketed(text, negate.Operand, BindingOf(negate.Operand) < ValueBinding);
                break;
            case FormulaBinary binary:
                int binding = BindingOf(binary);
                WriteBracketed(text, binary.Left, BindingOf(binary.Left) < binding);
                text.Append(' ').Append(OperatorText(binary.Operator)).Append(' ');
                WriteBracketed(text, binary.Right, BindingOf(binary.Right) <= binding);
                break;
            case FormulaMethod method:
                WriteBracketed(text, method.Target, true);
                text.Append('.').Append(MethodName(method.Method));
                break;
            case FormulaExtreme extreme:
                text.Append('[');
                for (int i = 0; i < extreme.Items.Count; i++)
                {
                    text.Append(i == 0 ? "" : ", ");
                    Write(text, extreme.Items[i]);
                }

                text.Append(extreme.Kind == FormulaExtremeKind.Max ? "].max" : "].min");
                break;
            case FormulaClamp clamp:
                text.Append("[[");
                Write(text, clamp.Value);
                text.Append(", ");
                Write(text, clamp.Low);
                text.Append("].max, ");
                Write(text, clamp.High);
                text.Append("].min");
                break;
            default:
                throw new ArgumentException($"Unknown formula node {node.GetType().Name}.", nameof(node));
        }
    }

    /// <summary>
    /// Tells whether a number's text is a NUMBER the parser would read.
    /// </summary>
    /// <remarks>A tree read from JSON never went through the parser, and its text goes to the game's
    /// eval as it stands.</remarks>
    /// <param name="text">The number's text.</param>
    /// <returns>Whether it is digits without a leading zero, with an optional point and digits, and an
    /// integer fits a long.</returns>
    private static bool IsGrammarNumber(string? text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return false;
        }

        int point = text.IndexOf('.');
        string whole = point < 0 ? text : text[..point];
        if (!IsDigits(whole) || (whole.Length > 1 && whole[0] == '0'))
        {
            return false;
        }

        return point < 0
            ? long.TryParse(whole, NumberStyles.None, CultureInfo.InvariantCulture, out _)
            : IsDigits(text[(point + 1)..]);
    }

    /// <summary>
    /// Tells whether a text is one or more ASCII digits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is digits only and not empty.</returns>
    private static bool IsDigits(string text)
    {
        foreach (char c in text)
        {
            if (!char.IsAsciiDigit(c))
            {
                return false;
            }
        }

        return text.Length > 0;
    }

    /// <summary>
    /// Writes a node, in round brackets when asked.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="node">The node.</param>
    /// <param name="bracketed">Whether to bracket it.</param>
    private static void WriteBracketed(StringBuilder text, FormulaNode node, bool bracketed)
    {
        if (bracketed)
        {
            text.Append('(');
        }

        Write(text, node);
        if (bracketed)
        {
            text.Append(')');
        }
    }

    /// <summary>
    /// Tells how tightly a node binds, so the printer knows when to bracket it.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>Its binding; higher binds tighter.</returns>
    private static int BindingOf(FormulaNode node) => node switch
    {
        FormulaBinary { Operator: FormulaOperator.Add or FormulaOperator.Subtract } => SumBinding,
        FormulaBinary => ProductBinding,
        FormulaNegate => NegateBinding,
        _ => ValueBinding,
    };

    /// <summary>
    /// Gives an operator's text.
    /// </summary>
    /// <param name="op">The operator.</param>
    /// <returns>Its text.</returns>
    private static string OperatorText(FormulaOperator op) => op switch
    {
        FormulaOperator.Add => "+",
        FormulaOperator.Subtract => "-",
        FormulaOperator.Multiply => "*",
        FormulaOperator.Divide => "/",
        FormulaOperator.Modulo => "%",
        _ => throw new ArgumentOutOfRangeException(nameof(op)),
    };

    /// <summary>
    /// Gives a stat's name as Ruby calls it.
    /// </summary>
    /// <param name="stat">The stat.</param>
    /// <returns>Its name, such as "atk".</returns>
    private static string StatName(FormulaStatName stat) => stat switch
    {
        FormulaStatName.Atk => "atk",
        FormulaStatName.Def => "def",
        FormulaStatName.Mat => "mat",
        FormulaStatName.Mdf => "mdf",
        FormulaStatName.Agi => "agi",
        FormulaStatName.Luk => "luk",
        FormulaStatName.Mhp => "mhp",
        FormulaStatName.Mmp => "mmp",
        FormulaStatName.Hp => "hp",
        FormulaStatName.Mp => "mp",
        FormulaStatName.Level => "level",
        _ => throw new ArgumentOutOfRangeException(nameof(stat)),
    };

    /// <summary>
    /// Gives a method's name as Ruby calls it.
    /// </summary>
    /// <param name="method">The method.</param>
    /// <returns>Its name, such as "to_i".</returns>
    private static string MethodName(FormulaMethodName method) => method switch
    {
        FormulaMethodName.Abs => "abs",
        FormulaMethodName.Floor => "floor",
        FormulaMethodName.Ceil => "ceil",
        FormulaMethodName.Round => "round",
        FormulaMethodName.ToInteger => "to_i",
        FormulaMethodName.ToFloat => "to_f",
        _ => throw new ArgumentOutOfRangeException(nameof(method)),
    };
}
