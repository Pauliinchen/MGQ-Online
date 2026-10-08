//----------------------------------------------------------------
//  Pbkdf2Sha256.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// PBKDF2 with HMAC-SHA256 (RFC 8018), on a SHA-256 of its own, which gives the same bytes as
/// <see cref="Rfc2898DeriveBytes.Pbkdf2(byte[], byte[], int, HashAlgorithmName, int)"/>.
/// </summary>
/// <remarks>
/// .NET derives PBKDF2 on Windows through a BCrypt pseudo-handle that no Proton release supports,
/// so on a Steam Deck every world lock failed with "Unknown error (0xc1000008)".
/// </remarks>
internal static class Pbkdf2Sha256
{
    /// <summary>
    /// Size of a SHA-256 block, in bytes.
    /// </summary>
    private const int BlockBytes = 64;

    /// <summary>
    /// Size of a SHA-256 digest, in bytes.
    /// </summary>
    private const int DigestBytes = 32;

    /// <summary>
    /// Size of a SHA-256 digest, in 32-bit words.
    /// </summary>
    private const int DigestWords = DigestBytes / sizeof(uint);

    /// <summary>
    /// Size of the SHA-256 message schedule, in 32-bit words.
    /// </summary>
    private const int ScheduleWords = 64;

    /// <summary>
    /// Bits of a message made of one pad block and one digest, as an inner or outer HMAC hashes in each iteration.
    /// </summary>
    private const uint PadAndDigestBits = (BlockBytes + DigestBytes) * 8;

    /// <summary>
    /// The SHA-256 round constants (FIPS 180-4).
    /// </summary>
    private static ReadOnlySpan<uint> RoundConstants =>
    [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    /// <summary>
    /// The SHA-256 starting state (FIPS 180-4).
    /// </summary>
    private static ReadOnlySpan<uint> InitialState =>
    [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];

    /// <summary>
    /// Derives a key from a password.
    /// </summary>
    /// <param name="password">The password's bytes.</param>
    /// <param name="salt">The salt.</param>
    /// <param name="iterations">How often each block hashes, at least 1.</param>
    /// <param name="length">The key's length in bytes, at least 1.</param>
    /// <returns>The key.</returns>
    public static byte[] DeriveKey(ReadOnlySpan<byte> password, ReadOnlySpan<byte> salt, int iterations, int length)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(iterations);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(length);

        Span<uint> inner = stackalloc uint[DigestWords];
        Span<uint> outer = stackalloc uint[DigestWords];
        Span<uint> chained = stackalloc uint[DigestWords];
        Span<uint> sum = stackalloc uint[DigestWords];
        Span<uint> schedule = stackalloc uint[ScheduleWords];
        var key = new byte[length];
        var first = new byte[salt.Length + sizeof(uint)];
        salt.CopyTo(first);

        try
        {
            PadStates(password, inner, outer, schedule);

            for (var block = 1; (block - 1) * DigestBytes < length; block++)
            {
                BinaryPrimitives.WriteInt32BigEndian(first.AsSpan(salt.Length), block);
                Hmac(inner, outer, first, chained, schedule);
                chained.CopyTo(sum);

                for (var iteration = 1; iteration < iterations; iteration++)
                {
                    HmacOfDigest(inner, outer, chained, schedule);

                    for (var word = 0; word < DigestWords; word++)
                    {
                        sum[word] ^= chained[word];
                    }
                }

                var offset = (block - 1) * DigestBytes;
                WriteDigest(sum, key.AsSpan(offset, Math.Min(DigestBytes, length - offset)));
            }

            return key;
        }
        finally
        {
            inner.Clear();
            outer.Clear();
            chained.Clear();
            sum.Clear();
            schedule.Clear();
        }
    }

