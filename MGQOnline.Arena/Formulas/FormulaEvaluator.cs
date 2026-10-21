//----------------------------------------------------------------
//  FormulaEvaluator.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// Computes a formula tree with the game's Ruby arithmetic.
/// </summary>
/// <remarks>
/// A formula fails whole: a division or remainder by zero, a result that is not finite or an integer
/// beyond 64 bits makes it 0, as the game's rescue makes a failing formula 0. The game also raises a
/// negative result to 0, which is left to the caller.
/// </remarks>
public static class FormulaEvaluator
{
    /// <summary>
    /// Computes a formula.
    /// </summary>
    /// <param name="formula">The formula's tree.</param>
    /// <param name="a">The user's stats.</param>
    /// <param name="b">The target's stats.</param>
    /// <returns>The value, 0 when the formula fails.</returns>
    public static double Evaluate(FormulaNode formula, FormulaStats a, FormulaStats b) =>
        TryEvaluate(formula, a, b, out FormulaValue value) ? value.AsDouble : 0;

    /// <summary>
    /// Computes a formula, telling a failure apart and keeping whether the value is an integer.
    /// </summary>
    /// <param name="formula">The formula's tree.</param>
    /// <param name="a">The user's stats.</param>
    /// <param name="b">The target's stats.</param>
    /// <param name="value">The value, 0 when the formula fails.</param>
    /// <returns>Whether the formula gave a value.</returns>
    public static bool TryEvaluate(FormulaNode formula, FormulaStats a, FormulaStats b, out FormulaValue value)
    {
        ArgumentNullException.ThrowIfNull(formula);
        ArgumentNullException.ThrowIfNull(a);
        ArgumentNullException.ThrowIfNull(b);
        try
        {
            value = Compute(formula, a, b);
            return true;
        }
        catch (ArithmeticException)
        {
            value = new FormulaValue(0L);
            return false;
        }
    }

    /// <summary>
    /// Computes a node.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <param name="a">The user's stats.</param>
    /// <param name="b">The target's stats.</param>
    /// <returns>The node's value.</returns>
    /// <exception cref="ArithmeticException">The formula fails.</exception>
    private static FormulaValue Compute(FormulaNode node, FormulaStats a, FormulaStats b) => node switch
    {
        FormulaNumber number => Number(number.Text),
        FormulaStat stat => new FormulaValue((stat.Subject == FormulaSubject.User ? a : b).Get(stat.Stat)),
        FormulaNegate negate => Negate(Compute(negate.Operand, a, b)),
        FormulaBinary binary => Binary(binary.Operator, Compute(binary.Left, a, b), Compute(binary.Right, a, b)),
        FormulaMethod method => Method(method.Method, Compute(method.Target, a, b)),
        FormulaExtreme extreme => Extreme(extreme, a, b),
        FormulaClamp clamp => Clamp(clamp, a, b),
        _ => throw new ArgumentException($"Unknown formula node {node.GetType().Name}.", nameof(node)),
    };

