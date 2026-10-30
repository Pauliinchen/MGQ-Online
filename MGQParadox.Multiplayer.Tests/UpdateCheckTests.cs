//----------------------------------------------------------------
//  UpdateCheckTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Dropped GitHub, which the Mod Framework asks for updates
//                            - Read the release version, the relay version and the development stamp in one theory
//                            - Cut the release tags to one of each kind
//      Paulinchen  2026-10-23: Read the release version through ReleaseVersion
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
    /// Asserts what a build reads from its stamp: a release its version, a development or pre-release
    /// build none; the version named to the relay without the commit; and a development build only by
    /// the development stamp.
    /// </summary>
    /// <param name="informationalVersion">The version the build stamped.</param>
    /// <param name="release">The release version, or <see langword="null"/>.</param>
    /// <param name="named">The version named to the relay.</param>
    /// <param name="development">Whether it is a development build.</param>
    [Theory]
    [InlineData("0.1.0+4357977", "0.1.0", "0.1.0", false)]
    [InlineData("0.2.0", "0.2.0", "0.2.0", false)]
    [InlineData("0.0.0-dev+9611cfb", null, "0.0.0-dev", true)]
    [InlineData("0.6.0-beta+9611cfb", null, "0.6.0-beta", false)]
    [InlineData("", null, "", false)]
    public void Stamp_ReadsTheReleaseTheRelayVersionAndADevelopmentBuild(string informationalVersion, string? release, string named, bool development)
    {
        Assert.Equal(release, ReleaseVersion.OfStamp(informationalVersion)?.ToString());
        Assert.Equal(named, UpdateCheck.VersionOf(informationalVersion));
        Assert.Equal(development, UpdateCheck.IsDevelopmentVersion(informationalVersion));
    }

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
    /// Asserts that the relay's release is the one to play, an older one as a step back.
    /// </summary>
    /// <param name="installed">The installed version.</param>
    /// <param name="current">The release the relay names.</param>
    /// <param name="rollback">Whether the offer is a step back.</param>
    [Theory]
    [InlineData("0.6.7.7", "0.6.8", false)]
    [InlineData("0.6.8", "0.6.7.7", true)]
    public void Choose_OffersTheRelaysRelease(string installed, string current, bool rollback)
    {
        var offer = UpdateCheck.Choose(Version.Parse(installed), () => current);

        Assert.Equal(new ReleaseOffer(current, rollback), offer);
    }

    /// <summary>
    /// Asserts that nothing is to play but this DLL while the relay names it, names none or cannot be
    /// reached.
    /// </summary>
    [Fact]
    public void Choose_WithoutAnotherReleaseFromTheRelay_FindsNone()
    {
        Assert.Null(UpdateCheck.Choose(Version.Parse("0.6.8"), () => "0.6.8.0"));
        Assert.Null(UpdateCheck.Choose(Version.Parse("0.6.8"), () => null));
        Assert.Null(UpdateCheck.Choose(Version.Parse("0.6.8"), () => throw new HttpRequestException("unreachable")));
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
}
