//----------------------------------------------------------------
//  PartyInvite.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.World;

/// <summary>
/// The player's standing party invite: to the players nearby, and to players anywhere named by
/// their id, for a number of frames.
/// </summary>
internal sealed class PartyInvite
{
    /// <summary>
    /// Frames an invite stands, fifteen seconds at 60 frames per second.
    /// </summary>
    public const int Frames = 900;

    /// <summary>
    /// Frames an invite to a player named from afar stands, a minute: they first have to notice it in
    /// the notification box or the World overview.
    /// </summary>
    public const int NamedFrames = 3600;

    /// <summary>
    /// The ids the invite names.
    /// </summary>
    private readonly List<string> named = [];

    /// <summary>
    /// The frames the invite stands for still.
    /// </summary>
    private int frames;

    /// <summary>
    /// Gets a value indicating whether the invite stands.
    /// </summary>
    public bool Inviting => frames > 0;

    /// <summary>
    /// Gets the frames the invite stands for still, 0 while none stands.
    /// </summary>
    public int FramesLeft => Inviting ? frames : 0;

    /// <summary>
    /// Gets the ids of the players the invite reaches wherever they are, none while no invite stands.
    /// </summary>
    public IReadOnlyList<string> Targets => Inviting ? named : [];

    /// <summary>
    /// Tells whether the invite reaches another player: standing near, or named.
    /// </summary>
    /// <param name="state">What the other player last told.</param>
    /// <param name="near">Whether they stand near the player.</param>
    /// <returns>Whether it does.</returns>
    public bool Covers(WorldFields state, bool near) => Inviting && (near || named.Contains(state.Text("id"), StringComparer.Ordinal));

    /// <summary>
    /// Invites for <see cref="Frames"/> from now, or <see cref="NamedFrames"/> for a player named,
    /// keeping the targets of an invite that stands and the longer time left.
    /// </summary>
    /// <param name="targetId">The id of a player the invite reaches wherever they are.</param>
    public void Invite(string? targetId)
    {
        if (!Inviting)
        {
            named.Clear();
        }

        if (targetId is not null && !named.Contains(targetId, StringComparer.Ordinal))
        {
            named.Add(targetId);
        }

        frames = Math.Max(frames, targetId is null ? Frames : NamedFrames);
    }

    /// <summary>
    /// Stops inviting.
    /// </summary>
    public void Stop()
    {
        frames = 0;
        named.Clear();
    }

    /// <summary>
    /// Stops naming a player, as once they declined; the invite still reaches them while they stand near.
    /// </summary>
    /// <param name="targetId">Their id.</param>
    public void Drop(string targetId) => named.RemoveAll(id => id == targetId);

    /// <summary>
    /// Lets the invite run out. Called every frame.
    /// </summary>
    /// <returns>Whether it ran out this frame.</returns>
    public bool CountDown()
    {
        if (!Inviting)
        {
            return false;
        }

        frames--;
        if (Inviting)
        {
            return false;
        }

        Stop();
        return true;
    }

    /// <summary>
    /// Copies the ids the invite names now.
    /// </summary>
    /// <returns>The ids.</returns>
    public List<string> CopyTargets() => [.. Targets];

    /// <summary>
    /// Tells whether the invite names a player.
    /// </summary>
    /// <param name="id">Their id.</param>
    /// <returns>Whether it does.</returns>
    public bool Names(string id) => Targets.Any(target => target == id);
}
