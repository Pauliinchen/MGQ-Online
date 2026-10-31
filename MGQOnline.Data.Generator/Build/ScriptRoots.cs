//----------------------------------------------------------------
//  ScriptRoots.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Named the place of each script
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Reads the roots of an event's scripts: everything a script reaches starts at one of them, a
/// function of the interpreter, a global with the member it uses, a constant with the member it
/// uses, or an instance variable of the interpreter.
/// </summary>
internal static partial class ScriptRoots
{
    /// <summary>
    /// The branch's kind that runs a script.
    /// </summary>
    private const int ScriptBranch = 12;

    /// <summary>
    /// The variable operand that runs a script.
    /// </summary>
    private const int ScriptOperand = 4;

    /// <summary>
    /// Ruby's keywords, which are no roots.
    /// </summary>
    private static readonly HashSet<string> Keywords =
    [
        "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else", "elsif", "end", "ensure", "false", "for", "if",
        "in", "module", "next", "nil", "not", "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef", "unless",
        "until", "when", "while", "yield",
    ];

    /// <summary>
    /// Lists the roots of every script of a list, each once in the order met: the script commands
    /// with their continuation lines, the branches that run a script and the variables a script sets.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>The roots.</returns>
    public static IReadOnlyList<string> In(IReadOnlyList<RawCommand> list)
    {
        var roots = new List<string>();
        foreach ((_, string script) in ScriptsOf(list))
        {
            roots.AddRange(Of(script).Where(root => !roots.Contains(root)));
        }

        return roots;
    }

    /// <summary>
    /// Lists the roots of each script of a list with the place of the command that runs it.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>Each script's place and roots, in the order met.</returns>
    public static IEnumerable<(int Idx, IReadOnlyList<string> Roots)> At(IReadOnlyList<RawCommand> list) =>
        ScriptsOf(list).Select(script => (script.Idx, Of(script.Text)));

    /// <summary>
    /// Lists the roots of one script, each once in the order met.
    /// </summary>
    /// <param name="script">The script.</param>
    /// <returns>The roots.</returns>
    public static IReadOnlyList<string> Of(string script)
    {
        string code = Plain(script);
        var locals = new HashSet<string>(Assigned().Matches(code).Select(match => match.Groups[1].Value));
        locals.UnionWith(BlockParameters().Matches(code).SelectMany(match => match.Groups[1].Value.Split(',')).Select(name => name.Trim(' ', '*', '&')));
        locals.UnionWith(LoopVariable().Matches(code).Select(match => match.Groups[1].Value));
        var roots = new List<string>();
        foreach (Match match in Root().Matches(code))
        {
            string? root = RootAt(code, match, locals);
            if (root is not null && !roots.Contains(root))
            {
                roots.Add(root);
            }
        }

        return roots;
    }

    /// <summary>
    /// Lists the scripts of a list.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>Each script's text with the place of the command that runs it.</returns>
    private static IEnumerable<(int Idx, string Text)> ScriptsOf(IReadOnlyList<RawCommand> list)
    {
        for (int idx = 0; idx < list.Count; idx++)
        {
            RawCommand command = list[idx];
            if (command.Code == EventCodes.Script)
            {
                int start = idx;
                var script = new StringBuilder(command.Text(0));
                while (idx + 1 < list.Count && list[idx + 1].Code == EventCodes.ScriptLine)
                {
                    script.Append('\n').Append(list[++idx].Text(0));
                }

                yield return (start, script.ToString());
            }
            else if (command.Code == EventCodes.Branch && Number(command, 0) == ScriptBranch)
            {
                yield return (idx, command.Text(1));
            }
            else if (command.Code == EventCodes.ControlVariables && Number(command, 3) == ScriptOperand)
            {
                yield return (idx, command.Text(4));
            }
        }
    }

    /// <summary>
    /// Reads a command's parameter as a whole number.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="index">The parameter's place.</param>
    /// <returns>The number, 0 for none.</returns>
    private static long Number(RawCommand command, int index) =>
        index < command.Parameters.Count ? EventCommand.NumberOf(command.Parameters[index]) : 0;

    /// <summary>
    /// Leaves a script's code alone: its strings and regular expressions emptied and its comments
    /// dropped.
    /// </summary>
    /// <param name="script">The script.</param>
    /// <returns>The code.</returns>
    private static string Plain(string script)
    {
        var code = new StringBuilder(script.Length);
        for (int at = 0; at < script.Length; at++)
        {
            char next = script[at];
            if (next is '"' or '\'')
            {
                at = EndOf(script, at, next);
                code.Append(next).Append(next);
            }
            else if (next == '/' && StartsPattern(code.ToString()))
            {
                at = EndOf(script, at, '/');
                while (at + 1 < script.Length && char.IsAsciiLetter(script[at + 1]))
                {
                    at++;
                }

                code.Append("//");
            }
            else if (next == '#')
            {
                while (at + 1 < script.Length && script[at + 1] != '\n')
                {
                    at++;
                }
            }
            else
            {
                code.Append(next);
            }
        }

        return code.ToString();
    }

