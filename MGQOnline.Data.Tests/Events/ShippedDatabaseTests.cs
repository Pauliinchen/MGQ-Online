//----------------------------------------------------------------
//  ShippedDatabaseTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Pinned the fingerprint of format 2
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Data.Events;

namespace MGQOnline.Data.Tests.Events;

/// <summary>
/// Covers the events database the mod ships, <c>package/Multiplayer/Data/events.db</c>, as the
/// game's DLL opens it: the release's gate against a file generated for another schema or game.
/// </summary>
public sealed class ShippedDatabaseTests
{
    /// <summary>
    /// The fingerprint of the untranslated game 3.06, which the shipped file is generated from and
    /// which the running game writes to <c>Patch/Multiplayer/GameData.ini</c>.
    /// </summary>
    private const string GameFingerprint = "2:2a67edfc.e66a7e3b.780f63eb.e0cc106c.91029dff.d15da834.01b68542.e8cacada.d37476e0.2deb6f76.05a2612e";

    /// <summary>
    /// The shipped file's path below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// Asserts that the shipped file opens read-only and unchanging in the 32-bit process, holds this
    /// code's schema and was generated from the untranslated 3.06.
    /// </summary>
    [Fact]
    public void ShippedFile_IsOfThisSchemaAndTheUntranslatedGame()
    {
        using EventStore store = EventStore.Open(ShippedFile());

        Assert.True(store.Problem is null, store.Problem);
        EventStoreMeta meta = store.Meta!;
        Assert.Equal(EventSchema.Version, meta.SchemaVersion);
        Assert.Equal(GameFingerprint, meta.Build.Fingerprint);
        Assert.Equal(("3.06", "untranslated"), (meta.Build.GameVersion, meta.Build.Source));
    }

    /// <summary>
    /// Finds the shipped file in the repository the tests were built in.
    /// </summary>
    /// <returns>Its full path.</returns>
    private static string ShippedFile()
    {
        for (DirectoryInfo? folder = new(AppContext.BaseDirectory); folder is not null; folder = folder.Parent)
        {
            string path = Path.Combine(folder.FullName, ShippedPath);
            if (File.Exists(path))
            {
                return path;
            }
        }

        throw new FileNotFoundException($"{ShippedPath} is in no folder above {AppContext.BaseDirectory}");
    }
}
