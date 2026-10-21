//----------------------------------------------------------------
//  ReferenceTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Reflection;

namespace MGQOnline.Arena.Tests;

/// <summary>
/// Tests what the arena library depends on.
/// </summary>
public sealed class ReferenceTests
{
    /// <summary>
    /// The arena library references nothing but the BCL.
    /// </summary>
    [Fact]
    public void ReferencesOnlyTheBcl()
    {
        Assembly arena = Assembly.Load("MGQOnline.Arena");

        string[] foreign = arena.GetReferencedAssemblies()
            .Select(reference => reference.Name ?? "")
            .Where(name => !IsBcl(name))
            .ToArray();

        Assert.Empty(foreign);
    }

    /// <summary>
    /// Tells whether an assembly name belongs to the BCL.
    /// </summary>
    /// <param name="name">The assembly name.</param>
    /// <returns>True for the runtime's own assemblies.</returns>
    private static bool IsBcl(string name) =>
        name is "System" or "netstandard" or "mscorlib"
        || name.StartsWith("System.", StringComparison.Ordinal)
        || name.StartsWith("Microsoft.Win32.", StringComparison.Ordinal);
}
