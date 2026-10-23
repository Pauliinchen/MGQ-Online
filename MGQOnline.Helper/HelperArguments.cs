//----------------------------------------------------------------
//  HelperArguments.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace MGQOnline.Helper;

/// <summary>
/// What the helper does.
/// </summary>
internal enum HelperMode
{
    /// <summary>
    /// Installs a release of the mod over the game folder.
    /// </summary>
    Update,

    /// <summary>
    /// Starts the game again once it closed.
    /// </summary>
    Restart,

    /// <summary>
    /// Watches a game that parked mods and brings them back once it closed.
    /// </summary>
    Watch,
}

/// <summary>
/// What the helper was started with.
/// </summary>
/// <param name="Mode">What it does.</param>
/// <param name="GameFolder">The game folder's full path, which holds Game.exe and Patch.</param>
/// <param name="Game">The game's process id, which the helper waits for; 0 for none.</param>
/// <param name="Version">The release the update installs, newer or older; <see langword="null"/> for the latest.</param>
/// <param name="Rejoin">Whether the watchdog starts the game again into the world; else it starts it to the title once the mods are back, when the journal asks for it.</param>
/// <param name="Watch">The id the DLL wrote into the journal for the watchdog.</param>
/// <param name="UnreadableSeconds">How long the journal may stay unreadable before the watchdog gives up.</param>
internal sealed record HelperArguments(HelperMode Mode, string GameFolder, int Game, string? Version, bool Rejoin, string Watch, int UnreadableSeconds)
{
    /// <summary>
    /// What the helper prints when its arguments make no sense.
    /// </summary>
    public const string Usage = """
        Usage: Helper.exe update [--version <release>] [--game <process id>] [--folder <game folder>]
               Helper.exe restart --game <process id> [--folder <game folder>]
               Helper.exe watch --game <process id> --mode rejoin|title --watch <id> [--folder <game folder>]
        """;

    /// <summary>
    /// How long the journal may stay unreadable by default, in seconds; only tests pass less.
    /// </summary>
    public const int DefaultUnreadableSeconds = 600;

    /// <summary>
    /// The options each mode takes.
    /// </summary>
    private static readonly Dictionary<HelperMode, string[]> Options = new()
    {
        [HelperMode.Update] = ["--version", "--game", "--folder"],
        [HelperMode.Restart] = ["--game", "--folder"],
        [HelperMode.Watch] = ["--game", "--mode", "--watch", "--folder", "--unreadable-seconds"],
    };

    /// <summary>
    /// The game's Game.exe.
    /// </summary>
    public string GameExe => Path.Combine(GameFolder, "Game.exe");

    /// <summary>
    /// The mod's folder in Patch, which holds the DLL, Manifest.txt and the helper.
    /// </summary>
    public string ModDirectory => Path.Combine(GameFolder, "Patch", "Multiplayer");

    /// <summary>
    /// Reads the helper's arguments: the mode, then pairs of an option and its value.
    /// </summary>
    /// <param name="args">The arguments.</param>
    /// <param name="defaultFolder">The game folder when <c>--folder</c> names none.</param>
    /// <returns>The arguments, or <see langword="null"/> for an unknown mode or option, a missing value, or a restart or watch without the options it needs.</returns>
    public static HelperArguments? Parse(IReadOnlyList<string> args, string defaultFolder)
    {
        if (args.Count == 0 || !Enum.TryParse<HelperMode>(args[0], ignoreCase: true, out var mode) || !Enum.IsDefined(mode) || args.Count % 2 == 0)
        {
            return null;
        }

        var values = new Dictionary<string, string>(StringComparer.Ordinal);

        for (var index = 1; index < args.Count; index += 2)
        {
            if (Array.IndexOf(Options[mode], args[index]) < 0 || !values.TryAdd(args[index], args[index + 1]))
            {
                return null;
            }
        }

        var game = values.TryGetValue("--game", out var id) ? NumberOf(id) : (mode == HelperMode.Update ? 0 : -1);
        var unreadable = values.TryGetValue("--unreadable-seconds", out var seconds) ? NumberOf(seconds) : DefaultUnreadableSeconds;
        var watchMode = values.GetValueOrDefault("--mode");

        if (game < 0 || unreadable <= 0 || (mode == HelperMode.Watch && (watchMode is not ("rejoin" or "title") || !values.ContainsKey("--watch"))))
        {
            return null;
        }

        var folder = values.TryGetValue("--folder", out var given) ? given : defaultFolder;
        var version = values.GetValueOrDefault("--version");

        return new HelperArguments(
            mode,
            Path.TrimEndingDirectorySeparator(Path.GetFullPath(folder)),
            game,
            string.IsNullOrEmpty(version) ? null : version,
            watchMode == "rejoin",
            values.GetValueOrDefault("--watch", string.Empty),
            unreadable);
    }

    /// <summary>
    /// Reads a whole number that is no less than 0.
    /// </summary>
    /// <param name="text">The number's digits.</param>
    /// <returns>The number, or -1 for anything else.</returns>
    private static int NumberOf(string text) =>
        int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : -1;
}
