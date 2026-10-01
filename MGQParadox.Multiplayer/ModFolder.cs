//----------------------------------------------------------------
//  ModFolder.cs
//
//  Changelog:
//      Paulinchen  2026-10-01: Built the game's paths from the folder two above the mod folder, now that it is Patch\Multiplayer
//      Paulinchen  2026-09-30: Built paths the game script names relative to the game's folder
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The mod folder, Patch\Multiplayer in the game folder, which holds the DLL and everything it reads or writes.
/// </summary>
internal static class ModFolder
{
    /// <summary>
    /// Full path of the folder, without a trailing separator.
    /// </summary>
    public static string Root { get; private set; } = WithoutTrailingSeparator(AppContext.BaseDirectory);

    /// <summary>
    /// Points the folder somewhere else.
    /// </summary>
    /// <param name="root">Full path of the folder.</param>
    public static void SetRoot(string root) => Root = WithoutTrailingSeparator(root);

    /// <summary>
    /// Builds the path of a file inside the folder.
    /// </summary>
    /// <param name="fileName">The name of the file.</param>
    /// <returns>The full path of the file.</returns>
    public static string PathOf(string fileName) => Path.Combine(Root, fileName);

    /// <summary>
    /// Builds the path of a file the game script names relative to the game's folder.
    /// </summary>
    /// <param name="path">The path, relative to the game's folder or full.</param>
    /// <returns>The full path.</returns>
    public static string GamePathOf(string path) => GamePathOf(path, Root);

    /// <summary>
    /// Builds the path of a file the game script names relative to the game's folder, two folders above the mod folder.
    /// </summary>
    /// <param name="path">The path, relative to the game's folder or full.</param>
    /// <param name="modFolder">Full path of the mod folder, Patch\Multiplayer in the game folder.</param>
    /// <returns>The full path.</returns>
    internal static string GamePathOf(string path, string modFolder)
    {
        var patch = Path.GetDirectoryName(modFolder) ?? modFolder;
        return Path.GetFullPath(Path.Combine(Path.GetDirectoryName(patch) ?? patch, path));
    }

    /// <summary>
    /// Removes a trailing separator from a folder path.
    /// </summary>
    /// <param name="path">The folder path.</param>
    /// <returns>The path without a trailing separator.</returns>
    private static string WithoutTrailingSeparator(string path) => path.TrimEnd('\\', '/');
}
