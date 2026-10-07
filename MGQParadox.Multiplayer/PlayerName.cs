//----------------------------------------------------------------
//  PlayerName.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System.Linq;

namespace MGQParadox.Multiplayer;

/// <summary>
/// What every player name the game script hands over goes through before it is sent on, in PvP battles and worlds alike.
/// </summary>
internal static class PlayerName
{
    /// <summary>
    /// Keeps a name short and on one line.
    /// </summary>
    /// <param name="name">The name, <see langword="null"/> for none.</param>
    /// <param name="maxLength">Longest name kept.</param>
    /// <returns>The name without control characters, trimmed and cut to <paramref name="maxLength"/>; empty for none.</returns>
    public static string Cleaned(string? name, int maxLength)
    {
        var cleaned = new string((name ?? string.Empty).Where(character => !char.IsControl(character)).ToArray()).Trim();

        return cleaned.Length <= maxLength ? cleaned : cleaned[..maxLength];
    }
}
