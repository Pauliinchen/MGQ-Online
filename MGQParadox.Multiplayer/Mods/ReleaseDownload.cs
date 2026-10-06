//----------------------------------------------------------------
//  ReleaseDownload.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
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
    /// The largest release file taken, as on the relay.
    /// </summary>
    public const int MaxBytes = 2 * 1024 * 1024;

    /// <summary>
    /// The hosts GitHub serves release files from.
    /// </summary>
    private static readonly string[] FileHosts = ["objects.githubusercontent.com", "release-assets.githubusercontent.com"];

    /// <summary>
    /// Follows no redirect by itself, so each one is checked.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(2) };

    /// <summary>
    /// Tells whether an address is a release file of the admins' GitHub.
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
    public static byte[] Get(string url)
    {
        if (!IsReleaseFile(url))
        {
            throw new InvalidOperationException("The mod's address is no release file on the admins' GitHub.");
        }

        var address = new Uri(url);

        for (var hop = 0; hop <= 3; hop++)
        {
            using var response = Http.Send(new HttpRequestMessage(HttpMethod.Get, address));

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

            if (response.Content.Headers.ContentLength > MaxBytes)
            {
                throw new InvalidOperationException("The mod is larger than a script may be.");
            }

            var bytes = response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
            return bytes.Length is > 0 and <= MaxBytes ? bytes : throw new InvalidOperationException("The mod is empty or larger than a script may be.");
        }

        throw new InvalidOperationException("The mod was sent on too often.");
    }

    /// <summary>
    /// A release file of the admins' GitHub.
    /// </summary>
    [GeneratedRegex(@"^https://github\.com/Pauliinchen/[A-Za-z0-9._-]+/releases/download/[^/?#]+/[^/?#]+\.rb$")]
    private static partial Regex ReleaseFile();
}
