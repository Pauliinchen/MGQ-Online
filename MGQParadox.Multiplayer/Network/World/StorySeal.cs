//----------------------------------------------------------------
//  StorySeal.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A Raid World's story as the relay keeps it: encrypted with a key from the world's token, so the
/// relay cannot read it and any game in the world can.
/// </summary>
internal static class StorySeal
{
    /// <summary>
    /// Most bytes the story may have, in UTF-8; sealed in base64 it stays within what the relay takes.
    /// </summary>
    public const int MaxStoryBytes = 200 * 1024;

    /// <summary>
    /// Separates the story's key from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] KeyInfo = "mgqmp world story v1"u8.ToArray();

    /// <summary>
    /// Encrypts a world's story.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="story">The story, as the game script packed it.</param>
    /// <returns>The nonce, the encrypted story and the tag, in base64.</returns>
    public static string Seal(string token, string story) =>
        Convert.ToBase64String(SealedBox.Seal(KeyOf(token), Encoding.UTF8.GetBytes(story)));

    /// <summary>
    /// Decrypts a world's story.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="sealedStory">The story as <see cref="Seal"/> made it.</param>
    /// <returns>The story.</returns>
    /// <exception cref="InvalidDataException">The text is damaged, or belongs to another world.</exception>
    public static string Open(string token, string sealedStory)
    {
        byte[] box;

        try
        {
            box = Convert.FromBase64String(sealedStory);
        }
        catch (FormatException)
        {
            throw new InvalidDataException("The world's story is no base64.");
        }

        var plain = SealedBox.Open(KeyOf(token), box)
            ?? throw new InvalidDataException("The world's story is damaged, or belongs to another world.");

        return Encoding.UTF8.GetString(plain);
    }

    /// <summary>
    /// Makes the story's key from the world's token.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>The key.</returns>
    private static byte[] KeyOf(string token) => SealedBox.KeyOf(token, KeyInfo);
}
