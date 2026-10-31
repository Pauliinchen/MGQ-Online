//----------------------------------------------------------------
//  SourcePruner.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the switches an enemy's actions ask for and a skill's or item's damage formula
//      Paulinchen  2026-10-30: Kept the notes, features and effects the fingerprint asks about instead of the names
//      Paulinchen  2026-10-28: Kept the names and texts the flags are read from
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Source;

/// <summary>
/// Reads the game's RPG classes into the generator's types as their objects finish, keeping the
/// fields the events database is made of, what the fingerprint asks about and the names and texts
/// the flags are read from.
/// </summary>
/// <remarks>
/// Unlike the DLL's reader it keeps the parameters of every command the database keeps, flags and
/// texts included, since a list's shape hashes them as the game's Ruby sees them.
/// </remarks>
internal sealed class SourcePruner : MarshalPruner
{
    /// <summary>
    /// The one pruner; it keeps no state.
    /// </summary>
    public static readonly SourcePruner Instance = new();

    /// <summary>
    /// The condition type of an enemy's action that asks for a switch to be on.
    /// </summary>
    private const int SwitchCondition = 6;

    /// <summary>
    /// The characters Ruby's <c>strip</c> takes off a text's ends.
    /// </summary>
    private static readonly char[] RubyWhiteSpace = [' ', '\t', '\n', '\v', '\f', '\r', '\0'];

    /// <summary>
    /// The fields kept of each class read; a class not named keeps every field.
    /// </summary>
    private static readonly Dictionary<string, HashSet<string>> Kept = new()
    {
        ["RPG::Map"] = ["tileset_id", "encounter_list", "events"],
        ["RPG::Map::Encounter"] = ["troop_id", "weight"],
        ["RPG::Event"] = ["id", "x", "y", "pages"],
        ["RPG::Event::Page"] = ["condition", "move_type", "trigger", "list"],
        ["RPG::EventCommand"] = ["code", "indent", "parameters"],
        ["RPG::CommonEvent"] = ["id", "name", "trigger", "switch_id", "list"],
        ["RPG::Troop"] = ["id", "members", "pages"],
        ["RPG::Troop::Page"] = ["condition", "span", "list"],
        ["RPG::System"] = ["switches", "variables"],
        ["RPG::MapInfo"] = ["name", "parent_id"],
        ["RPG::Actor"] = ["note", "features"],
        ["RPG::Class"] = ["note", "features"],
        ["RPG::Skill"] = ["note", "features", "effects", "damage"],
        ["RPG::Item"] = ["note", "features", "effects", "itype_id", "description", "damage"],
        ["RPG::Weapon"] = ["note", "features", "description"],
        ["RPG::Armor"] = ["note", "features", "description"],
        ["RPG::Enemy"] = ["note", "features", "actions"],
        ["RPG::Enemy::Action"] = ["condition_type", "condition_param1"],
        ["RPG::UsableItem::Damage"] = ["formula"],
        ["RPG::State"] = ["note", "features"],
        ["RPG::BaseItem::Feature"] = [],
        ["RPG::UsableItem::Effect"] = [],
    };

    /// <inheritdoc />
    public override bool Keeps(RubyObject owner, string field)
    {
        if (!Kept.TryGetValue(owner.ClassName, out HashSet<string>? fields))
        {
            return true;
        }

        if (!fields.Contains(field))
        {
            return false;
        }

        // A command's code comes before its parameters, as RPG::EventCommand sets them.
        return field != "parameters" || owner["code"] is not RubyInteger code || KeepsParameters((int)code.Value);
    }

    /// <inheritdoc />
    /// <remarks>The editor copies events, common events and troops whole, so no data links into another's.</remarks>
    public override bool Seals(RubyObject value) => value.ClassName is "RPG::Event" or "RPG::CommonEvent" or "RPG::Troop";

