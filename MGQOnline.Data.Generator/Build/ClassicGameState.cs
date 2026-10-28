//----------------------------------------------------------------
//  ClassicGameState.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Events;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The values a Classic party's game holds for the sorter: the switches on and the variables set,
/// a new game's by default, and the player's own switches and variables of a Classic party's table,
/// the side switches among them while the sides still get other rewards.
/// </summary>
/// <param name="table">The Classic party's table.</param>
/// <param name="switchesOn">The switches that are on, none for a new game.</param>
/// <param name="variables">The variables that are not 0, none for a new game.</param>
internal sealed class ClassicGameState(StoryTable table, IReadOnlySet<long>? switchesOn = null, IReadOnlyDictionary<long, long>? variables = null) : IEventState
{
    /// <inheritdoc />
    public bool Switch(long id) => switchesOn?.Contains(id) == true;

    /// <inheritdoc />
    public long? Variable(long id) => variables?.GetValueOrDefault(id) ?? 0;

    /// <inheritdoc />
    public bool PersonalSwitch(long id) => IsPersonal(table.Switches, id);

    /// <inheritdoc />
    public bool PersonalVariable(long id) => IsPersonal(table.Variables, id);

    /// <summary>
    /// Tells whether a switch or variable is the player's own by its class, as story_keys.rbx's
    /// shared? tells it before the Great Decision; one beyond the table is.
    /// </summary>
    /// <param name="classes">The classes by id.</param>
    /// <param name="id">The switch or variable.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsPersonal(byte[] classes, long id)
    {
        if (id < 0 || id >= classes.Length)
        {
            return true;
        }

        var found = (StoryClass)classes[id];
        return !found.HasFlag(StoryClass.Kept) || found.HasFlag(StoryClass.Side);
    }
}
