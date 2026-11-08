//----------------------------------------------------------------
//  GameBridgeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Checked that the DLL exports nothing beside the bridge's four functions
//                            - Checked that the DLL's project roots the assembly that installs the bridge's host
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Xml.Linq;
using MGQOnline.Bridge;

namespace MGQOnline.Multiplayer.Tests;

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
    /// Asserts that the DLL exports no function of its own, so the scripts reach it through the
    /// bridge's four functions alone and every message format stays the DLL's.
    /// </summary>
    [Fact]
    public void Dll_ExportsNothingBesideTheBridge()
    {
        var exported = typeof(GameBridge).Assembly.GetTypes()
            .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly))
            .Select(method => method.GetCustomAttribute<UnmanagedCallersOnlyAttribute>()?.EntryPoint)
            .Where(entry => entry != null);

        Assert.Empty(exported);
    }

    /// <summary>
    /// Asserts that the DLL's project roots the DLL's own assembly for NativeAOT, which otherwise
    /// drops the module initializer that installs the bridge's host, so every handshake answers
    /// nothing and the mod stays off.
    /// </summary>
    [Fact]
    public void Project_RootsTheAssemblyThatInstallsTheBridge()
    {
        string folder = AppContext.BaseDirectory;
        while (!File.Exists(Path.Combine(folder, "MGQ-Online.slnx")))
        {
            folder = Path.GetDirectoryName(folder) ?? throw new InvalidOperationException("The repository's solution was not found above the tests.");
        }

        XDocument project = XDocument.Load(Path.Combine(folder, "MGQOnline.Multiplayer", "MGQOnline.Multiplayer.csproj"));
        string assembly = project.Descendants("AssemblyName").Single().Value;
        IEnumerable<string> rooted = project.Descendants("TrimmerRootAssembly").Select(root => root.Attribute("Include")!.Value.Replace("$(AssemblyName)", assembly, StringComparison.Ordinal));

        Assert.Equal(typeof(GameBridge).Assembly.GetName().Name, assembly);
        Assert.Contains(assembly, rooted);
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
