//----------------------------------------------------------------
//  StoryClass.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Story;

/// <summary>
/// How a story key is shared, as one byte of the tables the scripts look keys up in: no bit for a
/// key that is each player's own.
/// </summary>
[Flags]
public enum StoryClass : byte
{
    /// <summary>Each player's own: never a request, never pushed.</summary>
    Personal = 0,

    /// <summary>Kept on a track: every write of it is a request, and pushes carry it.</summary>
    Kept = 1,

    /// <summary>Kept, and only ever goes up.</summary>
    OneWay = 2,

    /// <summary>On only while a scene runs: shown to viewers, never kept.</summary>
    Scene = 4,

    /// <summary>A chest's: each player's own, but kept with the player on the relay.</summary>
    Chest = 8,

    /// <summary>A count the relay keeps itself.</summary>
    Count = 16,

    /// <summary>Kept for the whole world, players behind included.</summary>
    WholeWorld = 32,

    /// <summary>The post-defeat processing writes it.</summary>
    DefeatWrite = 64,

    /// <summary>A side switch of a Classic world, each player's own while the sides still differ.</summary>
    Side = 128,
}
