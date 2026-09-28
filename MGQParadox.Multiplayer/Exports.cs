//----------------------------------------------------------------
//  Exports.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Added mp_status, the state without the friend's team
//                            - Took an empty message instead of leaving it to block the ones behind it
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions GameScript/Multiplayer.rb calls through Win32API.
/// </summary>
/// <remarks>
/// Nothing may throw out of these, since an exception crossing into the game ends it.
/// </remarks>
internal static unsafe class Exports
{
    /// <summary>
    /// Size at which the log starts over.
    /// </summary>
    private const long MaxLogBytes = 200_000;

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

            Log.ClearIfLargerThan(MaxLogBytes);
            Log.Write("--- multiplayer started ---");
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
            return GameWindow.KeepRunning() ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_keep_running failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Takes the player's name, which the friend sees. Sent with every later host or join.
    /// </summary>
    /// <param name="name">The name, UTF-8 and null-terminated.</param>
    /// <returns>1 when taken, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_set_player_name", CallConvs = [typeof(CallConvStdcall)])]
    public static int SetPlayerName(byte* name)
    {
        try
        {
            Session.Current.SetPlayerName(Text(name));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_set_player_name failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts hosting. Returns at once, the network runs on a thread of its own.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <param name="port">The port to listen on.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_host", CallConvs = [typeof(CallConvStdcall)])]
    public static int Host(byte* game, byte* payload, int port)
    {
        try
        {
            Session.Current.Host(Text(game), Text(payload), port);
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_host failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Joins the host of the Discord invite that is waiting. Returns at once.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_join_invite", CallConvs = [typeof(CallConvStdcall)])]
    public static int JoinInvite(byte* game, byte* payload)
    {
        try
        {
            Session.Current.JoinInvite(Text(game), Text(payload));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_join_invite failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Joins the host whose join code is on the clipboard. Returns at once.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_join_clipboard", CallConvs = [typeof(CallConvStdcall)])]
    public static int JoinClipboard(byte* game, byte* payload)
    {
        try
        {
            Session.Current.JoinClipboard(Text(game), Text(payload));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_join_clipboard failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Keeps the join code of an invite the player accepted in Discord, which the Discord mod hands over,
    /// until the player joins with it.
    /// </summary>
    /// <param name="joinCode">The invite's join code, UTF-8 and null-terminated.</param>
    /// <returns>1 when taken, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_receive_invite", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReceiveInvite(byte* joinCode)
    {
        try
        {
            Session.Current.ReceiveInvite(Text(joinCode));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_receive_invite failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Stops hosting or joining, closes the link, forgets what arrived and turns down a waiting invite.
    /// </summary>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_cancel", CallConvs = [typeof(CallConvStdcall)])]
    public static int Cancel()
    {
        try
        {
            Session.Current.Cancel();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_cancel failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Puts the join code of the hosted connection on the clipboard again.
    /// </summary>
    /// <returns>1 when the clipboard holds it, 0 otherwise.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_copy_code", CallConvs = [typeof(CallConvStdcall)])]
    public static int CopyCode()
    {
        try
        {
            return Session.Current.CopyJoinCode() ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_copy_code failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the connection stands, with what the friend handed over once it arrived.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int State(byte* buffer, int size)
    {
        try
        {
            return Copy(Session.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the connection stands, without what the friend handed over, for the checks the
    /// game script makes many times a second.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_status", CallConvs = [typeof(CallConvStdcall)])]
    public static int Status(byte* buffer, int size)
    {
        try
        {
            return Copy(Session.Current.Describe(includeTeam: false), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_status failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Sends a message to the friend. Returns at once, the link sends it on a thread of its own.
    /// </summary>
    /// <param name="text">The message, UTF-8 and null-terminated.</param>
    /// <returns>1 when it goes out, 0 without an open link or when it is too long.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_send", CallConvs = [typeof(CallConvStdcall)])]
    public static int Send(byte* text)
    {
        try
        {
            return Session.Current.Send(Text(text)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_send failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the oldest message from the friend and takes it, unless the buffer is too small for it.
    /// </summary>
    /// <param name="buffer">Receives the message, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The message's length, or its length negated when the buffer is too small, 0 while none waits or for an empty one.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_receive", CallConvs = [typeof(CallConvStdcall)])]
    public static int Receive(byte* buffer, int size)
    {
        try
        {
            if (Session.Current.PeekMessage() is not { } message)
            {
                return 0;
            }

            var length = Copy(message, buffer, size);

            // An empty message reads as none waiting, but it has to be taken all the same, or it
            // would block every message behind it.
            if (length >= 0)
            {
                Session.Current.TakeMessage();
            }

            return length;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_receive failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Writes a text into a buffer of the game script.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="buffer">Receives the text, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length in bytes, or its length negated when the buffer is too small.</returns>
    private static int Copy(string text, byte* buffer, int size)
    {
        var bytes = Encoding.UTF8.GetBytes(text);

        if (bytes.Length >= size)
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
    private static string Text(byte* text) => Marshal.PtrToStringUTF8((nint)text) ?? string.Empty;
}
