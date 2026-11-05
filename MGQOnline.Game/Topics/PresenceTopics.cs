//----------------------------------------------------------------
//  PresenceTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the grace of players away outside a world's room, see <see cref="Sessions"/>,
/// which the battle server's scripts ask, since the battle channel tells the presence there.
/// </summary>
public static class PresenceTopics
{
    /// <summary>
    /// Starts the grace of a player whose connection dropped: their id in; whether it started out.
    /// </summary>
    public const string Away = "presence.away";

    /// <summary>
    /// Takes back a player whose connection came back: their id in; the frames they were away out,
    /// nil for one not kept away.
    /// </summary>
    public const string Back = "presence.back";

    /// <summary>
    /// Counts a frame of the grace: nothing in; the ids of the players who stayed away for all of it out.
    /// </summary>
    public const string Tick = "presence.tick";

    /// <summary>
    /// Forgets a player who left: their id in, nothing out.
    /// </summary>
    public const string Forget = "presence.forget";

    /// <summary>
    /// Tells the grace in frames, which the battle holds a player's missing messages for: nothing
    /// in, <see cref="Sessions.GraceFrames"/> out.
    /// </summary>
    public const string Grace = "presence.grace";

    /// <summary>
    /// Registers the topics on a context, with a grace of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The grace, for tests.</returns>
    public static Sessions Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        Sessions sessions = new();
        context.Register(Away, (_, request) => sessions.Away(request.AsText()));
        context.Register(Back, (_, request) => sessions.Back(request.AsText()) is { } frames ? (RubyValue)frames : RubyNil.Value);
        context.Register(Tick, (_, _) => new RubyArray(sessions.Tick().Select(id => (RubyValue)id)));
        context.Register(Forget, (_, request) =>
        {
            sessions.Forget(request.AsText());
            return null;
        });
        context.Register(Grace, (_, _) => Sessions.GraceFrames);
        return sessions;
    }
}
