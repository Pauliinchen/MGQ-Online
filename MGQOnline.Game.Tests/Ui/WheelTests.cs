//----------------------------------------------------------------
//  WheelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;
using MGQOnline.Game.Ui.Wheels;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers the wheels: the pointing and placing against the cases the scripts' own rules wrote
/// (fixtures/ui/wheel.json), and the action and emote wheels through the tick.
/// </summary>
public sealed class WheelTests
{
    /// <summary>
    /// The arrows' bits as the scripts hand them over, by their names in the cases.
    /// </summary>
    private static readonly Dictionary<string, WheelArrows> Arrows = new()
    {
        ["UP"] = WheelArrows.Up,
        ["DOWN"] = WheelArrows.Down,
        ["LEFT"] = WheelArrows.Left,
        ["RIGHT"] = WheelArrows.Right,
    };

    /// <summary>
    /// Gives the name of every pointing case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> SteadyCases() => new(Fixtures.Ui("wheel.json").GetProperty("steady").EnumerateArray().Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that the arrows held frame by frame point where the scripts pointed.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(SteadyCases))]
    public void Steady_PointsWhereTheScriptPointed(string name)
    {
        JsonElement entry = Fixtures.Ui("wheel.json").GetProperty("steady").EnumerateArray().Single(item => item.GetProperty("name").GetString() == name);
        var pointer = new WheelPointer();

        string?[] pointed = [.. entry.GetProperty("frames").EnumerateArray().Select(frame => NameOf(pointer.Steady(ArrowsOf(frame))))];

        Assert.Equal(entry.GetProperty("pointed").EnumerateArray().Select(direction => direction.GetString()), pointed);
    }

    /// <summary>
    /// Asserts that every count of choices is placed where the scripts placed it, halves of the
    /// division rounded away from zero, and that the grace is the scripts'.
    /// </summary>
    [Fact]
    public void Places_SpreadTheChoicesAsTheScriptDid()
    {
        JsonElement fixture = Fixtures.Ui("wheel.json");

        foreach (JsonElement entry in fixture.GetProperty("places").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("places").EnumerateArray().Select(place => place.GetString()), WheelPlaces.Of(entry.GetProperty("count").GetInt32()).Select(place => NameOf(place)));
        }

