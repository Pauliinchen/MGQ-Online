//----------------------------------------------------------------
//  BridgeExports.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MGQOnline.Bridge.Native;

/// <summary>
/// The four functions the scripts reach the bridge through, mp_bridge_open, mp_call, mp_reply and
/// mp_drain, over the one <see cref="BridgeHost"/> of the process.
/// </summary>
/// <remarks>
/// A NativeAOT library exports them by naming this assembly as an UnmanagedEntryPointsAssembly and
/// calling <see cref="Install"/> from a module initializer; until then every export answers 0, as a
/// stand-in DLL does, so the scripts stay off.
/// </remarks>
public static unsafe class BridgeExports
{
    /// <summary>
    /// The host the exports call, <see langword="null"/> until the library installs one.
    /// </summary>
    private static BridgeHost? _host;

    /// <summary>
    /// Makes the exports call a host, in place of the one before.
    /// </summary>
    /// <param name="host">The host, made by the library with its log and topics.</param>
    public static void Install(BridgeHost host)
    {
        ArgumentNullException.ThrowIfNull(host);
        _host = host;
    }

    /// <summary>
    /// Opens a context when the scripts speak the bridge's version (mp_bridge_open, 'lpl').
    /// </summary>
    /// <param name="version">The scripts' BRIDGE_VERSION.</param>
    /// <param name="reply">The scripts' reply buffer.</param>
    /// <param name="size">The size of the reply buffer in bytes.</param>
    /// <returns>As <see cref="BridgeHost.Open"/>; 0 without a host or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_bridge_open", CallConvs = [typeof(CallConvStdcall)])]
    public static int Open(int version, byte* reply, int size)
    {
        if (_host is not BridgeHost host)
        {
            return 0;
        }

        try
        {
            return host.Open(version, Buffer(reply, size));
        }
        catch (Exception e)
        {
            return Failed(host, "mp_bridge_open", e);
        }
    }

    /// <summary>
    /// Runs a topic's handler (mp_call, 'lpplpl').
    /// </summary>
    /// <param name="context">The context's id from the handshake.</param>
    /// <param name="topic">The topic, UTF-8 and null-terminated.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <param name="requestLength">The request's length in bytes; 0 for nil.</param>
    /// <param name="reply">The scripts' reply buffer.</param>
    /// <param name="size">The size of the reply buffer in bytes.</param>
    /// <returns>As <see cref="BridgeHost.Call"/>; 0 without a host or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_call", CallConvs = [typeof(CallConvStdcall)])]
    public static int Call(int context, byte* topic, byte* request, int requestLength, byte* reply, int size)
    {
        if (_host is not BridgeHost host)
        {
            return 0;
        }

        try
        {
            return host.Call(context, MemoryMarshal.CreateReadOnlySpanFromNullTerminated(topic), Buffer(request, requestLength), Buffer(reply, size));
        }
        catch (Exception e)
        {
            return Failed(host, "mp_call", e);
        }
    }

    /// <summary>
    /// Hands out the reply a call parked (mp_reply, 'lpl').
    /// </summary>
    /// <param name="context">The context's id from the handshake.</param>
    /// <param name="reply">The scripts' reply buffer, now large enough.</param>
    /// <param name="size">The size of the reply buffer in bytes.</param>
    /// <returns>As <see cref="BridgeHost.TakeReply"/>; 0 without a host or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_reply", CallConvs = [typeof(CallConvStdcall)])]
    public static int Reply(int context, byte* reply, int size)
    {
        if (_host is not BridgeHost host)
        {
            return 0;
        }

        try
        {
            return host.TakeReply(context, Buffer(reply, size));
        }
        catch (Exception e)
        {
            return Failed(host, "mp_reply", e);
        }
    }

    /// <summary>
    /// Hands out the queued events once a frame (mp_drain, 'llpl').
    /// </summary>
    /// <param name="context">The context's id from the handshake.</param>
    /// <param name="frame">The scripts' frame counter.</param>
    /// <param name="buffer">The scripts' drain buffer.</param>
    /// <param name="size">The size of the drain buffer in bytes.</param>
    /// <returns>As <see cref="BridgeHost.Drain"/>; 0 without a host or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_drain", CallConvs = [typeof(CallConvStdcall)])]
    public static int Drain(int context, int frame, byte* buffer, int size)
    {
        if (_host is not BridgeHost host)
        {
            return 0;
        }

        try
        {
            return host.Drain(context, frame, Buffer(buffer, size));
        }
        catch (Exception e)
        {
            return Failed(host, "mp_drain", e);
        }
    }

    /// <summary>
    /// Takes the scripts' memory as a span.
    /// </summary>
    /// <param name="pointer">The memory; <see langword="null"/> for none.</param>
    /// <param name="size">Its size in bytes; 0 or less for none.</param>
    /// <returns>The span, empty for none.</returns>
    private static Span<byte> Buffer(byte* pointer, int size) =>
        pointer == null || size <= 0 ? Span<byte>.Empty : new Span<byte>(pointer, size);

    /// <summary>
    /// Logs an exception that got past the host, which must never cross into the game.
    /// </summary>
    /// <param name="host">The host, whose log takes the line.</param>
    /// <param name="export">The export that failed.</param>
    /// <param name="exception">The exception.</param>
    /// <returns>0, which the scripts take as no reply.</returns>
    private static int Failed(BridgeHost host, string export, Exception exception)
    {
        try
        {
            host.Log.Write($"Bridge export {export} failed:{Environment.NewLine}{exception}");
        }
        catch (Exception)
        {
            // A log that fails must not take the game down with it.
        }

        return 0;
    }
}
