//----------------------------------------------------------------
//  CommandClassifier.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read a talk's script that shows the game's extended choices as a choice
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// Reads a list's commands into what the rules read of them, numbers only: a self switch's letter A
/// to D becomes 1 to 4, a label the number of its name in the list, a jump the place of its label
/// (-1 for none), a script its <see cref="TextKind"/> (a choice's variable its first number), and
/// every script text the switches and variables it names.
/// </summary>
/// <remarks>
/// Every rule on a command's text lives here, so that the rules work the same on lists whose texts
/// never reach them.
/// </remarks>
public static partial class CommandClassifier
{
    /// <summary>
    /// The self switches' letters, in the order of their numbers from 1.
    /// </summary>
    private const string Letters = "ABCD";

    /// <summary>
    /// The kind of a conditional branch that runs a script, its second parameter.
    /// </summary>
    private const long ScriptBranch = 12;

    /// <summary>
    /// The kind of a Control Variables operand that runs a script, its fifth parameter.
    /// </summary>
    private const long ScriptOperand = 4;

    /// <summary>
    /// Reads a list's commands.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <param name="exChoiceResult">The variable the game's extended choices (<c>ex_choice_show</c>) write their answer into, as the game's scripts name it; <see langword="null"/> while unknown, which reads them as talk.</param>
    /// <returns>The commands as the rules read them, in the same places.</returns>
    public static EventCommand[] Classify(IReadOnlyList<RawCommand> list, long? exChoiceResult = null)
    {
        Dictionary<string, (int Place, int Number)> labels = LabelsOf(list);
        var commands = new EventCommand[list.Count];
        for (int place = 0; place < list.Count; place++)
        {
            commands[place] = Classify(list, place, labels, exChoiceResult);
        }

        return commands;
    }

    /// <summary>
    /// Names a self switch by its number, as <see cref="Classify"/> numbers its letter.
    /// </summary>
    /// <param name="number">The number, 1 to 4.</param>
    /// <returns>Its letter, empty for another number.</returns>
    public static string LetterOf(long number) => number is >= 1 and <= 4 ? Letters[(int)number - 1].ToString() : string.Empty;

    /// <summary>
    /// Finds the switch of the innermost branch on a switch being on that encloses a command; its
    /// else does not count.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="index">The command's place.</param>
    /// <param name="among">The switches that count, such as the side switches; <see langword="null"/> for every switch.</param>
    /// <returns>The switch, <see langword="null"/> when no such branch encloses it.</returns>
    public static long? EnclosingSwitch(IReadOnlyList<EventCommand> list, int index, IReadOnlySet<long>? among = null)
    {
        int indent = list[index].Indent;
        for (int place = index - 1; place >= 0; place--)
        {
            EventCommand command = list[place];
            if (command.Indent >= indent)
            {
                continue;
            }

            indent = command.Indent;
            if (command.Code == EventCodes.Branch && command.Number(0) == 0 && command.Number(2) == 0 && (among is null || among.Contains(command.Number(1))))
            {
                return command.Number(1);
            }
        }

        return null;
    }

    /// <summary>
    /// Reads one command of a list.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <param name="place">The command's place.</param>
    /// <param name="labels">The list's labels, see <see cref="LabelsOf"/>.</param>
    /// <param name="exChoiceResult">The variable of the extended choices' answers, see <see cref="Classify(IReadOnlyList{RawCommand}, long?)"/>.</param>
    /// <returns>The command.</returns>
    private static EventCommand Classify(IReadOnlyList<RawCommand> list, int place, Dictionary<string, (int Place, int Number)> labels, long? exChoiceResult)
    {
        RawCommand raw = list[place];
        long[] numbers = NumbersOf(raw.Parameters);
        TextKind kind = TextKind.None;
        string? script = null;
        switch (raw.Code)
        {
            case EventCodes.ControlSelfSwitch:
                numbers = WithFirst(numbers, LetterNumber(raw.Text(0)));
                break;
            case EventCodes.Label:
                numbers = WithFirst(numbers, labels[raw.Text(0)].Number);
                break;
            case EventCodes.JumpToLabel:
                numbers = WithFirst(numbers, labels.TryGetValue(raw.Text(0), out (int Place, int Number) label) ? label.Place : -1);
                break;
            case EventCodes.Script:
                script = raw.Text(0);
                kind = ScriptKindOf(script, JoinedScript(list, place), exChoiceResult, out long variable);
                numbers = kind == TextKind.Choice ? WithFirst(numbers, variable) : numbers;
                break;
            case EventCodes.ScriptLine:
                script = raw.Text(0);
                break;
            case EventCodes.Branch when raw.Parameters.Count > 0 && numbers[0] == ScriptBranch:
                script = raw.Text(1);
                break;
            case EventCodes.ControlVariables when numbers.Length > 3 && numbers[3] == ScriptOperand:
                script = raw.Text(4);
                break;
        }

        return new EventCommand(raw.Code, raw.Indent, numbers, kind, script is null ? EventCommand.NoKeys : KeysOf(script));
    }

