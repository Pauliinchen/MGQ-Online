//----------------------------------------------------------------
//  RubyValueException.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// Marshal data that is broken or refused at the bridge, or a value of another kind than its reader
/// expects.
/// </summary>
public sealed class RubyValueException : Exception
{
    /// <summary>
    /// The message of a value nested deeper than <see cref="RubyValue.MaxDepth"/>.
    /// </summary>
    internal static readonly string TooDeep = $"The value nests deeper than {RubyValue.MaxDepth} values.";

    /// <summary>
    /// Creates the exception.
    /// </summary>
    /// <param name="message">What is wrong, as a sentence.</param>
    public RubyValueException(string message)
        : base(message)
    {
    }

    /// <summary>
    /// Creates the exception without a message.
    /// </summary>
    public RubyValueException()
    {
    }

    /// <summary>
    /// Creates the exception with the exception that caused it.
    /// </summary>
    /// <param name="message">What is wrong, as a sentence.</param>
    /// <param name="inner">The cause.</param>
    public RubyValueException(string message, Exception inner)
        : base(message, inner)
    {
    }
}
