//----------------------------------------------------------------
//  PatchScripts.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Lists the scripts of the game's Patch folder, which the required-mods check, the mod picker and
/// a world's details read.
/// </summary>
internal static class PatchScripts
{
    /// <summary>
    /// The folder the mods lie in, in the game folder.
    /// </summary>
    private const string PatchName = "Patch";

    /// <summary>
    /// This mod's folder in Patch, whose files are none of the player's mods.
    /// </summary>
    private const string OwnFolderName = "Multiplayer";

    /// <summary>
    /// The extension of a script.
    /// </summary>
    private const string ScriptExtension = ".rb";

    /// <summary>
    /// Lists every script in Patch and in its folders, but those of this mod's folder and names that
    /// start with a dot, following a link to a folder once.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>Each script's path relative to the game folder with forward slashes, sorted ignoring case; <see langword="null"/> when a folder could not be read.</returns>
    public static IReadOnlyList<string>? List(string gameFolder)
    {
        string game = Path.GetFullPath(gameFolder);
        string patch = Path.Combine(game, PatchName);

        try
        {
            List<string> found = [];
            if (Directory.Exists(patch))
            {
                Collect(new DirectoryInfo(patch), game, Path.Combine(patch, OwnFolderName), found, new HashSet<string>(StringComparer.OrdinalIgnoreCase) { patch });
            }

            found.Sort(StringComparer.OrdinalIgnoreCase);
            return found;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"the scripts in Patch could not be listed: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Adds the scripts of a folder and its folders.
    /// </summary>
    /// <param name="folder">The folder.</param>
    /// <param name="game">The game folder, which the paths are relative to.</param>
    /// <param name="own">This mod's folder, left out.</param>
    /// <param name="found">The scripts found so far.</param>
    /// <param name="visited">The folders listed, by their real paths, so a link to one is listed once.</param>
    private static void Collect(DirectoryInfo folder, string game, string own, List<string> found, HashSet<string> visited)
    {
        foreach (FileSystemInfo entry in folder.EnumerateFileSystemInfos().Where(entry => !entry.Name.StartsWith('.')))
        {
            if (entry is not DirectoryInfo directory)
            {
                if (entry.Name.EndsWith(ScriptExtension, StringComparison.OrdinalIgnoreCase))
                {
                    found.Add(Path.GetRelativePath(game, entry.FullName).Replace('\\', '/'));
                }

                continue;
            }

            if (string.Equals(Path.TrimEndingDirectorySeparator(directory.FullName), own, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            string real = directory.Attributes.HasFlag(FileAttributes.ReparsePoint) && directory.ResolveLinkTarget(returnFinalTarget: true) is { Exists: true } target
                ? Path.TrimEndingDirectorySeparator(target.FullName)
                : directory.FullName;
            if (visited.Add(real))
            {
                Collect(directory, game, own, found, visited);
            }
        }
    }
}
