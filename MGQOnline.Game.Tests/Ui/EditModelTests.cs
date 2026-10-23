//----------------------------------------------------------------
//  EditModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;
using MGQOnline.Game.Ui.Text;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers the text box being typed into through its topics: typing straight from the keyboard,
/// stopping at Enter, what the box shows once drawn, the chat's filters and the game's letters.
/// </summary>
public sealed class EditModelTests
{
    /// <summary>
    /// The key bits of Home.
    /// </summary>
    private const int Home = (int)EditKeys.Home;

    /// <summary>
    /// Asserts that a tick types what came from the keyboard and posts the text with what typing
    /// did, and that Enter stops typing until the owner acted, the rest typed in the next tick.
    /// </summary>
    [Fact]
    public void Tick_TypesFromTheKeyboardAndStopsAtEnter()
    {
        var keyboard = new Keyboard();
        var ui = new UiContext();
        UiTopics.Register(ui.Context, keyboard);
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "ab" }, { "max_chars", 4 } }).AsInt();

        keyboard.Typed.Enqueue(("cd\rxyz", 6));
        RubyHash first = Event(ui.Tick(new RubyHash { { "edit", Input(id) } }));
        RubyHash second = Event(ui.Tick(new RubyHash { { "edit", Input(id) } }));

        Assert.Equal(("abcd", 4, new RubyArray { "typed", "typed", "enter" }, 6, 6), (first["text"].AsText(), first["cursor"].AsInt(), first["outcomes"], first["keys"].AsInt(), first["chars"].AsInt()));
        Assert.Equal(("abcd", new RubyArray { "refused", "refused", "refused" }, 0), (second["text"].AsText(), second["outcomes"], second["keys"].AsInt()));
    }

    /// <summary>
    /// Asserts that a quiet box posts nothing, that closing it drops what waited, and that a tick
    /// of another box's id moves nothing.
    /// </summary>
    [Fact]
    public void Tick_PostsOnlyWhatChangedForTheOpenBox()
    {
        var keyboard = new Keyboard();
        var ui = new UiContext();
        UiTopics.Register(ui.Context, keyboard);
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "" } }).AsInt();
        keyboard.Typed.Enqueue(("a\rb", 3));
        ui.Tick(new RubyHash { { "edit", Input(id) } });

        List<(string Topic, RubyValue Payload)> quiet = ui.Tick(new RubyHash { { "edit", new RubyArray { id, -1, 0, 0, 0 } } });
        ui.Value(EditModel.CloseTopic, id);
        int next = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "" } }).AsInt();
        List<(string Topic, RubyValue Payload)> stale = ui.Tick(new RubyHash { { "edit", Input(id) } });
        RubyHash fresh = Event(ui.Tick(new RubyHash { { "edit", Input(next) } }));

        Assert.Empty(quiet);
        Assert.Empty(stale);
        Assert.Equal(("", new RubyArray()), (fresh["text"].AsText(), fresh["outcomes"]));
    }

    /// <summary>
    /// Asserts that a box drawn on one line shows the part around the cursor with the cursor's
    /// place in pixels, a password as stars, and follows the keys.
    /// </summary>
    [Fact]
    public void View_ShowsThePartAroundTheCursor()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context, new Keyboard());
        Define(ui, 1, 10);
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "abcdefgh" }, { "mask", "*" } }).AsInt();

        RubyHash drawn = ui.Value(EditModel.ViewTopic, new RubyHash { { "id", id }, { "font", 1 }, { "width", 35 }, { "rows", 0 } }).AsHash();
        RubyHash home = Event(ui.Tick(new RubyHash { { "edit", new RubyArray { id, Home, 0, 0, 0 } } }));

        Assert.Equal(new RubyArray { 5, 3, 30 }, drawn["view"].AsHash()["line"]);
        Assert.Equal(new RubyArray { 0, 3, 0 }, home["view"].AsHash()["line"]);
    }

    /// <summary>
    /// Asserts that a box of several lines shows its lines, the first in sight, the cursor's line
    /// and its place, and scrolls by the wheel.
    /// </summary>
    [Fact]
    public void View_ShowsTheLinesOfABoxOfSeveral()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context, new Keyboard());
        Define(ui, 1, 10);
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "aa bb cc dd" } }).AsInt();

        RubyArray area = ui.Value(EditModel.ViewTopic, new RubyHash { { "id", id }, { "font", 1 }, { "width", 30 }, { "rows", 2 } }).AsHash()["view"].AsHash()["area"].AsArray();
        RubyArray scrolled = Event(ui.Tick(new RubyHash { { "edit", new RubyArray { id, -1, 0, -1, 0 } } }))["view"].AsHash()["area"].AsArray();

        Assert.Equal(new RubyArray { new RubyArray { 0, 3 }, new RubyArray { 3, 3 }, new RubyArray { 6, 3 }, new RubyArray { 9, 2 } }, area[0]);
        Assert.Equal(new RubyArray { 2, 3, 20 }, new RubyArray { area[1], area[2], area[3] });
        Assert.Equal(new RubyArray { 1, 2, 20 }, new RubyArray { scrolled[1], scrolled[2], scrolled[3] });
    }

    /// <summary>
    /// Asserts the chat's filters: the opening key's character left out once, what Alt types
    /// dropped, and a locked box taking only Escape.
    /// </summary>
    [Fact]
    public void Tick_FiltersAsTheOwnerAsked()
    {
        var keyboard = new Keyboard();
        var ui = new UiContext();
        UiTopics.Register(ui.Context, keyboard);
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "" }, { "echo", new RubyArray { 'T', 3 } }, { "alt_codes", 2 } }).AsInt();

        keyboard.Typed.Enqueue(("tt", 1));
        string echoed = Event(ui.Tick(new RubyHash { { "edit", Input(id) } }))["text"].AsText();
        keyboard.Typed.Enqueue(("@", 1));
        string altHeld = Event(ui.Tick(new RubyHash { { "edit", new RubyArray { id, -1, 1, 0, 1 } } }))["text"].AsText();
        keyboard.Typed.Enqueue(("x", 1));
        string justAfter = Event(ui.Tick(new RubyHash { { "edit", Input(id) } }))["text"].AsText();
        ui.Context.Call(System.Text.Encoding.UTF8.GetBytes(EditModel.SetTopic), RubyMarshal.Write(new RubyHash { { "id", id }, { "locked", true } }), new byte[256]);
        keyboard.Typed.Enqueue(("y\r\u001b", 3));
        RubyHash locked = Event(ui.Tick(new RubyHash { { "edit", Input(id) } }));

        Assert.Equal(("t", "t", "t"), (echoed, altHeld, justAfter));
        Assert.Equal(("t", new RubyArray { "escape" }), (locked["text"].AsText(), locked["outcomes"]));
    }

    /// <summary>
    /// Asserts that the game's letters type at once, answering what typing did.
    /// </summary>
    [Fact]
    public void Type_TypesTheLettersAtOnce()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context, new Keyboard());
        int id = ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "1" }, { "allowed", new RubyArray { @"\A\d\z", false } } }).AsInt();

        RubyHash typed = ui.Value(EditModel.TypeTopic, new RubyHash { { "id", id }, { "text", "2a\b" } }).AsHash();

        Assert.Equal(new RubyHash { { "outcomes", new RubyArray { "typed", "refused", "erased" } }, { "text", "1" }, { "cursor", 1 } }, typed);
    }

    /// <summary>
    /// Defines a font in which every printable ASCII character is equally wide.
    /// </summary>
    /// <param name="ui">The context.</param>
    /// <param name="key">The font's key.</param>
    /// <param name="width">Each character's width.</param>
    private static void Define(UiContext ui, int key, int width)
    {
        var widths = new RubyHash();
        for (int point = 32; point < 127; point++)
        {
            widths.Add(point, width);
        }

        ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", key }, { "name", "test" }, { "size", 16 }, { "bold", false }, { "widths", widths } });
    }

    /// <summary>
    /// Builds a box's input that takes what was typed, without keys.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The input.</returns>
    private static RubyArray Input(int id) => [id, -1, 1, 0, 0];

    /// <summary>
    /// Finds the box's event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Event(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == EditModel.EventTopic).Payload.AsHash();

    /// <summary>
    /// A keyboard that hands out what a test queued, one take each.
    /// </summary>
    private sealed class Keyboard : ITypedText
    {
        /// <summary>
        /// Gets the takes to hand out.
        /// </summary>
        public Queue<(string Text, int Keys)> Typed { get; } = new();

        /// <inheritdoc />
        public (string Text, int Keys) Take() => Typed.Count > 0 ? Typed.Dequeue() : (string.Empty, 0);
    }
}
