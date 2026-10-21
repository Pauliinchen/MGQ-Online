//----------------------------------------------------------------
//  Program.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MGQOnline.Tools.AotProbe;

/// <summary>
/// Prints what the NativeAOT build of the arena and update libraries computes, so two platforms can
/// be compared line by line.
/// </summary>
public static class Program
{
    /// <summary>
    /// Prints the probe's lines.
    /// </summary>
    /// <returns>The exit code, 0 when the probe ran.</returns>
    public static int Main()
    {
        Console.WriteLine($"runtime {RuntimeInformation.RuntimeIdentifier}");
        Console.WriteLine($"aot {!RuntimeFeature.IsDynamicCodeSupported}");
        return 0;
    }
}