    /// <inheritdoc />
    public override RubyValue Finish(RubyObject value) => value.ClassName switch
    {
        "RPG::EventCommand" => Box(new RawCommand(Int(value["code"]), Int(value["indent"]), value["parameters"] as RubyArray ?? RawCommand.NoParameters)),
        "RPG::Event::Page::Condition" => Box(ConditionOf(value)),
        "RPG::Event::Page" => Box(new SourcePage(Content<SourceCondition>(value["condition"]) ?? SourceCondition.None, Int(value["trigger"]), Int(value["move_type"]), ItemsOf<RawCommand>(value["list"]))),
        "RPG::Event" => Box(new SourceEvent(Int(value["id"]), Int(value["x"]), Int(value["y"]), ItemsOf<SourcePage>(value["pages"]))),
        "RPG::Map::Encounter" => Box(new SourceEncounter(Int(value["troop_id"]), Int(value["weight"]))),
        "RPG::CommonEvent" => Box(new SourceCommon(Int(value["id"]), Int(value["id"]), TextOf(value["name"]), Int(value["trigger"]), Int(value["switch_id"]), ItemsOf<RawCommand>(value["list"]))),
        "RPG::Troop::Member" => Box(new SourceMember(Int(value["enemy_id"]), Int(value["x"]), Int(value["y"]), IsOn(value["hidden"]))),
        "RPG::Troop::Page::Condition" => Box(TroopConditionOf(value)),
        "RPG::Troop::Page" => Box(new SourceTroopPage(Content<SourceTroopCondition>(value["condition"]) ?? SourceTroopCondition.None, Int(value["span"]), ItemsOf<RawCommand>(value["list"]))),
        "RPG::Troop" => Box(new SourceTroop(Int(value["id"]), ItemsOf<SourceMember>(value["members"]), ItemsOf<SourceTroopPage>(value["pages"]))),
        "RPG::MapInfo" => Box(new SourceMapEntry(TextOf(value["name"]), Int(value["parent_id"]))),
        "RPG::Actor" or "RPG::Class" or "RPG::Skill" or "RPG::Item" or "RPG::Weapon" or "RPG::Armor" or "RPG::Enemy" or "RPG::State" =>
            Box(new SourceEntry(InUse(value), Int(value["itype_id"]), TextOf(value["description"]), TextOf(value["note"]), FormulaOf(value["damage"]), ActionSwitches(value["actions"]))),
        _ => value,
    };

    /// <summary>
    /// Takes what a box holds.
    /// </summary>
    /// <typeparam name="T">What it should hold.</typeparam>
    /// <param name="value">The value.</param>
    /// <returns>Its content, default for anything else.</returns>
    public static T? Content<T>(RubyValue value) => value is RubyBox<T> box ? box.Content : default;

    /// <summary>
    /// Reads an Array of boxed values.
    /// </summary>
    /// <typeparam name="T">What each holds.</typeparam>
    /// <param name="value">The Array, nil for none.</param>
    /// <returns>The values.</returns>
    /// <exception cref="InvalidDataException">The Array holds something else.</exception>
    public static T[] ItemsOf<T>(RubyValue value)
    {
        if (value is not RubyArray array)
        {
            return [];
        }

        var items = new T[array.Count];
        for (int index = 0; index < items.Length; index++)
        {
            items[index] = array[index] is RubyBox<T> box ? box.Content : throw new InvalidDataException($"Expected {typeof(T).Name} in the game data, found {array[index].KindName}.");
        }

        return items;
    }

    /// <summary>
    /// Reads a whole number field.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Its number, 0 for anything else.</returns>
    public static int Int(RubyValue value) => (int)EventCommand.NumberOf(value);

    /// <summary>
    /// Reads a text field as UTF-8, as the game's data holds it.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Its text, empty for anything else.</returns>
    public static string TextOf(RubyValue value) => value is RubyString text ? text.Text : string.Empty;

