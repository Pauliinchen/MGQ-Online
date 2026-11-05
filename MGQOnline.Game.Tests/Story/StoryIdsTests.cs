//----------------------------------------------------------------
//  StoryIdsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Left out the generator's review aids, which keep the retired event checker's tables as it wrote them
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Data.Generator.Tools;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the one table of the story's ids: the relay reads the copy the generator writes of it,
/// and no script, relay module or C# file writes a story id of its own.
/// </summary>
public sealed partial class StoryIdsTests
{
    /// <summary>
    /// The folders whose code reads the story's ids, below the repository, with the files' endings.
    /// </summary>
    private static readonly (string Folder, string Ending)[] CodeFolders =
    [
        ("GameScript/Multiplayer", ".rbx"),
        ("GameScript", ".rb"),
        ("BattleServer", ".rb"),
        ("Relay/core", ".js"),
        ("Relay/node", ".js"),
        ("Relay/cloudflare", ".js"),
        (".", ".cs"),
    ];

    /// <summary>
    /// Asserts that the relay's copy of the table is what the generator writes of it now.
    /// </summary>
    [Fact]
    public void RelayCopy_IsWhatTheGeneratorWrites()
    {
        string copy = File.ReadAllText(Path.Combine(Repository.Root, StoryIdsFile.RelayPath)).ReplaceLineEndings("\n");

        Assert.True(copy == StoryIdsFile.Text(), $"{StoryIdsFile.RelayPath} differs from StoryIds: run dotnet run --project MGQOnline.Data.Generator -- story-ids {StoryIdsFile.RelayPath}");
    }

    /// <summary>
    /// Asserts that no code outside the table writes one of the story's ids of its own: a switch or
    /// variable of the markers, the return point, the playthrough, the Great Decision's progress,
    /// the story's band, the route clears, the castle's bosses or the areas' progress, as a number or
    /// a key such as "v1001", "s7096" or the counter "r1141"; or a common event of the routes' rules
    /// where it is called, such as "ce:154" or a common event's index. Comments, tests, fixtures and
    /// data are left out, and so are the generator's review aids, whose tables are the retired event
    /// checker's own, kept so they write what it wrote.
    /// </summary>
    [Fact]
    public void Code_WritesNoStoryIdOutsideTheTable()
    {
        int[] ids = [.. StoryIds.Markers, StoryIds.GameOverReturn, StoryIds.Playthrough, StoryIds.DecisionProgress, StoryIds.FirstStorySwitch,
            .. StoryIds.ClearSwitches, .. StoryIds.CastleBosses, .. StoryIds.AreaProgress];
        int[] events = [StoryIds.DecisionEvent, StoryIds.FinalResetEvent, StoryIds.ResetEvent, StoryIds.ReaperEvent, .. StoryIds.ReturnEvents];
        var number = new Regex($@"\b[vsr]?({string.Join("|", ids.Distinct())})\b|(?i:\bce:|common_?events?\w*\s*[\[(]\s*)({string.Join("|", events)})\b",
            RegexOptions.CultureInvariant);
        var found = new List<string>();
        foreach (string file in CodeFiles())
        {
            string[] lines = File.ReadAllLines(file);
            bool ruby = file.EndsWith(".rb", StringComparison.Ordinal) || file.EndsWith(".rbx", StringComparison.Ordinal);
            for (int at = 0; at < lines.Length; at++)
            {
                if (number.Match(ruby ? RubyComment().Replace(lines[at], string.Empty) : CodeOf(lines[at])) is { Success: true } match)
                {
                    found.Add($"{Path.GetRelativePath(Repository.Root, file)}:{at + 1}: {match.Value}");
                }
            }
        }

        Assert.True(found.Count == 0, $"story ids written outside MGQOnline.Game/Story/StoryIds.cs:\n{string.Join("\n", found)}");
    }

    /// <summary>
    /// Lists the code files the table's ids must not be written in: every script, relay module and
    /// C# file of the repository but the table itself, the tests, the generated, the native ones and
    /// the generator's review aids.
    /// </summary>
    /// <returns>Their full paths.</returns>
    private static IEnumerable<string> CodeFiles()
    {
        string table = Path.GetFullPath(Path.Combine(Repository.Root, "MGQOnline.Game", "Story", "StoryIds.cs"));
        string reviewAids = Path.GetFullPath(Path.Combine(Repository.Root, "MGQOnline.Data.Generator", "Review")) + Path.DirectorySeparatorChar;
        string[] skipped = ["Tests", "bin", "obj", "native", "node_modules", "fixtures", "Shipping", "TestResults"];
        return CodeFolders.SelectMany(folder => Directory.EnumerateFiles(Path.Combine(Repository.Root, folder.Folder), "*" + folder.Ending, SearchOption.AllDirectories))
            .Select(Path.GetFullPath).Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(file => file != table && !file.EndsWith(".test.js", StringComparison.Ordinal) && !file.StartsWith(reviewAids, StringComparison.OrdinalIgnoreCase)
                && !Path.GetRelativePath(Repository.Root, file).Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                    .Any(part => skipped.Contains(part) || part.EndsWith(".Tests", StringComparison.Ordinal)));
    }

    /// <summary>
    /// Takes the comments off a line of C# or JavaScript: from <c>//</c> on, and a line of a block
    /// comment.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>Its code.</returns>
    private static string CodeOf(string line)
    {
        string trimmed = line.TrimStart();
        if (trimmed.StartsWith('*') || trimmed.StartsWith("/*", StringComparison.Ordinal))
        {
            return string.Empty;
        }

        int comment = line.IndexOf("//", StringComparison.Ordinal);
        return comment < 0 ? line : line[..comment];
    }

    /// <summary>
    /// A Ruby comment: from a <c>#</c> that starts no interpolation to the line's end.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"#(?!\{).*$", RegexOptions.CultureInvariant)]
    private static partial Regex RubyComment();
}
