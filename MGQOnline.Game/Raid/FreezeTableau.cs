//----------------------------------------------------------------
//  FreezeTableau.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// Where a frozen fight's stand-ins wait and which live events they keep from starting, as its
/// record is taken (battles_raid_freeze.rbx); the scripts pick which events stand in.
/// </summary>
public static class FreezeTableau
{
    /// <summary>
    /// Places a frozen fight's tableau: on a field map where its event ran, the stand-ins in place;
    /// for a cutscene, its boss on the field map the story entered it from where the player left
    /// it, else at the first field event that leads there; for an event that moved the player
    /// away before its battle, its boss at that event on the map it started on. The fight's own
    /// events and every page of that map that calls a common event of the fight cannot start.
    /// </summary>
    /// <param name="ask">The fight.</param>
    /// <returns>The place.</returns>
    public static TableauPlace Place(TableauAsk ask)
    {
        ArgumentNullException.ThrowIfNull(ask);
        int map = ask.Map;
        (int X, int Y)? at = null;
        IEnumerable<int> own = [ask.EventId];
        if (ask.Scene)
        {
            if (ask.Sources.Count == 0)
            {
                throw new ArgumentException("A cutscene's tableau needs the field events that lead into it.", nameof(ask));
            }

            SceneSource first = ask.Sources[0];
            (map, int x, int y) = ask.Origin is { } origin && ask.Sources.Any(source => source.Map == origin.Map) ? origin : (first.Map, first.X, first.Y);
            at = (x, y);
            own = ask.Sources.Where(source => source.Map == map).Select(source => source.Event);
        }
        else if (ask.Moved)
        {
            at = ask.Place ?? (0, 0);
        }

        int[] fights = [.. own];
        int[] blocked = [.. fights.Concat(ask.Callers.Where(caller => caller.Map == map).Select(caller => caller.Event)).Distinct().Order()];
        return new TableauPlace(map, at, blocked, blocked.Except(fights).Count());
    }
}

/// <summary>
/// A field event that leads into a cutscene, see <see cref="TableauAsk.Sources"/>.
/// </summary>
/// <param name="Map">Its field map.</param>
/// <param name="Event">The event.</param>
/// <param name="X">Where it stands.</param>
/// <param name="Y">Where it stands.</param>
public readonly record struct SceneSource(int Map, int Event, int X, int Y);

/// <summary>
/// A fight whose tableau <see cref="FreezeTableau.Place"/> places.
/// </summary>
/// <param name="Scene">Whether its battle runs on a cutscene map.</param>
/// <param name="Moved">Whether its event moved the player to another map before its battle.</param>
/// <param name="Map">The map its event runs on: the field map, or the map a moved event started on.</param>
/// <param name="EventId">Its event.</param>
/// <param name="Origin">Where the player left a field map for the cutscene: map, x and y; null for unknown.</param>
/// <param name="Place">Where a moved event stood as it started, null for unknown.</param>
/// <param name="Sources">The field events that lead into its cutscene, the first the story's own way in.</param>
/// <param name="Callers">The map pages that call a common event of its frames: map and event.</param>
public sealed record TableauAsk(bool Scene, bool Moved, int Map, int EventId, (int Map, int X, int Y)? Origin, (int X, int Y)? Place,
    IReadOnlyList<SceneSource> Sources, IReadOnlyList<(int Map, int Event)> Callers);

/// <summary>
/// Where a frozen fight's tableau stands, see <see cref="FreezeTableau.Place"/>.
/// </summary>
/// <param name="Map">The map its stand-ins show on.</param>
/// <param name="At">Where its boss's stand-in stands; null when the stand-ins stand where their events stood.</param>
/// <param name="Blocked">The live events it keeps from starting, by id.</param>
/// <param name="Callers">How many of them are other callers of its common events.</param>
public sealed record TableauPlace(int Map, (int X, int Y)? At, IReadOnlyList<int> Blocked, int Callers);
