//----------------------------------------------------------------
//  LocalWorlds.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-28: Wrote a world described anew at once
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Multiplayer.Network.World;

/// <summary>
/// The worlds on this PC: a folder each in Patch/Multiplayer/Worlds, named by a hash of the world
/// code (<see cref="WorldCode.IdOf"/>), with its world.ini and the world's Save folder.
/// </summary>
/// <remarks>
/// The worlds are read from their folders once until one is written, made or deleted, since the
/// world screen asks every few frames; a world described anew keeps that in the worlds read until
/// then, as the scripts' copy of a world did.
/// </remarks>
/// <param name="folder">The folder of the worlds, a full path.</param>
/// <param name="shownFolder">How the log and the scripts name it, relative to the game folder, such as "Patch/Multiplayer/Worlds".</param>
/// <param name="now">Tells the time in seconds since 1970, when a world was made or played.</param>
internal sealed class LocalWorlds(string folder, string shownFolder, Func<long> now)
{
    /// <summary>
    /// The folder below a world's that holds its saves.
    /// </summary>
    public const string SaveFolder = "Save";

    /// <summary>
    /// How many characters a folder's id has.
    /// </summary>
    private const int IdLength = 12;

    /// <summary>
    /// The worlds read, <see langword="null"/> until the next look reads their folders.
    /// </summary>
    private List<LocalWorld>? _all;

    /// <summary>
    /// Gets a number that changes whenever the worlds on this PC change.
    /// </summary>
    public long Revision { get; private set; }

    /// <summary>
    /// Lists the worlds on this PC.
    /// </summary>
    /// <returns>The worlds whose folder holds a world.ini with their world code.</returns>
    public IReadOnlyList<LocalWorld> All() => _all ??= List();

    /// <summary>
    /// Finds a world on this PC by its folder's id.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>The world, <see langword="null"/> when there is none.</returns>
    public LocalWorld? Find(string id) => All().FirstOrDefault(world => world.Id == id);

    /// <summary>
    /// Makes a world's folder, or finds the one there is, and describes the world in it.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <param name="about">What the directory says of the world.</param>
    /// <returns>The world, <see langword="null"/> when the text is no world code, the folder could not
    /// be made, its world.ini exists but could not be read, which is then left as it is, or could not
    /// be written.</returns>
    public LocalWorld? Found(string code, LocalWorldAbout about)
    {
        if (WorldCode.Parse(code) is not { } parsed)
        {
            Log.Write($"no folder for world {Short(about.DirectoryId)}: the relay's answer holds no world code");
            return null;
        }

        string id = WorldCode.IdOf(parsed.Token);
        try
        {
            Directory.CreateDirectory(FolderOf(id));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not create a world's folder: {e.GetType().Name}: {e.Message}");
            return null;
        }

        if (IniFile.Load(IniOf(id), ShownIniOf(id), false) is not { } values)
        {
            Log.Write($"left folder {id} of world {Short(about.DirectoryId)} as it is: its {LocalWorld.FileName} exists but could not be read");
            return null;
        }

        LocalWorld? known = LocalWorld.Of(id, values);
        LocalWorld world = (known ?? LocalWorld.Read(id, new Dictionary<string, string>(StringComparer.Ordinal) { ["code"] = code }) with { Created = now() }).Described(about);
        bool written = Write(world);
        Log.Write($"{(known != null ? "found" : "made")} folder {id} of world {Short(about.DirectoryId)} ({world.Name}){(written ? "" : ", but world.ini could not be written")}");
        return written ? world : null;
    }

    /// <summary>
    /// Describes a world anew as the directory says it and writes its world.ini at once.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <param name="about">What the directory says of the world.</param>
    /// <returns>The world described anew, <see langword="null"/> when there is none or its world.ini
    /// could not be written.</returns>
    public LocalWorld? Describe(string id, LocalWorldAbout about)
    {
        if (Find(id) is not { } found)
        {
            return null;
        }

        LocalWorld world = found.Described(about);
        if (!Write(world))
        {
            Log.Write($"folder {id} of world {Short(about.DirectoryId)} ({world.Name}) could not be described: world.ini could not be written");
            return null;
        }

        return world;
    }

