//----------------------------------------------------------------
//  UiButtons.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Ui;

/// <summary>
/// The game's buttons a model reads, in the order of their bits.
/// </summary>
public enum UiButton
{
    /// <summary>The game's confirm button, C.</summary>
    Confirm = 0,

    /// <summary>The game's cancel button, B.</summary>
    Cancel = 1,

    /// <summary>Up.</summary>
    Up = 2,

    /// <summary>Down.</summary>
    Down = 3,

    /// <summary>Left.</summary>
    Left = 4,

    /// <summary>Right.</summary>
    Right = 5,
}

/// <summary>
/// The game's buttons of a frame as the scripts read them past the capture (MGQ_MpUi::Tick.buttons):
/// a bit per button that went down, then one per button that went down or repeats, then one per
/// button held.
/// </summary>
/// <param name="Bits">The bits.</param>
public readonly record struct UiButtons(int Bits)
{
    /// <summary>
    /// The buttons in each group of bits.
    /// </summary>
    public const int Count = 6;

    /// <summary>
    /// Tells whether a button went down.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it did.</returns>
    public bool Triggered(UiButton button) => Bit((int)button);

    /// <summary>
    /// Tells whether a button went down or repeats while held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it does.</returns>
    public bool Repeated(UiButton button) => Bit(Count + (int)button);

    /// <summary>
    /// Tells whether a button is held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it is.</returns>
    public bool Pressed(UiButton button) => Bit(2 * Count + (int)button);

    /// <summary>
    /// Reads one bit.
    /// </summary>
    /// <param name="place">The bit's place.</param>
    /// <returns>Whether it is set.</returns>
    private bool Bit(int place) => (Bits & (1 << place)) != 0;
}
