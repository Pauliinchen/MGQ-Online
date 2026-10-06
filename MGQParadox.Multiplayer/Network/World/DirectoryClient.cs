//----------------------------------------------------------------
//  DirectoryClient.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Read whether a link mod of the catalog is a zip
//                            - Read the mod catalog and an uploaded mod's zip
//                            - Made, changed and read worlds with the creator's hashes of required mods outside the catalog and its mod settings
//      Paulinchen  2026-10-04: Read a world's lock without the mods, the game data and the rule for it, which the list tells
//                            - Replaced a world's game data
//                            - Listed the hidden worlds named by their ids too
//                            - Changed a world's seats, description and mods
//                            - Made worlds with a description, the mods they need, the creator's game data and whether only games with the same data may enter, and read them
//      Paulinchen  2026-10-02: Made worlds whose new players choose where to start, and read which worlds do
//                            - Made worlds without a password, and read which worlds have none and which are featured
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
using MGQParadox.Multiplayer.Mods;
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
    /// The mod catalog's address, /v1/mods at the relay.
    /// </summary>
    private readonly Uri _mods;

    /// <summary>
    /// Creates a client for a relay's directory.
    /// </summary>
    /// <param name="relay">The relay's address, wss:// or ws://, as <see cref="Relays"/> names it.</param>
    public DirectoryClient(Uri relay)
    {
        var web = new UriBuilder(relay) { Scheme = relay.Scheme == "wss" ? "https" : "http", Port = relay.IsDefaultPort ? -1 : relay.Port, Path = "/v1/worlds" };
        _worlds = web.Uri;
        web.Path = "/v1/mods";
        _mods = web.Uri;
    }

    /// <summary>
    /// Lists the worlds a player sees: every public world, the hidden ones the player joined or
    /// names by their ids, or every world for one of the relay's admins.
    /// </summary>
    /// <param name="playerKey">The player's key, or <see langword="null"/> for none.</param>
    /// <param name="ids">The ids of hidden worlds to list too, <see langword="null"/> for none.</param>
    /// <returns>The worlds, and whether the player is an admin.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached or answered with an error.</exception>
    public WorldListing List(string? playerKey, IReadOnlyCollection<string>? ids = null)
    {
        var query = new List<string>();

        if (playerKey != null)
        {
            query.Add($"player={Uri.EscapeDataString(playerKey)}");
        }

        if (ids is { Count: > 0 })
        {
            query.Add($"ids={Uri.EscapeDataString(string.Join(',', ids))}");
        }

        var address = query.Count == 0 ? _worlds : new Uri($"{_worlds}?{string.Join('&', query)}");
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
                Flag(world, "open"),
                Flag(world, "featured"),
                new WorldAbout(Text(world, "description"), Text(world, "mods"), Text(world, "data"), Flag(world, "strict"), Text(world, "modHashes"), Text(world, "settings")),
                members));
        }

        return new WorldListing(worlds, Flag(document.RootElement, "admin"));
    }

    /// <summary>
    /// Fetches a world's locked token, with the world's name, seats, starting save state, and whether new players choose where to start.
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
    /// <param name="open">Whether its password is empty, so the games enter without asking for it.</param>
    /// <param name="about">What its creator tells about it.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused the world.</exception>
    public void Create(string id, string name, int seats, string playerKey, string playerName, string authHash, WorldLock worldLock, bool start, bool hidden, bool choose, bool open, WorldAbout about)
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
            writer.WriteBoolean("open", open);
            writer.WriteString("description", about.Description);
            writer.WriteString("mods", about.Mods);

            if (about.Data.Length > 0)
            {
                writer.WriteString("data", about.Data);
            }

            writer.WriteBoolean("strict", about.Strict);
            writer.WriteString("modHashes", about.ModHashes);
            writer.WriteString("settings", about.Settings);
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
    /// Changes a world's seats, description and mods, and for its creator the hashes of its required mods outside the catalog and its mod settings.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's or an admin's key.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="description">What the world is about.</param>
    /// <param name="mods">The mods it needs.</param>
    /// <param name="creatorMods">The creator's mod hashes and mod settings, <see langword="null"/> to leave them, as an admin must.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void Edit(string id, string playerKey, int seats, string description, string mods, (string ModHashes, string Settings)? creatorMods = null)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteNumber("seats", seats);
            writer.WriteString("description", description);
            writer.WriteString("mods", mods);

            if (creatorMods is var (modHashes, settings))
            {
                writer.WriteString("modHashes", modHashes);
                writer.WriteString("settings", settings);
            }
        });

        using var _ = Send(HttpMethod.Post, WorldAddress(id, "edit"), body);
    }

    /// <summary>
    /// Replaces a world's game data, which only its creator may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's key.</param>
    /// <param name="data">What tells the creator's game data from another's.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void SetData(string id, string playerKey, string data)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("data", data);
        });

        using var _ = Send(HttpMethod.Post, WorldAddress(id, "edit"), body);
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
/// Lists the relay's mod catalog.
/// </summary>
/// <returns>The mods.</returns>
/// <exception cref="DirectoryException">The relay could not be reached or answered with an error.</exception>
public IReadOnlyList<CatalogMod> Mods()
{
    using var document = Send(HttpMethod.Get, _mods, null);
    var mods = new List<CatalogMod>();

    foreach (var mod in document.RootElement.GetProperty("mods").EnumerateArray())
    {
        var versions = new List<ModVersion>();

        if (mod.TryGetProperty("versions", out var listed) && listed.ValueKind == JsonValueKind.Array)
        {
            foreach (var version in listed.EnumerateArray())
            {
                versions.Add(new ModVersion(Text(version, "version"), FilesOf(version)));
            }
        }

        mods.Add(new CatalogMod(Text(mod, "key"), Text(mod, "name"), Text(mod, "kind"), Text(mod, "version"), FilesOf(mod), versions, Text(mod, "fileUrl"), Flag(mod, "archive")));
    }

    return mods;
}

