//----------------------------------------------------------------
//  AltMenuGuardTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Checked that Alt pressed alone never opens the menu, and Alt with a letter does without typing
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers when Alt may open the game window's menu.
/// </summary>
public sealed class AltMenuGuardTests
{
    /// <summary>
    /// VK_MENU, the virtual key of Alt.
    /// </summary>
    private const uint Alt = 0x12;

    /// <summary>
    /// A key message's second value for a key that was already down.
    /// </summary>
    private const nint Repeat = 1 << 30;

    /// <summary>
    /// The character the window's menu gets for Alt pressed alone.
    /// </summary>
    private const nint AltAlone = 0;

    /// <summary>
    /// The character the window's menu gets for Alt with F.
    /// </summary>
    private const nint AltWithLetter = 'f';

    /// <summary>
    /// Asserts that Alt pressed alone keeps the menu closed, typing or not.
    /// </summary>
    [Fact]
    public void AltAlone_KeepsTheMenuClosed()
    {
        var guard = new AltMenuGuard();

        Assert.True(guard.SwallowsKeyMenu(false, AltAlone));
        Assert.True(guard.SwallowsKeyMenu(true, AltAlone));
    }

    /// <summary>
    /// Asserts that Alt with a letter keeps the menu closed while typing, and opens it otherwise.
    /// </summary>
    [Fact]
    public void Typing_KeepsTheMenuClosed()
    {
        var guard = new AltMenuGuard();

        Assert.True(guard.SwallowsKeyMenu(true, AltWithLetter));
        Assert.False(guard.SwallowsKeyMenu(false, AltWithLetter));
    }

    /// <summary>
    /// Asserts that an Alt press that began while typing keeps the menu closed as it is released
    /// after the typing ended, even through its repeats, and only that once.
    /// </summary>
    [Fact]
    public void AltPressedWhileTyping_KeepsTheMenuClosedAfterTheTypingEnded()
    {
        var guard = new AltMenuGuard();

        guard.SystemKeyDown(true, Alt, 0);
        guard.SystemKeyDown(false, Alt, Repeat);

        Assert.True(guard.SwallowsKeyMenu(false, AltWithLetter));
        Assert.False(guard.SwallowsKeyMenu(false, AltWithLetter));
    }

    /// <summary>
    /// Asserts that an Alt press with a letter that began without typing opens the menu.
    /// </summary>
    [Fact]
    public void AltPressedWithoutTyping_OpensTheMenu()
    {
        var guard = new AltMenuGuard();

        guard.SystemKeyDown(true, Alt, 0);
        guard.SystemKeyDown(false, Alt, 0);

        Assert.False(guard.SwallowsKeyMenu(false, AltWithLetter));
    }
}
