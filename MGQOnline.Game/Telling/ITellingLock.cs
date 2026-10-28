//----------------------------------------------------------------
//  ITellingLock.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Telling;

/// <summary>
/// The relay's telling lock as the telling machine asks for it: one per map and track, held by
/// the first game to tell a story event there (Relay/README.md "Telling locks").
/// </summary>
public interface ITellingLock
{
    /// <summary>
    /// Gets whether tellings take the lock: a Raid World's story on tracks is open. A Classic
    /// party's story takes none.
    /// </summary>
    bool Locks { get; }

    /// <summary>
    /// Gets whether the relay hears a request now: the world room is open.
    /// </summary>
    bool Answerable { get; }

    /// <summary>
    /// Gets how the relay answered the telling's last request: <see langword="true"/> granted,
    /// <see langword="false"/> refused, <see langword="null"/> while unanswered or none asked.
    /// </summary>
    bool? Granted { get; }

    /// <summary>
    /// Gets the seat of the game that tells on the map where the request was refused.
    /// </summary>
    int? Holder { get; }

    /// <summary>
    /// Asks for the lock of a map: a new telling's, or the same telling going on on another map,
    /// which moves its lock there.
    /// </summary>
    /// <param name="site">The site that started the telling.</param>
    /// <param name="map">The map it is told on now.</param>
    void Request(string site, int map);

    /// <summary>
    /// Gives the lock back, as the telling ended.
    /// </summary>
    void Release();
}
