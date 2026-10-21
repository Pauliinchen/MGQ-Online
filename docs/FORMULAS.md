# Raid design formulas

Damage formulas in a published raid design use a small, safe grammar: numbers, the stats of the user (`a`) and the target (`b`), the four arithmetic operators and remainder, a few methods and three functions. The Raid Designer checks it while typing, Check reports a formula outside it as an error that blocks publishing, and the server's compile refuses it.

The grammar lives in `MGQOnline.Arena/Formulas` (`FormulaParser`, `FormulaEvaluator`, `RubyPrinter`, `FormulaStats`, `FormulaLimits`, `FormulaErrors`); the tree's records are in `MGQOnline.Arena/Model/Formulas`.

It applies to `damage.formula` in skill sections, a custom skill's `damage.formula` and `enemyFormula`, `markReactions[].gives.formula`, and the `damage` effect of rules.

## Grammar

```
expr    := term (('+' | '-') term)*
term    := unary (('*' | '/' | '%') unary)*
unary   := ('-' | '+') unary | postfix
postfix := primary ('.' ('abs' | 'floor' | 'ceil' | 'round' | 'to_i' | 'to_f'))*
primary := NUMBER | stat | call | '(' expr ')' | '[' expr (',' expr)* ']' '.' ('max' | 'min')
stat    := ('a' | 'b') '.' ('atk'|'def'|'mat'|'mdf'|'agi'|'luk'|'mhp'|'mmp'|'hp'|'mp'|'level')
call    := ('min' | 'max' | 'clamp') '(' expr (',' expr)* ')'
NUMBER  := DIGITS ('.' DIGITS)?
```

- Spaces and tabs separate tokens anywhere, also around the `.` of a stat or method.
- `min(x, y, ...)` and `max(x, y, ...)` are the same as `[x, y, ...].min` and `.max`; they take one value or more.
- `clamp(x, lo, hi)` takes exactly three values and is `[[x, lo].max, hi].min`, so `hi` wins when `lo` is higher.
- There is no `**`: it needs `Math.Pow`, and Ruby gives a Rational for a negative integer exponent.

Examples: `a.atk * 4 - b.def * 2`, `[a.mat, a.agi].max * 2 * 2.5 - b.mdf`, `(a.atk / 3.0).floor`, `clamp(a.luk - b.luk, 0, 20).to_f / 4`.

### Text Ruby reads otherwise

The game runs formulas with Ruby's `eval`. These are refused, because Ruby reads them differently from how they look:

| Refused | Ruby reads | Write instead |
|---|---|---|
| `a.atk -b.def`, `a.atk *2`, `[x, 1].max -1` (an operator with a space before and none after, behind a method) | `a.atk(-b.def)`: an argument, which fails in the game | `a.atk - b.def` |
| `012`, `09` (a whole number with a leading 0) | octal 10, or a syntax error | `12`, `9` |
| `-2.abs`, `-2.5.floor` (a minus against a number that a method follows) | `(-2).abs` = 2, while the grammar says `-(2.abs)` = -2 | `(-2).abs` or `-(2).abs` |
| a line break | two statements | one line |

`5 -2`, `(a.atk) -1` and `a.atk*-1` are read as Ruby reads them and accepted.

## Limits

| Limit | Value | Why |
|---|---|---|
| Length | 200 characters | keeps parsing bounded |
| Depth | 16 nodes on the longest path from the root to a leaf | the tree nests in the runtime JSON, which System.Text.Json reads to 64 levels |
| Nodes | 64 | keeps computing bounded |

Brackets make no node, a `+` sign makes none, and `-x` makes one. A chain `1 + 1 + ...` has one more level per `+`, so it holds at most 16 terms.

## Values

Values are integers (64-bit) or floats, as in Ruby:

