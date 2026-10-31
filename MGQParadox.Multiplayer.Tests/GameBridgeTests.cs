//----------------------------------------------------------------
//  GameBridgeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Tests of the topics the DLL registers on each context.
/// </summary>
public sealed class GameBridgeTests
{
    /// <summary>
    /// Asserts that the DLL registers none of the interface's topics, which the Mod Framework's DLL
    /// answers, but the bug report's screenshot.
    /// </summary>
    [Fact]
    public void RegisterTopics_LeavesTheInterfaceToTheModFramework()
    {
        var context = new BridgeContext(1, new LineLog());

        GameBridge.RegisterTopics(context);

        Assert.Equal(["ui.report.snap"], context.Topics.Where(topic => topic.StartsWith("ui.", System.StringComparison.Ordinal)));
    }

    /// <summary>
    /// A log that keeps its lines.
    /// </summary>
    private sealed class LineLog : IBridgeLog
    {
        /// <summary>
        /// Gets the lines written.
        /// </summary>
        public List<string> Lines { get; } = [];

        /// <inheritdoc />
        public void Write(string line) => Lines.Add(line);
    }
}
