//----------------------------------------------------------------
//  ScreenshotWalk.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Ui;

/// <summary>
/// Finds the pixels of an RGSS3 Bitmap from its Ruby object, as the bug report's screenshot reads
/// them: the object's data, then the bitmap's, then its pixels.
/// </summary>
/// <remarks>
/// The offsets are RGSS3's struct layout, the same binary under Wine; another engine has other ones.
/// </remarks>
public static class ScreenshotWalk
{
    /// <summary>
    /// Bytes per pixel of a bitmap's pixels: blue, green, red, alpha, the last row first.
    /// </summary>
    public const int PixelBytes = 4;

    /// <summary>
    /// Largest side of a screenshot the report keeps.
    /// </summary>
    public const int MaxSide = 4096;

    /// <summary>
    /// The offsets of the pointers from the Ruby object to the pixels.
    /// </summary>
    private static readonly int[] PointerSteps = [16, 8, 16];

    /// <summary>
    /// The lowest address a pointer on the way is read at; below it, a pointer before was empty.
    /// </summary>
    private const int LowestPointer = 16;

    /// <summary>
    /// Walks from a Bitmap's Ruby object to its pixels.
    /// </summary>
    /// <param name="address">The object's address: Ruby 1.9's object_id times two.</param>
    /// <param name="readPointer">Reads the pointer at an address of the game's process.</param>
    /// <returns>The pixels' address.</returns>
    /// <exception cref="InvalidOperationException">A pointer on the way is empty, or the pixels are not found.</exception>
    public static long PixelsOf(long address, Func<long, long> readPointer)
    {
        ArgumentNullException.ThrowIfNull(readPointer);
        foreach (int step in PointerSteps)
        {
            long at = address + step;
            address = at < LowestPointer ? throw new InvalidOperationException("A pointer on the way to the bitmap's pixels is empty.") : readPointer(at);
        }

        return address == 0 ? throw new InvalidOperationException("The bitmap's pixels were not found.") : address;
    }

    /// <summary>
    /// Tells whether a screen's size is one the report keeps.
    /// </summary>
    /// <param name="width">The width.</param>
    /// <param name="height">The height.</param>
    /// <returns>Whether both sides lie from 1 to <see cref="MaxSide"/>.</returns>
    public static bool IsScreenSize(int width, int height) => width is >= 1 and <= MaxSide && height is >= 1 and <= MaxSide;
}
