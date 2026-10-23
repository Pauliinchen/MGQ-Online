//----------------------------------------------------------------
//  Fixtures.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read the contract fixtures of a topic
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// The golden files under fixtures/bridge, copied next to the tests.
/// </summary>
internal static class Fixtures
{
    /// <summary>
    /// Reads a Marshal dump that fixtures/bridge/codec/make_fixtures.rb wrote.
    /// </summary>
    /// <param name="name">The case, such as "strings".</param>
    /// <returns>The dump's bytes.</returns>
    public static byte[] Codec(string name) =>
        File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "bridge", "codec", name + ".marshal"));

    /// <summary>
    /// Reads a contract fixture that fixtures/bridge/make_topic_fixtures.rb wrote.
    /// </summary>
    /// <param name="topic">The topic's folder, such as "batch".</param>
    /// <param name="name">The case, such as "in_order".</param>
    /// <param name="part">"request" or "reply".</param>
    /// <returns>The dump's bytes, none for no reply.</returns>
    public static byte[] Topic(string topic, string name, string part) =>
        File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "bridge", topic, $"{name}.{part}.marshal"));
}
