//----------------------------------------------------------------
//  RoutedMessage.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// Which gate a route's messages pass before a script takes them.
/// </summary>
public enum RouteGate
{
    /// <summary>
    /// Every message of the route passes.
    /// </summary>
    None,

    /// <summary>
    /// Only messages of an admitted member of the player's party pass.
    /// </summary>
    Party,

    /// <summary>
    /// Only messages for the player's map, or the map the story takes them to, pass.
    /// </summary>
    Map,
}

/// <summary>
/// A message the room hands to the script registered for its field.
/// </summary>
/// <param name="Field">The field the script registered.</param>
/// <param name="Seat">The sender's seat, <see langword="null"/> for the relay's push.</param>
/// <param name="Fields">The message's fields.</param>
/// <param name="Body">What follows the fields.</param>
/// <param name="Relay">Whether the relay pushed it, which no player's message can claim.</param>
public sealed record RoutedMessage(string Field, int? Seat, WorldFields Fields, string Body, bool Relay);
