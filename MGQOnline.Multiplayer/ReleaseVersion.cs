//----------------------------------------------------------------
//  ReleaseVersion.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;

namespace MGQOnline.Multiplayer;

/// <summary>
/// Reads and compares the versions of releases, as the update check and the helper's update name them.
/// </summary>
internal static class ReleaseVersion
{
    /// <summary>
    /// The most parts of a release's version, like <c>0.6.7.7</c>.
    /// </summary>
    private const int MaxParts = 4;

    /// <summary>
    /// Reads a release's version as the relay and the updater name it: dotted numbers alone.
    /// </summary>
    /// <param name="text">The version, like <c>0.6.8</c>.</param>
    /// <returns>The version with every part it lacks as 0, or <see langword="null"/> for anything else.</returns>
    public static Version? Parse(string? text)
    {
        var parts = text?.Split('.') ?? [];

        if (parts.Length is 0 or > MaxParts || !parts.All(part => part.Length is > 0 and <= 9 && part.All(char.IsAsciiDigit)))
        {
            return null;
        }

        var numbers = parts.Select(int.Parse).Concat(Enumerable.Repeat(0, MaxParts - parts.Length)).ToArray();
        return new Version(numbers[0], numbers[1], numbers[2], numbers[3]);
    }

    /// <summary>
    /// Reads the release version from the DLL's informational version, which is also its product version.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped, like <c>0.1.0+&lt;commit&gt;</c>.</param>
    /// <returns>The version, or <see langword="null"/> for one with a pre-release tag, like <c>0.0.0-dev</c>, or none.</returns>
    public static Version? OfStamp(string informationalVersion)
    {
        var version = informationalVersion.Split('+')[0];
        return !version.Contains('-') && Version.TryParse(version, out var parsed) ? parsed : null;
    }

    /// <summary>
    /// Writes a version with every part it lacks as 0, so <c>0.6.8</c> and <c>0.6.8.0</c> count as one.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <returns>The version with four parts.</returns>
    public static Version Padded(Version version) =>
        new(version.Major, version.Minor, Math.Max(version.Build, 0), Math.Max(version.Revision, 0));
}
