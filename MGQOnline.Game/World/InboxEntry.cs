//----------------------------------------------------------------
//  InboxEntry.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// An entry of the world room's inbox: a seat taken, a game coming or going, another game's
/// message, or a push of the relay.
/// </summary>
/// <param name="Kind">The kind: "seat", "in", "out", "message", or a relay push ("chat", "story",
/// "boss", "difficulty", "squad", "raid_bosses", "mods_rule").</param>
/// <param name="Seat">The seat it is about, -1 for a relay push.</param>
/// <param name="Headers">The entry's other headers, such as "rev" of a story push.</param>
/// <param name="Text">A message's text, or a chat line.</param>
public sealed record InboxEntry(string Kind, int Seat, WorldFields Headers, string Text);
