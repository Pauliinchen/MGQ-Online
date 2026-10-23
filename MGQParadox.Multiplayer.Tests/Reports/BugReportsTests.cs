//----------------------------------------------------------------
//  BugReportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Checked the public fact of where the last error was raised
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Reports;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Covers the in-game bug reports: the pending screenshot, what a report sends and when it is
/// refused, and the state the game script reads, against a report relay inside this process.
/// </summary>
public sealed class BugReportsTests : IDisposable
{
    /// <summary>
    /// How long a test waits for a report to end.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// When the game started in these tests, in UTC.
    /// </summary>
    private static readonly DateTime Started = new(2026, 10, 11, 12, 0, 0, DateTimeKind.Utc);

    /// <summary>
    /// The game folder of the test.
    /// </summary>
    private readonly string _game = Path.Combine(Path.GetTempPath(), $"mgqmp-bug-report-{Guid.NewGuid():N}");

    /// <summary>
    /// Creates the game folder with a log of the session.
    /// </summary>
    public BugReportsTests()
    {
        Directory.CreateDirectory(Path.Combine(_game, "Logs"));
        var log = Path.Combine(_game, "Logs", "Multiplayer session.log");
        File.WriteAllText(log, "session line\r\n");
        File.SetLastWriteTimeUtc(log, Started.AddMinutes(3));
    }

    /// <inheritdoc />
    public void Dispose() => Directory.Delete(_game, true);

    /// <summary>
    /// Asserts that a report with the screenshot and the logs sends the header, report.md, the PNG
    /// and the session's files, ends as sent with the issue, and forgets the screenshot.
    /// </summary>
    [Fact]
    public void Send_WithScreenshotAndLogs_SendsBothFilesAndEndsSent()
    {
        using var relay = new ReportRelay();
        var reports = NewReports(relay);

        Assert.Equal("idle", reports.Describe());
        Assert.True(reports.Snap(new byte[2 * 2 * 4], 2, 2));
        Assert.True(reports.Send("  Formation stays shut ", "It stays shut.", "Mod\t0.6.3\nWorld\tRaid\n", "Player\t<Player>\nMap\t154", BugReports.AttachScreenshot | BugReports.AttachLogs));

        Assert.Equal("sent\t42\thttps://github.com/Pauliinchen/MGQ-Online/issues/42", AwaitEnd(reports));

        var (header, files) = Parse(Assert.Single(relay.Requests).Body);
        Assert.Equal("Formation stays shut", header.GetProperty("title").GetString());
        Assert.Equal("It stays shut.", header.GetProperty("text").GetString());
        Assert.Equal("0.6.3", header.GetProperty("version").GetString());
        Assert.Equal(2, header.GetProperty("facts").GetArrayLength());
        Assert.Equal(["report.md", "screenshot.png", "Logs/Multiplayer session.log", "mods.txt"], files.Keys);
        Assert.Equal([true, false, true, true], files.Values.Select(file => file.Gzip));
        Assert.Equal(Png.Signature.ToArray(), files["screenshot.png"].Data[..8]);
        Assert.Equal("session line\r\n", ReportFilesTests.Unpack(files["Logs/Multiplayer session.log"]));

        var page = ReportFilesTests.Unpack(files["report.md"]);
        Assert.StartsWith("# Formation stays shut\n\nIt stays shut.\n\n## Facts\n| | |\n| --- | --- |\n| Mod | 0.6.3 |\n| World | Raid |\n\n", page, StringComparison.Ordinal);
        Assert.Contains("| Mod build | 0.6.3+0123abcd |\n| Development build | no |\n| Player | <Player> |\n| Map | 154 |\n", page);
        Assert.Contains("## Screenshot\n![Screenshot](screenshot.png)\n", page);
        Assert.Contains("- [Logs/Multiplayer session.log](Logs/Multiplayer%20session.log) - 1 KB\n", page);

        Assert.True(reports.Send("Again", "Once more.", string.Empty, string.Empty, BugReports.AttachScreenshot));
        AwaitEnd(reports);
        var (_, again) = Parse(relay.Requests[1].Body);
        Assert.Equal(["report.md"], again.Keys);
        Assert.Contains("## Screenshot\nNo screenshot attached.\n\n## Files\nLogs not attached.\n", ReportFilesTests.Unpack(again["report.md"]));
    }

