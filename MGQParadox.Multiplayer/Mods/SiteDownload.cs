//----------------------------------------------------------------
//  SiteDownload.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Shared the download within the website with the thumbnails
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Downloads a mod of the website's list: only from the website over HTTPS, sent on only within
/// it, and only the file whose hash the signed list names.
/// </summary>
internal static class SiteDownload
{
    /// <summary>
    /// The website's host, the only one a download goes to.
    /// </summary>
    public const string Host = "mgqonline.org";

    /// <summary>
    /// The largest file taken, as the website takes.
    /// </summary>
    public const int MaxBytes = 64 * 1024 * 1024;

    /// <summary>
    /// How many redirects a download follows at most.
    /// </summary>
    public const int MaxRedirects = 3;

    /// <summary>
    /// Follows no redirect by itself, so each one is checked.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(5) };

    /// <summary>
    /// Tells whether an address is on the website, over HTTPS.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsSite(Uri url) => url.Scheme == Uri.UriSchemeHttps && string.Equals(url.Host, Host, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Downloads a mod's file.
    /// </summary>
    /// <param name="url">The file's address, as the list names it.</param>
    /// <param name="sha256">The SHA-256 of its raw bytes, as the list names it.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file differs, or the download failed.</exception>
    public static byte[] Get(string url, string sha256) => Get(url, sha256, Http);

    /// <summary>
    /// Downloads a mod's file with a client of the caller's, following at most <see cref="MaxRedirects"/> redirects within the website.
    /// </summary>
    /// <param name="url">The file's address, as the list names it.</param>
    /// <param name="sha256">The SHA-256 of its raw bytes, as the list names it.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file differs, or the download failed.</exception>
    internal static byte[] Get(string url, string sha256, HttpClient http) => Checked(url, Fetch(url, "mod", MaxBytes, http), sha256);

    /// <summary>
    /// Downloads a file of the website with a client of the caller's, following at most <see cref="MaxRedirects"/> redirects within the website.
    /// </summary>
    /// <param name="url">The file's address.</param>
    /// <param name="what">What the file is, such as "mod", for the player.</param>
    /// <param name="maxBytes">The largest file taken.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file is too large, or the download failed.</exception>
    internal static byte[] Fetch(string url, string what, int maxBytes, HttpClient http)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var address) || !IsSite(address))
        {
            Log.Write($"download of {url} refused: it is not on the website");
            throw new InvalidOperationException($"The {what}'s address is not on the website.");
        }

        Log.Write($"downloading {url}");

        try
        {
            for (var hop = 0; hop <= MaxRedirects; hop++)
            {
                using var response = http.Send(new HttpRequestMessage(HttpMethod.Get, address), HttpCompletionOption.ResponseHeadersRead);
                Log.Write($"website GET {address.AbsolutePath}: {(int)response.StatusCode}");

                if ((int)response.StatusCode is >= 300 and < 400)
                {
                    var next = response.Headers.Location is { } location ? new Uri(address, location) : null;

                    if (next == null || !IsSite(next))
                    {
                        Log.Write($"download of {url} refused: sent on to {next?.ToString() ?? "nowhere"}");
                        throw new InvalidOperationException($"The {what} was sent on to {next?.Host ?? "nowhere"}, which is not the website.");
                    }

                    address = next;
                    continue;
                }

                if (response.StatusCode != HttpStatusCode.OK)
                {
                    throw new InvalidOperationException($"The website answered {(int)response.StatusCode}.");
                }

                if (response.Content.Headers.ContentLength > maxBytes)
                {
                    Log.Write($"download of {url} refused: {response.Content.Headers.ContentLength} bytes, more than {maxBytes}");
                    throw new InvalidOperationException(TooLarge(what, maxBytes));
                }

                return ReadAtMost(response.Content, what, maxBytes);
            }
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            Log.Write($"download of {url} failed: {ex.GetBaseException().Message}");
            throw new InvalidOperationException("The website could not be reached.");
        }

        throw new InvalidOperationException($"The {what} was sent on too often.");
    }

    /// <summary>
    /// Reads a response's file, stopping once it grows larger than the largest file taken.
    /// </summary>
    /// <param name="content">The response's content.</param>
    /// <param name="what">What the file is, for the player.</param>
    /// <param name="maxBytes">The largest file taken.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The file is too large.</exception>
    private static byte[] ReadAtMost(HttpContent content, string what, int maxBytes)
    {
        using var stream = content.ReadAsStream();
        using var copy = new MemoryStream();
        var buffer = new byte[81920];
        int read;

        while ((read = stream.Read(buffer)) > 0)
        {
            copy.Write(buffer, 0, read);

            if (copy.Length > maxBytes)
            {
                throw new InvalidOperationException(TooLarge(what, maxBytes));
            }
        }

        return copy.ToArray();
    }

    /// <summary>
    /// Tells the player that a file is too large.
    /// </summary>
    /// <param name="what">What the file is.</param>
    /// <param name="maxBytes">The largest file taken.</param>
    /// <returns>The reason.</returns>
    private static string TooLarge(string what, int maxBytes) =>
        maxBytes == MaxBytes ? $"The {what} is larger than the website takes." : $"The {what} is larger than {maxBytes / (1024 * 1024)} MB.";

    /// <summary>
    /// Checks a downloaded file against the list's hash, and logs the outcome.
    /// </summary>
    /// <param name="url">The file's address, for the log.</param>
    /// <param name="bytes">The file.</param>
    /// <param name="sha256">The list's hash.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The file differs.</exception>
    private static byte[] Checked(string url, byte[] bytes, string sha256)
    {
        var actual = Convert.ToHexStringLower(SHA256.HashData(bytes));

        if (!string.Equals(actual, sha256, StringComparison.OrdinalIgnoreCase))
        {
            Log.Write($"{url} differs from the website's list: hash {Log.Short(actual)}, the list says {Log.Short(sha256)}");
            throw new InvalidOperationException("The mod differs from the version the website checked. It may just have been updated: refresh the list and try again.");
        }

        Log.Write($"{url} matches the website's list, {bytes.Length} bytes");
        return bytes;
    }
}
