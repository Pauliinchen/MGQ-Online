//----------------------------------------------------------------
//  AfterUpdateArguments.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;

namespace MGQOnline.Updates;

/// <summary>
/// What the replaced program tells the new one it starts: <c>--after-update &lt;pid&gt; &lt;startTimeTicks&gt; &lt;oldVersion&gt;</c>.
/// </summary>
/// <param name="Previous">The replaced program's process.</param>
/// <param name="OldVersion">The replaced program's version.</param>
public sealed record AfterUpdateArguments(ProcessStamp Previous, ReleaseVersion OldVersion)
{
    /// <summary>
    /// The switch that starts the arguments.
    /// </summary>
    public const string Switch = "--after-update";

    /// <summary>
    /// The number of values after the switch.
    /// </summary>
    private const int ValueCount = 3;

    /// <summary>
    /// Writes the arguments for the new process.
    /// </summary>
    /// <returns>The switch and its three values.</returns>
    public IReadOnlyList<string> ToArguments() =>
    [
        Switch,
        Previous.Pid.ToString(CultureInfo.InvariantCulture),
        Previous.StartTimeTicks.ToString(CultureInfo.InvariantCulture),
        OldVersion.ToString(),
    ];

    /// <summary>
    /// Finds the arguments among a program's command line.
    /// </summary>
    /// <param name="args">The command line's arguments.</param>
    /// <returns>The arguments, or null when the switch is missing or its values are not all valid.</returns>
    public static AfterUpdateArguments? Find(IReadOnlyList<string> args)
    {
        for (var index = 0; index < args.Count; index++)
        {
            if (!string.Equals(args[index], Switch, StringComparison.Ordinal))
            {
                continue;
            }

            if (index + ValueCount < args.Count
                && int.TryParse(args[index + 1], NumberStyles.None, CultureInfo.InvariantCulture, out var pid)
                && long.TryParse(args[index + 2], NumberStyles.None, CultureInfo.InvariantCulture, out var ticks)
                && ReleaseVersion.TryParse(args[index + 3], out var oldVersion))
            {
                return new AfterUpdateArguments(new ProcessStamp(pid, ticks), oldVersion);
            }

            return null;
        }

        return null;
    }
}
