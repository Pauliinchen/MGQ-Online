//----------------------------------------------------------------
//  BuildTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Dropped the topics that wrote and read an item, which a trade's tokens in TradeTopics do
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Actors;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics that write and read characters' builds and equipped items as text (Actors),
/// so the scripts hand over and get back each character's and item's facts (<see cref="BuildPlain"/>)
/// and never the text's fields. Both hosts answer them, since the battle server rebuilds the
/// players' characters too.
/// </summary>
public static class BuildTopics
{
    /// <summary>
    /// Writes builds: {"actors" (each character's facts), "backline" (true or false for a PvP
    /// team, nil for builds alone)} in; the text out.
    /// </summary>
    public const string Write = "builds.write";

    /// <summary>
    /// Reads builds another game wrote: {"text", "limit"} in; each readable character's facts out,
    /// at most limit.
    /// </summary>
    public const string Read = "builds.read";

    /// <summary>
    /// Writes the fingerprint of the game's data and the build format: the sizes of the databases
    /// a build names in; the fingerprint out.
    /// </summary>
    public const string Game = "builds.game";

    /// <summary>
    /// What a log line of the topics starts with, as the scripts' lines of the builds do.
    /// </summary>
    private const string LogTag = "actors: ";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Write, (_, request) => BuildsText(request.AsHash()));
        context.Register(Read, (each, request) => BuildsOf(each, request.AsHash()));
        context.Register(Game, (_, request) => BuildText.Game(request.AsArray().Select(size => size.AsLong())));
    }

    /// <summary>
    /// Answers <see cref="Write"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The builds' text.</returns>
    private static RubyValue BuildsText(RubyHash request)
    {
        RubyValue backline = request["backline"];
        return BuildText.Write(request["actors"].AsArray().Select(BuildPlain.BuildOf), backline.IsNil ? null : backline.AsBool());
    }

    /// <summary>
    /// Answers <see cref="Read"/>.
    /// </summary>
    /// <param name="context">The context, whose log takes what was left out.</param>
    /// <param name="request">The request.</param>
    /// <returns>Each character's facts.</returns>
    private static RubyArray BuildsOf(BridgeContext context, RubyHash request) =>
        new(BuildText.Read(TextOf(request["text"]), request["limit"].AsInt(), line => context.Log.Write(LogTag + line)).Select(build => (RubyValue)BuildPlain.ToPlain(build)));

    /// <summary>
    /// Takes a text another game sent, of any encoding.
    /// </summary>
    /// <param name="value">The text, nil for none.</param>
    /// <returns>The text.</returns>
    private static string TextOf(RubyValue value) => value.IsNil ? string.Empty : Encoding.UTF8.GetString(value.AsBytes().Span);
}
