//----------------------------------------------------------------
//  LocalAddress.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Net;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// An address of one of this PC's network adapters.
/// </summary>
/// <param name="Address">The address.</param>
/// <param name="Adapter">The adapter's id, the same for every address of one adapter.</param>
/// <param name="Temporary">Whether Windows made it up for privacy and replaces it every few hours.</param>
internal readonly record struct LocalAddress(IPAddress Address, string Adapter, bool Temporary);
