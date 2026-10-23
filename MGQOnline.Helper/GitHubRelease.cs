//----------------------------------------------------------------
//  GitHubRelease.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace MGQOnline.Helper;

/// <summary>
/// A file attached to a release.
/// </summary>
/// <param name="Name">The file's name, like <c>MGQ-Online-0.6.8.zip</c>.</param>
/// <param name="Url">Where it is downloaded from.</param>
internal sealed record ReleaseAsset(string Name, string Url);

/// <summary>
/// A release of the mod, as GitHub's API describes it.
/// </summary>
/// <param name="Tag">The release's tag, like <c>v0.6.8</c>.</param>
/// <param name="Notes">The release's notes as written on GitHub; empty for none.</param>
/// <param name="Page">The release's page on GitHub.</param>
/// <param name="Assets">The files attached to it.</param>
internal sealed record GitHubRelease(string Tag, string Notes, string Page, IReadOnlyList<ReleaseAsset> Assets)
{
    /// <summary>
    /// Reads GitHub's description of a release.
    /// </summary>
    /// <param name="json">GitHub's answer to <c>releases/latest</c> or <c>releases/tags/&lt;tag&gt;</c>.</param>
    /// <returns>The release.</returns>
    /// <exception cref="InvalidDataException">The answer names no tag.</exception>
    /// <exception cref="JsonException">The answer is no JSON.</exception>
    public static GitHubRelease Parse(string json)
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        var tag = TextOf(root, "tag_name");

        if (tag.Length == 0)
        {
            throw new InvalidDataException("GitHub named no release.");
        }

        var assets = root.ValueKind == JsonValueKind.Object && root.TryGetProperty("assets", out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Select(asset => new ReleaseAsset(TextOf(asset, "name"), TextOf(asset, "browser_download_url"))).ToList()
            : [];

        return new GitHubRelease(tag, TextOf(root, "body"), TextOf(root, "html_url"), assets);
    }

    /// <summary>
    /// Reads a text property of an object.
    /// </summary>
    /// <param name="element">The object.</param>
    /// <param name="name">The property's name.</param>
    /// <returns>Its text, empty when it is missing or no text.</returns>
    private static string TextOf(JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? string.Empty
            : string.Empty;
}
