//----------------------------------------------------------------
//  WorldEntries.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// A world as the directory lists it, with what the world screen's order reads of it.
/// </summary>
/// <param name="Id">The world's id.</param>
/// <param name="Name">The world's name.</param>
/// <param name="Raid">Whether it is a Raid World.</param>
/// <param name="Featured">Whether it is one of the relay's own worlds, which an admin made.</param>
public sealed record ListedWorldRow(string Id, string Name, bool Raid, bool Featured);

/// <summary>
/// A world on this PC, with what the world screen's order reads of it.
/// </summary>
/// <param name="FolderId">Its folder's id.</param>
/// <param name="Name">The world's name.</param>
/// <param name="DirectoryId">The directory's id of the world, <see langword="null"/> when its world.ini names none.</param>
/// <param name="Raid">Whether its world.ini keeps it as a Raid World.</param>
/// <param name="PlayedAt">When it was played last, in seconds since 1970; 0 for never.</param>
public sealed record LocalWorldRow(string FolderId, string Name, string? DirectoryId, bool Raid, long PlayedAt);

/// <summary>
/// A world as the world screen lists it: the directory's, this PC's folder of it, or both.
/// </summary>
/// <param name="Id">The directory's id of the world, <see langword="null"/> for a world on this PC whose world.ini names none.</param>
/// <param name="Name">The world's name, the directory's when it lists the world.</param>
/// <param name="ListedIndex">The world's place in the directory's list, <see langword="null"/> once the directory no longer has it.</param>
/// <param name="Local">This PC's folder of the world, <see langword="null"/> before the player entered it.</param>
/// <param name="Favourite">Whether the player marked it as a favourite.</param>
/// <param name="Gone">Whether the directory no longer has it, as opposed to its list not having arrived.</param>
public sealed record WorldEntry(string? Id, string Name, int? ListedIndex, LocalWorldRow? Local, bool Favourite, bool Gone);

/// <summary>
/// Builds what the world screen lists: the directory's worlds, and the worlds on this PC the
/// directory no longer has, those it still has first, Raid Worlds first among them, then
/// favourites, then the featured ones, then those played last, then by name.
/// </summary>
public static class WorldEntries
{
    /// <summary>
    /// Builds the entries in their order.
    /// </summary>
    /// <remarks>
    /// Worlds alike in every part of the order keep the order they came in, where the scripts' sort
    /// left them in no order of their own.
    /// </remarks>
    /// <param name="listed">The directory's worlds in its order.</param>
    /// <param name="local">The worlds on this PC.</param>
    /// <param name="favourites">The directory ids of the favourite worlds.</param>
    /// <param name="complete">Whether the directory's list arrived, so a world missing from it is gone.</param>
    /// <returns>The entries.</returns>
    public static IReadOnlyList<WorldEntry> Of(IReadOnlyList<ListedWorldRow> listed, IReadOnlyList<LocalWorldRow> local, IReadOnlyCollection<string> favourites, bool complete)
    {
        Dictionary<string, LocalWorldRow> byDirectoryId = new(StringComparer.Ordinal);
        foreach (LocalWorldRow world in local)
        {
            if (world.DirectoryId != null)
            {
                byDirectoryId[world.DirectoryId] = world;
            }
        }

        HashSet<string> listedIds = new(listed.Select(world => world.Id), StringComparer.Ordinal);
        List<(WorldEntry Entry, bool Raid, bool Featured)> entries = [];
        for (int index = 0; index < listed.Count; index++)
        {
            ListedWorldRow world = listed[index];
            entries.Add((new WorldEntry(world.Id, world.Name, index, byDirectoryId.GetValueOrDefault(world.Id), favourites.Contains(world.Id), false), world.Raid, world.Featured));
        }

        foreach (LocalWorldRow world in local.Where(world => world.DirectoryId == null || !listedIds.Contains(world.DirectoryId)))
        {
            bool favourite = world.DirectoryId != null && favourites.Contains(world.DirectoryId);
            entries.Add((new WorldEntry(world.DirectoryId, world.Name, null, world, favourite, complete || world.DirectoryId == null), world.Raid, false));
        }

        return entries
            .OrderBy(item => item.Entry.Gone ? 1 : 0)
            .ThenBy(item => item.Raid ? 0 : 1)
            .ThenBy(item => item.Entry.Favourite ? 0 : 1)
            .ThenBy(item => item.Featured ? 0 : 1)
            .ThenBy(item => -(item.Entry.Local?.PlayedAt ?? 0))
            .ThenBy(item => Encoding.UTF8.GetBytes(AsciiLower(item.Entry.Name)), ByteOrder.Instance)
            .Select(item => item.Entry)
            .ToList();
    }

    /// <summary>
    /// Lower-cases the ASCII letters of a name only, as the game's Ruby does.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name with A to Z lower-cased.</returns>
    public static string AsciiLower(string name) =>
        string.Create(name.Length, name, (characters, source) =>
        {
            for (int index = 0; index < source.Length; index++)
            {
                char character = source[index];
                characters[index] = character is >= 'A' and <= 'Z' ? (char)(character + ('a' - 'A')) : character;
            }
        });

    /// <summary>
    /// Compares texts by their bytes, as Ruby compares strings.
    /// </summary>
    private sealed class ByteOrder : IComparer<byte[]>
    {
        /// <summary>
        /// The one comparer.
        /// </summary>
        public static readonly ByteOrder Instance = new();

        /// <inheritdoc />
        public int Compare(byte[]? x, byte[]? y) => ((ReadOnlySpan<byte>)x).SequenceCompareTo(y);
    }
}
