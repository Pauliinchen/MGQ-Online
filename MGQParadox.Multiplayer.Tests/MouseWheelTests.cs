//----------------------------------------------------------------
//  MouseWheelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the mouse wheel's notches the game script takes.
/// </summary>
public sealed class MouseWheelTests
{
    /// <summary>
    /// Asserts that the notches turned either way add up and a take hands them out once.
    /// </summary>
    [Fact]
    public void Take_HandsOutTheNotchesOnce()
    {
        var wheel = new MouseWheel();

        wheel.Turn(MouseWheel.Notch);
        wheel.Turn(MouseWheel.Notch);
        wheel.Turn(-MouseWheel.Notch);

        Assert.Equal(1, wheel.Take());
        Assert.Equal(0, wheel.Take());
    }

    /// <summary>
    /// Asserts that a turn towards the player counts negative.
    /// </summary>
    [Fact]
    public void Take_TowardsThePlayer_IsNegative()
    {
        var wheel = new MouseWheel();

        wheel.Turn(-3 * MouseWheel.Notch);

        Assert.Equal(-3, wheel.Take());
    }

    /// <summary>
    /// Asserts that parts of a notch, as a wheel without notches turns, wait until they make a
    /// whole one, either way.
    /// </summary>
    [Fact]
    public void Take_KeepsThePartsOfANotch()
    {
        var wheel = new MouseWheel();

        wheel.Turn(MouseWheel.Notch / 2);
        Assert.Equal(0, wheel.Take());

        wheel.Turn(MouseWheel.Notch / 2 + 10);
        Assert.Equal(1, wheel.Take());

        wheel.Turn(-MouseWheel.Notch - 10);
        Assert.Equal(-1, wheel.Take());
        Assert.Equal(0, wheel.Take());
    }
}
