//----------------------------------------------------------------
//  ConnectionStatus.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// How the world connection stands, as the room looks at it every few frames.
/// </summary>
/// <param name="State">"idle", "connecting", "open", "reconnecting" or "failed".</param>
/// <param name="Seat">The game's seat, <see langword="null"/> while it holds none.</param>
/// <param name="Ping">The last round trip to the relay in milliseconds, <see langword="null"/> without a connection.</param>
/// <param name="Error">Why the world cannot be entered now, <see langword="null"/> for nothing.</param>
public sealed record ConnectionStatus(string State, int? Seat, int? Ping, string? Error);
