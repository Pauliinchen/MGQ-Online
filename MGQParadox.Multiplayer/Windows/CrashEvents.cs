//----------------------------------------------------------------
//  CrashEvents.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// The crashes of the game Windows recorded in its Application event log since the previous game
/// session started, which the log names at the next start.
/// </summary>
/// <remarks>
/// A crash in native code ends the game before any script or the DLL can log it.
/// </remarks>
internal static unsafe partial class CrashEvents
{
    /// <summary>
    /// The file, relative to the game's folder, that keeps when the previous game session started.
    /// </summary>
    /// <remarks>
    /// Not a <c>.log</c> or <c>.txt</c> file, so bug reports do not take it for a log.
    /// </remarks>
    internal const string MarkFile = @"Logs\Multiplayer crash check.dat";

    /// <summary>
    /// Most crashes one start logs, the newest first.
    /// </summary>
    internal const int MaxLogged = 3;

    /// <summary>
    /// Most events one start reads, of every program, which keeps a log full of other crashes quick.
    /// </summary>
    private const int MaxRead = 64;

    /// <summary>
    /// The event log the crashes are in.
    /// </summary>
    private const string Channel = "Application";

    /// <summary>
    /// The source of Windows' event of a program that crashed.
    /// </summary>
    private const string ApplicationError = "Application Error";

    /// <summary>
    /// The id of Windows' event of a program that crashed.
    /// </summary>
    private const int ApplicationErrorId = 1000;

    /// <summary>
    /// The source of the event of .NET code that ended its program.
    /// </summary>
    private const string DotNetRuntime = ".NET Runtime";

    /// <summary>
    /// The id of the event of .NET code that ended its program.
    /// </summary>
    private const int DotNetCrashId = 1026;

    /// <summary>
    /// What the first line of a .NET crash's text starts with, before the program's file name.
    /// </summary>
    private const string DotNetApplicationLabel = "Application: ";

    /// <summary>
    /// What the line of a .NET crash's text that names the exception starts with.
    /// </summary>
    private const string DotNetExceptionLabel = "Exception Info: ";

    /// <summary>
    /// The query's path is the name of an event log.
    /// </summary>
    private const uint QueryChannelPath = 0x1;

    /// <summary>
    /// The query reads the newest events first.
    /// </summary>
    private const uint QueryReverseDirection = 0x200;

    /// <summary>
    /// Renders an event as its XML.
    /// </summary>
    private const uint RenderEventXml = 1;

    /// <summary>
    /// The Windows error of a buffer too small for what it should receive.
    /// </summary>
    private const int InsufficientBuffer = 122;

    /// <summary>
    /// How long reading the next events may take, in milliseconds.
    /// </summary>
    private const uint NextTimeout = 1000;

    /// <summary>
    /// The format of the time in the mark file and in the query, in UTC.
    /// </summary>
    private const string UtcFormat = "yyyy-MM-dd'T'HH:mm:ss.fff'Z'";

    /// <summary>
    /// How far back the first check looks, before a game session left its start in the mark file.
    /// </summary>
    private static readonly TimeSpan FirstLookBack = TimeSpan.FromDays(7);

    /// <summary>
    /// A named value of an event: <c>&lt;Data Name='ModuleName'&gt;KERNELBASE.dll&lt;/Data&gt;</c>.
    /// </summary>
    private static readonly Regex NamedData = new(@"<Data Name=['""](?<name>[^'""]+)['""]>(?<value>[^<]*)</Data>", RegexOptions.CultureInvariant);

    /// <summary>
    /// A value of an event without a name, as older Windows writes them and as .NET writes its text.
    /// </summary>
    private static readonly Regex PlainData = new(@"<Data>(?<value>[^<]*)</Data>", RegexOptions.CultureInvariant);

    /// <summary>
    /// The event's source.
    /// </summary>
    private static readonly Regex Provider = new(@"<Provider Name=['""](?<value>[^'""]+)['""]", RegexOptions.CultureInvariant);

