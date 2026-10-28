//----------------------------------------------------------------
//  SqliteConnection.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace MGQOnline.Data.Sqlite;

/// <summary>
/// One SQLite database connection with its prepared statements, which it keeps for reuse.
/// </summary>
/// <remarks>
/// Not thread-safe: the store that owns a connection guards it with a lock.
/// </remarks>
public sealed unsafe class SqliteConnection : IDisposable
{
    /// <summary>
    /// The file name SQLite opens as a private in-memory database.
    /// </summary>
    public const string InMemory = ":memory:";

    /// <summary>
    /// The statements prepared on this connection, by their SQL.
    /// </summary>
    private readonly Dictionary<string, SqliteStatement> _statements = new(StringComparer.Ordinal);

    /// <summary>
    /// The native connection, 0 once closed.
    /// </summary>
    private nint _handle;

    /// <summary>
    /// Wraps an open native connection.
    /// </summary>
    /// <param name="handle">The native connection.</param>
    private SqliteConnection(nint handle)
    {
        _handle = handle;
    }

    /// <summary>
    /// Gets the version of the SQLite library this process runs, such as "3.54.1".
    /// </summary>
    public static string LibraryVersion => Utf8(SqliteNative.LibraryVersion());

    /// <summary>
    /// Opens a database.
    /// </summary>
    /// <param name="fileName">The file's path, <see cref="InMemory"/>, or a "file:" URI with query
    /// parameters such as immutable=1.</param>
    /// <param name="mode">Whether the connection may write and create the file.</param>
    /// <returns>The open connection.</returns>
    /// <exception cref="SqliteException">SQLite could not open the database.</exception>
    public static SqliteConnection Open(string fileName, SqliteOpenMode mode)
    {
        ArgumentNullException.ThrowIfNull(fileName);
        int flags = SqliteNative.OpenUri | (mode == SqliteOpenMode.ReadOnly
            ? SqliteNative.OpenReadOnly
            : SqliteNative.OpenReadWrite | SqliteNative.OpenCreate);
        nint handle;
        int code;
        fixed (byte* name = Utf8z(fileName))
        {
            code = SqliteNative.Open(name, out handle, flags, null);
        }

        if (code != SqliteNative.Ok)
        {
            string message = handle == 0 ? "out of memory" : Utf8(SqliteNative.ErrorMessage(handle));
            SqliteNative.Close(handle);
            throw new SqliteException(code, $"SQLite could not open {fileName}: {message}");
        }

        return new SqliteConnection(handle);
    }

    /// <summary>
    /// Runs SQL that returns no rows, such as table definitions or a PRAGMA that sets a value;
    /// several statements separated by semicolons run in order.
    /// </summary>
    /// <param name="sql">The SQL.</param>
    /// <exception cref="SqliteException">SQLite refused a statement; the ones before it ran.</exception>
    public void Execute(string sql)
    {
        ArgumentNullException.ThrowIfNull(sql);
        nint handle = Handle;
        fixed (byte* text = Utf8z(sql))
        {
            Check(SqliteNative.Execute(handle, text, 0, 0, 0));
        }
    }

    /// <summary>
    /// Gets a statement for the SQL, prepared once per connection and reused after that.
    /// </summary>
    /// <remarks>
    /// Every caller of the same SQL shares one statement, so a caller disposes of it before the
    /// same SQL is prepared again; disposing only resets it.
    /// </remarks>
    /// <param name="sql">One SQL statement, with ? parameters.</param>
    /// <returns>The statement, before its first step and with every parameter NULL.</returns>
    /// <exception cref="SqliteException">SQLite refused the SQL.</exception>
    public SqliteStatement Prepare(string sql)
    {
        ArgumentNullException.ThrowIfNull(sql);
        nint handle = Handle;
        if (_statements.TryGetValue(sql, out SqliteStatement? cached))
        {
            cached.Dispose();
            return cached;
        }

        nint statement;
        fixed (byte* text = Utf8z(sql))
        {
            Check(SqliteNative.Prepare(handle, text, -1, out statement, 0));
        }

        if (statement == 0)
        {
            throw new SqliteException(0, $"The SQL holds no statement: {sql}");
        }

        var prepared = new SqliteStatement(this, statement);
        _statements.Add(sql, prepared);
        return prepared;
    }

    /// <summary>
    /// Deletes the prepared statements and closes the connection. Calling it again does nothing.
    /// </summary>
    public void Dispose()
    {
        if (_handle == 0)
        {
            return;
        }

        foreach (SqliteStatement statement in _statements.Values)
        {
            statement.Release();
        }

        _statements.Clear();
        SqliteNative.Close(_handle);
        _handle = 0;
    }

    /// <summary>
    /// Throws when a call's result code is not <see cref="SqliteNative.Ok"/>.
    /// </summary>
    /// <param name="code">The result code.</param>
    /// <exception cref="SqliteException">The code names a failure.</exception>
    internal void Check(int code)
    {
        if (code != SqliteNative.Ok)
        {
            throw Failure(code);
        }
    }

    /// <summary>
    /// Makes the exception for a failed call, with the connection's message.
    /// </summary>
    /// <param name="code">The result code.</param>
    /// <returns>The exception.</returns>
    internal SqliteException Failure(int code) => new(code, Utf8(SqliteNative.ErrorMessage(Handle)));

    /// <summary>
    /// Gets the native connection.
    /// </summary>
    /// <exception cref="ObjectDisposedException">The connection is closed.</exception>
    private nint Handle
    {
        get
        {
            ObjectDisposedException.ThrowIf(_handle == 0, this);
            return _handle;
        }
    }

    /// <summary>
    /// Encodes text as null-terminated UTF-8, as SQLite takes it.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its bytes and a terminating zero.</returns>
    internal static byte[] Utf8z(string text)
    {
        var bytes = new byte[Encoding.UTF8.GetByteCount(text) + 1];
        Encoding.UTF8.GetBytes(text, bytes);
        return bytes;
    }

    /// <summary>
    /// Decodes a null-terminated UTF-8 string SQLite owns.
    /// </summary>
    /// <param name="text">The string.</param>
    /// <returns>The text, empty for a null pointer.</returns>
    private static string Utf8(byte* text) => text == null ? string.Empty : Encoding.UTF8.GetString(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(text));
}
