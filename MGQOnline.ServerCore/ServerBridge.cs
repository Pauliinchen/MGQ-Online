//----------------------------------------------------------------
//  ServerBridge.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Registered the topics both hosts answer
//                            - Registered the topic that derives the story mapping's index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using System.Runtime;
using System.Runtime.CompilerServices;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.ServerCore;

/// <summary>
/// The battle server core's side of the bridge: the host the four bridge exports of
/// MGQOnline.Bridge.Native call, with the log that leaves as events and the core's topics.
/// </summary>
internal static class ServerBridge
{
    /// <summary>
    /// The topic that describes the core's runtime, such as the GC heap limit it runs with.
    /// </summary>
    public const string RuntimeTopic = "core.runtime";

    /// <summary>
    /// Gets the build the handshake names, such as "0.6.9", or "0.0.0-dev" for a development build.
    /// </summary>
    public static string Build { get; } =
        (typeof(ServerBridge).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? string.Empty).Split('+')[0];

    /// <summary>
    /// Installs the host before the battle server first calls an export.
    /// </summary>
    [ModuleInitializer]
    [SuppressMessage("Usage", "CA2255:The 'ModuleInitializer' attribute should not be used in libraries", Justification = "The core is the application: NativeAOT runs it as the runtime starts, before any export runs.")]
    internal static void Install()
    {
        var log = new EventLog();
        BridgeExports.Install(new BridgeHost(Build, log, context => RegisterTopics(context, log)));
    }

    /// <summary>
    /// Points the log at a new context and registers the core's topics on it; each area adds its
    /// own as it moves to the bridge.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="log">The core's log.</param>
    private static void RegisterTopics(BridgeContext context, EventLog log)
    {
        log.Attach(context);
        context.Register(RuntimeTopic, (_, _) => DescribeRuntime());
        SharedTopics.Register(context);
        StoryIndexTopic.Register(context, System.IO.Directory.GetCurrentDirectory);
    }

    /// <summary>
    /// Describes the runtime the core runs on.
    /// </summary>
    /// <returns>{"heap_limit"=>bytes the GC may use, "server_gc"=>..., "latency"=>the GC's latency mode}.</returns>
    private static RubyHash DescribeRuntime() => new()
    {
        { "heap_limit", GC.GetGCMemoryInfo().TotalAvailableMemoryBytes },
        { "server_gc", GCSettings.IsServerGC },
        { "latency", GCSettings.LatencyMode.ToString() },
    };
}
