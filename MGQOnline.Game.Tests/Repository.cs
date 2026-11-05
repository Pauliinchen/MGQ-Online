//----------------------------------------------------------------
//  Repository.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQOnline.Game.Tests;

/// <summary>
/// The repository the tests were built in, for the tests that read its sources and shipped files.
/// </summary>
internal static class Repository
{
    /// <summary>
    /// Gets the repository's folder: the first folder above the tests that holds the solution.
    /// </summary>
    public static string Root { get; } = FindRoot();

    /// <summary>
    /// Finds the repository's folder.
    /// </summary>
    /// <returns>Its full path.</returns>
    /// <exception cref="DirectoryNotFoundException">No folder above the tests holds the solution.</exception>
    private static string FindRoot()
    {
        for (DirectoryInfo? folder = new(AppContext.BaseDirectory); folder is not null; folder = folder.Parent)
        {
            if (File.Exists(Path.Combine(folder.FullName, "MGQ-Online.slnx")))
            {
                return folder.FullName;
            }
        }

        throw new DirectoryNotFoundException($"MGQ-Online.slnx is in no folder above {AppContext.BaseDirectory}");
    }
}
