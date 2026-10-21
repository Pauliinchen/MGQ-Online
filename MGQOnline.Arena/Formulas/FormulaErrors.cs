//----------------------------------------------------------------
//  FormulaErrors.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// The codes of why a formula cannot be read; the designer words them for people.
/// </summary>
public static class FormulaErrors
{
    /// <summary>
    /// The formula is empty or only spaces.
    /// </summary>
    public const string Empty = "empty";

    /// <summary>
    /// The formula is longer than <see cref="FormulaLimits.MaxLength"/>.
    /// </summary>
    public const string TooLong = "tooLong";

    /// <summary>
    /// The tree is higher than <see cref="FormulaLimits.MaxDepth"/>.
    /// </summary>
    public const string TooDeep = "tooDeep";

    /// <summary>
    /// The tree has more than <see cref="FormulaLimits.MaxNodes"/> nodes.
    /// </summary>
    public const string TooManyNodes = "tooManyNodes";

    /// <summary>
    /// A character the grammar has no use for, such as a quote, a semicolon or a line break.
    /// </summary>
    public const string Character = "character";

    /// <summary>
    /// The power operator **, which the grammar leaves out.
    /// </summary>
    public const string Power = "power";

    /// <summary>
    /// A whole number with a leading 0, which Ruby reads as octal.
    /// </summary>
    public const string LeadingZero = "leadingZero";

    /// <summary>
    /// A whole number too large for a 64-bit integer.
    /// </summary>
    public const string NumberTooLarge = "numberTooLarge";

    /// <summary>
    /// An operator with a space before and none after behind a method, which Ruby reads as the start
    /// of the method's argument.
    /// </summary>
    public const string ArgumentSpace = "argumentSpace";

    /// <summary>
    /// A minus written against a number that a method follows, such as -2.abs, which Ruby reads as
    /// (-2).abs.
    /// </summary>
    public const string SignedLiteralMethod = "signedLiteralMethod";

    /// <summary>
    /// A name that is neither a, b, min, max nor clamp.
    /// </summary>
    public const string UnknownName = "unknownName";

    /// <summary>
    /// A stat name after a. or b. that formulas cannot read.
    /// </summary>
    public const string UnknownStat = "unknownStat";

    /// <summary>
    /// A method name after a value that formulas cannot call.
    /// </summary>
    public const string UnknownMethod = "unknownMethod";

    /// <summary>
    /// A list in brackets without .max or .min behind it.
    /// </summary>
    public const string ListMethod = "listMethod";

    /// <summary>
    /// clamp with other than three values.
    /// </summary>
    public const string ClampArguments = "clampArguments";

    /// <summary>
    /// A token where the grammar expects another one.
    /// </summary>
    public const string Unexpected = "unexpected";

    /// <summary>
    /// The formula ends where the grammar expects more.
    /// </summary>
    public const string UnexpectedEnd = "unexpectedEnd";
}
