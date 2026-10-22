//----------------------------------------------------------------
//  CanonicalGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Took the fight changes in the goldens
//                            - Took the debris types in the design golden
//      Paulinchen  2026-10-22: Took the hazards in the goldens
//                            - Took the cycle in the design golden
//                            - Took the rest skip switch and event in the goldens
//                            - Took the start rest event and the opener in the goldens
//                            - Took the normal attacks per turn in the design golden
//                            - Took the seat of a rule fire in the events golden
//                            - Took the main target in the goldens
//      Paulinchen  2026-10-21: Took the hash of the design golden with formula trees
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Json;

/// <summary>
/// Tests the canonical bytes of the sample design and battle log against committed goldens, so any change
/// of the runtime JSON contract shows as a golden change.
/// </summary>
public sealed class CanonicalGoldenTests
{
    /// <summary>
    /// The SHA-256 of the design golden.
    /// </summary>
    private const string DesignSha256 = "2505b5a2c27a28b0a9236e68d2a3e095fa34e659b5c888f4b31312c0efce422a";

    /// <summary>
    /// The SHA-256 of the battle log golden.
    /// </summary>
    private const string EventsSha256 = "5ce1a091d935ede91cc7145cb163bbf61726c21a31bf2f3249c736b97e692a2f";

    /// <summary>
    /// The sample design writes the golden's bytes.
    /// </summary>
    [Fact]
    public void DesignMatchesItsGolden() =>
        AssertGolden("runtimeDesign.json", CanonicalJson.Serialize(Samples.Design, ArenaJsonContext.Default.RuntimeDesign), DesignSha256);

    /// <summary>
    /// The sample battle log writes the golden's bytes.
    /// </summary>
    [Fact]
    public void EventsMatchTheirGolden() =>
        AssertGolden("battleEvents.json", CanonicalJson.Serialize(Samples.Events, ArenaJsonContext.Default.IReadOnlyListBattleEvent), EventsSha256);

    /// <summary>
    /// The design golden read and written again gives its own bytes.
    /// </summary>
    [Fact]
    public void DesignGoldenIsAFixedPoint()
    {
        byte[] golden = File.ReadAllBytes(GoldenPath("runtimeDesign.json"));

        RuntimeDesign design = JsonSerializer.Deserialize(golden, ArenaJsonContext.Default.RuntimeDesign)!;

        Assert.Equal(golden, CanonicalJson.Serialize(design, ArenaJsonContext.Default.RuntimeDesign));
    }

    /// <summary>
    /// The battle log golden read and written again gives its own bytes.
    /// </summary>
    [Fact]
    public void EventsGoldenIsAFixedPoint()
    {
        byte[] golden = File.ReadAllBytes(GoldenPath("battleEvents.json"));

        IReadOnlyList<BattleEvent> events = JsonSerializer.Deserialize(golden, ArenaJsonContext.Default.IReadOnlyListBattleEvent)!;

        Assert.Equal(golden, CanonicalJson.Serialize(events, ArenaJsonContext.Default.IReadOnlyListBattleEvent));
    }

    /// <summary>
    /// Compares bytes with a golden file and its hash; on a difference the bytes are saved beside the test output.
    /// </summary>
    /// <param name="name">The golden's file name.</param>
    /// <param name="actual">The bytes written.</param>
    /// <param name="sha256">The golden's recorded hash.</param>
    private static void AssertGolden(string name, byte[] actual, string sha256)
    {
        string path = GoldenPath(name);
        byte[] golden = File.Exists(path) ? File.ReadAllBytes(path) : [];
        if (!golden.AsSpan().SequenceEqual(actual) || ContentHash.Sha256Hex(actual) != sha256)
        {
            string saved = Path.Combine(AppContext.BaseDirectory, "canonical-actual", name);
            Directory.CreateDirectory(Path.GetDirectoryName(saved)!);
            File.WriteAllBytes(saved, actual);
            Assert.Fail($"{name} differs from its golden or its hash; the bytes written are in {saved}, SHA-256 {ContentHash.Sha256Hex(actual)}.");
        }
    }

    /// <summary>
    /// Gets a golden's path in the source tree.
    /// </summary>
    /// <param name="name">The golden's file name.</param>
    /// <param name="source">This file's path, filled in by the compiler.</param>
    /// <returns>The path.</returns>
    private static string GoldenPath(string name, [CallerFilePath] string source = "") =>
        Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(source))!, "Fixtures", "canonical", name);
}
