//----------------------------------------------------------------
//  Program.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Printed and checked the formula vectors
//                            - Printed and checked the random reference vectors
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
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
    /// The user's stats of the formula vectors, as the arena tests' formula corpus has them.
    /// </summary>
    private static readonly FormulaStats User = new(5000, 300, 100, 60, 80, 40, 50, 20, 4000, 200, 30);

    /// <summary>
    /// The target's stats of the formula vectors, as the arena tests' formula corpus has them.
    /// </summary>
    private static readonly FormulaStats Target = new(1000, 100, 70, 50, 60, 30, 40, 10, 1000, 100, 10);

    /// <summary>
    /// The formula vectors with their values' round-trip text, as the arena tests hold them.
    /// </summary>
    private static readonly (string Formula, string Value)[] FormulaVectors =
    [
        ("a.atk * 2 * 1.5 - b.def / 2", "275"),
        ("a.mat * 2 * 1.4 - b.mdf / 2", "209"),
        ("(a.mat + 0.1) * 3 / 7.0", "34.32857142857143"),
        ("-7 / 2", "-4"),
        ("-7.5 % 2", "0.5"),
        ("6543.21 % 137", "104.21000000000004"),
        ("1.0 % 0.3", "0.10000000000000003"),
        ("(a.atk / 3.0).round", "33"),
        ("[a.atk / 7.0, b.def * 0.3].max", "15"),
        ("clamp(a.agi * 1.1, 0, 60)", "55.00000000000001"),
        ("a.atk / 0", "0"),
        ("(a.hp * 0.123456789).floor + a.mhp / 9.0", "1048.5555555555557"),
    ];

    /// <summary>
    /// Prints the probe's lines.
    /// </summary>
    /// <returns>The exit code: 0 when every vector matches, 1 otherwise.</returns>
    public static int Main()
    {
        Console.WriteLine($"runtime {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"aot {!RuntimeFeature.IsDynamicCodeSupported}");
        bool matches = PrintRandomVectors() & PrintFormulaVectors();
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

    /// <summary>
    /// Prints the formula vectors with their printed Ruby text and checks their values.
    /// </summary>
    /// <returns>Whether every value matches.</returns>
    private static bool PrintFormulaVectors()
    {
        bool matches = true;
        foreach ((string formula, string expected) in FormulaVectors)
        {
            FormulaParse parse = FormulaParser.Parse(formula);
            string value = parse.IsValid
                ? FormulaEvaluator.Evaluate(parse.Root, User, Target).ToString("R", CultureInfo.InvariantCulture)
                : parse.ErrorCode;
            Console.WriteLine($"formula {formula} = {value} | {(parse.IsValid ? RubyPrinter.Print(parse.Root) : "")}");
            matches &= value == expected;
        }

        return matches;
    }
}
