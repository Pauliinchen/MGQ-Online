//----------------------------------------------------------------
//  ModInstaller.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Installed a link to a zip of a release like an upload, and read zips written with backslashes
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
/// they moved into place, so a download that differs changes nothing.
/// </summary>
internal static class ModInstaller
{
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

            foreach (var (file, target) in staged)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Copy(file, target, overwrite: true);
            }

            return staged.Select(file => Path.GetRelativePath(gameFolder, file.Target)).ToList();
        }
        finally
        {
            try
            {
                Directory.Delete(stage, recursive: true);
            }
            catch (IOException)
            {
                // A staging folder left behind costs only disk space in the temporary folder.
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

        return ModHash.Of(name, bytes) == hash ? (bytes, path) : throw new InvalidDataException($"{mod.Name} differs from the version the relay checked. It may just have been updated: try again in a minute.");
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

        // Some zip tools of Windows write backslashes, which the relay reads as slashes too.
        foreach (var entry in archive.Entries)
        {
            entries.TryAdd(entry.FullName.Replace('\\', '/'), entry);
        }

        var files = new List<(byte[] Bytes, string Path)>();

        foreach (var (name, hash) in mod.Files)
        {
            var entry = entries.GetValueOrDefault(name) ?? throw new InvalidDataException($"{mod.Name} lacks {name}.");
            using var stream = entry.Open();
            using var copy = new MemoryStream();
            stream.CopyTo(copy);
            var bytes = copy.ToArray();

            if (ModHash.Of(name, bytes) != hash)
            {
                throw new InvalidDataException($"{name} of {mod.Name} differs from the version the relay keeps.");
            }

            files.Add((bytes, Inside(patch, Path.Combine(patch, name), mod)));
        }

        return files;
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
