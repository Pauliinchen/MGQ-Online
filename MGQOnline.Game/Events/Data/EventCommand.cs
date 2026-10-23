//----------------------------------------------------------------
//  EventCommand.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// One command of an event's list, as the game's RPG::EventCommand holds it.
/// </summary>
/// <param name="Code">The command's code, such as 111 for a conditional branch.</param>
/// <param name="Indent">How deep in branches it stands.</param>
/// <param name="Parameters">Its parameters; empty for the codes whose parameters no rule reads (see <see cref="EventCodes.KeepsParameters"/>), which the reader leaves out.</param>
public readonly record struct EventCommand(int Code, int Indent, RubyArray Parameters)
{
    /// <summary>
    /// The parameters of a command whose parameters were left out.
    /// </summary>
    public static readonly RubyArray NoParameters = [];

    /// <summary>
    /// Reads a parameter as a whole number as Ruby's <c>to_i</c> does for the values game data holds.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The number; 0 for a parameter that is missing or no number.</returns>
    public long Number(int index) => index < Parameters.Count ? NumberOf(Parameters[index]) : 0;

    /// <summary>
    /// Reads a parameter as text, as Ruby's <c>to_s</c> does for a String; anything else reads as empty.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The text.</returns>
    public string Text(int index) => index < Parameters.Count && Parameters[index] is RubyString text ? text.Text : string.Empty;

    /// <summary>
    /// Gets a parameter as it was read.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The value, nil for a parameter that is missing.</returns>
    public RubyValue Parameter(int index) => index < Parameters.Count ? Parameters[index] : RubyNil.Value;

    /// <summary>
    /// Reads a value as a whole number as Ruby's <c>to_i</c> does: an Integer as it is, a Float cut
    /// toward zero, anything else 0.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number.</returns>
    public static long NumberOf(RubyValue value) => value switch
    {
        RubyInteger number when number.Value >= long.MinValue && number.Value <= long.MaxValue => (long)number.Value,
        RubyFloat real when double.IsFinite(real.Value) => (long)Math.Truncate(real.Value),
        _ => 0,
    };
}
