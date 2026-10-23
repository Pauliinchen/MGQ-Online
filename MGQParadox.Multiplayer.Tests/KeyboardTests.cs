//----------------------------------------------------------------
//  KeyboardTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Checked a take handed out once and forgotten when typing stops
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers how the keyboard hands out what was typed.
/// </summary>
public sealed class KeyboardTests
{
    /// <summary>
    /// Asserts that what was typed comes out with the next take, and only once.
    /// </summary>
    [Fact]
    public void Take_HandsWhatWasTypedOutOnce()
    {
        Keyboard.SetActive(true);
        Keyboard.TakeCharacter('a');
        Keyboard.TakeCharacter('b');
        var first = Keyboard.Take();
        var second = Keyboard.Take();
        Keyboard.SetActive(false);

        Assert.Equal(("ab", 0), first);
        Assert.Equal((string.Empty, 0), second);
    }

    /// <summary>
    /// Asserts that stopping the typing forgets what nobody took.
    /// </summary>
    [Fact]
    public void SetActive_ForgetsWhatWasNotTaken()
    {
        Keyboard.SetActive(true);
        Keyboard.TakeCharacter('c');
        Keyboard.SetActive(false);

        Assert.Equal((string.Empty, 0), Keyboard.Take());
    }
}
