//----------------------------------------------------------------
//  BugReportRequest.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Reports;

/// <summary>
/// Where a report is asked for or waits, by the scene in front.
/// </summary>
internal enum ReportPlace
{
    /// <summary>
    /// The map.
    /// </summary>
    Map,

    /// <summary>
    /// A battle.
    /// </summary>
    Battle,

    /// <summary>
    /// A menu the form opens over at once.
    /// </summary>
    Menu,

    /// <summary>
    /// A menu the report waits in until the player is back on the map, since it cannot be left for
    /// the form and come back, such as the story's choices.
    /// </summary>
    WaitingMenu,

    /// <summary>
    /// The report's form.
    /// </summary>
    Form,

    /// <summary>
    /// The title or game over screen, which leave the game being played.
    /// </summary>
    Title,

    /// <summary>
    /// Any other scene.
    /// </summary>
    Other,
}

/// <summary>
/// How a report is asked for.
/// </summary>
internal enum ReportVia
{
    /// <summary>
    /// The bug report's hotkey.
    /// </summary>
    Hotkey,

    /// <summary>
    /// The action wheel's choice.
    /// </summary>
    Wheel,
}

/// <summary>
/// The scene in front as the report looks at it.
/// </summary>
/// <param name="Name">The scene's class name, for the log.</param>
/// <param name="Place">What kind of scene it is.</param>
/// <param name="InWorld">Whether a world is open.</param>
/// <param name="MapReady">Whether the player is free on the map and no screen of the mod lies over it.</param>
/// <param name="NoticesShown">Whether the notification box shows.</param>
/// <param name="Typing">Whether the player types into a text box.</param>
internal sealed record ReportScene(string Name, ReportPlace Place, bool InWorld, bool MapReady, bool NoticesShown, bool Typing);

/// <summary>
/// What the report reaches outside itself: the log, the hotkeys' log, the game's sounds, the chat
/// log and the notification box, the player's name, and the DLL's reports.
/// </summary>
internal interface IReportHost
{
    /// <summary>
    /// Gets a value indicating whether the player chose a name, which a report needs.
    /// </summary>
    bool Named { get; }

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line, starting with what wrote it.</param>
    void Log(string line);

    /// <summary>
    /// Logs that the hotkey asked for a report that does not open, as the hotkeys log it.
    /// </summary>
    /// <param name="reason">Why.</param>
    void HotkeyRefused(string reason);

    /// <summary>
    /// Plays one of the game's sounds.
    /// </summary>
    /// <param name="name">Its name after <c>Sound.play_</c>, such as "ok".</param>
    void Sound(string name);

    /// <summary>
    /// Adds a line of the game's own to the battle's chat log.
    /// </summary>
    /// <param name="text">The line.</param>
    void ChatLine(string text);

    /// <summary>
    /// Shows a message in the notification box.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <param name="frames">How long it shows, <see langword="null"/> for the box's own time.</param>
    void Notice(string text, int? frames);

    /// <summary>
    /// Forgets the screenshot taken for the report.
    /// </summary>
    void DropSnap();

    /// <summary>
    /// Starts sending a report on the DLL's own thread.
    /// </summary>
    /// <param name="title">Its title.</param>
    /// <param name="text">What happened.</param>
    /// <param name="facts">The public facts, a line per label and value split by a tab.</param>
    /// <param name="details">The private details, the same way.</param>
    /// <param name="flags"><see cref="BugReports.AttachScreenshot"/> and <see cref="BugReports.AttachLogs"/>.</param>
    /// <returns>Whether it started.</returns>
    bool Send(string title, string text, string facts, string details, int flags);

    /// <summary>
    /// Tells how the last report's sending went, see <see cref="BugReports.Describe"/>.
    /// </summary>
    /// <returns>The kind, then the value and the reason, split by tabs.</returns>
    string Describe();
}

/// <summary>
/// The in-game bug report's request: asked for by the hotkey or the wheel, it takes the screenshot
/// at once or once the wheel faded out, opens the form at once in a menu or waits until the player
/// is free on the map, is forgotten once the game leaves for the title, sends the report the form
/// filled and follows the sending, telling the player its outcome in the notification box once it shows.
/// </summary>
/// <remarks>
/// The screenshot and the form are the scripts': an answer that says to snap or to open is acted on
/// at once, before the next step, since the report's state follows them.
/// </remarks>
internal sealed partial class BugReportRequest
{
    /// <summary>
    /// Frames between the wheel's choice and its screenshot: the wheel's fade out of 12 frames and
    /// one more, so the wheel is not in it.
    /// </summary>
    public const int WheelFrames = 13;

