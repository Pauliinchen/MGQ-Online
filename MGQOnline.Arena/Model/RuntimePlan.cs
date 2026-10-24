//----------------------------------------------------------------
//  RuntimePlan.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Arena.Model;

/// <summary>
/// How a boss fight plays out: its stages with their rolled skills, and every row of the battle.
/// </summary>
/// <param name="Stages">The stages in order, at least one; the first is where the battle starts.</param>
/// <param name="Rules">Every row of the battle, of all owners, in design order.</param>
public sealed record RuntimePlan(IReadOnlyList<RuntimeStage> Stages, IReadOnlyList<RuleSpec> Rules)
{
    /// <summary>
    /// The id of the one stage of a battle without stages.
    /// </summary>
    public const string MainStage = "main";

    /// <summary>
    /// Makes the plan of a battle without stages.
    /// </summary>
    /// <param name="actions">The rolled skills per enemy slot.</param>
    /// <param name="rules">Every row of the battle.</param>
    /// <returns>The plan, its one stage <see cref="MainStage"/>.</returns>
    public static RuntimePlan OneStage(IReadOnlyDictionary<string, IReadOnlyList<RuntimeAction>> actions, IReadOnlyList<RuleSpec> rules) =>
        new([new RuntimeStage(MainStage, string.Empty, actions)], rules);

    /// <summary>
    /// Gives the rolled skills of an enemy slot in a stage: the stage's own list, else that of the
    /// nearest stage before it that sets one.
    /// </summary>
    /// <param name="stage">The stage id; an unknown id counts as the first stage.</param>
    /// <param name="slot">The enemy slot.</param>
    /// <returns>The rolled skills, none when no stage up to it sets the slot.</returns>
    public IReadOnlyList<RuntimeAction> ActionsOf(string stage, string slot)
    {
        ArgumentNullException.ThrowIfNull(stage);
        ArgumentNullException.ThrowIfNull(slot);
        int last = Math.Max(0, IndexOf(stage));
        for (int place = Math.Min(last, Stages.Count - 1); place >= 0; place--)
        {
            if (Stages[place].Actions?.TryGetValue(slot, out IReadOnlyList<RuntimeAction>? actions) == true)
            {
                return actions;
            }
        }

        return [];
    }

    /// <summary>
    /// Gives a stage's place.
    /// </summary>
    /// <param name="stage">The stage id.</param>
    /// <returns>Its index in <see cref="Stages"/>, or -1 when no stage has the id.</returns>
    public int IndexOf(string stage)
    {
        for (int place = 0; place < Stages.Count; place++)
        {
            if (string.Equals(Stages[place].Id, stage, StringComparison.Ordinal))
            {
                return place;
            }
        }

        return -1;
    }

    /// <summary>
    /// Lists the enemy slots any stage sets rolled skills for.
    /// </summary>
    /// <returns>The slots, each once, in the order they first come.</returns>
    public IEnumerable<string> Slots() =>
        Stages.SelectMany(stage => stage.Actions?.Keys ?? Enumerable.Empty<string>()).Distinct(StringComparer.Ordinal);
}

/// <summary>
/// A stage of a battle plan.
/// </summary>
/// <param name="Id">The stage id, unique within its battle.</param>
/// <param name="Name">The stage's name, empty for the one stage of a battle without stages.</param>
/// <param name="Actions">The rolled skills per enemy slot; a missing slot, or null for every slot, keeps the stage before's list.</param>
public sealed record RuntimeStage(string Id, string Name, IReadOnlyDictionary<string, IReadOnlyList<RuntimeAction>>? Actions = null);