    /// <summary>
    /// Finds the labels of a list.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>Each label's name with the place of its first label, where a jump to it goes, and its number in the order of the names' first labels, from 1.</returns>
    private static Dictionary<string, (int Place, int Number)> LabelsOf(IReadOnlyList<RawCommand> list)
    {
        var labels = new Dictionary<string, (int Place, int Number)>(StringComparer.Ordinal);
        for (int place = 0; place < list.Count; place++)
        {
            if (list[place].Code == EventCodes.Label)
            {
                labels.TryAdd(list[place].Text(0), (place, labels.Count + 1));
            }
        }

        return labels;
    }

    /// <summary>
    /// Reads parameters as whole numbers, texts as 0.
    /// </summary>
    /// <param name="parameters">The parameters.</param>
    /// <returns>The numbers.</returns>
    private static long[] NumbersOf(RubyArray parameters)
    {
        if (parameters.Count == 0)
        {
            return EventCommand.NoNumbers;
        }

        var numbers = new long[parameters.Count];
        for (int index = 0; index < numbers.Length; index++)
        {
            numbers[index] = EventCommand.NumberOf(parameters[index]);
        }

        return numbers;
    }

    /// <summary>
    /// Puts a number in the first place.
    /// </summary>
    /// <param name="numbers">The numbers, which a command without parameters shares with others.</param>
    /// <param name="first">The first number.</param>
    /// <returns>The numbers.</returns>
    private static long[] WithFirst(long[] numbers, long first)
    {
        if (numbers.Length == 0)
        {
            return [first];
        }

        numbers[0] = first;
        return numbers;
    }

    /// <summary>
    /// Numbers a self switch's letter.
    /// </summary>
    /// <param name="letter">The letter.</param>
    /// <returns>1 to 4 for A to D, 0 for anything else.</returns>
    private static long LetterNumber(string letter) => letter.Length == 1 ? Letters.IndexOf(letter[0], StringComparison.Ordinal) + 1 : 0;

    /// <summary>
    /// Reads a script command with its continuation lines.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <param name="place">The script command's place.</param>
    /// <returns>The script, its lines joined by line breaks.</returns>
    private static string JoinedScript(IReadOnlyList<RawCommand> list, int place)
    {
        var lines = new List<string> { list[place].Text(0) };
        for (int next = place + 1; next < list.Count && list[next].Code == EventCodes.ScriptLine; next++)
        {
            lines.Add(list[next].Text(0));
        }

        return string.Join('\n', lines);
    }

    /// <summary>
    /// Tells what a script does.
    /// </summary>
    /// <param name="first">The script command's own line.</param>
    /// <param name="script">The whole script, see <see cref="JoinedScript"/>.</param>
    /// <param name="exChoiceResult">The variable of the extended choices' answers, <see langword="null"/> while unknown.</param>
    /// <param name="variable">The variable a choice writes, 0 for another kind.</param>
    /// <returns>The kind.</returns>
    private static TextKind ScriptKindOf(string first, string script, long? exChoiceResult, out long variable)
    {
        variable = 0;
        if (TravelScript().IsMatch(script))
        {
            return TextKind.Travel;
        }

        if (TalkScript().IsMatch(script))
        {
            if (ChoiceScript().Match(first) is { Success: true } match && long.TryParse(match.Groups[1].ValueSpan, NumberStyles.None, CultureInfo.InvariantCulture, out variable))
            {
                return TextKind.Choice;
            }

            if (exChoiceResult is { } result && ExChoiceShow().IsMatch(script))
            {
                variable = result;
                return TextKind.Choice;
            }

            return TextKind.Talk;
        }

        return NovelScene().IsMatch(first) ? TextKind.Novel : TextKind.Other;
    }

