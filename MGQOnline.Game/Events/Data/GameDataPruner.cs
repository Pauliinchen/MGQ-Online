//----------------------------------------------------------------
//  GameDataPruner.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Shared the reading of a page's conditions with the check of the player's maps
//                            - Read the game's extended choices as choices by the variable of their answers
//      Paulinchen  2026-10-28: Classified each list of commands as it finished
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// Reads the game's RPG classes into the event types as their objects finish, keeping only the fields
/// the rules read.
/// </summary>
internal sealed class GameDataPruner : MarshalPruner
{
    /// <summary>
    /// The pruner that reads the game's extended choices as talk; it keeps no state.
    /// </summary>
    public static readonly GameDataPruner Instance = new(null);

    /// <summary>
    /// The variable the game's extended choices write their answer into, <see langword="null"/> while unknown.
    /// </summary>
    private readonly long? _exChoiceResult;

    /// <summary>
    /// Initializes a pruner.
    /// </summary>
    /// <param name="exChoiceResult">The variable the game's extended choices write their answer into, <see langword="null"/> while unknown, which reads them as talk.</param>
    public GameDataPruner(long? exChoiceResult)
    {
        _exChoiceResult = exChoiceResult;
    }

    /// <summary>
    /// The fields kept of each class the rules read; a class not named keeps every field.
    /// </summary>
    private static readonly Dictionary<string, HashSet<string>> Kept = new()
    {
        ["RPG::Map"] = ["events"],
        ["RPG::Event"] = ["id", "name", "pages"],
        ["RPG::Event::Page"] = ["condition", "trigger", "list"],
        ["RPG::EventCommand"] = ["code", "indent", "parameters"],
        ["RPG::CommonEvent"] = ["id", "name", "trigger", "switch_id", "list"],
        ["RPG::Troop"] = ["id", "name", "pages"],
        ["RPG::Troop::Page"] = ["list"],
        ["RPG::System"] = ["switches", "variables"],
        ["RPG::MapInfo"] = ["name", "parent_id"],
        ["RPG::Actor"] = [],
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
        return field != "parameters" || owner["code"] is not RubyInteger code || EventCodes.KeepsParameters((int)code.Value);
    }

    /// <inheritdoc />
    /// <remarks>The editor copies events, common events and troops whole, so no data links into another's.</remarks>
    public override bool Seals(RubyObject value) => value.ClassName is "RPG::Event" or "RPG::CommonEvent" or "RPG::Troop";

    /// <inheritdoc />
    public override RubyValue Finish(RubyObject value) => value.ClassName switch
    {
        "RPG::EventCommand" => Box(new RawCommand(Int(value["code"]), Int(value["indent"]), value["parameters"] as RubyArray ?? RawCommand.NoParameters)),
        "RPG::Event::Page::Condition" => Box(ConditionOf(value)),
        "RPG::Event::Page" => Box(new EventPage(Content<PageCondition>(value["condition"]) ?? PageCondition.None, Int(value["trigger"]), ListOf(value["list"]))),
        "RPG::Event" => Box(new MapEvent(Int(value["id"]), TextOf(value["name"]), ItemsOf<EventPage>(value["pages"]))),
        "RPG::CommonEvent" => Box(new CommonEvent(Int(value["id"]), TextOf(value["name"]), Int(value["trigger"]), Int(value["switch_id"]), ListOf(value["list"]))),
        "RPG::Troop::Page" => Box(ListOf(value["list"])),
        "RPG::Troop" => Box(new Troop(Int(value["id"]), TextOf(value["name"]), ItemsOf<IReadOnlyList<EventCommand>>(value["pages"]))),
        "RPG::MapInfo" => Box(new MapInfo(0, TextOf(value["name"]), Int(value["parent_id"]))),
        _ => value,
    };

    /// <summary>
    /// Reads a list of commands, its texts classified.
    /// </summary>
    /// <param name="value">The list as read: an Array of boxed commands, nil for none.</param>
    /// <returns>The commands.</returns>
    internal IReadOnlyList<EventCommand> ListOf(RubyValue value) => CommandClassifier.Classify(ItemsOf<RawCommand>(value), _exChoiceResult);

    /// <summary>
    /// Reads an Array of boxed values.
    /// </summary>
    /// <typeparam name="T">What each holds.</typeparam>
    /// <param name="value">The Array, nil for none.</param>
    /// <returns>The values.</returns>
    /// <exception cref="InvalidDataException">The Array holds something else.</exception>
    internal static T[] ItemsOf<T>(RubyValue value)
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
    /// Boxes what the pruner built of an object.
    /// </summary>
    /// <typeparam name="T">What it built.</typeparam>
    /// <param name="content">The value built.</param>
    /// <returns>The box, which stands for the object in the read.</returns>
    private static RubyBox<T> Box<T>(T content) => new(content);

    /// <summary>
    /// Takes what a box holds.
    /// </summary>
    /// <typeparam name="T">What it should hold.</typeparam>
    /// <param name="value">The value.</param>
    /// <returns>Its content, default for anything else.</returns>
    internal static T? Content<T>(RubyValue value) => value is RubyBox<T> box ? box.Content : default;

    /// <summary>
    /// Reads a whole number field.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Its number, 0 for anything else.</returns>
    internal static int Int(RubyValue value) => (int)EventCommand.NumberOf(value);

    /// <summary>
    /// Reads a text field as UTF-8, as the game's data holds it.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Its text, empty for anything else.</returns>
    internal static string TextOf(RubyValue value) => value is RubyString text ? text.Text : string.Empty;

    /// <summary>
    /// Reads a page's conditions.
    /// </summary>
    /// <param name="value">The RPG::Event::Page::Condition.</param>
    /// <returns>The conditions it checks.</returns>
    internal static PageCondition ConditionOf(RubyObject value) => new(
        IsOn(value["switch1_valid"]) ? Int(value["switch1_id"]) : null,
        IsOn(value["switch2_valid"]) ? Int(value["switch2_id"]) : null,
        IsOn(value["variable_valid"]) ? Int(value["variable_id"]) : null,
        EventCommand.NumberOf(value["variable_value"]),
        IsOn(value["self_switch_valid"]) ? TextOf(value["self_switch_ch"]) : null);

    /// <summary>
    /// Tells whether a field is true, as Ruby takes any value but nil and false.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsOn(RubyValue value) => value is not (RubyNil or RubyBool { Flag: false });
}
