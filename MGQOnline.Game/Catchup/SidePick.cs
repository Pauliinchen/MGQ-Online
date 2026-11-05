//----------------------------------------------------------------
//  SidePick.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The side a player takes along in Iliasville, Alice's or Ilias's, decided once for both world
/// types: which side the player took, when to ask a player who has none of their own, what an answer
/// sets and brings, and the side a Classic member plays past the Great Decision.
/// </summary>
/// <remarks>
/// The save's note is the only memory of the side past the Great Decision, since each route sets the
/// side switches anew; a note of "" marks a save of another player's starting save, whose side
/// switches are that player's.
/// </remarks>
public static class SidePick
{
    /// <summary>
    /// The parts before the Great Decision, whose sides the player chose themselves.
    /// </summary>
    public static readonly IReadOnlyList<string> SidedParts = ["1", "2", "3"];

    /// <summary>
    /// The sides by the name the scripts and the save's note use.
    /// </summary>
    private static readonly string[] Sides = ["alice", "ilias"];

    /// <summary>
    /// Answers the topic of the side: what the player took along and whether to ask them, or, with
    /// <c>chose</c>, what their answer sets and brings.
    /// </summary>
    /// <param name="tables">The catch-up's tables, whose rules name the choice's step and each side's companion.</param>
    /// <param name="request">"own" (the player's own story, as the catch-up's snapshot holds it), "played" (the story they play, nil for their own), "note" (the save's note: "alice", "ilias", "" or nil), "leader" (a Classic member's leader's side, nil otherwise), "chose" (the side the player just answered, nil otherwise) and "gates" (for the question of a Classic world's player, see <see cref="MayAsk"/>; nil for none).</param>
    /// <returns>"side" (the side taken along, nil while unknown), "note" (the note to write, nil to leave it), "ask" (whether to ask the player), "unknown" (true while the rules that tell when to ask have not come, so the answer may change though the request does not), "took" (the leader's side to name in the question, nil for none), "switches" ([id, on] each, the side switches to set) and "companion" (the companion the answer brings, nil for none).</returns>
    public static RubyHash Answer(CatchupTables tables, RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(request);
        StoryValues own = CatchupLook.StoryOf(request["own"]) ?? new StoryValues([], [], []);
        StoryValues played = CatchupLook.StoryOf(request["played"]) ?? own;
        string? note = request["note"] is RubyString noted ? noted.Text : null;
        string? leader = SideOf(request["leader"]);
        bool unknown = tables.Rules.SideStep is null;
        if (SideOf(request["chose"]) is { } chose)
        {
            bool beforeDecision = SidesDiffer(own) && SidesDiffer(played);
            return new RubyHash
            {
                { "side", chose }, { "note", chose }, { "ask", false }, { "unknown", unknown }, { "took", RubyNil.Value },
                { "switches", beforeDecision ? SwitchesOf(chose) : [] },
                { "companion", beforeDecision && CompanionOf(chose, tables.Rules) is { } companion ? companion : RubyNil.Value },
            };
        }

        (string? side, string? write) = Taken(own, note);
        bool follows = leader is not null && !SidesDiffer(played) && (played.Switch(StoryIds.SideSwitches[0]) != (leader == Sides[0]) || played.Switch(StoryIds.SideSwitches[1]) != (leader == Sides[1]));
        bool ask = side is null && (request["gates"] is not RubyHash gates || MayAsk(gates)) && Lost(note, false, own, played, tables.Rules.SideStep, leader is not null);
        return new RubyHash
        {
            { "side", side is null ? RubyNil.Value : side }, { "note", write is null ? RubyNil.Value : write },
            { "ask", ask }, { "unknown", unknown },
            { "took", leader is not null && SidesDiffer(played) ? leader : RubyNil.Value },
            { "switches", follows ? SwitchesOf(leader!) : [] }, { "companion", RubyNil.Value },
        };
    }

