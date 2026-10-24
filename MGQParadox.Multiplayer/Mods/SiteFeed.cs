//----------------------------------------------------------------
//  SiteFeed.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Read each mod's thumbnail and fetched a mod's description
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Text;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Reads the website's list of its mods, <c>GET /api/mods</c>, and a mod's details,
/// <c>GET /api/mods/{slug}</c>, and takes them only with the website's signature.
/// </summary>
/// <remarks>
/// The key is built in rather than fetched, so whoever could change the list could not hand out a key of their own with it.
/// </remarks>
internal static class SiteFeed
{
    /// <summary>
    /// The list's address.
    /// </summary>
    public const string Address = "https://mgqonline.org/api/mods";

    /// <summary>
    /// The response header that carries the signature, base64 of r and s, 32 bytes each.
    /// </summary>
    public const string SignatureHeader = "X-MGQ-Signature";

    /// <summary>
    /// The response header that names the key the list was signed with.
    /// </summary>
    public const string KeyHeader = "X-MGQ-Signature-Key";

    /// <summary>
    /// The largest list taken.
    /// </summary>
    public const int MaxBytes = 8 * 1024 * 1024;

    /// <summary>
    /// Why the list failed when the website could not be reached or answered with an error.
    /// </summary>
    public const string Unreachable = "The website could not be reached.";

    /// <summary>
    /// Why the list failed when its signature is missing, of another key or wrong.
    /// </summary>
    public const string Unverified = "The mod list of the website could not be verified.";

    /// <summary>
    /// Why the list failed when it is signed but cannot be read.
    /// </summary>
    public const string Unreadable = "The mod list of the website could not be read.";

    /// <summary>
    /// The length of a P-256 signature as r and s side by side.
    /// </summary>
    private const int SignatureBytes = 64;

    /// <summary>
    /// Follows no redirect, since the list comes from its address alone.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(15) };

    /// <summary>
    /// The website's key the list is signed with.
    /// </summary>
    public static FeedKey PinnedKey { get; } = new("2efb340a85f6120d", "b2jL9pyjQ0fuMk8413XuKnwuogJGZrlu_ufo9c_qH9g", "mZvWzSgGvvPWJffqi8EwAj_zUV8F6sBSv8pXUwY1lro");

    /// <summary>
    /// Fetches the list and checks its signature.
    /// </summary>
    /// <param name="key">The key the list must be signed with.</param>
    /// <returns>The mods.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be verified or read.</exception>
    public static IReadOnlyList<SiteMod> Fetch(FeedKey key) => Fetch(key, Http);

    /// <summary>
    /// Fetches the list with a client of the caller's and checks its signature.
    /// </summary>
    /// <param name="key">The key the list must be signed with.</param>
    /// <param name="http">The client.</param>
    /// <returns>The mods.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be verified or read.</exception>
    internal static IReadOnlyList<SiteMod> Fetch(FeedKey key, HttpClient http) => Verified(Address, "mod list", key, http, Parse);

    /// <summary>
    /// Fetches a mod's details, <c>GET /api/mods/{slug}</c>, checks their signature and reads its description.
    /// </summary>
    /// <param name="key">The key the details must be signed with.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <returns>The description, Markdown; empty when the mod has none.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the details could not be verified or read.</exception>
    public static string FetchDescription(FeedKey key, string slug) => FetchDescription(key, slug, Http);

    /// <summary>
    /// Fetches a mod's details with a client of the caller's, checks their signature and reads its description.
    /// </summary>
    /// <param name="key">The key the details must be signed with.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="http">The client.</param>
    /// <returns>The description, Markdown; empty when the mod has none.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the details could not be verified or read.</exception>
    internal static string FetchDescription(FeedKey key, string slug, HttpClient http) =>
        Verified($"{Address}/{Uri.EscapeDataString(slug)}", $"details of {slug}", key, http, DescriptionOf);

    /// <summary>
    /// Fetches a signed answer of the website, checks its signature and reads it.
    /// </summary>
    /// <typeparam name="T">What is read of it.</typeparam>
    /// <param name="address">The answer's address.</param>
    /// <param name="what">What the answer is, for the log.</param>
    /// <param name="key">The key it must be signed with.</param>
    /// <param name="http">The client.</param>
    /// <param name="parse">Reads it.</param>
    /// <returns>What was read.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the answer could not be verified or read.</exception>
    private static T Verified<T>(string address, string what, FeedKey key, HttpClient http, Func<byte[], T> parse)
    {
        byte[] body;
        string? signature;
        string? keyId;
        var path = new Uri(address).AbsolutePath;

        try
        {
            using var response = http.Send(new HttpRequestMessage(HttpMethod.Get, address), HttpCompletionOption.ResponseHeadersRead);
            Log.Write($"website GET {path}: {(int)response.StatusCode}");

            if (response.StatusCode != HttpStatusCode.OK)
            {
                throw new SiteFeedException(Unreachable);
            }

            if (response.Content.Headers.ContentLength > MaxBytes)
            {
                Log.Write($"the website's {what} is larger than {MaxBytes} bytes");
                throw new SiteFeedException(Unreadable);
            }

            body = response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
            signature = HeaderOf(response, SignatureHeader);
            keyId = HeaderOf(response, KeyHeader);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            Log.Write($"website GET {path} failed: {ex.GetBaseException().Message}");
            throw new SiteFeedException(Unreachable);
        }

        return Read(body, signature, keyId, key, what, parse);
    }

