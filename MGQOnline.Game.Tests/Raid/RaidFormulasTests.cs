//----------------------------------------------------------------
//  RaidFormulasTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Held the script tests to both checks too
//                            - Checked that the refusal chain is written once
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Checks that each raid rule the scripts and the C# hosts once each kept a copy of is worked out in
/// one place of the game's code: the pools' regeneration in <c>PoolLedger</c>, whose share the
/// relay's own count is held to by fixtures/pool/relay.json, and the refusal chain in <c>BossRules</c>.
/// </summary>
public sealed partial class RaidFormulasTests
{
    /// <summary>
    /// Asserts that only the ledger fills a pool up by the share a minute, and that no script,
    /// script test or battle server file reads the share a minute but the pools' stand-in.
    /// </summary>
    /// <remarks>The pools' stand-in of the script tests still counts it; its removal is queued.</remarks>
    [Fact]
    public void Regeneration_IsCountedOnce()
    {
        Assert.Equal(["MGQOnline.Game/Raid/PoolLedger.cs"], FilesWhere(CSharpSources(), line => RegenTimes().IsMatch(line)));
        Assert.Equal(["GameScript/Tests/pool_support.rb"], FilesWhere(ScriptSources(), line => RegenWord().IsMatch(line)));
    }

    /// <summary>
    /// Asserts that the refusal chain of the story boss battles, which the pools, the tiers and a
    /// lost battle's defeat once each kept, is written once, in <c>BossRules</c>, and no script or
    /// script test refuses a battle by its own chain.
    /// </summary>
    [Fact]
    public void RefusalChain_IsWrittenOnce()
    {
        Assert.Equal(["MGQOnline.Game/Raid/BossRules.cs"], FilesWhere(CSharpSources(), line => ChainReason().IsMatch(line)));
        Assert.Empty(FilesWhere(ScriptSources(), line => ChainReason().IsMatch(line)));
    }

    /// <summary>
    /// Lists the game's C# sources, the tests and build output left out.
    /// </summary>
    /// <returns>The files.</returns>
    internal static IEnumerable<string> CSharpSources() =>
        Directory.EnumerateFiles(Repository.Root, "*.cs", SearchOption.AllDirectories)
            .Where(file => !Relative(file).Split('/').Any(part => part is "bin" or "obj" || part.EndsWith(".Tests", StringComparison.Ordinal)));

    /// <summary>
    /// Lists the game's scripts, their tests and the battle server's Ruby files, so a test's copy of
    /// a rule counts as a copy too.
    /// </summary>
    /// <returns>The files.</returns>
    internal static IEnumerable<string> ScriptSources() =>
        Directory.EnumerateFiles(Path.Combine(Repository.Root, "GameScript", "Multiplayer", "Scripts"), "*.rbx")
            .Append(Path.Combine(Repository.Root, "GameScript", "Multiplayer.rb"))
            .Concat(Directory.EnumerateFiles(Path.Combine(Repository.Root, "GameScript", "Tests"), "*.rb"))
            .Concat(Directory.EnumerateFiles(Path.Combine(Repository.Root, "BattleServer", "lib"), "*.rb"));

    /// <summary>
    /// Lists the files a line of which matches, as paths from the repository's folder.
    /// </summary>
    /// <param name="files">The files.</param>
    /// <param name="matches">Whether a line matches.</param>
    /// <returns>The files, in order.</returns>
    internal static IReadOnlyList<string> FilesWhere(IEnumerable<string> files, Func<string, bool> matches) =>
        [.. files.Where(file => File.ReadLines(file).Any(matches)).Select(Relative).Order(StringComparer.Ordinal)];

    /// <summary>
    /// Writes a file's path from the repository's folder with forward slashes.
    /// </summary>
    /// <param name="file">The file.</param>
    /// <returns>The path.</returns>
    private static string Relative(string file) => Path.GetRelativePath(Repository.Root, file).Replace('\\', '/');

    /// <summary>
    /// A share a minute multiplied by the time passed.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"[Rr]egen\w*\s*\*")]
    private static partial Regex RegenTimes();

    /// <summary>
    /// A reason of the refusal chain written as a text: an earlier phase, a Hades rematch, a
    /// Colosseum battle or a fight raid bosses leave out.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\"(an earlier phase of its fight|a Hades rematch|a Colosseum battle|a fight raid bosses leave out[^\"]*)\"")]
    private static partial Regex ChainReason();

    /// <summary>
    /// The share a minute named in a script.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\bregen\b|@regen|regen_per", RegexOptions.IgnoreCase)]
    private static partial Regex RegenWord();
}
