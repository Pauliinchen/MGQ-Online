//----------------------------------------------------------------
//  UpdateCheckTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Covered the release the relay names, a step back too, and GitHub without its answer
//      Paulinchen  2026-10-12: Covered the version named to the relay
//      Paulinchen  2026-10-10: Covered telling a development build by its stamp
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Net.Http;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers how the update check picks the release to offer.
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

    /// <summary>
    /// Asserts that the relay's answer names a release only as dotted numbers.
    /// </summary>
    /// <param name="json">The relay's answer.</param>
    /// <param name="expected">The release, or <see langword="null"/>.</param>
    [Theory]
    [InlineData("""{"current":"0.6.8","min":"0.6.0","repo":"Pauliinchen/MGQ-Online"}""", "0.6.8")]
    [InlineData("""{"current":null,"min":"0.6.0"}""", null)]
    [InlineData("""{"current":"v0.6.8"}""", null)]
    [InlineData("""{"min":"0.6.0"}""", null)]
    public void CurrentRelease_ReadsOnlyAReleaseVersion(string json, string? expected) =>
        Assert.Equal(expected, UpdateCheck.CurrentRelease(json));

    /// <summary>
    /// Asserts that the relay's release is offered, an older one as a step back, without asking GitHub.
    /// </summary>
    /// <param name="installed">The installed version.</param>
    /// <param name="current">The release the relay names.</param>
    /// <param name="rollback">Whether the offer is a step back.</param>
    [Theory]
    [InlineData("0.6.7.7", "0.6.8", false)]
    [InlineData("0.6.8", "0.6.7.7", true)]
    public void Choose_OffersTheRelaysRelease(string installed, string current, bool rollback)
    {
        var offer = UpdateCheck.Choose(Version.Parse(installed), () => current, () => throw new InvalidOperationException("GitHub was asked."));

        Assert.Equal(new ReleaseOffer(current, rollback), offer);
    }

    /// <summary>
    /// Asserts that the relay naming the installed release offers nothing, even while GitHub has a newer one.
    /// </summary>
    [Fact]
    public void Choose_TheRelaysReleaseInstalled_OffersNothing() =>
        Assert.Null(UpdateCheck.Choose(Version.Parse("0.6.8"), () => "0.6.8.0", () => Latest("v0.6.9")));

    /// <summary>
    /// Asserts that GitHub's newer latest release is offered while the relay names none or cannot be reached.
    /// </summary>
    [Fact]
    public void Choose_WithoutTheRelaysRelease_AsksGitHub()
    {
        Assert.Equal(new ReleaseOffer("0.6.9", false), UpdateCheck.Choose(Version.Parse("0.6.8"), () => null, () => Latest("v0.6.9")));
        Assert.Equal(new ReleaseOffer("0.6.9", false), UpdateCheck.Choose(Version.Parse("0.6.8"), () => throw new HttpRequestException("unreachable"), () => Latest("v0.6.9")));
        Assert.Null(UpdateCheck.Choose(Version.Parse("0.6.8"), () => null, () => Latest("v0.6.7.7")));
    }

    /// <summary>
    /// Asserts that the release route lies at the relay's address over HTTP.
    /// </summary>
    [Fact]
    public void ReleaseAddress_IsTheRelaysRoute()
    {
        Assert.Equal("https://relay.mgqonline.org/v1/release", UpdateCheck.ReleaseAddress(new Uri("wss://relay.mgqonline.org")).ToString());
        Assert.Equal("http://127.0.0.1:8080/v1/release", UpdateCheck.ReleaseAddress(new Uri("ws://127.0.0.1:8080")).ToString());
    }

    /// <summary>
    /// Describes a latest release as GitHub does, as far as the check reads it.
    /// </summary>
    /// <param name="tag">The release's tag.</param>
    /// <returns>The description.</returns>
    private static string Latest(string tag) => $$"""{"id":1,"tag_name":"{{tag}}","assets":[]}""";
}
