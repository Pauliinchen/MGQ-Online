//----------------------------------------------------------------
//  TestReleases.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;
using System.Text.Json.Nodes;

namespace MGQOnline.Updates.Tests.Support;

/// <summary>
/// Builds signed releases and reads the contract fixtures for the tests.
/// </summary>
internal static class TestReleases
{
    /// <summary>
    /// The product the designer's manifests name.
    /// </summary>
    public const string Product = "MGQ Online Raid Designer";

    /// <summary>
    /// The runtime of the desktop designer.
    /// </summary>
    public const string Rid = "win-x64";

    /// <summary>
    /// A key pair made once for every test.
    /// </summary>
    public static readonly (string PrivateKeyPem, string PublicKeyPem) Keys = ReleaseSignature.CreateKeyPair();

    /// <summary>
    /// Reads a fixture file next to the test executable.
    /// </summary>
    /// <param name="name">The fixture's file name.</param>
    /// <returns>The fixture's bytes.</returns>
    public static byte[] Fixture(string name) =>
        File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", name));

    /// <summary>
    /// Reads the body of one answer in the contract's <c>release.json</c>.
    /// </summary>
    /// <param name="exchange">The exchange's index in the fixture.</param>
    /// <returns>The answer's JSON bytes.</returns>
    public static byte[] ContractAnswer(int exchange)
    {
        var body = JsonNode.Parse(Fixture("release.json"))!["exchanges"]![exchange]!["response"]!["body"]!;
        return Encoding.UTF8.GetBytes(body.ToJsonString());
    }

    /// <summary>
    /// Builds a manifest with a desktop and a CLI file.
    /// </summary>
    /// <param name="version">The release version.</param>
    /// <param name="exeSha256">The desktop exe's SHA-256.</param>
    /// <param name="exeSize">The desktop exe's length.</param>
    /// <returns>The manifest.</returns>
    public static ReleaseManifest Manifest(string version, string exeSha256, long exeSize = 1234) =>
        new(
            Product,
            ReleaseVersion.Parse(version),
            "abc1234",
            1,
            [
                new ManifestFile(Rid, $"RaidDesigner-{version}-win-x64.exe", exeSize, exeSha256),
                new ManifestFile("linux-x64", $"raid-designer-cli-{version}-linux-x64", 99, new string('e', 64)),
            ],
            "Notes.");

    /// <summary>
    /// Builds the relay's answer for a manifest, signed with <see cref="Keys"/>.
    /// </summary>
    /// <param name="manifest">The manifest.</param>
    /// <param name="minimum">The minimum version the answer names, or null for none.</param>
    /// <returns>The answer's JSON bytes.</returns>
    public static byte[] SignedAnswer(ReleaseManifest manifest, string? minimum = "1.0.0")
    {
        var bytes = manifest.ToUtf8Json();
        return Answer(manifest, bytes, ReleaseSignature.Sign(bytes, Keys.PrivateKeyPem), minimum);
    }

    /// <summary>
    /// Builds the relay's answer from given manifest bytes and signature.
    /// </summary>
    /// <param name="manifest">The manifest the answer names its version and file from.</param>
    /// <param name="manifestBytes">The manifest bytes the answer carries.</param>
    /// <param name="signature">The signature the answer carries; empty leaves it out.</param>
    /// <param name="minimum">The minimum version the answer names, or null for none.</param>
    /// <returns>The answer's JSON bytes.</returns>
    public static byte[] Answer(ReleaseManifest manifest, byte[] manifestBytes, byte[] signature, string? minimum = "1.0.0")
    {
        var file = manifest.FileFor(Rid);
        var json = new StringBuilder("{")
            .Append($"\"version\":\"{manifest.Version}\",")
            .Append(minimum == null ? string.Empty : $"\"minimum\":\"{minimum}\",")
            .Append($"\"notes\":\"{manifest.Notes}\",")
            .Append($"\"manifest\":\"{Convert.ToBase64String(manifestBytes)}\",")
            .Append(signature.Length == 0 ? string.Empty : $"\"signature\":\"{Convert.ToBase64String(signature)}\",")
            .Append($"\"size\":{file.Size},")
            .Append($"\"sha256\":\"{file.Sha256}\"}}");
        return Encoding.UTF8.GetBytes(json.ToString());
    }

    /// <summary>
    /// Builds a verified release.
    /// </summary>
    /// <param name="version">The release version.</param>
    /// <param name="exeSha256">The desktop exe's SHA-256.</param>
    /// <param name="minimum">The minimum version, or null for none.</param>
    /// <returns>The verified release.</returns>
    public static VerifiedRelease Verified(string version, string exeSha256, string? minimum = "1.0.0") =>
        ReleaseAnswer.Parse(SignedAnswer(Manifest(version, exeSha256), minimum))
            .Verify(Keys.PublicKeyPem, Product, Rid);
}
