//----------------------------------------------------------------
//  UpdateMutex.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace MGQOnline.Helper;

/// <summary>
/// The named mutex the update holds for its game folder while it runs, so the watchdog never starts
/// a game of its own beside the one the update starts.
/// </summary>
internal static class UpdateMutex
{
    /// <summary>
    /// What starts the mutex's name, in this session's namespace.
    /// </summary>
    private const string Prefix = @"Local\MGQ-Online update ";

    /// <summary>
    /// How many hexadecimal characters of the folder's hash the name keeps.
    /// </summary>
    private const int HashLength = 32;

    /// <summary>
    /// Names the mutex of a game folder.
    /// </summary>
    /// <remarks>
    /// A mutex's name may not hold a backslash, so the folder goes in as a hash.
    /// </remarks>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>The name, the same for every spelling of the folder that differs only in case or a trailing separator.</returns>
    public static string NameOf(string gameFolder)
    {
        var folder = Path.TrimEndingDirectorySeparator(Path.GetFullPath(gameFolder)).ToUpperInvariant();
        return Prefix + Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(folder)))[..HashLength];
    }

    /// <summary>
    /// Takes the mutex of a game folder.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>The mutex, held until it is disposed or the process ends; <see langword="null"/> while another update of the folder holds it.</returns>
    public static Mutex? Take(string gameFolder)
    {
        var mutex = new Mutex(initiallyOwned: true, NameOf(gameFolder), out var createdNew);

        if (createdNew)
        {
            return mutex;
        }

        mutex.Dispose();
        return null;
    }

    /// <summary>
    /// Tells whether an update of a game folder runs.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>Whether its mutex exists; <see langword="true"/> as well when it exists but may not be opened.</returns>
    public static bool Held(string gameFolder)
    {
        try
        {
            if (!Mutex.TryOpenExisting(NameOf(gameFolder), out var mutex))
            {
                return false;
            }

            mutex.Dispose();
            return true;
        }
        catch (UnauthorizedAccessException)
        {
            return true;
        }
    }
}
