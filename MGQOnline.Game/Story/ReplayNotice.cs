//----------------------------------------------------------------
//  ReplayNotice.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// One thing the receiver holds, as the scripts list it before and after a replay.
/// </summary>
/// <param name="Key">What it is, such as "i12" or "g"; the scripts name it.</param>
/// <param name="Amount">How much or how many.</param>
/// <param name="Name">Its name as shown.</param>
/// <param name="Sum">Whether it is told as an amount before its name, as gold is ("100 G").</param>
public sealed record ReplayHolding(string Key, long Amount, string Name, bool Sum);

/// <summary>
/// Builds the one notice of a replay from the difference of what the receiver held before and
/// after it, since the replay itself shows no message.
/// </summary>
public static class ReplayNotice
{
    /// <summary>
    /// Builds the notice.
    /// </summary>
    /// <param name="entry">The run replayed.</param>
    /// <param name="before">What the receiver held before.</param>
    /// <param name="after">What they held after.</param>
    /// <returns>The notice, <see langword="null"/> for none: a run of the story or with no opener run that changed nothing the receiver holds.</returns>
    public static string? Text(ReplayEntry entry, IReadOnlyList<ReplayHolding> before, IReadOnlyList<ReplayHolding> after)
    {
        ArgumentNullException.ThrowIfNull(entry);
        ArgumentNullException.ThrowIfNull(before);
        ArgumentNullException.ThrowIfNull(after);
        Dictionary<string, long> had = AmountsOf(before);
        Dictionary<string, long> has = AmountsOf(after);
        string gains = Listed(after.DistinctBy(thing => thing.Key).Where(thing => has[thing.Key] > had.GetValueOrDefault(thing.Key)).Select(thing => Told(thing, has[thing.Key] - had.GetValueOrDefault(thing.Key))));
        string costs = Listed(before.DistinctBy(thing => thing.Key).Where(thing => had[thing.Key] > has.GetValueOrDefault(thing.Key)).Select(thing => Told(thing, had[thing.Key] - has.GetValueOrDefault(thing.Key))));
        string paid = costs.Length == 0 ? string.Empty : $" You paid {costs}.";
        if (entry.Opener is null || entry.Derived)
        {
            return gains.Length == 0 ? null : $"Caught up: {gains}.{paid}";
        }

        if (entry.Scope == StoryScope.Party)
        {
            return gains.Length == 0 ? $"{entry.Opener} opened a chest for the party.{paid}" : $"{entry.Opener} opened a chest for the party: {gains}.{paid}";
        }

        return gains.Length == 0 && costs.Length == 0 ? null : gains.Length == 0
            ? $"{entry.Opener} played an event for everyone.{paid}"
            : $"{entry.Opener} played an event for everyone: {gains}.{paid}";
    }

    /// <summary>
    /// Reads what the receiver holds as the scripts list it.
    /// </summary>
    /// <param name="value">[[key, amount, name, sum], ...].</param>
    /// <returns>The things, in their order.</returns>
    /// <exception cref="RubyValueException">A thing is no such four.</exception>
    public static IReadOnlyList<ReplayHolding> Read(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return [.. value.AsArray().Select(entry => entry.AsArray() is { Count: 4 } fields
            ? new ReplayHolding(fields[0].AsText(), fields[1].AsLong(), fields[2].AsText(), fields[3].AsBool())
            : throw new RubyValueException("A thing held is [key, amount, name, sum]."))];
    }

    /// <summary>
    /// Sums the amounts of things by key.
    /// </summary>
    /// <param name="things">The things.</param>
    /// <returns>The amounts.</returns>
    private static Dictionary<string, long> AmountsOf(IEnumerable<ReplayHolding> things)
    {
        var amounts = new Dictionary<string, long>(StringComparer.Ordinal);
        foreach (ReplayHolding thing in things)
        {
            amounts[thing.Key] = amounts.GetValueOrDefault(thing.Key) + thing.Amount;
        }

        return amounts;
    }

    /// <summary>
    /// Tells an amount of a thing.
    /// </summary>
    /// <param name="thing">The thing.</param>
    /// <param name="amount">How much or how many changed hands.</param>
    /// <returns>Such as "100 G", "Potion x2" or "Blast Voice".</returns>
    private static string Told(ReplayHolding thing, long amount) =>
        thing.Sum ? string.Create(CultureInfo.InvariantCulture, $"{amount} {thing.Name}")
            : amount == 1 ? thing.Name : string.Create(CultureInfo.InvariantCulture, $"{thing.Name} x{amount}");

    /// <summary>
    /// Lists texts.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>Them comma separated, empty for none.</returns>
    private static string Listed(IEnumerable<string> texts) => string.Join(", ", texts);
}
