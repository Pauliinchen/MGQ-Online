//----------------------------------------------------------------
//  BattleEventTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Dropped the test of the effect queue seam
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Events;

/// <summary>
/// Tests the battle events and the seams that pass them on.
/// </summary>
public sealed class BattleEventTests
{
    /// <summary>
    /// Every rule trigger has an event of the same JSON type.
    /// </summary>
    [Fact]
    public void EveryTriggerHasItsEvent()
    {
        HashSet<string> events = Discriminators(typeof(BattleEvent)).ToHashSet();

        string[] missing = Discriminators(typeof(TriggerSpec)).Where(name => !events.Contains(name)).ToArray();

        Assert.Empty(missing);
    }

    /// <summary>
    /// Gets the JSON type names of a polymorphic base.
    /// </summary>
    /// <param name="type">The base.</param>
    /// <returns>The names.</returns>
    private static IEnumerable<string> Discriminators(System.Type type) =>
        type.GetCustomAttributes<JsonDerivedTypeAttribute>().Select(attribute => (string)attribute.TypeDiscriminator!);
}