    /// <summary>
    /// Reads a number as typed: an integer without a point, a float with one.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <returns>The number.</returns>
    /// <exception cref="ArithmeticException">The text is no number of the grammar.</exception>
    private static FormulaValue Number(string text)
    {
        if (text.Contains('.'))
        {
            return double.TryParse(text, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out double number)
                ? Finite(number)
                : throw new ArithmeticException("The number cannot be read.");
        }

        return long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out long integer)
            ? new FormulaValue(integer)
            : throw new ArithmeticException("The number cannot be read.");
    }

    /// <summary>
    /// Negates a value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The negated value.</returns>
    private static FormulaValue Negate(FormulaValue value) =>
        value.IsInteger ? new FormulaValue(checked(-value.Integer)) : new FormulaValue(-value.Float);

    /// <summary>
    /// Joins two values by an operator: integers stay integers, a float on either side makes a float.
    /// </summary>
    /// <param name="op">The operator.</param>
    /// <param name="x">The left value.</param>
    /// <param name="y">The right value.</param>
    /// <returns>The result.</returns>
    private static FormulaValue Binary(FormulaOperator op, FormulaValue x, FormulaValue y)
    {
        if (x.IsInteger && y.IsInteger)
        {
            long l = x.Integer;
            long r = y.Integer;
            return new FormulaValue(op switch
            {
                FormulaOperator.Add => checked(l + r),
                FormulaOperator.Subtract => checked(l - r),
                FormulaOperator.Multiply => checked(l * r),
                FormulaOperator.Divide => RubyMath.FloorDiv(l, r),
                _ => RubyMath.FloorMod(l, r),
            });
        }

        double p = x.AsDouble;
        double q = y.AsDouble;
        return Finite(op switch
        {
            FormulaOperator.Add => p + q,
            FormulaOperator.Subtract => p - q,
            FormulaOperator.Multiply => p * q,
            FormulaOperator.Divide => p / q,
            _ => RubyMath.FloorMod(p, q),
        });
    }

    /// <summary>
    /// Calls a method on a value.
    /// </summary>
    /// <param name="method">The method.</param>
    /// <param name="value">The value.</param>
    /// <returns>The result: an integer, except for .abs on a float and .to_f.</returns>
    private static FormulaValue Method(FormulaMethodName method, FormulaValue value)
    {
        if (method == FormulaMethodName.ToFloat)
        {
            return new FormulaValue(value.AsDouble);
        }

        if (value.IsInteger)
        {
            return method == FormulaMethodName.Abs ? new FormulaValue(Math.Abs(value.Integer)) : value;
        }

        double number = value.Float;
        return method switch
        {
            FormulaMethodName.Abs => new FormulaValue(Math.Abs(number)),
            FormulaMethodName.Floor => new FormulaValue(RubyMath.ToLong(Math.Floor(number))),
            FormulaMethodName.Ceil => new FormulaValue(RubyMath.ToLong(Math.Ceiling(number))),
            FormulaMethodName.Round => new FormulaValue(RubyMath.RoundHalfAway(number)),
            _ => new FormulaValue(RubyMath.ToLong(Math.Truncate(number))),
        };
    }

    /// <summary>
    /// Takes the largest or smallest of a list's values, the first on a tie, as Ruby's Array#max and
    /// Array#min do.
    /// </summary>
    /// <param name="extreme">The node.</param>
    /// <param name="a">The user's stats.</param>
    /// <param name="b">The target's stats.</param>
    /// <returns>The value taken, as it is, integer or float.</returns>
    private static FormulaValue Extreme(FormulaExtreme extreme, FormulaStats a, FormulaStats b)
    {
        if (extreme.Items.Count == 0)
        {
            throw new ArithmeticException("The list is empty.");
        }

        FormulaValue best = Compute(extreme.Items[0], a, b);
        for (int i = 1; i < extreme.Items.Count; i++)
        {
            best = Pick(extreme.Kind, best, Compute(extreme.Items[i], a, b));
        }

        return best;
    }

    /// <summary>
    /// Holds a value between bounds as [[x, lo].max, hi].min does, which the printer writes.
    /// </summary>
    /// <param name="clamp">The node.</param>
    /// <param name="a">The user's stats.</param>
    /// <param name="b">The target's stats.</param>
    /// <returns>The value held.</returns>
    private static FormulaValue Clamp(FormulaClamp clamp, FormulaStats a, FormulaStats b)
    {
        FormulaValue raised = Pick(FormulaExtremeKind.Max, Compute(clamp.Value, a, b), Compute(clamp.Low, a, b));
        return Pick(FormulaExtremeKind.Min, raised, Compute(clamp.High, a, b));
    }

    /// <summary>
    /// Picks the larger or smaller of two values, the first on a tie.
    /// </summary>
    /// <remarks>
    /// The game's Ruby 1.9 compares an integer with a float as two doubles, so this does too.
    /// </remarks>
    /// <param name="kind">Whether to pick the larger.</param>
    /// <param name="first">The first value.</param>
    /// <param name="second">The second value.</param>
    /// <returns>The value picked.</returns>
    private static FormulaValue Pick(FormulaExtremeKind kind, FormulaValue first, FormulaValue second)
    {
        int order = first.IsInteger && second.IsInteger
            ? second.Integer.CompareTo(first.Integer)
            : second.AsDouble.CompareTo(first.AsDouble);
        return (kind == FormulaExtremeKind.Max ? order > 0 : order < 0) ? second : first;
    }

    /// <summary>
    /// Keeps a finite float and fails on any other.
    /// </summary>
    /// <param name="number">The float.</param>
    /// <returns>The float as a value.</returns>
    /// <exception cref="ArithmeticException">The float is infinite or NaN.</exception>
    private static FormulaValue Finite(double number) =>
        double.IsFinite(number) ? new FormulaValue(number) : throw new ArithmeticException("The result is not finite.");
}
