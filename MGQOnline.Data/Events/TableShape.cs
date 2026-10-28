//----------------------------------------------------------------
//  TableShape.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Events;

/// <summary>
/// How one table's rows are written and read: its columns, the order its rows are written in, and
/// one write and one read that take the columns in the same order.
/// </summary>
/// <typeparam name="T">The row.</typeparam>
/// <param name="Name">The table.</param>
/// <param name="Columns">Its columns, in the order the write and the read take them.</param>
/// <param name="Key">The row's key, which orders the rows written.</param>
/// <param name="Write">Binds a row's columns.</param>
/// <param name="Read">Reads a row from its columns.</param>
internal sealed record TableShape<T>(
    string Name,
    string[] Columns,
    Func<T, IComparable> Key,
    Action<RowWriter, T> Write,
    Func<RowReader, T> Read)
{
    /// <summary>
    /// Gets the SQL that inserts one row.
    /// </summary>
    public string InsertSql { get; } = $"INSERT INTO {Name}({string.Join(", ", Columns)}) VALUES({string.Join(", ", Array.ConvertAll(Columns, _ => "?"))})";

    /// <summary>
    /// Gets the start of a SELECT of every column, to which a WHERE and an ORDER BY are added.
    /// </summary>
    public string SelectSql { get; } = $"SELECT {string.Join(", ", Columns)} FROM {Name}";
}

/// <summary>
/// Binds a row's columns to an INSERT, one after the other.
/// </summary>
/// <param name="statement">The INSERT.</param>
internal sealed class RowWriter(SqliteStatement statement)
{
    /// <summary>
    /// The parameter the next column binds, from 1.
    /// </summary>
    private int _next = 1;

    /// <summary>
    /// Binds a whole number.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The writer, for the next column.</returns>
    public RowWriter Int(long value)
    {
        statement.Bind(_next++, value);
        return this;
    }

    /// <summary>
    /// Binds a whole number or NULL.
    /// </summary>
    /// <param name="value">The value, <see langword="null"/> for NULL.</param>
    /// <returns>The writer, for the next column.</returns>
    public RowWriter Int(long? value)
    {
        if (value is { } number)
        {
            statement.Bind(_next++, number);
        }
        else
        {
            statement.Bind(_next++, (string?)null);
        }

        return this;
    }

    /// <summary>
    /// Binds a flag as 1 or 0.
    /// </summary>
    /// <param name="value">The flag.</param>
    /// <returns>The writer, for the next column.</returns>
    public RowWriter Flag(bool value) => Int(value ? 1L : 0L);

    /// <summary>
    /// Binds a flag as 1 or 0, or NULL.
    /// </summary>
    /// <param name="value">The flag, <see langword="null"/> for NULL.</param>
    /// <returns>The writer, for the next column.</returns>
    public RowWriter Flag(bool? value) => Int(value is { } flag ? (flag ? 1L : 0L) : null);

    /// <summary>
    /// Binds text or NULL.
    /// </summary>
    /// <param name="value">The text, <see langword="null"/> for NULL.</param>
    /// <returns>The writer, for the next column.</returns>
    public RowWriter Text(string? value)
    {
        statement.Bind(_next++, value);
        return this;
    }
}

/// <summary>
/// Reads the columns of a SELECT's current row, one after the other.
/// </summary>
/// <param name="statement">The SELECT, on a row.</param>
internal sealed class RowReader(SqliteStatement statement)
{
    /// <summary>
    /// The column the next read takes, from 0.
    /// </summary>
    private int _next;

    /// <summary>
    /// Reads a whole number that fits 32 bits.
    /// </summary>
    /// <returns>The value, 0 for NULL.</returns>
    public int Int() => checked((int)statement.Int64(_next++));

    /// <summary>
    /// Reads a whole number that fits 32 bits, or NULL.
    /// </summary>
    /// <returns>The value, <see langword="null"/> for NULL.</returns>
    public int? IntOrNull() => statement.IsNull(_next) ? Skip<int>() : Int();

    /// <summary>
    /// Reads a whole number.
    /// </summary>
    /// <returns>The value, 0 for NULL.</returns>
    public long Long() => statement.Int64(_next++);

    /// <summary>
    /// Reads a flag.
    /// </summary>
    /// <returns>Whether the column is not 0.</returns>
    public bool Flag() => statement.Int64(_next++) != 0;

    /// <summary>
    /// Reads a flag, or NULL.
    /// </summary>
    /// <returns>Whether the column is not 0, <see langword="null"/> for NULL.</returns>
    public bool? FlagOrNull() => statement.IsNull(_next) ? Skip<bool>() : Flag();

    /// <summary>
    /// Reads text.
    /// </summary>
    /// <returns>The text, <see langword="null"/> for NULL.</returns>
    public string? Text() => statement.Text(_next++);

    /// <summary>
    /// Reads text the table never leaves NULL.
    /// </summary>
    /// <returns>The text.</returns>
    public string TextNotNull() => statement.Text(_next++) ?? string.Empty;

    /// <summary>
    /// Passes a NULL column.
    /// </summary>
    /// <typeparam name="TValue">The column's type.</typeparam>
    /// <returns><see langword="null"/>.</returns>
    private TValue? Skip<TValue>()
        where TValue : struct
    {
        _next++;
        return null;
    }
}
