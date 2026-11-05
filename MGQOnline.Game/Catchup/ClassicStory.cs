//----------------------------------------------------------------
//  ClassicStory.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// How a Classic party's member plays the leader's story (coop_story.rbx): whether both play one
/// story, how the member keeps it, and what their own story is once they leave it. A story's place
/// is its markers, the main story's progress and each route's, in the order of
/// <see cref="StoryIds.Markers"/>.
/// </summary>
public static class ClassicStory
{
    /// <summary>
    /// How far apart in the main story two players may be before the Great Decision to play one story.
    /// </summary>
    public const int SyncSteps = 2;

    /// <summary>
    /// How far apart on their route two players may be after the Great Decision to play one story.
    /// </summary>
    public const int RouteSyncSteps = 5;

    /// <summary>
    /// The member keeps the leader's story and what they play together, as far along as the leader.
    /// </summary>
    public const string Keep = "keep";

    /// <summary>
    /// The member keeps the leader's story and catches up with what it gave before, behind the leader.
    /// </summary>
    public const string CatchUp = "catch_up";

    /// <summary>
    /// The member borrows the leader's story and gets their own back unchanged, ahead of the leader.
    /// </summary>
    public const string Borrow = "borrow";

    /// <summary>
    /// Finds the route a story plays past the Great Decision: the first route with progress, the Chaos
    /// route's last, since the Great Decision itself starts it.
    /// </summary>
    /// <param name="markers">The story's place.</param>
    /// <returns>The route's place among <see cref="StoryIds.Routes"/>, <see langword="null"/> before any.</returns>
    public static int? RouteOf(IReadOnlyList<long> markers)
    {
        ArgumentNullException.ThrowIfNull(markers);
        for (int route = 0; route < StoryIds.RouteVariables.Count; route++)
        {
            if (markers[route + 1] > 0)
            {
                return route;
            }
        }

        return null;
    }

    /// <summary>
    /// Decides whether two players play one story, the same for both: before the Great Decision when
    /// both are at most <see cref="SyncSteps"/> apart in the main story, past it when both play the
    /// same route at most <see cref="RouteSyncSteps"/> apart.
    /// </summary>
    /// <param name="own">The one player's place.</param>
    /// <param name="other">The other's.</param>
    /// <returns>"synced", or why not: "apart", "decision" (one is past the Great Decision, the other before it) or "route".</returns>
    public static string SyncState(IReadOnlyList<long> own, IReadOnlyList<long> other)
    {
        ArgumentNullException.ThrowIfNull(own);
        ArgumentNullException.ThrowIfNull(other);
        bool past = own[0] >= StoryIds.GreatDecision;
        if (past != (other[0] >= StoryIds.GreatDecision))
        {
            return "decision";
        }

        if (!past)
        {
            return Math.Abs(own[0] - other[0]) <= SyncSteps ? "synced" : "apart";
        }

        int? route = RouteOf(own);
        if (route != RouteOf(other))
        {
            return "route";
        }

        return route is not { } on || Math.Abs(own[on + 1] - other[on + 1]) <= RouteSyncSteps ? "synced" : "apart";
    }

    /// <summary>
    /// Answers whether a member plays the leader's story now.
    /// </summary>
    /// <remarks>
    /// A member who keeps the leader's story plays it as far as the leader, so the leader's progress
    /// moving on never ends it.
    /// </remarks>
    /// <param name="request">"own" and "other" (the member's place and the leader's, nil while the leader's game tells none), "kept" (whether the member keeps the story of this same leader already) and "offer" (whether they accepted this leader's offer to sync the story).</param>
    /// <returns>"state" (see <see cref="SyncState"/>, or "unknown" while the leader's place is) and "route" (the leader's route past the Great Decision, its place among the routes, nil before it).</returns>
    public static RubyHash Sync(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        long[]? other = MarkersOf(request["other"]);
        string state = request["kept"] is RubyBool { Flag: true } || request["offer"] is RubyBool { Flag: true } ? "synced"
            : other is null ? "unknown"
            : SyncState(MarkersOf(request["own"]) ?? throw new BridgeRequestException("The member's own place is missing."), other);
        return new RubyHash
        {
            { "state", state },
            { "route", other is not null && other[0] >= StoryIds.GreatDecision && RouteOf(other) is { } route ? route : RubyNil.Value },
        };
    }

    /// <summary>
    /// Answers which members the leader hears about: those who start or stop following the leader's
    /// story since the last answer, and why.
    /// </summary>
    /// <remarks>
    /// A member's game may tell their progress a moment before their decision, so a member not
    /// following whom the rule finds synced, or whose place is unknown, is told about later.
    /// </remarks>
    /// <param name="request">"own" (the leader's place), "members" ([id, follows, place or nil] each) and "told" ({id => follows} as the last answer kept it, nil for none).</param>
    /// <returns>"tell" ([id, follows, state] each, see <see cref="SyncState"/>) and "told" (to hand to the next call).</returns>
    public static RubyHash Followers(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        long[] own = MarkersOf(request["own"]) ?? throw new BridgeRequestException("The leader's place is missing.");
        RubyHash before = request["told"] as RubyHash ?? [];
        var told = new RubyHash();
        var tell = new RubyArray();
        foreach (RubyValue member in request["members"].AsArray())
        {
            RubyArray fields = member.AsArray();
            RubyValue id = fields[0];
            bool follows = fields[1] is RubyBool { Flag: true };
            RubyValue known = before[id];
            if (known is RubyBool { Flag: var was } && was == follows)
            {
                told[id] = follows;
                continue;
            }

            long[]? theirs = MarkersOf(fields[2]);
            string state = follows ? "synced" : theirs is null ? "unknown" : SyncState(own, theirs);
            if (!follows && state is "synced" or "unknown")
            {
                if (!known.IsNil)
                {
                    told[id] = known;
                }

                continue;
            }

            told[id] = follows;
            tell.Add(new RubyArray { id, follows, state });
        }

        return new RubyHash { { "tell", tell }, { "told", told } };
    }

