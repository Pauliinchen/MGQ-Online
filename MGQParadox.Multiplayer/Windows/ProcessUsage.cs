//----------------------------------------------------------------
//  ProcessUsage.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// The memory and the handles the game uses, which the game script logs at each switch of screens.
/// </summary>
internal static unsafe partial class ProcessUsage
{
    /// <summary>
    /// Bytes in a megabyte.
    /// </summary>
    private const long Megabyte = 1024 * 1024;

    /// <summary>
    /// Asks GetGuiResources for the GDI objects.
    /// </summary>
    private const uint GdiObjects = 0;

    /// <summary>
    /// Asks GetGuiResources for the USER objects.
    /// </summary>
    private const uint UserObjects = 1;

    /// <summary>
    /// The handle that stands for the calling process.
    /// </summary>
    private const nint CurrentProcess = -1;

    /// <summary>
    /// Describes the memory and the handles the game uses now, in one short line.
    /// </summary>
    /// <returns>Such as <c>private 812 MB, address space 1450 of 4096 MB, 320 GDI and 150 USER handles</c>; a part Windows cannot tell is left out.</returns>
    public static string Describe()
    {
        var counters = new ProcessMemoryCounters { Size = (uint)sizeof(ProcessMemoryCounters) };
        var status = new MemoryStatus { Length = (uint)sizeof(MemoryStatus) };
        var parts = new List<string>();

        if (K32GetProcessMemoryInfo(CurrentProcess, &counters, counters.Size))
        {
            parts.Add($"private {Megabytes((ulong)counters.PrivateUsage)} MB");
        }

        if (GlobalMemoryStatusEx(&status))
        {
            parts.Add($"address space {Megabytes(status.TotalVirtual - status.AvailableVirtual)} of {Megabytes(status.TotalVirtual)} MB");
        }

        parts.Add($"{GetGuiResources(CurrentProcess, GdiObjects)} GDI and {GetGuiResources(CurrentProcess, UserObjects)} USER handles");
        return string.Join(", ", parts);
    }

    /// <summary>
    /// Turns bytes into whole megabytes.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The megabytes, rounded down.</returns>
    private static string Megabytes(ulong bytes) => (bytes / Megabyte).ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Reads the memory counters of a process.
    /// </summary>
    /// <param name="process">The process.</param>
    /// <param name="counters">Receives the counters.</param>
    /// <param name="size">The counters' size in bytes.</param>
    /// <returns><see langword="true"/> when they were read.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool K32GetProcessMemoryInfo(nint process, ProcessMemoryCounters* counters, uint size);

    /// <summary>
    /// Reads the memory of the computer and the address space of the calling process.
    /// </summary>
    /// <param name="status">Receives them, its length set.</param>
    /// <returns><see langword="true"/> when they were read.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GlobalMemoryStatusEx(MemoryStatus* status);

    /// <summary>
    /// Counts the GDI or USER objects of a process.
    /// </summary>
    /// <param name="process">The process.</param>
    /// <param name="kind">Which objects.</param>
    /// <returns>How many, 0 when it failed.</returns>
    [LibraryImport("user32.dll")]
    private static partial uint GetGuiResources(nint process, uint kind);

    /// <summary>
    /// PROCESS_MEMORY_COUNTERS_EX: a process's memory.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessMemoryCounters
    {
        /// <summary>The structure's size in bytes.</summary>
        public uint Size;

        /// <summary>The page faults.</summary>
        public uint PageFaultCount;

        /// <summary>The largest working set.</summary>
        public nuint PeakWorkingSetSize;

        /// <summary>The working set.</summary>
        public nuint WorkingSetSize;

        /// <summary>The largest paged pool.</summary>
        public nuint QuotaPeakPagedPoolUsage;

        /// <summary>The paged pool.</summary>
        public nuint QuotaPagedPoolUsage;

        /// <summary>The largest nonpaged pool.</summary>
        public nuint QuotaPeakNonPagedPoolUsage;

        /// <summary>The nonpaged pool.</summary>
        public nuint QuotaNonPagedPoolUsage;

        /// <summary>The committed memory.</summary>
        public nuint PagefileUsage;

        /// <summary>The largest committed memory.</summary>
        public nuint PeakPagefileUsage;

        /// <summary>The private bytes.</summary>
        public nuint PrivateUsage;
    }

    /// <summary>
    /// MEMORYSTATUSEX: the computer's memory and the calling process's address space.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatus
    {
        /// <summary>The structure's size in bytes.</summary>
        public uint Length;

        /// <summary>The share of memory in use, in percent.</summary>
        public uint MemoryLoad;

        /// <summary>The physical memory.</summary>
        public ulong TotalPhysical;

        /// <summary>The free physical memory.</summary>
        public ulong AvailablePhysical;

        /// <summary>The commit limit.</summary>
        public ulong TotalPageFile;

        /// <summary>The free commit.</summary>
        public ulong AvailablePageFile;

        /// <summary>The process's address space.</summary>
        public ulong TotalVirtual;

        /// <summary>The process's free address space.</summary>
        public ulong AvailableVirtual;

        /// <summary>Reserved, always 0.</summary>
        public ulong AvailableExtendedVirtual;
    }
}
