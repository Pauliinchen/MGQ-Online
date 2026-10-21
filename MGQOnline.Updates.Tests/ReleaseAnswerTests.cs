//----------------------------------------------------------------
//  ReleaseAnswerTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text;
using System.Text.Json.Nodes;
using MGQOnline.Updates.Tests.Support;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests reading and verifying the relay's release answer.
/// </summary>
public sealed class ReleaseAnswerTests
{
    /// <summary>
    /// The SHA-256 of the desktop exe in the test releases.
    /// </summary>
    private static readonly string ExeSha = new('a', 64);

    /// <summary>
    /// The contract's answer reads; its placeholder signature is refused.
    /// </summary>
    /// <param name="exchange">The exchange's index in the fixture.</param>
    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    public void RefusesTheContractsPlaceholderSignature(int exchange)
    {
        var answer = ReleaseAnswer.Parse(TestReleases.ContractAnswer(exchange));

        Assert.Equal("1.3.0", answer.Version);
        Assert.Equal(ReleaseVersion.Parse("1.2.0"), answer.Minimum);
        Assert.Equal(71234567, answer.Size);
        Assert.NotEmpty(answer.Signature);
        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, TestReleases.Product, TestReleases.Rid));
    }

    /// <summary>
    /// A signed answer verifies and carries the manifest's version, file and notes.
    /// </summary>
    [Fact]
    public void VerifiesASignedAnswer()
    {
        var release = TestReleases.Verified("1.4.0", ExeSha, minimum: "1.2.0");

        Assert.Equal(ReleaseVersion.Parse("1.4.0"), release.Version);
        Assert.Equal(ExeSha, release.File.Sha256);
        Assert.Equal("RaidDesigner-1.4.0-win-x64.exe", release.File.Name);
        Assert.Equal("Notes.", release.Notes);
        Assert.Equal(ReleaseVersion.Parse("1.2.0"), release.Minimum);
    }

    /// <summary>
    /// An answer without a minimum verifies with none.
    /// </summary>
    [Fact]
    public void ReadsAMissingMinimum()
    {
        Assert.Null(TestReleases.Verified("1.4.0", ExeSha, minimum: null).Minimum);
    }

    /// <summary>
    /// An answer without a signature is refused.
    /// </summary>
    [Fact]
    public void RefusesAnUnsignedAnswer()
    {
        var manifest = TestReleases.Manifest("1.4.0", ExeSha);
        var answer = ReleaseAnswer.Parse(TestReleases.Answer(manifest, manifest.ToUtf8Json(), []));

        Assert.Empty(answer.Signature);
        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, TestReleases.Product, TestReleases.Rid));
    }

    /// <summary>
    /// An answer whose manifest was swapped for another one after signing is refused.
    /// </summary>
    [Fact]
    public void RefusesASwappedManifest()
    {
        var signed = TestReleases.Manifest("1.4.0", ExeSha);
        var swapped = TestReleases.Manifest("1.4.0", new string('b', 64));
        var signature = ReleaseSignature.Sign(signed.ToUtf8Json(), TestReleases.Keys.PrivateKeyPem);
        var answer = ReleaseAnswer.Parse(TestReleases.Answer(swapped, swapped.ToUtf8Json(), signature));

        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, TestReleases.Product, TestReleases.Rid));
    }

    /// <summary>
    /// An answer that names another version, size or SHA-256 than its signed manifest is refused.
    /// </summary>
    /// <param name="field">The answer's field the test changes.</param>
    /// <param name="value">The changed value as JSON.</param>
    [Theory]
    [InlineData("version", "\"1.5.0\"")]
    [InlineData("size", "1235")]
    [InlineData("sha256", "\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"")]
    public void RefusesAnAnswerThatDisagreesWithItsManifest(string field, string value)
    {
        var json = Encoding.UTF8.GetString(TestReleases.SignedAnswer(TestReleases.Manifest("1.4.0", ExeSha)));
        var changed = JsonNode.Parse(json)!.AsObject();
        changed[field] = JsonNode.Parse(value);
        var answer = ReleaseAnswer.Parse(Encoding.UTF8.GetBytes(changed.ToJsonString()));

        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, TestReleases.Product, TestReleases.Rid));
    }

    /// <summary>
    /// A signed manifest of another product or without the program's runtime is refused.
    /// </summary>
    [Fact]
    public void RefusesAnotherProductOrRuntime()
    {
        var answer = ReleaseAnswer.Parse(TestReleases.SignedAnswer(TestReleases.Manifest("1.4.0", ExeSha)));

        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, "MGQ Online", TestReleases.Rid));
        Assert.Throws<UpdateRefusedException>(
            () => answer.Verify(TestReleases.Keys.PublicKeyPem, TestReleases.Product, "osx-arm64"));
    }

    /// <summary>
    /// A body that is no answer is refused.
    /// </summary>
    /// <param name="json">The body.</param>
    [Theory]
    [InlineData("")]
    [InlineData("[]")]
    [InlineData("{\"manifest\":\"not base64!\"}")]
    [InlineData("{\"minimum\":\"soon\"}")]
    public void RefusesNonAnswers(string json)
    {
        Assert.Throws<UpdateRefusedException>(() => ReleaseAnswer.Parse(Encoding.UTF8.GetBytes(json)));
    }
}
