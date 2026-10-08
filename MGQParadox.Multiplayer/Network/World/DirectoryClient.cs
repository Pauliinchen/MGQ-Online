//----------------------------------------------------------------
//  DirectoryClient.cs
//
//  Changelog:
//      Paulinchen  2026-10-09: Made and changed a Raid World with its difficulty, and read it from the list
//      Paulinchen  2026-10-08: Read the answer of a status a route expects besides success, such as the 409 that hands back a Raid World's story
//                            - Named the Raid Worlds this game plays in the X-MGQ-Features header of every request
//                            - Made worlds of a type, Classic or Raid, with how a Raid World shares companions, and read both from the list
//                            - Read whether the relay kept the Mod Config options sent, and the version whose options it keeps
//      Paulinchen  2026-10-07: Logged every request with its method, route and outcome, and its time when it failed or was slow, a repeated request only once its outcome changed
//                            - Sent the world's auth key in the X-MGQ-Auth header instead of the address, and kept the outcomes last logged to a bounded number
//      Paulinchen  2026-10-06: Sent the player's key in the X-MGQ-Player header, and no longer in the addresses of the directory and the trades
//                            - Wrote JSON without escaping letters beyond ASCII, which made long descriptions too large for the relay
//                            - Read the code a refusal names why with
//                            - Committed, cancelled, read and finished trades, and listed those committed and not yet done
//                            - Sent the Mod Config options of a catalog mod, and read the version they came from
//                            - Sent a world's mod settings on their own, which the creator or an admin may, and no longer with the other changes
//                            - Read whether a link mod of the catalog is a zip
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
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Encodings.Web;
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
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// The request header that carries the player's key, which an address would leave in logs.
    /// </summary>
    public const string PlayerHeader = "X-MGQ-Player";

    /// <summary>
    /// The request header that carries the world's auth key, which an address would leave in logs.
    /// </summary>
    public const string AuthHeader = "X-MGQ-Auth";

    /// <summary>
    /// The request header that names what this game plays, which the relay keeps games without it out of Raid Worlds by.
    /// </summary>
    public const string FeaturesHeader = "X-MGQ-Features";

    /// <summary>
    /// What this game names in <see cref="FeaturesHeader"/>, separated by commas.
    /// </summary>
    public const string Features = WorldType.Raid;

    /// <summary>
    /// How many outcomes last logged are kept; once full they are forgotten, which only has a repeated request log once more.
    /// </summary>
    private const int MaxLastOutcomes = 64;

    /// <summary>
    /// Writes JSON with letters beyond ASCII as they are, since escaping each as six characters makes long texts too large for the relay.
    /// </summary>
    private static readonly JsonWriterOptions JsonOptions = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// How long one request may take.
    /// </summary>
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// How long uploading or downloading a starting save may take, on a slow line too.
    /// </summary>
    private static readonly TimeSpan TransferTimeout = TimeSpan.FromMinutes(3);

    /// <summary>
    /// How long a request may take before the log names its time even when it succeeded.
    /// </summary>
    private static readonly TimeSpan SlowRequest = TimeSpan.FromSeconds(2);

    /// <summary>
    /// The outcome last logged of each request the game repeats, by its repeat key, at most <see cref="MaxLastOutcomes"/>.
    /// </summary>
    private static readonly Dictionary<string, string> LastOutcomes = new(StringComparer.Ordinal);

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
    /// The trades' address, /v1/trades at the relay.
    /// </summary>
    private readonly Uri _trades;

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
        web.Path = "/v1/trades";
        _trades = web.Uri;
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
        var address = ids is { Count: > 0 } ? new Uri($"{_worlds}?ids={Uri.EscapeDataString(string.Join(',', ids))}") : _worlds;
        using var document = Send(HttpMethod.Get, address, "worlds", null, playerKey, "worlds");
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
                members,
                Text(world, "type") is { Length: > 0 } type ? type : WorldType.Classic,
                Text(world, "share") is { Length: > 0 } share ? share : CompanionSharing.Off,
                world.TryGetProperty("difficulty", out var difficulty) && difficulty.ValueKind == JsonValueKind.Number && difficulty.TryGetInt32(out var level) && WorldDifficulty.IsValid(level) ? level : null));
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
        using var document = Send(HttpMethod.Get, WorldAddress(id, "lock"), $"world lock {Log.Short(id)}", null);
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
    /// <param name="type">Its type, see <see cref="WorldType"/>.</param>
    /// <param name="share">How a Raid World shares companions, see <see cref="CompanionSharing"/>.</param>
    /// <param name="difficulty">The difficulty a Raid World sets for every player, see <see cref="WorldDifficulty"/>; <see langword="null"/> for none.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused the world.</exception>
    public void Create(string id, string name, int seats, string playerKey, string playerName, string authHash, WorldLock worldLock, bool start, bool hidden, bool choose, bool open, WorldAbout about, string type = WorldType.Classic, string share = CompanionSharing.Off, int? difficulty = null)
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
            writer.WriteString("type", type);
            writer.WriteString("share", share);

            if (difficulty is { } level)
            {
                writer.WriteNumber("difficulty", level);
            }
        });

        using var _ = Send(HttpMethod.Post, _worlds, $"world create {Log.Short(id)}", body, playerKey);
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
        using var request = new HttpRequestMessage(HttpMethod.Post, WorldAddress(id, "start"))
        {
            Content = new ByteArrayContent(box),
        };

        request.Headers.Add(PlayerHeader, playerKey);
        using var response = Exchange(request, TransferHttp, $"world start upload {Log.Short(id)}, {box.Length} bytes");
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
        using var request = new HttpRequestMessage(HttpMethod.Get, WorldAddress(id, "start"));
        request.Headers.Add(PlayerHeader, playerKey);
        request.Headers.Add(AuthHeader, authKey);
        using var response = Exchange(request, TransferHttp, $"world start download {Log.Short(id)}");

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
    /// Changes a world's seats, description, mods and a Raid World's difficulty, and for its creator the hashes of its required mods outside the catalog.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's or an admin's key.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="description">What the world is about.</param>
    /// <param name="mods">The mods it needs.</param>
    /// <param name="modHashes">The creator's mod hashes, <see langword="null"/> to leave them, as an admin must.</param>
    /// <param name="difficulty">A Raid World's new difficulty, see <see cref="WorldDifficulty"/>; <see langword="null"/> to leave it.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void Edit(string id, string playerKey, int seats, string description, string mods, string? modHashes = null, int? difficulty = null)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteNumber("seats", seats);
            writer.WriteString("description", description);
            writer.WriteString("mods", mods);

            if (modHashes != null)
            {
                writer.WriteString("modHashes", modHashes);
            }

            if (difficulty is { } level)
            {
                writer.WriteNumber("difficulty", level);
            }
        });

        using var _ = Send(HttpMethod.Post, WorldAddress(id, "edit"), $"world edit {Log.Short(id)}", body, playerKey);
    }

    /// <summary>
    /// Replaces a world's mod settings, which its creator or an admin may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's or an admin's key.</param>
    /// <param name="settings">The settings, "key=type:value" pairs separated by semicolons.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void SetSettings(string id, string playerKey, string settings)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("settings", settings);
        });

        using var _ = Send(HttpMethod.Post, WorldAddress(id, "edit"), $"world settings {Log.Short(id)}", body, playerKey);
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

        using var _ = Send(HttpMethod.Post, WorldAddress(id, "edit"), $"world data {Log.Short(id)}", body, playerKey);
    }

    /// <summary>
    /// Deletes a world for everyone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="playerKey">The creator's or an admin's key.</param>
    /// <exception cref="DirectoryException">The directory could not be reached or refused.</exception>
    public void Delete(string id, string playerKey)
    {
        using var _ = Send(HttpMethod.Post, WorldAddress(id, "delete"), $"world delete {Log.Short(id)}", Json(writer => writer.WriteString("player", playerKey)), playerKey);
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
        using var _ = Send(HttpMethod.Post, WorldAddress(id, "ban"), $"world ban {Log.Short(id)} of player {Log.Short(target)}", Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("target", target);
        }), playerKey);
    }

    /// <summary>
    /// Lists the relay's mod catalog.
    /// </summary>
    /// <returns>The mods.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or answered with an error.</exception>
    public IReadOnlyList<CatalogMod> Mods()
    {
        using var document = Send(HttpMethod.Get, _mods, "mods", null, repeatKey: "mods");
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

            mods.Add(new CatalogMod(Text(mod, "key"), Text(mod, "name"), Text(mod, "kind"), Text(mod, "version"), FilesOf(mod), versions, Text(mod, "fileUrl"), Flag(mod, "archive"), Text(mod, "optionsVersion")));
        }

        return mods;
    }

    /// <summary>
    /// Sends the Mod Config options of a catalog mod, as the game's copy offers them, which only an admin may.
    /// </summary>
    /// <param name="key">The mod's key.</param>
    /// <param name="playerKey">An admin's key.</param>
    /// <param name="version">The version the game's copy is; empty for a copy of no version the catalog knows.</param>
    /// <param name="options">The options.</param>
    /// <returns>Whether the relay kept them, which it does not while it keeps a newer version's, and the version whose options it keeps, empty when it does not say.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public (bool Kept, string KeptVersion) SetModOptions(string key, string playerKey, string version, IReadOnlyList<ModOption> options)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("version", version);
            writer.WriteStartArray("options");

            foreach (var option in options)
            {
                writer.WriteStartObject();
                writer.WriteString("key", option.Key);
                writer.WriteString("name", option.Name);
                writer.WriteString("type", option.Type);
                writer.WriteString("default", option.Default);
                writer.WriteStartArray("choices");

                foreach (var (value, name) in option.Choices)
                {
                    writer.WriteStartObject();
                    writer.WriteString("value", value);
                    writer.WriteString("name", name);
                    writer.WriteEndObject();
                }

                writer.WriteEndArray();
                writer.WriteEndObject();
            }

            writer.WriteEndArray();
        });

        using var document = Send(HttpMethod.Post, new Uri($"{_mods}/{Uri.EscapeDataString(key)}/options"), $"mod options {key} {version}, {options.Count} option(s)", body, playerKey);
        var root = document.RootElement;
        // Relays before kept took every version's options, and answered without saying so.
        var kept = !root.TryGetProperty("kept", out var answer) || answer.ValueKind != JsonValueKind.False;
        return (kept, root.TryGetProperty("mod", out var mod) && mod.ValueKind == JsonValueKind.Object ? Text(mod, "optionsVersion") : string.Empty);
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
        using var response = Exchange(request, TransferHttp, $"mod file {key}");

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
    /// Commits this player's side of a trade: the hash of the offers both games agreed on, and the offers sealed.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="world">The world both players trade in.</param>
    /// <param name="partner">The other player's id.</param>
    /// <param name="hash">The SHA-256 of the offers, hexadecimal.</param>
    /// <param name="sealedOffers">The offers, see <see cref="TradeSeal.Seal"/>.</param>
    /// <returns>Where the trade stands.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public TradeAnswer CommitTrade(string trade, string playerKey, string world, string partner, string hash, string sealedOffers)
    {
        var body = Json(writer =>
        {
            writer.WriteString("player", playerKey);
            writer.WriteString("world", world);
            writer.WriteString("partner", partner);
            writer.WriteString("hash", hash);
            writer.WriteString("sealed", sealedOffers);
        });

        using var document = Send(HttpMethod.Post, TradeAddress(trade, "commit"), $"trade commit {Log.Short(trade)}", body, playerKey, $"trade commit {trade}");
        return AnswerOf(document.RootElement);
    }

    /// <summary>
    /// Cancels a trade while it is pending; a committed one stays committed.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <param name="playerKey">The key of one of its two players.</param>
    /// <returns>Where the trade stands.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, knows no such trade, or refused.</exception>
    public TradeAnswer CancelTrade(string trade, string playerKey)
    {
        using var document = Send(HttpMethod.Post, TradeAddress(trade, "cancel"), $"trade cancel {Log.Short(trade)}", Json(writer => writer.WriteString("player", playerKey)), playerKey);
        return AnswerOf(document.RootElement);
    }

    /// <summary>
    /// Reads where a trade stands.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <param name="playerKey">The key of one of its two players.</param>
    /// <returns>Where the trade stands.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, knows no such trade, or refused.</exception>
    public TradeAnswer TradeState(string trade, string playerKey)
    {
        using var document = Send(HttpMethod.Get, new Uri($"{_trades}/{Uri.EscapeDataString(trade)}"), $"trade state {Log.Short(trade)}", null, playerKey, $"trade state {trade}");
        return AnswerOf(document.RootElement);
    }

    /// <summary>
    /// Marks a committed trade done for this player, whose game applied and saved it.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <exception cref="DirectoryException">The relay could not be reached, knows no such trade, or refused.</exception>
    public void TradeDone(string trade, string playerKey)
    {
        using var _ = Send(HttpMethod.Post, TradeAddress(trade, "done"), $"trade done {Log.Short(trade)}", Json(writer => writer.WriteString("player", playerKey)), playerKey);
    }

    /// <summary>
    /// Lists the committed trades of a world this player has not marked done.
    /// </summary>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="world">The world.</param>
    /// <returns>The trades, each with the offers as this player's game sealed them.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public IReadOnlyList<SealedTrade> PendingTrades(string playerKey, string world)
    {
        using var document = Send(HttpMethod.Get, new Uri($"{_trades}?world={Uri.EscapeDataString(world)}"), $"trades pending {Log.Short(world)}", null, playerKey);
        var trades = new List<SealedTrade>();

        foreach (var trade in document.RootElement.GetProperty("trades").EnumerateArray())
        {
            trades.Add(new SealedTrade(Text(trade, "id"), Text(trade, "hash"), Text(trade, "sealed")));
        }

        return trades;
    }

    /// <summary>
    /// Reads the relay's answer about a trade.
    /// </summary>
    /// <param name="element">The answer.</param>
    /// <returns>The trade's state, and why it was cancelled.</returns>
    private static TradeAnswer AnswerOf(JsonElement element) => new(Text(element, "state"), Text(element, "reason"));

    /// <summary>
    /// Builds the address of one of a trade's routes.
    /// </summary>
    /// <param name="trade">The trade's id.</param>
    /// <param name="route">The route.</param>
    /// <returns>The address.</returns>
    private Uri TradeAddress(string trade, string route) => new($"{_trades}/{Uri.EscapeDataString(trade)}/{route}");

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
    /// <param name="route">What the request does, for the log; never a key.</param>
    /// <param name="body">The JSON body, or <see langword="null"/> for none.</param>
    /// <param name="playerKey">The player's key, sent in <see cref="PlayerHeader"/>; <see langword="null"/> for none.</param>
    /// <param name="repeatKey">Names a request the game repeats, see <see cref="Exchange"/>.</param>
    /// <returns>The answer, which the caller disposes.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, or answered with an error.</exception>
    private static JsonDocument Send(HttpMethod method, Uri address, string route, string? body, string? playerKey = null, string? repeatKey = null)
    {
        using var request = new HttpRequestMessage(method, address);

        if (body != null)
        {
            request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        }

        if (playerKey != null)
        {
            request.Headers.Add(PlayerHeader, playerKey);
        }

        using var response = Exchange(request, Http, route, repeatKey);

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
    /// Sends a request and logs how it went.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="http">The client to send it with.</param>
    /// <param name="route">What the request does, for the log, such as "world lock 1a2b3c4d5e6f"; never a key.</param>
    /// <param name="repeatKey">Names a request the game repeats, which is logged only when its outcome changes or it was slow; <see langword="null"/> to log it every time.</param>
    /// <param name="expected">A status the route answers with besides success, which the caller reads instead of an exception; <see langword="null"/> for none.</param>
    /// <returns>The successful or expected answer, which the caller disposes.</returns>
    /// <exception cref="DirectoryException">The directory could not be reached, or answered with an error.</exception>
    private static HttpResponseMessage Exchange(HttpRequestMessage request, HttpClient http, string route, string? repeatKey = null, HttpStatusCode? expected = null)
    {
        var started = Stopwatch.GetTimestamp();
        request.Headers.Add(FeaturesHeader, Features);

        try
        {
            HttpResponseMessage response;

            try
            {
                response = http.Send(request);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
            {
                throw new DirectoryException(null, ex.GetBaseException().Message);
            }

            try
            {
                if (response.StatusCode != expected)
                {
                    ThrowUnlessSuccess(response);
                }
            }
            catch
            {
                response.Dispose();
                throw;
            }

            LogRequest(request.Method, route, ((int)response.StatusCode).ToString(CultureInfo.InvariantCulture), Stopwatch.GetElapsedTime(started), false, repeatKey);
            return response;
        }
        catch (DirectoryException ex)
        {
            LogRequest(request.Method, route, OutcomeOf(ex), Stopwatch.GetElapsedTime(started), true, repeatKey);
            throw;
        }
    }

    /// <summary>
    /// Describes a failed request for the log.
    /// </summary>
    /// <param name="ex">Why it failed.</param>
    /// <returns>The status and the code the directory named its reason with, or "unreachable", then the reason.</returns>
    private static string OutcomeOf(DirectoryException ex) =>
        ex.Status is { } status ? $"{(int)status}{(ex.Code != null ? $" {ex.Code}" : string.Empty)} ({ex.Message})" : $"unreachable ({ex.Message})";

    /// <summary>
    /// Logs how a request went, with its time when it failed or was slow.
    /// </summary>
    /// <param name="method">The request's method.</param>
    /// <param name="route">What the request does.</param>
    /// <param name="outcome">How it went.</param>
    /// <param name="elapsed">How long it took.</param>
    /// <param name="failed">Whether it failed.</param>
    /// <param name="repeatKey">Names a request the game repeats, see <see cref="Exchange"/>.</param>
    private static void LogRequest(HttpMethod method, string route, string outcome, TimeSpan elapsed, bool failed, string? repeatKey)
    {
        var slow = elapsed >= SlowRequest;

        if (repeatKey != null)
        {
            lock (LastOutcomes)
            {
                var same = LastOutcomes.TryGetValue(repeatKey, out var last) && last == outcome;

                if (!same && LastOutcomes.Count >= MaxLastOutcomes)
                {
                    LastOutcomes.Clear();
                }

                LastOutcomes[repeatKey] = outcome;

                if (same && !slow)
                {
                    return;
                }
            }
        }

        Log.Write($"relay {method.Method} {route}: {outcome}{(failed || slow ? $" after {elapsed.TotalMilliseconds.ToString("0", CultureInfo.InvariantCulture)} ms" : string.Empty)}");
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
        string? code = null;

        try
        {
            using var document = JsonDocument.Parse(response.Content.ReadAsStream());

            if (document.RootElement.ValueKind == JsonValueKind.Object)
            {
                error = Text(document.RootElement, "error") is { Length: > 0 } reason ? reason : null;
                code = Text(document.RootElement, "code") is { Length: > 0 } named ? named : null;
            }
        }
        catch (Exception ex) when (ex is JsonException or IOException or HttpRequestException)
        {
        }

        throw new DirectoryException(response.StatusCode, error ?? $"HTTP {(int)response.StatusCode}", code);
    }

    /// <summary>
    /// Writes a JSON object.
    /// </summary>
    /// <param name="write">Writes the object's properties.</param>
    /// <returns>The JSON text.</returns>
    private static string Json(Action<Utf8JsonWriter> write)
    {
        using var stream = new MemoryStream();

        using (var writer = new Utf8JsonWriter(stream, JsonOptions))
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
/// <param name="code">The code the directory named its reason with, such as "removed", <see langword="null"/> for none.</param>
internal sealed class DirectoryException(HttpStatusCode? status, string reason, string? code = null) : Exception(reason)
{
    /// <summary>
    /// The HTTP status the directory answered with, <see langword="null"/> when it was not reached.
    /// </summary>
    public HttpStatusCode? Status { get; } = status;

    /// <summary>
    /// The code the directory named its reason with, such as "removed", <see langword="null"/> for none.
    /// </summary>
    public string? Code { get; } = code;
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
/// <param name="Type">Its type, see <see cref="WorldType"/>; Classic for a world the relay names none of.</param>
/// <param name="Share">How a Raid World shares companions, see <see cref="CompanionSharing"/>; off for one the relay names none of.</param>
/// <param name="Difficulty">The difficulty a Raid World sets for every player, see <see cref="WorldDifficulty"/>; <see langword="null"/> for a world that sets none.</param>
internal sealed record ListedWorld(string Id, string Name, int Seats, string CreatorId, string CreatorName, int Online, long Active, string Start, bool Hidden, bool Choose, bool Open, bool Featured, WorldAbout About, IReadOnlyList<ListedMember> Members, string Type, string Share, int? Difficulty = null);

/// <summary>
/// A world's types, as the relay names them, fixed once the world is made.
/// </summary>
internal static class WorldType
{
    /// <summary>
    /// A world where each party plays its own story, as every world before Raid Worlds.
    /// </summary>
    public const string Classic = "classic";

    /// <summary>
    /// A world whose players all play one story together.
    /// </summary>
    public const string Raid = "raid";
}

/// <summary>
/// The difficulties a Raid World may set for every player, the game's own values of its difficulty
/// variable, as the relay takes them.
/// </summary>
internal static class WorldDifficulty
{
    /// <summary>
    /// The easiest, VERY EASY.
    /// </summary>
    public const int Min = -2;

    /// <summary>
    /// The hardest, PARADOX.
    /// </summary>
    public const int Max = 4;

    /// <summary>
    /// Tells whether a value is one of the game's difficulties.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsValid(int value) => value is >= Min and <= Max;
}

/// <summary>
/// How a Raid World shares companions, as the relay names it, fixed once the world is made.
/// </summary>
internal static class CompanionSharing
{
    /// <summary>
    /// No companion is shared, and every Classic world.
    /// </summary>
    public const string Off = "off";

    /// <summary>
    /// The story's companions are shared.
    /// </summary>
    public const string Story = "story";

    /// <summary>
    /// The story's companions and those recruited in battle are shared.
    /// </summary>
    public const string All = "all";
}

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
/// Where a trade stands, as the relay answers.
/// </summary>
/// <param name="State">"pending", "committed" or "cancelled".</param>
/// <param name="Reason">Why it was cancelled: "cancelled", "differ" or "expired"; empty otherwise.</param>
internal sealed record TradeAnswer(string State, string Reason);

/// <summary>
/// A committed trade as the relay keeps it for one of its players.
/// </summary>
/// <param name="Id">The trade's id.</param>
/// <param name="Hash">The SHA-256 of its offers, hexadecimal.</param>
/// <param name="Sealed">Its offers as this player's game sealed them, see <see cref="TradeSeal.Seal"/>.</param>
internal sealed record SealedTrade(string Id, string Hash, string Sealed);

/// <summary>
/// A player of a world, as the directory lists them.
/// </summary>
/// <param name="Id">The player's id.</param>
/// <param name="Name">The player's name.</param>
/// <param name="Online">Whether the player is in the world now.</param>
internal sealed record ListedMember(string Id, string Name, bool Online);
