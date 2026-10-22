//----------------------------------------------------------------
//  RandomStream.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the stream of the start rests
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Randomness;

/// <summary>
/// The mechanics that each draw from a random stream of their own.
/// </summary>
/// <remarks>
/// The numbers seed the streams, so they never change; a new stream takes the next free number.
/// </remarks>
public enum RandomStream
{
    /// <summary>
    /// The boss's turn plan: which actions it rolls.
    /// </summary>
    Plan = 0,

    /// <summary>
    /// Crowd control rolls.
    /// </summary>
    Cc = 1,

    /// <summary>
    /// Where skills aim.
    /// </summary>
    Targeting = 2,

    /// <summary>
    /// Which half of the grid a zone skill takes.
    /// </summary>
    Side = 3,

    /// <summary>
    /// The chances of the Trigger -> Effect rules.
    /// </summary>
    Rules = 4,

    /// <summary>
    /// Where debris falls.
    /// </summary>
    Debris = 5,

    /// <summary>
    /// The rolls of single hits.
    /// </summary>
    Hits = 6,

    /// <summary>
    /// The simulated party's moves.
    /// </summary>
    Party = 7,

    /// <summary>
    /// The order in which the start rests of the cooldown skills are picked.
    /// </summary>
    StartRests = 8,
}
