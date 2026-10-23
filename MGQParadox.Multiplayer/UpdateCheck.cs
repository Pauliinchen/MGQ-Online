//----------------------------------------------------------------
//  UpdateCheck.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read release versions through ReleaseVersion
//      Paulinchen  2026-10-22: Asked the relay for the release to play first, an older one too, and GitHub only without its answer
//      Paulinchen  2026-10-12: Told the version this DLL names to the relay
//      Paulinchen  2026-10-10: Told whether this DLL is a development build
//      Paulinchen  2026-10-07: Started its thread through Threads
//      Paulinchen  2026-09-30: Asked the repository under its new name, MGQ-Online
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// A release the update check offers.
/// </summary>
/// <param name="Version">The release's version without the tag's <c>v</c>, like <c>0.6.8</c>.</param>
/// <param name="Rollback">Whether it is older than this DLL, a step back the relay asks for.</param>
internal sealed record ReleaseOffer(string Version, bool Rollback);

/// <summary>
/// Asks the relay which release the games should run, or GitHub for the latest release without the
/// relay's answer, once per game session, on a thread of its own.
/// </summary>
internal static class UpdateCheck
{
    /// <summary>
    /// The latest release, as GitHub's API describes it.
    /// </summary>
    private const string LatestReleaseUrl =
        "https://api.github.com/repos/Pauliinchen/MGQ-Online/releases/latest";

    /// <summary>
    /// The relay's route that names the release the games should run.
    /// </summary>
    private const string ReleasePath = "/v1/release";

    /// <summary>
    /// Names the mod to GitHub, which turns away requests without a user agent.
    /// </summary>
    private const string UserAgent = "MGQ-Online";

    /// <summary>
    /// The property of the release that holds its tag, like <c>v0.1.0</c>.
    /// </summary>
    private const string TagProperty = "tag_name";

    /// <summary>
    /// The property of the relay's answer that names the release the games should run.
    /// </summary>
    private const string CurrentProperty = "current";

    /// <summary>
    /// The version the project stamps on every build that no release workflow made.
    /// </summary>
    private const string DevelopmentVersion = "0.0.0-dev";

    /// <summary>
    /// How long the check waits for the relay, and then for GitHub.
    /// </summary>
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// 1 once the check has been started, so a second start does nothing.
    /// </summary>
    private static int _started;

    /// <summary>
    /// Backs <see cref="Offer"/>, written by the check's thread and read by the game's.
    /// </summary>
    private static ReleaseOffer? _offer;

    /// <summary>
    /// The release to install, once the check found one other than this DLL.
    /// </summary>
    public static ReleaseOffer? Offer => Volatile.Read(ref _offer);

    /// <summary>
    /// Whether this DLL is a development build, stamped <c>0.0.0-dev</c>, which no release stamps.
    /// </summary>
    public static bool DevelopmentBuild { get; } = IsDevelopmentVersion(InformationalVersion);

    /// <summary>
    /// The version this DLL names to the relay, like <c>0.6.4</c>, or <c>0.0.0-dev</c> for a development build.
    /// </summary>
    public static string ModVersion { get; } = VersionOf(InformationalVersion);

    /// <summary>
    /// The version the build stamped, like <c>0.1.0+&lt;commit&gt;</c>, empty when it stamped none.
    /// </summary>
    private static string InformationalVersion =>
        typeof(UpdateCheck).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? string.Empty;

    /// <summary>
    /// Starts the check on a background thread, once per game session.
    /// </summary>
    /// <remarks>
    /// A development or pre-release build has no release version to compare with, so it never asks.
    /// </remarks>
    public static void Start()
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
        {
            return;
        }

        var informationalVersion = InformationalVersion;

        if (ReleaseVersion.OfStamp(informationalVersion) is not { } installed)
        {
            Log.Write($"update check skipped: {informationalVersion} is no release");
            return;
        }

