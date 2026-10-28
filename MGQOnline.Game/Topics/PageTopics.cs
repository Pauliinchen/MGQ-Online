//----------------------------------------------------------------
//  PageTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ids;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.Telling;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a story's pages (<see cref="StoryPages"/>), which both hosts answer through
/// <see cref="SharedTopics"/>, since coop_events.rbx loads on the battle server too. Every frame is
/// the context's. A page goes over the wire as its fields: <c>page</c> (its id), <c>face</c>,
/// <c>index</c>, <c>background</c>, <c>position</c>, and <c>lines</c> and <c>choices</c>, each
/// line in Base64 and joined by commas.
/// </summary>
public static class PageTopics
{
    /// <summary>
    /// Takes a page the teller's story shows: <c>lines</c>, <c>choices</c>, <c>face</c>,
    /// <c>index</c>, <c>background</c>, <c>position</c> and <c>skip</c> in; nil for an empty page or
    /// the one shown already, else <c>id</c>, <c>told</c> (false while it is kept), <c>skipped</c>,
    /// <c>fields</c> and <c>note</c> (what the log says of it) out.
    /// </summary>
    public const string Show = "pages.show";

    /// <summary>
    /// Takes that the teller moved past the page shown: the id of the page whose end goes out now,
    /// or nil.
    /// </summary>
    public const string Passed = "pages.passed";

    /// <summary>
    /// Tells the page kept while the player skipped once it is due: <c>skip</c>, <c>telling</c> and
    /// <c>map</c> (whether the map's scene shows) in; nil, or <c>id</c>, <c>skipped</c>,
    /// <c>passed</c>, <c>fields</c> and <c>note</c> out.
    /// </summary>
    public const string Flush = "pages.flush";

    /// <summary>
    /// Takes that a new telling of the player starts.
    /// </summary>
    public const string TellingStarts = "pages.telling_starts";

    /// <summary>
    /// Keeps a page of another player's story: its fields and <c>name</c> (the teller's) in;
    /// <c>lines</c>, <c>choices</c>, <c>waiting</c> and <c>dropped</c> out, or <c>refused</c> (why)
    /// for a page without text or one whose lines do not read.
    /// </summary>
    public const string Hear = "pages.hear";

    /// <summary>
    /// Takes that the teller moved past a page: <c>page</c> in.
    /// </summary>
    public const string Done = "pages.done";

    /// <summary>
    /// Forgets the pages heard of a former teller: how many waited out.
    /// </summary>
    public const string Forget = "pages.forget";

    /// <summary>
    /// Shows the next page heard once the player is free: <c>giving_way</c> (what waits for the
    /// player, or nil) and <c>sharing</c> in; nil while none waits, else <c>show</c> (the page's
    /// <c>page</c>, <c>face</c>, <c>index</c>, <c>background</c>, <c>position</c> and <c>lines</c>,
    /// or nil), <c>skipped</c>, <c>passed</c>, <c>dropped</c> and <c>waiting</c> out.
    /// </summary>
    public const string Next = "pages.next";

    /// <summary>
    /// Tells whether the page the window holds is over: <c>teller</c> (the teller's name, nil once
    /// they are no longer the player's), <c>telling</c>, <c>raid</c>, <c>giving_way</c>,
    /// <c>confirm</c> and <c>skip</c> in; <c>over</c> and <c>reason</c> (the first time) out.
    /// </summary>
    public const string Over = "pages.over";

    /// <summary>
    /// Takes that the window finished the page it held, or an event cut it short: its id, or nil.
    /// </summary>
    public const string Ended = "pages.ended";

    /// <summary>
    /// The length of a teller's session id, which page ids start with.
    /// </summary>
    public const int SessionLength = 6;

    /// <summary>
    /// How much of a page's first line the teller's log shows.
    /// </summary>
    public const int NotedChars = 60;

    /// <summary>
    /// The characters strict Base64 holds besides letters and digits.
    /// </summary>
    private const string Base64Signs = "+/=";