/// <summary>
/// Downloads an uploaded mod's zip.
/// </summary>
/// <param name="key">The mod's key.</param>
/// <returns>The zip.</returns>
/// <exception cref="DirectoryException">The relay could not be reached, has no such mod, or answered with an error.</exception>
public byte[] ModFile(string key)
{
    using var request = new HttpRequestMessage(HttpMethod.Get, new Uri($"{_mods}/{Uri.EscapeDataString(key)}/file"));
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
/// Reads a catalog entry's files.
/// </summary>
/// <param name="element">The entry or version holding them.</param>
/// <returns>Each file's hash by its name or path.</returns>
private static Dictionary<string, string> FilesOf(JsonElement element)
{
    var files = new Dictionary<string, string>(StringComparer.Ordinal);

    if (element.TryGetProperty("files", out var listed) && listed.ValueKind == JsonValueKind.Object)
    {
        foreach (var file in listed.EnumerateObject())
        {
            files[file.Name] = file.Value.GetString() ?? string.Empty;
        }
    }

    return files;
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
    /// Reads a text of the directory's answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The text's name.</param>
    /// <returns>The text; empty when it is missing.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

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
/// <param name="Open">Whether it has no password.</param>
/// <param name="Featured">Whether it is one of the relay's own worlds, which an admin made.</param>
/// <param name="About">What its creator tells about it.</param>
/// <param name="Members">Everyone who ever joined it.</param>
internal sealed record ListedWorld(string Id, string Name, int Seats, string CreatorId, string CreatorName, int Online, long Active, string Start, bool Hidden, bool Choose, bool Open, bool Featured, WorldAbout About, IReadOnlyList<ListedMember> Members);

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
/// What a world's creator tells about it.
/// </summary>
/// <param name="Description">What the world is about.</param>
/// <param name="Mods">The mods it needs.</param>
/// <param name="Data">What tells the creator's game data from another's, which the game script writes and compares; empty when unknown.</param>
/// <param name="Strict">Whether only games with the same data may enter.</param>
/// <param name="ModHashes">The creator's hashes of the required mods outside the mod catalog, <c>name=hash</c> pairs separated by semicolons; empty for none.</param>
/// <param name="Settings">The creator's settings of the mods the world names, <c>key=type:value</c> pairs separated by semicolons; empty for none.</param>
internal sealed record WorldAbout(string Description, string Mods, string Data, bool Strict, string ModHashes = "", string Settings = "")
{
    /// <summary>
    /// Nothing told, and every game may enter.
    /// </summary>
    public static WorldAbout None { get; } = new(string.Empty, string.Empty, string.Empty, false);
}

/// <summary>
/// A player of a world, as the directory lists them.
/// </summary>
/// <param name="Id">The player's id.</param>
/// <param name="Name">The player's name.</param>
/// <param name="Online">Whether the player is in the world now.</param>
internal sealed record ListedMember(string Id, string Name, bool Online);