- `+ - *` of two integers give an integer; a float on either side gives a float.
- `/` and `%` of two integers are floor division and floor remainder (`RubyMath.FloorDiv`, `FloorMod`): the quotient rounds toward negative infinity and the remainder takes the divisor's sign. With a float they are float division and Ruby's float remainder (`fmod`, then the divisor's sign).
- `.floor`, `.ceil`, `.round` and `.to_i` give integers. `.round` rounds halves away from zero, `.to_i` cuts toward zero. On an integer they change nothing.
- `.abs` keeps the kind; `.to_f` gives a float.
- `[...].max` and `.min` give the item itself, integer or float, and the first item on a tie. An integer and a float are compared as two doubles, as Ruby 1.9 does.

Floor division table (Ruby's results):

| x | y | x / y | x % y |
|---|---|---|---|
| 7 | 2 | 3 | 1 |
| -7 | 2 | -4 | 1 |
| 7 | -2 | -4 | -1 |
| -7 | -2 | 3 | -1 |
| -7 | 3 | -3 | 2 |
| 7 | -3 | -3 | -2 |
| -1 | 3 | -1 | 2 |
| 1 | -3 | -1 | -2 |
| 6 | -3 | -2 | 0 |
| 7.5 | 2 | 3.75 | 1.5 |
| -7.5 | 2 | -3.75 | 0.5 |

### When a formula fails

The whole formula gives 0, as the game's `rescue` makes a failing formula 0, when anything in it:

- divides or takes a remainder by zero, integer or float;
- gives a float that is not finite (infinity or NaN), also inside a list or clamp that would drop it;
- gives an integer beyond 64 bits, or rounds a float beyond 64 bits to an integer. Ruby would give a Bignum here; the arena gives 0, which only absurd values reach.

The evaluator keeps a negative result. The game raises a negative base damage to 0 afterwards, and so do the arena's callers.

## Printing

`RubyPrinter.Print` writes the tree as canonical Ruby, and only that text reaches a compiled file, never the text a designer typed. So nothing outside the grammar can reach the game's `eval`.

- Operators get a space on both sides, list items `, `.
- Brackets go only where Ruby would read another order: a lower-binding left operand, a right operand that binds the same or lower (`1 - (2 - 3)`), and a negated operand that is not a single value (`-(a + b)`, `-(-3)`).
- A method's target is always bracketed: `(a.atk).floor`, `(-2).abs`.
- `max(...)`/`min(...)` print as `[...].max`/`.min`, `clamp(x, lo, hi)` as `[[x, lo].max, hi].min`.
- Numbers print as typed: `1.50` stays `1.50`. A number whose text is no `NUMBER` of the grammar is refused, so a tree read from JSON cannot carry other text into the game's eval.

Printing again what the printed text reads back to gives the same text and value.

## Tree (`formulaAst`)

The compiled file carries the printed text and, for the C# engine, the tree (`FormulaSpec.Ast`, next to `FormulaSpec.Text`). Each node is a JSON object whose `type` names its kind:

| `type` | Fields |
|---|---|
| `number` | `text`: the digits as typed |
| `stat` | `subject` (`user` = a, `target` = b), `stat` |
| `negate` | `operand` |
| `binary` | `operator` (`add`, `subtract`, `multiply`, `divide`, `modulo`), `left`, `right` |
| `method` | `method` (`abs`, `floor`, `ceil`, `round`, `toInteger`, `toFloat`), `target` |
| `extreme` | `kind` (`max`, `min`), `items` |
| `clamp` | `value`, `low`, `high` |

The enum values are written as the runtime model's JSON context writes enums.

## Error codes

`FormulaParser.Parse` returns the tree, or an error code with the index in the text where reading stopped. The designer words the codes.

| Code | Meaning |
|---|---|
| `empty` | nothing but spaces |
| `tooLong`, `tooDeep`, `tooManyNodes` | a limit is passed |
| `character` | a character the grammar has no use for (quotes, `;`, `$`, `?`, `>`, line breaks, ...) |
| `power` | `**` |
| `leadingZero` | a whole number with a leading 0 |
| `numberTooLarge` | a whole number beyond 64 bits |
| `argumentSpace` | an operator Ruby reads as an argument |
| `signedLiteralMethod` | `-2.abs` and the like |
| `unknownName` | a name other than `a`, `b`, `min`, `max`, `clamp` (`v[1]`, `rand`, `Kernel`, ...) |
| `unknownStat` | `a.` or `b.` with another name |
| `unknownMethod` | `.` with another method |
| `listMethod` | a list without `.max` or `.min` |
| `clampArguments` | `clamp` without exactly three values |
| `unexpected`, `unexpectedEnd` | a token, or the end, where the grammar expects something else |

## Checks

`MGQOnline.Arena.Tests/Formulas` holds the accept and refuse corpus, the formulas of the format-1 fixture's boss and of the `compile2` golden, the designer's old `DamageFormula` test cases and the floor division table. The AOT probe (`tools/AotProbe`) prints a set of formula vectors on win-x86 and linux-x64 and fails when a value differs.