    /// <summary>
    /// Frames between two looks at how the sending stands.
    /// </summary>
    public const int PollFrames = 30;

    /// <summary>
    /// Facts a report carries at most, as the relay takes them.
    /// </summary>
    public const int MaxFacts = 12;

    /// <summary>
    /// Characters of a fact's or a detail's label at most.
    /// </summary>
    public const int MaxLabelChars = 32;

    /// <summary>
    /// Characters of a fact's value at most.
    /// </summary>
    public const int MaxValueChars = 120;

    /// <summary>
    /// Characters of a detail's value at most.
    /// </summary>
    public const int MaxDetailChars = 1000;

    /// <summary>
    /// Frames the notification box shows the sending and its outcome.
    /// </summary>
    public const int NoticeFrames = 600;

    /// <summary>
    /// What the notification box says while the report is sent.
    /// </summary>
    public const string SendingText = "Sending the bug report . . .";

    /// <summary>
    /// What the player is told when the report waits for a battle to end.
    /// </summary>
    public const string BattleText = "The bug report opens after the battle.";

    /// <summary>
    /// What the player is told when the report waits for the player to be free on the map.
    /// </summary>
    public const string BusyText = "The bug report opens once you are free on the map.";

    /// <summary>
    /// Why a report does not open while the last one is still being sent.
    /// </summary>
    public const string SendingRefusal = "The last bug report is still being sent.";

    /// <summary>
    /// Why a report does not open while another waits to open.
    /// </summary>
    public const string WaitingRefusal = "A bug report waits to open already.";

    /// <summary>
    /// Why a report does not open or is not sent without the player's name.
    /// </summary>
    public const string NoNameRefusal = "Bug reports need your name: pick Multiplayer on the title screen to choose one.";

    /// <summary>
    /// Why the report is not sent once the DLL did not start sending it.
    /// </summary>
    public const string NotStartedRefusal = "The bug report could not be sent. Try again later.";

    /// <summary>
    /// What starts the report's lines in the log.
    /// </summary>
    private const string LogTag = "bug report: ";

    /// <summary>
    /// The friendly words for a failure, by the relay's code.
    /// </summary>
    private static readonly Dictionary<string, string> FriendlyReasons = new(StringComparer.Ordinal)
    {
        ["rate"] = "you sent several reports in a short time. Try again in an hour.",
        ["off"] = "bug reports are off right now.",
        ["busy"] = "too many reports at once. Try again in a minute.",
    };

    /// <summary>
    /// What a failure says for any other code.
    /// </summary>
    private const string OtherFailure = "try again later.";

    /// <summary>
    /// What the report reaches outside itself.
    /// </summary>
    private readonly IReportHost host;

    /// <summary>
    /// The report asked for that waits to open, <see langword="null"/> while none does.
    /// </summary>
    private Report? pending;

    /// <summary>
    /// The report whose form opens, until the form takes it.
    /// </summary>
    private Report? opening;

    /// <summary>
    /// The report the form holds.
    /// </summary>
    private Report? form;

    /// <summary>
    /// Frames left until the screenshot the wheel asked for, <see langword="null"/> while none waits.
    /// </summary>
    private int? snapIn;

    /// <summary>
    /// How the report asked for continues once the screenshot was taken, <see langword="null"/> for
    /// a screenshot the wheel asked for, which leaves the opening to the map.
    /// </summary>
    private ReportScene? afterSnap;

    /// <summary>
    /// Frames since the last look at how the sending stands.
    /// </summary>
    private int pollFrames;

    /// <summary>
    /// The sending's outcome kept for the notification box, <see langword="null"/> while none waits.
    /// </summary>
    private string? outcome;

    /// <summary>
    /// What the player is told once the notification box shows, <see langword="null"/> while nothing waits.
    /// </summary>
    private string? told;

    /// <summary>
    /// Initializes a request nobody asked for yet.
    /// </summary>
    /// <param name="host">What the report reaches outside itself.</param>
    public BugReportRequest(IReportHost host) => this.host = host ?? throw new ArgumentNullException(nameof(host));

