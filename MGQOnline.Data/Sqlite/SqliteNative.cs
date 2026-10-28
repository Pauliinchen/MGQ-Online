//----------------------------------------------------------------
//  SqliteNative.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named the results of a damaged file and of one that is no database
//                            - Created
//
//----------------------------------------------------------------

using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MGQOnline.Data.Sqlite;

/// <summary>
/// The SQLite functions the reader and the writer call, by the C API's names and signatures.
/// </summary>
/// <remarks>
/// The NativeAOT hosts bind <see cref="Library"/> at link time to the static library built from
/// the checked-in amalgamation; a JIT host loads the e_sqlite3 library of SQLitePCLRaw.lib.e_sqlite3.
/// </remarks>
internal static unsafe partial class SqliteNative
{
    /// <summary>
    /// The library name every import names, which the NativeAOT hosts list as a DirectPInvoke.
    /// </summary>
    public const string Library = "e_sqlite3";

    /// <summary>
    /// The result of a call that succeeded.
    /// </summary>
    public const int Ok = 0;

    /// <summary>
    /// The result of a step that produced a row.
    /// </summary>
    public const int Row = 100;

    /// <summary>
    /// The result of a step that finished the statement.
    /// </summary>
    public const int Done = 101;

    /// <summary>
    /// The result of a call that found the database file damaged.
    /// </summary>
    public const int Corrupt = 11;

    /// <summary>
    /// The result of a call that found the file is no database.
    /// </summary>
    public const int NotADatabase = 26;

    /// <summary>
    /// The open flag for a read-only connection.
    /// </summary>
    public const int OpenReadOnly = 0x00000001;

    /// <summary>
    /// The open flag for a connection that may write.
    /// </summary>
    public const int OpenReadWrite = 0x00000002;

    /// <summary>
    /// The open flag that creates a missing database file.
    /// </summary>
    public const int OpenCreate = 0x00000004;

    /// <summary>
    /// The open flag that reads a file name starting with "file:" as a URI.
    /// </summary>
    public const int OpenUri = 0x00000040;

    /// <summary>
    /// The column type of a NULL value.
    /// </summary>
    public const int NullType = 5;

    /// <summary>
    /// The destructor value that makes SQLite copy bound text before the call returns.
    /// </summary>
    public static readonly nint Transient = -1;

    /// <summary>
    /// Gets the library version, such as "3.54.1".
    /// </summary>
    /// <returns>A null-terminated UTF-8 string SQLite owns.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_libversion")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial byte* LibraryVersion();

    /// <summary>
    /// Opens a database connection.
    /// </summary>
    /// <param name="fileName">The null-terminated UTF-8 file name or URI.</param>
    /// <param name="db">The connection, set even when the open fails.</param>
    /// <param name="flags">The open flags.</param>
    /// <param name="vfs">The VFS's name, or null for the default.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_open_v2")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Open(byte* fileName, out nint db, int flags, byte* vfs);

    /// <summary>
    /// Closes a connection once its last statement is finalized.
    /// </summary>
    /// <param name="db">The connection.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_close_v2")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Close(nint db);

    /// <summary>
    /// Gets the message of the connection's last failed call.
    /// </summary>
    /// <param name="db">The connection.</param>
    /// <returns>A null-terminated UTF-8 string SQLite owns.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_errmsg")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial byte* ErrorMessage(nint db);

    /// <summary>
    /// Runs SQL statements without reading their rows.
    /// </summary>
    /// <param name="db">The connection.</param>
    /// <param name="sql">The null-terminated UTF-8 SQL.</param>
    /// <param name="callback">A row callback, always 0 here.</param>
    /// <param name="argument">The callback's argument, always 0 here.</param>
    /// <param name="errorMessage">Where to put an error message, always 0 here.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_exec")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Execute(nint db, byte* sql, nint callback, nint argument, nint errorMessage);

    /// <summary>
    /// Compiles the first SQL statement of a text.
    /// </summary>
    /// <param name="db">The connection.</param>
    /// <param name="sql">The null-terminated UTF-8 SQL.</param>
    /// <param name="bytes">The SQL's length in bytes, or -1 up to its terminator.</param>
    /// <param name="statement">The statement, 0 when the SQL holds none.</param>
    /// <param name="tail">Where to put the rest of the SQL, always 0 here.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_prepare_v2")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Prepare(nint db, byte* sql, int bytes, out nint statement, nint tail);

    /// <summary>
    /// Binds an integer to a parameter.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="index">The parameter, from 1.</param>
    /// <param name="value">The value.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_bind_int64")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int BindInt64(nint statement, int index, long value);

    /// <summary>
    /// Binds UTF-8 text to a parameter.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="index">The parameter, from 1.</param>
    /// <param name="text">The text; a null pointer would bind NULL.</param>
    /// <param name="bytes">The text's length in bytes.</param>
    /// <param name="destructor"><see cref="Transient"/>, so SQLite keeps a copy.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_bind_text")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int BindText(nint statement, int index, byte* text, int bytes, nint destructor);

    /// <summary>
    /// Binds NULL to a parameter.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="index">The parameter, from 1.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_bind_null")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int BindNull(nint statement, int index);

    /// <summary>
    /// Runs a statement to its next row or its end.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <returns><see cref="Row"/>, <see cref="Done"/> or an error code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_step")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Step(nint statement);

    /// <summary>
    /// Puts a statement back to before its first step, keeping its bindings.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <returns>The result code of its last step.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_reset")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Reset(nint statement);

    /// <summary>
    /// Sets every parameter of a statement back to NULL.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <returns>The result code.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_clear_bindings")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int ClearBindings(nint statement);

    /// <summary>
    /// Deletes a statement.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <returns>The result code of its last step.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_finalize")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int Finalize(nint statement);

    /// <summary>
    /// Gets how many columns a statement's rows have.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <returns>The column count.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_column_count")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int ColumnCount(nint statement);

    /// <summary>
    /// Gets the type of a column of the current row.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The type, such as <see cref="NullType"/>.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_column_type")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int ColumnType(nint statement, int column);

    /// <summary>
    /// Gets a column of the current row as an integer.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The value, 0 for NULL.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_column_int64")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial long ColumnInt64(nint statement, int column);

    /// <summary>
    /// Gets a column of the current row as UTF-8 text.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The text, which SQLite owns until the next step; a null pointer for NULL.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_column_text")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial byte* ColumnText(nint statement, int column);

    /// <summary>
    /// Gets the length in bytes of the text <see cref="ColumnText"/> gave.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The length, without the terminator.</returns>
    [LibraryImport(Library, EntryPoint = "sqlite3_column_bytes")]
    [UnmanagedCallConv(CallConvs = [typeof(CallConvCdecl)])]
    public static partial int ColumnBytes(nint statement, int column);
}
