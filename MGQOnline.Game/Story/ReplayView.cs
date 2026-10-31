//----------------------------------------------------------------
//  ReplayView.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;

namespace MGQOnline.Game.Story;

/// <summary>
/// The values a replay reads: the start values its entry carries, which are those of the world and
/// work keys, and the receiver's own values of every other key.
/// </summary>
/// <param name="start">The entry's start values.</param>
/// <param name="own">The receiver's own values.</param>
public sealed class ReplayView(IReadOnlyDictionary<StoryKey, string> start, IReplayState own) : IReplayState
{
    /// <inheritdoc />
    public bool Switch(long id) => id is >= 0 and <= StoryKey.MaxId && start.TryGetValue(StoryKey.Switch((int)id), out string? value) ? value == "1" : own.Switch(id);

    /// <inheritdoc />
    public long? Variable(long id) => id is >= 0 and <= StoryKey.MaxId && start.TryGetValue(StoryKey.Variable((int)id), out string? value) ? WholeOf(value) : own.Variable(id);

    /// <inheritdoc />
    public bool PersonalSwitch(long id) => own.PersonalSwitch(id);

    /// <inheritdoc />
    public bool PersonalVariable(long id) => own.PersonalVariable(id);

    /// <inheritdoc />
    public bool SelfSwitch(int map, int eventId, string letter) =>
        start.TryGetValue(StoryKey.SelfSwitch(map, eventId, letter), out string? value) ? value == "1" : own.SelfSwitch(map, eventId, letter);

    /// <inheritdoc />
    public bool HasItem(int item) => own.HasItem(item);

    /// <inheritdoc />
    public bool InParty(int actor) => own.InParty(actor);

    /// <summary>
    /// Reads a variable's value as the tracks keep it as a whole number, as Ruby's <c>to_i</c> does
    /// for a number.
    /// </summary>
    /// <param name="value">The value, such as "n12" or "f1.5".</param>
    /// <returns>The number, <see langword="null"/> for a value that is no number.</returns>
    public static long? WholeOf(string value)
    {
        ArgumentNullException.ThrowIfNull(value);
        if (value.StartsWith('n') && long.TryParse(value.AsSpan(1), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long whole))
        {
            return whole;
        }

        return value.StartsWith('f') && double.TryParse(value.AsSpan(1), NumberStyles.Float, CultureInfo.InvariantCulture, out double real) && double.IsFinite(real)
            ? (long)Math.Truncate(real)
            : null;
    }
}
