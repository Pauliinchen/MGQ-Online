//----------------------------------------------------------------
//  SharedSettingsTests.cs
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
/// Covers a world's shared mod settings and their notices against the cases world_mods.rbx gave
/// (fixtures/mods/settings.json).
/// </summary>
public sealed class SharedSettingsTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = Fixtures.Read("mods", "settings.json");

    /// <summary>
    /// Asserts that settings split, count as shared, fit, build, take the marker and merge as the script did.
    /// </summary>
    [Fact]
    public void Texts_AreTheScripts()
    {
        foreach (JsonElement entry in _cases.GetProperty("pairs").EnumerateArray())
        {
            Assert.Equal(Pairs(entry.GetProperty("pairs")), SharedSettings.Pairs(entry.GetProperty("text").GetString()));
        }

        foreach (JsonElement entry in _cases.GetProperty("shared").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("shared").GetBoolean(), SharedSettings.IsShared(entry.GetProperty("text").GetString()));
        }

        foreach (JsonElement entry in _cases.GetProperty("fits").EnumerateArray())
        {
            var (text, leftOut) = SharedSettings.Fit(Pairs(entry.GetProperty("pairs")), entry.GetProperty("most").GetInt32());
            Assert.Equal(entry.GetProperty("text").GetString(), text);
            Assert.Equal(Strings(entry.GetProperty("left_out")), leftOut);
        }

        foreach (JsonElement entry in _cases.GetProperty("built").EnumerateArray())
        {
            var (text, leftOut) = SharedSettings.Build(Pairs(entry.GetProperty("mine")), Strings(entry.GetProperty("known")), entry.GetProperty("base").GetString());
            Assert.Equal(entry.GetProperty("text").GetString(), text);
            Assert.Equal(Strings(entry.GetProperty("left_out")), leftOut);
        }

        foreach (JsonElement entry in _cases.GetProperty("marked").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("marked").GetString(), SharedSettings.WithMarker(entry.GetProperty("text").GetString()));
        }

        foreach (JsonElement entry in _cases.GetProperty("merged").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("merged").GetString(), SharedSettings.Merged(Text(entry, "base"), Text(entry, "mine"), Text(entry, "theirs"), Text(entry, "reason")));
        }

        foreach (JsonElement entry in _cases.GetProperty("names").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("text").GetString(), SharedSettings.ListText(Strings(entry.GetProperty("names")), entry.GetProperty("named").GetInt32()));
        }

        foreach (JsonElement entry in _cases.GetProperty("notices").EnumerateArray())
        {
            Assert.Equal(Strings(entry.GetProperty("lines")), SharedSettings.NoticeLines(Text(entry, "text"), 3, 46));
        }
    }

    /// <summary>
    /// Asserts that the notices name options, mods and changes as the script did.
    /// </summary>
    [Fact]
    public void Notices_AreTheScripts()
    {
        SettingNotices notices = new([.. _cases.GetProperty("options").EnumerateArray().Select(group => new SettingGroup(
            group[0].GetString()!,
            [.. group[1].EnumerateArray().Select(option => new SettingOption(option[0].GetString()!, option[1].GetString()!, [.. option[2].EnumerateArray().Select(name => new KeyValuePair<string, string>(name[0].GetString()!, name[1].GetString()!))]))]))]);

        foreach (JsonElement entry in _cases.GetProperty("changes").EnumerateArray())
        {
            Assert.True(entry.GetProperty("changes").GetString() == notices.Changes(Text(entry, "before"), Text(entry, "after")), $"the changes from {Text(entry, "before")} to {Text(entry, "after")}: {notices.Changes(Text(entry, "before"), Text(entry, "after"))}");
        }

        foreach (JsonElement entry in _cases.GetProperty("relay").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("text").GetString(), notices.RelayChange(Text(entry, "before"), Text(entry, "after")));
        }

        foreach (JsonElement entry in _cases.GetProperty("lists").EnumerateArray())
        {
            List<string> keys = Strings(entry.GetProperty("keys"));
            List<string> known = notices.KnownKeys(keys);
            Assert.Equal(Strings(entry.GetProperty("known")), known);
            Assert.Equal(Text(entry, "mods"), notices.ModsText(keys));
            Assert.Equal(entry.GetProperty("options").GetString(), keys.Count == 0 ? null : notices.OptionsText(known));
            Assert.Equal(Text(entry, "stay"), notices.Stay(known, "Creator"));
            Assert.Equal(Text(entry, "creator_on"), notices.CreatorOn(known));
        }

        foreach (JsonElement entry in _cases.GetProperty("details").EnumerateArray())
        {
            Assert.Equal(Text(entry, "text"), notices.Details(Text(entry, "settings"), Text(entry, "creator_id") == "me" ? "you" : "Creator"));
        }
    }

    /// <summary>
    /// Reads a text of a case.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="name">The text's name.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement entry, string name) => entry.GetProperty(name).GetString()!;

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Its texts.</returns>
    private static List<string> Strings(JsonElement list) => [.. list.EnumerateArray().Select(item => item.GetString()!)];

    /// <summary>
    /// Reads [key, pair] pairs.
    /// </summary>
    /// <param name="list">The pairs.</param>
    /// <returns>The pairs.</returns>
    private static List<(string Key, string Pair)> Pairs(JsonElement list) => [.. list.EnumerateArray().Select(pair => (pair[0].GetString()!, pair[1].GetString()!))];
}
