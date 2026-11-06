//----------------------------------------------------------------
//  EmoteTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the emotes, see <see cref="Emotes"/>, which the emote wheel asks.
/// </summary>
public static class EmoteTopics
{
    /// <summary>
    /// Lists the wheel's emotes: nothing in; [name, balloon or nil] each out.
    /// </summary>
    public const string List = "emote.list";

    /// <summary>
    /// Plays an emote of the player, see <see cref="Emotes.Play"/>: its place in; why it may not
    /// play out, nil when it plays.
    /// </summary>
    public const string Play = "emote.play";

    /// <summary>
    /// Tells whether another player's ghost plays their emote, see <see cref="Emotes.Ignored"/>:
    /// <c>emote</c>, <c>map</c>, <c>own_map</c> and <c>ghost</c> in; why not out, nil when it plays.
    /// </summary>
    public const string Take = "emote.take";

    /// <summary>
    /// Registers the topics on a context, with a cooldown of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        Emotes emotes = new();
        context.Register(List, (_, _) => new RubyArray(Emotes.All.Select(emote =>
            (RubyValue)new RubyArray { emote.Name, emote.Balloon is { } balloon ? (RubyValue)balloon : RubyNil.Value })));
        context.Register(Play, (host, request) => emotes.Play(request.AsInt(), host.Frame));
        context.Register(Take, (_, request) =>
        {
            RubyHash taken = request.AsHash();
            long? index = taken["emote"] is RubyInteger ? taken["emote"].AsLong() : null;
            return Emotes.Ignored(index, taken["map"].AsLong(), taken["own_map"].AsLong(), taken["ghost"].AsBool());
        });
    }
}
