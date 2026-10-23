//----------------------------------------------------------------
//  FontGlyphs.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Ui.Text;

/// <summary>
/// The width of each character in one font, as the scripts measured it with RGSS's
/// <c>Bitmap#text_size</c>, so a text's width is the sum of its characters' widths.
/// </summary>
/// <remarks>
/// The sum holds for the game's font, VL Gothic, on every size the mod draws in (no kerning, whole
/// pixel advances); the scripts check it once per font and measure a font that fails it themselves.
/// </remarks>
public sealed class FontGlyphs
{
    /// <summary>
    /// The widths by code point.
    /// </summary>
    private readonly Dictionary<int, int> _widths = [];

    /// <summary>
    /// The characters asked for that were never measured, until the scripts measured them.
    /// </summary>
    private readonly SortedSet<int> _missing = [];

    /// <summary>
    /// Creates the table of a font.
    /// </summary>
    /// <param name="name">The font's name, for the log.</param>
    /// <param name="size">Its size, which a character not measured yet counts as.</param>
    /// <param name="bold">Whether it is bold.</param>
    /// <param name="cells">Whether every character is one cell wide, as in a box that counts characters.</param>
    public FontGlyphs(string name, int size, bool bold, bool cells = false)
    {
        Name = name;
        Size = size;
        Bold = bold;
        Cells = cells;
    }

    /// <summary>
    /// Gets the font's name.
    /// </summary>
    public string Name { get; }

    /// <summary>
    /// Gets the font's size.
    /// </summary>
    public int Size { get; }

    /// <summary>
    /// Gets whether the font is bold.
    /// </summary>
    public bool Bold { get; }

    /// <summary>
    /// Gets whether every character is one cell wide.
    /// </summary>
    public bool Cells { get; }

    /// <summary>
    /// Gets the characters asked for that were never measured, in code point order.
    /// </summary>
    public IReadOnlyCollection<int> Missing => _missing;

    /// <summary>
    /// Keeps a character's width.
    /// </summary>
    /// <param name="codePoint">The character.</param>
    /// <param name="width">Its width in pixels.</param>
    public void Learn(int codePoint, int width)
    {
        _widths[codePoint] = width;
        _missing.Remove(codePoint);
    }

    /// <summary>
    /// Tells a character's width.
    /// </summary>
    /// <remarks>
    /// A character not measured yet counts as wide as the font's size, wider than the game font's
    /// widest, so a line breaks early rather than running out of its box until it is measured.
    /// </remarks>
    /// <param name="codePoint">The character.</param>
    /// <returns>Its width in pixels, 1 in a font of cells.</returns>
    public int Width(int codePoint)
    {
        if (Cells)
        {
            return 1;
        }

        if (_widths.TryGetValue(codePoint, out int width))
        {
            return width;
        }

        _missing.Add(codePoint);
        return Size;
    }

    /// <summary>
    /// Forgets which characters were asked for and never measured, once the scripts were told.
    /// </summary>
    public void ClearMissing() => _missing.Clear();
}
