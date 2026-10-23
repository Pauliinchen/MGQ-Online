//----------------------------------------------------------------
//  Exports.Input.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped mp_take_typed, since the text box in C# takes what is typed
//      Paulinchen  2026-10-12: Added mp_mouse_wheel
//      Paulinchen  2026-10-06: Kept what was typed when the game script's buffer was too small
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of what the player types, copies and turns: the keyboard, the clipboard and the
/// mouse wheel.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Hands out the mouse wheel's notches turned over the game's window since the last call.
    /// </summary>
    /// <returns>The notches, positive away from the player; 0 for none or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mouse_wheel", CallConvs = [typeof(CallConvStdcall)])]
    public static int TakeWheel()
    {
        try
        {
            return GameWindow.Wheel.Take();
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mouse_wheel failed: {ex}");
            return 0;
        }
    }

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
}
