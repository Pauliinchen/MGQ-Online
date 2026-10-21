//----------------------------------------------------------------
//  ProcessStamp.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Threading;

namespace MGQOnline.Updates;

/// <summary>
/// A process told apart by its id and its start time, since the system reuses ids.
/// </summary>
/// <param name="Pid">The process id.</param>
/// <param name="StartTimeTicks">The start time as UTC ticks.</param>
public sealed record ProcessStamp(int Pid, long StartTimeTicks)
{
    /// <summary>
    /// How far two readings of the same start time may differ.
    /// </summary>
    private static readonly long Tolerance = TimeSpan.FromMilliseconds(500).Ticks;

    /// <summary>
    /// How long to wait between two looks for a process that cannot be opened.
    /// </summary>
    private static readonly TimeSpan PollPause = TimeSpan.FromMilliseconds(100);

    /// <summary>
    /// Stamps the running process.
    /// </summary>
    /// <returns>The running process's id and start time.</returns>
    public static ProcessStamp Current()
    {
        using var process = Process.GetCurrentProcess();
        return new ProcessStamp(process.Id, StartTicksOf(process));
    }

    /// <summary>
    /// Waits until the stamped process has ended.
    /// </summary>
    /// <remarks>
    /// A process the caller may not open, like an elevated one, cannot show its start time, so it
    /// counts as ended only once its id is gone.
    /// </remarks>
    /// <param name="timeout">How long to wait at most.</param>
    /// <returns>True when the process has ended, or its id now belongs to another process.</returns>
    public bool WaitForExit(TimeSpan timeout)
    {
        Process process;

        try
        {
            process = Process.GetProcessById(Pid);
        }
        catch (ArgumentException)
        {
            return true;
        }

        using (process)
        {
            try
            {
                if (Math.Abs(StartTicksOf(process) - StartTimeTicks) > Tolerance)
                {
                    return true;
                }

                return process.WaitForExit(timeout);
            }
            catch (InvalidOperationException)
            {
                return true;
            }
            catch (Win32Exception)
            {
                return WaitForIdToVanish(timeout);
            }
        }
    }

    /// <summary>
    /// Looks for the stamped id until no process has it.
    /// </summary>
    /// <param name="timeout">How long to wait at most.</param>
    /// <returns>True when no process has the id any more.</returns>
    private bool WaitForIdToVanish(TimeSpan timeout)
    {
        var watch = Stopwatch.StartNew();

        while (true)
        {
            try
            {
                Process.GetProcessById(Pid).Dispose();
            }
            catch (ArgumentException)
            {
                return true;
            }

            if (watch.Elapsed >= timeout)
            {
                return false;
            }

            Thread.Sleep(PollPause);
        }
    }

    /// <summary>
    /// Reads a process's start time.
    /// </summary>
    /// <param name="process">The process.</param>
    /// <returns>The start time as UTC ticks.</returns>
    private static long StartTicksOf(Process process) => process.StartTime.ToUniversalTime().Ticks;
}
