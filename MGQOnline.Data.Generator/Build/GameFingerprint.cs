//----------------------------------------------------------------
//  GameFingerprint.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Left the checksums and the text to MGQOnline.Game's DataFingerprint, which the scripts' fingerprint is made by too
//      Paulinchen  2026-10-30: Counted an entry by its note, features and effects, never its name, in format 2
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Data.Events;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The game data's fingerprint of the game's files, as the scripts' of the game's data
/// (<c>MGQ_MpWorld::GameData.fingerprint</c> in world.rbx, written by <see cref="DataFingerprint"/>).
/// </summary>
internal static class GameFingerprint
{
    /// <summary>
    /// The fingerprint's format, see <see cref="DataFingerprint.Format"/>.
    /// </summary>
    public const string Format = DataFingerprint.Format;

    /// <summary>
    /// How many skills the game appends to the skills it loads (145 - Module.rb, the turn's end
    /// revive and the revive); they have effects, so the fingerprint counts them.
    /// </summary>
    public const int AppendedSkills = 2;

    /// <summary>
    /// Finds the parts of the fingerprint from the ids that exist of each.
    /// </summary>
    /// <param name="ids">The ids, per part in the order of <see cref="GameDataCompare.Parts"/>.</param>
    /// <returns>The parts.</returns>
    public static List<FingerprintPart> Parts(IReadOnlyList<IReadOnlyList<int>> ids) => DataFingerprint.Parts(ids);

    /// <summary>
    /// Writes the fingerprint of its parts.
    /// </summary>
    /// <param name="parts">The parts, in their order.</param>
    /// <returns>The fingerprint, such as "2:2a67edfc.e66a7e3b".</returns>
    public static string Text(IEnumerable<FingerprintPart> parts) => DataFingerprint.Text(parts);

    /// <summary>
    /// Lists the ids of the entries that are more than an empty place, as world.rbx's <c>existing</c>.
    /// </summary>
    /// <typeparam name="T">The entries.</typeparam>
    /// <param name="entries">The entries by id, <see langword="null"/> where the game has none.</param>
    /// <param name="exists">Whether an entry is in use.</param>
    /// <returns>The ids.</returns>
    public static IReadOnlyList<int> Existing<T>(IReadOnlyList<T?> entries, Func<T, bool> exists) =>
        [.. Enumerable.Range(0, entries.Count).Where(id => entries[id] is { } entry && exists(entry))];
}
