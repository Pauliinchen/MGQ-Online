//----------------------------------------------------------------
//  IEventState.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Events;

/// <summary>
/// The live values the event sorter reads: the switches and variables a branch checks, and which
/// switches and variables are each player's own.
/// </summary>
public interface IEventState
{
    /// <summary>
    /// Reads a switch.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is on.</returns>
    bool Switch(long id);

    /// <summary>
    /// Reads a variable as a whole number, as Ruby's <c>to_i</c> does.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its value, <see langword="null"/> for one that is no number, which no branch on it can tell.</returns>
    long? Variable(long id);

    /// <summary>
    /// Tells whether a switch is the player's own, which a page that sets it does not move the story with.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is.</returns>
    bool PersonalSwitch(long id);

    /// <summary>
    /// Tells whether a variable is the player's own, such as affection.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Whether it is.</returns>
    bool PersonalVariable(long id);
}
