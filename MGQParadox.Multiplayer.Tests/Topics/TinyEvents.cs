//----------------------------------------------------------------
//  TinyEvents.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Wrote the events database of a tiny game into a file
//                            - Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Tests.Events;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// The game's events of a tiny game as the DLL reads them: the events database the generator
/// builds of it in memory, with its files for whether one exists.
/// </summary>
internal static class TinyEvents
{
    /// <summary>
    /// Builds the events of a tiny game, its fingerprint not yet handed over.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The events.</returns>
    public static GameEvents Of(TinyGame game)
    {
        TinyGame files = game.Files();
        EventStore store = EventStore.Over(EventDatabaseWriter.Build(EventBuilder.Build(files, new BuildOptions())));
        Assert.Null(store.Problem);
        return new GameEvents(() => store, () => files, _ => { });
    }

    /// <summary>
    /// Writes the events database of a tiny game into a file, as the mod ships it.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <param name="path">The file.</param>
    public static void Write(TinyGame game, string path) => EventDatabaseWriter.Write(EventBuilder.Build(game.Files(), new BuildOptions()), path);

    /// <summary>
    /// Names a map event's page as the scripts do when they hold it as the database does.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <returns>The request: map, event, page, size and shape.</returns>
    public static RubyHash Page(GameEvents events, int map, int eventId, int page = 0)
    {
        ListRow list = events.Store.ListOf(map, eventId, page)!.Value;
        return new RubyHash { { "map", map }, { "event", eventId }, { "page", page }, { "size", list.CountAll }, { "shape", list.Shape } };
    }

    /// <summary>
    /// Names a page as a row of a map's question: [event, page, size, shape].
    /// </summary>
    /// <param name="events">The events.</param>
    /// <param name="eventId">The event on map 1.</param>
    /// <param name="shapeOffset">What is added to the shape, not 0 for a page the scripts hold otherwise.</param>
    /// <returns>The row.</returns>
    public static RubyArray Row(GameEvents events, int eventId, int shapeOffset = 0)
    {
        ListRow list = events.Store.ListOf(1, eventId, 0)!.Value;
        return [eventId, 0, list.CountAll, list.Shape + shapeOffset];
    }
}
