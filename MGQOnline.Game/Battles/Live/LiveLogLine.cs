//----------------------------------------------------------------
//  LiveLogLine.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// A line the live battle's rules ask battles_sync.rbx to log under its tag, so the log reads as
/// when the rules were the script's own.
/// </summary>
/// <param name="Key">What tells a line logged once per game from the script's other lines, such as
/// "audio_args\tse_play"; <see langword="null"/> for a line logged every time.</param>
/// <param name="Text">The line.</param>
public sealed record LiveLogLine(string? Key, string Text);