    /// <summary>
    /// Changes a world and writes its world.ini.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <param name="change">The change, such as a new difficulty.</param>
    /// <returns>The world as written and whether it was; <see langword="null"/> when there is none.</returns>
    public (LocalWorld World, bool Written)? Update(string id, Func<LocalWorld, LocalWorld> change)
    {
        if (Find(id) is not { } found)
        {
            return null;
        }

        LocalWorld world = change(found);
        return (world, Write(world));
    }

    /// <summary>
    /// Tells the time a world is played or made at.
    /// </summary>
    /// <returns>Seconds since 1970.</returns>
    public long Now() => now();

    /// <summary>
    /// Finds a world's latest save, an autosave included, by the files themselves, since the game
    /// only finds a world's saves while the world is open.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>The save and its path relative to the game folder, <see langword="null"/> without any.</returns>
    public (LatestSave Save, string Path)? LatestSave(string id)
    {
        string saves = Path.Combine(FolderOf(id), SaveFolder);
        try
        {
            if (!Directory.Exists(saves))
            {
                return null;
            }

            IEnumerable<(string, DateTime)> files = new DirectoryInfo(saves).EnumerateFiles()
                .OrderBy(file => file.Name, StringComparer.OrdinalIgnoreCase)
                .Select(file => (file.Name, file.LastWriteTimeUtc));
            return WorldSaves.Latest(files) is { } latest ? (latest, $"{shownFolder}/{id}/{SaveFolder}/{latest.File}") : null;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not look at the saves of world {id}: {e.GetType().Name}: {e.Message}");
            return null;
        }
    }

    /// <summary>
    /// Deletes a world's folder with everything in it: this game's saves of the world, and that it
    /// remembers the world's password.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>Whether it was deleted.</returns>
    public bool Delete(string id)
    {
        LocalWorld? world = Find(id);
        Forget();
        try
        {
            Directory.Delete(FolderOf(id), true);
            Log.Write($"deleted folder {id} of world {Short(world?.DirectoryId)} ({world?.Name}) with its saves");
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not delete world {id}: {e.GetType().Name}: {e.Message}");
            return false;
        }
    }

    /// <summary>
    /// Shortens a directory id for the log, as the scripts do.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first 12 characters, "none" for none.</returns>
    private static string Short(string? id) => id == null ? "none" : id[..Math.Min(id.Length, 12)];

    /// <summary>
    /// Writes a world's world.ini; the worlds are read again at the next look.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>Whether it was written.</returns>
    private bool Write(LocalWorld world)
    {
        Forget();
        return IniFile.Write(IniOf(world.Id), ShownIniOf(world.Id), world.Values());
    }

    /// <summary>
    /// Forgets the worlds read, so the next look reads their folders again.
    /// </summary>
    private void Forget()
    {
        _all = null;
        Revision++;
    }

    /// <summary>
    /// Reads the worlds from their folders.
    /// </summary>
    /// <returns>The worlds.</returns>
    private List<LocalWorld> List()
    {
        try
        {
            if (!Directory.Exists(folder))
            {
                return [];
            }

            return [.. new DirectoryInfo(folder).EnumerateDirectories()
                .Select(entry => entry.Name)
                .Where(IsId)
                .Order(StringComparer.Ordinal)
                .Select(id => IniFile.Load(IniOf(id), ShownIniOf(id), false) is { } values ? LocalWorld.Of(id, values) : null)
                .OfType<LocalWorld>()];
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not list the worlds: {e.GetType().Name}: {e.Message}");
            return [];
        }
    }

    /// <summary>
    /// Tells whether a folder's name is a world's id: 12 small hexadecimal digits.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsId(string name) => name.Length == IdLength && name.All(character => char.IsAsciiDigit(character) || character is >= 'a' and <= 'f');

    /// <summary>
    /// Builds a world's folder.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>Its full path.</returns>
    private string FolderOf(string id) => Path.Combine(folder, id);

    /// <summary>
    /// Builds a world's world.ini.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>Its full path.</returns>
    private string IniOf(string id) => Path.Combine(FolderOf(id), LocalWorld.FileName);

    /// <summary>
    /// Names a world's world.ini for the log.
    /// </summary>
    /// <param name="id">The folder's id.</param>
    /// <returns>Its path relative to the game folder.</returns>
    private string ShownIniOf(string id) => $"{shownFolder}/{id}/{LocalWorld.FileName}";
}
