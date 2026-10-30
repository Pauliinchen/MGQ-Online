//----------------------------------------------------------------
//  ServedSetup.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Carried the widths of the troop's pictures the starter measured
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Coop;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Served;

/// <summary>
/// What the starter of a co-op battle hands the relay's battle server to host it, as
/// battles_served.rbx wrote it: one battle line of the starter's facts, read back and checked on
/// the server as BattleServer/lib/served.rb checked it.
/// </summary>
public static partial class ServedSetup
{
    /// <summary>
    /// The setup's format; a server answers a setup of another format with a refusal, and the starter hosts.
    /// </summary>
    public const long Format = 1;

    /// <summary>
    /// The highest seat of a world's room, which seats 32 games.
    /// </summary>
    public const int WorldSeats = 31;

    /// <summary>
    /// The refusal's code of a setup the server cannot host.
    /// </summary>
    public const string SetupCode = "setup";

    /// <summary>
    /// The facts in the order the line holds them after the format.
    /// </summary>
    private static readonly string[] Facts =
        ["scripts", "data", "troop", "escape", "lose", "map", "rates", "enemies", "players", "level", "switches", "variables", "raid", "pool", "tiers", "starter", "squad", "mods", "settings"];

    /// <summary>
    /// The fact of the widths of the troop's pictures the starter measured, which follows the others
    /// only when the starter names it, so a setup without it keeps its bytes.
    /// </summary>
    private const string WidthsFact = "widths";

    /// <summary>
    /// The place of <see cref="WidthsFact"/> on the line.
    /// </summary>
    private const int WidthsAt = 20;

    /// <summary>
    /// The facts written as 1 or 0 for true or false.
    /// </summary>
    private static readonly HashSet<string> Flags = new(StringComparer.Ordinal) { "escape", "lose", "raid", "tiers" };

    /// <summary>
    /// The key of a one-key Hash that stands for a Float among the facts, its Ruby text as its
    /// value; the bridge carries no Floats.
    /// </summary>
    private const string FloatTag = "float";

    /// <summary>
    /// The key of a one-key Hash that stands for a Symbol among the facts, its name as its value;
    /// the bridge carries no Symbols.
    /// </summary>
    private const string SymbolTag = "symbol";

    /// <summary>
    /// What a setup's line is read against: plain values alone.
    /// </summary>
    private static readonly WireGame PlainLines = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Writes a setup from the facts the starter's game collected.
    /// </summary>
    /// <param name="facts">By name: <c>scripts</c> and <c>data</c> (the fingerprints), <c>troop</c>,
    /// <c>escape</c> and <c>lose</c> (true or false), <c>map</c>, <c>rates</c>, <c>enemies</c>,
    /// <c>players</c>, <c>level</c> (nil for none), <c>switches</c>, <c>variables</c>, <c>raid</c>,
    /// <c>pool</c> (nil for none), <c>tiers</c>, <c>starter</c>, <c>squad</c> ([name, value] pairs,
    /// nil for none), <c>mods</c>, <c>settings</c> and, when the starter measured them, <c>widths</c>
    /// ([enemy id, width] each, written as <see cref="EnemyWidths.Write"/> writes them); a Float or
    /// Symbol among them tagged.</param>
    /// <returns>The setup, a battle line.</returns>
    public static string Write(RubyHash facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        var values = new List<WireValue> { Format };
        foreach (string name in Facts)
        {
            RubyValue fact = facts[name];
            values.Add(name switch
            {
                _ when Flags.Contains(name) => fact is RubyBool { Flag: true } ? 1L : 0L,
                "level" => fact is RubyInteger level ? level.Value : 0L,
                "squad" => fact.IsNil ? new WireList([]) : WireOf(fact),
                _ => WireOf(fact),
            });
        }

        if (facts.TryGetValue(WidthsFact, out RubyValue? widths) && widths is RubyArray pairs)
        {
            values.Add(EnemyWidths.Write(pairs.Select(pair => (pair.AsArray()[0].AsLong(), pair.AsArray()[1].AsLong()))));
        }

        return WireWriter.Line(values);
    }

