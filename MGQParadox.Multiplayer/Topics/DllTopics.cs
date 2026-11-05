//----------------------------------------------------------------
//  DllTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of itself: the check for the release to play, whether it is a development
/// build, and the memory the game uses.
/// </summary>
internal static class DllTopics
{
    /// <summary>
    /// Starts asking the relay for the release to play, see <see cref="UpdateCheck.Start"/>: nothing
    /// in or out. Calling it again does nothing.
    /// </summary>
    public const string Check = "update.check";

    /// <summary>
    /// Hands out the release to play once the check found one: nothing in; nil while there is none,
    /// else <c>version</c> and <c>rollback</c> (whether it is older than this DLL) out.
    /// </summary>
    public const string Offer = "update.offer";

    /// <summary>
    /// Tells whether this DLL is a development build, which a bug report names: nothing in; true
    /// or false out.
    /// </summary>
    public const string DevBuild = "update.dev_build";

    /// <summary>
    /// Tells the memory and the handles the game uses now: nothing in; <c>line</c> (the description
    /// for the scripts' log) and <c>free_mb</c> (the address space left, nil when Windows cannot
    /// tell) out.
    /// </summary>
    public const string Memory = "dll.memory";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Check, (_, _) =>
        {
            UpdateCheck.Start();
            return null;
        });
        context.Register(Offer, (_, _) => UpdateCheck.Offer is { } offer ? new RubyHash { { "version", offer.Version }, { "rollback", offer.Rollback } } : null);
        context.Register(DevBuild, (_, _) => UpdateCheck.DevelopmentBuild);
        context.Register(Memory, (_, _) => new RubyHash
        {
            { "line", ProcessUsage.Describe() },
            { "free_mb", ProcessUsage.FreeAddressSpace() is { } free ? free : RubyNil.Value },
        });
    }
}
