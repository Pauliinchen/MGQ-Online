//----------------------------------------------------------------
//  ModTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//      Paulinchen  2026-10-23: Covered the mods text topic
//                            - Gave the topics the world directory too
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics through which the scripts learn about the game's mods, as the scripts call them.
/// </summary>
public sealed class ModTopicsTests : IDisposable
{
    /// <summary>
    /// The game folder under test.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The topics under test, over the game folder.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// Creates the topics over an empty game folder.
    /// </summary>
    public ModTopicsTests()
    {
        _topics = new TopicCaller(context => ModTopics.Register(context, () => PatchScripts.List(_game.Path), () => WorldDirectory.Current));
    }

    /// <summary>
    /// Asserts that each script comes with its key and its name, a name outside the system's code
    /// page as it is.
    /// </summary>
    [Fact]
    public void Installed_ListsEachScriptWithItsKeyAndName()
    {
        Directory.CreateDirectory(Path.Combine(_game.Path, "Patch", "Ünïcode 模组"));
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"), "# Level Cap\n");
        File.WriteAllText(Path.Combine(_game.Path, "Patch", "Ünïcode 模组", "Großer Mod.rb"), "# Mod\n");

        Assert.Equal(
            new RubyArray([new RubyArray(["levelcap", "Patch/Level_Cap.rb", "Level_Cap"]), new RubyArray(["großermod", "Patch/Ünïcode 模组/Großer Mod.rb", "Großer Mod"])]),
            _topics.Call(ModTopics.Installed));
    }

    /// <summary>
    /// Asserts that a world's mods come back without their marks, the required ones first.
    /// </summary>
    [Fact]
    public void Text_ReadsTheMarks()
    {
        Assert.Equal(
            new RubyHash { { "names", new RubyArray(["Level Cap", "Data", "Other"]) }, { "required", new RubyArray(["Level Cap"]) }, { "essential", new RubyArray(["Data"]) } },
            _topics.Call(ModTopics.Text, "?Data; Other; !Level Cap"));
    }

    /// <inheritdoc />
    public void Dispose() => _game.Dispose();
}
