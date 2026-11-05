//----------------------------------------------------------------
//  ClassicGameState.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Held a new game's values only
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Events;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The values a new game of a Classic party holds for the sorter: every switch off, every variable
/// 0, and the player's own switches and variables of a Classic party's table, the side switches
/// among them while the sides still get other rewards.
/// </summary>
/// <param name="table">The Classic party's table.</param>
internal sealed class ClassicGameState(StoryTable table) : IEventState
{
    /// <inheritdoc />
    public bool Switch(long id) => false;

    /// <inheritdoc />
    public long? Variable(long id) => 0;

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
