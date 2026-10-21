//----------------------------------------------------------------
//  FormulaLimits.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// The size limits of a formula, which keep its parsing, computing and JSON nesting bounded.
/// </summary>
public static class FormulaLimits
{
    /// <summary>
    /// The most characters a formula may have.
    /// </summary>
    public const int MaxLength = 200;

    /// <summary>
    /// The most nodes on the longest path from a formula tree's root to a leaf, both counted.
    /// </summary>
    /// <remarks>
    /// The tree is nested in the runtime JSON, so its height also has to stay well below the 64 levels
    /// System.Text.Json reads.
    /// </remarks>
    public const int MaxDepth = 16;

    /// <summary>
    /// The most nodes a formula tree may have.
    /// </summary>
    public const int MaxNodes = 64;
}
