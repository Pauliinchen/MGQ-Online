//----------------------------------------------------------------
//  DirectoryClient.cs
//
//  Changelog:
//      Paulinchen  2026-10-02: Made worlds whose new players choose where to start, and read which worlds do
//      Paulinchen  2026-09-30: Read whether the list was made for an admin
//                            - Uploaded and downloaded a world's starting save, and read which worlds have one
//                            - Made hidden worlds, listed them for their players, and read a world's name with its lock
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
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

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
    /// How long uploading or downloading a starting save may take, on a slow line too.
    /// </summary>
    private static readonly TimeSpan TransferTimeout = TimeSpan.FromMinutes(3);

    /// <summary>
    /// Sends the requests, shared by every client.
    /// </summary>
    private static readonly HttpClient Http = new() { Timeout = RequestTimeout };

    /// <summary>
    /// Sends the starting saves, which take longer than the other requests.
    /// </summary>
    private static readonly HttpClient TransferHttp = new() { Timeout = TransferTimeout };

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
    /// Lists the worlds a player sees: every public world, and the hidden ones the player joined, or
    /// every world for one of the relay's admins.
    /// </summary>
    /// <param name="playerKey">The player's key, or <see langword="null"/> for the public worlds only.</param>
    /// <returns>The worlds, and whether the player is an admin.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached or answered with an error.</exception>
    public WorldListing List(string? playerKey)
    {
        var address = playerKey == null ? _worlds : new Uri($"{_worlds}?player={Uri.EscapeDataString(playerKey)}");
        using var document = Send(HttpMethod.Get, address, null);
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
                world.TryGetProperty("start", out var start) ? start.GetString() ?? "none" : "none",
                Flag(world, "hidden"),
                Flag(world, "choose"),
                members));
        }

        return new WorldListing(worlds, Flag(document.RootElement, "admin"));
    }

    /// <summary>
    /// Fetches a world's locked token, with the world's name, seats, starting save state and whether new players choose where to start.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>The lock and the world.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, knows no such world, or answered with an error.</exception>
    public LockedWorld Lock(string id)
    {
        using var document = Send(HttpMethod.Get, WorldAddress(id, "lock"), null);
        var root = document.RootElement;
        var worldLock = new WorldLock(root.GetProperty("salt").GetString()!, root.GetProperty("iterations").GetInt32(), root.GetProperty("box").GetString()!);
        return new LockedWorld(worldLock, root.GetProperty("name").GetString() ?? "?", root.GetProperty("seats").GetInt32(), root.GetProperty("start").GetString() ?? "none", Flag(root, "choose"));
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
    /// <param name="start">Whether a starting save follows, which keeps everyone out until it arrived.</param>
    /// <param name="hidden">Whether the list leaves it out for everyone but its players.</param>
    /// <param name="choose">Whether each new player chooses where to start.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused the world.</exception>
    public void Create(string id, string name, int seats, string playerKey, string playerName, string authHash, WorldLock worldLock, bool start, bool hidden, bool choose)
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
            writer.WriteBoolean("start", start);
            writer.WriteBoolean("hidden", hidden);
            writer.WriteBoolean("choose", choose);
        });

        using var _ = Send(HttpMethod.Post, _worlds, body);
    }

    /// <summary>
    /// Uploads a world's starting save, which only its creator may, once.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's key.</param>
    /// <param name="box">The starting save, see <see cref="StartingSave.Seal"/>.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void PutStart(string id, string playerKey, byte[] box)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, WorldAddress(id, $"start?player={Uri.EscapeDataString(playerKey)}"))
        {
            Content = new ByteArrayContent(box),
        };

        using var response = Exchange(request, TransferHttp);
        ThrowUnlessSuccess(response);
    }

    /// <summary>
    /// Downloads a world's starting save, which only its players may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <returns>The starting save as the creator uploaded it.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, the world has no starting save, or the player may not have it.</exception>
    public byte[] GetStart(string id, string playerKey, string authKey)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, WorldAddress(id, $"start?player={Uri.EscapeDataString(playerKey)}&auth={Uri.EscapeDataString(authKey)}"));
        using var response = Exchange(request, TransferHttp);
        ThrowUnlessSuccess(response);

        try
        {
            return response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            throw new DirectoryException(null, ex.GetBaseException().Message);
        }
    }

    /// <summary>
    /// Deletes a world for everyone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's or an admin's key.</param>
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
    /// Reads a flag of the directory's answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The flag's name.</param>
    /// <returns>Whether it is <see langword="true"/>; <see langword="false"/> when it is missing.</returns>
    private static bool Flag(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;

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

        using var response = Exchange(request, Http);
        ThrowUnlessSuccess(response);

        try
        {
            return JsonDocument.Parse(response.Content.ReadAsStream());
        }
        catch (JsonException)
        {
            throw new DirectoryException(response.StatusCode, "The relay's answer is no JSON.");
        }
    }

    /// <summary>
    /// Sends a request.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="http">The client to send it with.</param>
    /// <returns>The answer, which the caller disposes.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached.</exception>
    private static HttpResponseMessage Exchange(HttpRequestMessage request, HttpClient http)
    {
        try
        {
            return http.Send(request);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            throw new DirectoryException(null, ex.GetBaseException().Message);
        }
    }

    /// <summary>
    /// Turns an error answer into an exception with the directory's reason.
    /// </summary>
    /// <param name="response">The answer.</param>
    /// <exception cref="DirectoryException">The answer is an error.</exception>
    private static void ThrowUnlessSuccess(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        string? error = null;

        try
        {
            using var document = JsonDocument.Parse(response.Content.ReadAsStream());

            if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("error", out var reason))
            {
                error = reason.GetString();
            }
        }
        catch (Exception ex) when (ex is JsonException or IOException or HttpRequestException)
        {
        }

        throw new DirectoryException(response.StatusCode, error ?? $"HTTP {(int)response.StatusCode}");
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
/// The worlds the directory lists for a player.
/// </summary>
/// <param name="Worlds">The worlds.</param>
/// <param name="Admin">Whether the player is one of the relay's admins, who sees every world and may delete any.</param>
internal sealed record WorldListing(IReadOnlyList<ListedWorld> Worlds, bool Admin);

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
/// <param name="Start">How far it is with its starting save: "none", "pending" or "ready".</param>
/// <param name="Hidden">Whether the list leaves it out for everyone but its players.</param>
/// <param name="Choose">Whether each new player chooses where to start.</param>
/// <param name="Members">Everyone who ever joined it.</param>
internal sealed record ListedWorld(string Id, string Name, int Seats, string CreatorId, string CreatorName, int Online, long Active, string Start, bool Hidden, bool Choose, IReadOnlyList<ListedMember> Members);

/// <summary>
/// A world's locked token, with what a player who knows only the world's id needs to enter it.
/// </summary>
/// <param name="Lock">The locked token.</param>
/// <param name="Name">The world's name.</param>
/// <param name="Seats">How many games it seats at once.</param>
/// <param name="Start">How far it is with its starting save: "none", "pending" or "ready".</param>
/// <param name="Choose">Whether each new player chooses where to start.</param>
internal sealed record LockedWorld(WorldLock Lock, string Name, int Seats, string Start, bool Choose);

/// <summary>
/// A player of a world, as the directory lists them.
/// </summary>
/// <param name="Id">The player's id.</param>
/// <param name="Name">The player's name.</param>
/// <param name="Online">Whether the player is in the world now.</param>
internal sealed record ListedMember(string Id, string Name, bool Online);