    /// <summary>
    /// Hashes the HMAC key's inner and outer pad blocks, which every HMAC under that key starts with.
    /// </summary>
    /// <param name="key">The HMAC key.</param>
    /// <param name="inner">Receives the state after the inner pad block.</param>
    /// <param name="outer">Receives the state after the outer pad block.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void PadStates(ReadOnlySpan<byte> key, Span<uint> inner, Span<uint> outer, Span<uint> schedule)
    {
        Span<byte> padded = stackalloc byte[BlockBytes];
        padded.Clear();

        if (key.Length > BlockBytes)
        {
            Span<uint> digest = stackalloc uint[DigestWords];
            InitialState.CopyTo(digest);
            HashRest(digest, key, 0, schedule);
            WriteDigest(digest, padded[..DigestBytes]);
        }
        else
        {
            key.CopyTo(padded);
        }

        PadState(padded, 0x36, inner, schedule);
        PadState(padded, 0x5c, outer, schedule);
        padded.Clear();
    }

    /// <summary>
    /// Hashes one pad block: the padded key with each byte xor'ed with the pad.
    /// </summary>
    /// <param name="padded">The key, padded with zeros to a block.</param>
    /// <param name="pad">The pad byte.</param>
    /// <param name="state">Receives the state after the block.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void PadState(ReadOnlySpan<byte> padded, byte pad, Span<uint> state, Span<uint> schedule)
    {
        for (var word = 0; word < BlockBytes / sizeof(uint); word++)
        {
            schedule[word] = BinaryPrimitives.ReadUInt32BigEndian(padded[(word * sizeof(uint))..]) ^ (pad * 0x01010101u);
        }

        InitialState.CopyTo(state);
        Compress(state, schedule);
    }

    /// <summary>
    /// Makes an HMAC of a message of any length.
    /// </summary>
    /// <param name="inner">The state after the inner pad block.</param>
    /// <param name="outer">The state after the outer pad block.</param>
    /// <param name="message">The message.</param>
    /// <param name="mac">Receives the HMAC, as words.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void Hmac(ReadOnlySpan<uint> inner, ReadOnlySpan<uint> outer, ReadOnlySpan<byte> message, Span<uint> mac, Span<uint> schedule)
    {
        inner.CopyTo(mac);
        HashRest(mac, message, BlockBytes, schedule);
        FinishWithOuter(outer, mac, schedule);
    }

    /// <summary>
    /// Makes the HMAC of a digest in place, the step PBKDF2 repeats for every iteration.
    /// </summary>
    /// <param name="inner">The state after the inner pad block.</param>
    /// <param name="outer">The state after the outer pad block.</param>
    /// <param name="digest">The digest, which receives its HMAC.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void HmacOfDigest(ReadOnlySpan<uint> inner, ReadOnlySpan<uint> outer, Span<uint> digest, Span<uint> schedule)
    {
        LoadDigestBlock(digest, schedule);
        inner.CopyTo(digest);
        Compress(digest, schedule);
        FinishWithOuter(outer, digest, schedule);
    }

    /// <summary>
    /// Hashes an inner digest under the outer pad, which completes an HMAC.
    /// </summary>
    /// <param name="outer">The state after the outer pad block.</param>
    /// <param name="digest">The inner digest, which receives the HMAC.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void FinishWithOuter(ReadOnlySpan<uint> outer, Span<uint> digest, Span<uint> schedule)
    {
        LoadDigestBlock(digest, schedule);
        outer.CopyTo(digest);
        Compress(digest, schedule);
    }

    /// <summary>
    /// Fills the schedule with the last block of a message made of one pad block and a digest.
    /// </summary>
    /// <param name="digest">The digest.</param>
    /// <param name="schedule">The message schedule.</param>
    private static void LoadDigestBlock(ReadOnlySpan<uint> digest, Span<uint> schedule)
    {
        digest.CopyTo(schedule);
        schedule[DigestWords] = 0x80000000;
        schedule[(DigestWords + 1)..15].Clear();
        schedule[15] = PadAndDigestBits;
    }

