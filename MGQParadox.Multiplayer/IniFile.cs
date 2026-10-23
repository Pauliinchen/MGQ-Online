//----------------------------------------------------------------
//  IniFile.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer;

/// <summary>
/// Files of key=value lines, such as Patch\Multiplayer\Player.ini and a world's world.ini, read and written as the game scripts did, so
/// files they wrote keep working.
/// </summary>
internal static class IniFile
{
    /// <summary>
    /// What a file is written to first, next to it, before it replaces the file.
    /// </summary>
    internal const string TempSuffix = ".tmp";

    /// <summary>
    /// What a value's line breaks are written as, since each value keeps to its line.
    /// </summary>
    private const char LineBreakStandIn = ' ';

    /// <summary>
    /// What Ruby's <c>strip</c> took off both ends of a key and a value: NUL and ASCII white space.
    /// </summary>
    private static readonly char[] Stripped = ['\0', '\t', '\n', '\v', '\f', '\r', ' '];

    /// <summary>
    /// UTF-8 that refuses bytes outside it, so a file saved as ANSI is told apart.
    /// </summary>
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    /// <summary>
    /// UTF-8 without a byte order mark, as files are written.
    /// </summary>
    private static readonly UTF8Encoding PlainUtf8 = new(false);

    /// <summary>
    /// Reads a file, telling one that could not be read from one that is missing.
    /// </summary>
    /// <param name="path">The file's full path.</param>
    /// <param name="shown">How the log names it.</param>
    /// <param name="quiet">Whether a file that could not be read goes unlogged, as when it failed just before.</param>
    /// <returns>The values by key in the file's order, empty when the file is missing; <see langword="null"/> when it exists but could not be read.</returns>
    public static OrderedDictionary<string, string>? Load(string path, string shown, bool quiet)
    {
        try
        {
            if (!Path.Exists(path))
            {
                return new OrderedDictionary<string, string>(StringComparer.Ordinal);
            }

            using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            var bytes = new byte[file.Length];
            file.ReadExactly(bytes);
            return Parse(bytes);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            if (!quiet)
            {
                Log.Write($"could not read {shown}: {ex.GetType().Name}: {ex.Message}");
            }

            return null;
        }
    }

    /// <summary>
    /// Writes a file, replacing it in one step: the values go to a file next to it first, which then takes its place, so a crash or a full
    /// disk never leaves it half written.
    /// </summary>
    /// <param name="path">The file's full path.</param>
    /// <param name="shown">How the log names it.</param>
    /// <param name="values">The values by key, each kept on its line.</param>
    /// <returns>Whether the file was written.</returns>
    public static bool Write(string path, string shown, IEnumerable<KeyValuePair<string, string>> values)
    {
        var temp = path + TempSuffix;

        try
        {
            using (var file = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                file.Write(Format(values));
                file.Flush(true);
            }

            // Deleting the file first would leave none behind a crash between the two steps, so the move replaces it.
            File.Move(temp, path, true);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            TryDelete(temp);
            Log.Write($"could not write {shown}: {ex.GetType().Name}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Reads a file's key=value lines; a line without "=" is left out, and a key that comes again keeps its first place and takes the last value.
    /// </summary>
    /// <param name="bytes">The file's bytes.</param>
    /// <returns>The values by key in the file's order.</returns>
    internal static OrderedDictionary<string, string> Parse(ReadOnlySpan<byte> bytes)
    {
        var values = new OrderedDictionary<string, string>(StringComparer.Ordinal);

        foreach (var line in TextOf(bytes).Split('\n'))
        {
            var separator = line.IndexOf('=', StringComparison.Ordinal);

            if (separator >= 0)
            {
                values[line[..separator].Trim(Stripped)] = line[(separator + 1)..].Trim(Stripped);
            }
        }

        return values;
    }

    /// <summary>
    /// Writes the lines of a file.
    /// </summary>
    /// <param name="values">The values by key.</param>
    /// <returns>The file's bytes: UTF-8 without a byte order mark, each value on one line.</returns>
    internal static byte[] Format(IEnumerable<KeyValuePair<string, string>> values)
    {
        var text = new StringBuilder();

        foreach (var (key, value) in values)
        {
            text.Append(key).Append('=').Append(value.Replace('\r', LineBreakStandIn).Replace('\n', LineBreakStandIn)).Append('\n');
        }

        return PlainUtf8.GetBytes(text.ToString());
    }

    /// <summary>
    /// Turns a file's bytes into text: UTF-16 by its byte order mark, UTF-8 without its byte order mark, and anything else as Latin-1, such
    /// as a file Notepad saved as ANSI.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The text.</returns>
    internal static string TextOf(ReadOnlySpan<byte> bytes)
    {
        if (bytes.StartsWith((ReadOnlySpan<byte>)[0xFF, 0xFE]))
        {
            return Utf16(bytes[2..], true);
        }

        if (bytes.StartsWith((ReadOnlySpan<byte>)[0xFE, 0xFF]))
        {
            return Utf16(bytes[2..], false);
        }

        if (bytes.StartsWith((ReadOnlySpan<byte>)[0xEF, 0xBB, 0xBF]))
        {
            bytes = bytes[3..];
        }

        try
        {
            return StrictUtf8.GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            return Encoding.Latin1.GetString(bytes);
        }
    }

    /// <summary>
    /// Turns UTF-16 bytes into text, joining surrogate pairs.
    /// </summary>
    /// <param name="bytes">The bytes after the byte order mark; an odd last byte is left out.</param>
    /// <param name="littleEndian">Whether each code unit's low byte comes first.</param>
    /// <returns>The text, a lone surrogate replaced by U+FFFD.</returns>
    private static string Utf16(ReadOnlySpan<byte> bytes, bool littleEndian)
    {
        var units = new char[bytes.Length / 2];

        for (var index = 0; index < units.Length; index++)
        {
            var (low, high) = littleEndian ? (bytes[2 * index], bytes[(2 * index) + 1]) : (bytes[(2 * index) + 1], bytes[2 * index]);
            units[index] = (char)(low | (high << 8));
        }

        var text = new StringBuilder(units.Length);

        for (var index = 0; index < units.Length; index++)
        {
            if (char.IsHighSurrogate(units[index]) && index + 1 < units.Length && char.IsLowSurrogate(units[index + 1]))
            {
                text.Append(units[index]).Append(units[index + 1]);
                index++;
            }
            else
            {
                text.Append(char.IsSurrogate(units[index]) ? '�' : units[index]);
            }
        }

        return text.ToString();
    }

    /// <summary>
    /// Deletes a file that may not be there.
    /// </summary>
    /// <param name="path">The file.</param>
    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
        }
    }
}
