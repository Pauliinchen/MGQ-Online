//----------------------------------------------------------------
//  Exports.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace MGQOnline.ServerCoreProbe;

/// <summary>
/// The probe library's exports, which probe.rb calls through Fiddle in a forked, sandboxed child.
/// Every export that writes text answers its length in bytes, or its negative length when the
/// caller's buffer is too small.
/// </summary>
internal static unsafe class Exports
{
    /// <summary>The version the handshake answers.</summary>
    private const int Version = 1;

    /// <summary>Bytes in a megabyte.</summary>
    private const int Megabyte = 1024 * 1024;

    /// <summary>The size of each throwaway block, below the large object heap's threshold.</summary>
    private const int ChurnBlock = 64 * 1024;

    /// <summary>The bytes between two writes that make a kept block's pages resident.</summary>
    private const int PageSize = 4096;

    /// <summary>The objects the stress call leaves to the finalizer.</summary>
    private const int Finalizables = 100;

    /// <summary>Holds the last throwaway block, so the compiler cannot drop the allocations.</summary>
    private static volatile byte[]? sink;

    /// <summary>Counts the objects the finalizer ran on.</summary>
    private static int finalized;

    /// <summary>
    /// The handshake. Its first call starts the runtime.
    /// </summary>
    /// <returns>The library's version.</returns>
    [UnmanagedCallersOnly(EntryPoint = "core_open")]
    public static int Open() => Version;

    /// <summary>
    /// Copies a byte buffer into another.
    /// </summary>
    /// <param name="input">The bytes.</param>
    /// <param name="length">How many bytes the input holds.</param>
    /// <param name="output">Where the copy goes.</param>
    /// <param name="capacity">How many bytes the output holds.</param>
    /// <returns>The length, its negative when the output is too small, or 0 for a negative length.</returns>
    [UnmanagedCallersOnly(EntryPoint = "core_echo")]
    public static int Echo(byte* input, int length, byte* output, int capacity)
    {
        if (length < 0)
        {
            return 0;
        }
        if (length > capacity)
        {
            return -length;
        }
        new ReadOnlySpan<byte>(input, length).CopyTo(new Span<byte>(output, capacity));
        return length;
    }

    /// <summary>
    /// Describes the runtime and the GC settings it started with, one "key=value" per line.
    /// </summary>
    /// <param name="output">Where the text goes.</param>
    /// <param name="capacity">How many bytes the output holds.</param>
    /// <returns>The text's length, see <see cref="Exports"/>.</returns>
    [UnmanagedCallersOnly(EntryPoint = "core_info")]
    public static int Info(byte* output, int capacity)
    {
        var text = new StringBuilder();
        try
        {
            text.Append("framework=").Append(RuntimeInformation.FrameworkDescription).Append('\n');
            text.Append("server_gc=").Append(GCSettings.IsServerGC).Append('\n');
            text.Append("latency=").Append(GCSettings.LatencyMode).Append('\n');
            text.Append("processors=").Append(Environment.ProcessorCount).Append('\n');
            text.Append("total_available=").Append(GC.GetGCMemoryInfo().TotalAvailableMemoryBytes).Append('\n');
            foreach (var (key, value) in GC.GetConfigurationVariables())
            {
                text.Append("gc.").Append(key).Append('=').Append(value).Append('\n');
            }
        }
        catch (Exception ex)
        {
            text.Append("error=").Append(ex.GetType().Name).Append(": ").Append(ex.Message).Append('\n');
        }
        return Write(text, output, capacity);
    }