        Threads.Start("MultiplayerUpdateCheck", () => Run(installed));
    }

    /// <summary>
    /// Reads the version from the DLL's informational version, leaving out the commit.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped, like <c>0.1.0+&lt;commit&gt;</c>.</param>
    /// <returns>The version, like <c>0.1.0</c> or <c>0.0.0-dev</c>; empty when the build stamped none.</returns>
    internal static string VersionOf(string informationalVersion) => informationalVersion.Split('+')[0];

    /// <summary>
    /// Tells whether the DLL's informational version is the development stamp.
    /// </summary>
    /// <remarks>
    /// Any other version, a pre-release tag like <c>0.6.0-beta</c> included, is a published build.
    /// </remarks>
    /// <param name="informationalVersion">The version the build stamped, like <c>0.0.0-dev+&lt;commit&gt;</c>.</param>
    /// <returns><see langword="true"/> only for <c>0.0.0-dev</c>, with or without its commit.</returns>
    internal static bool IsDevelopmentVersion(string informationalVersion) =>
        string.Equals(informationalVersion.Split('+')[0], DevelopmentVersion, StringComparison.Ordinal);

    /// <summary>
    /// Compares the latest release with the installed version.
    /// </summary>
    /// <param name="installed">The version of this DLL.</param>
    /// <param name="releaseJson">GitHub's description of the latest release.</param>
    /// <returns>The release's version without its <c>v</c>, or <see langword="null"/> unless it is newer.</returns>
    internal static string? NewerRelease(Version installed, string releaseJson)
    {
        using var release = JsonDocument.Parse(releaseJson);
        var tag = release.RootElement.GetProperty(TagProperty).GetString()?.TrimStart('v');

        return ReleaseVersion.Parse(tag) is { } latest && latest > ReleaseVersion.Padded(installed) ? tag : null;
    }

    /// <summary>
    /// Reads the release the relay names for the games to run.
    /// </summary>
    /// <param name="releaseJson">The relay's answer to <c>GET /v1/release</c>.</param>
    /// <returns>The release's version, or <see langword="null"/> while the relay names none or names it in a form no release has.</returns>
    internal static string? CurrentRelease(string releaseJson)
    {
        using var release = JsonDocument.Parse(releaseJson);
        var root = release.RootElement;

        return root.ValueKind == JsonValueKind.Object && root.TryGetProperty(CurrentProperty, out var current) && current.ValueKind == JsonValueKind.String
            && ReleaseVersion.Parse(current.GetString()) != null ? current.GetString() : null;
    }

    /// <summary>
    /// Picks the release to offer: the relay's, whether newer or older than this DLL, or GitHub's
    /// latest when it is newer and the relay names none or cannot be asked.
    /// </summary>
    /// <param name="installed">The version of this DLL.</param>
    /// <param name="relay">Asks the relay, see <see cref="CurrentRelease"/>; throws when it cannot be reached.</param>
    /// <param name="github">Asks GitHub for its latest release's description; throws when it cannot be reached.</param>
    /// <returns>The release to offer, or <see langword="null"/> when this DLL is the one to run.</returns>
    internal static ReleaseOffer? Choose(Version installed, Func<string?> relay, Func<string> github)
    {
        string? current = null;

        try
        {
            current = relay();
        }
        catch (Exception ex)
        {
            Log.Write($"the relay could not tell the release to play, asking GitHub: {ex.GetBaseException().Message}");
        }

        if (ReleaseVersion.Parse(current) is { } wanted)
        {
            var offer = wanted == ReleaseVersion.Padded(installed) ? null : new ReleaseOffer(current!, wanted < ReleaseVersion.Padded(installed));
            Log.Write(offer == null ? $"the relay names {current}, which is installed" : $"the relay names {current}, {installed} is installed{(offer.Rollback ? ": a step back" : string.Empty)}");
            return offer;
        }

        var newer = NewerRelease(installed, github());
        Log.Write(newer == null ? $"up to date at {installed} by GitHub's latest release" : $"release {newer} is out on GitHub, {installed} is installed");
        return newer == null ? null : new ReleaseOffer(newer, false);
    }

    /// <summary>
    /// Names the relay's release route.
    /// </summary>
    /// <param name="relay">The relay's address, wss:// or ws://, as <see cref="Relays"/> names it.</param>
    /// <returns>The route's address over https:// or http://.</returns>
    internal static Uri ReleaseAddress(Uri relay) =>
        new UriBuilder(relay) { Scheme = relay.Scheme == "wss" ? "https" : "http", Port = relay.IsDefaultPort ? -1 : relay.Port, Path = ReleasePath }.Uri;

    /// <summary>
    /// Asks the relay and GitHub and keeps the answer.
    /// </summary>
    /// <param name="installed">The version of this DLL.</param>
    private static void Run(Version installed)
    {
        try
        {
            using var http = new HttpClient { Timeout = Timeout };
            http.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
            var relay = Relays.AddressOf(Relays.Current);

            var offer = Choose(
                installed,
                () => relay == null ? null : CurrentRelease(AskRelay(http, ReleaseAddress(relay))),
                () => http.GetStringAsync(LatestReleaseUrl).GetAwaiter().GetResult());

            Volatile.Write(ref _offer, offer);
        }
        catch (Exception ex)
        {
            Log.Write($"update check failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Asks the relay's release route, naming this game's version as every request to the relay does.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <param name="address">The route's address.</param>
    /// <returns>The answer's body.</returns>
    private static string AskRelay(HttpClient http, Uri address)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, address);
        request.Headers.Add(DirectoryClient.VersionHeader, ModVersion);
        using var response = http.Send(request);
        response.EnsureSuccessStatusCode();
        return response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
    }
}
