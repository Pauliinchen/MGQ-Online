//----------------------------------------------------------------
//  ConfirmModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered a box that starts with its yes choice picked
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers the confirm box: one at a time, nothing read in the frame it opened in, the keys that
/// answer it, and the pick moving.
/// </summary>
public sealed class ConfirmModelTests
{
    /// <summary>
    /// Asserts that a box opens once at a time, reads nothing in its first tick, and that left or
    /// right move the pick, which confirm then takes as yes.
    /// </summary>
    [Fact]
    public void Ask_OpensOneBoxWhoseFirstTickReadsNothing()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        int id = ui.Value(ConfirmModel.AskTopic).AsInt();

        bool second = ui.Value(ConfirmModel.AskTopic).IsNil;
        List<(string Topic, RubyValue Payload)> first = ui.Tick(Keys(id, confirm: true));
        RubyHash moved = Event(ui.Tick(Keys(id, sideways: true)));
        RubyHash answered = Event(ui.Tick(Keys(id, confirm: true)));
        List<(string Topic, RubyValue Payload)> after = ui.Tick(Keys(id, decline: true));

        Assert.True(second);
        Assert.Empty(first);
        Assert.Equal((true, new RubyArray { UiCue.Cursor }, false), (moved["picked"].AsBool(), moved[UiCue.Key], moved.ContainsKey("answer")));
        Assert.Equal((true, "confirm", new RubyArray { UiCue.Ok }), (answered["answer"].AsBool(), answered["by"].AsText(), answered[UiCue.Key]));
        Assert.Empty(after);
    }

    /// <summary>
    /// Asserts that the accept hotkey answers yes before the others, the decline hotkey and cancel
    /// no with the cancel sound, and confirm the no choice picked first.
    /// </summary>
    [Fact]
    public void Tick_AnswersByTheKeyThatWentDown()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);

        var answers = new List<(bool, string, string)>();
        foreach (RubyHash keys in new[] { Keys(0, accept: true, decline: true), Keys(0, decline: true), Keys(0, cancel: true), Keys(0, confirm: true) })
        {
            int id = ui.Value(ConfirmModel.AskTopic).AsInt();
            ui.Tick(Keys(id));
            RubyArray input = keys["confirm"].AsArray();
            RubyHash answer = Event(ui.Tick(new RubyHash { { "confirm", new RubyArray { id, input[1], input[2], input[3], input[4], input[5] } } }));
            answers.Add((answer["answer"].AsBool(), answer["by"].AsText(), answer[UiCue.Key].AsArray()[0].AsText()));
        }

        Assert.Equal([(true, "accept", UiCue.Ok), (false, "decline", UiCue.Cancel), (false, "cancel", UiCue.Cancel), (false, "confirm", UiCue.Cancel)], answers);
    }

    /// <summary>
    /// Asserts that a box asked to start with its yes choice picked answers yes to confirm, and that
    /// left or right moves the pick back to no.
    /// </summary>
    [Fact]
    public void Ask_StartsOnYesWhenAsked()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        int id = ui.Value(ConfirmModel.AskTopic, true).AsInt();
        ui.Tick(Keys(id));

        RubyHash answered = Event(ui.Tick(Keys(id, confirm: true)));
        int next = ui.Value(ConfirmModel.AskTopic, true).AsInt();
        ui.Tick(Keys(next));
        RubyHash moved = Event(ui.Tick(Keys(next, sideways: true)));

        Assert.True(answered["answer"].AsBool());
        Assert.False(moved["picked"].AsBool());
    }

    /// <summary>
    /// Asserts that a box closed from outside reads no more keys, and that another may open then.
    /// </summary>
    [Fact]
    public void Close_EndsTheBoxForTheNext()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        int id = ui.Value(ConfirmModel.AskTopic).AsInt();
        ui.Tick(Keys(id));

        ui.Value(ConfirmModel.CloseTopic, new RubyArray { id });
        List<(string Topic, RubyValue Payload)> closed = ui.Tick(Keys(id, accept: true));
        int next = ui.Value(ConfirmModel.AskTopic).AsInt();

        Assert.Empty(closed);
        Assert.Equal(id + 1, next);
    }

    /// <summary>
    /// Builds the box's keys of a frame.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="accept">The accept hotkey.</param>
    /// <param name="decline">The decline hotkey.</param>
    /// <param name="cancel">Cancel.</param>
    /// <param name="confirm">Confirm.</param>
    /// <param name="sideways">Left or right.</param>
    /// <returns>The tick.</returns>
    private static RubyHash Keys(int id, bool accept = false, bool decline = false, bool cancel = false, bool confirm = false, bool sideways = false) =>
        new() { { "confirm", new RubyArray { id, accept, decline, cancel, confirm, sideways } } };

    /// <summary>
    /// Finds the box's event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Event(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == ConfirmModel.EventTopic).Payload.AsHash();
}
