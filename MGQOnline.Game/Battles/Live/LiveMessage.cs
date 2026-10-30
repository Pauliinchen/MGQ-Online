//----------------------------------------------------------------
//  LiveMessage.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// A message of the live battle that arrived and waits to be taken.
/// </summary>
/// <param name="Kind">What it is, such as "commands".</param>
/// <param name="Body">The rest, as the sender wrote it.</param>
/// <param name="Seat">The seat the battle knows the sender by.</param>
public sealed record LiveMessage(string Kind, string Body, int Seat);
