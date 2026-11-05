//----------------------------------------------------------------
//  WireGame.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Gave a game that knows every symbol, field and entry, whose script finds them among its own
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// What the reading game knows that a line is checked against: the symbols it has, the fields of
/// its action results and the sizes of its database tables.
/// </summary>
public sealed class WireGame
{
    /// <summary>
    /// The symbols' texts the game has.
    /// </summary>
    private readonly HashSet<string> symbols;

    /// <summary>
    /// The names of the fields of the game's <c>Game_ActionResult</c>, without "@".
    /// </summary>
    private readonly HashSet<string> resultFields;

    /// <summary>
    /// The size of each table the game has, its unused entry 0 counted.
    /// </summary>
    private readonly Dictionary<WireTable, int> tableSizes;

    /// <summary>
    /// Whether the game takes every symbol, field and entry a line names.
    /// </summary>
    private readonly bool takesAll;

    /// <summary>
    /// Initializes what a game knows.
    /// </summary>
    /// <param name="symbols">The symbols' texts the game has; Ruby takes them from <c>Symbol.all_symbols</c>.</param>
    /// <param name="resultFields">The names of the fields of its <c>Game_ActionResult</c>, without "@".</param>
    /// <param name="tableSizes">The size of each database table it has, as Ruby's <c>Array#size</c>
    /// counts it; a table left out reads as missing, so none of its entries are found.</param>
    public WireGame(IEnumerable<string> symbols, IEnumerable<string> resultFields, IReadOnlyDictionary<WireTable, int> tableSizes)
    {
        ArgumentNullException.ThrowIfNull(tableSizes);
        this.symbols = new HashSet<string>(symbols, StringComparer.Ordinal);
        this.resultFields = new HashSet<string>(resultFields, StringComparer.Ordinal);
        this.tableSizes = new Dictionary<WireTable, int>(tableSizes);
    }

    /// <summary>
    /// Gets a game that takes every symbol, action result field and database entry a line names,
    /// for the lines the scripts read through the bridge.
    /// </summary>
    /// <remarks>
    /// The script finds each of them among its own game's when it makes its objects, so a symbol
    /// is never made of the other game's text.
    /// </remarks>
    public static WireGame Any { get; } = new(true);

    /// <summary>
    /// Initializes a game that takes everything a line names.
    /// </summary>
    /// <param name="takesAll">Whether the game takes everything.</param>
    private WireGame(bool takesAll)
        : this([], [], new Dictionary<WireTable, int>()) => this.takesAll = takesAll;

    /// <summary>
    /// Tells whether the game has a symbol.
    /// </summary>
    /// <param name="text">The symbol's text.</param>
    /// <returns>Whether it does.</returns>
    public bool HasSymbol(string text) => takesAll || symbols.Contains(text);

    /// <summary>
    /// Tells whether the game's action results have a field.
    /// </summary>
    /// <param name="name">The field's name without "@".</param>
    /// <returns>Whether they do.</returns>
    public bool HasResultField(string name) => takesAll || resultFields.Contains(name);

    /// <summary>
    /// Gives a database table's size.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its size, <see langword="null"/> for a table the game lacks.</returns>
    public int? TableSize(WireTable table) => takesAll ? int.MaxValue : tableSizes.TryGetValue(table, out int size) ? size : null;
}
