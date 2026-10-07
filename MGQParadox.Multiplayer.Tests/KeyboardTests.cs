//----------------------------------------------------------------
//  KeyboardTests.cs
//
//  Changelog:
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
    /// Asserts that a take given back comes out first with the next take, and only once.
    /// </summary>
    [Fact]
    public void GiveBack_HandsTheTakeOutAgainOnce()
    {
        Keyboard.SetActive(true);
        Keyboard.TakeCharacter('c');
        var first = Keyboard.Take();

        Keyboard.GiveBack("ab", 2);
        Keyboard.TakeCharacter('d');
        var second = Keyboard.Take();
        var third = Keyboard.Take();
        Keyboard.SetActive(false);

        Assert.Equal(("c", 0), first);
        Assert.Equal(("abd", 2), second);
        Assert.Equal((string.Empty, 0), third);
    }

    /// <summary>
    /// Asserts that stopping the typing forgets a take given back.
    /// </summary>
    [Fact]
    public void SetActive_ForgetsATakeGivenBack()
    {
        Keyboard.SetActive(true);
        Keyboard.GiveBack("ab", 2);
        Keyboard.SetActive(false);

        Assert.Equal((string.Empty, 0), Keyboard.Take());
    }
}
