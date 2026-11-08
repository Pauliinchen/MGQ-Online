//----------------------------------------------------------------
//  ReportTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-01: Took the wheel's screenshot once the action wheel is gone
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Reports;

/// <summary>
/// The bridge topics of the in-game bug report's request (<see cref="BugReportRequest"/>): the
/// frame, the screenshot taken, the map, the wheel, the form's report, sending and closing in;
/// the sounds, the chat's lines, the notification box's messages and the hotkey's refusals out as
/// drained events.
/// </summary>
/// <remarks>
/// A scene goes as {"name", "place" ("map", "battle", "menu", "waiting_menu", "form", "title",
/// "other"), "in_world", "map_ready", "shown" (the notification box), "typing"}; facts and details
/// as [[label, value], ...].
/// </remarks>
internal sealed class ReportTopics : IReportHost
{
    /// <summary>
    /// The topic of a frame, after Graphics.update: {"scene", "hotkey" (pressed this frame), and with
    /// it "where", "facts", "details"} in; whether the scripts take the screenshot now, then telling
    /// <see cref="SnappedTopic"/>.
    /// </summary>
    public const string TickTopic = "report.tick";

    /// <summary>
    /// The topic of the screenshot taken: {"kept", "scene"} in; whether the scripts open the form now.
    /// The frame's rest runs after it.
    /// </summary>
    public const string SnappedTopic = "report.snapped";

    /// <summary>
    /// The topic of the map's update: the scene in; whether the scripts open the form now.
    /// </summary>
    public const string MapTopic = "report.on_map";

    /// <summary>
    /// The topic that tells why the wheel's choice is refused: the refusal out, nil while it may be taken.
    /// </summary>
    public const string WheelRefusalTopic = "report.wheel_refusal";

    /// <summary>
    /// The topic of the wheel's choice taken: {"scene", "where", "facts", "details"} in.
    /// </summary>
    public const string WheelTopic = "report.wheel";

    /// <summary>
    /// The topic of the action wheel gone: whether the scripts take the screenshot the wheel asked
    /// for now, then telling <see cref="SnappedTopic"/>.
    /// </summary>
    public const string WheelGoneTopic = "report.wheel_gone";

    /// <summary>
    /// The topic the form takes its report by: whether a screenshot was kept out, nil when none opens.
    /// </summary>
    public const string OpeningTopic = "report.take_opening";

    /// <summary>
    /// The topic that sends the form's report: {"title", "text", "screenshot", "logs"} in; why it was
    /// not sent out, nil once it is being sent.
    /// </summary>
    public const string SendTopic = "report.send";

    /// <summary>
    /// The topic of the form closing: why in.
    /// </summary>
    public const string ClosedTopic = "report.closed";

    /// <summary>
    /// The event of a sound to play: its name after <c>Sound.play_</c>.
    /// </summary>
    public const string SoundEvent = "report.sound";

    /// <summary>
    /// The event of a line for the battle's chat log: its text.
    /// </summary>
    public const string ChatLineEvent = "report.chat_line";

    /// <summary>
    /// The event of a message for the notification box: {"text", "frames" (nil for the box's own time)}.
    /// </summary>
    public const string NoticeEvent = "report.notice";

    /// <summary>
    /// The event of the hotkey's refusal, which the hotkeys log: why.
    /// </summary>
    public const string HotkeyRefusedEvent = "report.hotkey_refused";

    /// <summary>
    /// The places of the scenes by their names on the bridge.
    /// </summary>
    private static readonly Dictionary<string, ReportPlace> Places = new(StringComparer.Ordinal)
    {
        ["map"] = ReportPlace.Map,
        ["battle"] = ReportPlace.Battle,
        ["menu"] = ReportPlace.Menu,
        ["waiting_menu"] = ReportPlace.WaitingMenu,
        ["form"] = ReportPlace.Form,
        ["title"] = ReportPlace.Title,
        ["other"] = ReportPlace.Other,
    };

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext context;

    /// <summary>
    /// The DLL's reports.
    /// </summary>
    private readonly BugReports reports;

    /// <summary>
    /// Initializes the topics over the DLL's reports.
    /// </summary>
    /// <param name="context">The context the events go to.</param>
    /// <param name="reports">The DLL's reports.</param>
    private ReportTopics(BridgeContext context, BugReports reports)
    {
        this.context = context;
        this.reports = reports;
        Request = new BugReportRequest(this);
    }

    /// <summary>
    /// Gets the request.
    /// </summary>
    public BugReportRequest Request { get; }