    /// <summary>
    /// Checks a fetched answer's signature and reads it.
    /// </summary>
    /// <typeparam name="T">What is read of it.</typeparam>
    /// <param name="body">The answer exactly as it came.</param>
    /// <param name="signature">The signature header; <see langword="null"/> when it was missing.</param>
    /// <param name="keyId">The key header; <see langword="null"/> when it was missing.</param>
    /// <param name="key">The key the answer must be signed with.</param>
    /// <param name="what">What the answer is, for the log.</param>
    /// <param name="parse">Reads it.</param>
    /// <returns>What was read.</returns>
    /// <exception cref="SiteFeedException">The answer could not be verified or read.</exception>
    private static T Read<T>(byte[] body, string? signature, string? keyId, FeedKey key, string what, Func<byte[], T> parse)
    {
        if (body.Length > MaxBytes)
        {
            Log.Write($"the website's {what} is larger than {MaxBytes} bytes");
            throw new SiteFeedException(Unreadable);
        }

        if (Unsigned(body, signature, keyId, key) is { } why)
        {
            Log.Write($"the website's {what} of {body.Length} bytes could not be verified: {why}");
            throw new SiteFeedException(Unverified);
        }

        Log.Write($"the website's {what} of {body.Length} bytes is verified with key {key.Id}");

        try
        {
            return parse(body);
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or KeyNotFoundException or FormatException)
        {
            Log.Write($"the website's {what} could not be read: {ex.Message}");
            throw new SiteFeedException(Unreadable);
        }
    }

    /// <summary>
    /// Tells why a list is not signed with the key.
    /// </summary>
    /// <param name="body">The list exactly as it came.</param>
    /// <param name="signature">The signature header, or <see langword="null"/>.</param>
    /// <param name="keyId">The key header, or <see langword="null"/>.</param>
    /// <param name="key">The key the list must be signed with.</param>
    /// <returns>Why not, for the log; <see langword="null"/> when the signature is good.</returns>
    private static string? Unsigned(byte[] body, string? signature, string? keyId, FeedKey key)
    {
        if (string.IsNullOrEmpty(signature) || string.IsNullOrEmpty(keyId))
        {
            return "no signature";
        }

        if (keyId != key.Id)
        {
            return $"signed with key {keyId}, which this version does not know";
        }

        var bytes = new byte[SignatureBytes];

        if (!Convert.TryFromBase64String(signature, bytes, out var length) || length != SignatureBytes)
        {
            return "the signature is no P-256 signature";
        }

        using var ecdsa = ECDsa.Create(new ECParameters
        {
            Curve = ECCurve.NamedCurves.nistP256,
            Q = new ECPoint { X = Base64Url.DecodeFromChars(key.X), Y = Base64Url.DecodeFromChars(key.Y) },
        });

        return ecdsa.VerifyData(body, bytes, HashAlgorithmName.SHA256, DSASignatureFormat.IeeeP1363FixedFieldConcatenation) ? null : "the signature is wrong";
    }

    /// <summary>
    /// Reads the list.
    /// </summary>
    /// <param name="body">The list as JSON.</param>
    /// <returns>The mods, each with at least one version.</returns>
    private static List<SiteMod> Parse(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        var mods = new List<SiteMod>();

        foreach (var mod in document.RootElement.GetProperty("mods").EnumerateArray())
        {
            var versions = new List<SiteVersion>();

            foreach (var version in mod.GetProperty("versions").EnumerateArray())
            {
                var package = version.GetProperty("package");
                var files = new Dictionary<string, string>(StringComparer.Ordinal);

                foreach (var file in version.GetProperty("files").EnumerateArray())
                {
                    files[Text(file, "path")] = Text(file, "sha256").ToLowerInvariant();
                }

                versions.Add(new SiteVersion(
                    Text(version, "version"),
                    Text(version, "changelog"),
                    DateTimeOffset.Parse(Text(version, "uploadedAt"), CultureInfo.InvariantCulture),
                    new SitePackage(Text(package, "name"), package.TryGetProperty("size", out var size) && size.TryGetInt64(out var bytes) ? bytes : 0, Text(package, "sha256").ToLowerInvariant(), Text(package, "url")),
                    files));
            }

            if (versions.Count > 0)
            {
                var slug = Text(mod, "slug");
                mods.Add(new SiteMod(slug, Text(mod, "name"), Text(mod, "summary"), Text(mod, "author"), Text(mod, "page"), versions.OrderByDescending(version => version.UploadedAt).ToList(), ThumbnailOf(mod, slug)));
            }
        }

        return mods;
    }

