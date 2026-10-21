//----------------------------------------------------------------
//  ReleaseManifestTests.cs
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
/// Tests reading and writing release manifests.
/// </summary>
public sealed class ReleaseManifestTests
{
    /// <summary>
    /// The contract's manifest reads with every field.
    /// </summary>
    [Fact]
    public void ReadsTheContractManifest()
    {
        var manifest = ReleaseManifest.Parse(TestReleases.Fixture("manifest.json"));

        Assert.Equal("MGQ Online Raid Designer", manifest.Product);
        Assert.Equal(ReleaseVersion.Parse("1.3.0"), manifest.Version);
        Assert.Equal("abc1234", manifest.Commit);
        Assert.Equal(1, manifest.DesignFormat);
        Assert.Equal("Scheduled casts and mark reactions.", manifest.Notes);
        Assert.Equal(2, manifest.Files.Count);

        var exe = manifest.FileFor("win-x64");
        Assert.Equal("RaidDesigner-1.3.0-win-x64.exe", exe.Name);
        Assert.Equal(71234567, exe.Size);
        Assert.Equal("a3f1c2d4e5b60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00", exe.Sha256);
        Assert.Equal(41234567, manifest.FileFor("linux-x64").Size);
    }

    /// <summary>
    /// The manifest inside the contract's release answer is the contract's manifest.
    /// </summary>
    [Fact]
    public void ReadsTheManifestTheContractAnswerCarries()
    {
        var answer = ReleaseAnswer.Parse(TestReleases.ContractAnswer(0));

        Assert.Equal(
            JsonNode.Parse(TestReleases.Fixture("manifest.json"))!.ToJsonString(),
            JsonNode.Parse(answer.Manifest)!.ToJsonString());
    }

    /// <summary>
    /// A written manifest reads back the same, with the contract's field order.
    /// </summary>
    [Fact]
    public void WritesAndReadsBack()
    {
        var manifest = TestReleases.Manifest("1.4.0", new string('a', 64));
        var bytes = manifest.ToUtf8Json();
        var read = ReleaseManifest.Parse(bytes);

        Assert.Equal(manifest.Version, read.Version);
        Assert.Equal(manifest.Files, read.Files);
        Assert.StartsWith("{\"product\":", Encoding.UTF8.GetString(bytes));
        Assert.Equal(bytes, read.ToUtf8Json());
    }

    /// <summary>
    /// The contract's SHA-256 spelt in capitals reads as lowercase.
    /// </summary>
    [Fact]
    public void LowersShaDigits()
    {
        var json = Encoding.UTF8.GetString(TestReleases.Fixture("manifest.json"))
            .Replace("a3f1c2d4e5b60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00", "A3F1C2D4E5B60718293A4B5C6D7E8F90112233445566778899AABBCCDDEEFF00");

        Assert.Equal(
            "a3f1c2d4e5b60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00",
            ReleaseManifest.Parse(Encoding.UTF8.GetBytes(json)).FileFor("win-x64").Sha256);
    }

    /// <summary>
    /// A manifest with a missing or wrong field is refused.
    /// </summary>
    /// <param name="change">What the test does to the contract's manifest, as a short code.</param>
    [Theory]
    [InlineData("no-product")]
    [InlineData("empty-product")]
    [InlineData("no-version")]
    [InlineData("bad-version")]
    [InlineData("dev-version")]
    [InlineData("no-commit")]
    [InlineData("zero-format")]
    [InlineData("text-format")]
    [InlineData("no-files")]
    [InlineData("empty-files")]
    [InlineData("negative-size")]
    [InlineData("short-sha")]
    [InlineData("hexless-sha")]
    [InlineData("twice-rid")]
    [InlineData("no-name")]
    [InlineData("no-notes")]
    public void RefusesBadManifests(string change)
    {
        var root = JsonNode.Parse(TestReleases.Fixture("manifest.json"))!.AsObject();
        var files = root["files"]!.AsArray();
        var exe = files[0]!.AsObject();

        switch (change)
        {
            case "no-product": root.Remove("product"); break;
            case "empty-product": root["product"] = ""; break;
            case "no-version": root.Remove("version"); break;
            case "bad-version": root["version"] = "1.3"; break;
            case "dev-version": root["version"] = "0.0.0-dev"; break;
            case "no-commit": root.Remove("commit"); break;
            case "zero-format": root["designFormat"] = 0; break;
            case "text-format": root["designFormat"] = "1"; break;
            case "no-files": root.Remove("files"); break;
            case "empty-files": files.Clear(); break;
            case "negative-size": exe["size"] = -1; break;
            case "short-sha": exe["sha256"] = "abc"; break;
            case "hexless-sha": exe["sha256"] = new string('g', 64); break;
            case "twice-rid": files[1]!["rid"] = "win-x64"; break;
            case "no-name": exe.Remove("name"); break;
            case "no-notes": root.Remove("notes"); break;
        }

        Assert.Throws<UpdateRefusedException>(() => ReleaseManifest.Parse(Encoding.UTF8.GetBytes(root.ToJsonString())));
    }

    /// <summary>
    /// Text that is no JSON, a repeated property or trailing text is refused.
    /// </summary>
    /// <param name="json">The text.</param>
    [Theory]
    [InlineData("")]
    [InlineData("[]")]
    [InlineData("{\"product\":")]
    [InlineData("{\"product\":\"A\",\"product\":\"B\"}")]
    [InlineData("{} {}")]
    public void RefusesNonManifests(string json)
    {
        Assert.Throws<UpdateRefusedException>(() => ReleaseManifest.Parse(Encoding.UTF8.GetBytes(json)));
    }

    /// <summary>
    /// A runtime the release has no file for is refused.
    /// </summary>
    [Fact]
    public void RefusesAMissingRuntime()
    {
        var manifest = ReleaseManifest.Parse(TestReleases.Fixture("manifest.json"));

        Assert.Throws<UpdateRefusedException>(() => manifest.FileFor("osx-arm64"));
    }
}
