//----------------------------------------------------------------
//  WorldRequestsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Gave an edit's values no world type, as its form sets none
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Text.Json;
using MGQOnline.Game.Forms;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers what an edit of a world sends along and tells against what world_screen.rbx did
/// (fixtures/requests/edits.json).
/// </summary>
public sealed class WorldRequestsTests
{
    /// <summary>
    /// The difficulties' names, as fixtures/world/rules.json gives them.
    /// </summary>
    private static readonly Dictionary<int, string> DifficultyNames = new() { [-2] = "VERY EASY", [-1] = "EASY", [0] = "NORMAL", [1] = "HARD", [2] = "VERY HARD", [3] = "HELL", [4] = "PARADOX" };

    /// <summary>
    /// The squad rules a Raid World that names none plays with, as fixtures/world/rules.json gives them.
    /// </summary>
    private static readonly WorldSquad DefaultSquad = new(false, 4, 1, 1);

    /// <summary>
    /// Asserts that every edit sends along and tells what the screen sent and told.
    /// </summary>
    [Fact]
    public void EditOf_SendsAndTellsWhatTheScreenDid()
    {
        foreach (JsonElement entry in Fixtures.Read("requests", "edits.json").GetProperty("edits").EnumerateArray())
        {
            JsonElement form = entry.GetProperty("form");
            WorldEdit listed = new(Int(entry, "difficulty"), Squad(entry.GetProperty("squad")), entry.GetProperty("raid_bosses").GetBoolean(), entry.GetProperty("other_mods_off").GetBoolean());
            WorldFormValues values = new(null, Int(form, "difficulty"), Squad(form.GetProperty("squad"))!, form.GetProperty("raid_bosses").GetBoolean(), form.GetProperty("other_mods_off").GetBoolean());
            JsonElement edited = entry.GetProperty("edited");
            string name = entry.GetProperty("name").GetString()!;

            WorldEdit edit = WorldRequests.EditOf(entry.GetProperty("raid").GetBoolean(), listed, DefaultSquad, values);
            bool? sharing = WorldRequests.SharingOf(entry.GetProperty("own").GetBoolean(), entry.GetProperty("settings").GetString()!.StartsWith('!'), form.GetProperty("shared").GetBoolean());

            Assert.True(new WorldEdit(Int(edited, "difficulty"), Squad(edited.GetProperty("squad")), Bool(edited, "raid_bosses"), Bool(edited, "other_mods_off")) == edit, name);
            Assert.True(SharingOfGolden(edited) == sharing, name);
            Assert.True(entry.GetProperty("text").GetString() == WorldRequests.ChangedText(edit, value => DifficultyNames[value], Formation), name);
        }
    }

    /// <summary>
    /// Names a Formation size as the rules do.
    /// </summary>
    /// <param name="size">The size.</param>
    /// <returns>Its name.</returns>
    private static string Formation(int size) => size == 0 ? "Original" : size.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Reads the sharing a golden edit sent: shared settings start with the marker, none left it.
    /// </summary>
    /// <param name="edited">What the edit sent.</param>
    /// <returns>Whether it shares them, <see langword="null"/> when it left them.</returns>
    private static bool? SharingOfGolden(JsonElement edited) =>
        edited.GetProperty("settings").ValueKind == JsonValueKind.Null ? null : edited.GetProperty("settings").GetString()!.Length > 0;

    /// <summary>
    /// Reads a whole number that may be null.
    /// </summary>
    /// <param name="entry">The object.</param>
    /// <param name="name">The field.</param>
    /// <returns>The number.</returns>
    private static int? Int(JsonElement entry, string name) =>
        entry.GetProperty(name).ValueKind == JsonValueKind.Null ? null : entry.GetProperty(name).GetInt32();

    /// <summary>
    /// Reads a flag that may be null.
    /// </summary>
    /// <param name="entry">The object.</param>
    /// <param name="name">The field.</param>
    /// <returns>The flag.</returns>
    private static bool? Bool(JsonElement entry, string name) =>
        entry.GetProperty(name).ValueKind == JsonValueKind.Null ? null : entry.GetProperty(name).GetBoolean();

    /// <summary>
    /// Reads squad rules that may be null.
    /// </summary>
    /// <param name="squad">The rules.</param>
    /// <returns>The rules.</returns>
    private static WorldSquad? Squad(JsonElement squad) =>
        squad.ValueKind == JsonValueKind.Null ? null : new WorldSquad(squad.GetProperty("luka").GetBoolean(), squad.GetProperty("formation").GetInt32(), squad.GetProperty("front").GetInt32(), squad.GetProperty("raid_front").GetInt32());
}
