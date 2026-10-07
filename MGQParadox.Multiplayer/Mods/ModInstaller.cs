//----------------------------------------------------------------
//  ModInstaller.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Logged each file's hash check, each file written or put back, and the files a zip holds that no catalog entry names
//      Paulinchen  2026-10-06: Put every replaced file back when one cannot be written, so a failed install leaves the old version whole
//                            - Deleted the files an older version of a zip mod shipped that the installed one no longer has
//                            - Refused a zip that holds a file twice, as the relay does
//                            - Read a zip whose files sit in a Patch folder, to extract into the game folder
//                            - Installed a link to a zip of a release like an upload, and read zips written with backslashes
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Installs a world's mods into the game's Patch folder: every file is checked against the
/// catalog's hash and kept in a folder of its own first, and only once every mod checked out are
/// they moved into place, so a download that differs changes nothing; a file that cannot be
/// written puts back the ones written before it.
/// </summary>
internal static class ModInstaller
{
    /// <summary>
    /// The folder a zip for players holds its files in, read as the Patch folder itself.
    /// </summary>
    private const string PatchFolder = "Patch/";

    /// <summary>
    /// Installs mods.
    /// </summary>
    /// <param name="mods">Each mod, and for a script where it goes, relative to the game's folder; a zip's files go to their paths inside Patch.</param>
    /// <param name="download">Fetches a mod: a script, or a zip of a release or an upload.</param>
    /// <param name="gameFolder">The game's folder, which holds Patch.</param>
    /// <returns>The files written, relative to the game's folder.</returns>
    /// <exception cref="InvalidDataException">A file differs from the catalog, is missing, or would land outside Patch.</exception>
    public static IReadOnlyList<string> Install(IReadOnlyList<(CatalogMod Mod, string Target)> mods, Func<CatalogMod, byte[]> download, string gameFolder)
    {
        var patch = Path.GetFullPath(Path.Combine(gameFolder, "Patch"));
        var staged = new List<(string Staged, string Target)>();
        var stage = Directory.CreateTempSubdirectory("mgqmp-mods-").FullName;

        try
        {
            foreach (var (mod, target) in mods)
            {
                var files = mod.IsZip ? FilesOfZip(mod, download(mod), patch) : [FileOfLink(mod, download(mod), target, gameFolder, patch)];

                foreach (var (bytes, path) in files)
                {
                    var file = Path.Combine(stage, staged.Count.ToString(System.Globalization.CultureInfo.InvariantCulture));
                    File.WriteAllBytes(file, bytes);
                    staged.Add((file, path));
                }
            }

            MoveIntoPlace(staged, stage, patch);
            var written = new HashSet<string>(staged.Select(file => file.Target), StringComparer.OrdinalIgnoreCase);

            foreach (var (mod, _) in mods.Where(mod => mod.Mod.IsZip))
            {
                RemoveOldFiles(mod, patch, written);
            }

            return staged.Select(file => Path.GetRelativePath(gameFolder, file.Target)).ToList();
        }
        finally
        {
            try
            {
                Directory.Delete(stage, recursive: true);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // A staging folder left behind costs only disk space in the temporary folder.
            }
        }
    }

