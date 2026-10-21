//----------------------------------------------------------------
//  GridValues.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A cell of the arena grid, or an offset between two cells; JSON <c>[x, y]</c>.
/// </summary>
/// <param name="X">The column, 0 at the left.</param>
/// <param name="Y">The row, 0 at the front nearest the boss.</param>
[JsonConverter(typeof(GridCellJsonConverter))]
public readonly record struct GridCell(int X, int Y);

/// <summary>
/// The size of an arena grid; JSON <c>[cols, rows]</c>.
/// </summary>
/// <param name="Cols">The columns.</param>
/// <param name="Rows">The rows.</param>
[JsonConverter(typeof(GridSizeJsonConverter))]
public readonly record struct GridSize(int Cols, int Rows);

/// <summary>
/// A colour with alpha; JSON <c>[r, g, b, a]</c>, each from 0 to 255.
/// </summary>
/// <param name="R">The red part.</param>
/// <param name="G">The green part.</param>
/// <param name="B">The blue part.</param>
/// <param name="A">The opacity, 255 opaque.</param>
[JsonConverter(typeof(ColorRgbaJsonConverter))]
public readonly record struct ColorRgba(byte R, byte G, byte B, byte A);

/// <summary>
/// A tile of a tileset sheet; JSON <c>["sheet", tileId]</c>.
/// </summary>
/// <param name="Sheet">The sheet's file name.</param>
/// <param name="TileId">The tile id on the map layer.</param>
[JsonConverter(typeof(TileRefJsonConverter))]
public sealed record TileRef(string Sheet, int TileId);

/// <summary>
/// A size rule by a skill's power; JSON <c>[power, size]</c>.
/// </summary>
/// <param name="Power">The least power the size applies from.</param>
/// <param name="Size">The area size.</param>
[JsonConverter(typeof(PowerSizeJsonConverter))]
public readonly record struct PowerSize(int Power, int Size);