    /// <summary>
    /// Gets a value indicating whether a report is being sent.
    /// </summary>
    public bool Sending { get; private set; }

    /// <summary>
    /// Gets a value indicating whether a report waits to open.
    /// </summary>
    public bool Waiting => pending is not null;

    /// <summary>
    /// Tells why the wheel's choice is refused.
    /// </summary>
    /// <returns>The refusal, <see langword="null"/> while it may be taken.</returns>
    public string? WheelRefusal() => Sending ? SendingRefusal : pending is not null ? WaitingRefusal : host.Named ? null : NoNameRefusal;

    /// <summary>
    /// Asks for a report: refused where it cannot open; otherwise the screenshot follows, at once or
    /// once the wheel faded out, and the form opens at once in a menu or waits until the player is
    /// free on the map.
    /// </summary>
    /// <param name="via">How it was asked for.</param>
    /// <param name="scene">The scene in front.</param>
    /// <param name="where">Where the player is, for the log.</param>
    /// <param name="facts">The report's public facts, each a label and its value.</param>
    /// <param name="details">The report's private details, each a label and its value.</param>
    /// <returns>Whether the scripts take the screenshot now.</returns>
    public bool Request(ReportVia via, ReportScene scene, string where, IReadOnlyList<(string Label, string Value)> facts, IReadOnlyList<(string Label, string Value)> details)
    {
        ArgumentNullException.ThrowIfNull(scene);
        if (RefusalAt(scene) is { } refusal)
        {
            Refuse(via, refusal, scene);
            return false;
        }

        pending = new Report(facts, details);
        Log($"asked for a report by {(via == ReportVia.Hotkey ? "hotkey" : "wheel")} in {where}");
        if (via == ReportVia.Wheel)
        {
            // The wheel played its own sound as the choice was taken.
            snapIn = WheelFrames;
            return false;
        }

        host.Sound("ok");
        afterSnap = scene;
        return true;
    }

    /// <summary>
    /// Takes the screenshot the scripts took for the waiting report, and goes on as the request
    /// that asked for it at once does: the form opens in a menu, else the player is told when it does.
    /// </summary>
    /// <param name="kept">Whether the DLL kept the screenshot.</param>
    /// <returns>Whether the scripts open the form now.</returns>
    public bool Snapped(bool kept)
    {
        if (pending is null)
        {
            return false;
        }

        pending.Snapped = kept;
        pending.Ready = true;
        ReportScene? scene = afterSnap;
        afterSnap = null;
        switch (scene?.Place)
        {
            case null:
                return false;
            case ReportPlace.Map:
                if (!scene.MapReady)
                {
                    Tell(BusyText, scene);
                }

                return false;
            case ReportPlace.Menu:
                Open();
                return true;
            default:
                Tell(scene.Place == ReportPlace.Battle ? BattleText : BusyText, scene);
                return false;
        }
    }

    /// <summary>
    /// Forgets the report of a form that never opened, since another scene took its place before it
    /// started, which would refuse every later report as waiting. Comes first in each frame.
    /// </summary>
    /// <param name="scene">The scene in front.</param>
    public void ForgetLostForm(ReportScene scene)
    {
        ArgumentNullException.ThrowIfNull(scene);
        if (opening is null || scene.Place == ReportPlace.Form)
        {
            return;
        }

        Report report = opening;
        opening = null;
        Closed(report, $"{scene.Name} took the place of the form before it opened");
    }

    /// <summary>
    /// Counts down to the screenshot the wheel asked for. Comes after the hotkey in each frame.
    /// </summary>
    /// <returns>Whether the scripts take the screenshot now, then telling <see cref="Snapped"/>.</returns>
    public bool SnapDue()
    {
        if (snapIn is null || pending is null)
        {
            return false;
        }

        snapIn--;
        if (snapIn > 0)
        {
            return false;
        }

        snapIn = null;
        afterSnap = null;
        return true;
    }

    /// <summary>
    /// Runs the rest of a frame: forgets a waiting report once the game left for the title, follows
    /// the sending and tells what waits for the notification box once it shows.
    /// </summary>
    /// <param name="scene">The scene in front.</param>
    public void Frame(ReportScene scene)
    {
        ArgumentNullException.ThrowIfNull(scene);
        if (pending is not null && scene.Place == ReportPlace.Title)
        {
            Forget($"the game left for {scene.Name}");
        }

        Poll();
        if (outcome is not null && scene.NoticesShown)
        {
            host.Notice(outcome, NoticeFrames);
            outcome = null;
        }

        ShowTold(scene);
    }