    /// <summary>
    /// Tells whether a slash after some code starts a regular expression: it divides only after a
    /// value, a name that is no keyword, a closing parenthesis or bracket.
    /// </summary>
    /// <param name="before">The code before the slash.</param>
    /// <returns>Whether it starts one.</returns>
    private static bool StartsPattern(string before)
    {
        string code = before.TrimEnd();
        if (code.Length == 0 || code[^1] is not (')' or ']') && !char.IsAsciiLetterOrDigit(code[^1]) && code[^1] != '_')
        {
            return true;
        }

        return LastWord().Match(code) is { Success: true } word && Keywords.Contains(word.Value);
    }

    /// <summary>
    /// Finds where a quoted text ends, its escapes skipped.
    /// </summary>
    /// <param name="script">The script.</param>
    /// <param name="start">The place of its opening mark.</param>
    /// <param name="mark">The mark that closes it.</param>
    /// <returns>The place of its closing mark, the script's end for a text never closed.</returns>
    private static int EndOf(string script, int start, char mark)
    {
        int at = start + 1;
        while (at < script.Length && script[at] != mark)
        {
            at += script[at] == '\\' ? 2 : 1;
        }

        return at;
    }

    /// <summary>
    /// Names the root a match starts, by what follows it.
    /// </summary>
    /// <param name="code">The script's code.</param>
    /// <param name="match">The match.</param>
    /// <param name="locals">The script's local variables.</param>
    /// <returns>The root, <see langword="null"/> for a keyword or a local variable.</returns>
    private static string? RootAt(string code, Match match, HashSet<string> locals)
    {
        string name = match.Value;
        int after = match.Index + match.Length;
        switch (name[0])
        {
            case '$':
                if (At(code, after) == '[')
                {
                    return name + (Assigns(code, CloseOf(code, after) + 1) ? "[]=" : "[]");
                }

                return Member(code, after) is { } member ? $"{name}.{member}" : Assigns(code, after) ? name + "=" : name;
            case '@':
                return Assigns(code, after) ? name + "=" : name;
            case >= 'A' and <= 'Z':
                return Member(code, after) is { } call ? $"{name}.{call}" : name;
            default:
                return Keywords.Contains(name) || locals.Contains(name) ? null : name;
        }
    }

    /// <summary>
    /// Reads the member a dot calls right after a place.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="at">The place.</param>
    /// <returns>The member, <see langword="null"/> when no dot follows.</returns>
    private static string? Member(string code, int at) =>
        At(code, at) == '.' && MemberName().Match(code, at + 1) is { Success: true, Index: var index } found && index == at + 1 ? found.Value : null;

    /// <summary>
    /// Tells whether an assignment follows a place: "=", "+=", "-=", "||=" and the like, not a comparison.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="at">The place.</param>
    /// <returns>Whether one does.</returns>
    private static bool Assigns(string code, int at) => Assignment().Match(code, at) is { Success: true, Index: var index } && index == at;

    /// <summary>
    /// Finds the bracket that closes the one at a place.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="open">The place of the opening bracket.</param>
    /// <returns>The place of its closing bracket, the code's end for one never closed.</returns>
    private static int CloseOf(string code, int open)
    {
        int depth = 0;
        for (int at = open; at < code.Length; at++)
        {
            depth += code[at] switch
            {
                '[' => 1,
                ']' => -1,
                _ => 0,
            };
            if (depth == 0)
            {
                return at;
            }
        }

        return code.Length;
    }

    /// <summary>
    /// Reads the character at a place.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="at">The place.</param>
    /// <returns>The character, '\0' past the end.</returns>
    private static char At(string code, int at) => at < code.Length ? code[at] : '\0';

    /// <summary>
    /// A root's start: a global, an instance variable, a constant with its namespaces, or a name.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"(?<![\w$@:.])(?:\$\w+|@\w+|[A-Z]\w*(?:::[A-Z]\w*)*|[a-z_]\w*[?!]?)", RegexOptions.CultureInvariant)]
    private static partial Regex Root();

    /// <summary>
    /// A local variable a script assigns.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"(?<![\w$@:.])([a-z_]\w*)[ \t]*(?:=(?![=~>])|\+=|-=|\*=|/=|\|\|=|&&=)", RegexOptions.CultureInvariant)]
    private static partial Regex Assigned();

    /// <summary>
    /// The parameters of a block.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\|([^|]*)\|", RegexOptions.CultureInvariant)]
    private static partial Regex BlockParameters();

    /// <summary>
    /// The variable of a for loop.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"(?<![\w$@:.])for[ \t]+([a-z_]\w*)", RegexOptions.CultureInvariant)]
    private static partial Regex LoopVariable();

    /// <summary>
    /// The name a piece of code ends with.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"[A-Za-z_]\w*\z", RegexOptions.CultureInvariant)]
    private static partial Regex LastWord();

    /// <summary>
    /// A member's name.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"[A-Za-z_]\w*[?!]?", RegexOptions.CultureInvariant)]
    private static partial Regex MemberName();

    /// <summary>
    /// An assignment, after spaces.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"[ \t]*(?:=(?![=~>])|\+=|-=|\*=|/=|\|\|=|&&=)", RegexOptions.CultureInvariant)]
    private static partial Regex Assignment();
}