    /// <summary>
    /// Reports whether a Classic world's player may be asked whom they take along now: in a Classic
    /// world, with no question open and no event of another player's playing in their game; a member
    /// who plays the leader's story only once the leader's side came and outside the leader's story
    /// scene.
    /// </summary>
    /// <param name="gates">"classic" (in a Classic world), "asking" (the question is open), "mirroring" (another player's event plays in the player's game), "guest" (the player plays the leader's story), "holdings" (the leader's side came), "led" (the party has another player as its leader) and "telling" (the leader plays a story scene).</param>
    /// <returns>Whether they may.</returns>
    public static bool MayAsk(RubyHash gates)
    {
        ArgumentNullException.ThrowIfNull(gates);
        bool On(string name) => gates[name] is RubyBool { Flag: true };
        if (!On("classic") || On("asking") || On("mirroring"))
        {
            return false;
        }

        return !On("guest") || (On("holdings") && On("led") && !On("telling"));
    }

    /// <summary>
    /// Finds the side the player took along by their own story: before the Great Decision the one its
    /// switches tell, which the save notes unless it noted one already, but none while they hold the
    /// side of another player's starting save; past it the one the save noted.
    /// </summary>
    /// <param name="own">The player's own story.</param>
    /// <param name="note">The save's note.</param>
    /// <returns>The side, <see langword="null"/> while unknown; the note to write, <see langword="null"/> to leave it.</returns>
    public static (string? Side, string? Note) Taken(StoryValues own, string? note)
    {
        ArgumentNullException.ThrowIfNull(own);
        if (!SidesDiffer(own))
        {
            return (string.IsNullOrEmpty(note) ? null : note, null);
        }

        if (note == string.Empty)
        {
            return (null, null);
        }

        string? side = own.Side;
        return (side, side is not null && note is null ? side : null);
    }

    /// <summary>
    /// Reports whether to ask the player whom they take along: their story played went past the
    /// choice in Iliasville, before the Great Decision or on a route, or the leader whose story they
    /// play holds a side, while no side they took along themselves is noted, and their own switches
    /// hold none or hold another player's.
    /// </summary>
    /// <param name="noted">The side noted: one, "" for none of their own, <see langword="null"/> for never noted.</param>
    /// <param name="otherStart">Whether the save came from another player's starting save.</param>
    /// <param name="own">The player's own story.</param>
    /// <param name="played">The story they play.</param>
    /// <param name="step">The main story's step the choice leaves, <see langword="null"/> before the tables came.</param>
    /// <param name="leaderSided">Whether the Classic leader whose story the player plays holds a side.</param>
    /// <returns>Whether to ask.</returns>
    public static bool Lost(string? noted, bool otherStart, StoryValues own, StoryValues played, long? step, bool leaderSided = false)
    {
        ArgumentNullException.ThrowIfNull(own);
        ArgumentNullException.ThrowIfNull(played);
        if (step is not { } at || noted is { Length: > 0 } || (noted is null && !otherStart && own.Side is not null))
        {
            return false;
        }

        long progress = played.Variable(StoryIds.MainProgress) ?? 0;
        return leaderSided || StoryParts.Routes.Contains(played.Part) || (SidedParts.Contains(played.Part) && progress >= at && progress <= StoryIds.BeforeDecision);
    }

    /// <summary>
    /// Reports whether the sides still differ in a story: before the Great Decision, while no route
    /// has progress.
    /// </summary>
    /// <param name="story">The story.</param>
    /// <returns>Whether they do.</returns>
    public static bool SidesDiffer(StoryValues story)
    {
        ArgumentNullException.ThrowIfNull(story);
        return StoryIds.RouteVariables.All(route => (story.Variable(route) ?? 0) == 0);
    }

    /// <summary>
    /// Reads a side the scripts name.
    /// </summary>
    /// <param name="value">"alice", "ilias" or anything else.</param>
    /// <returns>The side, <see langword="null"/> for none.</returns>
    private static string? SideOf(RubyValue value) => value is RubyString { Text: "alice" or "ilias" } side ? side.Text : null;

    /// <summary>
    /// Writes the side switches of a side.
    /// </summary>
    /// <param name="side">The side.</param>
    /// <returns>[id, on] each.</returns>
    private static RubyArray SwitchesOf(string side) =>
        new(StoryIds.SideSwitches.Select((id, at) => (RubyValue)new RubyArray { id, Sides[at] == side }));

    /// <summary>
    /// Finds the companion a side brings along.
    /// </summary>
    /// <param name="side">The side.</param>
    /// <param name="rules">The catch-up's rules.</param>
    /// <returns>The companion, <see langword="null"/> before the rules named one.</returns>
    private static int? CompanionOf(string side, CatchupRules rules) => side == Sides[0] ? rules.AliceCompanion : rules.IliasCompanion;
}
