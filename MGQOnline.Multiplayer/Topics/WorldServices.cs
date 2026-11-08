//----------------------------------------------------------------
//  WorldServices.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Shared the scripts of the Patch folder in place of the parking
//      Paulinchen  2026-10-23: Shared the directory's action tickets
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// What the topics of worlds and mods share on one context: Player.ini, the changes the scripts are
/// told of, the world directory, its action tickets and the scripts of the Patch folder.
/// </summary>
/// <param name="Player">The Player.ini every topic reads and writes.</param>
/// <param name="Changes">The changes the scripts are told of once a frame.</param>
/// <param name="Directory">Gives the world directory once a topic is called.</param>
/// <param name="Scripts">Lists the scripts of the Patch folder once a topic is called, see <see cref="Mods.PatchScripts"/>.</param>
/// <param name="Tickets">Tells whose answer the directory's action is.</param>
internal sealed record WorldServices(PlayerIni Player, WorldChanges Changes, Func<WorldDirectory> Directory, Func<IReadOnlyList<string>?> Scripts, DirectoryTickets Tickets);
