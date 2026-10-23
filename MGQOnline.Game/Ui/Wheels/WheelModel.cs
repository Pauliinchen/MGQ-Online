//----------------------------------------------------------------
//  WheelModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui.Wheels;

/// <summary>
/// A wheel on the map, the action wheel or the emote wheel: its hotkey opens and closes it, the
/// arrows held point at a choice like a joystick, which stays picked once they are let go, and
/// confirm takes it. Its owner reads the hotkey and whether the map leaves the wheel free, the wheel
/// decides the rest and posts what changed.
/// </summary>
public sealed class WheelModel : IUiModel
{
    /// <summary>
    /// The wheels' event: {"wheel", "open", "selected", "places" when opened or the choices changed,
    /// "take" when confirm took a choice, "reason" when it closed, "cues"}.
    /// </summary>
    public const string EventTopic = "ui.wheel";

    /// <summary>
    /// Closes a wheel from outside, as a choice taken does: [name].
    /// </summary>
    public const string CloseTopic = "ui.wheel.close";

    /// <summary>
    /// Places a count of choices: [count], answering their directions.
    /// </summary>
    public const string PlacesTopic = "ui.wheel.places";

    /// <summary>
    /// What the action wheel's middle choice is selected as, a direction of none.
    /// </summary>
    public const int Center = -1;

    /// <summary>
    /// The host the wheel posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The pointing of the arrows.
    /// </summary>
    private readonly WheelPointer _pointer = new();

    /// <summary>
    /// Whether a direction without a choice picks the middle, as the action wheel's does, rather
    /// than keeping the pick, as the emote wheel's does.
    /// </summary>
    private readonly bool _hasCenter;

    /// <summary>
    /// Whether confirm closes the wheel, as the emote wheel's does; the action wheel's choice closes
    /// it once it was taken.
    /// </summary>
    private readonly bool _closesOnConfirm;

    /// <summary>
    /// The directions of the choices.
    /// </summary>
    private WheelDirection[] _places = [];

    /// <summary>
    /// Whether the wheel is open.
    /// </summary>
    private bool _open;

    /// <summary>
    /// The direction picked, <see cref="Center"/> for the middle, null for none.
    /// </summary>
    private int? _selected;

    /// <summary>
    /// Creates a wheel.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    /// <param name="name">Its name in the tick and its events, such as "wheel".</param>
    /// <param name="hasCenter">Whether it has a middle choice, which a direction without a choice picks.</param>
    /// <param name="closesOnConfirm">Whether confirm closes it.</param>
    public WheelModel(UiHost host, string name, bool hasCenter, bool closesOnConfirm)
    {
        ArgumentNullException.ThrowIfNull(host);
        _host = host;
        Name = name;
        _hasCenter = hasCenter;
        _closesOnConfirm = closesOnConfirm;
    }

    /// <inheritdoc />
    public string Name { get; }

    /// <summary>
    /// Gets whether the wheel is open.
    /// </summary>
    public bool IsOpen => _open;

