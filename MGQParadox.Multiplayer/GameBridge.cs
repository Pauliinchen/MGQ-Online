//----------------------------------------------------------------
//  GameBridge.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Registered the topics of a Raid World's difficulty
//                            - Registered the topics of a Raid World's gated areas
//      Paulinchen  2026-11-06: Registered the topics of the items a trade moves
//                            - Registered the topics of the emotes
//      Paulinchen  2026-11-05: Registered the topics of the frozen fights and of a lost raid boss battle's defeat, sharing the troops' sizes with the raid bosses' rules
//                            - Started the DLL as the scripts first shake hands, in place of mp_start, a refused handshake too
//                            - Registered the topics of the world directory, the update check, the memory, a Raid World's shared companions and its boss pools
//                            - Handed a Classic member's catch-up what the story's topics know of the party
//      Paulinchen  2026-10-31: Opened the registration of the topics to the tests
//                            - Left the interface's models, the keyboard and the window to the Mod Framework, keeping the bug report's screenshot
//                            - Registered the topics of the bug report's request
//                            - Left the freeze journal topics to the topics both hosts answer
//                            - Left the trades' topics to the world room's, which registers every area over the room
//      Paulinchen  2026-10-30: Registered the world screen's steps without this game's data, which entering compares once the world's mods loaded
//                            - Registered the topics of the served battle's front
//                            - Handed the topics both hosts answer the DLL's way to the raid pools
//                            - Handed the topics both hosts answer the raid pools the relay requests fill
//                            - Stopped registering the topics of turning other mods off, which the Mod Framework's session does
//                            - Registered the topics of trades
//      Paulinchen  2026-10-28: Registered the topics that read the events database's rows
//                            - Registered the topics of the catch-up over the tables the story mapping came with
//      Paulinchen  2026-10-23: Stopped registering the directory's tickets as topics
//                            - Handed the world screen's forms and this game's data to its requests
//                            - Registered the world screen's steps into a world
//                            - Registered the topics of the world screen's model
//                            - Registered the topics of turning other mods off
//                            - Registered the topics of the mods check, the shared mod settings and the directory's tickets
//                            - Registered the topics of the world screen's forms
//                            - Registered the topics of the worlds on this PC and of the mod picker
//                            - Registered the topics of the World overview
//                            - Kept the bug report's screenshot by walking to its pixels here
//                            - Registered the topics of the frozen fights' write journal
//                            - Registered the interface's models with the keyboard
//                            - Registered the topics of the story tracks and the story tables
//                            - Registered the topics of the open world
//                            - Registered the topics both hosts answer
//                            - Registered the topics of the event sorter
//                            - Shared Player.ini, the world changes, the directory and the parking between the topics
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
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Runtime.CompilerServices;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Sqlite;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;
using MGQOnline.Game.Ui;
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
    internal static void Install() => BridgeExports.Install(new BridgeHost(UpdateCheck.ModVersion, new FileLog(), context =>
    {
        Start();
        RegisterTopics(context);
    }));

    /// <summary>
    /// Whether <see cref="Start"/> ran in this process.
    /// </summary>
    private static int _started;

    /// <summary>
    /// Finds the mod folder, starts the log, deletes the logs of earlier days and puts back what an
    /// older release left parked, once per process, as the scripts first shake hands.
    /// </summary>
    /// <remarks>
    /// Nothing may throw out of it, since an exception crossing into the game ends it.
    /// </remarks>
    private static void Start()
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
        {
            return;
        }

        try
        {
            if (NativeMethods.FileOfModuleContaining((nint)(delegate* unmanaged[Stdcall]<int>)&Marker) is { } dll)
            {
                ModFolder.SetRoot(Path.GetDirectoryName(dll)!);
            }

            var version = typeof(GameBridge).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "unknown";
            Log.Write($"--- multiplayer {version} started ---");
            Log.Write($"the events database reader runs sqlite {SqliteConnection.LibraryVersion}");
            Log.DeleteOtherDays();

            if (NativeMethods.WineVersion() is { } wine)
            {
                Log.Write($"the game runs under wine {wine}");
            }

            ParkedLeftovers.PutBack(ModFolder.GamePathOf("."));
            CrashEvents.LogOnce();
        }
        catch (Exception ex)
        {
            Log.Write($"starting the DLL failed: {ex}");
        }
    }

    /// <summary>
    /// A function of the DLL whose address finds the DLL's file; never called.
    /// </summary>
    /// <returns>0.</returns>
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Marker() => 0;

    /// <summary>
    /// Registers the DLL's topics on a new context; each area adds its own as it moves to the bridge.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    internal static void RegisterTopics(BridgeContext context)
    {
        var services = new WorldServices(new PlayerIni(Path.Combine(ModFolder.Root, PlayerIni.FileName)), new WorldChanges(context), () => WorldDirectory.Current, () => PatchScripts.List(ModFolder.GamePathOf(".")),
            new DirectoryTickets(() => WorldDirectory.Current.ActionNow().State, WorldDirectory.Current.ClearAction));
        ScriptLog.Register(context);
        DllTopics.Register(context);
        DirectoryTopics.Register(context, () => WorldDirectory.Current);
        RaidRelayTopics.Register(context, RaidStory.Current, RaidBosses.Current);
        SettingsTopics.Register(context, services.Player);
        RuleTopics.Register(context);
        var roster = new RaidRoster();
        SharedTopics.Register(context, RaidBosses.Current, roster);
        FreezeTopics.Register(context, () => RaidBosses.Current.Ledger, roster, () => GameEvents.Current);
        ModTopics.Register(context, services.Scripts, services.Directory);
        EventTopics.Register(context, () => GameEvents.Current);
        EventTableTopics.Register(context, () => GameEvents.Current);
        WorldTopics.Register(context);
        OverviewTopics.Register(context);
        EmoteTopics.Register(context);
        TradeLimitTopics.Register(context);
        GateTopics.Register(context);
        DifficultyTopics.Register(context);
        LocalWorldTopics.Kept local = LocalWorldTopics.Register(context, services);
        ModPickTopics.Register(context, services.Scripts);
        FormTopics forms = FormTopics.Register(context);
        ModCheckTopics check = ModCheckTopics.Register(context, services);
        SharedSettingsSync settings = SharedSettingsSync.Register(context, services);
        WorldScreen screen = new(WorldScreenSources.Of(services, local, check, settings));
        ScreenTopics.Register(context, screen, services.Changes, () => services.Directory().ListRevision);
        EnteringTopics.Register(context, services, local.Worlds, local.Lists, forms);
        WorldRoomTopics.Register(context);
        StoryTopics story = StoryTopics.Register(context);
        CatchupTopics.Register(context, () => story.Catchup, () => story.ClassicParty);
        ServedTopics.Register(context, BattleSession.Current);
        context.Register(SnapTopic, (_, request) => Snap(request.AsArray()));
        ReportTopics.Register(context, BugReports.Current);
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
    /// Writes the bridge's lines into the DLL's log, starting the DLL first, so a handshake the
    /// bridge refuses before any context opens is logged in the game's Logs folder too.
    /// </summary>
    private sealed class FileLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
            Start();
            Log.Write(line);
        }
    }
}
