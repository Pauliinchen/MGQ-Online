//----------------------------------------------------------------
//  GameWindow.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Passed key presses and typed characters on to Keyboard while a text screen wants them
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The game's window, whose game RGSS pauses while another application is active.
/// </summary>
internal static unsafe partial class GameWindow
{
    /// <summary>
    /// The class RGSS registers its window under.
    /// </summary>
    private const string ClassName = "RGSS Player";

    /// <summary>
    /// The index of a window's procedure among its values.
    /// </summary>
    private const int ProcedureIndex = -4;

    /// <summary>
    /// WM_ACTIVATEAPP, which tells a window that its application became active or inactive.
    /// </summary>
    private const uint ActivateApp = 0x1C;

    /// <summary>
    /// WM_KEYDOWN, a key going down.
    /// </summary>
    private const uint KeyDown = 0x0100;

    /// <summary>
    /// WM_CHAR, a character Windows made from a key press.
    /// </summary>
    private const uint Character = 0x0102;

    /// <summary>
    /// WM_SYSKEYDOWN, a key going down while Alt is held, as with AltGr.
    /// </summary>
    private const uint SystemKeyDown = 0x0104;

    /// <summary>
    /// The window procedure that was in place before, which gets every message on.
    /// </summary>
    private static nint previousProcedure;

    /// <summary>
    /// Keeps the game running while another application is active, once.
    /// </summary>
    /// <remarks>
    /// RGSS301.dll learns of it only from WM_ACTIVATEAPP, and its frame loop waits while the last
    /// one said inactive.
    /// </remarks>
    /// <returns><see langword="true"/> when the game keeps running.</returns>
    public static bool KeepRunning()
    {
        if (previousProcedure != 0)
        {
            return true;
        }

        var window = Find();

        if (window == 0)
        {
            return false;
        }

        var procedure = (nint)(delegate* unmanaged[Stdcall]<nint, uint, nint, nint, nint>)&Procedure;
        previousProcedure = SetWindowLongW(window, ProcedureIndex, procedure);

        if (previousProcedure == 0)
        {
            return false;
        }

        // The game may have started behind another application, which RGSS remembers until told otherwise.
        PostMessageW(window, ActivateApp, 1, 0);
        return true;
    }

    /// <summary>
    /// Finds the window of this game, not of another game running next to it.
    /// </summary>
    /// <returns>The window, or 0 when there is none.</returns>
    private static nint Find()
    {
        var process = (uint)Environment.ProcessId;
        nint window = 0;

        while ((window = FindWindowExW(0, window, ClassName, null)) != 0)
        {
            GetWindowThreadProcessId(window, out var owner);

            if (owner == process)
            {
                return window;
            }
        }

        return 0;
    }

    /// <summary>
    /// Hands every message on, telling the game its application is active whenever Windows says
    /// either, and passing what is typed to <see cref="Keyboard"/> while it wants it.
    /// </summary>
    /// <param name="window">The game's window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns>What the previous procedure returned.</returns>
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static nint Procedure(nint window, uint message, nint wParam, nint lParam)
    {
        if (message == ActivateApp)
        {
            wParam = 1;
        }
        else if (Keyboard.Active)
        {
            if (message == Character)
            {
                Keyboard.TakeCharacter((char)wParam);
            }
            else if (message is KeyDown or SystemKeyDown)
            {
                Keyboard.TakeKey((uint)wParam, (uint)(lParam >> 16) & 0xFF);
            }
        }

        return CallWindowProcW(previousProcedure, window, message, wParam, lParam);
    }

    /// <summary>
    /// Finds a top-level window by its class.
    /// </summary>
    /// <param name="parent">0 for top-level windows.</param>
    /// <param name="after">The window to continue after, 0 to start with the first.</param>
    /// <param name="className">The window class.</param>
    /// <param name="title">The window title, <see langword="null"/> for any.</param>
    /// <returns>The window, or 0 when no more match.</returns>
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint FindWindowExW(nint parent, nint after, string className, string? title);

    /// <summary>
    /// Finds the process that owns a window.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="process">The id of the process.</param>
    /// <returns>The id of the thread that created the window.</returns>
    [LibraryImport("user32.dll")]
    private static partial uint GetWindowThreadProcessId(nint window, out uint process);

    /// <summary>
    /// Replaces one of a window's values.
    /// </summary>
    /// <remarks>
    /// The 32-bit user32.dll exports no SetWindowLongPtrW, and a pointer fits a LONG in a 32-bit process.
    /// </remarks>
    /// <param name="window">The window.</param>
    /// <param name="index">Which value.</param>
    /// <param name="value">The new value.</param>
    /// <returns>The previous value, or 0 when it failed.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint SetWindowLongW(nint window, int index, nint value);

    /// <summary>
    /// Hands a message to a window procedure.
    /// </summary>
    /// <param name="procedure">The window procedure.</param>
    /// <param name="window">The window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns>What the procedure returned.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint CallWindowProcW(nint procedure, nint window, uint message, nint wParam, nint lParam);

    /// <summary>
    /// Queues a message for a window.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns><see langword="true"/> when it was queued.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool PostMessageW(nint window, uint message, nint wParam, nint lParam);
}
