//----------------------------------------------------------------
//  Program.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Printed the game data's proposals of work keys after a build
//      Paulinchen  2026-10-28: Added the ordinals command, which rewrites the relay's join and removal indexes into ords
//                            - Added the sort, names and export commands of the tools
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Data.Generator.Tools;
using MGQOnline.Data.Sqlite;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator;

/// <summary>
/// The generator's commands: build the events database from a game folder, check a file against
/// one, print a game's fingerprint, and compare another copy of the game with a file; for the
/// tools, sort every page of a file, write the names of the story's keys and export a table; and
/// for the relay, rewrite the command indexes of its join and removal rows into ords.
/// </summary>
internal static class Program
{
    /// <summary>
    /// The exit code of a command that did what it was asked.
    /// </summary>
    private const int Done = 0;

    /// <summary>
    /// The exit code of a check that found the file different.
    /// </summary>
    private const int Differs = 1;

    /// <summary>
    /// The exit code of a command line the generator does not understand.
    /// </summary>
    private const int Usage = 2;

    /// <summary>
    /// How to call the generator.
    /// </summary>
    private const string UsageText = """
        usage:
          build <game folder> <events.db> [--game-version 3.06] [--source untranslated]
          check <game folder> <events.db> [--game-version 3.06] [--source untranslated]
          fingerprint <game folder>
          compare <events.db> <other game folder>
          sort <events.db> <out.jsonl> [--state new|<values.json>]
          names <translated game folder> <out.json>
          export <events.db> <table> <out.json>
          ordinals <events.db> <game folder the indexes were read from> <rows.json> <out.json>
        """;

    /// <summary>
    /// Runs one command.
    /// </summary>
    /// <param name="args">The command and its arguments.</param>
    /// <returns>The exit code.</returns>
    public static int Main(string[] args)
    {
        try
        {
            return args switch
            {
                ["build", string game, string file, .. string[] rest] when OptionsOf(rest) is { } options => BuildFile(game, file, options),
                ["check", string game, string file, .. string[] rest] when OptionsOf(rest) is { } options => Check(game, file, options),
                ["fingerprint", string game] => PrintFingerprint(game),
                ["compare", string file, string other] => Compare(file, other),
                ["sort", string file, string output] => Sort(file, output, null),
                ["sort", string file, string output, "--state", "new"] => Sort(file, output, null),
                ["sort", string file, string output, "--state", string values] => Sort(file, output, values),
                ["names", string game, string output] => WriteNames(game, output),
                ["export", string file, string table, string output] => Export(file, table, output),
                ["ordinals", string file, string game, string rows, string output] => Ordinals(file, game, rows, output),
                _ => Fail(UsageText),
            };
        }
        catch (Exception failure) when (failure is IOException or UnauthorizedAccessException or InvalidDataException or RubyValueException or SqliteException)
        {
            Console.Error.WriteLine(failure.Message);
            return Usage;
        }
    }

    /// <summary>
    /// Reads the options after a command's arguments.
    /// </summary>
    /// <param name="rest">The arguments left.</param>
    /// <returns>The options, <see langword="null"/> for arguments the generator does not understand.</returns>
    private static BuildOptions? OptionsOf(string[] rest)
    {
        var options = new BuildOptions();
        for (int index = 0; index + 1 < rest.Length; index += 2)
        {
            options = rest[index] switch
            {
                "--game-version" => options with { GameVersion = rest[index + 1] },
                "--source" => options with { Source = rest[index + 1] },
                _ => null,
            };
            if (options is null)
            {
                return null;
            }
        }

        return rest.Length % 2 == 0 ? options : null;
    }

