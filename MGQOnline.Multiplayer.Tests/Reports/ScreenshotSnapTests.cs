//----------------------------------------------------------------
//  ScreenshotSnapTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.InteropServices;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Reports;

namespace MGQOnline.Multiplayer.Tests.Reports;

/// <summary>
/// Covers the screenshot the scripts hand over by a Bitmap's address: the DLL walks to its pixels
/// in this process, as RGSS3 lays a Bitmap out.
/// </summary>
public sealed class ScreenshotSnapTests
{
    /// <summary>
    /// Asserts that a chain of pointers laid out as RGSS3's leads to the pixels the report keeps,
    /// and that a screen outside the report's sizes is refused before any pointer is read.
    /// </summary>
    [Fact]
    public unsafe void Snap_WalksToThePixelsAndKeepsThem()
    {
        nint pixels = Marshal.AllocHGlobal(2 * 1 * 4);
        nint bitmap = Marshal.AllocHGlobal(32);
        nint data = Marshal.AllocHGlobal(32);
        nint ruby = Marshal.AllocHGlobal(32);
        try
        {
            new Span<byte>((void*)pixels, 8).Fill(0x7F);
            *(uint*)(bitmap + 16) = (uint)pixels;
            *(uint*)(data + 8) = (uint)bitmap;
            *(uint*)(ruby + 16) = (uint)data;

            RubyValue kept = GameBridge.Snap([(long)(uint)ruby, 2, 1]);
            RubyValue refused = GameBridge.Snap([0, 0, 1]);

            Assert.True(kept.AsBool());
            Assert.False(refused.AsBool());
        }
        finally
        {
            BugReports.Current.DropSnap();
            foreach (nint block in new[] { pixels, bitmap, data, ruby })
            {
                Marshal.FreeHGlobal(block);
            }
        }
    }
}
