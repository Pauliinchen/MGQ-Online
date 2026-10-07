//----------------------------------------------------------------
//  UpdateCheck.cs
//
//  Changelog:
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

        var informationalVersion = typeof(UpdateCheck).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;

        if (ReleaseVersionOf(informationalVersion ?? string.Empty) is not { } installed)
        {
            Log.Write($"update check skipped: {informationalVersion} is no release");
            return;
        }

        new Thread(() => Run(installed)) { IsBackground = true, Name = "UpdateCheck" }.Start();
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
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
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
