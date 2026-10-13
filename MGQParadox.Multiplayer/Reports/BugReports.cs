//----------------------------------------------------------------
//  BugReports.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reflection;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Reports;

/// <summary>
/// The in-game bug reports: the screenshot taken when the report opened, and sending one report at a
/// time to the relay on a thread of its own, which files it as a GitHub issue. The game script reads
/// how the last report went.
/// </summary>
internal sealed class BugReports
{
    /// <summary>
    /// The flag of <see cref="Send"/> that attaches the pending screenshot.
    /// </summary>
    public const int AttachScreenshot = 1;

    /// <summary>
    /// The flag of <see cref="Send"/> that attaches the logs, <c>errors.txt</c> and the list of the Patch folder.
    /// </summary>
    public const int AttachLogs = 2;

    /// <summary>
    /// The widest and highest screenshot taken, in pixels.
    /// </summary>
    public const int MaxScreenSide = 4096;

    /// <summary>
    /// The longest title the relay takes, trimmed.
    /// </summary>
    public const int MaxTitleLength = 100;

    /// <summary>
    /// The longest text the relay takes, trimmed.
    /// </summary>
    public const int MaxTextLength = 4000;

    /// <summary>
    /// The most facts the relay takes.
    /// </summary>
    public const int MaxFacts = 12;

    /// <summary>
    /// The longest label of a fact the relay takes.
    /// </summary>
    public const int MaxFactLabelLength = 32;

    /// <summary>
    /// The longest value of a fact the relay takes.
    /// </summary>
    public const int MaxFactValueLength = 120;

    /// <summary>
    /// The longest version the relay takes.
    /// </summary>
    private const int MaxVersionLength = 32;

    /// <summary>
    /// The largest PNG sent, whose base64 is the 4 MiB the relay takes.
    /// </summary>
    private const int MaxScreenshotBytes = 3 * 1024 * 1024;

    /// <summary>
    /// The state before the first report.
    /// </summary>
    private const string Idle = "idle";

    /// <summary>
    /// The state while a report is sent.
    /// </summary>
    private const string Sending = "sending";

    /// <summary>
    /// The failure's code when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "unreachable";

    /// <summary>
    /// The failure's code when the report could not be put together.
    /// </summary>
    private const string LocalError = "error";

    /// <summary>
    /// How long before the game process started the logs taken may have been written.
    /// </summary>
    private static readonly TimeSpan LogSlack = TimeSpan.FromMinutes(1);

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The screenshot taken when the report opened, <see langword="null"/> for none.
    /// </summary>
    private Screenshot? _screenshot;

    /// <summary>
    /// Whether a report is being sent.
    /// </summary>
    private bool _sending;

    /// <summary>
    /// What the game script reads, see <see cref="Describe"/>.
    /// </summary>
    private string _state = Idle;

    /// <summary>
    /// The game's bug reports, which the game script uses.
    /// </summary>
    public static BugReports Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// The game's folder, whose logs go into the report; tests point it elsewhere.
    /// </summary>
    public Func<string> GameFolder { get; init; } = () => ModFolder.GamePathOf(".");

    /// <summary>
    /// When the game process started, in UTC; logs written since go into the report.
    /// </summary>
    public Func<DateTime> SessionStart { get; init; } = GameStart;

    /// <summary>
    /// Tells the time in UTC.
    /// </summary>
    public Func<DateTime> Now { get; init; } = () => DateTime.UtcNow;

    /// <summary>
    /// Writes what the DLL's log holds queued, so the report carries it.
    /// </summary>
    public Action FlushLog { get; init; } = Log.Flush;

    /// <summary>
    /// The mod's version as the build stamped it, such as <c>0.6.3+&lt;commit&gt;</c>.
    /// </summary>
    public string Version { get; init; } = typeof(BugReports).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "unknown";

    /// <summary>
    /// Whether the mod is a development build.
    /// </summary>
    public bool DevelopmentBuild { get; init; } = UpdateCheck.DevelopmentBuild;