    /// <summary>
    /// Registers the topics every wheel shares on a context: closing one by its name and placing
    /// choices.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="wheels">The wheels.</param>
    public static void RegisterTopics(BridgeContext context, params WheelModel[] wheels)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(CloseTopic, (_, request) =>
        {
            string name = request.AsArray()[0].AsText();
            Array.Find(wheels, wheel => wheel.Name == name)?.Close();
            return null;
        });
        context.Register(PlacesTopic, (_, request) => Directions(WheelPlaces.Of(request.AsArray()[0].AsInt())));
    }

    /// <summary>
    /// Follows a frame on the map: [true, or why the wheel may not show; the hotkey went down;
    /// cancel; confirm; the arrows held; how many choices it has].
    /// </summary>
    /// <param name="input">The owner's input.</param>
    public void Tick(RubyValue input)
    {
        RubyArray values = input.AsArray();
        bool key = values[1].AsBool();
        if (values[0] is RubyString reason)
        {
            if (_open)
            {
                CloseWith(reason.Text);
            }

            return;
        }

        int count = values[5].AsInt();
        bool placesChanged = count != _places.Length;
        if (placesChanged)
        {
            _places = WheelPlaces.Of(count);
        }

        if (!_open)
        {
            if (key)
            {
                Open();
            }

            return;
        }

        if (key || values[2].AsBool())
        {
            CloseWith(key ? "its key" : "cancel", UiCue.Cancel);
            return;
        }

        Follow((WheelArrows)values[4].AsInt(), values[3].AsBool(), placesChanged);
    }

    /// <summary>
    /// Writes directions as the scripts read them.
    /// </summary>
    /// <param name="places">The directions.</param>
    /// <returns>Each direction's number.</returns>
    private static RubyArray Directions(WheelDirection[] places)
    {
        var value = new RubyArray();
        foreach (WheelDirection place in places)
        {
            value.Add((long)place);
        }

        return value;
    }

    /// <summary>
    /// Opens the wheel on its middle choice, or on none.
    /// </summary>
    private void Open()
    {
        _open = true;
        _selected = _hasCenter ? Center : null;
        _pointer.Reset();
        RubyHash state = State();
        state["places"] = Directions(_places);
        Post(state, UiCue.Cursor);
    }

    /// <summary>
    /// Points at the choice the arrows held point to and takes it on confirm.
    /// </summary>
    /// <param name="arrows">The arrows held.</param>
    /// <param name="confirm">Whether confirm went down.</param>
    /// <param name="placesChanged">Whether the choices changed this tick.</param>
    private void Follow(WheelArrows arrows, bool confirm, bool placesChanged)
    {
        int? pointed = _selected;
        if (_pointer.Steady(arrows) is { } held)
        {
            bool hasChoice = Array.IndexOf(_places, held) >= 0;
            pointed = hasChoice ? (int)held : _hasCenter ? Center : _selected;
        }

        bool moved = pointed != _selected;
        _selected = pointed;
        if (!confirm)
        {
            if (moved || placesChanged)
            {
                RubyHash state = State();
                if (placesChanged)
                {
                    state["places"] = Directions(_places);
                }

                Post(state, moved ? UiCue.Cursor : null);
            }

            return;
        }

        if (!_closesOnConfirm)
        {
            RubyHash taken = State();
            taken["take"] = Value(_selected);
            Post(taken, moved ? UiCue.Cursor : null);
            return;
        }

        _open = false;
        RubyHash closed = State();
        closed["take"] = Value(_selected);
        closed["reason"] = _selected is null ? "confirmed with nothing pointed at" : "took a choice";
        Post(closed, _selected is null ? UiCue.Cancel : null);
    }

    /// <summary>
    /// Closes the wheel from outside, without an event, as its owner closes it itself.
    /// </summary>
    private void Close() => _open = false;

    /// <summary>
    /// Closes the wheel and posts why.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    /// <param name="cue">The sound, null for none.</param>
    private void CloseWith(string reason, string? cue = null)
    {
        _open = false;
        RubyHash state = State();
        state["reason"] = reason;
        Post(state, cue);
    }

    /// <summary>
    /// Builds the wheel's state for its event.
    /// </summary>
    /// <returns>{"wheel", "open", "selected"}.</returns>
    private RubyHash State() => new() { { "wheel", Name }, { "open", _open }, { "selected", Value(_selected) } };

    /// <summary>
    /// Writes a pick as the scripts read it.
    /// </summary>
    /// <param name="selected">The pick.</param>
    /// <returns>The direction's number, -1 for the middle, nil for none.</returns>
    private static RubyValue Value(int? selected) => selected is int direction ? direction : RubyNil.Value;

    /// <summary>
    /// Posts the wheel's event with its sound.
    /// </summary>
    /// <param name="state">The event.</param>
    /// <param name="cue">The sound, null for none.</param>
    private void Post(RubyHash state, string? cue)
    {
        state[UiCue.Key] = cue is null ? new RubyArray() : new RubyArray { cue };
        _host.Post(EventTopic, state);
    }
}
