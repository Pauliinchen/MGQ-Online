//----------------------------------------------------------------
//  ShippedFileTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Data.Generator.Source;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers the events database the mod ships, <c>package/Multiplayer/Data/events.db</c>, against
/// this generator: a file left behind by a change of the generator fails the release.
/// </summary>
public sealed class ShippedFileTests
{
    /// <summary>
    /// The shipped file's path below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The switches whose scratch flag differs between the shipped file and the translated names:
    /// the translation names the temples' flags "Temple" and 2250 "General", which match the words
    /// "temp" and "general" by accident, and only the untranslated name of 73 matches.
    /// </summary>
    private static readonly int[] ReviewedSwitches =
    [
        73, 202, 270, 271, 289, 318, 358, 2250, 2505, 2737, 5002, 5040, 5059, 5060, 5094, 5133, 5202, 5270,
        5271, 5289, 5318, 5358, 5483, 5494, 5510, 5518, 5520,
    ];

    /// <summary>
    /// The variables whose scratch flag differs as <see cref="ReviewedSwitches"/> tells, all three
    /// named after a temple.
    /// </summary>
    private static readonly int[] ReviewedVariables = [1022, 1068, 1075];

    /// <summary>
    /// Asserts that the shipped file was written by this generator's version or a later one.
    /// </summary>
    [Fact]
    public void ShippedFile_IsNotOlderThanTheGenerator()
    {
        using EventStore store = EventStore.Open(ShippedFile());

        Assert.True(store.Problem is null, store.Problem);
        Assert.True(store.Meta!.Build.GeneratorVersion >= EventBuilder.Version, $"generator {store.Meta.Build.GeneratorVersion} wrote the shipped file, this one is {EventBuilder.Version}: build it again");
    }

    /// <summary>
    /// Asserts that a build of the untranslated copy EVENTS_SOURCE_DIR names gives the shipped file
    /// byte for byte; skipped without it.
    /// </summary>
    [Fact]
    public void ShippedFile_IsWhatABuildOfTheUntranslatedCopyWrites()
    {
        string source = RealGameTests.FolderOrSkip(RealGameTests.SourceSetting);
        string built = Path.Combine(Path.GetTempPath(), $"mgq-events-shipped-{Guid.NewGuid():N}.db");
        try
        {
            EventDatabaseWriter.Write(EventBuilder.Build(new GameFolderFiles(source), new BuildOptions()), built);

            Assert.True(File.ReadAllBytes(built).AsSpan().SequenceEqual(File.ReadAllBytes(ShippedFile())), $"{ShippedPath} is not what a build writes: build it again");
        }
        finally
        {
            File.Delete(built);
        }
    }

    /// <summary>
    /// Asserts that the shipped file marks the same switches and variables scratch as the names of
    /// the installed copy BATTLE_GAME_DIR names, which 0.6.9.2 read: all of them on an untranslated
    /// copy, all but the reviewed ids on a translated one; skipped without it.
    /// </summary>
    /// <remarks>
    /// A translated copy sorts each event that sets a differing id unlike 0.6.9.2 did, so a new id
    /// here needs a review before it ships.
    /// </remarks>
    [Fact]
    public void ShippedFile_MarksTheScratchOfTheInstalledCopyApartFromTheReviewedIds()
    {
        var game = new GameSource(new GameFolderFiles(RealGameTests.FolderOrSkip(RealGameTests.GameSetting)));
        (IReadOnlyList<string> switchNames, IReadOnlyList<string> variableNames) = game.ReadSystemNames();
        using EventStore store = EventStore.Open(ShippedFile());

        int[] switches = [.. IdFlags.Switches(switchNames, new HashSet<int>()).Where(row => row.Scratch != store.SwitchFlags(row.Id)?.Scratch).Select(row => row.Id)];
        int[] variables = [.. IdFlags.Variables(variableNames, 0).Where(row => row.Scratch != store.VariableFlags(row.Id)?.Scratch).Select(row => row.Id)];

        bool untranslated = switches.Length == 0 && variables.Length == 0;
        bool reviewed = ReviewedSwitches.SequenceEqual(switches) && ReviewedVariables.SequenceEqual(variables);
        Assert.True(untranslated || reviewed, $"the switches {string.Join(", ", switches)} and the variables {string.Join(", ", variables)} differ: review them first");
    }

    /// <summary>
    /// Finds the shipped file in the repository the tests were built in.
    /// </summary>
    /// <returns>Its full path.</returns>
    private static string ShippedFile()
    {
        for (DirectoryInfo? folder = new(AppContext.BaseDirectory); folder is not null; folder = folder.Parent)
        {
            string path = Path.Combine(folder.FullName, ShippedPath);
            if (File.Exists(path))
            {
                return path;
            }
        }

        throw new FileNotFoundException($"{ShippedPath} is in no folder above {AppContext.BaseDirectory}");
    }
}
