//----------------------------------------------------------------
//  SqliteConnectionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Tests.Sqlite;

/// <summary>
/// Covers the P/Invoke layer over SQLite on an in-memory database, in the 32-bit process the
/// game's DLL runs in.
/// </summary>
public sealed class SqliteConnectionTests
{
    /// <summary>
    /// Asserts that the tests run 32-bit and that a row written with bound values reads back with
    /// its integer, its text beyond ASCII, its empty text and its NULL.
    /// </summary>
    [Fact]
    public void Prepare_WritesAndReadsBackARowIn32Bit()
    {
        Assert.Equal(4, IntPtr.Size);
        using SqliteConnection connection = SqliteConnection.Open(SqliteConnection.InMemory, SqliteOpenMode.ReadWriteCreate);
        connection.Execute("CREATE TABLE switches(id INTEGER PRIMARY KEY, name TEXT, note TEXT, flag TEXT)");

        using (SqliteStatement insert = connection.Prepare("INSERT INTO switches VALUES(?, ?, ?, ?)"))
        {
            insert.Bind(1, 8001L);
            insert.Bind(2, "汎用スイッチ");
            insert.Bind(3, string.Empty);
            insert.Bind(4, null);
            Assert.False(insert.Step());
        }

        using SqliteStatement select = connection.Prepare("SELECT id, name, note, flag FROM switches");
        Assert.True(select.Step());
        Assert.Equal(4, select.ColumnCount);
        Assert.Equal(8001L, select.Int64(0));
        Assert.Equal("汎用スイッチ", select.Text(1));
        Assert.Equal(string.Empty, select.Text(2));
        Assert.True(select.IsNull(3));
        Assert.Null(select.Text(3));
        Assert.False(select.Step());
    }

    /// <summary>
    /// Asserts that preparing the same SQL again hands back the one statement, from its first row
    /// and with its parameters NULL, even when the earlier caller stopped halfway.
    /// </summary>
    [Fact]
    public void Prepare_HandsBackTheCachedStatementFromTheStart()
    {
        using SqliteConnection connection = SqliteConnection.Open(SqliteConnection.InMemory, SqliteOpenMode.ReadWriteCreate);
        connection.Execute("CREATE TABLE ids(id INTEGER); INSERT INTO ids VALUES(1), (2), (3);");
        const string sql = "SELECT id, ? FROM ids ORDER BY id";

        SqliteStatement first = connection.Prepare(sql);
        first.Bind(1, 7L);
        Assert.True(first.Step());
        Assert.True(first.Step());

        SqliteStatement again = connection.Prepare(sql);
        Assert.Same(first, again);
        Assert.True(again.Step());
        Assert.Equal(1L, again.Int64(0));
        Assert.True(again.IsNull(1));
    }

    /// <summary>
    /// Asserts that SQL SQLite refuses throws with SQLite's own message, and the connection
    /// still works after it.
    /// </summary>
    [Fact]
    public void Execute_ThrowsSqliteMessageForBadSql()
    {
        using SqliteConnection connection = SqliteConnection.Open(SqliteConnection.InMemory, SqliteOpenMode.ReadWriteCreate);

        SqliteException refused = Assert.Throws<SqliteException>(() => connection.Prepare("SELECT * FROM missing"));

        Assert.Equal(1, refused.Code);
        Assert.Contains("no such table: missing", refused.Message, StringComparison.Ordinal);
        connection.Execute("CREATE TABLE present(id INTEGER)");
    }

    /// <summary>
    /// Asserts that a read-only open of a file that does not exist is refused, not created.
    /// </summary>
    [Fact]
    public void Open_RefusesAMissingFileReadOnly()
    {
        string path = Path.Combine(Path.GetTempPath(), $"mgq-missing-{Guid.NewGuid():N}.db");

        Assert.Throws<SqliteException>(() => SqliteConnection.Open(path, SqliteOpenMode.ReadOnly));
        Assert.False(File.Exists(path));
    }
}
