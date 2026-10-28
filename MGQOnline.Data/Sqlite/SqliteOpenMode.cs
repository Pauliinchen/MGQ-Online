//----------------------------------------------------------------
//  SqliteOpenMode.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Data.Sqlite;

/// <summary>
/// How <see cref="SqliteConnection.Open"/> opens a database.
/// </summary>
public enum SqliteOpenMode
{
    /// <summary>
    /// Reads an existing database and never writes it.
    /// </summary>
    ReadOnly,

    /// <summary>
    /// Reads and writes a database, creating its file when missing.
    /// </summary>
    ReadWriteCreate,
}
