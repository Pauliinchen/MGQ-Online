//----------------------------------------------------------------
//  CoopRoster.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Duels;

namespace MGQOnline.Game.Coop;

/// <summary>
/// A field of another game's message left out for being of the wrong kind, which the scripts log
/// once per field and kind.
/// </summary>
/// <param name="Field">The field, such as "vitals".</param>
/// <param name="Kind">The Ruby class it came as, such as "String".</param>
/// <param name="Owner">Whose field it is, as the log names it, such as "a player's".</param>
public sealed record FieldDrop(string Field, string Kind, string Owner);

/// <summary>
/// A player of a co-op battle as its messages carry them: <c>MGQ_MpBattlesCoop::Player</c>'s
/// fields in order.
/// </summary>
/// <param name="Seat">Their world seat.</param>
/// <param name="Name">Their name.</param>
/// <param name="Builds">Their characters' builds.</param>
/// <param name="Vitals">Their characters' HP and MP by place: each a list of whole numbers (another
/// kind of item as <see langword="null"/>), <see langword="null"/> for none.</param>
/// <param name="Max">Their party_member_max, <see langword="null"/> for none.</param>
/// <param name="Order">The order of their places, the Frontline's first, <see langword="null"/> for none.</param>
/// <param name="Front">Their share of the Frontline, <see langword="null"/> for none.</param>
/// <param name="Bench">Their share of the Backline, <see langword="null"/> for none.</param>
public sealed record RosterPlayer(
    BigInteger Seat,
    string Name,
    string Builds,
    IReadOnlyList<IReadOnlyList<BigInteger?>?> Vitals,
    BigInteger? Max,
    IReadOnlyList<BigInteger>? Order,
    BigInteger? Front,
    BigInteger? Bench);

/// <summary>
/// The players a co-op battle's message names, as read, and the fields left out of them.
/// </summary>
/// <param name="Players">The players, those whose seat is no number left out.</param>
/// <param name="Drops">The fields left out, in the order they were met.</param>
public sealed record RosterPlayers(List<RosterPlayer> Players, List<FieldDrop> Drops);

/// <summary>
/// A roster, the host's word of a co-op battle's start: its troop, its players, its level and,
/// for a player who joins it late, its turn.
/// </summary>
/// <param name="Enemies">The troop's enemies as sent.</param>
/// <param name="Players">The players.</param>
/// <param name="Level">The battle's level, <see langword="null"/> for none or one that is no number.</param>
/// <param name="Turn">The battle's turn, <see langword="null"/> for none or one that is no number.</param>
public sealed record RosterLine(List<HostEnemy> Enemies, RosterPlayers Players, BigInteger? Level, BigInteger? Turn);

/// <summary>
/// Writes and reads the lines a co-op battle's host sends its players on the live battle's codec
/// (<see cref="WireWriter"/>, <see cref="WireReader"/>): the roster (<c>roster</c>), the party
/// (<c>coop_party</c>) and the troop (<c>coop_troop</c>), reading another game's players as
/// <c>MGQ_MpBattlesCoop::Player.read</c> did.
/// </summary>
public static class CoopRoster
{
    /// <summary>
    /// What the reading game has for the lines, which name no game object.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Whose fields the players' are, as the log names them.
    /// </summary>
    private const string PlayerOwner = "a player's";

    /// <summary>
    /// Writes a roster: the troop, the players and the level, and the turn for players who join late.
    /// </summary>
    /// <param name="enemies">The troop's enemies.</param>
    /// <param name="players">The players' fields.</param>
    /// <param name="level">The battle's level, nil in a roster of players who join late.</param>
    /// <param name="turn">The battle's turn, <see langword="null"/> for a roster of the battle's start.</param>
    /// <returns>The line.</returns>
    public static string WriteRoster(WireValue enemies, WireValue players, WireValue level, WireValue? turn) =>
        turn is null ? WireWriter.Line(enemies, players, level) : WireWriter.Line(enemies, players, level, turn);

    /// <summary>
    /// Writes the party the host tells its guests after a player joined, left or swapped.
    /// </summary>
    /// <param name="players">The players' fields.</param>
    /// <returns>The line.</returns>
    public static string WriteParty(WireValue players) => WireWriter.Line(players);

    /// <summary>
    /// Reads a roster.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>The roster, empty for a line that does not read.</returns>
    public static RosterLine ReadRoster(string line)
    {
        IReadOnlyList<WireValue> values = WireReader.Parse(line, NoGame) ?? [];
        return new RosterLine(HostEnemies(At(values, 0)), ReadPlayers(At(values, 1)), Whole(At(values, 2)), Whole(At(values, 3)));
    }

    /// <summary>
    /// Reads the party the host tells its guests.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>The players.</returns>
    public static RosterPlayers ReadParty(string line) => ReadPlayers(At(WireReader.Parse(line, NoGame) ?? [], 0));

    /// <summary>
    /// Reads the troop the host tells its guests once it changed: its enemies and the host's names.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>The enemies as sent, and the names, <see langword="null"/> for none that are text.</returns>
    public static (List<HostEnemy> Enemies, string? Names) ReadTroop(string line)
    {
        IReadOnlyList<WireValue> values = WireReader.Parse(line, NoGame) ?? [];
        return (HostEnemies(At(values, 0)), At(values, 1) is WireString names ? names.Text : null);
    }

