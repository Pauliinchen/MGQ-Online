//----------------------------------------------------------------
//  DirectoryTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of the world directory beside the world screen's: opening a world, whose mods
/// the list then carries, and reading the list as it stands.
/// </summary>
internal static class DirectoryTopics
{
    /// <summary>
    /// Opens a world, see <see cref="WorldDirectory.Open"/>: its id in, nil or empty for none;
    /// nothing out.
    /// </summary>
    public const string Open = "directory.open";

    /// <summary>
    /// Hands out the list as it stands: nothing in; <c>state</c> ("idle", "loading", "ready" or
    /// "failed"), <c>error</c>, <c>admin</c> and <c>worlds</c> (each as
    /// <see cref="ScreenTopics.ListedValue"/> writes it) out.
    /// </summary>
    public const string List = "directory.list";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="directory">The directory, read at each call.</param>
    public static void Register(BridgeContext context, Func<WorldDirectory> directory)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(directory);
        context.Register(Open, (_, request) =>
        {
            directory().Open(request.IsNil ? string.Empty : request.AsText());
            return null;
        });
        context.Register(List, (_, _) =>
        {
            (string state, string? error, bool admin, var worlds) = directory().ListNow();
            return new RubyHash
            {
                { "state", state },
                { "error", error },
                { "admin", admin },
                { "worlds", new RubyArray(worlds.Select(world => (RubyValue)ScreenTopics.ListedValue(world))) },
            };
        });
    }
}
