//----------------------------------------------------------------
//  ReleaseManifest.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace MGQOnline.Updates;

/// <summary>
/// What a release holds: its product, version, commit, design format, files and notes.
/// </summary>
/// <param name="Product">The product's name, like <c>MGQ Online Raid Designer</c>.</param>
/// <param name="Version">The release's version.</param>
/// <param name="Commit">The commit the release was built from.</param>
/// <param name="DesignFormat">The design format the release reads and writes.</param>
/// <param name="Files">The release's files, one per runtime.</param>
/// <param name="Notes">The release notes.</param>
public sealed record ReleaseManifest(
    string Product,
    ReleaseVersion Version,
    string Commit,
    int DesignFormat,
    IReadOnlyList<ManifestFile> Files,
    string Notes)
{
    /// <summary>
    /// The number of hex digits in a SHA-256.
    /// </summary>
    private const int Sha256HexLength = 64;

    /// <summary>
    /// How release JSON is read.
    /// </summary>
    /// <remarks>
    /// A repeated property is refused, so no reader can see another value than the one the signer meant.
    /// </remarks>
    internal static readonly JsonDocumentOptions StrictJson = new() { AllowDuplicateProperties = false };

    /// <summary>
    /// Reads a manifest and refuses one that lacks a field or holds a wrong value.
    /// </summary>
    /// <param name="utf8Json">The manifest's exact bytes.</param>
    /// <returns>The manifest.</returns>
    /// <exception cref="UpdateRefusedException">The bytes are no valid manifest.</exception>
    public static ReleaseManifest Parse(ReadOnlyMemory<byte> utf8Json)
    {
        try
        {
            using var document = JsonDocument.Parse(utf8Json, StrictJson);
            return Read(document.RootElement);
        }
        catch (JsonException ex)
        {
            throw new UpdateRefusedException("The release manifest is no JSON.", ex);
        }
    }

    /// <summary>
    /// Finds the file built for a runtime.
    /// </summary>
    /// <param name="rid">The runtime, like <c>win-x64</c>.</param>
    /// <returns>The file.</returns>
    /// <exception cref="UpdateRefusedException">The release has no file for that runtime.</exception>
    public ManifestFile FileFor(string rid)
    {
        foreach (var file in Files)
        {
            if (string.Equals(file.Rid, rid, StringComparison.Ordinal))
            {
                return file;
            }
        }

        throw new UpdateRefusedException($"The release has no file for {rid}.");
    }

    /// <summary>
    /// Writes the manifest as compact JSON, in the field order of the contract.
    /// </summary>
    /// <returns>The manifest's bytes, which are what the signature covers.</returns>
    public byte[] ToUtf8Json()
    {
        using var stream = new MemoryStream();

        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            writer.WriteString("product", Product);
            writer.WriteString("version", Version.ToString());
            writer.WriteString("commit", Commit);
            writer.WriteNumber("designFormat", DesignFormat);
            writer.WriteStartArray("files");

            foreach (var file in Files)
            {
                writer.WriteStartObject();
                writer.WriteString("rid", file.Rid);
                writer.WriteString("name", file.Name);
                writer.WriteNumber("size", file.Size);
                writer.WriteString("sha256", file.Sha256);
                writer.WriteEndObject();
            }

            writer.WriteEndArray();
            writer.WriteString("notes", Notes);
            writer.WriteEndObject();
        }

        return stream.ToArray();
    }

    /// <summary>
    /// Tells whether a text is a SHA-256 in hex.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>True for exactly 64 hex digits of either case.</returns>
    internal static bool IsSha256Hex(string text)
    {
        if (text.Length != Sha256HexLength)
        {
            return false;
        }

        foreach (var character in text)
        {
            if (!char.IsAsciiHexDigit(character))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Reads the manifest's fields.
    /// </summary>
    /// <param name="root">The manifest's JSON object.</param>
    /// <returns>The manifest.</returns>
    /// <exception cref="UpdateRefusedException">A field is missing or wrong.</exception>
    private static ReleaseManifest Read(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object)
        {
            throw new UpdateRefusedException("The release manifest is no JSON object.");
        }

        var versionText = RequiredString(root, "version");

        if (!ReleaseVersion.TryParse(versionText, out var version) || version.IsDevelopment)
        {
            throw new UpdateRefusedException($"The release manifest names no release version: '{versionText}'.");
        }

        var designFormat = RequiredProperty(root, "designFormat", JsonValueKind.Number);

        if (!designFormat.TryGetInt32(out var format) || format < 1)
        {
            throw new UpdateRefusedException("The release manifest names no design format.");
        }

        return new ReleaseManifest(
            NonEmptyString(root, "product"),
            version,
            NonEmptyString(root, "commit"),
            format,
            ReadFiles(RequiredProperty(root, "files", JsonValueKind.Array)),
            RequiredString(root, "notes"));
    }

    /// <summary>
    /// Reads the manifest's files.
    /// </summary>
    /// <param name="array">The JSON array of files.</param>
    /// <returns>The files, at least one, each runtime once.</returns>
    /// <exception cref="UpdateRefusedException">A file is wrong, or a runtime repeats, or there is none.</exception>
    private static List<ManifestFile> ReadFiles(JsonElement array)
    {
        var files = new List<ManifestFile>();
        var rids = new HashSet<string>(StringComparer.Ordinal);

        foreach (var element in array.EnumerateArray())
        {
            if (element.ValueKind != JsonValueKind.Object)
            {
                throw new UpdateRefusedException("A file of the release manifest is no JSON object.");
            }

            var rid = NonEmptyString(element, "rid");
            var sha256 = RequiredString(element, "sha256");

            if (!RequiredProperty(element, "size", JsonValueKind.Number).TryGetInt64(out var size) || size < 0)
            {
                throw new UpdateRefusedException($"The release file for {rid} has no valid size.");
            }

            if (!IsSha256Hex(sha256))
            {
                throw new UpdateRefusedException($"The release file for {rid} has no valid SHA-256.");
            }

            if (!rids.Add(rid))
            {
                throw new UpdateRefusedException($"The release manifest lists {rid} twice.");
            }

            files.Add(new ManifestFile(rid, NonEmptyString(element, "name"), size, sha256.ToLowerInvariant()));
        }

        if (files.Count == 0)
        {
            throw new UpdateRefusedException("The release manifest lists no files.");
        }

        return files;
    }

    /// <summary>
    /// Reads a property that must exist with a given kind.
    /// </summary>
    /// <param name="parent">The JSON object.</param>
    /// <param name="name">The property's name.</param>
    /// <param name="kind">The kind its value must have.</param>
    /// <returns>The property's value.</returns>
    /// <exception cref="UpdateRefusedException">The property is missing or of another kind.</exception>
    private static JsonElement RequiredProperty(JsonElement parent, string name, JsonValueKind kind)
    {
        if (!parent.TryGetProperty(name, out var value) || value.ValueKind != kind)
        {
            throw new UpdateRefusedException($"The release manifest has no valid '{name}'.");
        }

        return value;
    }

    /// <summary>
    /// Reads a string property that must exist.
    /// </summary>
    /// <param name="parent">The JSON object.</param>
    /// <param name="name">The property's name.</param>
    /// <returns>The string, possibly empty.</returns>
    /// <exception cref="UpdateRefusedException">The property is missing or no string.</exception>
    private static string RequiredString(JsonElement parent, string name) =>
        RequiredProperty(parent, name, JsonValueKind.String).GetString() ?? string.Empty;

    /// <summary>
    /// Reads a string property that must exist and hold text.
    /// </summary>
    /// <param name="parent">The JSON object.</param>
    /// <param name="name">The property's name.</param>
    /// <returns>The non-empty string.</returns>
    /// <exception cref="UpdateRefusedException">The property is missing, no string or empty.</exception>
    private static string NonEmptyString(JsonElement parent, string name)
    {
        var text = RequiredString(parent, name);
        return text.Length > 0 ? text : throw new UpdateRefusedException($"The release manifest has an empty '{name}'.");
    }
}
