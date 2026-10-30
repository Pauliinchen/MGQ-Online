//----------------------------------------------------------------
//  LiveFacts.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// What the scripts know of the world when the live battle checks whether it ends.
/// </summary>
/// <param name="InWorld">Whether the player is in a world.</param>
/// <param name="ServedClosed">Whether the battle channel of a battle the server hosts closed.</param>
public sealed record LiveFacts(bool InWorld, bool ServedClosed);
