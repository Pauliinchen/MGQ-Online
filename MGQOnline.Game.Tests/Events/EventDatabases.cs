//----------------------------------------------------------------
//  EventDatabases.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Builds the events database of a game's files in memory, as the generator writes the shipped
/// file, for the tests of the rules over it.
/// </summary>
internal static class EventDatabases
{
    /// <summary>
    /// Builds the database of a game's files.
    /// </summary>
    /// <param name="files">The game's data files, such as a <see cref="TinyGame"/>'s.</param>
    /// <returns>The store over it.</returns>
    public static EventStore Of(IGameDataFiles files)
    {
        EventStore store = EventStore.Over(EventDatabaseWriter.Build(EventBuilder.Build(files, new BuildOptions())));
        Assert.Null(store.Problem);
        return store;
    }

    /// <summary>
    /// Builds the database of a tiny game and reads it as the rules do.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The game's events from the database.</returns>
    public static EventStoreSource SourceOf(TinyGame game) => new(Of(game.Files()));
}
