//----------------------------------------------------------------
//  UpdateReason.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Updates;

/// <summary>
/// Why a release is offered to the running program.
/// </summary>
public enum UpdateReason
{
    /// <summary>
    /// The release is not offered.
    /// </summary>
    None,

    /// <summary>
    /// The release has a newer version.
    /// </summary>
    Newer,

    /// <summary>
    /// The release has the running version but another build of it.
    /// </summary>
    Rebuilt,
}
