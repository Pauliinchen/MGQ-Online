//----------------------------------------------------------------
//  DirectoryClient.Bosses.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Read a boss pool as the share of its raid max HP left, the raid max HP and who defeated it, and reported a battle's turn as its sequence number, the share lost, the raid max HP and whether the boss died
//      Paulinchen  2026-10-09: Sent boss requests with the timeout of other requests, and logged the fetch of the pools only when its outcome changed or it was slow
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The routes of a Raid World's boss pools at the relay, see docs/DEVELOPER.md, "Raid boss pools on the relay".
/// </summary>
internal sealed partial class DirectoryClient
{
    /// <summary>
    /// Fetches every boss pool of a Raid World that a report touched.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <returns>The pools, with the share of a raid max HP they fill up by per minute when the relay names it.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, the world is no Raid World, or the player may not read it.</exception>
    public BossList GetBosses(string world, string playerKey, string authKey)
    {
        using var document = SendStory(HttpMethod.Get, BossAddress(world, string.Empty), $"raid bosses {Log.Short(world)}", null, playerKey, authKey, null, out _, Http, $"raid bosses {world}");
        var root = document.RootElement;
        var pools = root.TryGetProperty("bosses", out var bosses) && bosses.ValueKind == JsonValueKind.Array
            ? bosses.EnumerateArray().Where(pool => pool.ValueKind == JsonValueKind.Object).Select(BossPool.Read).ToList()
            : [];
        var regen = BossPool.Decimal(root, "regenPerMinute");

        return new BossList(pools, regen is > 0 and <= 1 ? regen : null);
    }

    /// <summary>
    /// Reports what a battle's turn did to a boss's pool; the relay takes each sequence number of a battle once.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="boss">The pool's key.</param>
    /// <param name="turn">What the turn did.</param>
    /// <returns>The pool after the report, and whether the relay took this sequence number before.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public BossReport ReportBoss(string world, string playerKey, string authKey, string boss, BossTurn turn)
    {
        var body = Json(writer =>
        {
            writer.WriteString("battle", turn.Battle);
            writer.WriteNumber("seq", turn.Seq);
            writer.WriteNumber("delta", turn.Delta);
            writer.WriteNumber("max", turn.Max);
            writer.WriteBoolean("killed", turn.Killed);
        });

        // A small request: a hung relay must free the queue within seconds, not the minutes a story may take.
        using var document = SendStory(HttpMethod.Post, BossAddress(world, $"/{Uri.EscapeDataString(boss)}/report"), $"raid boss report {Log.Short(world)} battle {turn.Battle} seq {turn.Seq}", body, playerKey, authKey, null, out _, Http);
        var root = document.RootElement;
        var pool = root.TryGetProperty("boss", out var inner) && inner.ValueKind == JsonValueKind.Object ? inner : root;
        return new BossReport(BossPool.Read(pool), BossPool.Flag(root, "repeat"));
    }

    /// <summary>
    /// Builds the address of one of a world's boss routes.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="rest">What follows <c>/bosses</c>, empty for every pool.</param>
    /// <returns>The address.</returns>
    private Uri BossAddress(string world, string rest) => new($"{_worlds}/{Uri.EscapeDataString(world)}/bosses{rest}");
}

/// <summary>
/// A Raid World's boss pools as the relay hands them out.
/// </summary>
/// <param name="Pools">The pools a report touched.</param>
/// <param name="RegenPerMinute">The share of a raid max HP every pool fills up by per minute, <see langword="null"/> when the relay did not name it.</param>
internal sealed record BossList(IReadOnlyList<BossPool> Pools, double? RegenPerMinute);

/// <summary>
/// What one turn of a battle did to a boss's pool, as the game script reports it.
/// </summary>
/// <param name="Battle">The battle's id.</param>
/// <param name="Seq">The report's number in its battle, which grows with each report.</param>
/// <param name="Delta">The share of the pool's raid max HP lost since the battle's last report; healing makes it negative.</param>
/// <param name="Max">The raid max HP the game fights, which the relay keeps only for a pool that has none yet.</param>
/// <param name="Killed">Whether the boss died in the battle, which defeats it for the world.</param>
internal sealed record BossTurn(string Battle, long Seq, double Delta, double Max, bool Killed);

/// <summary>
/// What the relay answered a boss report.
/// </summary>
/// <param name="Pool">The pool after the report.</param>
/// <param name="Repeat">Whether the relay took the report's sequence number before and changed nothing.</param>
internal sealed record BossReport(BossPool Pool, bool Repeat);

/// <summary>
/// One boss's pool as the relay hands it out.
/// </summary>
/// <param name="Key">The pool's key, as the game script named it.</param>
/// <param name="Left">The share of the raid max HP left when the relay answered, 0 to 1.</param>
/// <param name="Max">The raid max HP, as the first report named it.</param>
/// <param name="Defeated">Whether the boss died, which defeats it for the world until an admin resets it.</param>
/// <param name="By">The name of the player who defeated it, empty while it stands or when the relay did not say.</param>
internal sealed record BossPool(string Key, double Left, double Max, bool Defeated, string By)
{
    /// <summary>
    /// Reads a pool of the relay's answer.
    /// </summary>
    /// <param name="element">The pool.</param>
    /// <returns>The pool.</returns>
    public static BossPool Read(JsonElement element)
    {
        var defeated = Flag(element, "defeated");
        var by = !defeated ? string.Empty : Text(element, "defeatedBy") is { Length: > 0 } defeater ? defeater : Text(element, "by");
        return new BossPool(Text(element, "key"), defeated ? 0 : Math.Clamp(Decimal(element, "left"), 0, 1), Math.Max(0, Decimal(element, "max")), defeated, by);
    }

    /// <summary>
    /// Tells the share left a while after the relay answered, filled up at a rate, at most full.
    /// </summary>
    /// <param name="elapsed">How long ago the relay answered.</param>
    /// <param name="regenPerMinute">The share it fills up by per minute.</param>
    /// <returns>The share left, 0 to 1; 0 for a defeated boss.</returns>
    public double LeftAfter(TimeSpan elapsed, double regenPerMinute) =>
        Defeated ? 0 : Math.Min(1, Left + (Math.Max(0, elapsed.TotalMinutes) * regenPerMinute));

    /// <summary>
    /// Reads a number of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The number; 0 when it is missing.</returns>
    public static double Decimal(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) && double.IsFinite(number) ? number : 0;

    /// <summary>
    /// Reads a true or false of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>Whether it is true; false when it is missing.</returns>
    public static bool Flag(JsonElement element, string name) => element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Reads a text of the answer.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The text; empty when it is missing.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
}
