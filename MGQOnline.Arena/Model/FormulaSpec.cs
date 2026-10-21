//----------------------------------------------------------------
//  FormulaSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Model;

/// <summary>
/// A damage formula of the safe grammar.
/// </summary>
/// <remarks>Partial so the parsed tree joins it from the formula records, which another package owns.</remarks>
/// <param name="Text">The formula re-printed as canonical Ruby; only this text reaches a compiled file.</param>
public sealed partial record FormulaSpec(string Text);
