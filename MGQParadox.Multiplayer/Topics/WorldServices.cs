//----------------------------------------------------------------
//  WorldServices.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Shared the directory's action tickets
//                            - Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// What the topics of worlds and mods share on one context: Player.ini, the changes the scripts are
/// told of, the world directory, its action tickets and the parking of the game folder.
/// </summary>
/// <param name="Player">The Player.ini every topic reads and writes.</param>
/// <param name="Changes">The changes the scripts are told of once a frame.</param>
/// <param name="Directory">Gives the world directory once a topic is called.</param>
/// <param name="Parking">Gives the parking of the game folder once a topic is called.</param>
/// <param name="Tickets">Tells whose answer the directory's action is.</param>
internal sealed record WorldServices(PlayerIni Player, WorldChanges Changes, Func<WorldDirectory> Directory, Func<ModParking> Parking, DirectoryTickets Tickets);