    /// <summary>
    /// Lists the switches and variables a script text names by their ids.
    /// </summary>
    /// <param name="script">The script, or one of its lines.</param>
    /// <returns>The keys in their order, each as often as named.</returns>
    private static ScriptKey[] KeysOf(string script)
    {
        MatchCollection matches = ScriptKeyPattern().Matches(script);
        if (matches.Count == 0)
        {
            return EventCommand.NoKeys;
        }

        var keys = new ScriptKey[matches.Count];
        for (int index = 0; index < keys.Length; index++)
        {
            Match match = matches[index];
            keys[index] = new ScriptKey(
                match.Groups["kind"].Value == "variables",
                long.Parse(match.Groups["id"].ValueSpan, CultureInfo.InvariantCulture),
                match.Groups["set"].Success);
        }

        return keys;
    }

    /// <summary>
    /// Scripts a talk may run, such as companions' lines, choices, presents, menus, shops that list
    /// their goods in a script, and cosmetic scripts like move routes, waits and zooms.
    /// </summary>
    /// <returns>The pattern, ASCII classes as Ruby's.</returns>
    [GeneratedRegex(@"\A[ \t\r\n\f\v]*(actor_label_jump|unlimited_choices|ex_choice_[A-Za-z0-9_]+|present_start|change_friend|gain_medal|gain_coin|play_base_bgm|clear_skill_name|display_skill_name|call_synthesize|call_slot_scene|start_poker|call_party_edit|SceneManager\.call\(Scene_JobChange\)|names = party_members|@?goods(?![A-Za-z0-9_])|[A-Za-z0-9_]+ = RPG::MoveRoute\.new|wait\(|set_(angle|zoom|zoom_anime|swing_anime|circle_anime|cycle)\(|map_zoom|input_keys|check_picture_exist)", RegexOptions.CultureInvariant)]
    private static partial Regex TalkScript();

    /// <summary>
    /// Scripts that travel.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A[ \t\r\n\f\v]*(forced_transfer|forced_get_off_vehicle|forced_get_on_airship)", RegexOptions.CultureInvariant)]
    private static partial Regex TravelScript();

    /// <summary>
    /// A script that shows a choice and writes the answer into the variable its first argument names.
    /// </summary>
    /// <returns>The pattern, the variable's id its first group.</returns>
    [GeneratedRegex(@"\A[ \t\r\n\f\v]*unlimited_choices\([ \t\r\n\f\v]*([0-9]+)", RegexOptions.CultureInvariant)]
    private static partial Regex ChoiceScript();

    /// <summary>
    /// A script that shows the game's extended choices, which write the answer into the variable
    /// the game's scripts name.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\bex_choice_show\b", RegexOptions.CultureInvariant)]
    private static partial Regex ExChoiceShow();

    /// <summary>
    /// A script that plays a novel scene.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A[ \t\r\n\f\v]*call_novel_scene", RegexOptions.CultureInvariant)]
    private static partial Regex NovelScene();

    /// <summary>
    /// A switch or variable a script names by its id, set when an assignment follows.
    /// </summary>
    /// <returns>The pattern: its kind ("switches" or "variables"), id and whether it is set.</returns>
    [GeneratedRegex(@"\$game_(?<kind>switches|variables)\[\s*(?<id>[0-9]{1,9})\s*\](?<set>\s*(?:[-+*/%|&]|<<|>>|\|\||&&)?=(?!=))?", RegexOptions.CultureInvariant)]
    private static partial Regex ScriptKeyPattern();
}
