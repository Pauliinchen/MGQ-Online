//----------------------------------------------------------------
//  TopicCounters.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;

namespace MGQOnline.Bridge;

/// <summary>
/// What one topic cost since the counters were last logged.
/// </summary>
public sealed class TopicCounters
{
    /// <summary>
    /// Gets the calls.
    /// </summary>
    public long Calls { get; private set; }

    /// <summary>
    /// Gets the request bytes taken.
    /// </summary>
    public long BytesIn { get; private set; }

    /// <summary>
    /// Gets the reply bytes made.
    /// </summary>
    public long BytesOut { get; private set; }

    /// <summary>
    /// Gets the longest call.
    /// </summary>
    public TimeSpan LongestCall { get; private set; }

    /// <summary>
    /// Gets the calls that answered an error.
    /// </summary>
    public long Errors { get; private set; }

    /// <summary>
    /// Counts one call.
    /// </summary>
    /// <param name="bytesIn">The request bytes.</param>
    /// <param name="bytesOut">The reply bytes.</param>
    /// <param name="took">How long the call took.</param>
    /// <param name="failed">Whether it answered an error.</param>
    internal void Count(int bytesIn, int bytesOut, TimeSpan took, bool failed)
    {
        Calls++;
        BytesIn += bytesIn;
        BytesOut += bytesOut;
        LongestCall = took > LongestCall ? took : LongestCall;
        Errors += failed ? 1 : 0;
    }

    /// <summary>
    /// Describes the counters for the log.
    /// </summary>
    /// <param name="topic">The topic they count.</param>
    /// <returns>Such as "Bridge topic story.write: 600 calls, 1200 bytes in, 3400 bytes out, longest 85 µs, 0 errors."</returns>
    internal string Describe(string topic) => string.Create(
        CultureInfo.InvariantCulture,
        $"Bridge topic {topic}: {Calls} calls, {BytesIn} bytes in, {BytesOut} bytes out, longest {(long)LongestCall.TotalMicroseconds} µs, {Errors} errors.");
}
