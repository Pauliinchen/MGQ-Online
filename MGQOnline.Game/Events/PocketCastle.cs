//----------------------------------------------------------------
//  PocketCastle.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Events;

/// <summary>
/// What a page's texts tell of it, which only the game holds: the events database keeps no
/// dialogue and no script's text.
/// </summary>
/// <param name="Speaker">The variables the first line of dialogue shows in its speaker's name, as a companion's name shows their affection.</param>
/// <param name="Goods">Whether a script lists a shop's goods itself, as the castle's coin shop does.</param>
public sealed record PageTexts(IReadOnlyList<long> Speaker, bool Goods)
{
    /// <summary>
    /// A page whose texts tell nothing.
    /// </summary>
    public static PageTexts None { get; } = new([], false);
}

/// <summary>
/// The Pocket Castle's residents: its companions, merchants, inn, maids and services, each a talk
/// every player has in their own game, whatever the talk sets.
/// </summary>
public static class PocketCastle
{
    /// <summary>
    /// The maps of the castle's residents, without the maps of the castle's side stories.
    /// </summary>
    public static readonly IReadOnlySet<long> ResidentMaps = new HashSet<long>([227, 228, 229, 230, .. Enumerable.Range(268, 11).Select(map => (long)map)]);

    /// <summary>
    /// The common events of the castle's services: Vanilla's shop (106), Papi's smithy (107), the
    /// maids' party saves (111), the item storage (144), Promestein's race machine (231) and Teeny's
    /// inn (270).
    /// </summary>
    /// <remarks>
    /// The race machine writes its unlock switches and switch 3454, which made it story, so a
    /// player behind the world could not use it (issue #48).
    /// </remarks>
    public static readonly IReadOnlySet<long> Services = new HashSet<long> { 106, 107, 111, 144, 231, 270 };

    /// <summary>
    /// Reports whether a list is a resident's: on a castle map, a call of a service, a shop that
    /// lists its goods, or a companion's talk, whose first speaker shows an affection the player keeps.
    /// </summary>
    /// <param name="map">The map the list runs on.</param>
    /// <param name="list">The commands.</param>
    /// <param name="texts">What the list's texts tell.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsResident(long map, IReadOnlyList<EventCommand> list, PageTexts texts, IEventState state) =>
        ResidentMaps.Contains(map)
        && (texts.Goods
            || list.Any(command => command.Code == EventCodes.CallCommonEvent && Services.Contains(command.Number(0)))
            || texts.Speaker.Any(variable => variable >= ClassicStoryTable.AffectionBase && state.PersonalVariable(variable)));
}
