//----------------------------------------------------------------
//  WorldCipher.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// Encrypts the frames one game sends into its world room and checks the frames of the others, with
/// keys only the holders of the world code know.
/// </summary>
/// <remarks>
/// Every game encrypts with a key of its own, from the world's token and a salt it picks for the
/// connection, and sends the salt along; many games share a world, and one key per sender keeps
/// their counters, which make the nonces, from ever meeting. The sender's seat is authenticated too,
/// so a frame passed on under another seat fails its check.
/// </remarks>
internal sealed class WorldCipher
{
    /// <summary>
    /// Bytes a sealed frame carries on top of its text: the salt, the counter and the tag.
    /// </summary>
    public const int Overhead = SaltSize + CounterSize + TagSize;

    /// <summary>
    /// Size of the salt that makes each sender's key its own.
    /// </summary>
    private const int SaltSize = 16;

    /// <summary>
    /// Size of the counter behind the salt.
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
    /// Size of an AES-GCM nonce: four empty bytes and the counter.
    /// </summary>
    private const int NonceSize = 12;

    /// <summary>
    /// Separates the world keys from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] KeyInfo = "mgqmp world key v1"u8.ToArray();

    /// <summary>
    /// The world's token, which every key comes from.
    /// </summary>
    private readonly byte[] _token;

    /// <summary>
    /// This game's salt, sent ahead of each of its frames.
    /// </summary>
    private readonly byte[] _salt;

    /// <summary>
    /// The cipher with this game's key.
    /// </summary>
    private readonly AesGcm _own;

    /// <summary>
    /// The other games' keys by seat, with the counter each one's next frame must reach.
    /// </summary>
    private readonly Dictionary<int, Sender> _senders = new();

    /// <summary>
    /// Salts of senders that left their seat, whose frames are refused from then on.
    /// </summary>
    private readonly HashSet<string> _retired = new(StringComparer.Ordinal);

    /// <summary>
    /// Guards the counters and the senders.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The counter of the next frame this game sends.
    /// </summary>
    private ulong _sent;

    /// <summary>
    /// Picks a salt and derives this game's key from the world's token.
    /// </summary>
    /// <param name="token">The world's token.</param>
    public WorldCipher(string token)
    {
        _token = Encoding.UTF8.GetBytes(token);
        _salt = RandomNumberGenerator.GetBytes(SaltSize);
        _own = new AesGcm(Key(_salt), TagSize);
    }

    /// <summary>
    /// Encrypts a frame to send.
    /// </summary>
    /// <param name="seat">This game's seat, which the receivers check the frame against.</param>
    /// <param name="plain">The frame's text.</param>
    /// <returns>The salt, the counter, the encrypted text and the tag.</returns>
    public byte[] Seal(int seat, ReadOnlySpan<byte> plain)
    {
        var sealedFrame = new byte[Overhead + plain.Length];
        _salt.CopyTo(sealedFrame, 0);

        lock (_gate)
        {
            var counter = _sent++;

            BinaryPrimitives.WriteUInt64BigEndian(sealedFrame.AsSpan(SaltSize), counter);
            _own.Encrypt(Nonce(counter), plain, sealedFrame.AsSpan(SaltSize + CounterSize, plain.Length), sealedFrame.AsSpan(SaltSize + CounterSize + plain.Length), SeatData(seat));
        }

        return sealedFrame;
    }

    /// <summary>
    /// Checks and decrypts a frame another game sent.
    /// </summary>
    /// <remarks>
    /// A sender's counters only have to grow, not follow each other, since frames it sent to other
    /// seats alone never arrive here.
    /// </remarks>
    /// <param name="seat">The sender's seat, as the relay named it.</param>
    /// <param name="sealedFrame">The frame as <see cref="Seal"/> wrote it on the other side.</param>
    /// <returns>The frame's text, or <see langword="null"/> when the frame fails the check.</returns>
    public byte[]? Open(int seat, ReadOnlySpan<byte> sealedFrame)
    {
        if (sealedFrame.Length < Overhead)
        {
            return null;
        }

        var salt = sealedFrame[..SaltSize];
        var counter = BinaryPrimitives.ReadUInt64BigEndian(sealedFrame.Slice(SaltSize, CounterSize));
        var textLength = sealedFrame.Length - Overhead;
        var plain = new byte[textLength];

        lock (_gate)
        {
            var saltText = Convert.ToHexString(salt);

            if (_retired.Contains(saltText))
            {
                return null;
            }

            _senders.TryGetValue(seat, out var known);
            var sender = known?.Salt == saltText ? known : new Sender(saltText, new AesGcm(Key(salt), TagSize));

            if (counter < sender.Next)
            {
                return null;
            }

            try
            {
                sender.Aes.Decrypt(Nonce(counter), sealedFrame.Slice(SaltSize + CounterSize, textLength), sealedFrame[^TagSize..], plain, SeatData(seat));
            }
            catch (AuthenticationTagMismatchException)
            {
                return null;
            }

            sender.Next = counter + 1;
            _senders[seat] = sender;

            // The seat's earlier game is gone, since a game keeps its salt for as long as it is connected.
            if (known != null && known != sender)
            {
                _retired.Add(known.Salt);
            }
        }

        return plain;
    }

    /// <summary>
    /// Forgets the game that left a seat and refuses its frames from then on, since the seat may go to another game.
    /// </summary>
    /// <param name="seat">The seat.</param>
    public void Forget(int seat)
    {
        lock (_gate)
        {
            if (_senders.Remove(seat, out var sender))
            {
                _retired.Add(sender.Salt);
            }
        }
    }

    /// <summary>
    /// Derives a sender's key.
    /// </summary>
    /// <param name="salt">The sender's salt.</param>
    /// <returns>The key.</returns>
    private byte[] Key(ReadOnlySpan<byte> salt)
    {
        var key = new byte[KeySize];
        HKDF.DeriveKey(HashAlgorithmName.SHA256, _token, key, salt, KeyInfo);
        return key;
    }

    /// <summary>
    /// Makes the nonce of a frame, unique per key and counter.
    /// </summary>
    /// <param name="counter">The frame's counter.</param>
    /// <returns>The nonce.</returns>
    private static byte[] Nonce(ulong counter)
    {
        var nonce = new byte[NonceSize];
        BinaryPrimitives.WriteUInt64BigEndian(nonce.AsSpan(NonceSize - CounterSize), counter);
        return nonce;
    }

    /// <summary>
    /// Makes the authenticated data of a frame: its sender's seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The data.</returns>
    private static byte[] SeatData(int seat) => [(byte)seat];

    /// <summary>
    /// Another game's key, and the counter its next frame must reach.
    /// </summary>
    /// <param name="salt">The sender's salt, as hexadecimal.</param>
    /// <param name="aes">The cipher with the sender's key.</param>
    private sealed class Sender(string salt, AesGcm aes)
    {
        /// <summary>
        /// The sender's salt, as hexadecimal.
        /// </summary>
        public string Salt { get; } = salt;

        /// <summary>
        /// The cipher with the sender's key.
        /// </summary>
        public AesGcm Aes { get; } = aes;

        /// <summary>
        /// The counter the sender's next frame must reach.
        /// </summary>
        public ulong Next { get; set; }
    }
}
