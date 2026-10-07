//----------------------------------------------------------------
//  Player.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Logged who plays once it changes, and why a player was not taken
//                            - Cleaned the name through PlayerName, shared with the PvP session
//      Paulinchen  2026-10-06: Read the key and name at once, and said what the DLL says while they are not set
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Threading;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// Who plays this game in worlds: the key only this game knows, which proves the player to the
/// relay, and the name the others see. The game script sets both.
/// </summary>
internal static class Player
{
    /// <summary>
    /// Length of a player's key, in hexadecimal characters.
    /// </summary>
    private const int KeyLength = 32;

    /// <summary>
    /// Longest name passed on, as the relay takes it.
    /// </summary>
    private const int MaxNameLength = 32;

    /// <summary>
    /// What the DLL says while the game script has not set the player.
    /// </summary>
    public const string NotSet = "The game has not said who plays yet.";

    /// <summary>
    /// The player's key and name, swapped as one.
    /// </summary>
    private static Identity? current;

    /// <summary>
    /// The player's key, <see langword="null"/> until the game script set a valid one.
    /// </summary>
    public static string? Key => Volatile.Read(ref current)?.Key;

    /// <summary>
    /// The player's name, <see langword="null"/> until the game script set one.
    /// </summary>
    public static string? Name => Volatile.Read(ref current)?.Name;

    /// <summary>
    /// Reads the player's key and name at once.
    /// </summary>
    /// <returns>The key and name, <see langword="null"/> until the game script set them.</returns>
    public static (string Key, string Name)? Current() => Volatile.Read(ref current) is { } identity ? (identity.Key, identity.Name) : null;

    /// <summary>
    /// Sets the player's key and name.
    /// </summary>
    /// <param name="key">The key, 32 lowercase hexadecimal characters.</param>
    /// <param name="name">The name.</param>
    /// <returns><see langword="false"/> when the key or the name is not as it must be.</returns>
    public static bool Set(string key, string name)
    {
        var cleaned = PlayerName.Cleaned(name, MaxNameLength);

        if (key.Length != KeyLength || !key.All(character => character is (>= '0' and <= '9') or (>= 'a' and <= 'f')) || cleaned.Length == 0)
        {
            Log.Write($"player not taken: {(cleaned.Length == 0 ? "the name is empty" : "the key is malformed")}");
            return false;
        }

        var identity = new Identity(key, cleaned);

        if (Interlocked.Exchange(ref current, identity) != identity)
        {
            Log.Write($"player is {identity.Name}, id {Log.Short(WorldKeys.PlayerIdOf(key))}");
        }

        return true;
    }

    /// <summary>
    /// A player's key and name.
    /// </summary>
    /// <param name="Key">The key.</param>
    /// <param name="Name">The name.</param>
    private sealed record Identity(string Key, string Name);
}
