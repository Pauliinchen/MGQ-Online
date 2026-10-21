//----------------------------------------------------------------
//  UpdateOfferTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Updates.Tests.Support;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests which releases the running program is offered.
/// </summary>
public sealed class UpdateOfferTests
{
    /// <summary>
    /// The SHA-256 of the released exe.
    /// </summary>
    private static readonly string ReleasedSha = new('a', 64);

    /// <summary>
    /// The SHA-256 of another build of the same version.
    /// </summary>
    private static readonly string OtherSha = new('b', 64);

    /// <summary>
    /// A newer version is offered.
    /// </summary>
    [Fact]
    public void OffersANewerVersion()
    {
        var offer = UpdateOffer.Decide(ReleaseVersion.Parse("1.3.0"), ReleasedSha, TestReleases.Verified("1.4.0", ReleasedSha));

        Assert.Equal(UpdateReason.Newer, offer.Reason);
        Assert.True(offer.Offered);
        Assert.False(offer.Required);
    }

    /// <summary>
    /// The same version with another SHA-256 than the running exe is offered.
    /// </summary>
    [Fact]
    public void OffersTheSameVersionWithAnotherSha()
    {
        var offer = UpdateOffer.Decide(ReleaseVersion.Parse("1.4.0"), OtherSha, TestReleases.Verified("1.4.0", ReleasedSha));

        Assert.Equal(UpdateReason.Rebuilt, offer.Reason);
    }

    /// <summary>
    /// The same version compares its SHA-256 without regard to case.
    /// </summary>
    [Fact]
    public void IgnoresTheCaseOfTheSha()
    {
        var offer = UpdateOffer.Decide(ReleaseVersion.Parse("1.4.0"), ReleasedSha.ToUpperInvariant(), TestReleases.Verified("1.4.0", ReleasedSha));

        Assert.False(offer.Offered);
    }

    /// <summary>
    /// The same build, an older version or an unreadable exe with the same version is not offered.
    /// </summary>
    /// <param name="running">The running version.</param>
    /// <param name="sameSha">Whether the running exe has the released SHA-256.</param>
    /// <param name="readable">Whether the running exe could be read.</param>
    [Theory]
    [InlineData("1.4.0", true, true)]
    [InlineData("1.4.0", false, false)]
    [InlineData("1.5.0", false, true)]
    [InlineData("2.0.0", true, true)]
    public void OffersNothingElse(string running, bool sameSha, bool readable)
    {
        var sha = readable ? (sameSha ? ReleasedSha : OtherSha) : null;

        Assert.Same(UpdateOffer.None, UpdateOffer.Decide(ReleaseVersion.Parse(running), sha, TestReleases.Verified("1.4.0", ReleasedSha)));
    }

    /// <summary>
    /// A development build is never offered a release, whatever its SHA-256.
    /// </summary>
    [Fact]
    public void NeverOffersToADevelopmentBuild()
    {
        var offer = UpdateOffer.Decide(ReleaseVersion.Development, OtherSha, TestReleases.Verified("1.4.0", ReleasedSha, minimum: "1.4.0"));

        Assert.Same(UpdateOffer.None, offer);
    }

    /// <summary>
    /// A version below the relay's minimum must take the offer; one at the minimum need not.
    /// </summary>
    /// <param name="running">The running version.</param>
    /// <param name="required">Whether the offer is required.</param>
    [Theory]
    [InlineData("1.1.9", true)]
    [InlineData("1.2.0-beta", true)]
    [InlineData("1.2.0", false)]
    [InlineData("1.3.0", false)]
    public void RequiresTheUpdateBelowTheMinimum(string running, bool required)
    {
        var offer = UpdateOffer.Decide(ReleaseVersion.Parse(running), ReleasedSha, TestReleases.Verified("1.4.0", ReleasedSha, minimum: "1.2.0"));

        Assert.Equal(UpdateReason.Newer, offer.Reason);
        Assert.Equal(required, offer.Required);
    }
}
