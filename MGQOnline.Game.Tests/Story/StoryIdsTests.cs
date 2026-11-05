//----------------------------------------------------------------
//  StoryIdsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the Cloudflare relay's folder from the scan
//                            - Dropped the scan of the code for story ids written outside the table
//      Paulinchen  2026-11-05: Left out the generator's review aids, which keep the retired event checker's tables as it wrote them
//                            - Created
//
//----------------------------------------------------------------

using System.IO;
using MGQOnline.Data.Generator.Tools;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the one table of the story's ids: the relay reads the copy the generator writes of it.
/// </summary>
public sealed class StoryIdsTests
{
    /// <summary>
    /// Asserts that the relay's copy of the table is what the generator writes of it now.
    /// </summary>
    [Fact]
    public void RelayCopy_IsWhatTheGeneratorWrites()
    {
        string copy = File.ReadAllText(Path.Combine(Repository.Root, StoryIdsFile.RelayPath)).ReplaceLineEndings("\n");

        Assert.True(copy == StoryIdsFile.Text(), $"{StoryIdsFile.RelayPath} differs from StoryIds: run dotnet run --project MGQOnline.Data.Generator -- story-ids {StoryIdsFile.RelayPath}");
    }
}