    /// <summary>
    /// Opens the report that waits, once it took its screenshot and the player is free on the map.
    /// Comes after the map's update.
    /// </summary>
    /// <param name="scene">The map.</param>
    /// <returns>Whether the scripts open the form now.</returns>
    public bool OnMap(ReportScene scene)
    {
        ArgumentNullException.ThrowIfNull(scene);
        if (pending is not { Ready: true } || !scene.MapReady)
        {
            return false;
        }

        Open();
        return true;
    }

    /// <summary>
    /// Hands the form the report whose form opens, once.
    /// </summary>
    /// <returns>Whether the report took a screenshot, <see langword="null"/> when none opens.</returns>
    public bool? TakeOpening()
    {
        form = opening;
        opening = null;
        return form?.Snapped;
    }

    /// <summary>
    /// Starts sending the report the form holds on the DLL's own thread, and says so in the
    /// notification box.
    /// </summary>
    /// <param name="title">Its title.</param>
    /// <param name="text">What happened.</param>
    /// <param name="screenshot">Whether to attach the screenshot.</param>
    /// <param name="logs">Whether to attach the logs.</param>
    /// <returns>Why it was not sent, <see langword="null"/> once it is being sent.</returns>
    public string? Send(string title, string text, bool screenshot, bool logs)
    {
        ArgumentNullException.ThrowIfNull(title);
        ArgumentNullException.ThrowIfNull(text);
        if (Sending)
        {
            return SendingRefusal;
        }

        if (!host.Named)
        {
            return NoNameRefusal;
        }

        Report report = form ?? new Report([], []);
        int flags = (screenshot && report.Snapped ? BugReports.AttachScreenshot : 0) | (logs ? BugReports.AttachLogs : 0);
        string facts = Lines(report.Facts.Take(MaxFacts), MaxValueChars);
        string details = Lines(report.Details, MaxDetailChars);
        bool started = host.Send(title, text, facts, details, flags);
        string attached = $"{((flags & BugReports.AttachScreenshot) != 0 ? "with" : "without")} the screenshot, {((flags & BugReports.AttachLogs) != 0 ? "with" : "without")} the logs";
        if (!started)
        {
            Log($"the DLL did not start sending \"{Short(title)}\" ({attached})");
            return NotStartedRefusal;
        }

        report.Sent = true;
        Sending = true;
        pollFrames = 0;
        outcome = null;
        Log($"sending \"{Short(title)}\" ({Length(text)} characters, {attached}) with {Math.Min(report.Facts.Count, MaxFacts)} facts");
        host.Notice(SendingText, NoticeFrames);
        return null;
    }

    /// <summary>
    /// Forgets the screenshot of the form's report once the form closed without sending it.
    /// </summary>
    /// <param name="reason">Why the form closed, for the log.</param>
    public void Closed(string reason)
    {
        Closed(form, reason);
        form = null;
    }

    /// <summary>
    /// Writes facts or details as the DLL takes them: a line per pair, its label and value split by
    /// a tab, each on one line and cut to its length.
    /// </summary>
    /// <param name="pairs">The labels and their values.</param>
    /// <param name="most">The most characters of a value.</param>
    /// <returns>The lines.</returns>
    internal static string Lines(IEnumerable<(string Label, string Value)> pairs, int most) =>
        string.Join("\n", pairs.Select(pair => $"{OneLine(pair.Label, MaxLabelChars)}\t{OneLine(pair.Value, most)}"));

    /// <summary>
    /// Tells why a report failed, in friendly words for the relay's rate limit, a relay that takes no
    /// reports and one busy with others; the rest only asks to try again, the log keeps why.
    /// </summary>
    /// <param name="code">The relay's code, or "http&lt;status&gt;" or "unreachable".</param>
    /// <returns>The reason.</returns>
    internal static string FailureText(string code) => FriendlyReasons.GetValueOrDefault(code, OtherFailure);

