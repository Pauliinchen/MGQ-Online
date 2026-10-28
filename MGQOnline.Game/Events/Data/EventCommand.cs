//----------------------------------------------------------------
//  EventCommand.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Carried numbers, the text kind and the script keys instead of the parameters
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// One command of an event's list as the rules read it: numbers only, its texts classified where the
/// list was read (see <see cref="CommandClassifier"/>).
/// </summary>
/// <param name="Code">The command's code, such as 111 for a conditional branch.</param>
/// <param name="Indent">How deep in branches it stands.</param>
/// <param name="Numbers">Its parameters as whole numbers, a text as <see cref="CommandClassifier"/> numbers it; empty for the codes whose parameters no rule reads (see <see cref="EventCodes.KeepsParameters"/>).</param>
/// <param name="TextKind">What a script does, <see cref="TextKind.None"/> for any other command.</param>
/// <param name="ScriptKeys">The switches and variables the command's script text names by id.</param>
public readonly record struct EventCommand(int Code, int Indent, long[] Numbers, TextKind TextKind, ScriptKey[] ScriptKeys)
{
    /// <summary>
    /// The numbers of a command whose parameters were left out.
    /// </summary>
    public static readonly long[] NoNumbers = [];

    /// <summary>
    /// The script keys of a command whose text names none.
    /// </summary>
    public static readonly ScriptKey[] NoKeys = [];

    /// <summary>
    /// Reads a parameter as a whole number.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The number; 0 for a parameter that is missing.</returns>
    public long Number(int index) => index < Numbers.Length ? Numbers[index] : 0;

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

/// <summary>
/// One command of an event's list as the game's RPG::EventCommand holds it, its texts included.
/// </summary>
/// <param name="Code">The command's code.</param>
/// <param name="Indent">How deep in branches it stands.</param>
/// <param name="Parameters">Its parameters; empty for the codes whose parameters no rule reads, which the reader leaves out.</param>
public readonly record struct RawCommand(int Code, int Indent, RubyArray Parameters)
{
    /// <summary>
    /// The parameters of a command whose parameters were left out.
    /// </summary>
    public static readonly RubyArray NoParameters = [];

    /// <summary>
    /// Reads a parameter as text, as Ruby's <c>to_s</c> does for a String; anything else reads as empty.
    /// </summary>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The text.</returns>
    public string Text(int index) => index < Parameters.Count && Parameters[index] is RubyString text ? text.Text : string.Empty;
}

/// <summary>
/// What a script command does, as the sorter tells scripts apart.
/// </summary>
public enum TextKind : byte
{
    /// <summary>No script.</summary>
    None,

    /// <summary>A script a talk may run, such as a companion's line, a menu or a move route.</summary>
    Talk,

    /// <summary>A script that travels.</summary>
    Travel,

    /// <summary>A talk's script that shows a choice and writes the answer into the variable of its first number.</summary>
    Choice,

    /// <summary>A script that plays a novel scene.</summary>
    Novel,

    /// <summary>Any other script, which moves the story on.</summary>
    Other,
}

/// <summary>
/// A switch or variable a script names by its id.
/// </summary>
/// <param name="Variable">Whether it is a variable, else a switch.</param>
/// <param name="Id">Its id.</param>
/// <param name="Set">Whether the script assigns it.</param>
public readonly record struct ScriptKey(bool Variable, long Id, bool Set);
