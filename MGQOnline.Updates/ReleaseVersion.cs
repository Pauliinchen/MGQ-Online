//----------------------------------------------------------------
//  ReleaseVersion.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;

namespace MGQOnline.Updates;

/// <summary>
/// A release version like <c>1.3.0</c> or <c>1.3.0-beta.2</c>, ordered by Semantic Versioning 2.0.
/// </summary>
public readonly struct ReleaseVersion : IEquatable<ReleaseVersion>, IComparable<ReleaseVersion>
{
    /// <summary>
    /// The version every build carries that no release workflow stamped.
    /// </summary>
    public static readonly ReleaseVersion Development = new(0, 0, 0, "dev");

    /// <summary>
    /// Backs <see cref="PreRelease"/>; null in a default value.
    /// </summary>
    private readonly string? _preRelease;

    /// <summary>
    /// Creates a version from its parts.
    /// </summary>
    /// <param name="major">The major number.</param>
    /// <param name="minor">The minor number.</param>
    /// <param name="patch">The patch number.</param>
    /// <param name="preRelease">The pre-release label without its dash, empty for a release.</param>
    private ReleaseVersion(int major, int minor, int patch, string preRelease)
    {
        Major = major;
        Minor = minor;
        Patch = patch;
        _preRelease = preRelease;
    }

    /// <summary>
    /// The major number.
    /// </summary>
    public int Major { get; }

    /// <summary>
    /// The minor number.
    /// </summary>
    public int Minor { get; }

    /// <summary>
    /// The patch number.
    /// </summary>
    public int Patch { get; }

    /// <summary>
    /// The pre-release label without its dash, like <c>beta.2</c>; empty for a release.
    /// </summary>
    public string PreRelease => _preRelease ?? string.Empty;

    /// <summary>
    /// Whether this is <c>0.0.0-dev</c>, the version of a development build.
    /// </summary>
    public bool IsDevelopment => Equals(Development);

    /// <summary>
    /// Reads a version, refusing anything that is not one.
    /// </summary>
    /// <param name="text">The version, like <c>1.3.0</c>, <c>v1.3.0</c> or <c>1.3.0+abc1234</c>.</param>
    /// <returns>The version, without its build metadata.</returns>
    /// <exception cref="FormatException">The text is no version.</exception>
    public static ReleaseVersion Parse(string text) =>
        TryParse(text, out var version) ? version : throw new FormatException($"'{text}' is no version.");

    /// <summary>
    /// Reads a version.
    /// </summary>
    /// <remarks>
    /// A leading <c>v</c> is accepted because release tags carry one, and build metadata after <c>+</c>
    /// is dropped because the assembly's informational version appends the commit there.
    /// </remarks>
    /// <param name="text">The version, like <c>1.3.0</c>, <c>v1.3.0</c> or <c>1.3.0+abc1234</c>.</param>
    /// <param name="version">The version, without its build metadata.</param>
    /// <returns>True when the text is a version.</returns>
    public static bool TryParse([NotNullWhen(true)] string? text, out ReleaseVersion version)
    {
        version = default;

        if (string.IsNullOrEmpty(text))
        {
            return false;
        }

        var core = text.StartsWith('v') ? text[1..] : text;
        var plus = core.IndexOf('+');

        if (plus >= 0)
        {
            if (!AreIdentifiers(core[(plus + 1)..], numericRule: false))
            {
                return false;
            }

            core = core[..plus];
        }

        var preRelease = string.Empty;
        var dash = core.IndexOf('-');

        if (dash >= 0)
        {
            preRelease = core[(dash + 1)..];
            core = core[..dash];

            if (!AreIdentifiers(preRelease, numericRule: true))
            {
                return false;
            }
        }

        var numbers = core.Split('.');

        if (numbers.Length != 3
            || !TryNumber(numbers[0], out var major)
            || !TryNumber(numbers[1], out var minor)
            || !TryNumber(numbers[2], out var patch))
        {
            return false;
        }

        version = new ReleaseVersion(major, minor, patch, preRelease);
        return true;
    }

    /// <inheritdoc />
    public int CompareTo(ReleaseVersion other)
    {
        var byNumbers = Major != other.Major ? Major.CompareTo(other.Major)
            : Minor != other.Minor ? Minor.CompareTo(other.Minor)
            : Patch.CompareTo(other.Patch);

        return byNumbers != 0 ? byNumbers : ComparePreReleases(PreRelease, other.PreRelease);
    }

    /// <inheritdoc />
    public bool Equals(ReleaseVersion other) =>
        Major == other.Major && Minor == other.Minor && Patch == other.Patch
        && string.Equals(PreRelease, other.PreRelease, StringComparison.Ordinal);

    /// <inheritdoc />
    public override bool Equals(object? obj) => obj is ReleaseVersion other && Equals(other);

    /// <inheritdoc />
    public override int GetHashCode() => HashCode.Combine(Major, Minor, Patch, PreRelease);

    /// <summary>
    /// Writes the version, like <c>1.3.0</c> or <c>1.3.0-beta.2</c>.
    /// </summary>
    /// <returns>The version without build metadata.</returns>
    public override string ToString() =>
        PreRelease.Length == 0
            ? string.Create(CultureInfo.InvariantCulture, $"{Major}.{Minor}.{Patch}")
            : string.Create(CultureInfo.InvariantCulture, $"{Major}.{Minor}.{Patch}-{PreRelease}");

    /// <summary>
    /// Tells whether the left version equals the right one.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when both are the same version.</returns>
    public static bool operator ==(ReleaseVersion left, ReleaseVersion right) => left.Equals(right);

    /// <summary>
    /// Tells whether the left version differs from the right one.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when the versions differ.</returns>
    public static bool operator !=(ReleaseVersion left, ReleaseVersion right) => !left.Equals(right);

    /// <summary>
    /// Tells whether the left version comes before the right one.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when the left version is older.</returns>
    public static bool operator <(ReleaseVersion left, ReleaseVersion right) => left.CompareTo(right) < 0;

    /// <summary>
    /// Tells whether the left version comes after the right one.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when the left version is newer.</returns>
    public static bool operator >(ReleaseVersion left, ReleaseVersion right) => left.CompareTo(right) > 0;

    /// <summary>
    /// Tells whether the left version is the right one or comes before it.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when the left version is not newer.</returns>
    public static bool operator <=(ReleaseVersion left, ReleaseVersion right) => left.CompareTo(right) <= 0;

    /// <summary>
    /// Tells whether the left version is the right one or comes after it.
    /// </summary>
    /// <param name="left">The left version.</param>
    /// <param name="right">The right version.</param>
    /// <returns>True when the left version is not older.</returns>
    public static bool operator >=(ReleaseVersion left, ReleaseVersion right) => left.CompareTo(right) >= 0;

    /// <summary>
    /// Reads one of the three version numbers.
    /// </summary>
    /// <param name="text">The number's digits.</param>
    /// <param name="number">The number.</param>
    /// <returns>True for plain digits without a leading zero.</returns>
    private static bool TryNumber(string text, out int number)
    {
        number = 0;
        return IsDigits(text)
            && (text.Length == 1 || text[0] != '0')
            && int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out number);
    }

    /// <summary>
    /// Tells whether dot-separated identifiers are well formed.
    /// </summary>
    /// <param name="text">The identifiers, like <c>beta.2</c>.</param>
    /// <param name="numericRule">Whether a numeric identifier may not have a leading zero, as in a pre-release label.</param>
    /// <returns>True when every identifier is non-empty ASCII letters, digits or dashes.</returns>
    private static bool AreIdentifiers(string text, bool numericRule)
    {
        foreach (var identifier in text.Split('.'))
        {
            if (identifier.Length == 0)
            {
                return false;
            }

            foreach (var character in identifier)
            {
                if (!char.IsAsciiLetterOrDigit(character) && character != '-')
                {
                    return false;
                }
            }

            if (numericRule && IsDigits(identifier) && identifier.Length > 1 && identifier[0] == '0')
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Orders two pre-release labels.
    /// </summary>
    /// <param name="left">The left label, empty for a release.</param>
    /// <param name="right">The right label, empty for a release.</param>
    /// <returns>Below zero when the left label comes first, zero when equal, above zero otherwise.</returns>
    private static int ComparePreReleases(string left, string right)
    {
        if (left.Length == 0 || right.Length == 0)
        {
            return left.Length == right.Length ? 0 : left.Length == 0 ? 1 : -1;
        }

        var leftParts = left.Split('.');
        var rightParts = right.Split('.');

        for (var index = 0; index < Math.Min(leftParts.Length, rightParts.Length); index++)
        {
            var order = CompareIdentifiers(leftParts[index], rightParts[index]);

            if (order != 0)
            {
                return order;
            }
        }

        return leftParts.Length.CompareTo(rightParts.Length);
    }

    /// <summary>
    /// Orders two pre-release identifiers.
    /// </summary>
    /// <param name="left">The left identifier.</param>
    /// <param name="right">The right identifier.</param>
    /// <returns>Below zero when the left identifier comes first, zero when equal, above zero otherwise.</returns>
    private static int CompareIdentifiers(string left, string right)
    {
        var leftNumeric = IsDigits(left);
        var rightNumeric = IsDigits(right);

        if (leftNumeric && rightNumeric)
        {
            return left.Length != right.Length
                ? left.Length.CompareTo(right.Length)
                : string.CompareOrdinal(left, right);
        }

        if (leftNumeric != rightNumeric)
        {
            return leftNumeric ? -1 : 1;
        }

        return string.CompareOrdinal(left, right);
    }

    /// <summary>
    /// Tells whether a text is ASCII digits only.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>True for one or more ASCII digits.</returns>
    private static bool IsDigits(string text)
    {
        if (text.Length == 0)
        {
            return false;
        }

        foreach (var character in text)
        {
            if (!char.IsAsciiDigit(character))
            {
                return false;
            }
        }

        return true;
    }
}