    /// <summary>
    /// Reads the players of a message, leaving out a field of the wrong kind and a player whose seat
    /// is no number.
    /// </summary>
    /// <param name="list">The players, as Ruby's <c>Array()</c> takes them.</param>
    /// <returns>The players and the fields left out.</returns>
    public static RosterPlayers ReadPlayers(WireValue? list)
    {
        var drops = new List<FieldDrop>();
        var players = new List<RosterPlayer>();
        foreach (WireValue fields in Items(list))
        {
            RosterPlayer? player = ReadPlayer(Items(fields), drops);
            if (player is not null)
            {
                players.Add(player);
            }
        }

        return new RosterPlayers(players, drops);
    }

    /// <summary>
    /// Reads the enemies of a troop as sent, as Ruby's <c>Array()</c> takes them.
    /// </summary>
    /// <param name="list">The enemies.</param>
    /// <returns>Each enemy's fields.</returns>
    public static List<HostEnemy> HostEnemies(WireValue? list) => [.. Items(list).Select(entry => entry is WireList fields
        ? new HostEnemy(Enumerable.Range(0, TroopRepair.FieldCount).Select(index => FieldOf(At(fields.Items, index))).ToList(), DuelText.ClassName(entry))
        : new HostEnemy(null, DuelText.ClassName(entry)))];

    /// <summary>
    /// Reads one player.
    /// </summary>
    /// <param name="fields">The player's fields.</param>
    /// <param name="drops">Where the fields left out go.</param>
    /// <returns>The player, <see langword="null"/> when their seat is no number.</returns>
    private static RosterPlayer? ReadPlayer(IReadOnlyList<WireValue> fields, List<FieldDrop> drops)
    {
        if (At(fields, 0) is not WireInteger seat)
        {
            drops.Add(Drop("seat", At(fields, 0)));
            return null;
        }

        IReadOnlyList<IReadOnlyList<BigInteger?>?> vitals = [];
        if (At(fields, 3) is WireList list)
        {
            vitals = [.. list.Items.Select(VitalsOf)];
        }
        else
        {
            drops.Add(Drop("vitals", At(fields, 3)));
        }

        BigInteger? max = Count("max", At(fields, 4), drops);
        IReadOnlyList<BigInteger>? order = Places(At(fields, 5), drops);
        BigInteger? front = Count("front", At(fields, 6), drops);
        BigInteger? bench = Count("bench", At(fields, 7), drops);
        return new RosterPlayer(seat.Value, DuelText.ToS(At(fields, 1)), DuelText.ToS(At(fields, 2)), vitals, max, order, front, bench);
    }

    /// <summary>
    /// Reads a character's HP and MP as the battle takes them: a list's whole numbers, and a whole
    /// number alone as a list of it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The numbers, <see langword="null"/> for none.</returns>
    private static IReadOnlyList<BigInteger?>? VitalsOf(WireValue value) => value switch
    {
        WireList list => [.. list.Items.Select(item => item is WireInteger number ? number.Value : (BigInteger?)null)],
        WireInteger number => [number.Value],
        _ => null,
    };

    /// <summary>
    /// Reads a count among a player's fields.
    /// </summary>
    /// <param name="field">The field's name.</param>
    /// <param name="value">Its value.</param>
    /// <param name="drops">Where it goes when left out.</param>
    /// <returns>The count, <see langword="null"/> for none or one that is no number of 0 or more.</returns>
    private static BigInteger? Count(string field, WireValue? value, List<FieldDrop> drops)
    {
        switch (value)
        {
            case null or WireNil:
                return null;
            case WireInteger number when number.Value >= 0:
                return number.Value;
            default:
                drops.Add(Drop(field, value));
                return null;
        }
    }

    /// <summary>
    /// Reads the order of a player's places.
    /// </summary>
    /// <param name="value">The order.</param>
    /// <param name="drops">Where it goes when left out.</param>
    /// <returns>The places, <see langword="null"/> for none or an order with anything but numbers of 0 or more.</returns>
    private static IReadOnlyList<BigInteger>? Places(WireValue? value, List<FieldDrop> drops)
    {
        if (value is null or WireNil)
        {
            return null;
        }

        if (value is WireList list && list.Items.All(item => item is WireInteger { Value.Sign: >= 0 }))
        {
            return [.. list.Items.Select(item => ((WireInteger)item).Value)];
        }

        drops.Add(Drop("order", value));
        return null;
    }

    /// <summary>
    /// Reads a field of an enemy as sent.
    /// </summary>
    /// <param name="value">The field, <see langword="null"/> past the enemy's end.</param>
    /// <returns>The field.</returns>
    private static EnemyField FieldOf(WireValue? value) => value is WireInteger number ? new EnemyField(number.Value, "Integer") : new EnemyField(null, DuelText.ClassName(value));

    /// <summary>
    /// Notes a player's field left out.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The note.</returns>
    private static FieldDrop Drop(string field, WireValue? value) => new(field, DuelText.ClassName(value), PlayerOwner);

    /// <summary>
    /// Reads a whole number.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, <see langword="null"/> for any other kind.</returns>
    private static BigInteger? Whole(WireValue? value) => value is WireInteger number ? number.Value : null;

    /// <summary>
    /// Takes a value as Ruby's <c>Array()</c> does: a list's items, none for nil, else the value alone.
    /// </summary>
    /// <param name="value">The value, <see langword="null"/> for none.</param>
    /// <returns>The items.</returns>
    private static IReadOnlyList<WireValue> Items(WireValue? value) => value switch
    {
        WireList list => list.Items,
        null or WireNil => [],
        _ => [value],
    };

    /// <summary>
    /// Takes an item of a list as Ruby's <c>[]</c> does.
    /// </summary>
    /// <param name="items">The list.</param>
    /// <param name="index">The item's place.</param>
    /// <returns>The item, <see langword="null"/> past the list's end.</returns>
    private static WireValue? At(IReadOnlyList<WireValue> items, int index) => index < items.Count ? items[index] : null;
}
