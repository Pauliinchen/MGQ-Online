//----------------------------------------------------------------
//  GameBridge.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Kept the bug report's screenshot by walking to its pixels here
//                            - Registered the interface's models with the keyboard
//                            - Registered the topics of the open world
//                            - Registered the topics both hosts answer
//                            - Registered the topics of Player.ini and the other settings files
//                            - Registered the topics of the scripts' log
//                            - Registered the topics of a world's rules
//                            - Registered the topics of the game's mods
//                            - Registered the topics of the game's rules
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQOnline.Game.Ui;
using MGQOnline.Game.Ui.Text;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Reports;
using MGQParadox.Multiplayer.Topics;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The DLL's side of the bridge to the scripts: the host the four bridge exports of
/// MGQOnline.Bridge.Native call, with the DLL's file log and topics.
/// </summary>
internal static unsafe class GameBridge
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
        RuleTopics.Register(context);
        SharedTopics.Register(context);
        ModTopics.Register(context, () => ModParking.Current, () => WorldDirectory.Current);
        WorldTopics.Register(context);
        WorldRoomTopics.Register(context);
        UiTopics.Register(context, new TypedText());
        context.Register(SnapTopic, (_, request) => Snap(request.AsArray()));
    }

    /// <summary>
    /// Keeps the screen of a Bitmap the scripts snapped as the bug report's screenshot: [the Bitmap's
    /// address, its width, its height], answering whether the report keeps it.
    /// </summary>
    internal const string SnapTopic = "ui.report.snap";

    /// <summary>
    /// Walks from a Bitmap's Ruby object to its pixels in this process and keeps a copy of them as
    /// the bug report's screenshot.
    /// </summary>
    /// <param name="request">[the Bitmap's address, its width, its height].</param>
    /// <returns>Whether the report keeps the screenshot.</returns>
    internal static RubyValue Snap(RubyArray request)
    {
        long address = request[0].AsLong();
        int width = request[1].AsInt();
        int height = request[2].AsInt();
        if (!ScreenshotWalk.IsScreenSize(width, height))
        {
            return false;
        }

        long pixels = ScreenshotWalk.PixelsOf(address, at => *(uint*)(nint)at);
        return BugReports.Current.Snap(new ReadOnlySpan<byte>((void*)(nint)pixels, width * height * ScreenshotWalk.PixelBytes), width, height);
    }

    /// <summary>
    /// Hands the text box of the interface what the player types into the game's window.
    /// </summary>
    private sealed class TypedText : ITypedText
    {
        /// <inheritdoc />
        public (string Text, int Keys) Take() => Keyboard.Take();
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
