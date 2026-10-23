//----------------------------------------------------------------
//  ModTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Gave the topics the world directory too
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
        ModParking parking = new(_game.Path);
        _topics = new TopicCaller(context => ModTopics.Register(context, () => parking, () => WorldDirectory.Current));
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

    /// <inheritdoc />
    public void Dispose() => _game.Dispose();
}
