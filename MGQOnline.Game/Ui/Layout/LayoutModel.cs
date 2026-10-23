//----------------------------------------------------------------
//  LayoutModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui.Layout;

/// <summary>
/// A place on the screen: its left, top, width and height.
/// </summary>
/// <param name="X">The left.</param>
/// <param name="Y">The top.</param>
/// <param name="Width">The width.</param>
/// <param name="Height">The height.</param>
public readonly record struct LayoutRect(int X, int Y, int Width, int Height)
{
    /// <summary>
    /// Tells whether a point lies inside.
    /// </summary>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>Whether it does.</returns>
    public bool Contains(int x, int y) => x >= X && x < X + Width && y >= Y && y < Y + Height;

    /// <summary>
    /// Writes the place as the scripts read it.
    /// </summary>
    /// <returns>[x, y, width, height].</returns>
    public RubyArray ToValue() => [X, Y, Width, Height];
}

/// <summary>
/// How a box resizes: both ways, in width alone, its height following what it shows, or not at all.
/// </summary>
public enum LayoutResize
{
    /// <summary>Both ways.</summary>
    Both,

    /// <summary>In width alone.</summary>
    Width,

    /// <summary>Not at all.</summary>
    None,
}

/// <summary>
/// Where the mod's floating boxes lie and how large they are (MGQ_MpUi::Layout in the scripts),
/// which the player changes with the left Alt held: a drag inside a box moves it, a drag on its edge
/// or corner resizes it, a double click puts it back where it starts. Each box keeps its place in
/// Player.ini, which the scripts read and write, never smaller than the least it needs.
/// </summary>
public sealed class LayoutModel : IUiModel
{
    /// <summary>
    /// Makes a box movable: [id, name, least width, least height, "both", "width" or "none", its
    /// place in Player.ini as "x,y,width,height" or nil], answering whether the player moved it.
    /// </summary>
    public const string RegisterTopic = "ui.layout.register";

    /// <summary>
    /// Tells where a box draws: [id, x, y, width, height of its default, the screen's width and
    /// height, its place in Player.ini or nil, or false when handed over before], answering
    /// [x, y, width, height, whether the player moved it].
    /// </summary>
    public const string RectTopic = "ui.layout.rect";

    /// <summary>
    /// Puts a box back where it starts: [id], answering where it draws then.
    /// </summary>
    public const string ResetTopic = "ui.layout.reset";

    /// <summary>
    /// The layout's event: {"rects" => {id => [x, y, width, height]} of the boxes whose place
    /// changed, "store" => {id => "x,y,width,height" or nil} for Player.ini, "dragging", "overlay"
    /// (the ids outlined while Alt is held, nil once it is let go), "hot", "log"}.
    /// </summary>
    public const string EventTopic = "ui.layout";

    /// <summary>
    /// Pixels inside a box's border on which a drag resizes it rather than moving it.
    /// </summary>
    public const int Grab = 8;

    /// <summary>
    /// Ticks within which a second click counts as a double click.
    /// </summary>
    public const int DoubleClickTicks = 24;

    /// <summary>
    /// Pixels a double click's second click may lie from the first, along either axis.
    /// </summary>
    public const int DoubleClickReach = 6;

    /// <summary>
    /// The host the layout posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The registered boxes by their ids.
    /// </summary>
    private readonly Dictionary<string, Box> _boxes = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the player left each box, null for one at its default, by the boxes' ids.
    /// </summary>
    private readonly Dictionary<string, LayoutRect?> _stored = new(StringComparer.Ordinal);

    /// <summary>
    /// Each box's last default, which its place is fitted against.
    /// </summary>
    private readonly Dictionary<string, LayoutRect> _defaults = new(StringComparer.Ordinal);

    /// <summary>
    /// The screen's width.
    /// </summary>
    private int _screenWidth = 640;

    /// <summary>
    /// The screen's height.
    /// </summary>
    private int _screenHeight = 480;

    /// <summary>
    /// The drag under way, null for none.
    /// </summary>
    private Drag? _drag;

    /// <summary>
    /// The last click with Alt: its box, where and when, null after a double click or a drag kept.
    /// </summary>
    private (string Id, int X, int Y, long Tick)? _lastClick;

    /// <summary>
    /// What the last event said of the overlay, so an unchanged overlay posts nothing.
    /// </summary>
    private string? _overlay;

