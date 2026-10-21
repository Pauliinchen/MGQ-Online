//----------------------------------------------------------------
//  Program.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Printed and checked the random reference vectors
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Tools.AotProbe;

/// <summary>
/// Prints what the NativeAOT build of the arena and update libraries computes, so two platforms can
/// be compared line by line.
/// </summary>
public static class Program
{
    /// <summary>
    /// The seed of the random reference vectors.
    /// </summary>
    private const ulong RandomSeed = 42;

    /// <summary>
    /// The SHA-256 of the first 1,000 values for <see cref="RandomSeed"/>, as the arena tests hold them.
    /// </summary>
    private const string RandomSha256 = "032f663664576503216350dd34efdd21c02e1ed6769b03f81bda92c6dd662ec4";

    /// <summary>
    /// Prints the probe's lines.
    /// </summary>
    /// <returns>The exit code: 0 when every vector matches, 1 otherwise.</returns>
    public static int Main()
    {
        Console.WriteLine($"runtime {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"aot {!RuntimeFeature.IsDynamicCodeSupported}");
        bool matches = PrintRandomVectors();
        Console.WriteLine(matches ? "vectors ok" : "vectors DIFFER");
        return matches ? 0 : 1;
    }

    /// <summary>
    /// Prints the random generator's reference vectors and checks them against the arena tests' goldens.
    /// </summary>
    /// <returns>Whether the 1,000 values match the goldens.</returns>
    private static bool PrintRandomVectors()
    {
        ArenaRandom random = new(RandomSeed);
        byte[] bytes = new byte[1000 * sizeof(uint)];
        for (int i = 0; i < 1000; i++)
        {
            uint value = random.NextUInt();
            BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(i * sizeof(uint)), value);
            if (i < 8)
            {
                Console.WriteLine($"random {RandomSeed} #{i} {value}");
            }
        }

        string sha = Convert.ToHexStringLower(SHA256.HashData(bytes));
        Console.WriteLine($"random {RandomSeed} first 1000 sha256 {sha}");
        RandomStreams streams = new(RandomSeed);
        foreach (RandomStream stream in Enum.GetValues<RandomStream>())
        {
            Console.WriteLine($"stream {stream} seed {RandomStreams.SeedOf(RandomSeed, stream)} first {streams.Get(stream).NextUInt()}");
        }

        return sha == RandomSha256;
    }
}
