//----------------------------------------------------------------
//  FrameCipher.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// Encrypts the frames one game sends to the other and checks the frames it receives, with a key
/// only the holders of the join code know.
/// </summary>
/// <remarks>
/// AES-GCM authenticates every frame, and each carries a counter per direction, so a frame made
/// without the join code, changed on the way, repeated, left out or sent back to its sender never
/// reaches the game. Whatever carries the frames, such as a relay, sees nothing but their sizes.
/// </remarks>
internal sealed class FrameCipher
{
    /// <summary>
    /// Bytes a sealed frame carries on top of its text: the counter and the authentication tag.
    /// </summary>
    public const int Overhead = CounterSize + TagSize;

    /// <summary>
    /// Size of the counter ahead of each sealed frame.
    /// </summary>
    private const int CounterSize = 8;

    /// <summary>
    /// Size of the authentication tag behind each sealed frame.
    /// </summary>
    private const int TagSize = 16;

    /// <summary>
    /// Size of the AES key.
    /// </summary>
    private const int KeySize = 32;

    /// <summary>
    /// Size of an AES-GCM nonce: the direction, three empty bytes and the counter.
    /// </summary>
    private const int NonceSize = 12;

    /// <summary>
    /// The direction byte of frames the host sends.
    /// </summary>
    private const byte FromHost = 1;

    /// <summary>
    /// The direction byte of frames the guest sends.
    /// </summary>
    private const byte FromGuest = 2;

    /// <summary>
    /// Separates the frame key from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] KeyInfo = "mgqmp frame key v1"u8.ToArray();

    /// <summary>
    /// The cipher with the derived key.
    /// </summary>
    private readonly AesGcm _aes;

    /// <summary>
    /// The direction byte of the frames this game sends.
    /// </summary>
    private readonly byte _sendDirection;

    /// <summary>
    /// The direction byte of the frames this game receives.
    /// </summary>
    private readonly byte _receiveDirection;

    /// <summary>
    /// Guards the counters.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The counter of the next frame this game sends.
    /// </summary>
    private ulong _sent;

    /// <summary>
    /// The counter the next frame this game receives must carry.
    /// </summary>
    private ulong _received;

    /// <summary>
    /// Derives the key from a join code's token.
    /// </summary>
    /// <param name="token">The join code's token.</param>
    /// <param name="host">Whether this game hosts, which decides the direction of its frames.</param>
    public FrameCipher(string token, bool host)
    {
        var key = HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), KeySize, info: KeyInfo);

        _aes = new AesGcm(key, TagSize);
        _sendDirection = host ? FromHost : FromGuest;
        _receiveDirection = host ? FromGuest : FromHost;
    }

    /// <summary>
    /// Encrypts a frame to send.
    /// </summary>
    /// <remarks>
    /// Frames must go out in the order they are sealed, since the other side takes them only in
    /// that order.
    /// </remarks>
    /// <param name="plain">The frame's text.</param>
    /// <returns>The counter, the encrypted text and the tag.</returns>
    public byte[] Seal(ReadOnlySpan<byte> plain)
    {
        var sealedFrame = new byte[CounterSize + plain.Length + TagSize];

        lock (_gate)
        {
            var counter = _sent++;

            BinaryPrimitives.WriteUInt64BigEndian(sealedFrame, counter);
            _aes.Encrypt(Nonce(_sendDirection, counter), plain, sealedFrame.AsSpan(CounterSize, plain.Length), sealedFrame.AsSpan(CounterSize + plain.Length));
        }

        return sealedFrame;
    }

    /// <summary>
    /// Checks and decrypts a frame that arrived.
    /// </summary>
    /// <param name="sealedFrame">The frame as <see cref="Seal"/> wrote it on the other side.</param>
    /// <returns>The frame's text, or <see langword="null"/> when the frame fails the check.</returns>
    public byte[]? Open(ReadOnlySpan<byte> sealedFrame)
    {
        if (sealedFrame.Length < Overhead)
        {
            return null;
        }

        var plain = new byte[sealedFrame.Length - Overhead];
        var counter = BinaryPrimitives.ReadUInt64BigEndian(sealedFrame);

        lock (_gate)
        {
            if (counter != _received)
            {
                return null;
            }

            try
            {
                _aes.Decrypt(Nonce(_receiveDirection, counter), sealedFrame.Slice(CounterSize, plain.Length), sealedFrame.Slice(CounterSize + plain.Length), plain);
            }
            catch (AuthenticationTagMismatchException)
            {
                return null;
            }

            _received++;
        }

        return plain;
    }

    /// <summary>
    /// Makes the nonce of a frame, unique per direction and counter.
    /// </summary>
    /// <param name="direction">The direction byte.</param>
    /// <param name="counter">The frame's counter.</param>
    /// <returns>The nonce.</returns>
    private static byte[] Nonce(byte direction, ulong counter)
    {
        var nonce = new byte[NonceSize];

        nonce[0] = direction;
        BinaryPrimitives.WriteUInt64BigEndian(nonce.AsSpan(NonceSize - CounterSize), counter);
        return nonce;
    }
}
