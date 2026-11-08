//----------------------------------------------------------------
//  DllTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Told the largest free block of the address space and the DLL's heap
//                            - Posted the relay's refusals of this version as the event update.needed
//                            - Told the version this DLL runs with the release to play
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Windows;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of itself: the check for the release to play and the relay's refusals of this
/// version, whether it is a development build, and the memory the game uses.
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
    /// else <c>version</c>, <c>rollback</c> (whether it is older than this DLL) and <c>have</c> (the
    /// version this DLL runs) out.
    /// </summary>
    public const string Offer = "update.offer";

    /// <summary>
    /// Tells whether this DLL is a development build, which a bug report names: nothing in; true
    /// or false out.
    /// </summary>
    public const string DevBuild = "update.dev_build";

    /// <summary>
    /// The event of a refusal of this version by the relay, posted at the next drain after it:
    /// <c>version</c> (the release to play, nil while none is known) and <c>have</c> (the version
    /// this DLL runs) out.
    /// </summary>
    public const string NeededEvent = "update.needed";

    /// <summary>
    /// Tells the memory and the handles the game uses now: nothing in; <c>line</c> (the description
    /// for the scripts' log), <c>free_mb</c> (the address space left), <c>largest_free_mb</c> (its
    /// largest free block), both nil when Windows cannot tell, and <c>heap_mb</c> (this DLL's heap) out.
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
        context.Register(Offer, (_, _) => UpdateCheck.Offer is { } offer ? new RubyHash { { "version", offer.Version }, { "rollback", offer.Rollback }, { "have", UpdateCheck.ModVersion } } : null);
        context.Register(DevBuild, (_, _) => UpdateCheck.DevelopmentBuild);
        var told = UpdateCheck.Refusals;
        context.EveryFrame(drained =>
        {
            var refusals = UpdateCheck.Refusals;

            if (refusals != told)
            {
                told = refusals;
                drained.Events.Post(NeededEvent, new RubyHash
                {
                    { "version", UpdateCheck.Offer is { } offer ? offer.Version : RubyNil.Value },
                    { "have", UpdateCheck.ModVersion },
                });
            }
        });
        context.Register(Memory, (_, _) => new RubyHash
        {
            { "line", ProcessUsage.Describe() },
            { "free_mb", ProcessUsage.FreeAddressSpace() is { } free ? free : RubyNil.Value },
            { "largest_free_mb", ProcessUsage.LargestFreeBlock() is { } largest ? largest : RubyNil.Value },
            { "heap_mb", ProcessUsage.DllHeap() },
        });
    }
}
