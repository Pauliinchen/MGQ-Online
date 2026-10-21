//----------------------------------------------------------------
//  FormulaNode.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A node of a damage formula's tree in the safe formula grammar (docs/FORMULAS.md).
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]
[JsonDerivedType(typeof(FormulaNumber), "number")]
[JsonDerivedType(typeof(FormulaStat), "stat")]
[JsonDerivedType(typeof(FormulaNegate), "negate")]
[JsonDerivedType(typeof(FormulaBinary), "binary")]
[JsonDerivedType(typeof(FormulaMethod), "method")]
[JsonDerivedType(typeof(FormulaExtreme), "extreme")]
[JsonDerivedType(typeof(FormulaClamp), "clamp")]
public abstract record FormulaNode;

/// <summary>
/// A number as it was typed: an integer without a point, a float with one.
/// </summary>
/// <param name="Text">The digits, such as "4" or "1.50".</param>
public sealed record FormulaNumber(string Text) : FormulaNode;

/// <summary>
/// A stat of the user (a) or the target (b).
/// </summary>
/// <param name="Subject">Whose stat.</param>
/// <param name="Stat">Which stat.</param>
public sealed record FormulaStat(FormulaSubject Subject, FormulaStatName Stat) : FormulaNode;

/// <summary>
/// A negated value: -x.
/// </summary>
/// <param name="Operand">The value.</param>
public sealed record FormulaNegate(FormulaNode Operand) : FormulaNode;

/// <summary>
/// Two values joined by an operator.
/// </summary>
/// <param name="Operator">The operator.</param>
/// <param name="Left">The left value.</param>
/// <param name="Right">The right value.</param>
public sealed record FormulaBinary(FormulaOperator Operator, FormulaNode Left, FormulaNode Right) : FormulaNode;

/// <summary>
/// A method called on a value, such as (x).floor.
/// </summary>
/// <param name="Method">The method.</param>
/// <param name="Target">The value it is called on.</param>
public sealed record FormulaMethod(FormulaMethodName Method, FormulaNode Target) : FormulaNode;

/// <summary>
/// The largest or smallest of a list: [x, y].max, [x, y].min, max(x, y) or min(x, y).
/// </summary>
/// <param name="Kind">Whether it takes the largest or the smallest.</param>
/// <param name="Items">The values, at least one; on a tie the first wins.</param>
public sealed record FormulaExtreme(FormulaExtremeKind Kind, IReadOnlyList<FormulaNode> Items) : FormulaNode
{
    /// <summary>
    /// Tells whether another node takes the same extreme of equal items.
    /// </summary>
    /// <param name="other">The other node.</param>
    /// <returns>Whether both are equal, item by item.</returns>
    public bool Equals(FormulaExtreme? other) =>
        other is not null && Kind == other.Kind && Items.SequenceEqual(other.Items);

    /// <inheritdoc />
    public override int GetHashCode()
    {
        HashCode hash = new();
        hash.Add(Kind);
        foreach (FormulaNode item in Items)
        {
            hash.Add(item);
        }

        return hash.ToHashCode();
    }
}

/// <summary>
/// A value held between a lower and an upper bound: clamp(x, lo, hi), which is [[x, lo].max, hi].min.
/// </summary>
/// <param name="Value">The value.</param>
/// <param name="Low">The lower bound.</param>
/// <param name="High">The upper bound, which wins over a higher lower bound.</param>
public sealed record FormulaClamp(FormulaNode Value, FormulaNode Low, FormulaNode High) : FormulaNode;
