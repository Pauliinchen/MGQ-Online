//----------------------------------------------------------------
//  BugReportRequestTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Walks the in-game bug report from the hotkey to the player told how the sending went, as the
/// scripts drive it frame by frame.
/// </summary>
public sealed class BugReportRequestTests
{
    /// <summary>
    /// The player free on the map of a world, the notification box showing.
    /// </summary>
    private static readonly ReportScene FreeOnMap = new("Scene_Map", ReportPlace.Map, true, true, true, false);

    /// <summary>
    /// A battle in a world.
    /// </summary>
    private static readonly ReportScene InBattle = new("Scene_Battle", ReportPlace.Battle, true, false, false, false);

    /// <summary>
    /// The report's form in front.
    /// </summary>
    private static readonly ReportScene OnForm = new("Scene_MpBugReport", ReportPlace.Form, true, false, true, false);

    /// <summary>
    /// Asserts that a report asked for by hotkey on the map takes the screenshot, opens the form,
    /// sends what the form holds with the screenshot and the logs, and tells the player the issue it
    /// became once the relay filed it.
    /// </summary>
    [Fact]
    public void Hotkey_OnTheMap_SendsTheReportAndTellsTheIssue()
    {
        var host = new Host();
        var request = new BugReportRequest(host);

        bool snap = request.Request(ReportVia.Hotkey, FreeOnMap, "Ilias Village", [("World", "Haven")], [("Player", "me")]);
        bool openAfterSnap = request.Snapped(kept: true);
        bool open = request.OnMap(FreeOnMap);
        bool? withScreenshot = request.TakeOpening();
        string? refusal = request.Send("Chest stays shut", "It never opens.", screenshot: true, logs: true);
        host.Described = "sent\t42\tfiled";
        for (int frame = 0; frame < BugReportRequest.PollFrames; frame++)
        {
            request.Frame(OnForm);
        }

        Assert.Equal((true, false, true, true, null), (snap, openAfterSnap, open, withScreenshot, refusal));
        Assert.Equal(("Chest stays shut", "World\tHaven", "Player\tme", BugReports.AttachScreenshot | BugReports.AttachLogs), Assert.Single(host.Sent));
        Assert.Equal([BugReportRequest.SendingText, "Bug report sent as issue #42. Thank you!"], host.Notices);
        Assert.False(request.Sending);
    }

    /// <summary>
    /// Asserts that a report asked for in a battle tells the battle's chat that it waits, opens once
    /// the player is free on the map, and drops its screenshot when the form closes unsent.
    /// </summary>
    [Fact]
    public void Hotkey_InABattle_WaitsForTheMapAndDropsTheScreenshotOfAFormClosedUnsent()
    {
        var host = new Host();
        var request = new BugReportRequest(host);

        request.Request(ReportVia.Hotkey, InBattle, "a battle", [], []);
        bool openInBattle = request.Snapped(kept: true);
        bool openOnBusyMap = request.OnMap(FreeOnMap with { MapReady = false });
        bool open = request.OnMap(FreeOnMap);
        request.TakeOpening();
        request.Closed("the player cancelled");

        Assert.Equal((false, false, true), (openInBattle, openOnBusyMap, open));
        Assert.Equal([BugReportRequest.BattleText], host.ChatLines);
        Assert.Equal(1, host.Drops);
        Assert.False(request.Waiting);
    }

    /// <summary>
    /// What the report reaches outside itself, kept for the checks.
    /// </summary>
    private sealed class Host : IReportHost
    {
        /// <summary>
        /// Gets the notices shown.
        /// </summary>
        public List<string> Notices { get; } = [];

        /// <summary>
        /// Gets the lines added to the battle's chat.
        /// </summary>
        public List<string> ChatLines { get; } = [];

        /// <summary>
        /// Gets the reports started: title, facts, details and flags.
        /// </summary>
        public List<(string Title, string Facts, string Details, int Flags)> Sent { get; } = [];

        /// <summary>
        /// Gets how often the screenshot was dropped.
        /// </summary>
        public int Drops { get; private set; }

        /// <summary>
        /// Gets or sets how the last report's sending went, as the DLL describes it.
        /// </summary>
        public string Described { get; set; } = "sending";

        /// <inheritdoc />
        public bool Named => true;

        /// <inheritdoc />
        public void Log(string line)
        {
        }

        /// <inheritdoc />
        public void HotkeyRefused(string reason)
        {
        }

        /// <inheritdoc />
        public void Sound(string name)
        {
        }

        /// <inheritdoc />
        public void ChatLine(string text) => ChatLines.Add(text);

        /// <inheritdoc />
        public void Notice(string text, int? frames) => Notices.Add(text);

        /// <inheritdoc />
        public void DropSnap() => Drops++;

        /// <inheritdoc />
        public bool Send(string title, string text, string facts, string details, int flags)
        {
            Sent.Add((title, facts, details, flags));
            return true;
        }

        /// <inheritdoc />
        public string Describe() => Described;
    }
}
