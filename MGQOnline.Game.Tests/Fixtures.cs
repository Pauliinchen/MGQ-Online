//----------------------------------------------------------------
//  Fixtures.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text.Json;

namespace MGQOnline.Game.Tests;

/// <summary>
/// The golden files under fixtures, copied next to the tests.
/// </summary>
internal static class Fixtures
{
    /// <summary>
    /// Reads a case file that fixtures/wire/make_fixtures.rb wrote.
    /// </summary>
    /// <param name="name">The file, such as "decode.json".</param>
    /// <returns>Its content.</returns>
    public static JsonElement Wire(string name)
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "wire", name)));
        return document.RootElement.Clone();
    }
}