    /// <summary>
    /// Registers the topics on a context, over pages of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="random">The context's randomness, which makes the session id.</param>
    public static void Register(BridgeContext context, Random random)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(random);
        var pages = new StoryPages(() => RandomId.Of(random, SessionLength, RandomId.MaxRadix));
        context.Register(Show, (host, request) => ShowOf(pages, request.AsHash(), host.Frame));
        context.Register(Passed, (_, _) => pages.Passed());
        context.Register(Flush, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            return pages.Flush(Flag(fields["skip"]), Flag(fields["telling"]), Flag(fields["map"]), host.Frame) is { } told
                ? Told(told.Id, told.Page, told.Skipped, told.Passed)
                : null;
        });
        context.Register(TellingStarts, (_, _) =>
        {
            pages.TellingStarts();
            return null;
        });
        context.Register(Hear, (_, request) => HearOf(pages, request.AsHash()));
        context.Register(Done, (_, request) =>
        {
            pages.Done(request.AsHash()["page"].AsText());
            return null;
        });
        context.Register(Forget, (_, _) => pages.Forget());
        context.Register(Next, (host, request) => NextOf(pages, request.AsHash(), host.Frame));
        context.Register(Over, (host, request) =>
        {
            RubyHash fields = request.AsHash();
            PageOver over = pages.Over(Text(fields["teller"]), Flag(fields["telling"]), Flag(fields["raid"]), Text(fields["giving_way"]), Flag(fields["confirm"]), Flag(fields["skip"]), host.Frame);
            return new RubyHash { { "over", over.Over }, { "reason", over.Reason } };
        });
        context.Register(Ended, (_, _) => pages.Ended());
    }

    /// <summary>
    /// Writes a page's lines as the wire takes them: each line's UTF-8 in Base64, joined by commas.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <returns>The text.</returns>
    public static string Encode(IReadOnlyList<string> lines)
    {
        ArgumentNullException.ThrowIfNull(lines);
        return string.Join(',', lines.Select(line => Convert.ToBase64String(Encoding.UTF8.GetBytes(line))));
    }

    /// <summary>
    /// Reads a page's lines off the wire as the script read them: split by commas as Ruby's
    /// split(",") does, which leaves out empty parts at the end, each in strict Base64.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The lines, <see langword="null"/> when one does not read.</returns>
    public static IReadOnlyList<string>? Decode(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        List<string> parts = [.. text.Split(',')];
        while (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        var lines = new List<string>();
        foreach (string part in parts)
        {
            if (!part.All(character => char.IsAsciiLetterOrDigit(character) || Base64Signs.Contains(character)))
            {
                return null;
            }

            byte[] bytes = new byte[part.Length];
            if (!Convert.TryFromBase64String(part, bytes, out int length))
            {
                return null;
            }

            lines.Add(Encoding.UTF8.GetString(bytes, 0, length));
        }

        return lines;
    }

    /// <summary>
    /// Answers <see cref="Show"/>.
    /// </summary>
    /// <param name="pages">The pages.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The page, or nil.</returns>
    private static RubyValue? ShowOf(StoryPages pages, RubyHash fields, long frame)
    {
        var page = new StoryPage(fields["face"].AsText(), fields["index"].AsInt(), fields["background"].AsInt(), fields["position"].AsInt(), Texts(fields["lines"]), Texts(fields["choices"]));
        if (pages.Show(page, Flag(fields["skip"]), frame) is not { } shown)
        {
            return null;
        }

        RubyHash answer = Told(shown.Id, shown.Page, shown.Skipped, false);
        answer["told"] = shown.Told;
        return answer;
    }

    /// <summary>
    /// Writes a page the teller tells or keeps.
    /// </summary>
    /// <param name="id">The page's id.</param>
    /// <param name="page">The page.</param>
    /// <param name="skipped">The pages kept before it that never went out.</param>
    /// <param name="passed">Whether the player moved past it.</param>
    /// <returns>Its <c>id</c>, <c>skipped</c>, <c>passed</c>, <c>fields</c> and <c>note</c>.</returns>
    private static RubyHash Told(string id, StoryPage page, int skipped, bool passed)
    {
        string first = page.Lines.Count > 0 ? string.Concat(page.Lines[0].EnumerateRunes().Take(NotedChars).Select(rune => rune.ToString())) : "";
        return new RubyHash
        {
            { "id", id },
            { "skipped", skipped },
            { "passed", passed },
            {
                "fields", new RubyHash
                {
                    { "page", id }, { "face", page.Face }, { "index", page.Index }, { "background", page.Background }, { "position", page.Position },
                    { "lines", Encode(page.Lines) }, { "choices", Encode(page.Choices) },
                }
            },
            { "note", $"{page.Lines.Count} lines, {page.Choices.Count} choices, face {page.Face}, first line \"{first}\"" },
        };
    }

    /// <summary>
    /// Answers <see cref="Hear"/>.
    /// </summary>
    /// <param name="pages">The pages.</param>
    /// <param name="fields">The request.</param>
    /// <returns>What was kept, or why not.</returns>
    private static RubyHash HearOf(StoryPages pages, RubyHash fields)
    {
        IReadOnlyList<string>? lines = Decode(Text(fields["lines"]) ?? "");
        IReadOnlyList<string>? choices = Decode(Text(fields["choices"]) ?? "");
        if (lines is null || choices is null)
        {
            return new RubyHash { { "refused", "its lines do not read" } };
        }

        var page = new StoryPage(Text(fields["face"]) ?? "", Number(fields["index"]), Number(fields["background"]), Number(fields["position"]), lines, choices);
        int dropped = pages.Hear(Text(fields["page"]) ?? "", Text(fields["name"]) ?? "", page);
        if (dropped < 0)
        {
            return new RubyHash { { "refused", "no text" } };
        }

        return new RubyHash { { "lines", lines.Count + (choices.Count > 0 ? 1 : 0) }, { "choices", choices.Count }, { "waiting", pages.Waiting }, { "dropped", dropped } };
    }

    /// <summary>
    /// Answers <see cref="Next"/>.
    /// </summary>
    /// <param name="pages">The pages.</param>
    /// <param name="fields">The request.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>What happened, or nil.</returns>
    private static RubyValue? NextOf(StoryPages pages, RubyHash fields, long frame)
    {
        if (pages.Next(Text(fields["giving_way"]), Flag(fields["sharing"]), frame) is not { } next)
        {
            return null;
        }

        RubyValue show = next.Show is { } page
            ? new RubyHash
            {
                { "page", page.Id }, { "face", page.Face }, { "index", page.Index }, { "background", page.Background }, { "position", page.Position },
                { "lines", new RubyArray(page.Lines.Select(line => (RubyValue)line)) },
            }
            : RubyNil.Value;
        return new RubyHash
        {
            { "show", show },
            { "skipped", new RubyArray(next.Skipped.Select(id => (RubyValue)id)) },
            { "passed", new RubyArray(next.Passed.Select(id => (RubyValue)id)) },
            { "dropped", next.Dropped },
            { "waiting", pages.Waiting },
        };
    }

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The texts, none for nil.</returns>
    private static List<string> Texts(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(text => text.AsText())];

    /// <summary>
    /// Reads a text another game sent, which may be anything.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, <see langword="null"/> for nil.</returns>
    private static string? Text(RubyValue value) => value switch
    {
        RubyNil => null,
        RubyString text => text.Text,
        _ => value.ToString(),
    };

    /// <summary>
    /// Reads a number another game sent as Ruby's to_i reads it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, 0 for one that does not read.</returns>
    private static int Number(RubyValue value) => value switch
    {
        RubyInteger number when number.Value >= int.MinValue && number.Value <= int.MaxValue => (int)number.Value,
        RubyString text => (int)BigInteger.Clamp(RubyNumbers.ToI(text.Bytes.Span), int.MinValue, int.MaxValue),
        _ => 0,
    };

    /// <summary>
    /// Reads a flag of a request, which a script may leave out.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(RubyValue value) => value is RubyBool { Flag: true };
}
