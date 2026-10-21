//----------------------------------------------------------------
//  FormulaSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Model;

/// <summary>
/// A damage formula of the safe grammar, as its printed text and its tree.
/// </summary>
/// <param name="Text">The formula re-printed as canonical Ruby; only this text reaches a compiled file.</param>
/// <param name="Ast">The formula's tree, which the C# engine computes.</param>
public sealed record FormulaSpec(string Text, FormulaNode Ast);
