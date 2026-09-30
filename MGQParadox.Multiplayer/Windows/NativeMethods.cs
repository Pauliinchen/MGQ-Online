//----------------------------------------------------------------
//  NativeMethods.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Runtime.InteropServices;

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// The Windows functions the DLL needs to find itself.
/// </summary>
internal static unsafe partial class NativeMethods
{
    /// <summary>
    /// Looks the module up by an address inside it instead of by name.
    /// </summary>
    private const uint FromAddress = 0x4;

    /// <summary>
    /// Leaves the module's reference count alone, so nothing has to be released.
    /// </summary>
    private const uint UnchangedRefCount = 0x2;

    /// <summary>
    /// Longest path Windows returns.
    /// </summary>
    private const int MaxPathLength = 32_768;

    /// <summary>
    /// Finds the file of the module that contains an address.
    /// </summary>
    /// <param name="address">An address inside the module, such as one of its functions.</param>
    /// <returns>The full path, or <see langword="null"/> when Windows cannot tell.</returns>
    public static string? FileOfModuleContaining(nint address)
    {
        if (!GetModuleHandleExW(FromAddress | UnchangedRefCount, address, out var module))
        {
            return null;
        }

        var buffer = new char[MaxPathLength];

        fixed (char* start = buffer)
        {
            var length = GetModuleFileNameW(module, start, (uint)buffer.Length);
            return length == 0 ? null : new string(start, 0, (int)length);
        }
    }

    /// <summary>
    /// Finds a loaded module.
    /// </summary>
    /// <param name="flags">How to look it up.</param>
    /// <param name="address">An address inside the module.</param>
    /// <param name="module">The module handle.</param>
    /// <returns><see langword="true"/> when the module was found.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetModuleHandleExW(uint flags, nint address, out nint module);

    /// <summary>
    /// Reads the file path of a loaded module.
    /// </summary>
    /// <param name="module">The module handle.</param>
    /// <param name="fileName">The buffer that receives the path.</param>
    /// <param name="size">The size of the buffer, in characters.</param>
    /// <returns>The length of the path, 0 when it failed.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial uint GetModuleFileNameW(nint module, char* fileName, uint size);
}
