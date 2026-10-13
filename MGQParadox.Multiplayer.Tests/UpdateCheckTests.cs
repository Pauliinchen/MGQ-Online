//----------------------------------------------------------------
//  UpdateCheckTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Covered the version named to the relay
//      Paulinchen  2026-10-10: Covered telling a development build by its stamp
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers how the update check tells a newer release.
/// </summary>
public sealed class UpdateCheckTests
{
    /// <summary>
    /// Asserts that a release build reads its version and a development build none.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped.</param>
    /// <param name="expected">The release version, or <see langword="null"/>.</param>
    [Theory]
    [InlineData("0.1.0+4357977", "0.1.0")]
    [InlineData("0.2.0", "0.2.0")]
    [InlineData("0.0.0-dev+9611cfb", null)]
    [InlineData("", null)]
    public void ReleaseVersionOf_SkipsDevelopmentBuilds(string informationalVersion, string? expected) =>
        Assert.Equal(expected, UpdateCheck.ReleaseVersionOf(informationalVersion)?.ToString());

    /// <summary>
    /// Asserts that the version named to the relay leaves out the commit and keeps a development stamp.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped.</param>
    /// <param name="expected">The version named to the relay.</param>
    [Theory]
    [InlineData("0.6.4+4357977", "0.6.4")]
    [InlineData("0.6.4", "0.6.4")]
    [InlineData("0.0.0-dev+9611cfb", "0.0.0-dev")]
    [InlineData("0.6.0-beta+9611cfb", "0.6.0-beta")]
    [InlineData("", "")]
    public void VersionOf_LeavesOutTheCommit(string informationalVersion, string expected) =>
        Assert.Equal(expected, UpdateCheck.VersionOf(informationalVersion));

    /// <summary>
    /// Asserts that only the development stamp counts as a development build, never a pre-release.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped.</param>
    /// <param name="expected">Whether it is a development build.</param>
    [Theory]
    [InlineData("0.0.0-dev+9611cfb", true)]
    [InlineData("0.0.0-dev", true)]
    [InlineData("0.6.0-beta+9611cfb", false)]
    [InlineData("0.6.0-rc1", false)]
    [InlineData("0.5.3+4357977", false)]
    [InlineData("", false)]
    public void IsDevelopmentVersion_IsOnlyTheDevelopmentStamp(string informationalVersion, bool expected) =>
        Assert.Equal(expected, UpdateCheck.IsDevelopmentVersion(informationalVersion));

    /// <summary>
    /// Asserts that only a newer release is reported, without the tag's <c>v</c>.
    /// </summary>
    /// <param name="installed">The installed version.</param>
    /// <param name="tag">The latest release's tag.</param>
    /// <param name="expected">The reported version, or <see langword="null"/>.</param>
    [Theory]
    [InlineData("0.1.0", "v0.2.0", "0.2.0")]
    [InlineData("0.1.0", "v0.1.10", "0.1.10")]
    [InlineData("0.1.0", "v0.1.0", null)]
    [InlineData("0.2.0", "v0.1.0", null)]
    [InlineData("0.1.0", "nightly", null)]
    public void NewerRelease_ReportsOnlyANewerTag(string installed, string tag, string? expected) =>
        Assert.Equal(expected, UpdateCheck.NewerRelease(Version.Parse(installed), $$"""{"id":1,"tag_name":"{{tag}}","assets":[]}"""));
}
