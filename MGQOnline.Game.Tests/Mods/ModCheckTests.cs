//----------------------------------------------------------------
//  ModCheckTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Tests.Mods;

/// <summary>
/// Covers the required-mods check against the cases world_mods.rbx gave (fixtures/mods/check.json).
/// </summary>
public sealed class ModCheckTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = Fixtures.Read("mods", "check.json");

    /// <summary>
    /// Asserts that each world's rows, summary, log line, installed versions and served mods are the script's.
    /// </summary>
    [Fact]
    public void Differing_ChecksAsTheScriptDid()
    {
        foreach (JsonElement entry in _cases.GetProperty("checks").EnumerateArray())
        {
            ModCheck check = CheckOf(entry);
            string mods = entry.GetProperty("mods").GetString()!;
            string hashes = entry.GetProperty("hashes").GetString()!;
            string shown = $"{mods} with {JsonSerializer.Serialize(entry.GetProperty("files"))}";

            IReadOnlyList<ModCheckRow> rows = check.Differing(mods, hashes);
            Assert.True(Json(entry.GetProperty("rows")) == Json(rows.Select(row => new { name = row.Name, yours = row.Yours, worlds = row.Worlds, key = row.Key, target = row.Target, text = row.Text })), $"the rows of {shown}: {Json(rows)}");
            Assert.True(entry.GetProperty("summary").GetString() == (rows.Count == 0 ? null : ModCheck.Summary("Modded", rows)), $"the summary of {shown}");
            Assert.True(entry.GetProperty("log").GetString() == check.CheckLine("Modded", mods, hashes, rows), $"the log of {shown}: {check.CheckLine("Modded", mods, hashes, rows)}");

            object?[][] versions = [.. Mods(_cases).Where(_ => check.CatalogKnown).Select(mod => new object?[] { mod.Key, check.InstalledVersion(mod) })];
            Assert.True(Json(entry.GetProperty("installed_versions")) == Json(versions), $"the installed versions of {shown}");

            string[] personal = check.CatalogKnown ? [.. _cases.GetProperty("catalog").GetProperty("personal").EnumerateArray().Select(key => key.GetString()!)] : [];
            object[][] served = [.. check.Served(mods, personal).Select(mod => new object[] { mod.Key, mod.Kind, mod.Version, mod.Files.Select(file => new[] { file.Key, file.Value }).ToArray() })];
            Assert.True(Json(entry.GetProperty("served")) == Json(served), $"the served mods of {shown}: {Json(served)}");
        }
    }

    /// <summary>
    /// Asserts that the creator's hashes leave out what the script left out, and fit the relay's limit as it did.
    /// </summary>
    [Fact]
    public void CreatorHashes_LeaveOutAsTheScriptDid()
    {
        foreach (JsonElement entry in _cases.GetProperty("creator").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("hashes").GetString(), CheckOf(entry).CreatorHashes(entry.GetProperty("mods").GetString(), _ => { }));
        }

        foreach (JsonElement entry in _cases.GetProperty("fits").EnumerateArray())
        {
            string[] pairs = [.. entry.GetProperty("pairs").EnumerateArray().Select(pair => pair.GetString()!)];
            Assert.Equal(entry.GetProperty("fitted").GetString(), ModCheck.FitHashes(pairs, entry.GetProperty("most").GetInt32(), _ => { }));
        }
    }

    /// <summary>
    /// Makes the check of a case: the catalog when it is known, the scripts in Patch and the files' hashes.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The check.</returns>
    private ModCheck CheckOf(JsonElement entry)
    {
        JsonElement installed = entry.GetProperty("installed");
        Dictionary<string, string> files = entry.GetProperty("files").EnumerateObject().ToDictionary(file => file.Name, file => file.Value.GetString()!);
        return new ModCheck(
            entry.GetProperty("catalog").GetBoolean() ? Mods(_cases) : null,
            installed.ValueKind == JsonValueKind.Null ? null : [.. installed.EnumerateArray().Select(script => (script[0].GetString()!, script[1].GetString()!))],
            path => files.GetValueOrDefault(path));
    }

    /// <summary>
    /// Reads the catalog of the cases.
    /// </summary>
    /// <param name="cases">The cases.</param>
    /// <returns>Its mods.</returns>
    internal static List<CheckedMod> Mods(JsonElement cases) =>
        [.. cases.GetProperty("catalog").GetProperty("mods").EnumerateArray().Select(mod => new CheckedMod(
            mod.GetProperty("key").GetString()!,
            mod.GetProperty("name").GetString()!,
            mod.GetProperty("kind").GetString()!,
            mod.GetProperty("version").GetString()!,
            Files(mod.GetProperty("files")),
            [.. mod.GetProperty("versions").EnumerateArray().Select(version => new KeyValuePair<string, IReadOnlyList<KeyValuePair<string, string>>>(version[0].GetString()!, Files(version[1])))],
            mod.GetProperty("options_version").GetString()))];

    /// <summary>
    /// Reads files' hashes in their order.
    /// </summary>
    /// <param name="files">The hashes by path.</param>
    /// <returns>The pairs.</returns>
    private static List<KeyValuePair<string, string>> Files(JsonElement files) =>
        [.. files.EnumerateObject().Select(file => new KeyValuePair<string, string>(file.Name, file.Value.GetString()!))];

    /// <summary>
    /// Writes a value as JSON, to compare it with a case's.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its JSON.</returns>
    private static string Json(object value) => JsonSerializer.Serialize(value is JsonElement element ? JsonSerializer.Deserialize<object>(element.GetRawText()) : value);
}
