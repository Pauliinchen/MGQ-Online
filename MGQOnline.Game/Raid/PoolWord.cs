//----------------------------------------------------------------
//  PoolWord.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// What the relay told of a Raid World's boss pool: in a fetch, an answer to a report or a push.
/// </summary>
/// <param name="Key">The pool's key, as the game script named it.</param>
/// <param name="Left">The share of the raid max HP left when the relay told it, 0 to 1.</param>
/// <param name="Max">The raid max HP, 0 when the relay named none.</param>
/// <param name="Defeated">Whether the boss is defeated for the world until an admin resets it.</param>
/// <param name="By">Who defeated it, empty while it stands or when the relay did not say.</param>
public sealed record PoolWord(string Key, double Left, double Max, bool Defeated, string By);
