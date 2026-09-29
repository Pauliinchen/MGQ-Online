//----------------------------------------------------------------
//  DirectoryClient.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// Talks to a relay's world directory over HTTP, see Relay/README.md.
/// </summary>
/// <remarks>
/// It reads and writes JSON by hand, since NativeAOT leaves out what serializing by reflection needs.
/// </remarks>
internal sealed class DirectoryClient
{
    /// <summary>
    /// How long one request may take.
    /// </summary>
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// Sends the requests, shared by every client.
    /// </summary>
    private static readonly HttpClient Http = new() { Timeout = RequestTimeout };

    /// <summary>
    /// The directory's address, /v1/worlds at the relay.
    /// </summary>
    private readonly Uri _worlds;

    /// <summary>
    /// Creates a client for a relay's directory.
    /// </summary>
    /// <param name="relay">The relay's address, wss:// or ws://, as <see cref="Relays"/> names it.</param>
    public DirectoryClient(Uri relay)
    {
        var web = new UriBuilder(relay) { Scheme = relay.Scheme == "wss" ? "https" : "http", Port = relay.IsDefaultPort ? -1 : relay.Port, Path = "/v1/worlds" };
        _worlds = web.Uri;
    }

    /// <summary>
    /// Lists every world.
    /// </summary>
    /// <returns>The worlds.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached or answered with an error.</exception>
    public IReadOnlyList<ListedWorld> List()
    {
        using var document = Send(HttpMethod.Get, _worlds, null);
        var worlds = new List<ListedWorld>();

        foreach (var world in document.RootElement.GetProperty("worlds").EnumerateArray())
        {
            var members = new List<ListedMember>();

            foreach (var member in world.GetProperty("members").EnumerateArray())
            {
                members.Add(new ListedMember(member.GetProperty("id").GetString()!, member.GetProperty("name").GetString() ?? "?", member.GetProperty("online").GetBoolean()));
            }

            var creator = world.GetProperty("creator");
            worlds.Add(new ListedWorld(
                world.GetProperty("id").GetString()!,
                world.GetProperty("name").GetString() ?? "?",
                world.GetProperty("seats").GetInt32(),
                creator.GetProperty("id").GetString()!,
                creator.GetProperty("name").GetString() ?? "?",
                world.GetProperty("online").GetInt32(),
                world.GetProperty("active").GetInt64(),
                members));
        }

        return worlds;
    }

    /// <summary>
    /// Fetches a world's locked token.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>The lock.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, knows no such world, or answered with an error.</exception>
    public WorldLock Lock(string id)
    {
        using var document = Send(HttpMethod.Get, WorldAddress(id, "lock"), null);
        var root = document.RootElement;
        return new WorldLock(root.GetProperty("salt").GetString()!, root.GetProperty("iterations").GetInt32(), root.GetProperty("box").GetString()!);
    }

    /// <summary>
    /// Makes a world.
    /// </summary>
    /// <param name="id">The world's id, its room's.</param>
    /// <param name="name">The world's name.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="playerKey">The creator's key.</param>
    /// <param name="playerName">The creator's name.</param>
    /// <param name="authHash">The hash of the world's auth key.</param>
    /// <param name="worldLock">The world's locked token.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused the world.</exception>
    public void Create(string id, string name, int seats, string playerKey, string playerName, string authHash, WorldLock worldLock)
    {
        var body = Json(writer =>
        {
            writer.WriteString("id", id);
            writer.WriteString("name", name);
            writer.WriteNumber("seats", seats);
            writer.WriteString("player", playerKey);
            writer.WriteString("playerName", playerName);
            writer.WriteString("authHash", authHash);
            writer.WriteStartObject("lock");
            writer.WriteString("salt", worldLock.Salt);
            writer.WriteNumber("iterations", worldLock.Iterations);
            writer.WriteString("box", worldLock.Box);
            writer.WriteEndObject();
        });

        using var _ = Send(HttpMethod.Post, _worlds, body);
    }

