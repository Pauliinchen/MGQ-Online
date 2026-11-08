//----------------------------------------------------------------
//  ScriptLog.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Multiplayer;

/// <summary>
/// The game scripts' lines in the DLL's log: the bridge topics their log writes through.
/// </summary>
internal static class ScriptLog
{
    /// <summary>
    /// The topic of one line, [time of day, line], which the scripts stage with the rest of their frame.
    /// </summary>
    public const string WriteTopic = "log.write";

    /// <summary>
    /// The topic that writes every line handed over at once, as the game closes or stops on an error.
    /// </summary>
    public const string FlushTopic = "log.flush";

    /// <summary>
    /// What starts each of the scripts' lines, which tells them from the DLL's in the one timeline.
    /// </summary>
    public const string Mark = "[script] ";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(WriteTopic, (_, request) => Write(request));
        context.Register(FlushTopic, (_, _) =>
        {
            Log.FlushAtClose();
            return null;
        });
    }

    /// <summary>
    /// Queues one of the scripts' lines with the time the scripts wrote it at.
    /// </summary>
    /// <remarks>
    /// The line may come as binary, as Ruby marks a text built from bytes the DLL handed over, so it is read as UTF-8 with any broken byte replaced.
    /// </remarks>
    /// <param name="request">[time of day, line], both Strings.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    /// <exception cref="BridgeRequestException">The request is no pair.</exception>
    internal static RubyValue? Write(RubyValue request)
    {
        RubyArray pair = request.AsArray();
        if (pair.Count != 2)
        {
            throw new BridgeRequestException("A log line is [time, line].");
        }

        Log.WriteAt(TextOf(pair[0]), Mark + TextOf(pair[1]));
        return null;
    }

    /// <summary>
    /// Reads a String of any encoding as text.
    /// </summary>
    /// <param name="value">The String.</param>
    /// <returns>Its bytes as UTF-8.</returns>
    private static string TextOf(RubyValue value) => Encoding.UTF8.GetString(value.AsBytes().Span);
}
