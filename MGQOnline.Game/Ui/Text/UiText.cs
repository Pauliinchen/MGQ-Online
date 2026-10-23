//----------------------------------------------------------------
//  UiText.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Ui.Text;

/// <summary>
/// The fonts the scripts measured (MGQ_MpUi::Glyphs) and the topics that cut and break texts by
/// them at draw time.
/// </summary>
public sealed class UiText
{
    /// <summary>
    /// Defines a font, or adds characters to one defined: {"key", "name", "size", "bold", "widths"},
    /// the name, size and boldness only when it is defined, the widths by code point.
    /// </summary>
    public const string GlyphsTopic = "ui.glyphs";

    /// <summary>
    /// Cuts a text: [key, width, text, tail, new widths or nil], answering the text cut.
    /// </summary>
    public const string CutTopic = "ui.text.cut";

    /// <summary>
    /// Breaks a text into lines at words: [key, width, text, new widths or nil], answering the lines.
    /// </summary>
    public const string WrapTopic = "ui.text.wrap";

    /// <summary>
    /// Breaks a text into lines that keep each character's place: [key, width, text, new widths or
    /// nil], answering [start, length] per line.
    /// </summary>
    public const string SpansTopic = "ui.text.spans";

    /// <summary>
    /// The event that asks the scripts to measure characters a model met that no font of theirs
    /// measured yet: {"key", "points"}.
    /// </summary>
    public const string WantedTopic = "ui.glyphs.wanted";

    /// <summary>
    /// The key of the font of cells, where every character is one cell wide, CELLS in ui.rbx.
    /// </summary>
    public const int CellsKey = 0;

    /// <summary>
    /// The fonts by their keys.
    /// </summary>
    private readonly Dictionary<int, FontGlyphs> _fonts = new() { [CellsKey] = new FontGlyphs("cells", 1, false, cells: true) };

    /// <summary>
    /// Registers the topics on the host's context, and asks for the characters met that were never
    /// measured at each drain.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    public UiText(UiHost host)
    {
        ArgumentNullException.ThrowIfNull(host);
        BridgeContext context = host.Context;
        context.EveryFrame(_ => PostMissing(host));
        context.Register(GlyphsTopic, (_, request) =>
        {
            Define(request.AsHash());
            return null;
        });
        context.Register(CutTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            FontGlyphs glyphs = Learned(args, 4);
            return TextLayout.Cut(glyphs, args[2].AsText(), args[1].AsInt(), args[3].AsText());
        });
        context.Register(WrapTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            FontGlyphs glyphs = Learned(args, 3);
            var lines = new RubyArray();
            foreach (string line in TextLayout.Wrap(glyphs, args[2].AsText(), args[1].AsInt()))
            {
                lines.Add(line);
            }

            return lines;
        });
        context.Register(SpansTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            FontGlyphs glyphs = Learned(args, 3);
            return SpansValue(TextLayout.Spans(glyphs, args[2].AsText(), args[1].AsInt()));
        });
    }

    /// <summary>
    /// Finds a font the scripts defined.
    /// </summary>
    /// <param name="key">The font's key.</param>
    /// <returns>The font.</returns>
    /// <exception cref="BridgeRequestException">No font has the key.</exception>
    public FontGlyphs Font(int key) =>
        _fonts.TryGetValue(key, out FontGlyphs? glyphs) ? glyphs : throw new BridgeRequestException(string.Create(CultureInfo.InvariantCulture, $"No font has the key {key}."));

    /// <summary>
    /// Posts the characters each font was asked for and never measured, once, for the scripts to
    /// measure.
    /// </summary>
    /// <param name="host">The host to post on.</param>
    public void PostMissing(UiHost host)
    {
        foreach ((int key, FontGlyphs glyphs) in _fonts)
        {
            if (glyphs.Missing.Count == 0)
            {
                continue;
            }

            var points = new RubyArray();
            foreach (int point in glyphs.Missing)
            {
                points.Add(point);
            }

            glyphs.ClearMissing();
            host.Post(WantedTopic, new RubyHash { { "key", key }, { "points", points } });
        }
    }

    /// <summary>
    /// Writes lines as the scripts read them.
    /// </summary>
    /// <param name="spans">The lines.</param>
    /// <returns>[start, length] per line.</returns>
    public static RubyArray SpansValue(IEnumerable<TextSpan> spans)
    {
        var value = new RubyArray();
        foreach (TextSpan span in spans)
        {
            value.Add(new RubyArray { span.Start, span.Length });
        }

        return value;
    }

    /// <summary>
    /// Defines a font or adds characters to it.
    /// </summary>
    /// <param name="request">The request, see <see cref="GlyphsTopic"/>.</param>
    private void Define(RubyHash request)
    {
        int key = request["key"].AsInt();
        if (request.ContainsKey("name"))
        {
            _fonts[key] = new FontGlyphs(request["name"].AsText(), request["size"].AsInt(), request["bold"].AsBool());
        }

        Learn(Font(key), request["widths"]);
    }

    /// <summary>
    /// Finds the font of a text request and keeps the new widths it carries.
    /// </summary>
    /// <param name="args">The request's arguments, the font's key first.</param>
    /// <param name="widthsAt">Where the new widths are, nil for none.</param>
    /// <returns>The font.</returns>
    private FontGlyphs Learned(RubyArray args, int widthsAt)
    {
        FontGlyphs glyphs = Font(args[0].AsInt());
        Learn(glyphs, args.Count > widthsAt ? args[widthsAt] : RubyNil.Value);
        return glyphs;
    }

    /// <summary>
    /// Keeps the widths of characters.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="widths">Each code point's width, nil for none.</param>
    private static void Learn(FontGlyphs glyphs, RubyValue widths)
    {
        if (widths.IsNil)
        {
            return;
        }

        foreach ((RubyValue point, RubyValue width) in widths.AsHash())
        {
            glyphs.Learn(point.AsInt(), width.AsInt());
        }
    }
}