    /// <summary>
    /// Copies the checked files into place, keeping a copy of each file it replaces first.
    /// </summary>
    /// <param name="staged">Each checked file in the staging folder and its full target path.</param>
    /// <param name="stage">The staging folder, which also keeps the replaced files.</param>
    /// <param name="patch">The full path of the Patch folder, which the log names the files from.</param>
    /// <exception cref="IOException">A file could not be written; every file written before it is put back.</exception>
    /// <exception cref="UnauthorizedAccessException">A file may not be written; every file written before it is put back.</exception>
    private static void MoveIntoPlace(IReadOnlyList<(string Staged, string Target)> staged, string stage, string patch)
    {
        var done = new List<(string Target, string? Backup)>();

        try
        {
            foreach (var (file, target) in staged)
            {
                string? backup = null;

                if (File.Exists(target))
                {
                    backup = Path.Combine(stage, $"backup-{done.Count.ToString(System.Globalization.CultureInfo.InvariantCulture)}");
                    File.Copy(target, backup, overwrite: true);
                }

                done.Add((target, backup));
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Copy(file, target, overwrite: true);
                Log.Write($"wrote {Path.GetRelativePath(patch, target)} in Patch{(backup != null ? ", replacing the file there" : ", a new file")}");
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            PutBack(done, patch);
            throw;
        }
    }

    /// <summary>
    /// Puts back the files an install wrote before one failed, the last written first.
    /// </summary>
    /// <param name="done">Each file written and the copy of the file it replaced, <see langword="null"/> for a new one.</param>
    /// <param name="patch">The full path of the Patch folder, which the log names the files from.</param>
    private static void PutBack(List<(string Target, string? Backup)> done, string patch)
    {
        for (var index = done.Count - 1; index >= 0; index--)
        {
            var (target, backup) = done[index];

            try
            {
                if (backup != null)
                {
                    File.Copy(backup, target, overwrite: true);
                    Log.Write($"put the earlier {Path.GetRelativePath(patch, target)} in Patch back");
                }
                else if (File.Exists(target))
                {
                    File.Delete(target);
                    Log.Write($"deleted the new {Path.GetRelativePath(patch, target)} in Patch again");
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"could not put {Path.GetRelativePath(patch, target)} in Patch back: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Deletes the files an older version of a zip mod shipped that the installed version no longer
    /// has, each only while it is exactly that version's file.
    /// </summary>
    /// <remarks>
    /// The mod loader loads every script in Patch, so a script a newer version dropped would still run.
    /// </remarks>
    /// <param name="mod">The mod just installed.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="written">The full paths just written, which stay whatever an older version named them.</param>
    private static void RemoveOldFiles(CatalogMod mod, string patch, IReadOnlySet<string> written)
    {
        foreach (var version in mod.Versions)
        {
            foreach (var (name, hash) in version.Files)
            {
                var path = Path.GetFullPath(Path.Combine(patch, name));

                if (mod.Files.ContainsKey(name) || written.Contains(path) || !path.StartsWith(patch + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try
                {
                    if (File.Exists(path) && ModHash.OfFile(path) == hash)
                    {
                        File.Delete(path);
                        Log.Write($"removed {Path.GetRelativePath(patch, path)}, which {mod.Name} {version.Version} shipped and {mod.Version} no longer does");
                    }
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    Log.Write($"could not remove {Path.GetRelativePath(patch, path)} of an older {mod.Name}: {ex.Message}");
                }
            }
        }
    }

    /// <summary>
    /// Checks a link mod's script.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="bytes">The script as downloaded.</param>
    /// <param name="target">Where it goes, relative to the game's folder.</param>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <returns>The script and its full target path.</returns>
    private static (byte[] Bytes, string Path) FileOfLink(CatalogMod mod, byte[] bytes, string target, string gameFolder, string patch)
    {
        var (name, hash) = mod.Files.Count == 1 ? mod.Files.First() : throw new InvalidDataException($"{mod.Name} names no single script.");
        var path = Inside(patch, Path.Combine(gameFolder, target), mod);

        if (!path.EndsWith(".rb", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException($"{mod.Name} would not be installed as a script.");
        }

        return Checked(mod, name, bytes, hash) ? (bytes, path) : throw new InvalidDataException($"{mod.Name} differs from the version the relay checked. It may just have been updated: try again in a minute.");
    }

    /// <summary>
    /// Checks the files of a mod that comes as a zip, each of which the zip must hold with the catalog's hash.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="zip">The zip as downloaded.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <returns>Each file and its full target path.</returns>
    private static List<(byte[] Bytes, string Path)> FilesOfZip(CatalogMod mod, byte[] zip, string patch)
    {
        using var archive = new ZipArchive(new MemoryStream(zip), ZipArchiveMode.Read);
        var entries = new Dictionary<string, ZipArchiveEntry>(StringComparer.Ordinal);

        // Some zip tools of Windows write backslashes, and a zip for players holds a Patch folder to
        // extract into the game folder; the relay reads both the same way.
        foreach (var entry in archive.Entries)
        {
            var name = entry.FullName.Replace('\\', '/');
            var path = name.StartsWith(PatchFolder, StringComparison.OrdinalIgnoreCase) ? name[PatchFolder.Length..] : name;

            if (!entries.TryAdd(path, entry) && path.Length > 0 && !path.EndsWith('/'))
            {
                throw new InvalidDataException($"{mod.Name} holds {path} twice.");
            }
        }

        var files = new List<(byte[] Bytes, string Path)>();

        foreach (var (name, hash) in mod.Files)
        {
            var entry = entries.GetValueOrDefault(name) ?? throw new InvalidDataException($"{mod.Name} lacks {name}.");
            using var stream = entry.Open();
            using var copy = new MemoryStream();
            stream.CopyTo(copy);
            var bytes = copy.ToArray();

            if (!Checked(mod, name, bytes, hash))
            {
                throw new InvalidDataException($"{name} of {mod.Name} differs from the version the relay keeps.");
            }

            files.Add((bytes, Inside(patch, Path.Combine(patch, name), mod)));
        }

        foreach (var path in entries.Keys.Where(path => path.Length > 0 && !path.EndsWith('/') && !mod.Files.ContainsKey(path)))
        {
            Log.Write($"left out {path} of {mod.Name}, which the catalog does not name");
        }

        return files;
    }

    /// <summary>
    /// Checks a downloaded file against the catalog's hash, and logs the outcome.
    /// </summary>
    /// <param name="mod">The mod it belongs to.</param>
    /// <param name="name">The file's name or path, as the catalog names it.</param>
    /// <param name="bytes">The file as downloaded.</param>
    /// <param name="hash">The catalog's hash.</param>
    /// <returns>Whether the hashes match.</returns>
    private static bool Checked(CatalogMod mod, string name, byte[] bytes, string hash)
    {
        var actual = ModHash.Of(name, bytes);
        var matches = actual == hash;
        Log.Write(matches
            ? $"{name} of {mod.Name} {mod.Version} matches the catalog, {bytes.Length} bytes"
            : $"{name} of {mod.Name} {mod.Version} differs from the catalog: hash {Log.Short(actual)}, the catalog says {Log.Short(hash)}");
        return matches;
    }

    /// <summary>
    /// Makes sure a path lies inside the Patch folder.
    /// </summary>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="path">The path.</param>
    /// <param name="mod">The mod it belongs to.</param>
    /// <returns>The full path.</returns>
    private static string Inside(string patch, string path, CatalogMod mod)
    {
        var full = Path.GetFullPath(path);
        return full.StartsWith(patch + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) ? full : throw new InvalidDataException($"{mod.Name} would land outside the Patch folder.");
    }
}
