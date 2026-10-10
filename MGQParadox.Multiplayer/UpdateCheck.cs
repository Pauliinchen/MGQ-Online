//----------------------------------------------------------------
//  UpdateCheck.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Told whether this DLL is a development build, which may give a Raid World a starting save
//      Paulinchen  2026-10-07: Started its thread through Threads, shared with the connections
//      Paulinchen  2026-09-30: Asked the repository under its new name, MGQ-Online
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer;

/// <summary>
/// Asks GitHub for the latest release of the mod, once per game session, on a thread of its own.
/// </summary>
internal static class UpdateCheck
{
    /// <summary>
    /// The latest release, as GitHub's API describes it.
    /// </summary>
    private const string LatestReleaseUrl =
        "https://api.github.com/repos/Pauliinchen/MGQ-Online/releases/latest";

    /// <summary>
    /// Names the mod to GitHub, which turns away requests without a user agent.
    /// </summary>
    private const string UserAgent = "MGQ-Online";

    /// <summary>
    /// The property of the release that holds its tag, like <c>v0.1.0</c>.
    /// </summary>
    private const string TagProperty = "tag_name";

    /// <summary>
    /// The version the project stamps on every build that no release workflow made.
    /// </summary>
    private const string DevelopmentVersion = "0.0.0-dev";

    /// <summary>
    /// How long the check waits for GitHub.
    /// </summary>
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// 1 once the check has been started, so a second start does nothing.
    /// </summary>
    private static int _started;

    /// <summary>
    /// Backs <see cref="NewerVersion"/>, written by the check's thread and read by the game's.
    /// </summary>
    private static string? _newerVersion;

    /// <summary>
    /// The latest release's version, like <c>0.1.0</c>, once the check found it newer than this DLL.
    /// </summary>
    public static string? NewerVersion => Volatile.Read(ref _newerVersion);

    /// <summary>
    /// Whether this DLL is a development build, stamped <c>0.0.0-dev</c>, which no release stamps.
    /// </summary>
    public static bool DevelopmentBuild { get; } = IsDevelopmentVersion(InformationalVersion);

    /// <summary>
    /// The version the build stamped, like <c>0.1.0+&lt;commit&gt;</c>, empty when it stamped none.
    /// </summary>
    private static string InformationalVersion =>
        typeof(UpdateCheck).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? string.Empty;

    /// <summary>
    /// Starts the check on a background thread, once per game session.
    /// </summary>
    /// <remarks>
    /// A development build has no release to compare with, so it never asks.
    /// </remarks>
    public static void Start()
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
        {
            return;
        }

        var informationalVersion = InformationalVersion;

        if (ReleaseVersionOf(informationalVersion) is not { } installed)
        {
            Log.Write($"update check skipped: {informationalVersion} is no release");
            return;
        }

        Threads.Start("MultiplayerUpdateCheck", () => Run(installed));
    }

    /// <summary>
    /// Reads the release version from the DLL's informational version.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped, like <c>0.1.0+&lt;commit&gt;</c>.</param>
    /// <returns>The version, or <see langword="null"/> for a development build like <c>0.0.0-dev</c>.</returns>
    internal static Version? ReleaseVersionOf(string informationalVersion)
    {
        var version = informationalVersion.Split('+')[0];
        return !version.Contains('-') && Version.TryParse(version, out var parsed) ? parsed : null;
    }

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

        return Version.TryParse(tag, out var latest) && latest > installed ? tag : null;
    }

    /// <summary>
    /// Asks GitHub and keeps the answer.
    /// </summary>
    /// <param name="installed">The version of this DLL.</param>
    private static void Run(Version installed)
    {
        try
        {
            using var http = new HttpClient { Timeout = Timeout };
            http.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);

            var newer = NewerRelease(installed, http.GetStringAsync(LatestReleaseUrl).GetAwaiter().GetResult());
            Volatile.Write(ref _newerVersion, newer);
            Log.Write(newer == null ? $"up to date at {installed}" : $"release {newer} is out, {installed} is installed");
        }
        catch (Exception ex)
        {
            Log.Write($"update check failed: {ex.Message}");
        }
    }
}
