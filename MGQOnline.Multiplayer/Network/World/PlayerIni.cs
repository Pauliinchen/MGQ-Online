//----------------------------------------------------------------
//  PlayerIni.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;

namespace MGQOnline.Multiplayer.Network.World;

/// <summary>
/// Patch\Multiplayer\Player.ini, which only the DLL reads and writes: the player's key, which never leaves the DLL, the name the
/// player chose, the last name Discord told, and every setting of the scripts, such as the hotkeys, the boxes' places and the favourite
/// worlds. It tells <see cref="Player"/> who plays.
/// </summary>
/// <remarks>
/// A Player.ini that exists but cannot be read is never written, since writing it would lose the player key and every setting.
/// </remarks>
internal sealed class PlayerIni
{
    /// <summary>
    /// The file's name inside the mod folder.
    /// </summary>
    public const string FileName = "Player.ini";

    /// <summary>
    /// The setting that keeps the player's key.
    /// </summary>
    public const string KeySetting = "id";

    /// <summary>
    /// The setting that keeps the name the player chose.
    /// </summary>
    public const string NameSetting = "name";

    /// <summary>
    /// The setting that keeps the last name Discord told.
    /// </summary>
    public const string DiscordNameSetting = "discord_name";

    /// <summary>
    /// What the notification box tells once a session while Player.ini exists but cannot be read and a write was turned down for it.
    /// </summary>
    public const string UnreadableNotice = "Player.ini could not be read; close programs that hold it. Settings are not saved until then.";

    /// <summary>
    /// Longest name kept, as the scripts cut names.
    /// </summary>
    private const int MaxNameLength = 32;

    /// <summary>
    /// What stands in for a name with nothing left of it once cleaned.
    /// </summary>
    private const string NameFallback = "A friend";

    /// <summary>
    /// Size of a new player key before it is written as hexadecimal.
    /// </summary>
    private const int KeyBytes = 16;

    /// <summary>
    /// The file's full path.
    /// </summary>
    private readonly string _path;

    /// <summary>
    /// Makes a new player key.
    /// </summary>
    private readonly Func<string> _newKey;

    /// <summary>
    /// Tells who plays to the worlds, <see cref="Player.Set"/> outside the tests.
    /// </summary>
    private readonly Func<string, string, bool> _setPlayer;

    /// <summary>
    /// The values by setting, <see langword="null"/> until read and while the file cannot be read.
    /// </summary>
    private OrderedDictionary<string, string>? _values;

    /// <summary>
    /// Whether the last read failed, which keeps the next failures out of the log.
    /// </summary>
    private bool _unreadable;

    /// <summary>
    /// Whether a write was turned down since the file became unreadable.
    /// </summary>
    private bool _refused;

    /// <summary>
    /// The name Discord tells this session, empty until it told one.
    /// </summary>
    private string _discordName = string.Empty;

    /// <summary>
    /// The name and whether it was taken, as the worlds were last told; <see langword="null"/> before the first time.
    /// </summary>
    private (string? Name, bool Taken)? _told;

