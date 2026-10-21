//----------------------------------------------------------------
//  ManifestFile.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Updates;

/// <summary>
/// One file of a release, as its manifest lists it.
/// </summary>
/// <param name="Rid">The runtime the file is built for, like <c>win-x64</c>.</param>
/// <param name="Name">The file's name among the release assets.</param>
/// <param name="Size">The file's length in bytes.</param>
/// <param name="Sha256">The file's SHA-256 as 64 lowercase hex digits.</param>
public sealed record ManifestFile(string Rid, string Name, long Size, string Sha256);