    /// <summary>
    /// Asserts that a report with the logs tells in a public fact where the newest error of the
    /// session's errors.txt was raised, and one without the logs does not.
    /// </summary>
    [Fact]
    public void Send_WithLogsAndAnError_TellsWhereTheLastErrorWasRaised()
    {
        using var relay = new ReportRelay();
        var reports = NewReports(relay);
        var errors = Path.Combine(_game, "errors.txt");
        File.WriteAllText(errors, "*Error - v3.06.00 - 2026-10-11 12:05:00 (Sunday)\nException : NameError\nundefined method\ntrace:\n[\"(eval):807:in `auto_battle_actions'\"]\n");
        File.SetLastWriteTimeUtc(errors, Started.AddMinutes(5));

        Assert.True(reports.Send("Battle stops", "It stops.", "World\tRaid\n", string.Empty, BugReports.AttachLogs));
        AwaitEnd(reports);
        Assert.True(reports.Send("Battle stops", "It stops.", "World\tRaid\n", string.Empty, 0));
        AwaitEnd(reports);

        var facts = relay.Requests.Select(request => Parse(request.Body).Header.GetProperty("facts").EnumerateArray().Select(fact => $"{fact[0].GetString()}: {fact[1].GetString()}").ToList()).ToList();
        Assert.Equal(["Mod: 0.6.3", "World: Raid", "Last error: raised in a Patch folder script, such as another mod"], facts[0]);
        Assert.Equal(["Mod: 0.6.3", "World: Raid"], facts[1]);
    }

    /// <summary>
    /// Asserts that a report without the screenshot flag sends no screenshot and still forgets the pending one.
    /// </summary>
    [Fact]
    public void Send_WithoutTheScreenshotFlag_ForgetsTheScreenshot()
    {
        using var relay = new ReportRelay();
        var reports = NewReports(relay);
        reports.Snap(new byte[4], 1, 1);

        Assert.True(reports.Send("Title", "Text", string.Empty, string.Empty, 0));
        AwaitEnd(reports);
        Assert.True(reports.Send("Title", "Text", string.Empty, string.Empty, BugReports.AttachScreenshot));
        AwaitEnd(reports);

        Assert.All(relay.Requests, request => Assert.Equal(["report.md"], Parse(request.Body).Files.Keys));
    }

    /// <summary>
    /// Asserts that a screenshot dropped is not sent.
    /// </summary>
    [Fact]
    public void DropSnap_LeavesTheScreenshotOut()
    {
        using var relay = new ReportRelay();
        var reports = NewReports(relay);
        reports.Snap(new byte[4], 1, 1);
        reports.DropSnap();

        Assert.True(reports.Send("Title", "Text", string.Empty, string.Empty, BugReports.AttachScreenshot));
        AwaitEnd(reports);

        Assert.Equal(["report.md"], Parse(Assert.Single(relay.Requests).Body).Files.Keys);
    }

    /// <summary>
    /// Asserts that a size outside the limits, or pixels that do not match it, are not kept.
    /// </summary>
    [Fact]
    public void Snap_RefusesSizesOutsideTheLimits()
    {
        var reports = new BugReports();

        Assert.False(reports.Snap(new byte[4], 0, 1));
        Assert.False(reports.Snap(new byte[4], 1, 4097));
        Assert.False(reports.Snap(new byte[3], 1, 1));
        Assert.False(reports.Snap(default, 1, 1));
        Assert.True(BugReports.IsScreenSize(4096, 4096));
        Assert.False(BugReports.IsScreenSize(4097, 1));
    }

