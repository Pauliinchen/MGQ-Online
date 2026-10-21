//----------------------------------------------------------------
//  ReferenceTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests what the update library depends on.
/// </summary>
public sealed class ReferenceTests
{
    /// <summary>
    /// The update library references nothing but the BCL.
    /// </summary>
    [Fact]
    public void ReferencesOnlyTheBcl()
    {
        var foreign = typeof(ReleaseVersion).Assembly.GetReferencedAssemblies()
            .Select(reference => reference.Name ?? string.Empty)
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
