//----------------------------------------------------------------
//  WorldLists.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The player's lists of worlds, kept in Player.ini: the favourite worlds (<c>favourite.&lt;id&gt;=1</c>)
/// and the hidden worlds added by their ids (<c>added.&lt;id&gt;=1</c>, the oldest first), with the
/// files of earlier versions moved into it once.
/// </summary>
/// <param name="player">The Player.ini.</param>
/// <param name="modFolder">The mod folder, which holds the files of earlier versions.</param>
/// <param name="frame">Tells the bridge's frame, which spaces out the tries to move those files.</param>
internal sealed class WorldLists(PlayerIni player, string modFolder, Func<long> frame)
{
    /// <summary>
    /// What the settings of the favourite worlds start with, before a world's id.
    /// </summary>
    public const string FavouriteSetting = "favourite.";

    /// <summary>
    /// What the settings of the hidden worlds added start with, before a world's id.
    /// </summary>
    public const string AddedSetting = "added.";

    /// <summary>
    /// Most hidden worlds kept, as many as the relay lists by their ids for one player.
    /// </summary>
    /// <remarks>
    /// The ids of deleted worlds are never listed again and so never removed by hand; without the
    /// limit they would crowd the newest ones out of what the relay lists.
    /// </remarks>
    public const int MaxAdded = 50;

    /// <summary>
    /// The frames between two tries to move the files of earlier versions, a second at 60 frames.
    /// </summary>
    public const long RetryFrames = 60;

    /// <summary>
    /// The files of earlier versions in the mod folder, with what their settings start with in Player.ini.
    /// </summary>
    private static readonly (string File, string Prefix)[] OldFiles = [("Favourites.ini", FavouriteSetting), ("Added.ini", AddedSetting)];

    /// <summary>
    /// Whether the files of earlier versions were moved, or there were none.
    /// </summary>
    private bool _merged;

    /// <summary>
    /// The frame of the last try that had to wait, <see langword="null"/> before one.
    /// </summary>
    private long? _triedAt;

    /// <summary>
    /// Lists the favourite worlds.
    /// </summary>
    /// <returns>Their directory ids, in the order Player.ini keeps them.</returns>
    public IReadOnlyList<string> Favourites()
    {
        Merge();
        return KeysUnder(FavouriteSetting);
    }

    /// <summary>
    /// Lists the hidden worlds added.
    /// </summary>
    /// <returns>Their directory ids, the one added last at the end.</returns>
    public IReadOnlyList<string> Added()
    {
        Merge();
        return KeysUnder(AddedSetting);
    }

    /// <summary>
    /// Marks a world as a favourite, or no longer.
    /// </summary>
    /// <param name="id">The world's directory id.</param>
    /// <param name="on">Whether it becomes one; <see langword="null"/> to turn it the other way.</param>
    /// <returns>Whether it is a favourite now; <see langword="null"/> when it stays as it was since Player.ini cannot be read.</returns>
    public bool? Favour(string id, bool? on)
    {
        Merge();
        string key = FavouriteSetting + id;
        bool was = IsSet(key);
        bool favourite = on ?? !was;
        if (favourite == was)
        {
            return favourite;
        }

        player.Change([new KeyValuePair<string, string?>(key, favourite ? "1" : null)]);
        if (IsSet(key) != favourite)
        {
            Log.Write($"world {Short(id)} stays as it was: Player.ini cannot be read");
            return null;
        }

        Log.Write($"world {Short(id)} {(favourite ? "is a favourite now" : "is no longer a favourite")}");
        return favourite;
    }

    /// <summary>
    /// Adds a hidden world, and forgets those added longest ago beyond <see cref="MaxAdded"/>.
    /// </summary>
    /// <param name="id">The world's directory id.</param>
    /// <returns>Whether Player.ini was written.</returns>
    public bool Add(string id)
    {
        List<string> ids = [.. Added().Where(old => old != id), id];
        List<string> dropped = ids.Count > MaxAdded ? ids[..(ids.Count - MaxAdded)] : [];
        List<KeyValuePair<string, string?>> changes = [.. dropped.Select(old => new KeyValuePair<string, string?>(AddedSetting + old, null)), new(AddedSetting + id, "1")];
        if (!Kept(player.Change(changes), $"add hidden world {Short(id)} to the list"))
        {
            return false;
        }

        string forgot = dropped.Count == 0 ? "" : $", forgot the oldest: {string.Join(", ", dropped.Select(Short))}";
        Log.Write($"added hidden world {Short(id)} to the list{forgot}");
        return true;
    }

