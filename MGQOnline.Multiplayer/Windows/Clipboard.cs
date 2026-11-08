//----------------------------------------------------------------
//  Clipboard.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-01: Dropped reading the clipboard, which the Mod Framework's text fields paste from
//      Paulinchen  2026-10-31: Found the game's window itself, since the Mod Framework hooks it
//      Paulinchen  2026-10-07: Logged clipboard failures with the Windows error
//                            - Found the game's window through GameWindow
//      Paulinchen  2026-10-06: Read the clipboard's text no further than its memory goes
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.InteropServices;

namespace MGQOnline.Multiplayer.Windows;

/// <summary>
/// The Windows clipboard, which the mod copies text to.
/// </summary>
internal static unsafe partial class Clipboard
{
    /// <summary>
    /// The clipboard format of UTF-16 text.
    /// </summary>
    private const uint UnicodeText = 13;

    /// <summary>
    /// The class RGSS registers its window under.
    /// </summary>
    private const string GameWindowClass = "RGSS Player";

    /// <summary>
    /// Memory the clipboard can take over.
    /// </summary>
    private const uint Moveable = 0x2;

    /// <summary>
    /// Replaces the clipboard's content with a text.
    /// </summary>
    /// <remarks>
    /// Windows turns the text away unless a window owns the clipboard, so the game's window does.
    /// </remarks>
    /// <param name="text">The text.</param>
    /// <returns><see langword="true"/> when the clipboard holds it.</returns>
    public static bool SetText(string text)
    {
        if (!OpenClipboard(FindGameWindow()))
        {
            LogError("could not be opened to write");
            return false;
        }

        try
        {
            EmptyClipboard();

            var size = (nuint)((text.Length + 1) * sizeof(char));
            var memory = GlobalAlloc(Moveable, size);

            if (memory == 0)
            {
                LogError($"got no memory for {text.Length} characters");
                return false;
            }

            var target = (char*)GlobalLock(memory);

            if (target == null)
            {
                LogError("could not lock its memory to write");
                GlobalFree(memory);
                return false;
            }

            text.AsSpan().CopyTo(new Span<char>(target, text.Length));
            target[text.Length] = '\0';
            GlobalUnlock(memory);

            if (SetClipboardData(UnicodeText, memory) != 0)
            {
                return true;
            }

            LogError("did not take the text");
            GlobalFree(memory);
            return false;
        }
        finally
        {
            CloseClipboard();
        }
    }

    /// <summary>
    /// Logs why the clipboard failed, with the error Windows names.
    /// </summary>
    /// <param name="what">What failed.</param>
    private static void LogError(string what) => Log.Write($"clipboard {what}, Windows error {Marshal.GetLastPInvokeError()}");

    /// <summary>
    /// Opens the clipboard for this thread.
    /// </summary>
    /// <param name="owner">The window that owns what is put on it.</param>
    /// <returns><see langword="true"/> when it opened.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenClipboard(nint owner);

    /// <summary>
    /// Closes the clipboard.
    /// </summary>
    /// <returns><see langword="true"/> when it closed.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseClipboard();

    /// <summary>
    /// Empties the open clipboard and makes the window that opened it its owner.
    /// </summary>
    /// <returns><see langword="true"/> when it emptied.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EmptyClipboard();

    /// <summary>
    /// Hands memory over to the open clipboard.
    /// </summary>
    /// <param name="format">The clipboard format.</param>
    /// <param name="memory">The memory, which the clipboard owns once this succeeds.</param>
    /// <returns>The memory, or 0 when it failed.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    private static partial nint SetClipboardData(uint format, nint memory);

    /// <summary>
    /// Allocates memory the clipboard can take over.
    /// </summary>
    /// <param name="flags">How to allocate it.</param>
    /// <param name="size">The size in bytes.</param>
    /// <returns>The memory, or 0 when it failed.</returns>
    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial nint GlobalAlloc(uint flags, nuint size);

    /// <summary>
    /// Frees memory the clipboard did not take over.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>0 when it was freed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalFree(nint memory);

    /// <summary>
    /// Makes memory addressable.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>Its address, or <see langword="null"/> when it failed.</returns>
    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial void* GlobalLock(nint memory);

    /// <summary>
    /// Ends what <see cref="GlobalLock"/> started.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>Whether other locks remain.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GlobalUnlock(nint memory);

    /// <summary>
    /// Finds the window of this game, not of another game running next to it, which owns the
    /// clipboard while the mod writes it.
    /// </summary>
    /// <returns>The window, or 0 when there is none.</returns>
    private static nint FindGameWindow()
    {
        var process = (uint)Environment.ProcessId;
        nint window = 0;
        while ((window = FindWindowExW(0, window, GameWindowClass, null)) != 0)
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
}
