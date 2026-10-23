//----------------------------------------------------------------
//  GameBridge.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Registered the topics of Player.ini and the other settings files
//                            - Registered the topics of the scripts' log
//                            - Created
//
//----------------------------------------------------------------

using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The DLL's side of the bridge to the scripts: the host the four bridge exports of
/// MGQOnline.Bridge.Native call, with the DLL's file log and topics.
/// </summary>
internal static class GameBridge
{
    /// <summary>
    /// Installs the host before the scripts first call an export.
    /// </summary>
    [ModuleInitializer]
    [SuppressMessage("Usage", "CA2255:The 'ModuleInitializer' attribute should not be used in libraries", Justification = "The DLL is the application: NativeAOT runs it as the runtime starts, before any export runs.")]
    internal static void Install() => BridgeExports.Install(new BridgeHost(UpdateCheck.ModVersion, new FileLog(), RegisterTopics));

    /// <summary>
    /// Registers the DLL's topics on a new context; each area adds its own as it moves to the bridge.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    private static void RegisterTopics(BridgeContext context)
    {
        ScriptLog.Register(context);
        SettingsTopics.Register(context);
    }

    /// <summary>
    /// Writes the bridge's lines into the DLL's log.
    /// </summary>
    private sealed class FileLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line) => Log.Write(line);
    }
}