    /// <summary>
    /// Reads a setup, leaving out what is of the wrong kind, as read_setup did.
    /// </summary>
    /// <param name="line">The setup.</param>
    /// <returns>By name: <c>scripts</c>, <c>data</c>, <c>troop</c>, <c>escape</c>, <c>lose</c>, <c>map</c>,
    /// <c>rates</c>, <c>enemies</c>, <c>players</c> (each player's fields as they came), <c>level</c>
    /// (nil for none), <c>switches</c>, <c>variables</c>, <c>raid</c>, <c>pool</c> (nil for none),
    /// <c>tiers</c>, <c>starter</c> (nil for none), <c>squad</c> (the [name, value] pairs of a squad
    /// rule's kinds), <c>mods</c> ([key, kind, version, {path => hash}] each), <c>settings</c> and,
    /// when the line holds them as a text, <c>widths</c>; <see langword="null"/> for a setup of
    /// another format.</returns>
    public static RubyHash? Read(string line)
    {
        ArgumentNullException.ThrowIfNull(line);
        IReadOnlyList<WireValue>? values = WireReader.Parse(line, PlainLines);
        if (values is null || At(values, 0) is not WireInteger { Value: var format } || format != Format || At(values, 3) is not WireInteger { Value: var troop })
        {
            return null;
        }

        if (ToI(At(values, 6)) is not { } map)
        {
            return null;
        }

        var setup = new RubyHash
        {
            { "scripts", ToS(At(values, 1)) },
            { "data", ToS(At(values, 2)) },
            { "troop", troop },
            { "escape", IsOne(At(values, 4)) },
            { "lose", IsOne(At(values, 5)) },
            { "map", map },
            { "rates", ToS(At(values, 7)) },
            { "enemies", RubyOf(new WireList(ArrayOf(At(values, 8)))) },
            { "players", RubyOf(new WireList(ArrayOf(At(values, 9)))) },
            { "level", At(values, 10) is WireInteger { Value: var level } && level > 0 ? level : RubyNil.Value },
            { "switches", new RubyArray(ArrayOf(At(values, 11)).OfType<WireInteger>().Where(id => id.Value > 0).Select(id => (RubyValue)id.Value)) },
            { "variables", new RubyArray(ArrayOf(At(values, 12)).Where(pair => pair is WireList { Items: [WireInteger, WireInteger] }).Select(RubyOf)) },
            { "raid", IsOne(At(values, 13)) },
            { "pool", At(values, 14) is WireList pool ? RubyOf(pool) : RubyNil.Value },
            { "tiers", IsOne(At(values, 15)) },
            { "starter", At(values, 16) is WireInteger { Value: var starter } ? starter : RubyNil.Value },
            { "squad", new RubyArray(ArrayOf(At(values, 17)).Where(pair => pair is WireList { Items: [WireString, WireInteger or WireBool] }).Select(RubyOf)) },
            { "mods", new RubyArray(ArrayOf(At(values, 18)).Select(ModOf).OfType<RubyValue>()) },
            { "settings", ToS(At(values, 19)) },
        };
        if (At(values, WidthsAt) is WireString { Text: var widths })
        {
            setup[WidthsFact] = widths;
        }

        return setup;
    }

    /// <summary>
    /// Finds why the battle server refuses a setup, as served.rb checked it.
    /// </summary>
    /// <param name="line">The setup.</param>
    /// <param name="scripts">The server's own scripts' fingerprint.</param>
    /// <param name="data">The server's own game data's fingerprint.</param>
    /// <param name="troopHasEnemies">Whether the setup's troop has enemies in the server's database.</param>
    /// <returns>The refusal's code (setup, scripts or data) and why; <see langword="null"/> for a setup the server hosts.</returns>
    public static (string Code, string Why)? Refusal(string line, string scripts, string data, bool troopHasEnemies)
    {
        if (Read(line) is not { } setup)
        {
            return (SetupCode, "a setup of another format");
        }

        if (setup["scripts"].AsText() != scripts)
        {
            return ("scripts", "the starter's MGQ Online differs from the server's");
        }

        if (setup["data"].AsText() != data)
        {
            return ("data", "the starter's game data differs from the server's");
        }

        BigInteger troop = ((RubyInteger)setup["troop"]).Value;
        if (troop <= 0 || !troopHasEnemies)
        {
            return (SetupCode, $"troop {troop} has no enemies");
        }

        // A player whose seat is no number is dropped as the game's Player.read drops them.
        var seats = setup["players"].AsArray().Select(player => player is RubyArray { Count: > 0 } fields ? fields[0] : RubyNil.Value).OfType<RubyInteger>().Select(seat => seat.Value).ToList();
        if (seats.Count == 0)
        {
            return (SetupCode, "a battle without players");
        }

        if (seats.Distinct().Count() != seats.Count || seats.Any(seat => seat < 0 || seat > WorldSeats))
        {
            return (SetupCode, $"players on seats [{string.Join(", ", seats)}], not distinct world seats");
        }

        return setup["starter"] is RubyInteger { Value: var starter } && seats.Contains(starter)
            ? null
            : (SetupCode, $"the starter on seat {(setup["starter"] is RubyInteger told ? told.Value.ToString() : "nil")} is none of the players");
    }

    /// <summary>
    /// The hashes of a mod's files the server takes: 64 hexadecimal digits in lower case.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("^[0-9a-f]{64}$")]
    private static partial Regex HashPattern();

