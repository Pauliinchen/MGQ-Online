//----------------------------------------------------------------
//  FormulaValue.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// A number as Ruby keeps it: an integer or a float.
/// </summary>
public readonly record struct FormulaValue
{
    /// <summary>
    /// Initializes an integer.
    /// </summary>
    /// <param name="integer">The integer.</param>
    public FormulaValue(long integer)
    {
        IsInteger = true;
        Integer = integer;
    }

    /// <summary>
    /// Initializes a float.
    /// </summary>
    /// <param name="number">The float.</param>
    public FormulaValue(double number) => Float = number;

    /// <summary>
    /// Gets whether the value is an integer rather than a float.
    /// </summary>
    public bool IsInteger { get; }

    /// <summary>
    /// Gets the integer, 0 for a float.
    /// </summary>
    public long Integer { get; }

    /// <summary>
    /// Gets the float, 0 for an integer.
    /// </summary>
    public double Float { get; }

    /// <summary>
    /// Gets the value as a double, as Ruby converts an integer for mixed arithmetic.
    /// </summary>
    public double AsDouble => IsInteger ? Integer : Float;
}
