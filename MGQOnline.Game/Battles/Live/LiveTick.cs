//----------------------------------------------------------------
//  LiveTick.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// What an ending check of the live battle found, see <see cref="LiveSession.Tick"/>.
/// </summary>
/// <param name="Ending">"forfeit", "broken" or "gone"; <see langword="null"/> while the battle goes on.</param>
/// <param name="Departed">The guests the check took out, each with the guests still in after them.</param>
/// <param name="Ask">Whether the battle's mode decides yet whether the other side is gone, see
/// <see cref="LiveSession.OtherSideGone"/>.</param>
/// <param name="Logs">The lines logged.</param>
public sealed record LiveTick(string? Ending, List<(int Seat, int StillIn)> Departed, bool Ask, List<LiveLogLine> Logs);