    /// <summary>
    /// Asserts that a title or text outside the relay's limits, or a missing player, refuses the report and keeps the screenshot for the next try.
    /// </summary>
    [Fact]
    public void Send_RefusesWhatTheRelayWouldRefuse()
    {
        using var relay = new ReportRelay();
        var reports = NewReports(relay);
        var nobody = new BugReports { RelayAddress = _ => relay.Address, Playing = () => null };
        reports.Snap(new byte[4], 1, 1);

        Assert.False(reports.Send("   ", "Text", string.Empty, string.Empty, 1));
        Assert.False(reports.Send(new string('t', 101), "Text", string.Empty, string.Empty, 1));
        Assert.False(reports.Send("Two\nlines", "Text", string.Empty, string.Empty, 1));
        Assert.False(reports.Send("Title", " \n ", string.Empty, string.Empty, 1));
        Assert.False(reports.Send("Title", new string('x', 4001), string.Empty, string.Empty, 1));
        Assert.False(nobody.Send("Title", "Text", string.Empty, string.Empty, 1));
        Assert.Equal("idle", reports.Describe());
        Assert.Empty(relay.Requests);

        Assert.True(reports.Send(new string('t', 100), new string('x', 4000), string.Empty, string.Empty, 1));
        AwaitEnd(reports);
        Assert.Equal(["report.md", "screenshot.png"], Parse(Assert.Single(relay.Requests).Body).Files.Keys);
    }

    /// <summary>
    /// Asserts that a second report is refused while the first is sent, which reads as sending until the relay answers.
    /// </summary>
    [Fact]
    public void Send_WhileSending_IsRefused()
    {
        using var relay = new ReportRelay();
        relay.Release.Reset();
        var reports = NewReports(relay);

        Assert.True(reports.Send("Title", "Text", string.Empty, string.Empty, 0));
        Assert.Equal("sending", reports.Describe());
        Assert.False(reports.Send("Title", "Text", string.Empty, string.Empty, 0));

        relay.Release.Set();
        Assert.StartsWith("sent\t", AwaitEnd(reports), StringComparison.Ordinal);
        Assert.True(reports.Send("Title", "Text", string.Empty, string.Empty, 0));
        AwaitEnd(reports);
    }

    /// <summary>
    /// Asserts that a refusal reads as failed with the relay's code, or the status where it names none, and its reason.
    /// </summary>
    [Fact]
    public void Send_Refused_EndsFailedWithTheCode()
    {
        using var relay = new ReportRelay { Status = 429, Answer = """{"error": "Too many reports.", "code": "rate"}""" };
        var reports = NewReports(relay);

        reports.Send("Title", "Text", string.Empty, string.Empty, 0);
        Assert.Equal("failed\trate\tToo many reports.", AwaitEnd(reports));

        relay.Status = 500;
        relay.Answer = "no json";
        reports.Send("Title", "Text", string.Empty, string.Empty, 0);
        Assert.Equal("failed\thttp500\tHTTP 500", AwaitEnd(reports));
    }

