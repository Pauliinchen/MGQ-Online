//----------------------------------------------------------------
//  FreezeFresh.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The fresh start of a frozen fight for a player without a record of their own: the world's entry
/// starts its event from its first command (battles_raid_freeze.rbx).
/// </summary>
public static class FreezeFresh
{
    /// <summary>
    /// The trigger of a page the action button starts.
    /// </summary>
    private const int ActionTrigger = 0;

    /// <summary>
    /// The triggers of a page that starts when touched: by the player, by the event.
    /// </summary>
    private static readonly int[] TouchTriggers = [1, 2];

    /// <summary>
    /// Plans how the world's entry of a fight starts: a cutscene's at the cutscene of the player's
    /// side, after the transfer the story enters it by; a field page from its event's own tile for a
    /// touch, from the tile in front of it for the action button, else where the player stands.
    /// </summary>
    /// <param name="ask">The entry and what the player's game shows.</param>
    /// <returns>The plan, or why it cannot start here.</returns>
    public static FreshPlan Plan(FreshAsk ask)
    {
        ArgumentNullException.ThrowIfNull(ask);
        if (ask.Scene)
        {
            FreshScene? scene = ask.Scenes.FirstOrDefault(each => each.Side is not { } side || ask.SwitchesOn.Contains(side));
            return scene is null
                ? FreshPlan.Refused("no cutscene of the player's side is known")
                : new FreshPlan(FreshStart.Scene, scene.Map, scene.Event, scene.Page, scene.Spot, null);
        }

        if (ask.Outer is not { } outer || outer.Map != ask.Map || ask.Shown != outer.Page - 1)
        {
            string name = ask.Outer is { } site ? $"[\"map\", {site.Map}, {site.Event}, {site.Page}]" : "the entry's page";
            return FreshPlan.Refused($"{name} is not the page that shows here (map {ask.Map})");
        }

        FreshStart start = ask.Trigger is { } trigger && TouchTriggers.Contains(trigger) ? FreshStart.Touch
            : ask.Trigger == ActionTrigger ? FreshStart.Action : FreshStart.Here;
        return new FreshPlan(start, outer.Map, outer.Event, outer.Page, null, null);
    }
}

/// <summary>
/// How a fresh start begins, see <see cref="FreezeFresh.Plan"/>.
/// </summary>
public enum FreshStart
{
    /// <summary>
    /// It cannot start here.
    /// </summary>
    None,

    /// <summary>
    /// The transfer into the cutscene, then its page from its first command.
    /// </summary>
    Scene,

    /// <summary>
    /// The transfer onto the event's own tile, then its page.
    /// </summary>
    Touch,

    /// <summary>
    /// The transfer onto a free tile next to the event, facing it, then its page.
    /// </summary>
    Action,

    /// <summary>
    /// Its page where the player stands.
    /// </summary>
    Here,
}

/// <summary>
/// A cutscene of a fight a fresh start may take, see <see cref="FreshAsk.Scenes"/>.
/// </summary>
/// <param name="Map">The cutscene's map.</param>
/// <param name="Event">Its event.</param>
/// <param name="Page">Its page from 1.</param>
/// <param name="Side">The side switch the story's way into it needs, null for none.</param>
/// <param name="Spot">The transfer into it: map, x, y and direction.</param>
public sealed record FreshScene(int Map, int Event, int Page, int? Side, IReadOnlyList<int> Spot);

/// <summary>
/// The world's entry a fresh start begins from and what the player's game shows.
/// </summary>
/// <param name="Scene">Whether the entry's fight runs on a cutscene map.</param>
/// <param name="Scenes">The fight's cutscenes in the order the story fights them.</param>
/// <param name="SwitchesOn">The switches that are on.</param>
/// <param name="Outer">The page that runs the fight: map, event and page from 1; null for a common event's.</param>
/// <param name="Map">The map the player stands on.</param>
/// <param name="Shown">The page the outer page's event shows here, from 0; null when the map lacks it.</param>
/// <param name="Trigger">That page's trigger, null when the map lacks it.</param>
public sealed record FreshAsk(bool Scene, IReadOnlyList<FreshScene> Scenes, IReadOnlySet<int> SwitchesOn, (int Map, int Event, int Page)? Outer, int Map, int? Shown, int? Trigger);

/// <summary>
/// How a fresh start begins, see <see cref="FreezeFresh.Plan"/>.
/// </summary>
/// <param name="Start">How, <see cref="FreshStart.None"/> when it cannot start here.</param>
/// <param name="Map">The page's map.</param>
/// <param name="Event">The page's event.</param>
/// <param name="Page">The page from 1.</param>
/// <param name="Spot">The transfer into a cutscene: map, x, y and direction; null for a field page.</param>
/// <param name="Refusal">Why it cannot start here, for the log.</param>
public sealed record FreshPlan(FreshStart Start, int Map, int Event, int Page, IReadOnlyList<int>? Spot, string? Refusal)
{
    /// <summary>
    /// Makes the plan of a fresh start that cannot begin here.
    /// </summary>
    /// <param name="why">Why, for the log.</param>
    /// <returns>The plan.</returns>
    public static FreshPlan Refused(string why) => new(FreshStart.None, 0, 0, 0, null, why);
}