    /// <summary>
    /// Hashes the rest of a message, with its padding, onto a state.
    /// </summary>
    /// <param name="state">The state after the blocks before, which receives the digest.</param>
    /// <param name="rest">The rest of the message.</param>
    /// <param name="before">How many bytes the blocks before held.</param>
    /// <param name="schedule">A message schedule to work in.</param>
    private static void HashRest(Span<uint> state, ReadOnlySpan<byte> rest, int before, Span<uint> schedule)
    {
        var paddedLength = (rest.Length + 1 + sizeof(ulong) + BlockBytes - 1) / BlockBytes * BlockBytes;
        var padded = new byte[paddedLength];
        rest.CopyTo(padded);
        padded[rest.Length] = 0x80;
        BinaryPrimitives.WriteUInt64BigEndian(padded.AsSpan(paddedLength - sizeof(ulong)), (ulong)(before + rest.Length) * 8);

        for (var offset = 0; offset < paddedLength; offset += BlockBytes)
        {
            for (var word = 0; word < BlockBytes / sizeof(uint); word++)
            {
                schedule[word] = BinaryPrimitives.ReadUInt32BigEndian(padded.AsSpan(offset + word * sizeof(uint)));
            }

            Compress(state, schedule);
        }

        CryptographicOperations.ZeroMemory(padded);
    }

    /// <summary>
    /// Writes a digest's words as big-endian bytes, as many as fit.
    /// </summary>
    /// <param name="digest">The digest.</param>
    /// <param name="bytes">Receives the bytes, at most a digest's worth.</param>
    private static void WriteDigest(ReadOnlySpan<uint> digest, Span<byte> bytes)
    {
        Span<byte> whole = stackalloc byte[DigestBytes];

        for (var word = 0; word < DigestWords; word++)
        {
            BinaryPrimitives.WriteUInt32BigEndian(whole[(word * sizeof(uint))..], digest[word]);
        }

        whole[..bytes.Length].CopyTo(bytes);
        whole.Clear();
    }

    /// <summary>
    /// Runs the SHA-256 compression on one block (FIPS 180-4).
    /// </summary>
    /// <param name="state">The state, which receives the next one.</param>
    /// <param name="schedule">The message schedule, whose first 16 words hold the block; the rest is overwritten.</param>
    [MethodImpl(MethodImplOptions.AggressiveOptimization)]
    private static void Compress(Span<uint> state, Span<uint> schedule)
    {
        for (var t = 16; t < ScheduleWords; t++)
        {
            var early = schedule[t - 15];
            var late = schedule[t - 2];
            var sigma0 = BitOperations.RotateRight(early, 7) ^ BitOperations.RotateRight(early, 18) ^ (early >> 3);
            var sigma1 = BitOperations.RotateRight(late, 17) ^ BitOperations.RotateRight(late, 19) ^ (late >> 10);
            schedule[t] = schedule[t - 16] + sigma0 + schedule[t - 7] + sigma1;
        }

        var a = state[0];
        var b = state[1];
        var c = state[2];
        var d = state[3];
        var e = state[4];
        var f = state[5];
        var g = state[6];
        var h = state[7];
        var constants = RoundConstants;

        for (var t = 0; t < ScheduleWords; t++)
        {
            var sum1 = BitOperations.RotateRight(e, 6) ^ BitOperations.RotateRight(e, 11) ^ BitOperations.RotateRight(e, 25);
            var choice = (e & f) ^ (~e & g);
            var temp1 = h + sum1 + choice + constants[t] + schedule[t];
            var sum0 = BitOperations.RotateRight(a, 2) ^ BitOperations.RotateRight(a, 13) ^ BitOperations.RotateRight(a, 22);
            var majority = (a & b) ^ (a & c) ^ (b & c);
            h = g;
            g = f;
            f = e;
            e = d + temp1;
            d = c;
            c = b;
            b = a;
            a = temp1 + sum0 + majority;
        }

        state[0] += a;
        state[1] += b;
        state[2] += c;
        state[3] += d;
        state[4] += e;
        state[5] += f;
        state[6] += g;
        state[7] += h;
    }
}
