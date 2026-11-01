//----------------------------------------------------------------
//  BugReportRequestTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Took the wheel's screenshot as the action wheel is gone
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Covers the bug report's request against the scenarios ui_bug_report.rbx played before it moved
/// to C# (fixtures/hud/report.json, written by make_report_fixtures.rb there), each frame acted on
/// in the script's order: the form a scene took the place of, the hotkey and its screenshot, the
/// rest of the frame, then the map.
/// </summary>
public sealed class BugReportRequestTests
{
    /// <summary>
    /// The scenes' class names by the place the cases name them.
    /// </summary>
    private static readonly Dictionary<string, (string Name, ReportPlace Place)> Scenes = new()
    {
        ["map"] = ("Scene_Map", ReportPlace.Map),
        ["battle"] = ("Scene_Battle", ReportPlace.Battle),
        ["menu"] = ("Scene_Menu", ReportPlace.Menu),
        ["waiting_menu"] = ("Scene_MpStoryChoices", ReportPlace.WaitingMenu),
        ["form"] = ("Scene_MpBugReport", ReportPlace.Form),
        ["title"] = ("Scene_Title", ReportPlace.Title),
        ["other"] = ("Scene_Load", ReportPlace.Other),
    };

    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Cases().EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario does what the script did.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Steps_DoWhatTheScriptDid(string name)
    {
        JsonElement scenario = Cases().EnumerateArray().Single(each => each.GetProperty("name").GetString() == name);
        var game = new Game();
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            JsonNode expected = JsonNode.Parse(step.GetProperty("answer").GetRawText())!;
            JsonNode actual = game.Run(step);
            Assert.True(JsonNode.DeepEquals(expected, actual), $"step {index} ({step.GetProperty("op").GetString()}): expected {expected.ToJsonString()}, got {actual.ToJsonString()}");
            index++;
        }
    }

    /// <summary>
    /// Reads the scenarios.
    /// </summary>
    /// <returns>The scenarios.</returns>
    private static JsonElement Cases()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "hud", "report.json")));
        return document.RootElement.GetProperty("scenarios").Clone();
    }

    /// <summary>
    /// The game around the request as the scenarios play it, writing down what the request did.
    /// </summary>
    private sealed class Game : IReportHost
    {
        /// <summary>
        /// The lines written into the log.
        /// </summary>
        private readonly List<string> logs = [];

        /// <summary>
        /// The hotkeys' refusals.
        /// </summary>
        private readonly List<string> refusals = [];

        /// <summary>
        /// The sounds played.
        /// </summary>
        private readonly List<string> sounds = [];

        /// <summary>
        /// The chat's lines.
        /// </summary>
        private readonly List<string> chat = [];

        /// <summary>
        /// The notification box's messages, each with its frames.
        /// </summary>
        private readonly List<(string Text, int? Frames)> notices = [];

        /// <summary>
        /// The reports sent, each its title, text, facts, details and flags.
        /// </summary>
        private readonly List<(string Title, string Text, string Facts, string Details, int Flags)> sends = [];

        /// <summary>
        /// The request.
        /// </summary>
        private readonly BugReportRequest request;

        /// <summary>
        /// The scene in front.
        /// </summary>
        private ReportScene scene = new("Scene_Map", ReportPlace.Map, true, true, true, false);

        /// <summary>
        /// The screenshots taken, the forms opened and the screenshots dropped in the step.
        /// </summary>
        private int snaps, opened, drops;

        /// <summary>
        /// Whether the DLL keeps a screenshot, and starts sending a report.
        /// </summary>
        private bool snapKept = true, started = true;

        /// <summary>
        /// How the last report's sending went.
        /// </summary>
        private string state = "idle";

        /// <summary>
        /// Initializes the game on a free map of an open world.
        /// </summary>
        public Game() => request = new BugReportRequest(this);

        /// <inheritdoc />
        public bool Named { get; private set; } = true;

        /// <summary>
        /// Runs one operation and reads what the request did.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <returns>What it did, as the cases record it.</returns>
        public JsonNode Run(JsonElement step)
        {
            logs.Clear();
            refusals.Clear();
            sounds.Clear();
            chat.Clear();
            notices.Clear();
            sends.Clear();
            snaps = opened = drops = 0;
            JsonNode? answer = null;
            switch (step.GetProperty("op").GetString())
            {
                case "scene": Take(step); break;
                case "frame":
                    int count = step.TryGetProperty("count", out JsonElement frames) ? frames.GetInt32() : 1;
                    for (int each = 0; each < count; each++)
                    {
                        Frame(step.TryGetProperty("hotkey", out JsonElement hotkey) && hotkey.GetBoolean());
                    }

                    break;
                case "wheel":
                    string? refusal = request.WheelRefusal();
                    answer = refusal;
                    if (refusal is null)
                    {
                        request.Request(ReportVia.Wheel, scene, Where, Facts, Details);
                    }

                    break;
                case "wheel_gone":
                    if (request.WheelGone())
                    {
                        Snap();
                    }

                    break;
                case "take_opening": answer = request.TakeOpening(); break;
                case "send":
                    answer = request.Send(Text(step, "title"), Text(step, "text"), step.GetProperty("screenshot").GetBoolean(), step.GetProperty("logs").GetBoolean());
                    break;
                case "closed": request.Closed(Text(step, "reason")); break;
                case "state": state = Text(step, "text"); break;
                case "named": Named = step.GetProperty("named").GetBoolean(); break;
                case "snap": snapKept = step.GetProperty("kept").GetBoolean(); break;
                case "started": started = step.GetProperty("started").GetBoolean(); break;
            }

            return new JsonObject
            {
                ["answer"] = answer,
                ["logs"] = Texts(logs),
                ["refusals"] = Texts(refusals),
                ["sounds"] = Texts(sounds),
                ["chat"] = Texts(chat),
                ["notices"] = new JsonArray([.. notices.Select(notice => (JsonNode)new JsonArray(notice.Text, notice.Frames is { } shown ? JsonValue.Create(shown) : null))]),
                ["snaps"] = snaps,
                ["opened"] = opened,
                ["drops"] = drops,
                ["sends"] = new JsonArray([.. sends.Select(sent => (JsonNode)new JsonArray(sent.Title, sent.Text, sent.Facts, sent.Details, sent.Flags))]),
                ["waiting"] = request.Waiting,
                ["sending"] = request.Sending,
            };
        }

        /// <inheritdoc />
        public void Log(string line) => logs.Add(line);

        /// <inheritdoc />
        public void HotkeyRefused(string reason) => refusals.Add(reason);

        /// <inheritdoc />
        public void Sound(string name) => sounds.Add(name);

        /// <inheritdoc />
        public void ChatLine(string text) => chat.Add(text);

        /// <inheritdoc />
        public void Notice(string text, int? frames) => notices.Add((text, frames));

        /// <inheritdoc />
        public void DropSnap() => drops++;

        /// <inheritdoc />
        public bool Send(string title, string text, string facts, string details, int flags)
        {
            sends.Add((title, text, facts, details, flags));
            return started;
        }

        /// <inheritdoc />
        public string Describe() => state;

        /// <summary>
        /// Writes texts as a JSON array.
        /// </summary>
        /// <param name="texts">The texts.</param>
        /// <returns>The array.</returns>
        private static JsonArray Texts(IEnumerable<string> texts) => new([.. texts.Select(text => (JsonNode)JsonValue.Create(text))]);

        /// <summary>
        /// Reads a text of a step.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <param name="name">The text's name.</param>
        /// <returns>The text.</returns>
        private static string Text(JsonElement step, string name) => step.GetProperty(name).GetString()!;

        /// <summary>
        /// Gets where the player is, as the script writes it.
        /// </summary>
        private string Where => $"{scene.Name}, map 5";

        /// <summary>
        /// Gets the facts the script gathers: twelve and where the player is.
        /// </summary>
        private List<(string, string)> Facts => [.. Enumerable.Range(1, 12).Select(n => ($"Fact {n}", $"value\t{n}")), ("Where", Where)];

        /// <summary>
        /// Gets the details the script gathers.
        /// </summary>
        private List<(string, string)> Details => [("Player", "Me\n(me000001)"), ("Long", new string('x', 1100))];

        /// <summary>
        /// Takes the scene a step names, keeping what it leaves out.
        /// </summary>
        /// <param name="step">The step.</param>
        private void Take(JsonElement step)
        {
            (string name, ReportPlace place) = Scenes[Text(step, "place")];
            bool Flag(string field, bool kept) => step.TryGetProperty(field, out JsonElement value) ? value.GetBoolean() : kept;
            scene = new ReportScene(name, place, Flag("in_world", scene.InWorld), Flag("map_ready", scene.MapReady), Flag("shown", scene.NoticesShown), Flag("typing", false));
        }

        /// <summary>
        /// Runs a frame as the script does: the form a scene took the place of, the hotkey and its
        /// screenshot, the rest of the frame, then the map.
        /// </summary>
        /// <param name="hotkey">Whether the hotkey was pressed.</param>
        private void Frame(bool hotkey)
        {
            request.ForgetLostForm(scene);
            if (hotkey && request.Request(ReportVia.Hotkey, scene, Where, Facts, Details))
            {
                Snap();
            }

            request.Frame(scene);
            if (scene.Place == ReportPlace.Map && request.OnMap(scene))
            {
                OpenForm();
            }
        }

        /// <summary>
        /// Takes the screenshot and opens the form when the request says so.
        /// </summary>
        private void Snap()
        {
            snaps++;
            if (request.Snapped(snapKept))
            {
                OpenForm();
            }
        }

        /// <summary>
        /// Opens the form, which is the scene in front from then on.
        /// </summary>
        private void OpenForm()
        {
            opened++;
            scene = scene with { Name = "Scene_MpBugReport", Place = ReportPlace.Form };
        }
    }
}
