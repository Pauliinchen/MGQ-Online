//----------------------------------------------------------------
//  Exports.Input.cs
//
//  Changelog:
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of what the player types and copies: the keyboard and the clipboard.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Puts a text on the clipboard, such as a hidden world's id for its creator to hand out.
    /// </summary>
    /// <param name="text">The text, UTF-8 and null-terminated.</param>
    /// <returns>1 when the clipboard holds it, 0 otherwise.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_copy_text", CallConvs = [typeof(CallConvStdcall)])]
    public static int CopyText(byte* text)
    {
        try
        {
            return Clipboard.SetText(Text(text)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_copy_text failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts or stops taking what the player types into the game's window.
    /// </summary>
    /// <param name="on">1 to take it, 0 to stop.</param>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_typing", CallConvs = [typeof(CallConvStdcall)])]
    public static int Typing(int on)
    {
        try
        {
            Keyboard.SetActive(on != 0);
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_typing failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out what was typed since the last call, see <see cref="Keyboard.Take"/>.
    /// </summary>
    /// <param name="buffer">Receives <c>keys=</c> the number of keys that went down, then the typed characters, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_take_typed", CallConvs = [typeof(CallConvStdcall)])]
    public static int TakeTyped(byte* buffer, int size)
    {
        try
        {
            var (text, keys) = Keyboard.Take();
            return Copy(new Message([new("keys", keys.ToString(System.Globalization.CultureInfo.InvariantCulture))], text).Encode(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_take_typed failed: {ex}");
            return 0;
        }
    }
}
