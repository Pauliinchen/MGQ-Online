//----------------------------------------------------------------
//  LayoutModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;
using MGQOnline.Game.Ui.Layout;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Replays the steps the scripts' own layout played (fixtures/ui/layout.json) through the C#
/// layout: the places asked for, the drags, the double click and what Player.ini kept, and covers
/// what only the C# side says: the overlay.
/// </summary>
public sealed class LayoutModelTests
{
    /// <summary>
    /// Asserts that every rect answers and every frame keeps or forgets in Player.ini what the
    /// script's layout did.
    /// </summary>
    [Fact]
    public void Steps_PlaceTheBoxesAsTheScriptDid()
    {
        JsonElement fixture = Fixtures.Ui("layout.json");
        int screenWidth = fixture.GetProperty("screen")[0].GetInt32();
        int screenHeight = fixture.GetProperty("screen")[1].GetInt32();
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        var offers = new RubyArray();
        var ini = new Dictionary<string, string>();
        bool held = false;
        bool dragging = false;
        int index = 0;

        foreach (JsonElement step in fixture.GetProperty("steps").EnumerateArray())
        {
            if (step.TryGetProperty("register", out JsonElement register))
            {
                RubyValue stored = step.GetProperty("stored").ValueKind == JsonValueKind.Null ? RubyNil.Value : step.GetProperty("stored").GetString();
                ui.Value(LayoutModel.RegisterTopic, new RubyArray { register[0].GetString(), register[1].GetString(), register[2].GetInt32(), register[3].GetInt32(), register[4].GetString(), stored });
            }
            else if (step.TryGetProperty("rect", out JsonElement rect))
            {
                RubyArray place = ui.Value(LayoutModel.RectTopic, new RubyArray { rect[0].GetString(), rect[1].GetInt32(), rect[2].GetInt32(), rect[3].GetInt32(), rect[4].GetInt32(), screenWidth, screenHeight, false }).AsArray();
                Assert.True(step.GetProperty("result").EnumerateArray().Select(value => value.GetInt32()).SequenceEqual(place.Take(4).Select(value => value.AsInt())), $"step {index}: {place}");
            }
            else if (step.TryGetProperty("offer", out JsonElement offer))
            {
                offers.Add(new RubyArray { offer[0].GetString(), offer[1].GetInt32(), offer[2].GetInt32(), offer[3].GetInt32(), offer[4].GetInt32(), offer[5].GetInt32() });
            }
            else if (step.TryGetProperty("tick", out JsonElement tick))
            {
                bool down = tick.GetProperty("held").GetBoolean();
                JsonElement mouse = tick.GetProperty("mouse");
                RubyArray input = [tick.GetProperty("alt").GetBoolean(), down, down && !held, mouse[0].GetInt32(), mouse[1].GetInt32(), screenWidth, screenHeight, offers];
                held = down;
                offers = [];
                var kept = new Dictionary<string, string>();
                var forgot = new List<string>();
                foreach ((string topic, RubyValue payload) in ui.Tick(new RubyHash { { "layout", input } }))
                {
                    RubyHash change = payload.AsHash();
                    if (change.TryGetValue("dragging", out RubyValue? drag))
                    {
                        dragging = drag.AsBool();
                    }

                    if (change.TryGetValue("store", out RubyValue? store))
                    {
                        foreach ((RubyValue id, RubyValue text) in store.AsHash())
                        {
                            string key = "ui_" + id.AsText();
                            if (text.IsNil)
                            {
                                forgot.Add(key);
                                ini.Remove(key);
                            }
                            else
                            {
                                kept[key] = text.AsText();
                                ini[key] = text.AsText();
                            }
                        }
                    }
                }

                JsonElement result = step.GetProperty("result");
                Assert.Equal(result.GetProperty("kept").EnumerateObject().Select(pair => (pair.Name, pair.Value.GetString()!)), kept.Select(pair => (pair.Key, pair.Value)));
                Assert.Equal(result.GetProperty("forgot").EnumerateArray().Select(key => key.GetString()), forgot);
                Assert.Equal(result.GetProperty("dragging").GetBoolean(), dragging);
            }
            else
            {
                ui.Value(LayoutModel.ResetTopic, new RubyArray { step.GetProperty("reset").GetString() });
            }

            index++;
        }
    }

    /// <summary>
    /// Asserts that Alt held outlines the boxes shown with the one under the mouse, says nothing
    /// while that stays, and hides once Alt is let go.
    /// </summary>
    [Fact]
    public void Tick_ShowsTheOverlayWhileAltIsHeld()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        RubyArray Offers() => [new RubyArray { "box", 10, 10, 100, 50, 1 }];

        RubyHash shown = Single(ui.Tick(Input(true, [20, 20], Offers())));
        List<(string Topic, RubyValue Payload)> same = ui.Tick(Input(true, [21, 20], Offers()));
        RubyHash hidden = Single(ui.Tick(Input(false, [21, 20], Offers())));

        Assert.Equal((new RubyArray { "box" }, "box"), (shown["overlay"], shown["hot"].AsText()));
        Assert.Empty(same);
        Assert.True(hidden["overlay"].IsNil);
    }

    /// <summary>
    /// Asserts how Player.ini's text reads: four whole numbers with spaces around them, and nothing
    /// for any other text.
    /// </summary>
    [Fact]
    public void Parse_ReadsFourWholeNumbers()
    {
        Assert.Equal(new LayoutRect(100, -20, 10, 10), LayoutModel.Parse(" 100, -20 ,10,10"));
        Assert.Equal(new LayoutRect(1, 2, 3, 4), LayoutModel.Parse("1,2,3,4,"));
        Assert.Null(LayoutModel.Parse("1,2,three,4"));
        Assert.Null(LayoutModel.Parse("1,2,3"));
        Assert.Null(LayoutModel.Parse(null));
    }

    /// <summary>
    /// Builds a frame's input without the button.
    /// </summary>
    /// <param name="alt">Whether Alt is held.</param>
    /// <param name="mouse">Where the mouse points.</param>
    /// <param name="offers">The boxes shown.</param>
    /// <returns>The tick.</returns>
    private static RubyHash Input(bool alt, int[] mouse, RubyArray offers) =>
        new() { { "layout", new RubyArray { alt, false, false, mouse[0], mouse[1], 640, 480, offers } } };

    /// <summary>
    /// Finds the layout's event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Single(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == LayoutModel.EventTopic).Payload.AsHash();
}
