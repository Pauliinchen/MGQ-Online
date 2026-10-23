//----------------------------------------------------------------
//  BridgeRequestException.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Bridge;

/// <summary>
/// Thrown by a handler whose request misses what its topic needs; the caller gets a
/// <see cref="BridgeEnvelope.BadRequest"/> reply with the message.
/// </summary>
public sealed class BridgeRequestException : Exception
{
    /// <summary>
    /// Creates the exception.
    /// </summary>
    /// <param name="message">What the request lacks, as a sentence, such as "The seat is missing."</param>
    public BridgeRequestException(string message)
        : base(message)
    {
    }

    /// <summary>
    /// Creates the exception without a message.
    /// </summary>
    public BridgeRequestException()
    {
    }

    /// <summary>
    /// Creates the exception with the exception that caused it.
    /// </summary>
    /// <param name="message">What the request lacks, as a sentence.</param>
    /// <param name="inner">The cause.</param>
    public BridgeRequestException(string message, Exception inner)
        : base(message, inner)
    {
    }
}
