//----------------------------------------------------------------
//  Exports.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Logged the Wine version the game runs under, if any
//      Paulinchen  2026-10-07: Kept every log, which no longer starts over, and logged the version started and whether the game keeps running in the background
//                            - Answered a null buffer with the length needed, and opened Copy and Text to the tests
//      Paulinchen  2026-09-30: Split the exports into files per area: Pvp, World, Directory and Input
//                            - Added mp_check_for_update and mp_newer_version
//                            - Took a starting save in mp_dir_create, and added mp_dir_fetch_start, which fetches it for new players
//                            - Took whether a world is hidden in mp_dir_create, dropped the seats from mp_dir_unlock, and added mp_copy_text
//      Paulinchen  2026-09-29: Added mp_set_player, mp_player_id, the mp_dir_* functions of the world directory and the keyboard's mp_typing and mp_take_typed, dropping the world code functions the directory replaces
//                            - Added mp_new_id, which hands out a random id for the player
//                            - Added the mp_world_* functions for entering a world and passing messages there
//                            - Dropped the port from mp_host, since hosting waits at the relay
//                            - Added mp_status, the state without the friend's team
//                            - Took an empty message instead of leaving it to block the ones behind it
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions GameScript/Multiplayer.rb calls through Win32API.
/// </summary>
/// <remarks>
/// Nothing may throw out of these, since an exception crossing into the game ends it.
/// </remarks>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Finds the mod folder and starts the log. Calling it again does nothing harmful.
    /// </summary>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_start", CallConvs = [typeof(CallConvStdcall)])]
    public static int Start()
    {
        try
        {
            if (NativeMethods.FileOfModuleContaining((nint)(delegate* unmanaged[Stdcall]<int>)&Start) is { } dll)
            {
                ModFolder.SetRoot(Path.GetDirectoryName(dll)!);
            }

            var version = typeof(Exports).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "unknown";
            Log.Write($"--- multiplayer {version} started ---");

            if (NativeMethods.WineVersion() is { } wine)
            {
                Log.Write($"the game runs under wine {wine}");
            }

            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_start failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Keeps the game running while another application is active. Calling it again does nothing.
    /// </summary>
    /// <returns>1 when the game keeps running, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_keep_running", CallConvs = [typeof(CallConvStdcall)])]
    public static int KeepRunning()
    {
        try
        {
            var running = GameWindow.KeepRunning();
            Log.Write(running ? "the game keeps running in the background" : "the game cannot keep running in the background: its window was not found or not hooked");
            return running ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_keep_running failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts asking GitHub for a newer release. Calling it again does nothing.
    /// </summary>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_check_for_update", CallConvs = [typeof(CallConvStdcall)])]
    public static int CheckForUpdate()
    {
        try
        {
            UpdateCheck.Start();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_check_for_update failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the version of a newer release, once the check found one.
    /// </summary>
    /// <param name="buffer">Receives the version, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The version's length, 0 while there is none or it does not fit.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_newer_version", CallConvs = [typeof(CallConvStdcall)])]
    public static int NewerVersion(byte* buffer, int size)
    {
        try
        {
            var version = UpdateCheck.NewerVersion;
            return version == null ? 0 : Math.Max(Copy(version, buffer, size), 0);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_newer_version failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Writes a text into a buffer of the game script.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="buffer">Receives the text, UTF-8 and null-terminated; <see langword="null"/> to only ask how much room it needs.</param>
    /// <param name="size">The size of the buffer in bytes, which the text and its terminating null must fit in.</param>
    /// <returns>The text's length in bytes, or its length negated when the buffer is missing or too small.</returns>
    internal static int Copy(string text, byte* buffer, int size)
    {
        var bytes = Encoding.UTF8.GetBytes(text);

        if (buffer == null || size < 0 || bytes.Length >= size)
        {
            return -bytes.Length;
        }

        bytes.CopyTo(new Span<byte>(buffer, size));
        buffer[bytes.Length] = 0;
        return bytes.Length;
    }

    /// <summary>
    /// Reads a text the game script handed over.
    /// </summary>
    /// <param name="text">The text, UTF-8 and null-terminated.</param>
    /// <returns>The text, empty for a null pointer.</returns>
    internal static string Text(byte* text) => Marshal.PtrToStringUTF8((nint)text) ?? string.Empty;
}
