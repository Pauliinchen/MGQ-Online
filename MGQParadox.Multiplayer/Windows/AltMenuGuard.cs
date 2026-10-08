//----------------------------------------------------------------
//  AltMenuGuard.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// Decides when Alt may not open the game window's menu: while a text screen wants the keyboard,
/// and for an Alt press that began while one did.
/// </summary>
/// <remarks>
/// The menu opens as Alt is released, and the game waits in it, so a chat that closes while Alt is
/// still held would otherwise stop the game.
/// </remarks>
internal sealed class AltMenuGuard
{
    /// <summary>
    /// VK_MENU, the virtual key of either Alt.
    /// </summary>
    private const uint AltKey = 0x12;

    /// <summary>
    /// The bit of a key message's second value that is set when the key was already down, as for a repeat.
    /// </summary>
    private const long WasDownBit = 1L << 30;

    /// <summary>
    /// Whether the Alt press held now, or the last one, began while a text screen wanted the keyboard.
    /// </summary>
    private bool _pressedWhileTyping;

    /// <summary>
    /// Notes a key going down while Alt is held.
    /// </summary>
    /// <param name="typing">Whether a text screen wants the keyboard.</param>
    /// <param name="key">The virtual key.</param>
    /// <param name="lParam">The key message's second value.</param>
    public void SystemKeyDown(bool typing, uint key, nint lParam)
    {
        // Repeats of a held Alt keep what its first press noted.
        if (key == AltKey && (lParam & WasDownBit) == 0)
        {
            _pressedWhileTyping = typing;
        }
    }

    /// <summary>
    /// Tells whether the window's menu that Alt asks for must stay closed, and forgets the Alt press it answered.
    /// </summary>
    /// <param name="typing">Whether a text screen wants the keyboard.</param>
    /// <returns><see langword="true"/> while typing, or for an Alt press that began while typing.</returns>
    public bool SwallowsKeyMenu(bool typing)
    {
        var swallowed = typing || _pressedWhileTyping;
        _pressedWhileTyping = false;
        return swallowed;
    }
}
