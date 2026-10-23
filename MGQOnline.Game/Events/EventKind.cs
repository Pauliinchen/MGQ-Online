//----------------------------------------------------------------
//  EventKind.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Added the battlefuck kind
//                            - Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Events;

/// <summary>
/// What an event page does, by what of it can run now.
/// </summary>
public enum EventKind
{
    /// <summary>A conversation, a shop or a menu, which each player plays in their own game.</summary>
    Talk,

    /// <summary>A transfer to another map.</summary>
    Travel,

    /// <summary>Items and the page's own self switch, which a chest gives once.</summary>
    Chest,

    /// <summary>A fight without dialogue of its own, such as a wandering monster.</summary>
    Battle,

    /// <summary>Everything that moves the story on.</summary>
    Story,

    /// <summary>A battlefuck, which plays in the game of whoever starts it alone.</summary>
    Own,
}

/// <summary>
/// What a list of event commands does, as the sorter finds it.
/// </summary>
[Flags]
public enum EventMarks
{
    /// <summary>Nothing found.</summary>
    None = 0,

    /// <summary>A command that moves the story on wherever it stands, or a script no talk runs.</summary>
    Story = 1,

    /// <summary>A switch or variable of the story is set.</summary>
    Sets = 2,

    /// <summary>Dialogue: text, choices or scrolling text.</summary>
    Says = 4,

    /// <summary>Gold, items, weapons or armor change.</summary>
    Gives = 8,

    /// <summary>The page's own self switch is set.</summary>
    OwnSwitch = 16,

    /// <summary>A battle starts.</summary>
    Battle = 32,

    /// <summary>The player is moved to another place.</summary>
    Travel = 64,

    /// <summary>A choice's branch does what would make the page story, which the player may never choose.</summary>
    ChoiceStory = 128,
}
