//----------------------------------------------------------------
//  Peer.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Told whether the connection is down, which the grace of Sessions counts
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// Another game of the world: its seat, the state its player last told, whether its connection is
/// down and whether its player is in the player's party.
/// </summary>
public sealed class Peer
{
    /// <summary>
    /// Initializes a game by its first state.
    /// </summary>
    /// <param name="seat">Its seat.</param>
    /// <param name="state">What its player told.</param>
    internal Peer(int seat, WorldFields state)
    {
        Seat = seat;
        State = state;
    }

    /// <summary>
    /// Gets the game's seat, which changes when its player tells from another one.
    /// </summary>
    public int Seat { get; internal set; }

    /// <summary>
    /// Gets what the player last told: "id", "name", "map", "x", "y" and the rest.
    /// </summary>
    public WorldFields State { get; internal set; }

    /// <summary>
    /// Gets a value indicating whether the game's connection is down, while <see cref="Sessions"/>
    /// keeps it for the grace.
    /// </summary>
    public bool Away { get; internal set; }

    /// <summary>
    /// Gets a value indicating whether the player was in the player's party at their last state.
    /// </summary>
    public bool Member { get; internal set; }

    /// <summary>
    /// Gets the player's id, empty before they told one.
    /// </summary>
    public string Id => State.Text("id");

    /// <summary>
    /// Gets the player's name, empty before they told one.
    /// </summary>
    public string Name => State.Text("name");

    /// <summary>
    /// Gets a value indicating whether the game's connection stands.
    /// </summary>
    public bool Present => !Away;

    /// <summary>
    /// Names the player for the log: their name and seat.
    /// </summary>
    /// <returns>The name.</returns>
    public override string ToString() => $"{Name} (seat {Seat})";
}
