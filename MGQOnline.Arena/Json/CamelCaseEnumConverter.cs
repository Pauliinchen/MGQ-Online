//----------------------------------------------------------------
//  CamelCaseEnumConverter.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Json;

/// <summary>
/// Reads and writes an enum as its lowerCamel name, such as <c>"randomCharacter"</c>, and refuses numbers.
/// </summary>
/// <typeparam name="TEnum">The enum.</typeparam>
public sealed class CamelCaseEnumConverter<TEnum> : JsonStringEnumConverter<TEnum>
    where TEnum : struct, Enum
{
    /// <summary>
    /// Initializes a new instance of the <see cref="CamelCaseEnumConverter{TEnum}"/> class.
    /// </summary>
    public CamelCaseEnumConverter()
        : base(JsonNamingPolicy.CamelCase, allowIntegerValues: false)
    {
    }
}
