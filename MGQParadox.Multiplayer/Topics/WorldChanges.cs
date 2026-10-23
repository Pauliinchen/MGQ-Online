//----------------------------------------------------------------
//  WorldChanges.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// Tells the scripts once a frame what changed in the worlds' models, as one Integer of bits, so they
/// ask for rows, details or steps only after a change.
/// </summary>
internal sealed class WorldChanges
{
    /// <summary>
    /// The event the bits go out with, at most one per drain.
    /// </summary>
    public const string Topic = "worlds.changed";

    /// <summary>
    /// The worlds on this PC or in the directory's list changed.
    /// </summary>
    public const int List = 1;

    /// <summary>
    /// What a world's details show changed, such as its players or the list it came with.
    /// </summary>
    public const int Details = 2;

    /// <summary>
    /// The mod catalog or the scripts in Patch changed, so the required-mods check may answer otherwise.
    /// </summary>
    public const int Mods = 4;

    /// <summary>
    /// The shared mod settings have something for the scripts to apply, lock or tell.
    /// </summary>
    public const int Settings = 8;

    /// <summary>
    /// Turning other mods off has something for the scripts to show or do.
    /// </summary>
    public const int Parking = 16;

    /// <summary>
    /// The world screen has a step for the scripts to play.
    /// </summary>
    public const int Screen = 32;

    /// <summary>
    /// The World overview's model changed.
    /// </summary>
    public const int Overview = 64;

    /// <summary>
    /// The watched revisions with their bits and the value each had at the last drain.
    /// </summary>
    private readonly List<Watched> _watched = [];

    /// <summary>
    /// The bits marked since the last drain.
    /// </summary>
    private int _pending;

    /// <summary>
    /// Creates the changes of a context and posts them at each of its drains.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public WorldChanges(BridgeContext context)
    {
        context.Events.Coalesce(Topic);
        context.EveryFrame(Flush);
    }

    /// <summary>
    /// Marks bits as changed for the next drain.
    /// </summary>
    /// <param name="bits">The bits, such as <see cref="List"/>.</param>
    public void Mark(int bits) => _pending |= bits;

    /// <summary>
    /// Marks bits at each drain whose revision differs from the one at the drain before, such as a
    /// list a network thread fetched.
    /// </summary>
    /// <param name="revision">Reads the revision, on the game thread.</param>
    /// <param name="bits">The bits a new revision marks.</param>
    public void Watch(Func<long> revision, int bits) => _watched.Add(new Watched(revision, bits) { Last = revision() });

    /// <summary>
    /// Posts the bits marked since the last drain, if any.
    /// </summary>
    /// <param name="context">The context being drained.</param>
    private void Flush(BridgeContext context)
    {
        foreach (Watched watched in _watched)
        {
            long now = watched.Revision();
            if (now != watched.Last)
            {
                watched.Last = now;
                _pending |= watched.Bits;
            }
        }

        if (_pending != 0)
        {
            context.Events.Post(Topic, _pending);
            _pending = 0;
        }
    }

    /// <summary>
    /// A revision the changes watch.
    /// </summary>
    /// <param name="Revision">Reads the revision.</param>
    /// <param name="Bits">The bits a new revision marks.</param>
    private sealed record Watched(Func<long> Revision, int Bits)
    {
        /// <summary>
        /// Gets or sets the revision at the last drain.
        /// </summary>
        public long Last { get; set; }
    }
}
