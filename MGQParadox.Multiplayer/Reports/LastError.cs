//----------------------------------------------------------------
//  LastError.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Reports;

/// <summary>
/// Tells where the newest error the game wrote into <c>errors.txt</c> was raised, by the top line of
/// its trace: in a script of MGQ Online, in a script of the Patch folder such as another mod, or in
/// the game, for a public fact of a bug report.
/// </summary>
internal static partial class LastError
{
    /// <summary>
    /// The fact's label.
    /// </summary>
    public const string Label = "Last error";

    /// <summary>
    /// What the game writes before each error in <c>errors.txt</c>.
    /// </summary>
    private const string EntryStart = "*Error - ";

    /// <summary>
    /// The line before an error's trace in <c>errors.txt</c>.
    /// </summary>
    private const string TraceLine = "trace:";

    /// <summary>
    /// What a trace line starts with for code the Patch folder's loader ran, which names no file.
    /// </summary>
    private const string EvalFrame = "(eval)";

    /// <summary>
    /// Bytes of the end of <c>errors.txt</c> read, which hold the newest error with its trace.
    /// </summary>
    /// <remarks>
    /// The file keeps every error the game ever wrote.
    /// </remarks>
    private const int TailBytes = 1024 * 1024;

    /// <summary>
    /// Describes where the newest error of <c>errors.txt</c> in a game folder was raised, for a report
    /// that attaches the file.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <param name="since">The file counts when written at or after it, in UTC, as <see cref="ReportFiles.Build"/> attaches it.</param>
    /// <returns>The fact, <see langword="null"/> without a file written since then or without a trace to read.</returns>
    public static ReportFact? FactOf(string gameFolder, DateTime since)
    {
        var path = Path.Combine(gameFolder, ReportFiles.ErrorsFile);

        if (!File.Exists(path) || File.GetLastWriteTimeUtc(path) < since)
        {
            return null;
        }

        return PlaceOf(Tail(path)) is { } place ? new ReportFact(Label, place) : null;
    }

    /// <summary>
    /// Describes where the newest error of a text of <c>errors.txt</c> was raised.
    /// </summary>
    /// <param name="errors">The text, or its end.</param>
    /// <returns>Such as <c>raised in MGQ Online (battles_pvp.rbx)</c>; <see langword="null"/> without an error with a trace.</returns>
    internal static string? PlaceOf(string errors)
    {
        var start = errors.LastIndexOf(EntryStart, StringComparison.Ordinal);
        var lines = (start < 0 ? string.Empty : errors[start..]).Replace("\r\n", "\n").Split('\n');
        var trace = Array.IndexOf(lines, TraceLine);

        if (trace < 0 || trace + 1 >= lines.Length || FirstFrame().Match(lines[trace + 1]) is not { Success: true } first)
        {
            return null;
        }

        var frame = first.Groups["frame"].Value.Replace(@"\\", @"\");

        if (OwnScript().Match(frame) is { Success: true } script)
        {
            return $"raised in MGQ Online ({script.Groups["script"].Value})";
        }

        if (frame.StartsWith(EvalFrame, StringComparison.Ordinal))
        {
            return "raised in a Patch folder script, such as another mod";
        }

        return GameSection().Match(frame) is { Success: true } section ? $"raised in the game ({section.Groups["section"].Value})" : "raised in the game";
    }

    /// <summary>
    /// Reads the end of a file, which the game may write meanwhile.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Its last <see cref="TailBytes"/> bytes as UTF-8.</returns>
    private static string Tail(string path)
    {
        using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var length = (int)Math.Min(file.Length, TailBytes);
        file.Seek(-length, SeekOrigin.End);
        var bytes = new byte[length];
        file.ReadExactly(bytes);
        return Encoding.UTF8.GetString(bytes);
    }

    /// <summary>
    /// The first line of a trace as the game writes it, a Ruby array of quoted lines.
    /// </summary>
    /// <returns>The pattern, whose group <c>frame</c> holds the line with its escapes.</returns>
    [GeneratedRegex(@"^\[""(?<frame>(?:[^""\\]|\\.)*)""", RegexOptions.CultureInvariant)]
    private static partial Regex FirstFrame();

    /// <summary>
    /// A line of a script of MGQ Online, such as <c>Patch\Multiplayer\Scripts\battles_pvp.rbx:328</c>.
    /// </summary>
    /// <returns>The pattern, whose group <c>script</c> holds the script's file name.</returns>
    [GeneratedRegex(@"Multiplayer[\\/]Scripts[\\/](?<script>[^\\/:]+\.rbx):\d+", RegexOptions.CultureInvariant)]
    private static partial Regex OwnScript();

    /// <summary>
    /// A line of a section of the game's scripts, such as <c>( Scene_Battle )：48</c>.
    /// </summary>
    /// <returns>The pattern, whose group <c>section</c> holds the section's name.</returns>
    [GeneratedRegex(@"^\( (?<section>.+?) \)：", RegexOptions.CultureInvariant)]
    private static partial Regex GameSection();
}
