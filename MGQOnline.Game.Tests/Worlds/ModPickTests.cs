//----------------------------------------------------------------
//  ModPickTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the mod picker against the steps world.rbx took (fixtures/worlds/modpick.json).
/// </summary>
public sealed partial class ModPickTests
{
    /// <summary>
    /// Asserts that every step answers and leaves the picker as the scripts' picker did.
    /// </summary>
    [Fact]
    public void Steps_GoAsTheScriptsWent()
    {
        foreach (JsonElement entry in Fixtures.Read("worlds", "modpick.json").GetProperty("cases").EnumerateArray())
        {
            ModPick pick = new(entry.GetProperty("text").GetString(), entry.GetProperty("installed").EnumerateArray().Select(name => name.GetString()!), ModKey.Of);
            Assert.True(Same(entry.GetProperty("start"), View(pick)), "the picker at the start");

            foreach (JsonElement step in entry.GetProperty("steps").EnumerateArray())
            {
                JsonElement[] arguments = [.. step.GetProperty("step").EnumerateArray()];
                object? answer = arguments[0].GetString() switch
                {
                    "toggle" => pick.Toggle(arguments[1].GetInt32()),
                    "mark" => pick.Mark(arguments[1].GetInt32(), StateOf(arguments[2].GetString()!)),
                    "set" => pick.Set(arguments[1].GetInt32(), StateOf(arguments[2].GetString()!)),
                    "remove" => pick.Remove(arguments[1].GetInt32()),
                    "add" => pick.Add(Expand(arguments[1].GetString()!)),
                    "list_all" => pick.ListAll(),
                    "unlist_all" => Unlisted(pick),
                    "all_listed" => pick.AllListed,
                    _ => throw new InvalidOperationException(arguments[0].GetString()),
                };

                string shown = step.GetProperty("step").GetRawText();
                Assert.True(Same(step.GetProperty("answer"), JsonSerializer.SerializeToElement(answer)), $"the answer of {shown}");
                Assert.True(Same(step.GetProperty("pick"), View(pick)), $"the picker after {shown}");
            }
        }
    }

    /// <summary>
    /// Unlists every installed mod, which answers nothing.
    /// </summary>
    /// <param name="pick">The picker.</param>
    /// <returns><see langword="null"/>.</returns>
    private static object? Unlisted(ModPick pick)
    {
        pick.UnlistAll();
        return null;
    }

    /// <summary>
    /// Writes the picker as the recorder wrote it.
    /// </summary>
    /// <param name="pick">The picker.</param>
    /// <returns>Its view.</returns>
    private static JsonElement View(ModPick pick)
    {
        string text = pick.Text();
        int size = ModPick.CharsOf(text);
        return JsonSerializer.SerializeToElement(new
        {
            entries = pick.Entries.Select(entry => new object[] { Shortened(entry.Name), entry.State.ToString().ToLowerInvariant(), entry.Installed }),
            text_size = size,
            text = size > 200 ? null : text,
            all_listed = pick.AllListed,
        });
    }

    /// <summary>
    /// Compares two JSON values by what they hold.
    /// </summary>
    /// <param name="expected">The one recorded.</param>
    /// <param name="actual">The one made.</param>
    /// <returns>Whether they hold the same.</returns>
    private static bool Same(JsonElement expected, JsonElement actual) => expected.ValueKind switch
    {
        JsonValueKind.Array => actual.ValueKind == JsonValueKind.Array && expected.GetArrayLength() == actual.GetArrayLength()
            && expected.EnumerateArray().Zip(actual.EnumerateArray()).All(pair => Same(pair.First, pair.Second)),
        JsonValueKind.Object => actual.ValueKind == JsonValueKind.Object && expected.EnumerateObject().Count() == actual.EnumerateObject().Count()
            && expected.EnumerateObject().All(property => actual.TryGetProperty(property.Name, out JsonElement other) && Same(property.Value, other)),
        JsonValueKind.String => actual.ValueKind == JsonValueKind.String && expected.GetString() == actual.GetString(),
        JsonValueKind.Number => actual.ValueKind == JsonValueKind.Number && expected.GetInt64() == actual.GetInt64(),
        _ => expected.ValueKind == actual.ValueKind,
    };

    /// <summary>
    /// Shortens a long name as the recorder did.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Its first three characters, a star and its length, for a name over 40 characters.</returns>
    private static string Shortened(string name)
    {
        int length = ModPick.CharsOf(name);
        return length > 40 ? $"{name[..3]}*{length}" : name;
    }

    /// <summary>
    /// Reads a state as the recorder wrote it.
    /// </summary>
    /// <param name="text">The state's name.</param>
    /// <returns>The state.</returns>
    private static ModPickState StateOf(string text) => Enum.Parse<ModPickState>(text, true);

    /// <summary>
    /// Expands an argument the recorder wrote short: "&lt;x*3&gt;" stands for "xxx".
    /// </summary>
    /// <param name="argument">The argument.</param>
    /// <returns>It, expanded.</returns>
    private static string Expand(string argument) =>
        Short().Match(argument) is { Success: true } match ? string.Concat(Enumerable.Repeat(match.Groups[1].Value, int.Parse(match.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture))) : argument;

    /// <summary>
    /// The short form of a long argument.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A<(.)\*(\d+)>\z")]
    private static partial Regex Short();
}
