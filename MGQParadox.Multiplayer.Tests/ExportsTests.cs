//----------------------------------------------------------------
//  ExportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Compared every export with the table of GameScript/Multiplayer.rb in one test
//      Paulinchen  2026-10-24: Covered mp_mod_browser_details
//                            - Covered the Mods screen's exports
//      Paulinchen  2026-10-23: Dropped the checks of the directory exports the world screen no longer calls
//                            - Dropped the parked mods' exports, whose work the bridge does
//                            - Covered the mp_memory_usage export
//      Paulinchen  2026-10-15: Expected the options of mp_dir_create in one number and no export past 16 arguments
//      Paulinchen  2026-10-13: Expected the raid bosses setting at the end of mp_dir_create and mp_dir_edit
//                            - Expected the squad settings at the end of mp_dir_create and mp_dir_edit
//      Paulinchen  2026-10-12: Covered the mp_mouse_wheel export
//      Paulinchen  2026-10-11: Covered the bug report exports
//      Paulinchen  2026-10-10: Covered the mp_dev_build export
//      Paulinchen  2026-10-09: Covered the parked mods' exports and the world exports that turn other mods off
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the buffers the exports hand texts to the game script in, and read its texts from, and
/// the names and arguments the game script calls exports by.
/// </summary>
public sealed unsafe class ExportsTests
{
    /// <summary>
    /// Asserts that a text whose bytes and terminating null fit is written, null-terminated, and its length returned.
    /// </summary>
    [Fact]
    public void Copy_ExactFit_WritesTheTextAndItsNull()
    {
        var bytes = Encoding.UTF8.GetBytes("アリス!");
        var buffer = new byte[bytes.Length + 1];
        buffer.AsSpan().Fill(0xFF);

        fixed (byte* target = buffer)
        {
            Assert.Equal(bytes.Length, Exports.Copy("アリス!", target, buffer.Length));
        }

        Assert.Equal(bytes, buffer[..bytes.Length]);
        Assert.Equal(0, buffer[^1]);
    }

    /// <summary>
    /// Asserts that a buffer without room for the terminating null gets nothing and the length needed is returned negated.
    /// </summary>
    [Fact]
    public void Copy_TooSmall_ReturnsTheNegatedLengthAndWritesNothing()
    {
        var buffer = new byte[3];
        buffer.AsSpan().Fill(0xFF);

        fixed (byte* target = buffer)
        {
            Assert.Equal(-3, Exports.Copy("abc", target, buffer.Length));
            Assert.Equal(-4, Exports.Copy("abcd", target, buffer.Length));
        }

        Assert.All(buffer, written => Assert.Equal(0xFF, written));
    }

    /// <summary>
    /// Asserts that a null buffer only asks how much room the text needs.
    /// </summary>
    [Fact]
    public void Copy_NullBuffer_ReturnsTheNegatedLength()
    {
        Assert.Equal(-5, Exports.Copy("hello", null, 100));
        Assert.Equal(0, Exports.Copy(string.Empty, null, 0));
    }

    /// <summary>
    /// Asserts that a text the game script hands over is read up to its null, and a null pointer as empty.
    /// </summary>
    [Fact]
    public void Text_ReadsUpToTheNull()
    {
        var bytes = Encoding.UTF8.GetBytes("ready\0ignored");

        fixed (byte* source = bytes)
        {
            Assert.Equal("ready", Exports.Text(source));
        }

        Assert.Equal(string.Empty, Exports.Text(null));
    }

    /// <summary>
    /// Asserts that every export takes the arguments the EXPORTS table of GameScript/Multiplayer.rb
    /// names for it and returns a long, and that none takes more than the 16 arguments the game's
    /// Win32API loads.
    /// </summary>
    [Fact]
    public void Exports_TakeWhatTheScriptsTableNames()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "GameScript", "Multiplayer.rb"));
        var readArguments = Regex.Match(source, "READ_ARGUMENTS = '([a-z]+)'").Groups[1].Value;
        var table = Regex.Matches(Regex.Match(source, @"    EXPORTS = \{.*?\n    \}", RegexOptions.Singleline).Value, "'(mp_[a-z0-9_]+)' => (?:'([a-z]+)'|READ_ARGUMENTS)")
            .ToDictionary(row => row.Groups[1].Value, row => !row.Groups[2].Success ? readArguments : row.Groups[2].Value == "v" ? string.Empty : row.Groups[2].Value);
        var exports = typeof(Exports).GetMethods(BindingFlags.Public | BindingFlags.Static)
            .Select(method => (Method: method, Attribute: method.GetCustomAttribute<UnmanagedCallersOnlyAttribute>()))
            .Where(export => export.Attribute?.EntryPoint != null)
            .ToArray();
        var exported = exports.ToDictionary(export => export.Attribute!.EntryPoint!, export => string.Concat(export.Method.GetParameters().Select(parameter => parameter.ParameterType == typeof(int) ? 'l' : 'p')));

        Assert.NotEmpty(table);
        Assert.Equal(table.OrderBy(row => row.Key), exported.OrderBy(row => row.Key));
        Assert.All(exports, export => Assert.Equal(typeof(int), export.Method.ReturnType));
        Assert.Empty(exported.Where(export => export.Value.Length > 16).Select(export => export.Key));
    }
}