    /// <summary>
    /// Takes a hidden world off the list again.
    /// </summary>
    /// <param name="id">The world's directory id.</param>
    /// <returns>Whether Player.ini was written.</returns>
    public bool Remove(string id)
    {
        Merge();
        if (!Kept(player.Change([new KeyValuePair<string, string?>(AddedSetting + id, null)]), $"remove hidden world {Short(id)} from the list"))
        {
            return false;
        }

        Log.Write($"removed hidden world {Short(id)} from the list");
        return true;
    }

    /// <summary>
    /// Moves the entries of the files of earlier versions into Player.ini, a setting it holds already
    /// winning, then deletes the files; tried again at most every <see cref="RetryFrames"/> until it worked.
    /// </summary>
    /// <remarks>
    /// Nothing is moved or deleted while any of the files or Player.ini cannot be read, so no entry is lost.
    /// </remarks>
    public void Merge()
    {
        if (_merged || (_triedAt is { } tried && frame() - tried < RetryFrames && frame() >= tried))
        {
            return;
        }

        List<(string File, string Prefix)> files = [.. OldFiles.Where(old => File.Exists(Path.Combine(modFolder, old.File)))];
        if (files.Count == 0)
        {
            _merged = true;
            return;
        }

        List<KeyValuePair<string, string>> entries = [];
        foreach ((string file, string prefix) in files)
        {
            if (IniFile.Load(Path.Combine(modFolder, file), file, _triedAt != null) is not { } values)
            {
                Later($"{string.Join(" or ", files.Select(old => old.File))} could not be read");
                return;
            }

            entries.AddRange(values.Select(pair => new KeyValuePair<string, string>(prefix + pair.Key, pair.Value)));
        }

        if (!player.Readable)
        {
            Later("Player.ini could not be read");
            return;
        }

        HashSet<string> held = [.. player.Settings.Select(setting => setting.Key)];
        List<KeyValuePair<string, string?>> fresh = [.. entries.Where(entry => !held.Contains(entry.Key)).Select(entry => new KeyValuePair<string, string?>(entry.Key, entry.Value))];
        if (!player.Change(fresh))
        {
            Later("Player.ini could not be written");
            return;
        }

        _merged = true;
        Log.Write($"moved the {entries.Count} entries of {string.Join(" and ", files.Select(old => old.File))} into Player.ini, {entries.Count - fresh.Count} of which it held already");
        foreach ((string file, _) in files)
        {
            Delete(file);
        }
    }

    /// <summary>
    /// Shortens a directory id for the log, as the scripts do.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first 12 characters.</returns>
    private static string Short(string id) => id[..Math.Min(id.Length, 12)];

    /// <summary>
    /// Logs a change of a list that Player.ini did not take.
    /// </summary>
    /// <param name="written">Whether Player.ini was written.</param>
    /// <param name="what">The change, for the log.</param>
    /// <returns>Whether it was written.</returns>
    private static bool Kept(bool written, string what)
    {
        if (!written)
        {
            Log.Write($"could not {what}: Player.ini was not written");
        }

        return written;
    }

    /// <summary>
    /// Lists the settings whose keys start with a prefix.
    /// </summary>
    /// <param name="prefix">What their keys start with.</param>
    /// <returns>The rest of each key after the prefix, in the order Player.ini keeps them.</returns>
    private List<string> KeysUnder(string prefix) =>
        [.. player.Settings.Where(setting => setting.Key.StartsWith(prefix, StringComparison.Ordinal)).Select(setting => setting.Key[prefix.Length..])];

    /// <summary>
    /// Tells whether Player.ini holds a setting.
    /// </summary>
    /// <param name="key">The setting.</param>
    /// <returns>Whether it does.</returns>
    private bool IsSet(string key) => player.Settings.Any(setting => setting.Key == key);

    /// <summary>
    /// Notes that the move must wait, logged once until it worked.
    /// </summary>
    /// <param name="reason">Why it waits.</param>
    private void Later(string reason)
    {
        if (_triedAt == null)
        {
            Log.Write($"did not move the favourites and hidden worlds into Player.ini yet: {reason}");
        }

        _triedAt = frame();
    }

    /// <summary>
    /// Deletes a file of an earlier version whose entries Player.ini holds now.
    /// </summary>
    /// <param name="file">The file.</param>
    private void Delete(string file)
    {
        try
        {
            File.Delete(Path.Combine(modFolder, file));
            Log.Write($"deleted {file}");
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not delete {file}, so the next start moves its entries again: {e.GetType().Name}: {e.Message}");
        }
    }
}
