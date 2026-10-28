//----------------------------------------------------------------
//  SqliteStatement.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Text;

namespace MGQOnline.Data.Sqlite;

/// <summary>
/// A prepared SQL statement of a <see cref="SqliteConnection"/>: bind its parameters, step
/// through its rows and read their columns, then dispose of it to hand it back.
/// </summary>
/// <remarks>
/// Parameters count from 1 and columns from 0, as in SQLite's own API.
/// </remarks>
public sealed unsafe class SqliteStatement : IDisposable
{
    /// <summary>
    /// The connection that prepared it.
    /// </summary>
    private readonly SqliteConnection _connection;

    /// <summary>
    /// The native statement, 0 once released.
    /// </summary>
    private nint _handle;

    /// <summary>
    /// Wraps a native statement.
    /// </summary>
    /// <param name="connection">The connection that prepared it.</param>
    /// <param name="handle">The native statement.</param>
    internal SqliteStatement(SqliteConnection connection, nint handle)
    {
        _connection = connection;
        _handle = handle;
    }

    /// <summary>
    /// Gets how many columns the statement's rows have.
    /// </summary>
    public int ColumnCount => SqliteNative.ColumnCount(Handle);

    /// <summary>
    /// Gets the native statement.
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
    /// Binds an integer to a parameter.
    /// </summary>
    /// <param name="index">The parameter, from 1.</param>
    /// <param name="value">The value.</param>
    /// <exception cref="SqliteException">There is no such parameter.</exception>
    public void Bind(int index, long value) => _connection.Check(SqliteNative.BindInt64(Handle, index, value));

    /// <summary>
    /// Binds text to a parameter, or NULL for <see langword="null"/>.
    /// </summary>
    /// <param name="index">The parameter, from 1.</param>
    /// <param name="value">The text.</param>
    /// <exception cref="SqliteException">There is no such parameter.</exception>
    public void Bind(int index, string? value)
    {
        if (value == null)
        {
            _connection.Check(SqliteNative.BindNull(Handle, index));
            return;
        }

        // The terminator keeps the pointer of an empty text from being null, which binds NULL.
        byte[] bytes = SqliteConnection.Utf8z(value);
        fixed (byte* text = bytes)
        {
            _connection.Check(SqliteNative.BindText(Handle, index, text, bytes.Length - 1, SqliteNative.Transient));
        }
    }

    /// <summary>
    /// Runs the statement to its next row.
    /// </summary>
    /// <returns><see langword="true"/> with a row to read, <see langword="false"/> at the end.</returns>
    /// <exception cref="SqliteException">SQLite failed the statement.</exception>
    public bool Step()
    {
        int code = SqliteNative.Step(Handle);
        return code switch
        {
            SqliteNative.Row => true,
            SqliteNative.Done => false,
            _ => throw _connection.Failure(code),
        };
    }

    /// <summary>
    /// Tells whether a column of the current row is NULL.
    /// </summary>
    /// <param name="column">The column, from 0.</param>
    /// <returns><see langword="true"/> for NULL.</returns>
    public bool IsNull(int column) => SqliteNative.ColumnType(Handle, column) == SqliteNative.NullType;

    /// <summary>
    /// Reads a column of the current row as an integer.
    /// </summary>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The value, 0 for NULL.</returns>
    public long Int64(int column) => SqliteNative.ColumnInt64(Handle, column);

    /// <summary>
    /// Reads a column of the current row as text.
    /// </summary>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The text, <see langword="null"/> for NULL.</returns>
    public string? Text(int column)
    {
        nint handle = Handle;
        byte* text = SqliteNative.ColumnText(handle, column);
        return text == null ? null : Encoding.UTF8.GetString(text, SqliteNative.ColumnBytes(handle, column));
    }

    /// <summary>
    /// Hands the statement back to its connection: resets it to before its first step and sets
    /// every parameter back to NULL. Calling it again does nothing harmful.
    /// </summary>
    public void Dispose()
    {
        if (_handle == 0)
        {
            return;
        }

        SqliteNative.Reset(_handle);
        SqliteNative.ClearBindings(_handle);
    }

    /// <summary>
    /// Deletes the native statement, as its connection closes.
    /// </summary>
    internal void Release()
    {
        SqliteNative.Finalize(_handle);
        _handle = 0;
    }
}