    /// <summary>
    /// Deletes a world for everyone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's key.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void Delete(string id, string playerKey)
    {
        using var _ = Send(HttpMethod.Post, WorldAddress(id, "delete"), Json(writer => writer.WriteString("player", playerKey)));
    }

    /// <summary>
    /// Removes a player from a world and keeps them out.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's key.</param>
    /// <param name="target">The id of the player to remove.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void Ban(string id, string playerKey, string target)
    {
        using var _ = Send(HttpMethod.Post, WorldAddress(id, "ban"), Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("target", target);
        }));
    }

    /// <summary>
    /// Builds the address of one of a world's routes.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="route">The route.</param>
    /// <returns>The address.</returns>
    private Uri WorldAddress(string id, string route) => new($"{_worlds}/{Uri.EscapeDataString(id)}/{route}");

    /// <summary>
    /// Sends a request and reads its JSON answer.
    /// </summary>
    /// <param name="method">The method.</param>
    /// <param name="address">The address.</param>
    /// <param name="body">The JSON body, or <see langword="null"/> for none.</param>
    /// <returns>The answer, which the caller disposes.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, or answered with an error.</exception>
    private static JsonDocument Send(HttpMethod method, Uri address, string? body)
    {
        using var request = new HttpRequestMessage(method, address);

        if (body != null)
        {
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        }

        HttpResponseMessage response;

        try
        {
            response = Http.Send(request);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            throw new DirectoryException(null, ex.GetBaseException().Message);
        }

        using (response)
        {
            using var stream = response.Content.ReadAsStream();
            JsonDocument? document = null;

            try
            {
                document = JsonDocument.Parse(stream);
            }
            catch (JsonException)
            {
            }

            if (response.IsSuccessStatusCode && document != null)
            {
                return document;
            }

            var error = document != null && document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("error", out var reason)
                ? reason.GetString()
                : null;
            document?.Dispose();
            throw new DirectoryException(response.StatusCode, error ?? $"HTTP {(int)response.StatusCode}");
        }
    }

    /// <summary>
    /// Writes a JSON object.
    /// </summary>
    /// <param name="write">Writes the object's properties.</param>
    /// <returns>The JSON text.</returns>
    private static string Json(Action<Utf8JsonWriter> write)
    {
        using var stream = new MemoryStream();

        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            write(writer);
            writer.WriteEndObject();
        }

        return Encoding.UTF8.GetString(stream.ToArray());
    }
}

/// <summary>
/// Why a directory request failed.
/// </summary>
/// <param name="status">The HTTP status the directory answered with, <see langword="null"/> when it was not reached.</param>
/// <param name="reason">The directory's reason, or what went wrong on the way.</param>
internal sealed class DirectoryException(HttpStatusCode? status, string reason) : Exception(reason)
{
    /// <summary>
    /// The HTTP status the directory answered with, <see langword="null"/> when it was not reached.
    /// </summary>
    public HttpStatusCode? Status { get; } = status;
}

/// <summary>
/// A world as the directory lists it.
/// </summary>
/// <param name="Id">The world's id.</param>
/// <param name="Name">The world's name.</param>
/// <param name="Seats">How many games it seats at once.</param>
/// <param name="CreatorId">The creator's player id.</param>
/// <param name="CreatorName">The creator's name.</param>
/// <param name="Online">How many players are in it now.</param>
/// <param name="Active">When someone was last in it, in milliseconds since 1970.</param>
/// <param name="Members">Everyone who ever joined it.</param>
internal sealed record ListedWorld(string Id, string Name, int Seats, string CreatorId, string CreatorName, int Online, long Active, IReadOnlyList<ListedMember> Members);

/// <summary>
/// A player of a world, as the directory lists them.
/// </summary>
/// <param name="Id">The player's id.</param>
/// <param name="Name">The player's name.</param>
/// <param name="Online">Whether the player is in the world now.</param>
internal sealed record ListedMember(string Id, string Name, bool Online);
