//----------------------------------------------------------------
//  UiHostTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers the frame's tick: each model gets its own input, in order, and the buttons' bits.
/// </summary>
public sealed class UiHostTests
{
    /// <summary>
    /// Asserts that a tick hands each model the input put under its name, in the order put, and
    /// that their events come out of the frame's drain.
    /// </summary>
    [Fact]
    public void Tick_HandsEachModelItsInputInOrder()
    {
        var ui = new UiContext();
        UiHost host = UiTopics.Register(ui.Context);
        var order = new List<string>();
        host.Add(new Recorder("first", order, host));
        host.Add(new Recorder("second", order, host));

        List<(string Topic, RubyValue Payload)> events = ui.Tick(new RubyHash { { "second", 2 }, { "first", 1 } });

        Assert.Equal(["second 2", "first 1"], order);
        Assert.Equal([("ui.second", (RubyValue)2), ("ui.first", (RubyValue)1)], events);
    }

    /// <summary>
    /// Asserts that a tick naming a model this build lacks is refused before any model moves.
    /// </summary>
    [Fact]
    public void Tick_RefusesAnUnknownModelBeforeAnyMoves()
    {
        var ui = new UiContext();
        UiHost host = UiTopics.Register(ui.Context);
        var order = new List<string>();
        host.Add(new Recorder("first", order, host));

        RubyHash? answer = ui.Call(UiHost.TickTopic, new RubyHash { { "first", 1 }, { "nothing", 2 } });

        Assert.Equal(BridgeEnvelope.BadRequest, answer!["error"].AsText());
        Assert.Empty(order);
    }

    /// <summary>
    /// Asserts that the buttons read their three groups of bits.
    /// </summary>
    [Fact]
    public void Buttons_ReadTriggerRepeatAndPress()
    {
        var buttons = new UiButtons((1 << (int)UiButton.Confirm) | (1 << (UiButtons.Count + (int)UiButton.Left)) | (1 << (2 * UiButtons.Count + (int)UiButton.Up)));

        Assert.Equal(
            [true, false, true, false, true, false],
            [buttons.Triggered(UiButton.Confirm), buttons.Triggered(UiButton.Left), buttons.Repeated(UiButton.Left), buttons.Repeated(UiButton.Confirm), buttons.Pressed(UiButton.Up), buttons.Pressed(UiButton.Left)]);
    }

    /// <summary>
    /// A model that notes its input and posts it back.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="order">Where it notes what it got.</param>
    /// <param name="host">The host it posts on.</param>
    private sealed class Recorder(string name, List<string> order, UiHost host) : IUiModel
    {
        /// <inheritdoc />
        public string Name => name;

        /// <inheritdoc />
        public void Tick(RubyValue input)
        {
            order.Add($"{name} {input}");
            host.Post($"ui.{name}", input);
        }
    }
}
