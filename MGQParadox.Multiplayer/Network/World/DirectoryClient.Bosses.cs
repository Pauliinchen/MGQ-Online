//----------------------------------------------------------------
//  DirectoryClient.Bosses.cs
//
//  Changelog:
//      Paulinchen  2026-10-09: Created
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
    /// <returns>The pools, with what a pool never reported has.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached, the world is no Raid World, or the player may not read it.</exception>
    public BossList GetBosses(string world, string playerKey, string authKey)
    {
        using var document = SendStory(HttpMethod.Get, BossAddress(world, string.Empty), $"raid bosses {Log.Short(world)}", null, playerKey, authKey, null, out _);
        var root = document.RootElement;
        var pools = root.TryGetProperty("bosses", out var bosses) && bosses.ValueKind == JsonValueKind.Array
            ? bosses.EnumerateArray().Where(pool => pool.ValueKind == JsonValueKind.Object).Select(BossPool.Read).ToList()
            : [];

        return new BossList(pools, BossPool.Decimal(root, "max"), BossPool.Decimal(root, "regen"));
    }

    /// <summary>
    /// Reports how much of a boss's max HP a battle dealt, which the relay counts once per battle.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="authKey">The auth key made from the world's token.</param>
    /// <param name="boss">The boss's key.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="dealt">The share of the boss's max HP dealt, 0 or more; the relay counts at most 1.</param>
    /// <returns>The pool after the report, and how the report went.</returns>
    /// <exception cref="DirectoryException">The relay could not be reached or refused.</exception>
    public BossReport ReportBoss(string world, string playerKey, string authKey, string boss, string battle, double dealt)
    {
        var body = Json(writer =>
        {
            writer.WriteString("battle", battle);
            writer.WriteNumber("dealt", dealt);
        });

        using var document = SendStory(HttpMethod.Post, BossAddress(world, $"/{Uri.EscapeDataString(boss)}/report"), $"raid boss report {Log.Short(world)} battle {battle}", body, playerKey, authKey, null, out _);
        var root = document.RootElement;
        return new BossReport(BossPool.Read(root), BossPool.Decimal(root, "dealt"), BossPool.Flag(root, "emptied"), BossPool.Flag(root, "repeat"));
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
/// <param name="Max">A full pool, in kills, which a pool never reported has.</param>
/// <param name="Regen">The kills a pool fills up by per hour.</param>
internal sealed record BossList(IReadOnlyList<BossPool> Pools, double Max, double Regen);

/// <summary>
/// What the relay answered a boss report.
/// </summary>
/// <param name="Pool">The pool after the report.</param>
/// <param name="Dealt">The kills the report took off, 0 for a battle counted before or a boss already defeated.</param>
/// <param name="Emptied">Whether this battle's report emptied the pool, which defeats the boss for the world.</param>
/// <param name="Repeat">Whether the battle was counted before.</param>
internal sealed record BossReport(BossPool Pool, double Dealt, bool Emptied, bool Repeat);

/// <summary>
/// One boss's pool as the relay hands it out.
/// </summary>
/// <param name="Key">The boss's key, as the game script named it.</param>
/// <param name="Hp">The hit points left when the relay answered, in kills.</param>
/// <param name="Max">A full pool, in kills.</param>
/// <param name="Regen">The kills it fills up by per hour.</param>
/// <param name="Defeated">Whether a report emptied it, which defeats the boss for the world for good.</param>
internal sealed record BossPool(string Key, double Hp, double Max, double Regen, bool Defeated)
{
    /// <summary>
    /// Reads a pool of the relay's answer.
    /// </summary>
    /// <param name="element">The pool.</param>
    /// <returns>The pool.</returns>
    public static BossPool Read(JsonElement element) => new(
        element.TryGetProperty("key", out var key) && key.ValueKind == JsonValueKind.String ? key.GetString() ?? string.Empty : string.Empty,
        Decimal(element, "hp"),
        Decimal(element, "max"),
        Decimal(element, "regen"),
        Flag(element, "defeated"));

    /// <summary>
    /// Tells the hit points a while after the relay answered, filled up at the pool's rate, at most full.
    /// </summary>
    /// <param name="elapsed">How long ago the relay answered.</param>
    /// <returns>The hit points in kills; 0 for a defeated boss.</returns>
    public double HpAfter(TimeSpan elapsed) => Defeated ? 0 : Math.Min(Max, Hp + (Math.Max(0, elapsed.TotalHours) * Regen));

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
}