    /// <summary>
    /// Tells whether a screenshot's size is one the DLL takes.
    /// </summary>
    /// <param name="width">The width in pixels.</param>
    /// <param name="height">The height in pixels.</param>
    /// <returns>Whether both are 1 to <see cref="MaxScreenSide"/>.</returns>
    public static bool IsScreenSize(int width, int height) => width is >= 1 and <= MaxScreenSide && height is >= 1 and <= MaxScreenSide;

    /// <summary>
    /// Keeps a copy of the screen as the pending screenshot, replacing an earlier one.
    /// </summary>
    /// <param name="pixels">The pixels as the game keeps a bitmap: B, G, R, A, the last row first.</param>
    /// <param name="width">The width in pixels.</param>
    /// <param name="height">The height in pixels.</param>
    /// <returns><see langword="false"/> for a size the DLL does not take or pixels that do not match it.</returns>
    public bool Snap(ReadOnlySpan<byte> pixels, int width, int height)
    {
        if (!IsScreenSize(width, height) || pixels.Length != width * height * Png.SourcePixelBytes)
        {
            Log.Write($"bug report screenshot not kept: {pixels.Length} bytes for {width} x {height} pixels");
            return false;
        }

        var screenshot = new Screenshot(pixels.ToArray(), width, height);

        lock (_gate)
        {
            _screenshot = screenshot;
        }

        Log.Write($"bug report screenshot kept, {width} x {height} pixels");
        return true;
    }

    /// <summary>
    /// Forgets the pending screenshot.
    /// </summary>
    public void DropSnap()
    {
        lock (_gate)
        {
            if (_screenshot == null)
            {
                return;
            }

            _screenshot = null;
        }

        Log.Write("bug report screenshot dropped");
    }

    /// <summary>
    /// Starts sending a report on a thread of its own. The pending screenshot is forgotten once it started, attached or not.
    /// </summary>
    /// <param name="title">The issue's title.</param>
    /// <param name="text">What happened.</param>
    /// <param name="facts">The public facts, lines of <c>label\tvalue</c>; those beyond the relay's limits are cut or left out.</param>
    /// <param name="details">The private details for <c>report.md</c>, lines of <c>label\tvalue</c>.</param>
    /// <param name="flags"><see cref="AttachScreenshot"/> and <see cref="AttachLogs"/>.</param>
    /// <returns><see langword="false"/> while a report is sent, without a player, without a relay, or for a title or text outside the relay's limits.</returns>
    public bool Send(string title, string text, string facts, string details, int flags)
    {
        title = title.Trim();
        text = text.Trim();

        if (title.Length is 0 or > MaxTitleLength || title.Contains('\n') || title.Contains('\r') || text.Length is 0 or > MaxTextLength)
        {
            Log.Write($"bug report not sent: the title has {title.Length} characters and the text {text.Length}, or the title spans lines");
            return false;
        }

        if (Playing() is not { } player || RelayAddress(Relays.Current) is not { } relay)
        {
            Log.Write("bug report not sent: no player, or a relay this version does not know");
            return false;
        }

        var version = VersionOf(Version);

        if (FitHeader(new BugReport(title, text, version, PublicFacts(version, facts))) is not { } report)
        {
            Log.Write("bug report not sent: its header is longer than the relay takes");
            return false;
        }

        Screenshot? screenshot;

        lock (_gate)
        {
            if (_sending)
            {
                Log.Write("bug report not sent: another one is still being sent");
                return false;
            }

            _sending = true;
            _state = Sending;
            screenshot = _screenshot;
            _screenshot = null;
        }

        var attachScreenshot = (flags & AttachScreenshot) != 0 && screenshot != null;
        var attachLogs = (flags & AttachLogs) != 0;
        Log.Write($"sending a bug report: title of {title.Length} characters, text of {text.Length}, {report.Facts.Count} fact(s), screenshot {(attachScreenshot ? "attached" : "not attached")}, logs {(attachLogs ? "attached" : "not attached")}");

        try
        {
            var job = new Job(report, LinesOf(details), attachScreenshot ? screenshot : null, attachLogs);
            var client = new DirectoryClient(relay);
            Threads.Start("MultiplayerBugReport", () => Run(client, player.Key, job));
            return true;
        }
        catch (Exception ex)
        {
            lock (_gate)
            {
                _state = FailureOf(ex);
                _sending = false;
            }

            throw;
        }
    }

