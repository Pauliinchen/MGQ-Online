//----------------------------------------------------------------
//  ReleaseVersionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests reading and ordering release versions.
/// </summary>
public sealed class ReleaseVersionTests
{
    /// <summary>
    /// Tags, build metadata and pre-release labels read as the version they name.
    /// </summary>
    /// <param name="text">The text to read.</param>
    /// <param name="expected">The version it names.</param>
    [Theory]
    [InlineData("1.3.0", "1.3.0")]
    [InlineData("v1.3.0", "1.3.0")]
    [InlineData("1.3.0+abc1234", "1.3.0")]
    [InlineData("0.0.0-dev+abc1234", "0.0.0-dev")]
    [InlineData("10.20.30-beta.2", "10.20.30-beta.2")]
    public void ReadsVersions(string text, string expected)
    {
        Assert.Equal(expected, ReleaseVersion.Parse(text).ToString());
    }

    /// <summary>
    /// Anything that is not a three-part version is refused.
    /// </summary>
    /// <param name="text">The text to read.</param>
    [Theory]
    [InlineData("")]
    [InlineData("1.3")]
    [InlineData("1.3.0.0")]
    [InlineData("1.03.0")]
    [InlineData("-1.3.0")]
    [InlineData("1.3.0-")]
    [InlineData("1.3.0-beta..2")]
    [InlineData("1.3.0-01")]
    [InlineData("1.3.0+")]
    [InlineData("1.3.x")]
    [InlineData(" 1.3.0")]
    [InlineData("99999999999.0.0")]
    public void RefusesNonVersions(string text)
    {
        Assert.False(ReleaseVersion.TryParse(text, out _));
        Assert.Throws<FormatException>(() => ReleaseVersion.Parse(text));
    }

    /// <summary>
    /// Versions order by Semantic Versioning, a pre-release before its release.
    /// </summary>
    /// <param name="older">The older version.</param>
    /// <param name="newer">The newer version.</param>
    [Theory]
    [InlineData("1.2.9", "1.3.0")]
    [InlineData("1.9.0", "1.10.0")]
    [InlineData("1.3.0", "2.0.0")]
    [InlineData("1.3.0-beta", "1.3.0")]
    [InlineData("1.3.0-alpha", "1.3.0-beta")]
    [InlineData("1.3.0-beta.2", "1.3.0-beta.10")]
    [InlineData("1.3.0-beta", "1.3.0-beta.1")]
    [InlineData("1.3.0-1", "1.3.0-alpha")]
    [InlineData("0.0.0-dev", "0.0.1")]
    public void OrdersVersions(string older, string newer)
    {
        var low = ReleaseVersion.Parse(older);
        var high = ReleaseVersion.Parse(newer);

        Assert.True(low < high);
        Assert.True(high > low);
        Assert.True(low.CompareTo(high) < 0);
        Assert.NotEqual(low, high);
    }

    /// <summary>
    /// Build metadata and a tag prefix do not change a version.
    /// </summary>
    [Fact]
    public void IgnoresBuildMetadataInEquality()
    {
        Assert.Equal(ReleaseVersion.Parse("1.3.0"), ReleaseVersion.Parse("v1.3.0+abc1234"));
        Assert.True(ReleaseVersion.Parse("1.3.0") >= ReleaseVersion.Parse("1.3.0+def"));
    }

    /// <summary>
    /// Only 0.0.0-dev is the development version.
    /// </summary>
    [Fact]
    public void TellsTheDevelopmentVersion()
    {
        Assert.True(ReleaseVersion.Parse("0.0.0-dev").IsDevelopment);
        Assert.True(ReleaseVersion.Parse("0.0.0-dev+abc1234").IsDevelopment);
        Assert.False(ReleaseVersion.Parse("0.0.0").IsDevelopment);
        Assert.False(ReleaseVersion.Parse("0.6.0-beta").IsDevelopment);
        Assert.False(default(ReleaseVersion).IsDevelopment);
    }
}
