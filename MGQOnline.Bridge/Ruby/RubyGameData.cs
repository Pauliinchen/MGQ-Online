//----------------------------------------------------------------
//  RubyGameData.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// A Ruby Symbol, read from game data only.
/// </summary>
/// <param name="name">The symbol's name, without the colon.</param>
public sealed class RubySymbol(string name) : RubyValue
{
    /// <summary>
    /// Gets the symbol's name, without the colon.
    /// </summary>
    public string Name { get; } = name;

    /// <inheritdoc />
    public override string KindName => "the Symbol :" + Name;

    /// <inheritdoc />
    public override bool Equals(object? obj) => obj is RubySymbol other && other.Name == Name;

    /// <inheritdoc />
    public override int GetHashCode() => Name.GetHashCode(StringComparison.Ordinal);

    /// <inheritdoc />
    public override string ToString() => ":" + Name;

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}

/// <summary>
/// A Ruby Float, read from game data only.
/// </summary>
/// <param name="value">The number.</param>
public sealed class RubyFloat(double value) : RubyValue
{
    /// <summary>
    /// Gets the number.
    /// </summary>
    public double Value { get; } = value;

    /// <inheritdoc />
    public override string KindName => "the Float " + ToString();

    /// <inheritdoc />
    public override bool Equals(object? obj) => obj is RubyFloat other && other.Value.Equals(Value);

    /// <inheritdoc />
    public override int GetHashCode() => Value.GetHashCode();

    /// <inheritdoc />
    public override string ToString() => Value.ToString("R", CultureInfo.InvariantCulture);

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}

/// <summary>
/// A Ruby object with instance variables, such as an RPG::Event, or a Struct with its members;
/// read from game data only.
/// </summary>
/// <param name="className">The object's class, such as "RPG::Event".</param>
/// <param name="isStruct">Whether the object is a Struct, whose fields are its members.</param>
public sealed class RubyObject(string className, bool isStruct = false) : RubyValue
{
    /// <summary>
    /// The fields in the order Marshal held them.
    /// </summary>
    private readonly List<KeyValuePair<string, RubyValue>> _fields = [];

    /// <summary>
    /// Gets the object's class, such as "RPG::Event".
    /// </summary>
    public string ClassName { get; } = className;

    /// <summary>
    /// Gets whether the object is a Struct.
    /// </summary>
    public bool IsStruct { get; } = isStruct;

    /// <summary>
    /// Gets the fields in order: instance variables without their "@", or a Struct's members.
    /// </summary>
    public IReadOnlyList<KeyValuePair<string, RubyValue>> Fields => _fields;

    /// <inheritdoc />
    public override string KindName => ClassName;

    /// <summary>
    /// Reads a field.
    /// </summary>
    /// <param name="name">The field's name, without the "@".</param>
    /// <returns>The value, nil when the object lacks it.</returns>
    public RubyValue this[string name] => _fields.FirstOrDefault(field => field.Key == name).Value ?? RubyNil.Value;

    /// <inheritdoc />
    public override string ToString() => $"#<{ClassName}>";

    /// <summary>
    /// Adds a field.
    /// </summary>
    /// <param name="name">The field's name, without the "@".</param>
    /// <param name="value">The value.</param>
    internal void Add(string name, RubyValue value) => _fields.Add(new KeyValuePair<string, RubyValue>(name, value));

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(ClassName);
}

/// <summary>
/// An object its class dumped as bytes (Ruby's _dump), such as the game's Table, Color and Tone;
/// read from game data only.
/// </summary>
/// <param name="className">The object's class, such as "Table".</param>
/// <param name="data">The bytes the class wrote, kept as they are.</param>
public sealed class RubyUserData(string className, byte[] data) : RubyValue
{
    /// <summary>
    /// Gets the object's class, such as "Table".
    /// </summary>
    public string ClassName { get; } = className;

    /// <summary>
    /// Gets the bytes the class wrote.
    /// </summary>
    public ReadOnlyMemory<byte> Data { get; } = data;

    /// <inheritdoc />
    public override string KindName => ClassName;

    /// <inheritdoc />
    public override string ToString() => $"#<{ClassName} {Data.Length} bytes>";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(ClassName);
}

/// <summary>
/// An object its class dumped as another value (Ruby's marshal_dump); read from game data only.
/// </summary>
/// <param name="className">The object's class.</param>
/// <param name="data">The value the class dumped.</param>
public sealed class RubyUserObject(string className, RubyValue data) : RubyValue
{
    /// <summary>
    /// Gets the object's class.
    /// </summary>
    public string ClassName { get; } = className;

    /// <summary>
    /// Gets the value the class dumped.
    /// </summary>
    public RubyValue Data { get; } = data;

    /// <inheritdoc />
    public override string KindName => ClassName;

    /// <inheritdoc />
    public override string ToString() => $"#<{ClassName} {Data}>";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(ClassName);
}

/// <summary>
/// A Ruby Regexp, its source and options; read from game data only.
/// </summary>
/// <param name="source">The pattern.</param>
/// <param name="options">The option bits, such as 1 for ignoring case.</param>
public sealed class RubyRegexp(RubyString source, int options) : RubyValue
{
    /// <summary>
    /// Gets the pattern.
    /// </summary>
    public RubyString Source { get; } = source;

    /// <summary>
    /// Gets the option bits.
    /// </summary>
    public int Options { get; } = options;

    /// <inheritdoc />
    public override string KindName => "a Regexp";

    /// <inheritdoc />
    public override string ToString() => "/" + Source.Text + "/";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}

/// <summary>
/// A reference to a class or module by name; read from game data only.
/// </summary>
/// <param name="name">The class or module's name.</param>
public sealed class RubyModule(string name) : RubyValue
{
    /// <summary>
    /// Gets the class or module's name.
    /// </summary>
    public string Name { get; } = name;

    /// <inheritdoc />
    public override string KindName => "the class " + Name;

    /// <inheritdoc />
    public override string ToString() => Name;

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) => Refusal(KindName);
}
