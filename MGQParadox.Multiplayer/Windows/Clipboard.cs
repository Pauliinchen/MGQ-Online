//----------------------------------------------------------------
//  Clipboard.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Read the clipboard's text no further than its memory goes
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// The Windows clipboard, which carries a join code when Discord's invites do not.
/// </summary>
internal static unsafe partial class Clipboard
{
    /// <summary>
    /// The clipboard format of UTF-16 text.
    /// </summary>
    private const uint UnicodeText = 13;

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
        using var game = Process.GetCurrentProcess();

        if (!OpenClipboard(game.MainWindowHandle))
        {
            return false;
        }

        try
        {
            EmptyClipboard();

            var size = (nuint)((text.Length + 1) * sizeof(char));
            var memory = GlobalAlloc(Moveable, size);

            if (memory == 0)
            {
                return false;
            }

            var target = (char*)GlobalLock(memory);

            if (target == null)
            {
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

            GlobalFree(memory);
            return false;
        }
        finally
        {
            CloseClipboard();
        }
    }

    /// <summary>
    /// Reads the clipboard's text.
    /// </summary>
    /// <returns>The text, or <see langword="null"/> when the clipboard holds none.</returns>
    public static string? GetText()
    {
        if (!OpenClipboard(0))
        {
            return null;
        }

        try
        {
            var memory = GetClipboardData(UnicodeText);

            if (memory == 0)
            {
                return null;
            }

            var source = (char*)GlobalLock(memory);

            try
            {
                if (source == null)
                {
                    return null;
                }

                // Another application's text may lack its terminating null, so the read stays inside
                // the memory.
                var text = new ReadOnlySpan<char>(source, (int)Math.Min((ulong)GlobalSize(memory) / sizeof(char), int.MaxValue));
                var end = text.IndexOf('\0');
                return new string(end >= 0 ? text[..end] : text);
            }
            finally
            {
                GlobalUnlock(memory);
            }
        }
        finally
        {
            CloseClipboard();
        }
    }

    /// <summary>
    /// Opens the clipboard for this thread.
    /// </summary>
    /// <param name="owner">The window that owns what is put on it.</param>
    /// <returns><see langword="true"/> when it opened.</returns>
    [LibraryImport("user32.dll")]
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
    [LibraryImport("user32.dll")]
    private static partial nint SetClipboardData(uint format, nint memory);

    /// <summary>
    /// Finds the memory of a format on the open clipboard.
    /// </summary>
    /// <param name="format">The clipboard format.</param>
    /// <returns>The memory, still owned by the clipboard, or 0 when the format is missing.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint GetClipboardData(uint format);

    /// <summary>
    /// Allocates memory the clipboard can take over.
    /// </summary>
    /// <param name="flags">How to allocate it.</param>
    /// <param name="size">The size in bytes.</param>
    /// <returns>The memory, or 0 when it failed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalAlloc(uint flags, nuint size);

    /// <summary>
    /// Frees memory the clipboard did not take over.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>0 when it was freed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalFree(nint memory);

    /// <summary>
    /// Reads the size of memory.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>Its size in bytes, 0 when it failed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nuint GlobalSize(nint memory);

    /// <summary>
    /// Makes memory addressable.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>Its address, or <see langword="null"/> when it failed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial void* GlobalLock(nint memory);

    /// <summary>
    /// Ends what <see cref="GlobalLock"/> started.
    /// </summary>
    /// <param name="memory">The memory.</param>
    /// <returns>Whether other locks remain.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GlobalUnlock(nint memory);
}
