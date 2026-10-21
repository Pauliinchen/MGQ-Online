//----------------------------------------------------------------
//  ReleaseAnswer.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Text.Json;

namespace MGQOnline.Updates;

/// <summary>
/// The relay's answer to <c>GET /v1/designs/release</c>, before anything in it is trusted.
/// </summary>
/// <param name="Version">The release version the relay names.</param>
/// <param name="Minimum">The lowest version the relay still serves, or null when it names none.</param>
/// <param name="Manifest">The manifest's exact bytes.</param>
/// <param name="Signature">The manifest's DER signature; empty when the relay sent none.</param>
/// <param name="Size">The desktop exe's length the relay names.</param>
/// <param name="Sha256">The desktop exe's SHA-256 the relay names.</param>
public sealed record ReleaseAnswer(
    string Version,
    ReleaseVersion? Minimum,
    byte[] Manifest,
    byte[] Signature,
    long Size,
    string Sha256)
{
    /// <summary>
    /// Reads the relay's answer.
    /// </summary>
    /// <param name="utf8Json">The answer's body.</param>
    /// <returns>The answer, not yet verified.</returns>
    /// <exception cref="UpdateRefusedException">The body is no release answer.</exception>
    public static ReleaseAnswer Parse(ReadOnlyMemory<byte> utf8Json)
    {
        try
        {
            using var document = JsonDocument.Parse(utf8Json, ReleaseManifest.StrictJson);
            var root = document.RootElement;

            if (root.ValueKind != JsonValueKind.Object)
            {
                throw new UpdateRefusedException("The release answer is no JSON object.");
            }

            return new ReleaseAnswer(
                StringOf(root, "version"),
                MinimumOf(root),
                Base64Of(root, "manifest"),
                Base64Of(root, "signature"),
                root.TryGetProperty("size", out var size) && size.TryGetInt64(out var length) ? length : -1,
                StringOf(root, "sha256"));
        }
        catch (Exception ex) when (ex is JsonException or FormatException or InvalidOperationException)
        {
            throw new UpdateRefusedException("The release answer is unreadable.", ex);
        }
    }

    /// <summary>
    /// Checks the manifest's signature and that the answer agrees with the signed manifest.
    /// </summary>
    /// <param name="publicKeyPem">The release key built into the program.</param>
    /// <param name="product">The product the manifest must name.</param>
    /// <param name="rid">The runtime whose file is the update, like <c>win-x64</c>.</param>
    /// <returns>The verified release.</returns>
    /// <exception cref="UpdateRefusedException">The manifest is unsigned, wrongly signed or disagrees with the answer.</exception>
    public VerifiedRelease Verify(string publicKeyPem, string product, string rid)
    {
        ReleaseSignature.Verify(Manifest, Signature, publicKeyPem);
        var manifest = ReleaseManifest.Parse(Manifest);

        if (!string.Equals(manifest.Product, product, StringComparison.Ordinal))
        {
            throw new UpdateRefusedException($"The release is for {manifest.Product}, not {product}.");
        }

        if (!ReleaseVersion.TryParse(Version, out var version) || version != manifest.Version)
        {
            throw new UpdateRefusedException($"The relay names version {Version}, the manifest {manifest.Version}.");
        }

        var file = manifest.FileFor(rid);

        if (Size != file.Size || !string.Equals(Sha256, file.Sha256, StringComparison.OrdinalIgnoreCase))
        {
            throw new UpdateRefusedException("The relay names another file than the manifest.");
        }

        return new VerifiedRelease(manifest, file, Minimum);
    }

    /// <summary>
    /// Reads a string property, empty when it is missing.
    /// </summary>
    /// <param name="root">The answer's JSON object.</param>
    /// <param name="name">The property's name.</param>
    /// <returns>The string, or empty.</returns>
    private static string StringOf(JsonElement root, string name) =>
        root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? string.Empty
            : string.Empty;

    /// <summary>
    /// Reads a base64 property, empty when it is missing.
    /// </summary>
    /// <param name="root">The answer's JSON object.</param>
    /// <param name="name">The property's name.</param>
    /// <returns>The decoded bytes, or none.</returns>
    /// <exception cref="FormatException">The property holds no base64.</exception>
    private static byte[] Base64Of(JsonElement root, string name)
    {
        var text = StringOf(root, name);
        return text.Length == 0 ? [] : Convert.FromBase64String(text);
    }

    /// <summary>
    /// Reads the minimum version.
    /// </summary>
    /// <param name="root">The answer's JSON object.</param>
    /// <returns>The minimum, or null when the relay names none.</returns>
    /// <exception cref="UpdateRefusedException">The minimum is no version.</exception>
    private static ReleaseVersion? MinimumOf(JsonElement root)
    {
        var text = StringOf(root, "minimum");

        if (text.Length == 0)
        {
            return null;
        }

        return ReleaseVersion.TryParse(text, out var minimum)
            ? minimum
            : throw new UpdateRefusedException($"The release answer names no minimum version: '{text}'.");
    }
}
