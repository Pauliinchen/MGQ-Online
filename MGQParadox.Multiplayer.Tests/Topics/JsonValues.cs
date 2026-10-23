//----------------------------------------------------------------
//  JsonValues.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Turns the golden cases' JSON into the plain values the bridge carries.
/// </summary>
internal static class JsonValues
{
    /// <summary>
    /// Turns a JSON value into the plain value the bridge carries.
    /// </summary>
    /// <param name="json">The JSON value.</param>
    /// <returns>The value.</returns>
    public static RubyValue RubyOf(JsonElement json) => json.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Number => json.GetInt64(),
        JsonValueKind.String => json.GetString(),
        JsonValueKind.Array => new RubyArray(json.EnumerateArray().Select(RubyOf)),
        _ => HashOf(json),
    };

    /// <summary>
    /// Turns a JSON object into a Hash with String keys, in its order.
    /// </summary>
    /// <param name="json">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement json)
    {
        RubyHash hash = new();
        foreach (JsonProperty property in json.EnumerateObject())
        {
            hash.Add(property.Name, RubyOf(property.Value));
        }

        return hash;
    }
}