    /// <summary>
    /// Makes the GC run, keeps memory alive up to a size, runs the finalizer and a thread of its own.
    /// </summary>
    /// <param name="churnMegabytes">Megabytes allocated and dropped at once, which makes the GC run.</param>
    /// <param name="keepMegabytes">Megabytes kept alive at once, which tests the heap limit.</param>
    /// <param name="output">Where the outcome goes, one "key=value" per line.</param>
    /// <param name="capacity">How many bytes the output holds.</param>
    /// <returns>The text's length, see <see cref="Exports"/>.</returns>
    [UnmanagedCallersOnly(EntryPoint = "core_stress")]
    public static int Stress(int churnMegabytes, int keepMegabytes, byte* output, int capacity)
    {
        var text = new StringBuilder();
        try
        {
            var started = Stopwatch.GetTimestamp();
            var collections = new[] { GC.CollectionCount(0), GC.CollectionCount(1), GC.CollectionCount(2) };
            Churn(churnMegabytes);
            var (kept, outOfMemory) = Keep(keepMegabytes);
            text.Append("kept_mb=").Append(kept).Append('\n');
            text.Append("oom=").Append(outOfMemory ? 1 : 0).Append('\n');
            text.Append("peak_committed=").Append(GC.GetGCMemoryInfo().TotalCommittedBytes).Append('\n');
            GC.Collect();
            text.Append("finalized=").Append(RunFinalizer()).Append('\n');
            text.Append("thread=").Append(RunThread()).Append('\n');
            for (var generation = 0; generation < collections.Length; generation++)
            {
                text.Append("gc").Append(generation).Append('=').Append(GC.CollectionCount(generation) - collections[generation]).Append('\n');
            }
            text.Append("heap=").Append(GC.GetTotalMemory(false)).Append('\n');
            text.Append("total_available=").Append(GC.GetGCMemoryInfo().TotalAvailableMemoryBytes).Append('\n');
            text.Append("ms=").Append((long)Stopwatch.GetElapsedTime(started).TotalMilliseconds).Append('\n');
        }
        catch (Exception ex)
        {
            text.Append("error=").Append(ex.GetType().Name).Append(": ").Append(ex.Message).Append('\n');
        }
        return Write(text, output, capacity);
    }

    /// <summary>
    /// Allocates blocks and drops each at once.
    /// </summary>
    /// <param name="megabytes">How many megabytes in all.</param>
    private static void Churn(int megabytes)
    {
        for (long i = 0; i < (long)megabytes * Megabyte / ChurnBlock; i++)
        {
            var block = new byte[ChurnBlock];
            block[0] = 1;
            sink = block;
        }
        sink = null;
    }

    /// <summary>
    /// Keeps megabyte blocks alive, each page written, until the size or the heap limit is reached,
    /// then lets them go.
    /// </summary>
    /// <param name="megabytes">How many megabytes to keep.</param>
    /// <returns>How many megabytes were kept, and whether the heap ran out first.</returns>
    private static (int Kept, bool OutOfMemory) Keep(int megabytes)
    {
        var blocks = new List<byte[]>(megabytes);
        try
        {
            while (blocks.Count < megabytes)
            {
                var block = new byte[Megabyte];
                for (var offset = 0; offset < block.Length; offset += PageSize)
                {
                    block[offset] = 1;
                }
                blocks.Add(block);
            }
            return (blocks.Count, false);
        }
        catch (OutOfMemoryException)
        {
            return (blocks.Count, true);
        }
    }

    /// <summary>
    /// Leaves objects to the finalizer and waits for it.
    /// </summary>
    /// <remarks>
    /// A runtime started before a fork has no finalizer thread in the child, so this never returns
    /// there.
    /// </remarks>
    /// <returns>How many of them it ran on.</returns>
    private static int RunFinalizer()
    {
        var before = Volatile.Read(ref finalized);
        LeaveFinalizables();
        GC.Collect();
        GC.WaitForPendingFinalizers();
        return Volatile.Read(ref finalized) - before;
    }

    /// <summary>
    /// Makes objects with a finalizer and drops them, in a method of its own so none stays reachable
    /// from the caller's frame.
    /// </summary>
    private static void LeaveFinalizables()
    {
        for (var i = 0; i < Finalizables; i++)
        {
            _ = new Finalizable();
        }
    }

    /// <summary>
    /// Starts a thread that sums numbers and joins it.
    /// </summary>
    /// <returns>The thread's sum.</returns>
    private static long RunThread()
    {
        long sum = 0;
        var thread = new Thread(() =>
        {
            for (var i = 0; i < 1_000_000; i++)
            {
                sum += i;
            }
        });
        thread.Start();
        thread.Join();
        return sum;
    }

    /// <summary>
    /// Writes a text into the caller's buffer as UTF-8.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="output">The buffer.</param>
    /// <param name="capacity">How many bytes it holds.</param>
    /// <returns>The text's length, its negative when the buffer is too small.</returns>
    private static int Write(StringBuilder text, byte* output, int capacity)
    {
        var bytes = Encoding.UTF8.GetBytes(text.ToString());
        if (bytes.Length > capacity)
        {
            return -bytes.Length;
        }
        bytes.CopyTo(new Span<byte>(output, capacity));
        return bytes.Length;
    }

    /// <summary>
    /// An object that counts its finalization.
    /// </summary>
    private sealed class Finalizable
    {
        /// <summary>
        /// Counts the finalization.
        /// </summary>
        ~Finalizable() => Interlocked.Increment(ref finalized);
    }
}