    /// <summary>
    /// Reads a mod a setup names as mods_of did: its key, kind, version and its files' hashes by path.
    /// </summary>
    /// <param name="mod">The mod as the line holds it.</param>
    /// <returns>The mod; <see langword="null"/> for one of another shape.</returns>
    private static RubyValue? ModOf(WireValue mod)
    {
        if (mod is not WireList { Items: [WireString { Text: { Length: > 0 } key }, WireString { Text: var kind }, WireString { Text: var version }, WireList { Items: var files }, ..] })
        {
            return null;
        }

        var hashes = new RubyHash();
        foreach (WireValue file in files)
        {
            if (file is WireList { Items: [WireString { Text: var path }, WireString { Text: var hash }, ..] } && HashPattern().IsMatch(hash))
            {
                hashes[path] = hash;
            }
        }

        return new RubyArray([key, kind, version, hashes]);
    }

    /// <summary>
    /// Finds a value of the line, nil past its end.
    /// </summary>
    /// <param name="values">The line's values.</param>
    /// <param name="index">The place.</param>
    /// <returns>The value.</returns>
    private static WireValue At(IReadOnlyList<WireValue> values, int index) => index < values.Count ? values[index] : WireNil.Value;

    /// <summary>
    /// Reads a value as Ruby's <c>Array()</c> does: a list's items, none for nil, else the value alone.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The items.</returns>
    private static IReadOnlyList<WireValue> ArrayOf(WireValue value) => value switch
    {
        WireList list => list.Items,
        WireNil => [],
        _ => [value],
    };

    /// <summary>
    /// Tells whether a value is the Integer 1, as a flag of the setup.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsOne(WireValue value) => value is WireInteger { Value: var number } && number == 1;

    /// <summary>
    /// Reads a value as a text as Ruby's <c>to_s</c> does for the values a setup holds.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text; empty for nil and for what no setup holds.</returns>
    private static string ToS(WireValue value) => value switch
    {
        WireString text => text.Text,
        WireInteger number => number.Value.ToString(),
        WireBool flag => flag.Flag ? "true" : "false",
        _ => string.Empty,
    };

    /// <summary>
    /// Reads a value as a whole number as Ruby's <c>to_i</c> does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number; <see langword="null"/> for a value that has no <c>to_i</c>.</returns>
    private static BigInteger? ToI(WireValue value) => value switch
    {
        WireInteger number => number.Value,
        WireString text => RubyNumbers.ToI(Encoding.UTF8.GetBytes(text.Text)),
        WireNil => BigInteger.Zero,
        _ => null,
    };

    /// <summary>
    /// Writes a plain value of the bridge as a value of the line.
    /// </summary>
    /// <param name="value">The value: nil, true, false, an Integer, a String, a tagged Float or
    /// Symbol (see <see cref="FloatTag"/> and <see cref="SymbolTag"/>) or an Array of these.</param>
    /// <returns>The line's value.</returns>
    private static WireValue WireOf(RubyValue value) => value switch
    {
        RubyNil => WireNil.Value,
        RubyBool flag => flag.Flag,
        RubyInteger number => number.Value,
        RubyString text => text.AsText(),
        RubyArray list => new WireList(list.Select(WireOf).ToList()),
        RubyHash { Count: 1 } tagged when tagged.TryGetValue(FloatTag, out RubyValue? number) => new WireFloat(FloatOf(number.AsText())),
        RubyHash { Count: 1 } tagged when tagged.TryGetValue(SymbolTag, out RubyValue? name) => new WireSymbol(name.AsText()),
        _ => throw new ArgumentException($"{value.GetType().Name} has no place in a setup.", nameof(value)),
    };

    /// <summary>
    /// Reads a Float as Ruby's <c>Float#to_s</c> wrote it.
    /// </summary>
    /// <param name="text">The text, such as "320.5", "1.0e+20" or "Infinity".</param>
    /// <returns>The number.</returns>
    private static double FloatOf(string text) => text switch
    {
        "Infinity" => double.PositiveInfinity,
        "-Infinity" => double.NegativeInfinity,
        "NaN" => double.NaN,
        _ => double.Parse(text, NumberStyles.Float, CultureInfo.InvariantCulture),
    };

    /// <summary>
    /// Writes a value of the line as a plain value of the bridge.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value; nil for what no setup holds.</returns>
    private static RubyValue RubyOf(WireValue value) => value switch
    {
        WireBool flag => flag.Flag,
        WireInteger number => number.Value,
        WireString text => text.Text,
        WireList list => new RubyArray(list.Items.Select(RubyOf)),
        _ => RubyNil.Value,
    };
}
