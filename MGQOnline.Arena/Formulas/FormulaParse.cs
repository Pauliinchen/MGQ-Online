//----------------------------------------------------------------
//  FormulaParse.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Diagnostics.CodeAnalysis;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// The outcome of reading a formula.
/// </summary>
/// <param name="Root">The formula's tree, null when it cannot be read.</param>
/// <param name="ErrorCode">Why it cannot be read, one of <see cref="FormulaErrors"/>; null when it can.</param>
/// <param name="Index">Where in the text reading failed, -1 when it did not.</param>
public sealed record FormulaParse(FormulaNode? Root, string? ErrorCode, int Index)
{
    /// <summary>
    /// Gets whether the formula can be read.
    /// </summary>
    [MemberNotNullWhen(true, nameof(Root))]
    [MemberNotNullWhen(false, nameof(ErrorCode))]
    public bool IsValid => Root is not null;
}