    /// <summary>
    /// Creates the owner of a Player.ini, read once it is first asked.
    /// </summary>
    /// <param name="path">The file's full path.</param>
    /// <param name="newKey">Makes a new player key; 32 random lowercase hexadecimal characters by default.</param>
    /// <param name="setPlayer">Tells who plays to the worlds; <see cref="Player.Set"/> by default.</param>
    public PlayerIni(string path, Func<string>? newKey = null, Func<string, string, bool>? setPlayer = null)
    {
        _path = path;
        _newKey = newKey ?? (() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(KeyBytes)));
        _setPlayer = setPlayer ?? Player.Set;
    }

    /// <summary>
    /// Tells whether the file was read, or is missing, so its settings are known.
    /// </summary>
    public bool Readable => Load() is not null;

    /// <summary>
    /// Lists the settings in the file's order, the player key left out; none while the file cannot be read.
    /// </summary>
    public IReadOnlyList<KeyValuePair<string, string>> Settings =>
        Load() is { } values ? values.Where(pair => pair.Key != KeySetting).ToList() : [];

    /// <summary>
    /// Gets the notice the notification box tells while a write was turned down for an unreadable file, <see langword="null"/> otherwise.
    /// </summary>
    public string? Notice => _refused ? UnreadableNotice : null;

    /// <summary>
    /// Gets the name the others see: the one the player chose, or else their name on Discord, or the last one Discord told while it has
    /// not told one this session.
    /// </summary>
    public string? Name
    {
        get
        {
            var values = Load();
            var chosen = Value(values, NameSetting);

            if (chosen.Length > 0)
            {
                return Cleaned(chosen, NameFallback);
            }

            var discord = _discordName.Length > 0 ? _discordName : Value(values, DiscordNameSetting);
            return discord.Length == 0 ? null : Cleaned(discord, NameFallback);
        }
    }

    /// <summary>
    /// Cleans a name the player or Discord gave as the scripts do: control characters and backslashes, which start message codes, go,
    /// then the spaces around it, and it is cut to 32 characters.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <param name="fallback">What stands in when nothing is left of it.</param>
    /// <returns>The name, or the fallback.</returns>
    internal static string Cleaned(string? name, string fallback)
    {
        var kept = new string((name ?? string.Empty).Where(character => character >= ' ' && character != '\\').ToArray()).Trim(' ');
        var cut = string.Concat(kept.EnumerateRunes().Take(MaxNameLength).Select(rune => rune.ToString()));
        return cut.Length == 0 ? fallback : cut;
    }

    /// <summary>
    /// Keeps and removes settings in one write. A setting kept moves to the end of the file, so a list such as the hidden worlds added
    /// reads back the oldest first.
    /// </summary>
    /// <remarks>
    /// A setting that could not be written still holds for the session, unless the file could not be read.
    /// </remarks>
    /// <param name="changes">The values by setting, <see langword="null"/> for one to remove.</param>
    /// <returns>Whether the file was written.</returns>
    public bool Change(IEnumerable<KeyValuePair<string, string?>> changes)
    {
        if (Writable() is not { } values)
        {
            return false;
        }

        foreach (var (key, value) in changes)
        {
            values.Remove(key);

            if (value is not null)
            {
                values[key] = value;
            }
        }

        return IniFile.Write(_path, FileName, values);
    }

    /// <summary>
    /// Takes the name Discord tells, and keeps it for the sessions Discord tells none.
    /// </summary>
    /// <param name="name">The name.</param>
    public void TellDiscordName(string name)
    {
        _discordName = name;

        if (name.Length > 0 && Value(Load(), DiscordNameSetting) != name && Change([new(DiscordNameSetting, name)]))
        {
            Log.Write($"kept the name Discord told: {name}");
        }
    }

    /// <summary>
    /// Keeps the name the player chose, which replaces their name on Discord; an empty one forgets the chosen name, so the name on Discord
    /// stands again. Then tells the worlds who plays.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Whether the worlds took who plays.</returns>
    public bool ChooseName(string name)
    {
        var chosen = Cleaned(name, string.Empty);
        Change([new(NameSetting, chosen.Length == 0 ? null : chosen)]);
        Log.Write(chosen.Length == 0 ? $"cleared the chosen name, the name on Discord stands: {(Name is { } shown ? $"\"{shown}\"" : "nil")}" : $"chose the name {chosen}");
        return Share();
    }

    /// <summary>
    /// Tells the worlds who plays, the key made first the first time, once the player has a name.
    /// </summary>
    /// <returns>Whether the worlds took who plays.</returns>
    public bool Share()
    {
        var name = Name;
        var key = Key();
        var taken = name is not null && key.Length > 0 && _setPlayer(key, name);

        if (_told != (name, taken))
        {
            _told = (name, taken);

            if (!taken)
            {
                Log.Write($"could not say who plays in worlds: {(name is null ? "no name yet" : key.Length == 0 ? "no player key" : "it was refused")}");
            }
        }

        return taken;
    }

    /// <summary>
    /// Reads the player's key, making one the first time.
    /// </summary>
    /// <returns>The key, empty while the file cannot be read.</returns>
    private string Key()
    {
        if (Writable() is not { } values)
        {
            return string.Empty;
        }

        if (Value(values, KeySetting).Length == 0)
        {
            values[KeySetting] = _newKey();
            IniFile.Write(_path, FileName, values);
            Log.Write($"made a new player key and kept it in {FileName}");
        }

        return values[KeySetting];
    }

    /// <summary>
    /// Reads the file once, and again whenever asked while it cannot be read.
    /// </summary>
    /// <returns>The values by setting, <see langword="null"/> while the file exists but cannot be read.</returns>
    private OrderedDictionary<string, string>? Load()
    {
        if (_values is not null)
        {
            return _values;
        }

        var values = IniFile.Load(_path, FileName, _unreadable);

        if (values is null)
        {
            _unreadable = true;
            return null;
        }

        if (_unreadable)
        {
            Log.Write($"read {FileName} again");
        }

        _unreadable = false;
        _refused = false;
        _values = values;
        return values;
    }

    /// <summary>
    /// Gives the values to change, unless the file exists but cannot be read.
    /// </summary>
    /// <returns>The values by setting, <see langword="null"/> while the file cannot be read.</returns>
    private OrderedDictionary<string, string>? Writable()
    {
        if (Load() is { } values)
        {
            return values;
        }

        if (!_refused)
        {
            _refused = true;
            Log.Write($"{FileName} exists but could not be read; not writing it, so the player key and settings are kept");
        }

        return null;
    }

    /// <summary>
    /// Reads a setting.
    /// </summary>
    /// <param name="values">The values, <see langword="null"/> while the file cannot be read.</param>
    /// <param name="key">The setting.</param>
    /// <returns>Its value, empty while it is not set.</returns>
    private static string Value(OrderedDictionary<string, string>? values, string key) =>
        values is not null && values.TryGetValue(key, out var value) ? value : string.Empty;
}
