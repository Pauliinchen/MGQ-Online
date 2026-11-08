//----------------------------------------------------------------
//  DirectoryClient.Story.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Fetched the story without naming the known revision
//      Paulinchen  2026-10-23: Fetched the story mapping, and dropped the story's writes, checkpoints and route lock, which play on tracks
//      Paulinchen  2026-10-15: Wrote and read a Raid World's story key by key, and fetched it without its keys while this game holds them
//      Paulinchen  2026-10-12: Carried the level caps of the world's story
//      Paulinchen  2026-10-09: Logged story fetches only when their outcome changes and let boss requests name their client
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace MGQOnline.Multiplayer.Network.World;

/// <summary>
/// The routes of a Raid World's story at the relay the game still asks: its state with the shared
/// companions, adding companions, and the story mapping every Raid World shares, see
/// docs/DEVELOPER.md, "World story on the relay".
/// </summary>
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// Fetches a Raid World's story state as it stands: its revision and the shared companions.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <returns>The state.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, the world is no Raid World, or the player may not read it.</exception>
    public StoryState GetStory(string world, string playerKey, string authKey)
    {
        using var document = SendStory(HttpMethod.Get, StoryAddress(world, string.Empty), $"raid story {Log.Short(world)}", null, playerKey, authKey, null, out _, repeatKey: $"raid story {world}");
        return StoryState.Read(document.RootElement);
    }

    /// <summary>
    /// Adds companions to a Raid World's shared list.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="ids">The companions' actor ids.</param>
    /// <returns>The state as it now stands.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public StoryState AddCompanions(string world, string playerKey, string authKey, IReadOnlyList<int> ids)
    {
        var body = Json(writer =>
        {
            writer.WriteStartArray("ids");

            foreach (var id in ids)
            {
                writer.WriteNumberValue(id);
            }

            writer.WriteEndArray();
        });

        using var document = SendStory(HttpMethod.Post, StoryAddress(world, "/companions"), $"raid companions {Log.Short(world)}, {ids.Count} id(s)", body, playerKey, authKey, null, out _);
        return StoryState.Read(document.RootElement);
    }

    /// <summary>
    /// Fetches the story mapping every Raid World shares, as games read it.
    /// </summary>
    /// <param name="known">The revision this game holds, which the relay then answers alone; <see langword="null"/> for none.</param>
    /// <returns>The answer, which the caller disposes: <c>rev</c> and <c>same</c>, or the whole mapping.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or answered with an error.</exception>
    public JsonDocument GetStoryMapping(long? known)
    {
        var query = known is { } rev ? string.Create(CultureInfo.InvariantCulture, $"?known={rev}") : string.Empty;
        using var request = new HttpRequestMessage(HttpMethod.Get, new Uri($"{_mapping}{query}"));
        using var response = Exchange(request, TransferHttp, "story mapping", "story mapping");

        try
        {
            return JsonDocument.Parse(response.Content.ReadAsStream());
        }
        catch (Exception ex) when (ex is JsonException or HttpRequestException or System.IO.IOException)
        {
            throw new DirectoryException(response.StatusCode, "The relay's answer is no JSON.");
        }
    }

    /// <summary>
    /// Builds the address of one of a world's story routes.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="rest">What follows <c>/story</c>, empty for the story itself.</param>
    /// <returns>The address.</returns>
    private Uri StoryAddress(string world, string rest) => new($"{_worlds}/{Uri.EscapeDataString(world)}/story{rest}");

    /// <summary>
    /// Sends a request of a story or boss route with the player's and the world's keys, and reads its JSON answer.
    /// </summary>
    /// <param name="method">The method.</param>
    /// <param name="address">The address.</param>
    /// <param name="route">What the request does, for the log; never a key.</param>
    /// <param name="body">The JSON body, or <see langword="null"/> for none.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="expected">A status the route answers with besides success, whose answer is read too; <see langword="null"/> for none.</param>
    /// <param name="status">The status the relay answered with.</param>
    /// <param name="http">The client to send with; <see langword="null"/> for the one with the long timeout, as a world's story state may be large.</param>
    /// <param name="repeatKey">Names a request the game repeats, see <see cref="Exchange"/>.</param>
    /// <returns>The answer, which the caller disposes.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, or answered with an error.</exception>
    private static JsonDocument SendStory(HttpMethod method, Uri address, string route, string? body, string playerKey, string authKey, HttpStatusCode? expected, out HttpStatusCode status, HttpClient? http = null, string? repeatKey = null)
    {
        using var request = new HttpRequestMessage(method, address);

        if (body != null)
        {
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        }

        request.Headers.Add(PlayerHeader, playerKey);
        request.Headers.Add(AuthHeader, authKey);

        using var response = Exchange(request, http ?? TransferHttp, route, repeatKey, expected);
        status = response.StatusCode;

        try
        {
            return JsonDocument.Parse(response.Content.ReadAsStream());
        }
        catch (Exception ex) when (ex is JsonException or HttpRequestException or System.IO.IOException)
        {
            throw new DirectoryException(response.StatusCode, "The relay's answer is no JSON.");
        }
    }
}

/// <summary>
/// A Raid World's story state as the relay keeps it beside the tracks: its revision and the
/// companions it shares.
/// </summary>
/// <param name="Rev">The revision, which every change counts up.</param>
/// <param name="Comps">The companions the world shares, by actor id.</param>
/// <param name="Code">The code a refusal named why with, empty otherwise.</param>
internal sealed record StoryState(long Rev, IReadOnlyList<int> Comps, string Code)
{
    /// <summary>
    /// Reads the relay's answer.
    /// </summary>
    /// <param name="element">The answer.</param>
    /// <returns>The state.</returns>
    public static StoryState Read(JsonElement element) => new(
        element.TryGetProperty("rev", out var rev) && rev.ValueKind == JsonValueKind.Number && rev.TryGetInt64(out var number) ? number : 0,
        element.TryGetProperty("comps", out var comps) && comps.ValueKind == JsonValueKind.Array
            ? comps.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.Number && item.TryGetInt32(out _)).Select(item => item.GetInt32()).ToList()
            : [],
        element.TryGetProperty("code", out var code) && code.ValueKind == JsonValueKind.String ? code.GetString() ?? string.Empty : string.Empty);
}
