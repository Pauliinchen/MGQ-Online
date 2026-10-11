//----------------------------------------------------------------
//  DirectoryClientReportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.Json;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Reports;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the relay's bug report route as the client uses it: the header line, the body's layout,
/// and the answers, against a report relay inside this process.
/// </summary>
public sealed class DirectoryClientReportsTests
{
    /// <summary>
    /// The report the tests send.
    /// </summary>
    private static readonly BugReport Report = new(
        "Formation stays shut",
        "After the meeting \"nothing\" works.\nアリス stays.",
        "0.6.3",
        [new ReportFact("Mod", "0.6.3"), new ReportFact("World", "Raid")]);

    /// <summary>
    /// Asserts that the header is one line of JSON with the title, text, version, facts as pairs and the files with their lengths and whether each is gzipped, letters beyond ASCII as they are.
    /// </summary>
    [Fact]
    public void ReportHeader_WritesOneLineOfJson()
    {
        var header = DirectoryClient.ReportHeader(Report, [("report.md", 12, true), ("screenshot.png", 8, false)]);
        var text = Encoding.UTF8.GetString(header);

        Assert.DoesNotContain('\n', text);
        Assert.Contains("アリス", text);

        using var document = JsonDocument.Parse(header);
        var root = document.RootElement;
        Assert.Equal(Report.Title, root.GetProperty("title").GetString());
        Assert.Equal(Report.Text, root.GetProperty("text").GetString());
        Assert.Equal("0.6.3", root.GetProperty("version").GetString());
        Assert.Equal([["Mod", "0.6.3"], ["World", "Raid"]], root.GetProperty("facts").EnumerateArray().Select(fact => fact.EnumerateArray().Select(part => part.GetString()!).ToArray()).ToArray());
        Assert.Equal([("report.md", 12, true), ("screenshot.png", 8, false)], root.GetProperty("files").EnumerateArray().Select(file => (file.GetProperty("name").GetString()!, file.GetProperty("length").GetInt32(), file.GetProperty("gzip").GetBoolean())).ToArray());
    }

    /// <summary>
    /// Asserts that the body is the header, a line break, then each file's base64 in order with nothing between them, of the lengths the header names.
    /// </summary>
    [Fact]
    public void ReportBody_PutsTheBase64OfEachFileBehindTheHeader()
    {
        ReportFile[] files = [new("report.md", [1, 2, 3, 4], true), new("screenshot.png", [5, 6, 7, 8, 9, 10])];

        var bytes = DirectoryClient.ReportBody(Report, files);
        var body = Encoding.UTF8.GetString(bytes);
        var lineBreak = body.IndexOf('\n');
        using var header = JsonDocument.Parse(body[..lineBreak]);
        var lengths = header.RootElement.GetProperty("files").EnumerateArray().Select(file => file.GetProperty("length").GetInt32()).ToArray();

        Assert.Equal("AQIDBA==BQYHCAkK", body[(lineBreak + 1)..]);
        Assert.Equal([8, 8], lengths);
        Assert.All(lengths, length => Assert.Equal(0, length % 4));
        Assert.Equal(bytes.Length, DirectoryClient.ReportBodyLength(Report, files));
    }

    /// <summary>
    /// Asserts that a report goes to /v1/reports as plain UTF-8 text with the player's key and the features header, and the issue the relay opened is read.
    /// </summary>
    [Fact]
    public void SendReport_PostsTheBodyAndReadsTheIssue()
    {
        using var relay = new ReportRelay();
        ReportFile[] files = [new("report.md", [1, 2, 3], true)];

        var answer = new DirectoryClient(relay.Address).SendReport(WorldDirectoryTests.CreatorKey, Report, files);

        Assert.Equal(new ReportAnswer(42, "https://github.com/Pauliinchen/MGQ-Online/issues/42", "2026-10-11-0123abcd"), answer);
        var request = Assert.Single(relay.Requests);
        Assert.Equal(("POST", "/v1/reports"), (request.Method, request.Path));
        Assert.Equal(WorldDirectoryTests.CreatorKey, request.Player);
        Assert.Equal(DirectoryClient.Features, request.Features);
        Assert.Equal("text/plain; charset=utf-8", request.ContentType);
        Assert.Equal(DirectoryClient.ReportBody(Report, files), request.Body);
    }

    /// <summary>
    /// Asserts that a refusal throws with the relay's status, reason and code.
    /// </summary>
    [Fact]
    public void SendReport_Refused_ThrowsWithTheRelaysCode()
    {
        using var relay = new ReportRelay { Status = 429, Answer = """{"error": "too many reports", "code": "rate"}""" };

        var refusal = Assert.Throws<DirectoryException>(() => new DirectoryClient(relay.Address).SendReport(WorldDirectoryTests.CreatorKey, Report, []));

        Assert.Equal((HttpStatusCode.TooManyRequests, "too many reports", "rate"), (refusal.Status, refusal.Message, refusal.Code));
    }
}
