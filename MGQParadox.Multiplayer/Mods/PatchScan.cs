//----------------------------------------------------------------
//  PatchScan.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Reads which version of each mod of the mod browser the game's Patch folder holds, and removes
/// an installed mod's files.
/// </summary>
internal static class PatchScan
{
    /// <summary>
    /// Tells how each mod stands in the Patch folder.
    /// </summary>
    /// <param name="mods">The mods.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <returns>Each mod's state by its id.</returns>
    public static IReadOnlyDictionary<string, ModState> Detect(IReadOnlyList<BrowsedMod> mods, string patch)
    {
        var read = new Dictionary<string, (bool Exists, byte[]? Bytes)>(StringComparer.OrdinalIgnoreCase);
        var states = new Dictionary<string, ModState>(StringComparer.Ordinal);

        (bool Exists, byte[]? Bytes) FileAt(string path)
        {
            if (!read.TryGetValue(path, out var file))
            {
                read[path] = file = ReadFile(patch, path);
            }

            return file;
        }

        foreach (var mod in mods)
        {
            var installed = mod.Known.FirstOrDefault(version => version.Files.All(file => FileAt(file.Key).Bytes is { } bytes && ModHash.Matches(file.Key, bytes, file.Value)));
            var state = installed != null
                ? new ModState(installed.Version == mod.Latest ? ModStatus.Current : ModStatus.Update, installed)
                : new ModState(mod.Known.SelectMany(version => version.Files.Keys).Any(path => FileAt(path).Exists) ? ModStatus.Changed : ModStatus.Available, null);
            states[mod.Id] = state;
            Log.Write($"mod browser: {mod.Id} is {state.Status}{(installed != null ? $", {installed.Version} installed" : string.Empty)}, latest {mod.Latest}");
        }

        return states;
    }

    /// <summary>
    /// Deletes the DLLs an install renamed out of the way, as far as the game no longer has them loaded.
    /// </summary>
    /// <param name="patch">The full path of the Patch folder.</param>
    public static void DeleteOldDlls(string patch)
    {
        if (!Directory.Exists(patch))
        {
            return;
        }

        var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true };

        foreach (var file in Directory.EnumerateFiles(patch, "*.dll" + ModInstaller.OldDllSuffix, options).Where(file => file.EndsWith(".dll" + ModInstaller.OldDllSuffix, StringComparison.OrdinalIgnoreCase)))
        {
            try
            {
                File.Delete(file);
                Log.Write($"deleted {Path.GetRelativePath(patch, file)} in Patch, a DLL an install renamed out of the way");
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // The game still has it loaded until it restarts.
            }
        }
    }

    /// <summary>
    /// Removes the files of a mod's installed version that are still exactly that version's, then the
    /// folders inside Patch that leaves empty.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="installed">The version installed.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="kept">Paths inside Patch that other installed mods ship, which stay.</param>
    /// <returns>The paths inside Patch removed, and those that could not be removed.</returns>
    public static (IReadOnlyList<string> Removed, IReadOnlyList<string> Failed) Remove(BrowsedMod mod, ModVersion installed, string patch, IReadOnlySet<string> kept)
    {
        var removed = new List<string>();
        var failed = new List<string>();
        var folders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var (path, hash) in installed.Files)
        {
            if (kept.Contains(path))
            {
                Log.Write($"kept {path} in Patch, which another installed mod ships too");
                continue;
            }

            var full = Path.GetFullPath(Path.Combine(patch, path));

            try
            {
                if (!full.StartsWith(patch + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !File.Exists(full))
                {
                    continue;
                }

                if (!ModHash.Matches(path, File.ReadAllBytes(full), hash))
                {
                    Log.Write($"kept {path} in Patch, which differs from {mod.Name} {installed.Version}");
                    continue;
                }

                Delete(full, patch);
                removed.Add(path);
                folders.Add(Path.GetDirectoryName(full)!);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"could not remove {path} of {mod.Name} in Patch: {ex.Message}");
                failed.Add(path);
            }
        }

        foreach (var folder in folders.OrderByDescending(folder => folder.Length))
        {
            DeleteEmptyFolders(folder, patch);
        }

        return (removed, failed);
    }

    /// <summary>
    /// Deletes a mod's file, renaming a DLL the game has loaded out of the way instead.
    /// </summary>
    /// <param name="full">The file's full path.</param>
    /// <param name="patch">The full path of the Patch folder, which the log names the file from.</param>
    /// <exception cref="IOException">The file could not be deleted or renamed.</exception>
    /// <exception cref="UnauthorizedAccessException">The file may not be deleted or renamed.</exception>
    private static void Delete(string full, string patch)
    {
        try
        {
            File.Delete(full);
            Log.Write($"removed {Path.GetRelativePath(patch, full)} in Patch");
        }
        catch (Exception ex) when ((ex is IOException or UnauthorizedAccessException) && full.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
        {
            File.Move(full, full + ModInstaller.OldDllSuffix, overwrite: true);
            Log.Write($"renamed {Path.GetRelativePath(patch, full)} in Patch out of the way, which is likely loaded: {ex.Message}");
        }
    }

    /// <summary>
    /// Deletes a folder and the folders above it while they are empty, up to the Patch folder, which stays.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    private static void DeleteEmptyFolders(string folder, string patch)
    {
        try
        {
            while (folder.StartsWith(patch + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) && Directory.Exists(folder) && !Directory.EnumerateFileSystemEntries(folder).Any())
            {
                Directory.Delete(folder);
                Log.Write($"removed the empty folder {Path.GetRelativePath(patch, folder)} in Patch");
                folder = Path.GetDirectoryName(folder)!;
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not remove the folder {Path.GetRelativePath(patch, folder)} in Patch: {ex.Message}");
        }
    }

    /// <summary>
    /// Reads a file inside Patch.
    /// </summary>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="path">The path inside Patch.</param>
    /// <returns>Whether it exists, and its bytes; none for a file missing, outside Patch or that cannot be read.</returns>
    private static (bool Exists, byte[]? Bytes) ReadFile(string patch, string path)
    {
        var full = Path.GetFullPath(Path.Combine(patch, path));

        if (!full.StartsWith(patch + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !File.Exists(full))
        {
            return (false, null);
        }

        try
        {
            return (true, File.ReadAllBytes(full));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not read {path} in Patch: {ex.Message}");
            return (true, null);
        }
    }
}