    /// <summary>
    /// Puts a text on one line without tabs, cut to a length.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="most">The most characters kept.</param>
    /// <returns>The text.</returns>
    private static string OneLine(string text, int most) => Cut(Strip(ControlRuns().Replace(text, " ")), most);

    /// <summary>
    /// Writes a title for the log as the scripts' log shortens it: on one line, cut to 80
    /// characters with "..." at the end.
    /// </summary>
    /// <param name="text">The title.</param>
    /// <returns>The title for the log.</returns>
    private static string Short(string text)
    {
        string line = LineEnds().Replace(text, " ");
        return Length(line) > 80 ? Cut(line, 77) + "..." : line;
    }

    /// <summary>
    /// Counts the characters of a text, as Ruby counts a UTF-8 string's.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The characters.</returns>
    private static int Length(string text) => text.EnumerateRunes().Count();

    /// <summary>
    /// Keeps the first characters of a text, as Ruby's <c>text[0, count]</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="count">The characters kept at most.</param>
    /// <returns>The text kept.</returns>
    private static string Cut(string text, int count) => string.Concat(text.EnumerateRunes().Take(count).Select(rune => rune.ToString()));

    /// <summary>
    /// Strips a text as Ruby's <c>String#strip</c> does: ASCII white space from both ends and NUL
    /// from the end.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The stripped text.</returns>
    private static string Strip(string text) => text.TrimStart(' ', '\t', '\n', '\v', '\f', '\r').TrimEnd(' ', '\t', '\n', '\v', '\f', '\r', '\0');

    /// <summary>
    /// Runs of control characters, which a fact's line writes as one space.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("[\\x00-\\x1f]+", RegexOptions.CultureInvariant)]
    private static partial Regex ControlRuns();

    /// <summary>
    /// Line breaks, which the log writes as one space.
    /// </summary>
    /// <returns>The expression.</returns>
    [GeneratedRegex("[\\r\\n]+", RegexOptions.CultureInvariant)]
    private static partial Regex LineEnds();

    /// <summary>
    /// Writes a line of the report into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => host.Log(LogTag + line);

    /// <summary>
    /// Tells why a report cannot open here, if it cannot.
    /// </summary>
    /// <param name="scene">The scene in front.</param>
    /// <returns>What the player is told, or the log's reason where the player is told nothing;
    /// <see langword="null"/> when it can open.</returns>
    private (string Text, bool Told)? RefusalAt(ReportScene scene)
    {
        if (scene.Typing)
        {
            return ("the player types", false);
        }

        if (scene.Place == ReportPlace.Form)
        {
            return ("the form is open already", false);
        }

        if (scene.Place == ReportPlace.Title)
        {
            return ("the game shows the title or game over screen", false);
        }

        if (Sending)
        {
            return (SendingRefusal, true);
        }

        if (pending is not null || opening is not null)
        {
            return (WaitingRefusal, true);
        }

        return host.Named ? null : (NoNameRefusal, true);
    }

    /// <summary>
    /// Logs why a report does not open, and tells the player when they should know.
    /// </summary>
    /// <param name="via">How it was asked for.</param>
    /// <param name="refusal">Why, and whether the player is told.</param>
    /// <param name="scene">The scene in front.</param>
    private void Refuse(ReportVia via, (string Text, bool Told) refusal, ReportScene scene)
    {
        if (via == ReportVia.Hotkey)
        {
            host.HotkeyRefused(refusal.Text);
        }
        else
        {
            Log($"no report by wheel: {refusal.Text}");
        }

        if (!refusal.Told)
        {
            return;
        }

        host.Sound("buzzer");
        Tell(refusal.Text, scene);
    }

    /// <summary>
    /// Forgets the waiting report and its screenshot.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    private void Forget(string reason)
    {
        Report? report = pending;
        pending = null;
        snapIn = null;
        told = null;
        if (report is null)
        {
            return;
        }

        DropSnap(report);
        Log($"forgot the waiting report: {reason}");
    }

    /// <summary>
    /// Opens the form of the waiting report.
    /// </summary>
    private void Open()
    {
        opening = pending;
        pending = null;
        told = null;
        Log($"opening the form{(opening!.Snapped ? " with the screenshot" : " without a screenshot")}");
    }

