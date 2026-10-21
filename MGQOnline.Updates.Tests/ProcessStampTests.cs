//----------------------------------------------------------------
//  ProcessStampTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests waiting for a process told apart by its id and start time.
/// </summary>
public sealed class ProcessStampTests
{
    /// <summary>
    /// How long a test waits for a short process.
    /// </summary>
    private static readonly TimeSpan LongWait = TimeSpan.FromSeconds(30);

    /// <summary>
    /// A running process with its own start time is waited for until the timeout.
    /// </summary>
    [Fact]
    public void WaitsForARunningProcess()
    {
        var current = ProcessStamp.Current();

        Assert.Equal(Environment.ProcessId, current.Pid);
        Assert.False(current.WaitForExit(TimeSpan.FromMilliseconds(50)));
    }

    /// <summary>
    /// A running process with another start time counts as ended, since its id was reused.
    /// </summary>
    /// <param name="offsetSeconds">How far the stamped start time is from the real one.</param>
    [Theory]
    [InlineData(-5)]
    [InlineData(5)]
    public void TreatsAReusedIdAsEnded(int offsetSeconds)
    {
        var current = ProcessStamp.Current();
        var other = current with { StartTimeTicks = current.StartTimeTicks + TimeSpan.FromSeconds(offsetSeconds).Ticks };

        Assert.True(other.WaitForExit(LongWait));
    }

    /// <summary>
    /// An id no process has counts as ended.
    /// </summary>
    [Fact]
    public void TreatsAMissingProcessAsEnded()
    {
        Assert.True(new ProcessStamp(int.MaxValue - 1, 0).WaitForExit(LongWait));
    }

    /// <summary>
    /// A short process is waited for until it ends.
    /// </summary>
    [Fact]
    public void WaitsUntilAProcessEnds()
    {
        var start = OperatingSystem.IsWindows()
            ? new ProcessStartInfo("cmd.exe", "/c ping -n 2 127.0.0.1 >nul")
            : new ProcessStartInfo("/bin/sh", "-c \"sleep 1\"");
        start.UseShellExecute = false;
        start.CreateNoWindow = true;

        using var process = Process.Start(start)!;
        var stamp = new ProcessStamp(process.Id, process.StartTime.ToUniversalTime().Ticks);

        Assert.True(stamp.WaitForExit(LongWait));
        Assert.True(process.HasExited);
        Assert.True(stamp.WaitForExit(TimeSpan.Zero));
    }
}