    /// <summary>
    /// Creates the layout and registers its topics.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    public LayoutModel(UiHost host)
    {
        ArgumentNullException.ThrowIfNull(host);
        _host = host;
        BridgeContext context = host.Context;
        context.Register(RegisterTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            string id = args[0].AsText();
            _boxes[id] = new Box(args[1].AsText(), args[2].AsInt(), args[3].AsInt(), ResizeOf(args[4].AsText()));
            Keep(id, args[5]);
            return Moved(id);
        });
        context.Register(RectTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            string id = args[0].AsText();
            _defaults[id] = new LayoutRect(args[1].AsInt(), args[2].AsInt(), args[3].AsInt(), args[4].AsInt());
            _screenWidth = args[5].AsInt();
            _screenHeight = args[6].AsInt();
            if (args[7] is not RubyBool { Flag: false })
            {
                Keep(id, args[7]);
            }

            RubyArray place = Place(id).ToValue();
            place.Add(Moved(id));
            return place;
        });
        context.Register(ResetTopic, (_, request) =>
        {
            string id = request.AsArray()[0].AsText();
            _stored[id] = null;
            if (_drag?.Id == id)
            {
                _drag = null;
            }

            return Place(id).ToValue();
        });
    }

    /// <inheritdoc />
    public string Name => "layout";

    /// <summary>
    /// Reads the place a text of Player.ini keeps: four whole numbers split by commas.
    /// </summary>
    /// <param name="text">The text, such as "20,30,300,120".</param>
    /// <returns>The place, null for a text that names none.</returns>
    public static LayoutRect? Parse(string? text)
    {
        // Ruby's split drops the empty fields at the end.
        string[] parts = (text ?? string.Empty).Split(',');
        int count = parts.Length;
        while (count > 0 && parts[count - 1].Length == 0)
        {
            count--;
        }

        parts = parts[..count];
        var numbers = new int[parts.Length];
        for (int index = 0; index < parts.Length; index++)
        {
            string part = parts[index].Trim(' ', '\t', '\n', '\v', '\f', '\r', '\0');
            bool whole = part.Length > 0 && part.TrimStart('-').Length > 0 && part.Skip(part[0] == '-' ? 1 : 0).All(char.IsAsciiDigit);
            if (!whole || !int.TryParse(part, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out numbers[index]))
            {
                return null;
            }
        }

        return numbers.Length == 4 ? new LayoutRect(numbers[0], numbers[1], numbers[2], numbers[3]) : null;
    }

    /// <summary>
    /// Follows a frame while Alt is held or a drag runs: [Alt held, the left button held, it went
    /// down, the mouse's x and y or nil, the screen's width and height, the boxes shown as
    /// [id, x, y, width, height, depth]].
    /// </summary>
    /// <param name="input">The owner's input.</param>
    public void Tick(RubyValue input)
    {
        RubyArray values = input.AsArray();
        bool alt = values[0].AsBool();
        bool held = values[1].AsBool();
        bool wentDown = values[2].AsBool();
        (int X, int Y)? position = values[3].IsNil ? null : (values[3].AsInt(), values[4].AsInt());
        _screenWidth = values[5].AsInt();
        _screenHeight = values[6].AsInt();
        List<Offer> offers = [.. values[7].AsArray().Select(OfferOf)];
        var change = new RubyHash();
        if (_drag is not null)
        {
            Follow(position, held, change);
        }
        else if (alt && wentDown && position is { } point)
        {
            StartDrag(offers, point, change);
        }

        ShowOverlay(alt || _drag is not null ? offers : [], position, change);
        if (change.Count > 0)
        {
            _host.Post(EventTopic, change);
        }
    }

    /// <summary>
    /// Fits a box's place: at least its least size, at most the screen, wholly on the screen; a box
    /// that resizes in width alone, or not at all, keeps its default's height, or its width too.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="rect">Its place.</param>
    /// <param name="fallback">Where it starts.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The fitted place.</returns>
    internal static LayoutRect Fit(Box box, LayoutRect rect, LayoutRect fallback, int screenWidth, int screenHeight)
    {
        int width = box.Resize == LayoutResize.None ? fallback.Width : rect.Width;
        int height = box.Resize == LayoutResize.Both ? rect.Height : fallback.Height;
        width = Within(width, box.MinWidth, screenWidth);
        height = Within(height, box.MinHeight, screenHeight);
        return OnScreen(rect with { Width = width, Height = height }, screenWidth, screenHeight);
    }

    /// <summary>
    /// Keeps a place wholly on the screen, its size as it is.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The place moved onto the screen.</returns>
    internal static LayoutRect OnScreen(LayoutRect rect, int screenWidth, int screenHeight)
    {
        int width = Math.Min(rect.Width, screenWidth);
        int height = Math.Min(rect.Height, screenHeight);
        return new LayoutRect(Within(rect.X, 0, screenWidth - width), Within(rect.Y, 0, screenHeight - height), width, height);
    }

    /// <summary>
    /// Keeps a value between two bounds, the upper winning, as MGQ_MpUi.within does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="low">The lower bound.</param>
    /// <param name="high">The upper bound.</param>
    /// <returns>The value, or the bound it passed.</returns>
    private static int Within(int value, int low, int high) => Math.Min(Math.Max(value, low), high);

    /// <summary>
    /// Reads how a box resizes.
    /// </summary>
    /// <param name="text">"both", "width" or "none"; anything else is both.</param>
    /// <returns>The way.</returns>
    private static LayoutResize ResizeOf(string text) => text switch
    {
        "width" => LayoutResize.Width,
        "none" => LayoutResize.None,
        _ => LayoutResize.Both,
    };

    /// <summary>
    /// Reads a box offered in a frame.
    /// </summary>
    /// <param name="value">[id, x, y, width, height, depth].</param>
    /// <returns>The offer.</returns>
    private static Offer OfferOf(RubyValue value)
    {
        RubyArray item = value.AsArray();
        return new Offer(item[0].AsText(), new LayoutRect(item[1].AsInt(), item[2].AsInt(), item[3].AsInt(), item[4].AsInt()), item[5].AsInt());
    }

    /// <summary>
    /// Finds the topmost box under a point.
    /// </summary>
    /// <param name="offers">The boxes shown.</param>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>The box, null for none.</returns>
    private static Offer? TopOffer(List<Offer> offers, int x, int y)
    {
        Offer? top = null;
        foreach (Offer offer in offers)
        {
            // The first of the deepest wins, as Ruby's max_by keeps.
            if (offer.Rect.Contains(x, y) && (top is null || offer.Z > top.Z))
            {
                top = offer;
            }
        }

        return top;
    }

    /// <summary>
    /// Moves the two ends of a span by a drag, keeping it at least its least length and within
    /// 0..limit; the end that does not move stays put.
    /// </summary>
    /// <param name="low">Its start.</param>
    /// <param name="high">Its end.</param>
    /// <param name="lowStep">How far its start moves.</param>
    /// <param name="highStep">How far its end moves.</param>
    /// <param name="least">Its least length.</param>
    /// <param name="limit">Where the screen ends.</param>
    /// <returns>The new start and end.</returns>
    private static (int Low, int High) Span(int low, int high, int lowStep, int highStep, int least, int limit)
    {
        least = Math.Min(least, limit);
        if (lowStep != 0)
        {
            low = Within(low + lowStep, 0, high - least);
        }
        else if (highStep != 0)
        {
            high = Within(high + highStep, low + least, limit);
        }

        return (low, high);
    }

    /// <summary>
    /// Keeps the place Player.ini names for a box.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="text">The text, nil for none.</param>
    private void Keep(string id, RubyValue text) => _stored[id] = Parse(text.IsNil ? null : text.AsText());

    /// <summary>
    /// Finds the box of an id, a box that never registered resizing both ways from nothing.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="resize">How an unregistered box resizes.</param>
    /// <returns>The box.</returns>
    private Box BoxOf(string id, LayoutResize resize) => _boxes.TryGetValue(id, out Box? box) ? box : new Box(id, 0, 0, resize);

    /// <summary>
    /// Tells whether the player moved a box from its default.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>Whether they did.</returns>
    private bool Moved(string id) => _stored.TryGetValue(id, out LayoutRect? kept) && kept is not null;

    /// <summary>
    /// Tells where a box draws: where it is being dragged, else where the player left it, else its
    /// default, at least its least size and wholly on the screen.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The place.</returns>
    private LayoutRect Place(string id)
    {
        if (_drag?.Id == id)
        {
            return _drag.Rect;
        }

        LayoutRect fallback = _defaults.TryGetValue(id, out LayoutRect given) ? given : default;
        LayoutRect? kept = _stored.TryGetValue(id, out LayoutRect? stored) ? stored : null;
        return Fit(BoxOf(id, LayoutResize.Both), kept ?? fallback, fallback, _screenWidth, _screenHeight);
    }

    /// <summary>
    /// Starts a drag on the topmost box under the mouse, or puts it back on a double click.
    /// </summary>
    /// <param name="offers">The boxes shown.</param>
    /// <param name="point">Where the mouse went down.</param>
    /// <param name="change">The frame's event.</param>
    private void StartDrag(List<Offer> offers, (int X, int Y) point, RubyHash change)
    {
        if (TopOffer(offers, point.X, point.Y) is not { } offer)
        {
            return;
        }

        if (_lastClick is { } last && last.Id == offer.Id && _host.Now - last.Tick <= DoubleClickTicks
            && Math.Abs(point.X - last.X) <= DoubleClickReach && Math.Abs(point.Y - last.Y) <= DoubleClickReach)
        {
            _lastClick = null;
            _stored[offer.Id] = null;
            Changed(change, "store", offer.Id, RubyNil.Value);
            Changed(change, "rects", offer.Id, Place(offer.Id).ToValue());
            Logged(change, $"put {NameOf(offer.Id)} back (a double click with Alt)");
            return;
        }

        _lastClick = (offer.Id, point.X, point.Y, _host.Now);
        _drag = new Drag(offer.Id, point, offer.Rect, SidesAt(BoxOf(offer.Id, LayoutResize.None), offer.Rect, point)) { Rect = offer.Rect };
        change["dragging"] = true;
    }

    /// <summary>
    /// Finds which sides of a box a drag from a point resizes: those whose border within
    /// <see cref="Grab"/> the point lies on, as the box resizes; none moves the box.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="rect">Where it lies.</param>
    /// <param name="point">The point.</param>
    /// <returns>Left, top, right and bottom.</returns>
    private static (bool Left, bool Top, bool Right, bool Bottom) SidesAt(Box box, LayoutRect rect, (int X, int Y) point)
    {
        if (box.Resize == LayoutResize.None)
        {
            return default;
        }

        bool left = point.X < rect.X + Grab;
        bool right = point.X >= rect.X + rect.Width - Grab;
        bool top = box.Resize == LayoutResize.Both && point.Y < rect.Y + Grab;
        bool bottom = box.Resize == LayoutResize.Both && point.Y >= rect.Y + rect.Height - Grab;
        return (left, top, right && !left, bottom && !top);
    }

    /// <summary>
    /// Follows the mouse while a drag runs and keeps the box's place once the button is let go.
    /// </summary>
    /// <param name="position">Where the mouse points, null outside the window.</param>
    /// <param name="held">Whether the left button is still held.</param>
    /// <param name="change">The frame's event.</param>
    private void Follow((int X, int Y)? position, bool held, RubyHash change)
    {
        Drag drag = _drag!;
        if (position is { } point)
        {
            LayoutRect moved = Dragged(BoxOf(drag.Id, LayoutResize.None), drag, point);
            if (moved != drag.Rect)
            {
                drag.Rect = moved;
                Changed(change, "rects", drag.Id, moved.ToValue());
            }
        }

        if (!held)
        {
            Finish(drag, change);
        }
    }

    /// <summary>
    /// Finds a dragged box's place: moved by how far the mouse went, or its sides that follow the
    /// mouse moved, never past its least size and never off the screen.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="drag">The drag.</param>
    /// <param name="point">Where the mouse points.</param>
    /// <returns>The place.</returns>
    private LayoutRect Dragged(Box box, Drag drag, (int X, int Y) point)
    {
        int dx = point.X - drag.Start.X;
        int dy = point.Y - drag.Start.Y;
        LayoutRect origin = drag.Origin;
        (bool left, bool top, bool right, bool bottom) = drag.Sides;
        if (!(left || top || right || bottom))
        {
            return OnScreen(origin with { X = origin.X + dx, Y = origin.Y + dy }, _screenWidth, _screenHeight);
        }

        (int x1, int x2) = Span(origin.X, origin.X + origin.Width, left ? dx : 0, right ? dx : 0, box.MinWidth, _screenWidth);
        (int y1, int y2) = Span(origin.Y, origin.Y + origin.Height, top ? dy : 0, bottom ? dy : 0, box.MinHeight, _screenHeight);
        return new LayoutRect(x1, y1, x2 - x1, y2 - y1);
    }

    /// <summary>
    /// Ends a drag, keeping the box's place for Player.ini unless it never moved.
    /// </summary>
    /// <param name="drag">The drag.</param>
    /// <param name="change">The frame's event.</param>
    private void Finish(Drag drag, RubyHash change)
    {
        _drag = null;
        change["dragging"] = false;
        if (drag.Rect == drag.Origin)
        {
            return;
        }

        LayoutRect rect = drag.Rect;
        _stored[drag.Id] = rect;
        _lastClick = null;
        Changed(change, "store", drag.Id, string.Create(CultureInfo.InvariantCulture, $"{rect.X},{rect.Y},{rect.Width},{rect.Height}"));
        Changed(change, "rects", drag.Id, Place(drag.Id).ToValue());
        bool resized = drag.Sides.Left || drag.Sides.Top || drag.Sides.Right || drag.Sides.Bottom;
        Logged(change, string.Create(CultureInfo.InvariantCulture, $"{(resized ? "resized" : "moved")} {NameOf(drag.Id)} to {rect.X},{rect.Y} at {rect.Width}x{rect.Height}"));
    }

    /// <summary>
    /// Says which boxes the overlay outlines and which one it washes, once that changed.
    /// </summary>
    /// <param name="offers">The boxes to outline, none while Alt is let go.</param>
    /// <param name="position">Where the mouse points.</param>
    /// <param name="change">The frame's event.</param>
    private void ShowOverlay(List<Offer> offers, (int X, int Y)? position, RubyHash change)
    {
        string? hot = _drag?.Id ?? (position is { } point ? TopOffer(offers, point.X, point.Y)?.Id : null);
        string? shown = offers.Count == 0 ? null : string.Join(",", offers.Select(offer => offer.Id).Order(StringComparer.Ordinal)) + "|" + hot;
        if (shown == _overlay)
        {
            return;
        }

        _overlay = shown;
        var ids = new RubyArray();
        foreach (Offer offer in offers)
        {
            ids.Add(offer.Id);
        }

        change["overlay"] = shown is null ? RubyNil.Value : ids;
        change["hot"] = hot;
    }

    /// <summary>
    /// Names a box for the log.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>Its name.</returns>
    private string NameOf(string id) => _boxes.TryGetValue(id, out Box? box) ? box.Name : id;

    /// <summary>
    /// Adds a box's change to the frame's event.
    /// </summary>
    /// <param name="change">The event.</param>
    /// <param name="kind">"rects" or "store".</param>
    /// <param name="id">The box.</param>
    /// <param name="value">What changed.</param>
    private static void Changed(RubyHash change, string kind, string id, RubyValue value)
    {
        if (!change.TryGetValue(kind, out RubyValue? group))
        {
            group = new RubyHash();
            change[kind] = group;
        }

        group.AsHash()[id] = value;
    }

    /// <summary>
    /// Adds a line for the log to the frame's event.
    /// </summary>
    /// <param name="change">The event.</param>
    /// <param name="line">The line.</param>
    private static void Logged(RubyHash change, string line)
    {
        if (!change.TryGetValue("log", out RubyValue? lines))
        {
            lines = new RubyArray();
            change["log"] = lines;
        }

        lines.AsArray().Add(line);
    }

    /// <summary>
    /// A box the player can move: its name, its least size and how it resizes.
    /// </summary>
    /// <param name="Name">Its name for the log.</param>
    /// <param name="MinWidth">The narrowest it gets.</param>
    /// <param name="MinHeight">The lowest it gets.</param>
    /// <param name="Resize">How it resizes.</param>
    internal sealed record Box(string Name, int MinWidth, int MinHeight, LayoutResize Resize);

    /// <summary>
    /// Where a box drew in a frame, its depth deciding which of two overlapping boxes a click takes.
    /// </summary>
    /// <param name="Id">The box.</param>
    /// <param name="Rect">Where.</param>
    /// <param name="Z">Its depth.</param>
    private sealed record Offer(string Id, LayoutRect Rect, int Z);

    /// <summary>
    /// A drag under way: its box, where the mouse went down, the box's place then and which sides
    /// follow the mouse (none to move it), and the place it has now.
    /// </summary>
    /// <param name="Id">The box.</param>
    /// <param name="Start">Where the mouse went down.</param>
    /// <param name="Origin">The box's place then.</param>
    /// <param name="Sides">Left, top, right and bottom.</param>
    private sealed record Drag(string Id, (int X, int Y) Start, LayoutRect Origin, (bool Left, bool Top, bool Right, bool Bottom) Sides)
    {
        /// <summary>Gets or sets the place the box has now.</summary>
        public LayoutRect Rect { get; set; }
    }
}
