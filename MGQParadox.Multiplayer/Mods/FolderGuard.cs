//----------------------------------------------------------------
//  FolderGuard.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Keeps the files a download writes inside the folder they belong in, whatever a path inside the
/// download says.
/// </summary>
internal static class FolderGuard
{
    /// <summary>
    /// Resolves a path and tells whether it lies inside a folder.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <param name="path">The path, full or relative to the current folder.</param>
    /// <returns>The path's full form, or <see langword="null"/> when it lies outside the folder or is the folder itself.</returns>
    public static string? Inside(string folder, string path)
    {
        var full = Path.GetFullPath(path);
        return full.StartsWith(Path.TrimEndingDirectorySeparator(folder) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) ? full : null;
    }
}
