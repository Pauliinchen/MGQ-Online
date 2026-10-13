//----------------------------------------------------------------
//  Exports.Reports.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of the in-game bug reports: keeping the screenshot taken when a report opened,
/// sending a report to the relay, which files it as a GitHub issue, and reading how it went.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Keeps a copy of the screen as the pending screenshot, replacing an earlier one; the PNG is encoded once a report is sent.
    /// </summary>
    /// <param name="pixels">The screen as the game keeps a bitmap, width times height times B, G, R, A, the last row first; copied at once.</param>
    /// <param name="width">The width in pixels, 1 to 4096.</param>
    /// <param name="height">The height in pixels, 1 to 4096.</param>
    /// <returns>1 when kept, 0 for a size outside the limits, no pixels, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_report_snap", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReportSnap(byte* pixels, int width, int height)
    {
        try
        {
            var screen = pixels != null && BugReports.IsScreenSize(width, height) ? new ReadOnlySpan<byte>(pixels, width * height * Png.SourcePixelBytes) : default;
            return BugReports.Current.Snap(screen, width, height) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_report_snap failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Forgets the pending screenshot.
    /// </summary>
    /// <returns>1, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_report_drop_snap", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReportDropSnap()
    {
        try
        {
            BugReports.Current.DropSnap();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_report_drop_snap failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts sending a bug report on a thread of the DLL's own; the pending screenshot is forgotten
    /// once it started, attached or not. Returns at once; the outcome follows in <c>mp_report_state</c>.
    /// </summary>
    /// <param name="title">The issue's title, 1 to 100 characters on one line, UTF-8 and null-terminated.</param>
    /// <param name="text">What happened, 1 to 4000 characters, UTF-8 and null-terminated.</param>
    /// <param name="facts">The public facts, lines of <c>label\tvalue</c> joined by line breaks, UTF-8 and null-terminated.</param>
    /// <param name="details">The private details for <c>report.md</c>, lines of <c>label\tvalue</c> joined by line breaks, UTF-8 and null-terminated.</param>
    /// <param name="flags">Bit 0 attaches the pending screenshot, bit 1 the logs.</param>
    /// <returns>1 when started, 0 while a report is sent, without a player or relay, for a title or text outside the relay's limits, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_report_send", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReportSend(byte* title, byte* text, byte* facts, byte* details, int flags)
    {
        try
        {
            return BugReports.Current.Send(Text(title), Text(text), Text(facts), Text(details), flags) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_report_send failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the last bug report went, see <see cref="BugReports.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The state's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_report_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReportState(byte* buffer, int size)
    {
        try
        {
            return Copy(BugReports.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_report_state failed: {ex}");
            return 0;
        }
    }
}
