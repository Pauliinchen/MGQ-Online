//----------------------------------------------------------------
//  ProcessUsage.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Told the largest free block of the address space and the heap of the DLL's collector
//      Paulinchen  2026-11-05: Told the free address space as a number, which the scripts weigh a live map by
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
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
    /// The state VirtualQuery gives a free region of the address space.
    /// </summary>
    private const uint MemoryFree = 0x10000;

    /// <summary>
    /// The lowest address a region of the address space may start at.
    /// </summary>
    private const ulong LowestAddress = 0x10000;

    /// <summary>
    /// Describes the memory and the handles the game uses now, in one short line.
    /// </summary>
    /// <returns>Such as <c>private 812 MB, address space 1450 of 4096 MB, largest free block 140 MB, 320 GDI and 150 USER handles, DLL heap 3 MB</c>; a part Windows cannot tell is left out.</returns>
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

        if (LargestFreeBlock() is { } largest)
        {
            parts.Add($"largest free block {largest} MB");
        }

        parts.Add($"{GetGuiResources(CurrentProcess, GdiObjects)} GDI and {GetGuiResources(CurrentProcess, UserObjects)} USER handles");
        parts.Add($"DLL heap {DllHeap()} MB");
        return string.Join(", ", parts);
    }

    /// <summary>
    /// Tells the largest free block of the game's address space, the most one picture or other
    /// allocation of the game may take.
    /// </summary>
    /// <remarks>
    /// A 32-bit game runs out of a free block of the size it asks for long before its free address
    /// space as a whole runs out.
    /// </remarks>
    /// <returns>The block's megabytes, <see langword="null"/> when Windows cannot tell.</returns>
    public static long? LargestFreeBlock()
    {
        var info = new MemoryBasicInformation();
        var size = (nuint)sizeof(MemoryBasicInformation);
        ulong address = LowestAddress;
        ulong largest = 0;
        var read = false;
        while (address <= nuint.MaxValue && VirtualQuery((nuint)address, &info, size) != 0)
        {
            read = true;
            if (info.State == MemoryFree && info.RegionSize > largest)
            {
                largest = info.RegionSize;
            }

            var next = (ulong)info.BaseAddress + info.RegionSize;
            if (next <= address)
            {
                break;
            }

            address = next;
        }

        return read ? (long)(largest / Megabyte) : null;
    }

    /// <summary>
    /// Tells the heap of this DLL's own garbage collector.
    /// </summary>
    /// <returns>The megabytes it holds.</returns>
    public static long DllHeap() => GC.GetTotalMemory(false) / Megabyte;

    /// <summary>
    /// Tells the address space the game has left.
    /// </summary>
    /// <returns>The free megabytes, <see langword="null"/> when Windows cannot tell.</returns>
    public static long? FreeAddressSpace()
    {
        var status = new MemoryStatus { Length = (uint)sizeof(MemoryStatus) };
        return GlobalMemoryStatusEx(&status) ? (long)(status.AvailableVirtual / Megabyte) : null;
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
    /// Reads the region of the address space an address lies in.
    /// </summary>
    /// <param name="address">The address.</param>
    /// <param name="info">Receives the region.</param>
    /// <param name="length">The size of <paramref name="info"/> in bytes.</param>
    /// <returns>The bytes written into <paramref name="info"/>, 0 past the last region.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nuint VirtualQuery(nuint address, MemoryBasicInformation* info, nuint length);

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
    /// MEMORY_BASIC_INFORMATION: a region of the address space.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryBasicInformation
    {
        /// <summary>Where the region starts.</summary>
        public nuint BaseAddress;

        /// <summary>Where the allocation the region belongs to starts.</summary>
        public nuint AllocationBase;

        /// <summary>The protection the allocation was made with.</summary>
        public uint AllocationProtect;

        /// <summary>The region's size in bytes.</summary>
        public nuint RegionSize;

        /// <summary>Whether the region is committed, reserved or free.</summary>
        public uint State;

        /// <summary>The region's protection.</summary>
        public uint Protect;

        /// <summary>The kind of its pages.</summary>
        public uint Type;
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
