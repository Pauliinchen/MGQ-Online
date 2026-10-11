//----------------------------------------------------------------
//  DirectoryClient.Reports.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Text;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The relay's bug report route, <c>POST /v1/reports</c>, which files a report as a GitHub issue.
/// </summary>
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// The longest header line the relay takes, in bytes.
    /// </summary>
    public const int MaxReportHeaderBytes = 16 * 1024;

    /// <summary>
    /// The name of a report's screenshot, as the relay takes it.
    /// </summary>
    public const string ScreenshotFile = "screenshot.png";

    /// <summary>
    /// The name of a report's page, the index of its files, as the relay takes it.
    /// </summary>
    public const string ReportPageFile = "report.md";

    /// <summary>
    /// Sends a bug report.
    /// </summary>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="report">What the player wrote and the public facts.</param>
    /// <param name="files">The files, in the order the body carries them.</param>
    /// <returns>The issue the relay opened.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public ReportAnswer SendReport(string playerKey, BugReport report, IReadOnlyList<ReportFile> files)
    {
        var body = ReportBody(report, files);
        var address = new UriBuilder(_worlds) { Path = "/v1/reports" }.Uri;

        using var request = new HttpRequestMessage(HttpMethod.Post, address) { Content = new ByteArrayContent(body) };
        request.Content.Headers.ContentType = new MediaTypeHeaderValue("text/plain") { CharSet = "utf-8" };
        request.Headers.Add(PlayerHeader, playerKey);

        using var response = Exchange(request, TransferHttp, $"report, {files.Count.ToString(CultureInfo.InvariantCulture)} file(s), {body.Length.ToString(CultureInfo.InvariantCulture)} bytes");

        try
        {
            using var document = JsonDocument.Parse(response.Content.ReadAsStream());
            var root = document.RootElement;
            var issue = root.TryGetProperty("issue", out var number) && number.ValueKind == JsonValueKind.Number && number.TryGetInt32(out var parsed) ? parsed : 0;
            return new ReportAnswer(issue, Text(root, "url"), Text(root, "id"));
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or IOException or HttpRequestException)
        {
            throw new DirectoryException(response.StatusCode, "The relay's answer is no JSON.");
        }
    }

    /// <summary>
    /// Builds a report's body: the header line, a line break, then each file's base64 one after the other.
    /// </summary>
    /// <param name="report">What the player wrote and the public facts.</param>
    /// <param name="files">The files, in the order the body carries them.</param>
    /// <returns>The body, UTF-8.</returns>
    internal static byte[] ReportBody(BugReport report, IReadOnlyList<ReportFile> files)
    {
        var header = ReportHeader(report, Listed(files));
        var body = new byte[header.Length + 1 + files.Sum(file => (long)file.Base64Length)];
        header.CopyTo(body, 0);
        body[header.Length] = (byte)'\n';

        var at = header.Length + 1;

        foreach (var file in files)
        {
            Base64.EncodeToUtf8(file.Data, body.AsSpan(at), out _, out var written);
            at += written;
        }

        return body;
    }

    /// <summary>
    /// Tells how long a report's body is, without building it.
    /// </summary>
    /// <param name="report">What the player wrote and the public facts.</param>
    /// <param name="files">The files, in the order the body carries them.</param>
    /// <returns>The body's length in bytes.</returns>
    internal static long ReportBodyLength(BugReport report, IReadOnlyList<ReportFile> files) =>
        ReportHeader(report, Listed(files)).Length + 1 + files.Sum(file => (long)file.Base64Length);

    /// <summary>
    /// Lists the files as the header names them.
    /// </summary>
    /// <param name="files">The files.</param>
    /// <returns>Each file's name, base64 length and whether it is gzipped.</returns>
    private static IEnumerable<(string Name, int Length, bool Gzip)> Listed(IReadOnlyList<ReportFile> files) =>
        files.Select(file => (file.Name, file.Base64Length, file.Gzip));

    /// <summary>
    /// Writes a report's header line.
    /// </summary>
    /// <param name="report">What the player wrote and the public facts.</param>
    /// <param name="files">Each file's name, base64 length and whether it is gzipped, in the order the body carries them.</param>
    /// <returns>The JSON object on one line, UTF-8.</returns>
    internal static byte[] ReportHeader(BugReport report, IEnumerable<(string Name, int Length, bool Gzip)> files) =>
        Encoding.UTF8.GetBytes(Json(writer =>
        {
            writer.WriteString("title", report.Title);
            writer.WriteString("text", report.Text);
            writer.WriteString("version", report.Version);
            writer.WriteStartArray("facts");

            foreach (var fact in report.Facts)
            {
                writer.WriteStartArray();
                writer.WriteStringValue(fact.Label);
                writer.WriteStringValue(fact.Value);
                writer.WriteEndArray();
            }

            writer.WriteEndArray();
            writer.WriteStartArray("files");

            foreach (var (name, length, gzip) in files)
            {
                writer.WriteStartObject();
                writer.WriteString("name", name);
                writer.WriteNumber("length", length);
                writer.WriteBoolean("gzip", gzip);
                writer.WriteEndObject();
            }

            writer.WriteEndArray();
        }));
}

/// <summary>
/// A label and its value, one line of a report's facts or details.
/// </summary>
/// <param name="Label">The label.</param>
/// <param name="Value">The value.</param>
internal sealed record ReportFact(string Label, string Value);

/// <summary>
/// What a bug report's header tells the relay, apart from its files.
/// </summary>
/// <param name="Title">The issue's title as the player wrote it.</param>
/// <param name="Text">What happened, as the player wrote it.</param>
/// <param name="Version">The mod's version, letters, digits, dots, plus and minus signs.</param>
/// <param name="Facts">The public facts the issue shows in a table.</param>
internal sealed record BugReport(string Title, string Text, string Version, IReadOnlyList<ReportFact> Facts);

/// <summary>
/// A file a bug report carries.
/// </summary>
/// <param name="Name">Its name: <see cref="DirectoryClient.ReportPageFile"/>, <see cref="DirectoryClient.ScreenshotFile"/>, or a text file such as <c>Logs/Multiplayer.log</c>.</param>
/// <param name="Data">Its bytes as sent, gzipped for a text file that says so.</param>
/// <param name="Gzip">Whether <paramref name="Data"/> is gzipped, which the relay unpacks.</param>
internal sealed record ReportFile(string Name, byte[] Data, bool Gzip = false)
{
    /// <summary>
    /// The length of its base64, padding included.
    /// </summary>
    public int Base64Length => Base64.GetMaxEncodedToUtf8Length(Data.Length);
}

/// <summary>
/// The issue the relay opened for a bug report.
/// </summary>
/// <param name="Issue">The issue's number, 0 when the relay did not name it.</param>
/// <param name="Url">The issue's address, empty when the relay did not name it.</param>
/// <param name="Id">The report's id, empty when the relay did not name it.</param>
internal sealed record ReportAnswer(int Issue, string Url, string Id);