    /// <summary>
    /// Forgets the screenshot of a report whose form closed without sending it.
    /// </summary>
    /// <param name="report">The report, <see langword="null"/> for none.</param>
    /// <param name="reason">Why the form closed, for the log.</param>
    private void Closed(Report? report, string reason)
    {
        if (report is null || report.Sent)
        {
            return;
        }

        DropSnap(report);
        Log($"the form closed without sending: {reason}");
    }

    /// <summary>
    /// Has the DLL forget a report's screenshot, if it took one.
    /// </summary>
    /// <param name="report">The report.</param>
    private void DropSnap(Report report)
    {
        if (!report.Snapped)
        {
            return;
        }

        host.DropSnap();
        report.Snapped = false;
        Log("dropped the screenshot");
    }

    /// <summary>
    /// Tells the player something: in the battle's chat log in a battle of a world, else in the
    /// notification box, or once it shows.
    /// </summary>
    /// <remarks>
    /// The box counts a message down while it hides, so a message posted then would run out unseen.
    /// </remarks>
    /// <param name="text">What to say.</param>
    /// <param name="scene">The scene in front.</param>
    private void Tell(string text, ReportScene scene)
    {
        if (scene.Place == ReportPlace.Battle && scene.InWorld)
        {
            host.ChatLine(text);
            return;
        }

        if (!scene.NoticesShown)
        {
            told = text;
            Log($"kept for the notification box until it shows: {text}");
            return;
        }

        told = null;
        host.Notice(text, null);
    }

    /// <summary>
    /// Tells what waits for the notification box once it shows. A text saying when the form opens is
    /// told only while the report still waits and not on a free map, where it opens at once, and as
    /// <see cref="BusyText"/>, since the battle it waited for is over.
    /// </summary>
    /// <param name="scene">The scene in front.</param>
    private void ShowTold(ReportScene scene)
    {
        if (told is null || !scene.NoticesShown)
        {
            return;
        }

        string text = told;
        told = null;
        if (text is BattleText or BusyText)
        {
            if (pending is null)
            {
                Log($"dropped what waited for the notification box, the report no longer waits: {text}");
                return;
            }

            if (scene.Place == ReportPlace.Map && scene.MapReady)
            {
                return;
            }

            text = BusyText;
        }

        host.Notice(text, null);
    }

    /// <summary>
    /// Looks at how the sending stands every <see cref="PollFrames"/> while a report is being sent,
    /// and keeps its outcome for the notification box.
    /// </summary>
    private void Poll()
    {
        if (!Sending)
        {
            return;
        }

        pollFrames++;
        if (pollFrames < PollFrames)
        {
            return;
        }

        pollFrames = 0;
        string[] parts = host.Describe().Split('\t', 3);
        string value = parts.Length > 1 ? parts[1] : string.Empty;
        string reason = parts.Length > 2 ? parts[2] : string.Empty;
        switch (parts[0])
        {
            case "sent":
                Finish($"Bug report sent as issue #{value}. Thank you!", $"was sent as issue {value}: {reason}");
                break;
            case "failed":
                Finish($"The bug report failed: {FailureText(value)}", $"failed ({value}): {reason}");
                break;
        }
    }

    /// <summary>
    /// Ends the sending and keeps its outcome for the notification box.
    /// </summary>
    /// <param name="text">What the box says.</param>
    /// <param name="logged">What the log says.</param>
    private void Finish(string text, string logged)
    {
        Sending = false;
        outcome = text;
        told = null;
        Log($"the report {logged}");
    }

    /// <summary>
    /// A report asked for: its facts and details as they were then, whether its screenshot was taken
    /// and kept, and whether it was sent.
    /// </summary>
    /// <param name="facts">The public facts.</param>
    /// <param name="details">The private details.</param>
    private sealed class Report(IReadOnlyList<(string Label, string Value)> facts, IReadOnlyList<(string Label, string Value)> details)
    {
        /// <summary>
        /// Gets the public facts.
        /// </summary>
        public IReadOnlyList<(string Label, string Value)> Facts { get; } = facts;

        /// <summary>
        /// Gets the private details.
        /// </summary>
        public IReadOnlyList<(string Label, string Value)> Details { get; } = details;

        /// <summary>
        /// Gets or sets a value indicating whether the DLL keeps its screenshot.
        /// </summary>
        public bool Snapped { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether its screenshot was taken, kept or not.
        /// </summary>
        public bool Ready { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether it was sent.
        /// </summary>
        public bool Sent { get; set; }
    }
}
