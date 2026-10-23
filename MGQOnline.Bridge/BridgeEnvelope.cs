//----------------------------------------------------------------
//  BridgeEnvelope.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge;

/// <summary>
/// The Hash every reply of the bridge is: {"ok"=>true, "value"=>...} or
/// {"ok"=>false, "error"=>code, "text"=>...}.
/// </summary>
public static class BridgeEnvelope
{
    /// <summary>
    /// The error of a request that is broken, refused or misses what its topic needs.
    /// </summary>
    public const string BadRequest = "bad_request";

    /// <summary>
    /// The error of a topic no handler is registered for.
    /// </summary>
    public const string UnknownTopic = "unknown_topic";

    /// <summary>
    /// The error of a handler that failed.
    /// </summary>
    public const string Internal = "internal";

    /// <summary>
    /// Makes the reply of a handler that answered.
    /// </summary>
    /// <param name="value">The handler's value.</param>
    /// <returns>{"ok"=>true, "value"=>value}.</returns>
    public static RubyHash Ok(RubyValue value) => new() { { "ok", true }, { "value", value } };

    /// <summary>
    /// Makes the reply of a request that failed.
    /// </summary>
    /// <param name="code">One of <see cref="BadRequest"/>, <see cref="UnknownTopic"/> and <see cref="Internal"/>.</param>
    /// <param name="text">What went wrong, as a sentence for the log.</param>
    /// <returns>{"ok"=>false, "error"=>code, "text"=>text}.</returns>
    public static RubyHash Error(string code, string text) => new() { { "ok", false }, { "error", code }, { "text", text } };
}
