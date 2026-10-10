//----------------------------------------------------------------
//  ExportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Covered mp_dev_build, exported without arguments
//      Paulinchen  2026-10-09: Covered the parked mods' exports and the world exports that take whether a world turns other mods off, with their arguments
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

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
    /// Asserts that the parked mods' functions, the world exports that take whether a world turns
    /// other mods off and mp_dev_build are exported under the names the game script calls, each
    /// taking what GameScript/Multiplayer.rb names for it.
    /// </summary>
    [Fact]
    public void ParkingExports_AreRegistered()
    {
        var exported = typeof(Exports).GetMethods(BindingFlags.Public | BindingFlags.Static)
            .Select(method => (Method: method, Attribute: method.GetCustomAttribute<UnmanagedCallersOnlyAttribute>()))
            .Where(export => export.Attribute?.EntryPoint != null)
            .ToDictionary(export => export.Attribute!.EntryPoint!, export => string.Concat(export.Method.GetParameters().Select(parameter => parameter.ParameterType == typeof(int) ? 'l' : 'p')));

        Assert.Equal("pp", exported["mp_mods_park"]);
        Assert.Equal("l", exported["mp_mods_restore"]);
        Assert.Equal("pl", exported["mp_mods_parked"]);
        Assert.Equal("pl", exported["mp_mods_scripts"]);
        Assert.Equal("pl", exported["mp_mods_restart_parked"]);
        Assert.Equal("p", exported["mp_mods_recover"]);
        Assert.Equal("pplllpppplppppll", exported["mp_dir_create"]);
        Assert.Equal("plppplllll", exported["mp_dir_edit"]);
        Assert.Equal(string.Empty, exported["mp_dev_build"]);
    }
}
