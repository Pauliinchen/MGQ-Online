//----------------------------------------------------------------
//  DirectoryClient.Battles.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The route that hands a world's co-op battle to the relay's battle server, see Relay/README.md,
/// "Server battles".
/// </summary>
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// Asks the relay to start a battle on its battle server, which answers once the server took it.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The starting player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seats">The world seats of the battle's players, who alone may come onto its channel.</param>
    /// <param name="setup">What the server needs to host the battle, as the game script wrote it.</param>
    /// <exception cref="DirectoryException">The relay could not be reached, or it or its battle server refused, with the code that names why, such as "no_server" or "busy".</exception>
    public void ServeBattle(string world, string playerKey, string authKey, string battle, IReadOnlyCollection<int> seats, string setup)
    {
        var body = Json(writer =>
        {
            writer.WriteString("battle", battle);
            writer.WriteStartArray("seats");

            foreach (var seat in seats)
            {
                writer.WriteNumberValue(seat);
            }

            writer.WriteEndArray();
            writer.WriteString("setup", Convert.ToBase64String(Encoding.UTF8.GetBytes(setup)));
        });

        using var answer = SendStory(HttpMethod.Post, new Uri($"{_worlds}/{Uri.EscapeDataString(world)}/battles"), $"battle serve {Log.Short(world)} battle {battle}, {seats.Count} players, {setup.Length} characters", body, playerKey, authKey, null, out _, Http);
    }
}