    /// <summary>
    /// Reads a mod's thumbnail, taking it only on the website over HTTPS.
    /// </summary>
    /// <param name="mod">The mod as JSON.</param>
    /// <param name="slug">The mod's slug, for the log.</param>
    /// <returns>The thumbnail; <see langword="null"/> when it has none or one elsewhere.</returns>
    private static SiteThumbnail? ThumbnailOf(JsonElement mod, string slug)
    {
        if (!mod.TryGetProperty("thumbnail", out var thumbnail) || thumbnail.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var url = Text(thumbnail, "url");

        if (!Uri.TryCreate(url, UriKind.Absolute, out var address) || !SiteDownload.IsSite(address))
        {
            Log.Write($"the thumbnail of {slug} is left out: {(url.Length > 0 ? $"{url} is not on the website" : "it has no address")}");
            return null;
        }

        return new SiteThumbnail(address.AbsoluteUri, Number(thumbnail, "width"), Number(thumbnail, "height"), thumbnail.TryGetProperty("spoiler", out var spoiler) && spoiler.ValueKind == JsonValueKind.True);
    }

    /// <summary>
    /// Reads the description of a mod's details.
    /// </summary>
    /// <param name="body">The details as JSON.</param>
    /// <returns>The description; empty when it has none.</returns>
    private static string DescriptionOf(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        return Text(document.RootElement.GetProperty("mod"), "description");
    }

    /// <summary>
    /// Reads a whole number field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The number; 0 when the field is missing or no whole number.</returns>
    private static int Number(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : 0;

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The text; empty when the field is missing, null or no text.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

    /// <summary>
    /// Reads a response header.
    /// </summary>
    /// <param name="response">The response.</param>
    /// <param name="name">The header's name.</param>
    /// <returns>Its first value, <see langword="null"/> when it is missing.</returns>
    private static string? HeaderOf(HttpResponseMessage response, string name) =>
        response.Headers.TryGetValues(name, out var values) ? values.FirstOrDefault() : null;
}

/// <summary>
/// A list of the website that could not be had, for a reason the player is told as it is.
/// </summary>
/// <param name="reason">The reason.</param>
internal sealed class SiteFeedException(string reason) : Exception(reason);

/// <summary>
/// A public P-256 key the website signs its list with.
/// </summary>
/// <param name="Id">The key's id, as the key header names it.</param>
/// <param name="X">The point's x, base64url as in a JWK.</param>
/// <param name="Y">The point's y, base64url as in a JWK.</param>
internal sealed record FeedKey(string Id, string X, string Y);

/// <summary>
/// A mod of the website's list.
/// </summary>
/// <param name="Slug">The mod's id on the website.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Summary">What it does, in a sentence.</param>
/// <param name="Author">Who made it.</param>
/// <param name="Page">The mod's page on the website.</param>
/// <param name="Versions">Its versions, the latest upload first.</param>
/// <param name="Thumbnail">The image its card shows; <see langword="null"/> for none.</param>
internal sealed record SiteMod(string Slug, string Name, string Summary, string Author, string Page, IReadOnlyList<SiteVersion> Versions, SiteThumbnail? Thumbnail = null);

/// <summary>
/// The PNG image the card of a mod of the website shows.
/// </summary>
/// <param name="Url">Its address, on the website.</param>
/// <param name="Width">Its width in pixels, as the list names it.</param>
/// <param name="Height">Its height in pixels, as the list names it.</param>
/// <param name="Spoiler">Whether it shows a spoiler, so a card blurs it.</param>
internal sealed record SiteThumbnail(string Url, int Width, int Height, bool Spoiler);

/// <summary>
/// A version of a mod of the website.
/// </summary>
/// <param name="Version">The version.</param>
/// <param name="Changelog">What changed, Markdown.</param>
/// <param name="UploadedAt">When it was uploaded.</param>
/// <param name="Package">What a game downloads.</param>
/// <param name="Files">Each file's SHA-256 of its raw bytes by its path as the package holds it.</param>
internal sealed record SiteVersion(string Version, string Changelog, DateTimeOffset UploadedAt, SitePackage Package, IReadOnlyDictionary<string, string> Files);

/// <summary>
/// The file a version of a mod of the website is downloaded as: a script or a zip.
/// </summary>
/// <param name="Name">The file's name.</param>
/// <param name="Size">Its size in bytes.</param>
/// <param name="Sha256">The SHA-256 of its raw bytes.</param>
/// <param name="Url">Its address.</param>
internal sealed record SitePackage(string Name, long Size, string Sha256, string Url);
