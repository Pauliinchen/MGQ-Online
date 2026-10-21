//----------------------------------------------------------------
//  FormulaParser.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// Reads a damage formula in the safe formula grammar (docs/FORMULAS.md) into a tree.
/// </summary>
/// <remarks>
/// Nothing of the text is ever run: only the tree is computed, and only the Ruby printer's text of
/// the tree reaches a compiled file. Text that Ruby reads otherwise than it looks is refused, so a
/// formula means the same to a designer, the C# engine and the game.
/// </remarks>
public static class FormulaParser
{
    /// <summary>
    /// The symbols a formula may use.
    /// </summary>
    private const string Symbols = "+-*/%()[],.";

    /// <summary>
    /// The operators Ruby may read as the start of a method's argument.
    /// </summary>
    private const string Operators = "+-*/%";

    /// <summary>
    /// Reads a formula.
    /// </summary>
    /// <param name="text">The formula's text.</param>
    /// <returns>The formula's tree, or the code and place of why it cannot be read.</returns>
    public static FormulaParse Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return new FormulaParse(null, FormulaErrors.Empty, 0);
        }

        if (text.Length > FormulaLimits.MaxLength)
        {
            return new FormulaParse(null, FormulaErrors.TooLong, FormulaLimits.MaxLength);
        }

        try
        {
            Reader reader = new(Tokenize(text));
            return new FormulaParse(reader.ReadAll(), null, -1);
        }
        catch (SyntaxException e)
        {
            return new FormulaParse(null, e.Code, e.Index);
        }
    }

    /// <summary>
    /// Splits a formula's text into tokens.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The tokens, ending with an end token.</returns>
    /// <exception cref="SyntaxException">The text holds something the grammar refuses.</exception>
    private static List<Token> Tokenize(string text)
    {
        List<Token> tokens = [];
        int i = 0;
        while (i < text.Length)
        {
            char c = text[i];
            int start = i;
            if (IsSpace(c))
            {
                i++;
            }
            else if (char.IsAsciiDigit(c))
            {
                i = SkipDigits(text, i);
                if (i - start > 1 && c == '0')
                {
                    throw new SyntaxException(FormulaErrors.LeadingZero, start);
                }

                bool isFloat = i + 1 < text.Length && text[i] == '.' && char.IsAsciiDigit(text[i + 1]);
                if (isFloat)
                {
                    i = SkipDigits(text, i + 1);
                }
                else if (!long.TryParse(text.AsSpan(start, i - start), NumberStyles.None, CultureInfo.InvariantCulture, out _))
                {
                    throw new SyntaxException(FormulaErrors.NumberTooLarge, start);
                }

                tokens.Add(new Token(TokenKind.Number, text[start..i], start));
            }
            else if (char.IsAsciiLetter(c) || c == '_')
            {
                while (i < text.Length && (char.IsAsciiLetterOrDigit(text[i]) || text[i] == '_'))
                {
                    i++;
                }

                tokens.Add(new Token(TokenKind.Name, text[start..i], start));
            }
            else if (Symbols.Contains(c))
            {
                if (c == '*' && i + 1 < text.Length && text[i + 1] == '*')
                {
                    throw new SyntaxException(FormulaErrors.Power, i);
                }

                if (ReadsAsArgument(text, i, tokens))
                {
                    throw new SyntaxException(FormulaErrors.ArgumentSpace, i);
                }

                tokens.Add(new Token(TokenKind.Symbol, c.ToString(), i));
                i++;
            }
            else
            {
                throw new SyntaxException(FormulaErrors.Character, i);
            }
        }

        tokens.Add(new Token(TokenKind.End, string.Empty, text.Length));
        return tokens;
    }

    /// <summary>
    /// Tells whether a character separates tokens.
    /// </summary>
    /// <param name="c">The character.</param>
    /// <returns>Whether it is a space or a tab.</returns>
    private static bool IsSpace(char c) => c is ' ' or '\t';

    /// <summary>
    /// Skips a run of digits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="index">Where the run starts.</param>
    /// <returns>The index after the run.</returns>
    private static int SkipDigits(string text, int index)
    {
        while (index < text.Length && char.IsAsciiDigit(text[index]))
        {
            index++;
        }

        return index;
    }

    /// <summary>
    /// Tells whether Ruby reads an operator as the start of an argument: one with a space before and
    /// none after, behind a method such as a.atk or [x, y].max, so "a.atk -b.def" is a.atk(-b.def).
    /// </summary>
    /// <param name="text">The formula's text.</param>
    /// <param name="index">Where the operator stands.</param>
    /// <param name="tokens">The tokens before it.</param>
    /// <returns>Whether the operator starts an argument.</returns>
    private static bool ReadsAsArgument(string text, int index, List<Token> tokens) =>
        Operators.Contains(text[index])
        && index > 0 && IsSpace(text[index - 1])
        && index + 1 < text.Length && !IsSpace(text[index + 1])
        && tokens.Count > 0 && tokens[^1] is { Kind: TokenKind.Name, Text: not ("a" or "b") };

    /// <summary>
    /// Maps a stat's name in a formula to the stat.
    /// </summary>
    /// <param name="name">The name, such as "atk".</param>
    /// <returns>The stat, null for a name formulas cannot read.</returns>
    private static FormulaStatName? StatOf(string name) => name switch
    {
        "atk" => FormulaStatName.Atk,
        "def" => FormulaStatName.Def,
        "mat" => FormulaStatName.Mat,
        "mdf" => FormulaStatName.Mdf,
        "agi" => FormulaStatName.Agi,
        "luk" => FormulaStatName.Luk,
        "mhp" => FormulaStatName.Mhp,
        "mmp" => FormulaStatName.Mmp,
        "hp" => FormulaStatName.Hp,
        "mp" => FormulaStatName.Mp,
        "level" => FormulaStatName.Level,
        _ => null,
    };

    /// <summary>
    /// Maps a method's name in a formula to the method.
    /// </summary>
    /// <param name="name">The name, such as "floor".</param>
    /// <returns>The method, null for a name formulas cannot call.</returns>
    private static FormulaMethodName? MethodOf(string name) => name switch
    {
        "abs" => FormulaMethodName.Abs,
        "floor" => FormulaMethodName.Floor,
        "ceil" => FormulaMethodName.Ceil,
        "round" => FormulaMethodName.Round,
        "to_i" => FormulaMethodName.ToInteger,
        "to_f" => FormulaMethodName.ToFloat,
        _ => null,
    };

    /// <summary>
    /// The kinds of formula tokens.
    /// </summary>
    private enum TokenKind
    {
        /// <summary>
        /// A number: digits, with a point and more digits for a float.
        /// </summary>
        Number,

        /// <summary>
        /// A name, such as a, atk or max.
        /// </summary>
        Name,

        /// <summary>
        /// An operator, bracket, comma or point.
        /// </summary>
        Symbol,

        /// <summary>
        /// The end of the text.
        /// </summary>
        End,
    }

    /// <summary>
    /// A token of a formula.
    /// </summary>
    /// <param name="Kind">Its kind.</param>
    /// <param name="Text">Its text.</param>
    /// <param name="Index">Where it starts in the formula.</param>
    private sealed record Token(TokenKind Kind, string Text, int Index);

    /// <summary>
    /// A subtree read so far.
    /// </summary>
    /// <param name="Node">The subtree's root.</param>
    /// <param name="Height">The nodes on its longest path from the root to a leaf.</param>
    /// <param name="Start">Where its text starts.</param>
    private readonly record struct Parsed(FormulaNode Node, int Height, int Start);

    /// <summary>
    /// Why a formula cannot be read.
    /// </summary>
    /// <param name="code">The code, one of <see cref="FormulaErrors"/>.</param>
    /// <param name="index">Where in the text.</param>
    private sealed class SyntaxException(string code, int index) : Exception(code)
    {
        /// <summary>
        /// Gets the code, one of <see cref="FormulaErrors"/>.
        /// </summary>
        public string Code { get; } = code;

        /// <summary>
        /// Gets where in the text reading failed.
        /// </summary>
        public int Index { get; } = index;
    }

    /// <summary>
    /// Reads tokens into a tree by recursive descent, one method per grammar rule.
    /// </summary>
    /// <param name="tokens">The tokens, ending with an end token.</param>
    private sealed class Reader(List<Token> tokens)
    {
        /// <summary>
        /// The next token's place.
        /// </summary>
        private int _position;

        /// <summary>
        /// The nodes made so far.
        /// </summary>
        private int _nodes;

        /// <summary>
        /// Gets the next token.
        /// </summary>
        private Token Current => tokens[_position];

        /// <summary>
        /// Reads the whole formula.
        /// </summary>
        /// <returns>The tree.</returns>
        public FormulaNode ReadAll()
        {
            Parsed formula = Expr();
            if (Current.Kind != TokenKind.End)
            {
                throw new SyntaxException(FormulaErrors.Unexpected, Current.Index);
            }

            return formula.Node;
        }

        /// <summary>
        /// Reads expr := term (('+' | '-') term)*.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Expr()
        {
            Parsed left = Term();
            while (IsSymbol('+') || IsSymbol('-'))
            {
                FormulaOperator op = Next().Text == "+" ? FormulaOperator.Add : FormulaOperator.Subtract;
                Parsed right = Term();
                left = Make(new FormulaBinary(op, left.Node, right.Node), left.Start, Math.Max(left.Height, right.Height));
            }

            return left;
        }

        /// <summary>
        /// Reads term := unary (('*' | '/' | '%') unary)*.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Term()
        {
            Parsed left = Unary();
            while (IsSymbol('*') || IsSymbol('/') || IsSymbol('%'))
            {
                FormulaOperator op = Next().Text switch
                {
                    "*" => FormulaOperator.Multiply,
                    "/" => FormulaOperator.Divide,
                    _ => FormulaOperator.Modulo,
                };
                Parsed right = Unary();
                left = Make(new FormulaBinary(op, left.Node, right.Node), left.Start, Math.Max(left.Height, right.Height));
            }

            return left;
        }

        /// <summary>
        /// Reads unary := ('-' | '+') unary | postfix. A plus makes no node, since it changes nothing.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Unary()
        {
            if (IsSymbol('+'))
            {
                int plus = Next().Index;
                return Unary() with { Start = plus };
            }

            if (!IsSymbol('-'))
            {
                return Postfix();
            }

            Token minus = Next();
            if (Current.Kind == TokenKind.Number && Current.Index == minus.Index + 1 && tokens[_position + 1] is { Kind: TokenKind.Symbol, Text: "." })
            {
                throw new SyntaxException(FormulaErrors.SignedLiteralMethod, minus.Index);
            }

            Parsed operand = Unary();
            return Make(new FormulaNegate(operand.Node), minus.Index, operand.Height);
        }

        /// <summary>
        /// Reads postfix := primary ('.' method)*.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Postfix()
        {
            Parsed target = Primary();
            while (IsSymbol('.'))
            {
                _position++;
                Token name = TakeName();
                FormulaMethodName method = MethodOf(name.Text) ?? throw new SyntaxException(FormulaErrors.UnknownMethod, name.Index);
                target = Make(new FormulaMethod(method, target.Node), target.Start, target.Height);
            }

            return target;
        }

        /// <summary>
        /// Reads primary := NUMBER | stat | call | '(' expr ')' | '[' expr (',' expr)* ']' '.' ('max' | 'min').
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Primary()
        {
            Token token = Current;
            switch (token.Kind)
            {
                case TokenKind.Number:
                    _position++;
                    return Make(new FormulaNumber(token.Text), token.Index, 0);
                case TokenKind.Name when token.Text is "a" or "b":
                    return Stat();
                case TokenKind.Name when token.Text is "min" or "max" or "clamp":
                    return Call();
                case TokenKind.Name:
                    throw new SyntaxException(FormulaErrors.UnknownName, token.Index);
                case TokenKind.Symbol when token.Text == "(":
                    _position++;
                    Parsed inner = Expr();
                    Expect(')');
                    return inner with { Start = token.Index };
                case TokenKind.Symbol when token.Text == "[":
                    return List();
                case TokenKind.End:
                    throw new SyntaxException(FormulaErrors.UnexpectedEnd, token.Index);
                default:
                    throw new SyntaxException(FormulaErrors.Unexpected, token.Index);
            }
        }

        /// <summary>
        /// Reads stat := ('a' | 'b') '.' name.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Stat()
        {
            Token subject = Next();
            Expect('.');
            Token name = TakeName();
            FormulaStatName stat = StatOf(name.Text) ?? throw new SyntaxException(FormulaErrors.UnknownStat, name.Index);
            FormulaSubject whose = subject.Text == "a" ? FormulaSubject.User : FormulaSubject.Target;
            return Make(new FormulaStat(whose, stat), subject.Index, 0);
        }

        /// <summary>
        /// Reads call := ('min' | 'max' | 'clamp') '(' expr (',' expr)* ')'.
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed Call()
        {
            Token name = Next();
            Expect('(');
            List<Parsed> values = Values();
            Expect(')');
            int height = MaxHeight(values);
            if (name.Text != "clamp")
            {
                FormulaExtremeKind kind = name.Text == "max" ? FormulaExtremeKind.Max : FormulaExtremeKind.Min;
                return Make(new FormulaExtreme(kind, values.ConvertAll(value => value.Node)), name.Index, height);
            }

            if (values.Count != 3)
            {
                throw new SyntaxException(FormulaErrors.ClampArguments, name.Index);
            }

            return Make(new FormulaClamp(values[0].Node, values[1].Node, values[2].Node), name.Index, height);
        }

        /// <summary>
        /// Reads '[' expr (',' expr)* ']' '.' ('max' | 'min').
        /// </summary>
        /// <returns>The subtree.</returns>
        private Parsed List()
        {
            int start = Next().Index;
            List<Parsed> items = Values();
            Expect(']');
            if (!IsSymbol('.'))
            {
                throw new SyntaxException(FormulaErrors.ListMethod, Current.Index);
            }

            _position++;
            Token method = Current;
            if (method is not { Kind: TokenKind.Name, Text: "max" or "min" })
            {
                throw new SyntaxException(FormulaErrors.ListMethod, method.Index);
            }

            _position++;
            FormulaExtremeKind kind = method.Text == "max" ? FormulaExtremeKind.Max : FormulaExtremeKind.Min;
            return Make(new FormulaExtreme(kind, items.ConvertAll(item => item.Node)), start, MaxHeight(items));
        }

        /// <summary>
        /// Reads expr (',' expr)*.
        /// </summary>
        /// <returns>The values.</returns>
        private List<Parsed> Values()
        {
            List<Parsed> values = [Expr()];
            while (IsSymbol(','))
            {
                _position++;
                values.Add(Expr());
            }

            return values;
        }

        /// <summary>
        /// Counts a new node and refuses a tree grown past the limits.
        /// </summary>
        /// <param name="node">The node.</param>
        /// <param name="start">Where its text starts.</param>
        /// <param name="childHeight">The height of its highest child, 0 for a leaf.</param>
        /// <returns>The subtree.</returns>
        private Parsed Make(FormulaNode node, int start, int childHeight)
        {
            if (++_nodes > FormulaLimits.MaxNodes)
            {
                throw new SyntaxException(FormulaErrors.TooManyNodes, start);
            }

            int height = childHeight + 1;
            if (height > FormulaLimits.MaxDepth)
            {
                throw new SyntaxException(FormulaErrors.TooDeep, start);
            }

            return new Parsed(node, height, start);
        }

        /// <summary>
        /// Gives the height of the highest subtree.
        /// </summary>
        /// <param name="values">The subtrees.</param>
        /// <returns>Their largest height.</returns>
        private static int MaxHeight(List<Parsed> values)
        {
            int height = 0;
            foreach (Parsed value in values)
            {
                height = Math.Max(height, value.Height);
            }

            return height;
        }

        /// <summary>
        /// Takes a name that must come next.
        /// </summary>
        /// <returns>The name's token.</returns>
        private Token TakeName()
        {
            if (Current.Kind != TokenKind.Name)
            {
                throw Mismatch();
            }

            return Next();
        }

        /// <summary>
        /// Tells whether the next token is a symbol.
        /// </summary>
        /// <param name="symbol">The symbol.</param>
        /// <returns>Whether it is.</returns>
        private bool IsSymbol(char symbol) => Current.Kind == TokenKind.Symbol && Current.Text[0] == symbol;

        /// <summary>
        /// Takes the next token.
        /// </summary>
        /// <returns>The token.</returns>
        private Token Next() => tokens[_position++];

        /// <summary>
        /// Takes a symbol that must come next.
        /// </summary>
        /// <param name="symbol">The symbol.</param>
        private void Expect(char symbol)
        {
            if (!IsSymbol(symbol))
            {
                throw Mismatch();
            }

            _position++;
        }

        /// <summary>
        /// Makes the error for a next token the grammar does not expect.
        /// </summary>
        /// <returns>The error, at the token.</returns>
        private SyntaxException Mismatch() =>
            new(Current.Kind == TokenKind.End ? FormulaErrors.UnexpectedEnd : FormulaErrors.Unexpected, Current.Index);
    }
}
