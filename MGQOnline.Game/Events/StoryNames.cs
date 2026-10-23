//----------------------------------------------------------------
//  StoryNames.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The names the game gives the keys of the story, which the website's World Admin shows the story
/// mapping with: those of the website's names file (its StoryNamesDto).
/// </summary>
/// <param name="Switches">The switch names by id, the empty ones left out.</param>
/// <param name="Variables">The variable names by id, the empty ones left out.</param>
/// <param name="Maps">The map names by id, of Data and its Data/Map folders.</param>
/// <param name="Events">The event names by "map.event", such as "858.139".</param>
/// <param name="Companions">How many entries the actor list holds, which is how many affection variables the game keeps.</param>
public sealed record StoryNames(
    IReadOnlyDictionary<int, string> Switches,
    IReadOnlyDictionary<int, string> Variables,
    IReadOnlyDictionary<int, string> Maps,
    IReadOnlyDictionary<string, string> Events,
    int Companions)
{
    /// <summary>
    /// Reads the names from the game's data, every map read once.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <returns>The names.</returns>
    public static StoryNames Of(GameData data)
    {
        var maps = new SortedDictionary<int, string>();
        var events = new SortedDictionary<string, string>(System.StringComparer.Ordinal);
        foreach (MapInfo info in data.Maps)
        {
            maps[info.Id] = info.Name;
            foreach (MapEvent mapEvent in data.ReadMap(info.Id)?.Events.Values ?? [])
            {
                events[string.Create(CultureInfo.InvariantCulture, $"{info.Id}.{mapEvent.Id}")] = mapEvent.Name;
            }
        }

        return new StoryNames(Named(data.System.Switches), Named(data.System.Variables), maps, events, data.ActorCount);
    }

    /// <summary>
    /// Keeps the names that are not empty.
    /// </summary>
    /// <param name="names">The names by id.</param>
    /// <returns>Those with a name, by id.</returns>
    private static SortedDictionary<int, string> Named(IReadOnlyList<string> names)
    {
        var named = new SortedDictionary<int, string>();
        for (int id = 1; id < names.Count; id++)
        {
            if (names[id].Length > 0)
            {
                named[id] = names[id];
            }
        }

        return named;
    }
}
