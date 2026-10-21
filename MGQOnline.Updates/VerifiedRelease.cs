//----------------------------------------------------------------
//  VerifiedRelease.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Updates;

/// <summary>
/// A release whose manifest carries a valid signature.
/// </summary>
/// <param name="Manifest">The signed manifest.</param>
/// <param name="File">The manifest's file for this program's runtime.</param>
/// <param name="Minimum">The lowest version the relay still serves, or null when it names none.</param>
public sealed record VerifiedRelease(ReleaseManifest Manifest, ManifestFile File, ReleaseVersion? Minimum)
{
    /// <summary>
    /// The release's version.
    /// </summary>
    public ReleaseVersion Version => Manifest.Version;

    /// <summary>
    /// The release notes, from the signed manifest.
    /// </summary>
    public string Notes => Manifest.Notes;
}
