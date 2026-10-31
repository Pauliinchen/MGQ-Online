//----------------------------------------------------------------
//  Fixtures.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Stopped reading the interface's cases, which moved into the Mod Framework
//      Paulinchen  2026-10-23: Read the interface's cases too
//                            - Read the golden files of any area
//                            - Read the world room's cases
//                            - Created
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
    public static JsonElement Wire(string name) => Read("wire", name);

    /// <summary>
    /// Reads a golden file of an area.
    /// </summary>
    /// <param name="area">The area's folder under fixtures, such as "catchup".</param>
    /// <param name="name">The file, such as "exp.json".</param>
    /// <returns>Its content.</returns>
    public static JsonElement Read(string area, string name)
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", area, name)));
        return document.RootElement.Clone();
    }

    /// <summary>
    /// Reads the world room's cases that fixtures/peers/make_fixtures.rb wrote.
    /// </summary>
    /// <returns>The routes and the scenarios.</returns>
    public static JsonElement Peers() => Read("peers", "cases.json");
}