    /// <summary>
    /// Tells whether an entry of a named part holds anything, as world.rbx's <c>used?</c> reads it in
    /// the running game.
    /// </summary>
    /// <param name="entry">The entry, such as an RPG::Actor.</param>
    /// <returns>Whether it holds a note past white space, features or effects.</returns>
    private static bool InUse(RubyObject entry) =>
        TextOf(entry["note"]).Trim(RubyWhiteSpace).Length > 0 || entry["features"] is RubyArray { Count: > 0 } || entry["effects"] is RubyArray { Count: > 0 };

    /// <summary>
    /// Tells whether the reader keeps a command's parameters: those of the codes the database keeps,
    /// and a script's continuation lines, which its first line's kind reads.
    /// </summary>
    /// <param name="code">The command's code.</param>
    /// <returns>Whether it keeps them.</returns>
    /// <summary>
    /// Reads a skill's or item's damage formula.
    /// </summary>
    /// <param name="damage">Its damage, nil for an entry without one.</param>
    /// <returns>The formula, empty for none.</returns>
    private static string FormulaOf(RubyValue damage) => damage is RubyObject found ? TextOf(found["formula"]) : string.Empty;

    /// <summary>
    /// Lists the switches an enemy's actions ask to be on (condition type 6).
    /// </summary>
    /// <param name="actions">Its actions, nil for an entry without them.</param>
    /// <returns>The switches.</returns>
    private static int[] ActionSwitches(RubyValue actions) => actions is RubyArray list
        ? [.. list.OfType<RubyObject>().Where(action => Int(action["condition_type"]) == SwitchCondition).Select(action => Int(action["condition_param1"]))]
        : [];

    private static bool KeepsParameters(int code) => EventSchema.Keeps(code) || code == EventCodes.ScriptLine;

    /// <summary>
    /// Boxes what the pruner built of an object.
    /// </summary>
    /// <typeparam name="T">What it built.</typeparam>
    /// <param name="content">The value built.</param>
    /// <returns>The box, which stands for the object in the read.</returns>
    private static RubyBox<T> Box<T>(T content) => new(content);

    /// <summary>
    /// Reads a page's conditions.
    /// </summary>
    /// <param name="value">The RPG::Event::Page::Condition.</param>
    /// <returns>The conditions it checks.</returns>
    private static SourceCondition ConditionOf(RubyObject value) => new(
        IsOn(value["switch1_valid"]) ? Int(value["switch1_id"]) : null,
        IsOn(value["switch2_valid"]) ? Int(value["switch2_id"]) : null,
        IsOn(value["variable_valid"]) ? Int(value["variable_id"]) : null,
        EventCommand.NumberOf(value["variable_value"]),
        IsOn(value["self_switch_valid"]) ? TextOf(value["self_switch_ch"]) : null,
        IsOn(value["item_valid"]) ? Int(value["item_id"]) : null,
        IsOn(value["actor_valid"]) ? Int(value["actor_id"]) : null);

    /// <summary>
    /// Reads a troop page's conditions.
    /// </summary>
    /// <param name="value">The RPG::Troop::Page::Condition.</param>
    /// <returns>The conditions.</returns>
    private static SourceTroopCondition TroopConditionOf(RubyObject value) => new(
        IsOn(value["turn_ending"]),
        IsOn(value["turn_valid"]),
        Int(value["turn_a"]),
        Int(value["turn_b"]),
        IsOn(value["enemy_valid"]),
        Int(value["enemy_index"]),
        Int(value["enemy_hp"]),
        IsOn(value["actor_valid"]),
        Int(value["actor_id"]),
        Int(value["actor_hp"]),
        IsOn(value["switch_valid"]),
        Int(value["switch_id"]));

    /// <summary>
    /// Tells whether a field is true, as Ruby takes any value but nil and false.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsOn(RubyValue value) => value is not (RubyNil or RubyBool { Flag: false } or RubySkipped);
}
