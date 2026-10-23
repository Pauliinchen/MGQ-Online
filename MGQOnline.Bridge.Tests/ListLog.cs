//----------------------------------------------------------------
//  ListLog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// A log that keeps its lines for the tests to read.
/// </summary>
internal sealed class ListLog : IBridgeLog
{
    /// <summary>
    /// Gets the lines written, in order.
    /// </summary>
    public List<string> Lines { get; } = [];

    /// <inheritdoc />
    public void Write(string line) => Lines.Add(line);
}