    /// <summary>
    /// Builds the database and writes it, then tells its size, how long the build took and the game
    /// data's proposals of work keys for the story key list's review.
    /// </summary>
    /// <param name="game">The game folder.</param>
    /// <param name="file">The file to write.</param>
    /// <param name="options">What the build is told about the game.</param>
    /// <returns>The exit code.</returns>
    private static int BuildFile(string game, string file, BuildOptions options)
    {
        var clock = Stopwatch.StartNew();
        (EventRows rows, BuiltGame built) = EventBuilder.Read(new GameFolderFiles(game), options);
        TimeSpan read = clock.Elapsed;
        EventDatabaseWriter.Write(rows, file);
        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"wrote {Path.GetFullPath(file)}: {new FileInfo(file).Length:N0} bytes, {rows.Lists.Count:N0} lists, {rows.Commands.Count:N0} kept commands"));
        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"read the game in {read.TotalSeconds:F1} s, wrote the file in {(clock.Elapsed - read).TotalSeconds:F1} s"));
        Console.WriteLine(rows.Build.Fingerprint);
        Console.WriteLine(WorkProposals(rows, built));
        return Done;
    }

    /// <summary>
    /// Writes the game data's proposals of work keys for the review of the story key list: the keys
    /// a command the story replay closes writes, and the switches and variables the game names as
    /// scratch.
    /// </summary>
    /// <param name="rows">The rows built.</param>
    /// <param name="built">The game read.</param>
    /// <returns>The line.</returns>
    private static string WorkProposals(EventRows rows, BuiltGame built)
    {
        IEnumerable<string> scratch = rows.Switches.Where(row => row.Scratch).Select(row => string.Create(CultureInfo.InvariantCulture, $"s{row.Id}"))
            .Concat(rows.Variables.Where(row => row.Scratch).Select(row => string.Create(CultureInfo.InvariantCulture, $"v{row.Id}")));
        return $"work keys to review: {string.Join(", ", ReplayChannels.ClosedWrites(built))} (a command the story replay closes writes them); scratch by the game's names: {string.Join(", ", scratch)}";
    }

    /// <summary>
    /// Builds the database again and compares it byte for byte with a file.
    /// </summary>
    /// <param name="game">The game folder.</param>
    /// <param name="file">The file to check.</param>
    /// <param name="options">What the build is told about the game.</param>
    /// <returns>The exit code: <see cref="Differs"/> when the file is not what the build writes.</returns>
    private static int Check(string game, string file, BuildOptions options)
    {
        EventRows rows = EventBuilder.Build(new GameFolderFiles(game), options);
        string built = Path.Combine(Path.GetTempPath(), $"mgq-events-check-{Guid.NewGuid():N}.db");
        try
        {
            EventDatabaseWriter.Write(rows, built);
            PrintParts(rows.FingerprintParts);
            bool same = File.ReadAllBytes(built).AsSpan().SequenceEqual(File.ReadAllBytes(file));
            Console.WriteLine(same ? $"{file} is byte-equal to a new build" : $"{file} differs from a new build");
            return same ? Done : Differs;
        }
        finally
        {
            File.Delete(built);
        }
    }

    /// <summary>
    /// Prints a game folder's fingerprint and its parts.
    /// </summary>
    /// <param name="game">The game folder.</param>
    /// <returns>The exit code.</returns>
    private static int PrintFingerprint(string game)
    {
        List<FingerprintPart> parts = EventBuilder.Fingerprint(new GameFolderFiles(game));
        PrintParts(parts);
        Console.WriteLine(GameFingerprint.Text(parts));
        return Done;
    }

    /// <summary>
    /// Compares another copy of the game with a database and prints the report.
    /// </summary>
    /// <param name="file">The database.</param>
    /// <param name="other">The other copy's game folder.</param>
    /// <returns>The exit code.</returns>
    private static int Compare(string file, string other)
    {
        using EventStore store = EventStore.Open(file);
        if (store.Problem is { } problem)
        {
            return Fail(problem);
        }

        Console.Write(CopyComparison.Of(store, new GameFolderFiles(other)).Report());
        return Done;
    }

    /// <summary>
    /// Sorts every map page and common event of a database as the mod sorts them in a Classic
    /// party's game, and writes their kinds and marks for the event checker.
    /// </summary>
    /// <param name="file">The database.</param>
    /// <param name="output">The JSON lines file to write.</param>
    /// <param name="values">A file of the switches and variables set, <see langword="null"/> for a new game.</param>
    /// <returns>The exit code.</returns>
    private static int Sort(string file, string output, string? values)
    {
        using EventStore store = EventStore.Open(file);
        if (store.Problem is { } problem)
        {
            return Fail(problem);
        }

        var clock = Stopwatch.StartNew();
        var source = new DatabaseSource(store);
        IEventState state = OfflineSort.StateOf(store, source, values);
        int count;
        using (FileStream stream = File.Create(output))
        {
            count = OfflineSort.Write(source, state, stream);
        }

        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"{count:N0} pages and common events sorted into {Path.GetFullPath(output)} in {clock.Elapsed.TotalSeconds:F1} s"));
        return Done;
    }

    /// <summary>
    /// Writes the names of the story's keys a game's data gives them, for the website.
    /// </summary>
    /// <param name="game">The game folder, a translated copy for the names a player reads.</param>
    /// <param name="output">The JSON file to write.</param>
    /// <returns>The exit code.</returns>
    private static int WriteNames(string game, string output)
    {
        StoryNames names = StoryNames.Of(GameData.OfFolder(game));
        using (FileStream stream = File.Create(output))
        {
            NamesFile.Write(names, stream);
        }

        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"wrote {Path.GetFullPath(output)}: {names.Switches.Count:N0} switches, {names.Variables.Count:N0} variables, {names.Maps.Count:N0} maps, {names.Events.Count:N0} events, {names.Companions:N0} companions"));
        return Done;
    }

    /// <summary>
    /// Writes one table or view of a database as JSON.
    /// </summary>
    /// <param name="file">The database.</param>
    /// <param name="table">The table or view.</param>
    /// <param name="output">The JSON file to write.</param>
    /// <returns>The exit code.</returns>
    private static int Export(string file, string table, string output)
    {
        using (EventStore store = EventStore.Open(file))
        {
            if (store.Problem is { } problem)
            {
                return Fail(problem);
            }
        }

        int count = TableExport.Write(file, table, output);
        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"wrote {count:N0} rows of {table} to {Path.GetFullPath(output)}"));
        return Done;
    }

    /// <summary>
    /// Rewrites the indexes of the relay's join or removal rows into the ords of the events database:
    /// a seed file (a list of admin edits) into the same file with the ords, or a table as the admin
    /// route lists it into the batch of changes for the admin route.
    /// </summary>
    /// <param name="file">The database.</param>
    /// <param name="game">The copy of the game the indexes were read from.</param>
    /// <param name="rows">The seed file or the admin route's listing.</param>
    /// <param name="output">The file to write.</param>
    /// <returns>The exit code: <see cref="Differs"/> when a row's command was not found, which it names.</returns>
    private static int Ordinals(string file, string game, string rows, string output)
    {
        using EventStore store = EventStore.Open(file);
        if (store.Problem is { } problem)
        {
            return Fail(problem);
        }

        EventRows copy = EventBuilder.Build(new GameFolderFiles(game), new BuildOptions());
        string text = File.ReadAllText(rows);
        var unresolved = new List<string>();
        string written = text.TrimStart().StartsWith('[')
            ? StoryOrdinals.RewriteSeed(text, copy, store, unresolved)
            : StoryOrdinals.Batch(text, copy, store, unresolved);
        File.WriteAllText(output, written);
        unresolved.ForEach(Console.Error.WriteLine);
        Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"wrote {Path.GetFullPath(output)}; {unresolved.Count} row(s) not found"));
        return unresolved.Count == 0 ? Done : Differs;
    }

    /// <summary>
    /// Prints the fingerprint's parts, one a line.
    /// </summary>
    /// <param name="parts">The parts.</param>
    private static void PrintParts(IEnumerable<FingerprintPart> parts)
    {
        foreach (FingerprintPart part in parts.OrderBy(part => part.PartNo))
        {
            Console.WriteLine(string.Create(CultureInfo.InvariantCulture, $"{part.Part,-14} {part.Crc} {part.IdCount,6} ids"));
        }
    }

    /// <summary>
    /// Tells why the generator stops.
    /// </summary>
    /// <param name="message">Why.</param>
    /// <returns><see cref="Usage"/>.</returns>
    private static int Fail(string message)
    {
        Console.Error.WriteLine(message);
        return Usage;
    }
}
