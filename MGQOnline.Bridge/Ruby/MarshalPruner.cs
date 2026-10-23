//----------------------------------------------------------------
//  MarshalPruner.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// Shapes a full-mode read of large game data as it goes: leaves out the fields a reader never
/// needs and builds its own values of the objects it finished, so the whole tree never stands at once.
/// </summary>
/// <remarks>
/// The game's CommonEvents.rvdata2 of about 49 MB reads into about 650 MB of values whole, more than
/// the game's 32-bit process and the battle server core's heap limit take.
/// </remarks>
public abstract class MarshalPruner
{
    /// <summary>
    /// Tells whether a field of an object being read is kept.
    /// </summary>
    /// <param name="owner">The object, with the fields read before this one.</param>
    /// <param name="field">The field's name, without the "@".</param>
    /// <returns>Whether it is kept; a field left out reads as <see cref="RubySkipped"/>.</returns>
    public virtual bool Keeps(RubyObject owner, string field) => true;

    /// <summary>
    /// Takes an object once its fields are read.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <returns>What stands for it from now on, also where the data links back to it: the object itself, or a value of the reader's own such as a <see cref="RubyBox{T}"/>.</returns>
    public virtual RubyValue Finish(RubyObject value) => value;

    /// <summary>
    /// Tells whether the data never links into a finished object's contents, so the read lets go
    /// of them at once; a link that does reads as <see cref="RubySkipped"/>.
    /// </summary>
    /// <param name="value">The object, before <see cref="Finish"/> took it.</param>
    /// <returns>Whether it is sealed.</returns>
    public virtual bool Seals(RubyObject value) => false;
}

/// <summary>
/// A value a <see cref="MarshalPruner"/> left out of a read.
/// </summary>
public sealed class RubySkipped : RubyValue
{
    /// <summary>
    /// The one value left out.
    /// </summary>
    public static readonly RubySkipped Value = new();

    /// <summary>
    /// Creates the one value.
    /// </summary>
    private RubySkipped()
    {
    }

    /// <inheritdoc />
    public override string KindName => "a value left out";

    /// <inheritdoc />
    public override string ToString() => "<left out>";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}

/// <summary>
/// A value a <see cref="MarshalPruner"/> built of an object as it was read, such as a typed event
/// command.
/// </summary>
/// <typeparam name="T">What the pruner built.</typeparam>
/// <param name="content">The value built.</param>
public sealed class RubyBox<T>(T content) : RubyValue
{
    /// <summary>
    /// Gets the value built.
    /// </summary>
    public T Content { get; } = content;

    /// <inheritdoc />
    public override string KindName => "a " + typeof(T).Name;

    /// <inheritdoc />
    public override string ToString() => Content?.ToString() ?? KindName;

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}
