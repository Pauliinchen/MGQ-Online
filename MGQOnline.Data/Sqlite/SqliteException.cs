//----------------------------------------------------------------
//  SqliteException.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Data.Sqlite;

/// <summary>
/// Thrown when SQLite refuses a call, with SQLite's result code and message.
/// </summary>
public sealed class SqliteException : Exception
{
    /// <summary>
    /// Creates the exception.
    /// </summary>
    /// <param name="code">SQLite's result code.</param>
    /// <param name="message">SQLite's message.</param>
    public SqliteException(int code, string message)
        : base(message)
    {
        Code = code;
    }

    /// <summary>
    /// Creates the exception without a message.
    /// </summary>
    public SqliteException()
    {
    }

    /// <summary>
    /// Creates the exception with a message.
    /// </summary>
    /// <param name="message">What went wrong.</param>
    public SqliteException(string message)
        : base(message)
    {
    }

    /// <summary>
    /// Creates the exception with the exception that caused it.
    /// </summary>
    /// <param name="message">What went wrong.</param>
    /// <param name="inner">The cause.</param>
    public SqliteException(string message, Exception inner)
        : base(message, inner)
    {
    }

    /// <summary>
    /// Gets SQLite's result code, such as 1 for an SQL error, or 0 when none was given.
    /// </summary>
    public int Code { get; }
}