    /// <summary>
    /// Asserts that a relay that cannot be reached reads as failed and unreachable.
    /// </summary>
    [Fact]
    public void Send_RelayUnreachable_EndsFailedUnreachable()
    {
        Uri address;

        using (var relay = new ReportRelay())
        {
            address = relay.Address;
        }

        var reports = new BugReports
        {
            RelayAddress = _ => address,
            Playing = () => (WorldDirectoryTests.CreatorKey, "<Player>"),
            FlushLog = () => { },
        };

        reports.Send("Title", "Text", string.Empty, string.Empty, 0);
        Assert.StartsWith("failed\tunreachable\t", AwaitEnd(reports), StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts how failures read: the relay's code, the status, unreachable or error, the reason on one line without tabs.
    /// </summary>
    [Fact]
    public void FailureOf_NamesTheCode()
    {
        Assert.Equal("failed\toff\tbug reports are off", BugReports.FailureOf(new DirectoryException(HttpStatusCode.ServiceUnavailable, "bug reports are off", "off")));
        Assert.Equal("failed\thttp413\ttoo large", BugReports.FailureOf(new DirectoryException(HttpStatusCode.RequestEntityTooLarge, "too large")));
        Assert.Equal("failed\tunreachable\tno host", BugReports.FailureOf(new DirectoryException(null, "no host")));
        Assert.Equal("failed\terror\tdisk   full", BugReports.FailureOf(new IOException("disk\t\r\nfull")));
    }

    /// <summary>
    /// Asserts that the facts are cut to the relay's limits: 12 at most, labels of 32, values of 120, lines without a label left out.
    /// </summary>
    [Fact]
    public void FactsOf_CutsToTheRelaysLimits()
    {
        var lines = string.Join('\n', Enumerable.Range(1, 14).Select(number => $"Fact {number}\tvalue {number}"));
        var facts = BugReports.FactsOf($"\tno label\r\n\r\n{new string('l', 40)}\t{new string('v', 130)}\nNo value\n{lines}");

        Assert.Equal(12, facts.Count);
        Assert.Equal(new ReportFact(new string('l', 32), new string('v', 120)), facts[0]);
        Assert.Equal(new ReportFact("No value", string.Empty), facts[1]);
        Assert.Equal(new ReportFact("Fact 10", "value 10"), facts[11]);
    }

    /// <summary>
    /// Asserts that the mod's version leads the public facts, in place of one the game named, and that they stay at 12.
    /// </summary>
    [Fact]
    public void PublicFacts_PutTheModsVersionFirst()
    {
        var lines = string.Join('\n', Enumerable.Range(1, 12).Select(number => $"Fact {number}\tvalue {number}"));
        var facts = BugReports.PublicFacts("0.6.3", $"Mod\t0.0.0\n{lines}");

        Assert.Equal(12, facts.Count);
        Assert.Equal(new ReportFact("Mod", "0.6.3"), facts[0]);
        Assert.Equal(new ReportFact("Fact 11", "value 11"), facts[11]);
    }

    /// <summary>
    /// Asserts that a value is never cut between the halves of a character.
    /// </summary>
    [Fact]
    public void FactsOf_NeverCutsACharacterInHalf()
    {
        var value = new string('v', 119) + "😀";

        Assert.Equal(new string('v', 119), BugReports.FactsOf($"Label\t{value}")[0].Value);
    }

    /// <summary>
    /// Asserts that the version sent is the build's without its commit, as the relay takes it.
    /// </summary>
    [Fact]
    public void VersionOf_DropsTheCommit()
    {
        Assert.Equal("0.6.3", BugReports.VersionOf("0.6.3+0123abcd"));
        Assert.Equal("0.0.0-dev", BugReports.VersionOf("0.0.0-dev+0123abcd"));
        Assert.Equal("unknown", BugReports.VersionOf(string.Empty));
        Assert.Equal(32, BugReports.VersionOf(new string('1', 40)).Length);
    }

    /// <summary>
    /// Makes bug reports that send to the report relay as a set player, from the test's game folder.
    /// </summary>
    /// <param name="relay">The relay.</param>
    /// <returns>The bug reports.</returns>
    private BugReports NewReports(ReportRelay relay) => new()
    {
        RelayAddress = _ => relay.Address,
        Playing = () => (WorldDirectoryTests.CreatorKey, "<Player>"),
        GameFolder = () => _game,
        SessionStart = () => Started,
        FlushLog = () => { },
        Version = "0.6.3+0123abcd",
        DevelopmentBuild = false,
    };

    /// <summary>
    /// Waits until a report ended.
    /// </summary>
    /// <param name="reports">The bug reports.</param>
    /// <returns>The state it ended in.</returns>
    private static string AwaitEnd(BugReports reports)
    {
        string state = string.Empty;
        Assert.True(SpinWait.SpinUntil(() => (state = reports.Describe()) is not ("sending" or "idle"), Patience), "the report did not end");
        return state;
    }

    /// <summary>
    /// Reads a report's body as the relay does.
    /// </summary>
    /// <param name="body">The body.</param>
    /// <returns>The header, and each file by name in the body's order, base64 decoded.</returns>
    private static (JsonElement Header, Dictionary<string, ReportFile> Files) Parse(byte[] body)
    {
        var text = Encoding.UTF8.GetString(body);
        var lineBreak = text.IndexOf('\n');
        var header = JsonDocument.Parse(text[..lineBreak]).RootElement;
        var files = new Dictionary<string, ReportFile>();
        var at = lineBreak + 1;

        foreach (var file in header.GetProperty("files").EnumerateArray())
        {
            var length = file.GetProperty("length").GetInt32();
            var name = file.GetProperty("name").GetString()!;
            files.Add(name, new ReportFile(name, Convert.FromBase64String(text.Substring(at, length)), file.GetProperty("gzip").GetBoolean()));
            at += length;
        }

        Assert.Equal(text.Length, at);
        return (header, files);
    }
}