        Assert.Equal(WheelPointer.GraceTicks, fixture.GetProperty("grace_frames").GetInt32());
    }

    /// <summary>
    /// Asserts that the action wheel opens on its middle with its places, points at a choice, picks
    /// the middle for a direction without one, keeps the pick once the arrows are let go and reports
    /// confirm without closing, which the choice taken does.
    /// </summary>
    [Fact]
    public void ActionWheel_PointsTakesAndStaysOpenForTheChoice()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);

        RubyHash opened = Event(ui.Tick(Input("wheel", key: true, count: 4)));
        RubyHash right = Event(ui.Tick(Input("wheel", arrows: WheelArrows.Right, count: 4)));
        RubyHash diagonal = Event(ui.Tick(Input("wheel", arrows: WheelArrows.Up | WheelArrows.Left, count: 4)));
        List<(string Topic, RubyValue Payload)> letGo = ui.Tick(Input("wheel", count: 4));
        RubyHash taken = Event(ui.Tick(Input("wheel", confirm: true, count: 4)));
        ui.Value(WheelModel.CloseTopic, new RubyArray { "wheel" });
        List<(string Topic, RubyValue Payload)> closed = ui.Tick(Input("wheel", arrows: WheelArrows.Down, count: 4));

        Assert.Equal((true, -1L, new RubyArray { 0, 2, 4, 6 }, new RubyArray { UiCue.Cursor }), (opened["open"].AsBool(), opened["selected"].AsLong(), opened["places"], opened[UiCue.Key]));
        Assert.Equal(2, right["selected"].AsInt());
        Assert.Equal(WheelModel.Center, diagonal["selected"].AsInt());
        Assert.Empty(letGo);
        Assert.Equal((true, WheelModel.Center), (taken["open"].AsBool(), taken["take"].AsInt()));
        Assert.Empty(closed);
    }

    /// <summary>
    /// Asserts that the emote wheel opens on nothing, closes with the emote pointed at on confirm,
    /// and closes without one with the cancel sound.
    /// </summary>
    [Fact]
    public void EmoteWheel_ClosesWithTheEmoteOnConfirm()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);

        RubyHash opened = Event(ui.Tick(Input("emotes", key: true, count: 8)));
        RubyHash pointed = Event(ui.Tick(Input("emotes", arrows: WheelArrows.Down, count: 8)));
        RubyHash taken = Event(ui.Tick(Input("emotes", confirm: true, count: 8)));
        ui.Tick(Input("emotes", key: true, count: 8));
        RubyHash empty = Event(ui.Tick(Input("emotes", confirm: true, count: 8)));

        Assert.True(opened["selected"].IsNil);
        Assert.Equal(4, pointed["selected"].AsInt());
        Assert.Equal((false, 4, new RubyArray()), (taken["open"].AsBool(), taken["take"].AsInt(), taken[UiCue.Key]));
        Assert.Equal((false, true, new RubyArray { UiCue.Cancel }), (empty["open"].AsBool(), empty["take"].IsNil, empty[UiCue.Key]));
    }

    /// <summary>
    /// Asserts that the hotkey and cancel close a wheel with the cancel sound, and that a map that
    /// no longer leaves it free closes it with the owner's reason, silently.
    /// </summary>
    [Fact]
    public void Wheel_ClosesOnItsKeyCancelAndTheMap()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);

        ui.Tick(Input("wheel", key: true, count: 2));
        RubyHash byKey = Event(ui.Tick(Input("wheel", key: true, count: 2)));
        ui.Tick(Input("wheel", key: true, count: 2));
        RubyHash byCancel = Event(ui.Tick(Input("wheel", cancel: true, count: 2)));
        ui.Tick(Input("wheel", key: true, count: 2));
        RubyHash byMap = Event(ui.Tick(new RubyHash { { "wheel", new RubyArray { "an event started", false, false, false, 0, 2 } } }));

        Assert.Equal(("its key", new RubyArray { UiCue.Cancel }), (byKey["reason"].AsText(), byKey[UiCue.Key]));
        Assert.Equal(("cancel", false), (byCancel["reason"].AsText(), byCancel["open"].AsBool()));
        Assert.Equal(("an event started", new RubyArray()), (byMap["reason"].AsText(), byMap[UiCue.Key]));
    }

    /// <summary>
    /// Builds a wheel's input.
    /// </summary>
    /// <param name="wheel">The wheel's name.</param>
    /// <param name="key">Whether its hotkey went down.</param>
    /// <param name="cancel">Whether cancel went down.</param>
    /// <param name="confirm">Whether confirm went down.</param>
    /// <param name="arrows">The arrows held.</param>
    /// <param name="count">How many choices it has.</param>
    /// <returns>The tick.</returns>
    private static RubyHash Input(string wheel, bool key = false, bool cancel = false, bool confirm = false, WheelArrows arrows = WheelArrows.None, int count = 0) =>
        new() { { wheel, new RubyArray { true, key, cancel, confirm, (long)arrows, count } } };

    /// <summary>
    /// Finds the wheels' event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Event(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == WheelModel.EventTopic).Payload.AsHash();

    /// <summary>
    /// Reads a frame's arrows of a case.
    /// </summary>
    /// <param name="frame">The names of the arrows held.</param>
    /// <returns>The arrows.</returns>
    private static WheelArrows ArrowsOf(JsonElement frame) => frame.EnumerateArray().Aggregate(WheelArrows.None, (held, arrow) => held | Arrows[arrow.GetString()!]);

    /// <summary>
    /// Names a direction as the scripts name it.
    /// </summary>
    /// <param name="direction">The direction, null for none.</param>
    /// <returns>Its name, such as "UP_RIGHT", null for none.</returns>
    private static string? NameOf(WheelDirection? direction) => direction switch
    {
        null => null,
        WheelDirection.UpRight => "UP_RIGHT",
        WheelDirection.DownRight => "DOWN_RIGHT",
        WheelDirection.DownLeft => "DOWN_LEFT",
        WheelDirection.UpLeft => "UP_LEFT",
        { } plain => plain.ToString().ToUpperInvariant(),
    };
}