    /// <summary>
    /// Describes how the last report went, for the game script.
    /// </summary>
    /// <returns><c>idle</c> before the first report, <c>sending</c>, <c>sent\t&lt;issue&gt;\t&lt;url&gt;</c>, or <c>failed\t&lt;code&gt;\t&lt;reason&gt;</c>, where the code is the relay's, <c>http&lt;status&gt;</c>, <c>unreachable</c> or <c>error</c>.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            return _state;
        }
    }

    /// <summary>
    /// Reads the version the relay is sent from the one the build stamped.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped, such as <c>0.6.3+&lt;commit&gt;</c>.</param>
    /// <returns>The version without its commit, only of the characters the relay takes, at most 32 of them; <c>unknown</c> when nothing is left.</returns>
    internal static string VersionOf(string informationalVersion)
    {
        var version = new string(informationalVersion.Split('+')[0].Where(character => char.IsAsciiLetterOrDigit(character) || character is '.' or '-').ToArray());
        return version.Length == 0 ? "unknown" : version[..Math.Min(version.Length, MaxVersionLength)];
    }

    /// <summary>
    /// Lists the public facts of a report: the mod's version first, then the game's facts.
    /// </summary>
    /// <remarks>
    /// The game's scripts cannot read the version the build stamped, which only the DLL carries.
    /// </remarks>
    /// <param name="version">The mod's version, see <see cref="VersionOf"/>.</param>
    /// <param name="facts">The game's facts, lines of <c>label\tvalue</c>.</param>
    /// <returns>At most <see cref="MaxFacts"/> facts, the version's among them.</returns>
    internal static IReadOnlyList<ReportFact> PublicFacts(string version, string facts) =>
        new[] { new ReportFact("Mod", version) }
            .Concat(FactsOf(facts).Where(fact => fact.Label != "Mod"))
            .Take(MaxFacts)
            .ToList();

    /// <summary>
    /// Reads the public facts as the relay takes them.
    /// </summary>
    /// <param name="text">Lines of <c>label\tvalue</c>.</param>
    /// <returns>At most <see cref="MaxFacts"/> facts, each label and value cut to the relay's limits; a line without a label is left out.</returns>
    internal static IReadOnlyList<ReportFact> FactsOf(string text) =>
        LinesOf(text)
            .Where(fact => fact.Label.Length > 0)
            .Select(fact => new ReportFact(Shortened(fact.Label, MaxFactLabelLength), Shortened(fact.Value, MaxFactValueLength)))
            .Take(MaxFacts)
            .ToList();

    /// <summary>
    /// Reads lines of <c>label\tvalue</c>.
    /// </summary>
    /// <param name="text">The lines, separated by line breaks.</param>
    /// <returns>Each line that is not blank, its label and value trimmed; a line without a tab is all label.</returns>
    internal static IReadOnlyList<ReportFact> LinesOf(string text)
    {
        var lines = new List<ReportFact>();

        foreach (var line in text.Replace('\r', ' ').Split('\n'))
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var tab = line.IndexOf('\t');
            lines.Add(tab < 0
                ? new ReportFact(line.Trim(), string.Empty)
                : new ReportFact(line[..tab].Trim(), line[(tab + 1)..].Replace('\t', ' ').Trim()));
        }

        return lines;
    }

    /// <summary>
    /// Describes a failure as the game script reads it.
    /// </summary>
    /// <param name="ex">Why the report failed.</param>
    /// <returns><c>failed\t&lt;code&gt;\t&lt;reason&gt;</c>, the reason on one line without tabs.</returns>
    internal static string FailureOf(Exception ex)
    {
        var code = ex is DirectoryException refusal
            ? refusal.Code ?? (refusal.Status is { } status ? $"http{((int)status).ToString(CultureInfo.InvariantCulture)}" : Unreachable)
            : LocalError;
        var reason = ex.GetBaseException().Message.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');
        return $"failed\t{code}\t{reason}";
    }

    /// <summary>
    /// Leaves facts out from the end until the header fits the relay's limit with the page and the screenshot at their longest.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <returns>The report that fits, <see langword="null"/> when it does not fit even without facts.</returns>
    private static BugReport? FitHeader(BugReport report)
    {
        (string, int, bool)[] longest = [(DirectoryClient.ReportPageFile, int.MaxValue, true), (DirectoryClient.ScreenshotFile, int.MaxValue, false)];

        for (var count = report.Facts.Count; count >= 0; count--)
        {
            var fitted = count == report.Facts.Count ? report : report with { Facts = report.Facts.Take(count).ToList() };

            if (DirectoryClient.ReportHeader(fitted, longest).Length <= DirectoryClient.MaxReportHeaderBytes)
            {
                return fitted;
            }
        }

        return null;
    }

    /// <summary>
    /// Cuts a text to a length, never between the halves of a character.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="length">The most characters kept.</param>
    /// <returns>The text, cut.</returns>
    private static string Shortened(string text, int length)
    {
        if (text.Length <= length)
        {
            return text;
        }

        return char.IsHighSurrogate(text[length - 1]) ? text[..(length - 1)] : text[..length];
    }

    /// <summary>
    /// Reads when the game process started.
    /// </summary>
    /// <returns>The start in UTC, or the earliest moment when Windows does not tell it, which takes every log.</returns>
    private static DateTime GameStart()
    {
        try
        {
            using var game = Process.GetCurrentProcess();
            return game.StartTime.ToUniversalTime();
        }
        catch
        {
            return DateTime.MinValue;
        }
    }

    /// <summary>
    /// Puts a report together and sends it, then keeps how it went.
    /// </summary>
    /// <param name="client">The relay's client.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="job">The report.</param>
    private void Run(DirectoryClient client, string playerKey, Job job)
    {
        string state;

        try
        {
            byte[]? png = null;
            string? screenshotNote = null;

            if (job.Screenshot is { } screenshot)
            {
                png = Png.Encode(screenshot.Pixels, screenshot.Width, screenshot.Height);

                if (png.Length > MaxScreenshotBytes)
                {
                    screenshotNote = $"The screenshot was left out: its {png.Length} bytes are more than the relay takes.";
                    Log.Write($"bug report screenshot left out: its {png.Length} bytes are more than the relay takes");
                    png = null;
                }
            }

            FlushLog();

            var start = SessionStart();
            var since = start > DateTime.MinValue + LogSlack ? start - LogSlack : DateTime.MinValue;
            var page = new ReportPage(job.Report, job.Details, Now(), Version, DevelopmentBuild, screenshotNote);
            var files = ReportFiles.Build(page, png, job.Logs ? GameFolder() : null, since);

            var answer = client.SendReport(playerKey, job.Report, files);
            state = $"sent\t{answer.Issue.ToString(CultureInfo.InvariantCulture)}\t{answer.Url}";
            Log.Write($"bug report sent as issue #{answer.Issue}, report {answer.Id}");
        }
        catch (Exception ex)
        {
            state = FailureOf(ex);
            Log.Write($"bug report failed: {state.Replace('\t', ' ')}");
        }

        lock (_gate)
        {
            _state = state;
            _sending = false;
        }
    }

    /// <summary>
    /// A screenshot as the game keeps it.
    /// </summary>
    /// <param name="Pixels">B, G, R, A per pixel, the last row first.</param>
    /// <param name="Width">The width in pixels.</param>
    /// <param name="Height">The height in pixels.</param>
    private sealed record Screenshot(byte[] Pixels, int Width, int Height);

    /// <summary>
    /// A report being sent.
    /// </summary>
    /// <param name="Report">What the header tells.</param>
    /// <param name="Details">The private details for <c>report.md</c>.</param>
    /// <param name="Screenshot">The screenshot to attach, <see langword="null"/> for none.</param>
    /// <param name="Logs">Whether the logs go in.</param>
    private sealed record Job(BugReport Report, IReadOnlyList<ReportFact> Details, Screenshot? Screenshot, bool Logs);
}
