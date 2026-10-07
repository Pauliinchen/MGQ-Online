//----------------------------------------------------------------
//  ReleaseDownload.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Logged each request to GitHub with its outcome, and why a download was refused
//                            - Took the client to download with, so the tests hand in one of their own
//      Paulinchen  2026-10-06: Took a zip of a release too, up to the size an upload may have
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Downloads a link mod's release file from GitHub, by the same rules the relay checked it with:
/// a release file of the admins' GitHub, sent on only to GitHub's own file hosts.
/// </summary>
internal static partial class ReleaseDownload
{
    /// <summary>
    /// The largest script taken, as on the relay.
    /// </summary>
    public const int MaxScriptBytes = 2 * 1024 * 1024;

    /// <summary>
    /// The largest zip taken, as on the relay.
    /// </summary>
    public const int MaxZipBytes = 16 * 1024 * 1024;

    /// <summary>
    /// How many redirects a download follows at most.
    /// </summary>
    public const int MaxRedirects = 3;

    /// <summary>
    /// The hosts GitHub serves release files from.
    /// </summary>
    private static readonly string[] FileHosts = ["objects.githubusercontent.com", "release-assets.githubusercontent.com"];

    /// <summary>
    /// Follows no redirect by itself, so each one is checked.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(2) };

    /// <summary>
    /// Tells whether an address is a release file of the admins' GitHub, a script or a zip.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsReleaseFile(string url) => ReleaseFile().IsMatch(url);

    /// <summary>
    /// Tells whether a redirect may lead to an address.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>Whether it is on one of GitHub's file hosts, over HTTPS.</returns>
    public static bool IsFileHost(Uri url) => url.Scheme == Uri.UriSchemeHttps && FileHosts.Contains(url.Host, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Downloads a release file.
    /// </summary>
    /// <param name="url">The release file's address, as the catalog names it.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, or the download failed.</exception>
    public static byte[] Get(string url) => Get(url, Http);

    /// <summary>
    /// Downloads a release file with a client of the caller's, following at most <see cref="MaxRedirects"/> redirects to GitHub's file hosts.
    /// </summary>
    /// <param name="url">The release file's address, as the catalog names it.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, or the download failed.</exception>
    internal static byte[] Get(string url, HttpClient http)
    {
        if (!IsReleaseFile(url))
        {
            throw new InvalidOperationException("The mod's address is no release file on the admins' GitHub.");
        }

        var maxBytes = url.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) ? MaxZipBytes : MaxScriptBytes;
        var address = new Uri(url);
        Log.Write($"downloading {url}");

        for (var hop = 0; hop <= MaxRedirects; hop++)
        {
            using var response = http.Send(new HttpRequestMessage(HttpMethod.Get, address));
            Log.Write($"GitHub GET {address.Host}{address.AbsolutePath}: {(int)response.StatusCode}");

            if ((int)response.StatusCode is >= 300 and < 400)
            {
                var next = response.Headers.Location is { } location ? new Uri(address, location) : null;

                if (next == null || !IsFileHost(next))
                {
                    throw new InvalidOperationException($"The mod was sent on to {next?.Host ?? "nowhere"}, which is no GitHub file host.");
                }

                address = next;
                continue;
            }

            if (response.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException($"GitHub answered {(int)response.StatusCode}.");
            }

            if (response.Content.Headers.ContentLength > maxBytes)
            {
                throw new InvalidOperationException("The mod is larger than the relay takes.");
            }

            var bytes = response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
            return bytes.Length > 0 && bytes.Length <= maxBytes ? bytes : throw new InvalidOperationException("The mod is empty or larger than the relay takes.");
        }

        throw new InvalidOperationException("The mod was sent on too often.");
    }

    /// <summary>
    /// A release file of the admins' GitHub, a script or a zip.
    /// </summary>
    [GeneratedRegex(@"^https://github\.com/Pauliinchen/[A-Za-z0-9._-]+/releases/download/[^/?#]+/[^/?#]+\.(?:rb|zip)$", RegexOptions.IgnoreCase)]
    private static partial Regex ReleaseFile();
}
