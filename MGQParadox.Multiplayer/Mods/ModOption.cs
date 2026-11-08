//----------------------------------------------------------------
//  ModOption.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Named an option's type and wrote its values from the values the scripts hand over
//                            - Took an option as the values the scripts hand over, no longer as a line of text
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A Mod Config option a mod of the website offers, as an admin's game read it.
/// </summary>
/// <param name="Key">The option's key, the name of the Ruby symbol the game keeps its value under.</param>
/// <param name="Name">Its name in the menu.</param>
/// <param name="Type">Its value's type as a world's settings write it: i, f, b, y or s.</param>
/// <param name="Default">Its default value.</param>
/// <param name="Choices">The values the menu offers, each with its name; none for a free value.</param>
internal sealed record ModOption(string Key, string Name, string Type, string Default, IReadOnlyList<(string Value, string Name)> Choices)
{
    /// <summary>
    /// Takes an option the scripts handed over, its type that of its default.
    /// </summary>
    /// <param name="option"><c>key</c> and <c>name</c> (texts), <c>default</c> and <c>choices</c>
    /// ([value, name] each), each value as <see cref="SharedSettings.ValueOf"/> reads it.</param>
    /// <returns>The option, its choices of a type a world does not keep left out; <see langword="null"/> for an option whose default has such a type.</returns>
    public static ModOption? Of(RubyHash option)
    {
        ArgumentNullException.ThrowIfNull(option);
        if (SharedSettings.ValueOf(option["default"]) is not { } fallback)
        {
            return null;
        }

        var choices = new List<(string Value, string Name)>();
        foreach (RubyArray choice in option["choices"].AsArray().Select(choice => choice.AsArray()))
        {
            if (SharedSettings.ValueOf(choice[0]) is { } value)
            {
                choices.Add((SharedSettings.Raw(value), choice[1].AsText()));
            }
        }

        return new ModOption(option["key"].AsText(), option["name"].AsText(), fallback.Type.ToString(), SharedSettings.Raw(fallback), choices);
    }
}
