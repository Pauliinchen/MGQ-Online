//----------------------------------------------------------------
//  DebrisTypes.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Debris;

/// <summary>
/// The resolved style of new debris: its type, its hits, its cover and its look.
/// </summary>
/// <param name="Type">The debris type id, or null for plain debris.</param>
/// <param name="Hits">The hits that break each cell, 0 unbreakable.</param>
/// <param name="Cover">Whether its cells shield the cells behind them from waves.</param>
/// <param name="Look">Its look, or null for the battle map's debris tile.</param>
public sealed record DebrisStyle(string? Type, int Hits, bool Cover, DebrisLook? Look)
{
    /// <summary>
    /// Gets the plain built-in style: unbreakable, giving cover, with the battle map's look.
    /// </summary>
    public static DebrisStyle Plain { get; } = new(null, 0, true, null);

    /// <summary>
    /// Applies a skill's or an effect's own hits over the type's.
    /// </summary>
    /// <param name="hits">The own hits, or null to keep the type's.</param>
    /// <returns>The style with the hits that win.</returns>
    public DebrisStyle WithHits(int? hits) => hits is int own ? this with { Hits = own } : this;
}

/// <summary>
/// Resolves which debris type new debris takes: its own, else its battle map's, else the game rule's standard one.
/// </summary>
public static class DebrisTypes
{
    /// <summary>
    /// Resolves the style of debris on a battle map.
    /// </summary>
    /// <param name="design">The design.</param>
    /// <param name="mapId">The battle map's id.</param>
    /// <param name="own">The skill's, effect's or boss's own type id, or null.</param>
    /// <returns>The style; the plain one for an unknown or missing type.</returns>
    public static DebrisStyle For(RuntimeDesign design, int mapId, string? own = null)
    {
        ArgumentNullException.ThrowIfNull(design);
        return Resolve(design.DebrisTypes, own, design.Maps.GetValueOrDefault(mapId)?.DebrisType, design.Rules.Debris.Standard);
    }

    /// <summary>
    /// Resolves a style by the first type id set.
    /// </summary>
    /// <param name="types">The design's debris types, or null for none.</param>
    /// <param name="own">The own type id, or null.</param>
    /// <param name="map">The battle map's type id, or null.</param>
    /// <param name="standard">The game rule's standard type id, or null.</param>
    /// <returns>The style; the plain one when the id that applies is unknown or none is set.</returns>
    public static DebrisStyle Resolve(IReadOnlyDictionary<string, RuntimeDebrisType>? types, string? own, string? map, string? standard)
    {
        string? id = own ?? map ?? standard;
        return id is not null && types?.GetValueOrDefault(id) is RuntimeDebrisType type
            ? new DebrisStyle(id, Math.Max(type.Hits, 0), type.Cover, type.Look)
            : DebrisStyle.Plain;
    }
}