    /// <inheritdoc />
    public bool Named => reports.Playing() is not null;

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="reports">The DLL's reports.</param>
    /// <returns>The topics.</returns>
    public static ReportTopics Register(BridgeContext context, BugReports reports)
    {
        var topics = new ReportTopics(context, reports);
        BugReportRequest request = topics.Request;
        context.Register(TickTopic, (_, value) => topics.Tick(value.AsHash()));
        context.Register(SnappedTopic, (_, value) =>
        {
            bool open = request.Snapped(value.AsHash()["kept"].AsBool());
            request.Frame(SceneOf(value.AsHash()["scene"]));
            return open;
        });
        context.Register(MapTopic, (_, value) => request.OnMap(SceneOf(value)));
        context.Register(WheelRefusalTopic, (_, _) => request.WheelRefusal());
        context.Register(WheelTopic, (_, value) =>
        {
            RubyHash asked = value.AsHash();
            request.Request(ReportVia.Wheel, SceneOf(asked["scene"]), asked["where"].AsText(), PairsOf(asked["facts"]), PairsOf(asked["details"]));
            return null;
        });
        context.Register(WheelGoneTopic, (_, _) => request.WheelGone());
        context.Register(OpeningTopic, (_, _) => request.TakeOpening() is { } snapped ? snapped : RubyNil.Value);
        context.Register(SendTopic, (_, value) =>
        {
            RubyHash form = value.AsHash();
            return request.Send(form["title"].AsText(), form["text"].AsText(), form["screenshot"].AsBool(), form["logs"].AsBool());
        });
        context.Register(ClosedTopic, (_, value) =>
        {
            request.Closed(value.AsText());
            return null;
        });
        return topics;
    }

    /// <inheritdoc />
    public void Log(string line) => Multiplayer.Log.Write(line);

    /// <inheritdoc />
    public void HotkeyRefused(string reason) => context.Events.Post(HotkeyRefusedEvent, reason);

    /// <inheritdoc />
    public void Sound(string name) => context.Events.Post(SoundEvent, name);

    /// <inheritdoc />
    public void ChatLine(string text) => context.Events.Post(ChatLineEvent, text);

    /// <inheritdoc />
    public void Notice(string text, int? frames) =>
        context.Events.Post(NoticeEvent, new RubyHash { { "text", text }, { "frames", frames is { } shown ? shown : RubyNil.Value } });

    /// <inheritdoc />
    public void DropSnap() => reports.DropSnap();

    /// <inheritdoc />
    public bool Send(string title, string text, string facts, string details, int flags) => reports.Send(title, text, facts, details, flags);

    /// <inheritdoc />
    public string Describe() => reports.Describe();

    /// <summary>
    /// Reads a scene.
    /// </summary>
    /// <param name="value">The scene, see the remarks.</param>
    /// <returns>The scene.</returns>
    /// <exception cref="BridgeRequestException">The place is none the report knows.</exception>
    private static ReportScene SceneOf(RubyValue value)
    {
        RubyHash scene = value.AsHash();
        string place = scene["place"].AsText();
        return new ReportScene(scene["name"].AsText(), Places.TryGetValue(place, out ReportPlace known) ? known : throw new BridgeRequestException($"There is no place {place}."),
            scene["in_world"].AsBool(), scene["map_ready"].AsBool(), scene["shown"].AsBool(), scene["typing"].AsBool());
    }

    /// <summary>
    /// Reads labels with their values.
    /// </summary>
    /// <param name="value">[[label, value], ...].</param>
    /// <returns>The pairs.</returns>
    private static List<(string, string)> PairsOf(RubyValue value) =>
        [.. value.AsArray().Select(pair => (pair.AsArray()[0].AsText(), pair.AsArray()[1].AsText()))];

    /// <summary>
    /// Runs a frame up to a screenshot that is due: the form a scene took the place of, the hotkey,
    /// then the frame's rest unless its screenshot comes first.
    /// </summary>
    /// <param name="frame">See <see cref="TickTopic"/>.</param>
    /// <returns>Whether the scripts take the screenshot now.</returns>
    private bool Tick(RubyHash frame)
    {
        ReportScene scene = SceneOf(frame["scene"]);
        Request.ForgetLostForm(scene);
        bool snap = frame["hotkey"].AsBool() && Request.Request(ReportVia.Hotkey, scene, frame["where"].AsText(), PairsOf(frame["facts"]), PairsOf(frame["details"]));
        if (!snap)
        {
            Request.Frame(scene);
        }

        return snap;
    }
}