    /// <summary>
    /// Answers how a member who starts following the leader's story keeps it.
    /// </summary>
    /// <param name="request">"own" (the member's place) and "leader" (the leader's).</param>
    /// <returns>"mode" (<see cref="Keep"/>, <see cref="CatchUp"/> or <see cref="Borrow"/>), "keeps" (whether the member keeps the leader's story), "progress" ("aside" while the member's own progress is the story kept aside, else "played") and "ahead" ([variable, own, leader] each marker the member is past the leader in).</returns>
    public static RubyHash Mode(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        long[] own = MarkersOf(request["own"]) ?? throw new BridgeRequestException("The member's own place is missing.");
        long[] leader = MarkersOf(request["leader"]) ?? throw new BridgeRequestException("The leader's place is missing.");
        var ahead = new RubyArray();
        for (int at = 0; at < own.Length; at++)
        {
            if (own[at] > leader[at])
            {
                ahead.Add(new RubyArray { StoryIds.Markers[at], own[at], leader[at] });
            }
        }

        string mode = own.SequenceEqual(leader) ? Keep : ahead.Count == 0 ? CatchUp : Borrow;
        return new RubyHash { { "mode", mode }, { "keeps", mode != Borrow }, { "progress", mode == Borrow ? "aside" : "played" }, { "ahead", ahead } };
    }

    /// <summary>
    /// Answers how the member's own story is made once they leave the leader's, or for a save made
    /// meanwhile: steps the scripts take in order over the stories they keep, each [step, source].
    /// </summary>
    /// <remarks>
    /// A member as far along keeps what they played together; one who caught up keeps the leader's
    /// story with their own values where it never set one and their own chests; one ahead gets their
    /// own back, with their own side, which the leader's route replaced while they played it. Every
    /// way keeps what is the member's own of the story played.
    /// </remarks>
    /// <param name="request">"mode" (see <see cref="Mode"/>) and "partial" (whether the leader's whole story came without what it turned off).</param>
    /// <returns>"steps": "start" (the story to start from: "own", the member's own kept aside, or "played"), "recorded" (the values of the leader's story the member kept as they came), "changed" (the source's values of what the member's game changed of the story they borrowed), "fill" (the source's values where the story holds none), "chests" (every chest's self switch as the source holds it), "personal" (the member's own keys as the source holds them) and "sides" (the side switches as the source holds them).</returns>
    public static RubyHash Restore(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        string mode = request["mode"].AsText();
        bool partial = request["partial"] is RubyBool { Flag: true };
        List<(string Step, string Source)> steps = mode switch
        {
            Keep => [("start", "own"), ("recorded", "recorded"), ("changed", "played"), ("personal", "played")],
            CatchUp => [("start", "played"), ("fill", "own"), ("chests", "own"), ("personal", "played")],
            _ => [("start", "own"), ("personal", "played"), ("sides", "own")],
        };
        if (partial)
        {
            steps.Remove(("fill", "own"));
        }

        return new RubyHash { { "steps", new RubyArray(steps.Select(step => (RubyValue)new RubyArray { step.Step, step.Source })) } };
    }

    /// <summary>
    /// Lists the routes a member played: those their own story is on or finished, and the one the story
    /// they play is on.
    /// </summary>
    /// <param name="own">The member's own story.</param>
    /// <param name="played">The story they play.</param>
    /// <returns>The routes, in the order of <see cref="StoryIds.Routes"/>.</returns>
    public static IReadOnlyList<string> Routes(StoryValues own, StoryValues played)
    {
        ArgumentNullException.ThrowIfNull(own);
        ArgumentNullException.ThrowIfNull(played);
        return [.. StoryIds.Routes.Where((route, at) =>
            (played.Variable(StoryIds.RouteVariables[at]) ?? 0) > 0 || (own.Variable(StoryIds.RouteVariables[at]) ?? 0) > 0 || own.Cleared(route))];
    }

    /// <summary>
    /// Reads a place the scripts hand.
    /// </summary>
    /// <param name="value">The markers, nil for none.</param>
    /// <returns>The markers, <see langword="null"/> for none.</returns>
    /// <exception cref="BridgeRequestException">The place holds another count of markers.</exception>
    private static long[]? MarkersOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        long[] markers = [.. value.AsArray().Select(marker => marker.AsLong())];
        return markers.Length == StoryIds.Markers.Count ? markers : throw new BridgeRequestException($"A place is {StoryIds.Markers.Count} markers.");
    }
}
