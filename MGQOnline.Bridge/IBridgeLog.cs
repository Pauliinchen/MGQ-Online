//----------------------------------------------------------------
//  IBridgeLog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Bridge;

/// <summary>
/// Where the bridge's lines go: the DLL's file log in the game, log events on the battle server.
/// </summary>
/// <remarks>
/// The core writes no file itself, since a sandboxed battle server child may write none.
/// </remarks>
public interface IBridgeLog
{
    /// <summary>
    /// Writes one line.
    /// </summary>
    /// <param name="line">The line, a sentence without a time stamp.</param>
    void Write(string line);
}
