//----------------------------------------------------------------
//  MarkdownTextTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers turning a mod's Markdown description into the plain lines the Mods screen shows.
/// </summary>
public sealed class MarkdownTextTests
{
    /// <summary>
    /// Asserts that each paragraph, heading and list item becomes one line without its marks, that
    /// images, HTML tags, fences and blank lines go, and that a word's underscores stay.
    /// </summary>
    [Fact]
    public void Lines_StripTheMarksToOneLinePerParagraphOrItem()
    {
        var markdown = """
            # Level Cap ##

            Caps the **levels** of
            your _party_ at the `Level_Cap.rb` [boss](https://mgqonline.org/mods/level-cap).

            ![Screenshot](https://mgqonline.org/shot.png)

            - **Points:** spend them
              on slots
            2. Second <b>item</b>

            ```ruby
            puts 1
            ```
            ---
            > Quoted *line* of Level_Cap
            """;

        Assert.Equal(
            ["Level Cap", "Caps the levels of your party at the Level_Cap.rb boss.", "- Points: spend them on slots", "- Second item", "puts 1", "Quoted line of Level_Cap"],
            MarkdownText.Lines(markdown.Replace("\n", "\r\n"), 60, 400));
    }

    /// <summary>
    /// Asserts that only the first lines are kept and a long line is cut.
    /// </summary>
    [Fact]
    public void Lines_KeepTheFirstLinesCut()
    {
        var markdown = string.Join("\n\n", Enumerable.Range(1, 70).Select(index => new string('a', index * 10)));

        var lines = MarkdownText.Lines(markdown, 60, 400);

        Assert.Equal(60, lines.Count);
        Assert.Equal(10, lines[0].Length);
        Assert.Equal(400, lines[59].Length);
    }
}
