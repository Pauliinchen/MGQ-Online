//----------------------------------------------------------------
//  FormulaEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Whose stat a formula reads.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FormulaSubject>))]
public enum FormulaSubject
{
    /// <summary>
    /// The skill's user, a in the formula.
    /// </summary>
    User,

    /// <summary>
    /// The skill's target, b in the formula.
    /// </summary>
    Target,
}

/// <summary>
/// The stats a formula may read.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FormulaStatName>))]
public enum FormulaStatName
{
    /// <summary>
    /// The attack, atk.
    /// </summary>
    Atk,

    /// <summary>
    /// The defense, def.
    /// </summary>
    Def,

    /// <summary>
    /// The magic attack, mat.
    /// </summary>
    Mat,

    /// <summary>
    /// The magic defense, mdf.
    /// </summary>
    Mdf,

    /// <summary>
    /// The agility, agi.
    /// </summary>
    Agi,

    /// <summary>
    /// The luck, luk.
    /// </summary>
    Luk,

    /// <summary>
    /// The maximum HP, mhp.
    /// </summary>
    Mhp,

    /// <summary>
    /// The maximum MP, mmp.
    /// </summary>
    Mmp,

    /// <summary>
    /// The HP left, hp.
    /// </summary>
    Hp,

    /// <summary>
    /// The MP left, mp.
    /// </summary>
    Mp,

    /// <summary>
    /// The level, level.
    /// </summary>
    Level,
}

/// <summary>
/// The operators between two values.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FormulaOperator>))]
public enum FormulaOperator
{
    /// <summary>
    /// The sum, +.
    /// </summary>
    Add,

    /// <summary>
    /// The difference, -.
    /// </summary>
    Subtract,

    /// <summary>
    /// The product, *.
    /// </summary>
    Multiply,

    /// <summary>
    /// The quotient, /, floored between two integers.
    /// </summary>
    Divide,

    /// <summary>
    /// The remainder, %, with the divisor's sign.
    /// </summary>
    Modulo,
}

/// <summary>
/// The methods a formula may call on a value.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FormulaMethodName>))]
public enum FormulaMethodName
{
    /// <summary>
    /// The absolute value, .abs.
    /// </summary>
    Abs,

    /// <summary>
    /// Rounded down to an integer, .floor.
    /// </summary>
    Floor,

    /// <summary>
    /// Rounded up to an integer, .ceil.
    /// </summary>
    Ceil,

    /// <summary>
    /// Rounded to the nearest integer, halves away from zero, .round.
    /// </summary>
    Round,

    /// <summary>
    /// Cut toward zero to an integer, .to_i.
    /// </summary>
    ToInteger,

    /// <summary>
    /// Made a float, .to_f.
    /// </summary>
    ToFloat,
}

/// <summary>
/// Which end of a list a formula takes.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FormulaExtremeKind>))]
public enum FormulaExtremeKind
{
    /// <summary>
    /// The largest, .max.
    /// </summary>
    Max,

    /// <summary>
    /// The smallest, .min.
    /// </summary>
    Min,
}
