//----------------------------------------------------------------
//  UpdateOffer.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Updates;

/// <summary>
/// Whether the running program is offered a release, and whether it must take it.
/// </summary>
/// <param name="Reason">Why the release is offered, or <see cref="UpdateReason.None"/>.</param>
/// <param name="Required">Whether the running version is below the relay's minimum.</param>
public sealed record UpdateOffer(UpdateReason Reason, bool Required)
{
    /// <summary>
    /// No release is offered.
    /// </summary>
    public static readonly UpdateOffer None = new(UpdateReason.None, false);

    /// <summary>
    /// Whether a release is offered.
    /// </summary>
    public bool Offered => Reason != UpdateReason.None;

    /// <summary>
    /// Decides whether the running program is offered a verified release.
    /// </summary>
    /// <remarks>
    /// A development build is never offered one, so a local build is never replaced by a release.
    /// </remarks>
    /// <param name="running">The running program's version.</param>
    /// <param name="runningSha256">The running exe's SHA-256, or null when it could not be read.</param>
    /// <param name="release">The verified release.</param>
    /// <returns>The offer.</returns>
    public static UpdateOffer Decide(ReleaseVersion running, string? runningSha256, VerifiedRelease release)
    {
        if (running.IsDevelopment)
        {
            return None;
        }

        var reason = release.Version > running ? UpdateReason.Newer
            : release.Version == running && runningSha256 != null
                && !string.Equals(runningSha256, release.File.Sha256, StringComparison.OrdinalIgnoreCase)
                ? UpdateReason.Rebuilt
            : UpdateReason.None;

        if (reason == UpdateReason.None)
        {
            return None;
        }

        return new UpdateOffer(reason, release.Minimum is { } minimum && running < minimum);
    }
}