    /// <summary>
    /// The event's id.
    /// </summary>
    private static readonly Regex EventId = new(@"<EventID[^>]*>(?<value>\d+)</EventID>", RegexOptions.CultureInvariant);

    /// <summary>
    /// When the event was recorded, in UTC.
    /// </summary>
    private static readonly Regex TimeCreated = new(@"<TimeCreated SystemTime=['""](?<value>[^'""]+)['""]", RegexOptions.CultureInvariant);

    /// <summary>
    /// Where Windows' event of a crash keeps its values when they have no names, by name.
    /// </summary>
    private static readonly Dictionary<string, int> ApplicationErrorOrder = new()
    {
        ["AppName"] = 0,
        ["ModuleName"] = 3,
        ["ModuleVersion"] = 4,
        ["ExceptionCode"] = 6,
        ["FaultingOffset"] = 7,
    };

    /// <summary>
    /// Whether this game session checked already, 1 once it did.
    /// </summary>
    private static int _checked;

    /// <summary>
    /// Logs, on a thread of its own, the crashes of the game Windows recorded since the previous game
    /// session started, once per game session and never under Wine, which keeps no such log.
    /// </summary>
    public static void LogOnce()
    {
        if (Interlocked.Exchange(ref _checked, 1) == 1 || NativeMethods.WineVersion() != null)
        {
            return;
        }

        Threads.Start("CrashEvents", Check);
    }

    /// <summary>
    /// Reads a crash of a program from an event as Windows renders it.
    /// </summary>
    /// <param name="xml">The event's XML.</param>
    /// <param name="program">The file name of the program whose crashes count, such as <c>Game.exe</c>.</param>
    /// <returns>The crash, <see langword="null"/> for any other event or another program's crash.</returns>
    internal static CrashEvent? Parse(string xml, string program)
    {
        var source = Provider.Match(xml).Groups["value"].Value;
        var id = EventId.Match(xml).Groups["value"].Value;

        if (!DateTime.TryParse(TimeCreated.Match(xml).Groups["value"].Value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var time))
        {
            return null;
        }

        if (source == ApplicationError && id == ApplicationErrorId.ToString(CultureInfo.InvariantCulture))
        {
            var values = ApplicationErrorValues(xml);
            return string.Equals(values["AppName"], program, StringComparison.OrdinalIgnoreCase)
                ? new CrashEvent(time.ToUniversalTime(), values["ModuleName"], values["ModuleVersion"], values["ExceptionCode"], values["FaultingOffset"], null)
                : null;
        }

        if (source == DotNetRuntime && id == DotNetCrashId.ToString(CultureInfo.InvariantCulture))
        {
            var lines = DataValues(PlainData, xml).FirstOrDefault()?.Split('\n').Select(line => line.TrimEnd('\r')).ToList() ?? [];
            var application = lines.FirstOrDefault(line => line.StartsWith(DotNetApplicationLabel, StringComparison.Ordinal))?[DotNetApplicationLabel.Length..];
            var exception = lines.FirstOrDefault(line => line.StartsWith(DotNetExceptionLabel, StringComparison.Ordinal))?[DotNetExceptionLabel.Length..];
            return string.Equals(application?.Trim(), program, StringComparison.OrdinalIgnoreCase)
                ? new CrashEvent(time.ToUniversalTime(), null, null, null, null, exception ?? "an exception the event does not name")
                : null;
        }

        return null;
    }

    /// <summary>
    /// Describes a crash in one line of the log.
    /// </summary>
    /// <param name="crash">The crash.</param>
    /// <returns>The line, with the time in local time.</returns>
    internal static string Describe(CrashEvent crash)
    {
        var time = crash.Time.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
        return crash.DotNetException is { } exception
            ? $"Windows recorded a crash of the game at {time} in .NET code: {exception}"
            : $"Windows recorded a crash of the game at {time}: faulting module {crash.Module} {crash.ModuleVersion}, exception code 0x{crash.ExceptionCode}, offset 0x{crash.Offset}";
    }

