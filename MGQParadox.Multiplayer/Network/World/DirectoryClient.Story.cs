//----------------------------------------------------------------
//  DirectoryClient.Story.cs
//
//  Changelog:
//      Paulinchen  2026-10-09: Logged the fetch of a world's story only when its outcome changed or it was slow, and let a boss route's request name the client it is sent with
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

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The routes of a Raid World's story at the relay, see docs/DEVELOPER.md, "World story on the relay".
/// </summary>
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// Fetches a Raid World's story as it stands.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <returns>The story with its sealed text.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, the world is no Raid World, or the player may not read it.</exception>
    public StoryState GetStory(string world, string playerKey, string authKey)
    {
        using var document = SendStory(HttpMethod.Get, StoryAddress(world, string.Empty), $"raid story {Log.Short(world)}", null, playerKey, authKey, null, out _, repeatKey: $"raid story {world}");
        return StoryState.Read(document.RootElement);
    }

    /// <summary>
    /// Writes a Raid World's story, which the relay takes only when it built on the story as it
    /// stands and its counters are not behind it.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="baseRev">The revision the story was built on.</param>
    /// <param name="counters">The counters the relay reads.</param>
    /// <param name="sealedStory">The story, see <see cref="StorySeal.Seal"/>.</param>
    /// <returns>Whether the relay took it, with the state as it now stands; a refused write comes with the world's sealed story and the code that names why.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused for another reason.</exception>
    public StoryAnswer PostStory(string world, string playerKey, string authKey, long baseRev, StoryCounters counters, string sealedStory)
    {
        var body = Json(writer =>
        {
            writer.WriteNumber("base", baseRev);
            writer.WriteStartObject("counters");
            counters.Write(writer);
            writer.WriteEndObject();
            writer.WriteString("blob", sealedStory);
        });

        using var document = SendStory(HttpMethod.Post, StoryAddress(world, string.Empty), $"raid story write {Log.Short(world)} on rev {baseRev}, {sealedStory.Length} characters", body, playerKey, authKey, HttpStatusCode.Conflict, out var status);
        return new StoryAnswer(status != HttpStatusCode.Conflict, StoryState.Read(document.RootElement));
    }

    /// <summary>
    /// Fetches a part's checkpoint of a Raid World's story.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="part">The part: 1, 2, 3, ad, mr or chaos.</param>
    /// <returns>The checkpoint with its sealed text, or <see langword="null"/> when the world has none of that part.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, the world is no Raid World, or the player may not read it.</exception>
    public StoryState? GetCheckpoint(string world, string playerKey, string authKey, string part)
    {
        using var document = SendStory(HttpMethod.Get, StoryAddress(world, $"/checkpoint/{Uri.EscapeDataString(part)}"), $"raid checkpoint {Log.Short(world)} part {part}", null, playerKey, authKey, HttpStatusCode.NotFound, out var status);

        if (status != HttpStatusCode.NotFound)
        {
            return StoryState.Read(document.RootElement);
        }

        var code = Text(document.RootElement, "code");
        return code == StoryState.NoCheckpoint ? null : throw new DirectoryException(status, Text(document.RootElement, "error") is { Length: > 0 } error ? error : "HTTP 404", code.Length > 0 ? code : null);
    }

    /// <summary>
    /// Locks the route a Raid World takes at the Great Decision; the first route locked wins.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="route">The route: ad, mr or chaos.</param>
    /// <returns>Whether the route is locked, with the state as it stands; a refusal names why in its code.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused for another reason.</exception>
    public StoryAnswer LockRoute(string world, string playerKey, string authKey, string route)
    {
        var body = Json(writer => writer.WriteString("route", route));
        using var document = SendStory(HttpMethod.Post, StoryAddress(world, "/route"), $"raid route lock {Log.Short(world)} {route}", body, playerKey, authKey, HttpStatusCode.Conflict, out var status);
        return new StoryAnswer(status != HttpStatusCode.Conflict, StoryState.Read(document.RootElement));
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
    /// <param name="http">The client to send with; <see langword="null"/> for the one with the long timeout of a story, which is up to 200 KB each way and takes a slow line longer than other requests.</param>
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
/// What the relay answered a story write or a route lock.
/// </summary>
/// <param name="Taken">Whether it took the write or locked the route.</param>
/// <param name="State">The story as it stands; for a refusal with the world's sealed story and the code that names why.</param>
internal sealed record StoryAnswer(bool Taken, StoryState State);

/// <summary>
/// Where the last story teleport of a Raid World went.
/// </summary>
/// <param name="Map">The map's id.</param>
/// <param name="X">The x tile.</param>
/// <param name="Y">The y tile.</param>
internal sealed record StoryEnd(int Map, int X, int Y)
{
    /// <summary>
    /// Writes the endpoint as the game script reads it.
    /// </summary>
    /// <returns>"map,x,y".</returns>
    public override string ToString() => string.Create(CultureInfo.InvariantCulture, $"{Map},{X},{Y}");
}

/// <summary>
/// A Raid World's story as the relay keeps it: the counters it reads, and the story sealed.
/// </summary>
/// <param name="Rev">The revision, which every change counts up.</param>
/// <param name="WRev">The revision of the last write, whose sealed story this is.</param>
/// <param name="P">Variable 1001, the story's progress.</param>
/// <param name="R1141">Variable 1141, how far the Angelic Dominion route is.</param>
/// <param name="R1142">Variable 1142, how far the Monster Realm route is.</param>
/// <param name="R1143">Variable 1143, how far the Chaos route is.</param>
/// <param name="Clear">The finished routes the last write named.</param>
/// <param name="Part">The part the story is in: 1, 2, 3, ad, mr or chaos.</param>
/// <param name="Route">The route locked: none, ad, mr or chaos.</param>
/// <param name="Done">The routes the world finished, in the order it did.</param>
/// <param name="End">Where the last story teleport went, <see langword="null"/> for nowhere.</param>
/// <param name="Comps">The companions the world shares, by actor id.</param>
/// <param name="Checkpoints">The parts the world keeps a checkpoint of.</param>
/// <param name="Blob">The sealed story, empty before the first write.</param>
/// <param name="Code">The code a refusal named why with, empty otherwise.</param>
internal sealed record StoryState(long Rev, long WRev, int P, int R1141, int R1142, int R1143, IReadOnlyList<string> Clear, string Part, string Route, IReadOnlyList<string> Done, StoryEnd? End, IReadOnlyList<int> Comps, IReadOnlyList<string> Checkpoints, string Blob, string Code)
{
    /// <summary>
    /// The code of a 404 for a part the world keeps no checkpoint of.
    /// </summary>
    public const string NoCheckpoint = "none";

    /// <summary>
    /// Reads the relay's answer.
    /// </summary>
    /// <param name="element">The answer.</param>
    /// <returns>The story.</returns>
    public static StoryState Read(JsonElement element) => new(
        Number(element, "rev"),
        Number(element, "wrev"),
        (int)Number(element, "p"),
        (int)Number(element, "r1141"),
        (int)Number(element, "r1142"),
        (int)Number(element, "r1143"),
        Texts(element, "clear"),
        Text(element, "part"),
        Text(element, "route"),
        Texts(element, "done"),
        EndOf(element),
        Numbers(element, "comps"),
        Texts(element, "checkpoints"),
        Text(element, "blob"),
        Text(element, "code"));

    /// <summary>
    /// Reads a whole number of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The number; 0 when it is missing.</returns>
    private static long Number(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number) ? number : 0;

    /// <summary>
    /// Reads a text of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The text; empty when it is missing.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

    /// <summary>
    /// Reads a list of texts of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The texts; empty when the list is missing.</returns>
    private static List<string> Texts(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array
            ? value.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString() ?? string.Empty).ToList()
            : [];

    /// <summary>
    /// Reads a list of whole numbers of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The numbers; empty when the list is missing.</returns>
    private static List<int> Numbers(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Array
            ? value.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.Number && item.TryGetInt32(out _)).Select(item => item.GetInt32()).ToList()
            : [];

    /// <summary>
    /// Reads the story's endpoint of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <returns>The endpoint, or <see langword="null"/> for none.</returns>
    private static StoryEnd? EndOf(JsonElement element) =>
        element.TryGetProperty("end", out var end) && end.ValueKind == JsonValueKind.Object
            ? new StoryEnd((int)Number(end, "map"), (int)Number(end, "x"), (int)Number(end, "y"))
            : null;
}

/// <summary>
/// The counters of a story write, which the relay reads to tell which story is further.
/// </summary>
/// <param name="P">Variable 1001.</param>
/// <param name="R1141">Variable 1141.</param>
/// <param name="R1142">Variable 1142.</param>
/// <param name="R1143">Variable 1143.</param>
/// <param name="Clear">The finished routes, by their clear switches 7096 (ad), 7097 (mr) and 7039 (chaos).</param>
/// <param name="End">Where the last story teleport went, <see langword="null"/> to forget it.</param>
/// <param name="KeepEnd">Whether to keep the endpoint the relay has, leaving <paramref name="End"/> out.</param>
internal sealed record StoryCounters(int P, int R1141, int R1142, int R1143, IReadOnlyList<string> Clear, StoryEnd? End, bool KeepEnd)
{
    /// <summary>
    /// The routes, by the names the relay and the game script use.
    /// </summary>
    public static readonly string[] Routes = ["ad", "mr", "chaos"];

    /// <summary>
    /// Reads the counters the game script hands over.
    /// </summary>
    /// <param name="text"><c>key=value</c> pairs separated by semicolons: <c>p</c>, <c>r1141</c>, <c>r1142</c> and <c>r1143</c> as whole numbers of 0 or more, <c>clear</c> the finished routes separated by commas, and <c>end</c> as <c>map,x,y</c>, empty to forget the endpoint, left out to keep it.</param>
    /// <returns>The counters, or <see langword="null"/> when the text is not as it should be.</returns>
    public static StoryCounters? Parse(string text)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var pair in text.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var equals = pair.IndexOf('=', StringComparison.Ordinal);

            if (equals <= 0 || !values.TryAdd(pair[..equals].Trim(), pair[(equals + 1)..].Trim()))
            {
                return null;
            }
        }

        if (values.Keys.Any(key => key is not ("p" or "r1141" or "r1142" or "r1143" or "clear" or "end")))
        {
            return null;
        }

        int[] numbers = [0, 0, 0, 0];
        string[] names = ["p", "r1141", "r1142", "r1143"];

        for (var index = 0; index < names.Length; index++)
        {
            if (!values.TryGetValue(names[index], out var value) || !int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out numbers[index]))
            {
                return null;
            }
        }

        var clear = values.TryGetValue("clear", out var cleared) ? cleared.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries) : [];

        if (clear.Any(route => !Routes.Contains(route)) || clear.Distinct().Count() != clear.Length || numbers.Skip(1).Count(number => number > 0) > 1)
        {
            return null;
        }

        StoryEnd? end = null;

        if (values.TryGetValue("end", out var endText) && endText.Length > 0)
        {
            var tiles = endText.Split(',', StringSplitOptions.TrimEntries);
            var parsed = tiles.Select(tile => int.TryParse(tile, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : -1).ToArray();

            if (parsed.Length != 3 || parsed.Any(number => number < 0) || parsed[0] == 0)
            {
                return null;
            }

            end = new StoryEnd(parsed[0], parsed[1], parsed[2]);
        }

        return new StoryCounters(numbers[0], numbers[1], numbers[2], numbers[3], Routes.Where(clear.Contains).ToList(), end, !values.ContainsKey("end"));
    }

    /// <summary>
    /// Writes the counters into the JSON object the relay reads.
    /// </summary>
    /// <param name="writer">The writer, inside the counters' object.</param>
    public void Write(Utf8JsonWriter writer)
    {
        writer.WriteNumber("p", P);
        writer.WriteNumber("r1141", R1141);
        writer.WriteNumber("r1142", R1142);
        writer.WriteNumber("r1143", R1143);
        writer.WriteStartArray("clear");

        foreach (var route in Clear)
        {
            writer.WriteStringValue(route);
        }

        writer.WriteEndArray();

        if (KeepEnd)
        {
            return;
        }

        if (End is { } end)
        {
            writer.WriteStartObject("end");
            writer.WriteNumber("map", end.Map);
            writer.WriteNumber("x", end.X);
            writer.WriteNumber("y", end.Y);
            writer.WriteEndObject();
        }
        else
        {
            writer.WriteNull("end");
        }
    }
}