    /// <summary>
    /// Reads when the previous game session started from the mark file.
    /// </summary>
    /// <param name="path">The mark file.</param>
    /// <returns>The time in UTC, <see langword="null"/> when the file is missing or unreadable.</returns>
    internal static DateTime? ReadMark(string path) =>
        File.Exists(path) && DateTime.TryParseExact(File.ReadAllText(path).Trim(), UtcFormat, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var mark)
            ? mark
            : null;

    /// <summary>
    /// Logs the crashes of the game since the previous game session started and leaves this one's
    /// start in the mark file for the next.
    /// </summary>
    private static void Check()
    {
        try
        {
            var start = DateTime.UtcNow;
            var markPath = ModFolder.GamePathOf(MarkFile);
            var since = ReadMark(markPath) ?? start - FirstLookBack;
            var program = Path.GetFileName(Environment.ProcessPath) ?? string.Empty;
            var crashes = RecentEvents(since).Select(xml => Parse(xml, program)).OfType<CrashEvent>().Take(MaxLogged).ToList();
            var sinceText = since.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);

            Log.Write(crashes.Count == 0 ? $"Windows recorded no crash of the game since {sinceText}" : $"Windows recorded {crashes.Count} crash(es) of the game since {sinceText}, the newest first:");
            crashes.ForEach(crash => Log.Write(Describe(crash)));

            Directory.CreateDirectory(Path.GetDirectoryName(markPath)!);
            File.WriteAllText(markPath, start.ToString(UtcFormat, CultureInfo.InvariantCulture));
        }
        catch (Exception ex)
        {
            Log.Write($"reading the crashes Windows recorded failed: {ex.GetType().Name}: {ex.Message}");
        }
    }

    /// <summary>
    /// Reads the newest crash events of every program recorded at or after a moment.
    /// </summary>
    /// <param name="since">The moment, in UTC.</param>
    /// <returns>The events' XML, the newest first, at most <see cref="MaxRead"/>; none when the event log cannot be read.</returns>
    private static List<string> RecentEvents(DateTime since)
    {
        var events = new List<string>();
        var query = $"*[System[Provider[@Name='{ApplicationError}' or @Name='{DotNetRuntime}'] and (EventID={ApplicationErrorId} or EventID={DotNetCrashId}) " +
            $"and TimeCreated[@SystemTime>='{since.ToString(UtcFormat, CultureInfo.InvariantCulture)}']]]";
        var results = EvtQuery(0, Channel, query, QueryChannelPath | QueryReverseDirection);

        if (results == 0)
        {
            return events;
        }

        try
        {
            var handles = new nint[MaxRead];
            var read = 0;

            fixed (nint* batch = handles)
            {
                while (read < MaxRead && EvtNext(results, (uint)(MaxRead - read), batch, NextTimeout, 0, out var returned) && returned > 0)
                {
                    read += (int)returned;

                    for (var i = 0; i < returned; i++)
                    {
                        try
                        {
                            if (Render(handles[i]) is { } xml)
                            {
                                events.Add(xml);
                            }
                        }
                        finally
                        {
                            EvtClose(handles[i]);
                        }
                    }
                }
            }
        }
        finally
        {
            EvtClose(results);
        }

        return events;
    }

    /// <summary>
    /// Renders an event as its XML.
    /// </summary>
    /// <param name="handle">The event.</param>
    /// <returns>The XML, <see langword="null"/> when it could not be rendered.</returns>
    private static string? Render(nint handle)
    {
        EvtRender(0, handle, RenderEventXml, 0, null, out var needed, out _);

        if (Marshal.GetLastPInvokeError() != InsufficientBuffer || needed == 0)
        {
            return null;
        }

        var buffer = new char[(needed + 1) / 2];

        fixed (char* start = buffer)
        {
            return EvtRender(0, handle, RenderEventXml, needed, start, out var used, out _)
                ? new string(start, 0, (int)(used / 2)).TrimEnd('\0')
                : null;
        }
    }

    /// <summary>
    /// Reads the values of Windows' event of a crash, by name, whether or not the event names them.
    /// </summary>
    /// <param name="xml">The event's XML.</param>
    /// <returns>The values the crash needs, empty where the event has none.</returns>
    private static Dictionary<string, string> ApplicationErrorValues(string xml)
    {
        var named = NamedData.Matches(xml).ToDictionary(match => match.Groups["name"].Value, match => WebUtility.HtmlDecode(match.Groups["value"].Value));
        var plain = named.Count == 0 ? DataValues(PlainData, xml) : [];
        return ApplicationErrorOrder.ToDictionary(
            field => field.Key,
            field => named.TryGetValue(field.Key, out var value) ? value : field.Value < plain.Count ? plain[field.Value] : string.Empty);
    }

    /// <summary>
    /// Reads the values a pattern finds in an event, in their order.
    /// </summary>
    /// <param name="pattern">The pattern, whose group <c>value</c> holds the value.</param>
    /// <param name="xml">The event's XML.</param>
    /// <returns>The values, their entities decoded.</returns>
    private static List<string> DataValues(Regex pattern, string xml) =>
        pattern.Matches(xml).Select(match => WebUtility.HtmlDecode(match.Groups["value"].Value)).ToList();

    /// <summary>
    /// Queries an event log.
    /// </summary>
    /// <param name="session">The session, 0 for this computer.</param>
    /// <param name="path">The event log's name.</param>
    /// <param name="query">The XPath query.</param>
    /// <param name="flags">How to read it.</param>
    /// <returns>The results' handle, 0 when it failed.</returns>
    [LibraryImport("wevtapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint EvtQuery(nint session, string path, string query, uint flags);

    /// <summary>
    /// Takes the next events of a query's results.
    /// </summary>
    /// <param name="results">The results' handle.</param>
    /// <param name="size">How many events the array takes.</param>
    /// <param name="events">Receives the events' handles.</param>
    /// <param name="timeout">How long it may take, in milliseconds.</param>
    /// <param name="flags">Reserved, 0.</param>
    /// <param name="returned">How many events it took.</param>
    /// <returns><see langword="true"/> when it took some.</returns>
    [LibraryImport("wevtapi.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EvtNext(nint results, uint size, nint* events, uint timeout, uint flags, out uint returned);

    /// <summary>
    /// Renders an event.
    /// </summary>
    /// <param name="context">The render context, 0 for the event's XML.</param>
    /// <param name="handle">The event.</param>
    /// <param name="flags">What to render.</param>
    /// <param name="size">The buffer's size in bytes.</param>
    /// <param name="buffer">Receives the rendering, <see langword="null"/> to ask its size.</param>
    /// <param name="used">The bytes used, or needed when the buffer was too small.</param>
    /// <param name="properties">How many properties were rendered.</param>
    /// <returns><see langword="true"/> when it was rendered.</returns>
    [LibraryImport("wevtapi.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EvtRender(nint context, nint handle, uint flags, uint size, char* buffer, out uint used, out uint properties);

    /// <summary>
    /// Frees a handle of the event log functions.
    /// </summary>
    /// <param name="handle">The handle.</param>
    /// <returns><see langword="true"/> when it was freed.</returns>
    [LibraryImport("wevtapi.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EvtClose(nint handle);
}

/// <summary>
/// A crash of the game Windows recorded.
/// </summary>
/// <param name="Time">When it was recorded, in UTC.</param>
/// <param name="Module">The file of the code that crashed, for a crash Windows caught.</param>
/// <param name="ModuleVersion">That file's version.</param>
/// <param name="ExceptionCode">The exception's code in hexadecimal digits, such as <c>c0000005</c>.</param>
/// <param name="Offset">Where in the file the code crashed, in hexadecimal digits.</param>
/// <param name="DotNetException">The exception of a crash in .NET code, <see langword="null"/> for a crash Windows caught.</param>
internal sealed record CrashEvent(DateTime Time, string? Module, string? ModuleVersion, string? ExceptionCode, string? Offset, string? DotNetException);
