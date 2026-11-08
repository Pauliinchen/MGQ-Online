//----------------------------------------------------------------
//  ParkedLeftovers.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;

namespace MGQOnline.Multiplayer.Mods;

/// <summary>
/// Puts back the mods an older release left parked: until the Mod Framework loaded a world's mods,
/// a world that turns other mods off moved the player's other scripts into the game folder's
/// "Parked mods", and a game that closed before they came back left them there.
/// </summary>
internal static class ParkedLeftovers
{
    /// <summary>
    /// The folder in the game folder older releases parked mods in, each at its path from the game folder.
    /// </summary>
    public const string FolderName = "Parked mods";

    /// <summary>
    /// The list of the parked mods older releases kept in <see cref="FolderName"/>.
    /// </summary>
    public const string JournalName = "Parked.txt";

    /// <summary>
    /// The folder of the game the mods belong in.
    /// </summary>
    private const string PatchName = "Patch";

    /// <summary>
    /// Moves every parked file back into Patch where no other file took its place, and removes the
    /// journal and the folders once nothing is left parked.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>How many files came back; files whose place is taken stay and are logged.</returns>
    public static int PutBack(string gameFolder)
    {
        string game = Path.GetFullPath(gameFolder);
        string parked = Path.Combine(game, FolderName, PatchName);
        if (!Directory.Exists(parked))
        {
            return 0;
        }

        int back = 0;
        int kept = 0;
        foreach (string file in Directory.EnumerateFiles(parked, "*", SearchOption.AllDirectories).ToList())
        {
            string target = Path.Combine(game, PatchName, Path.GetRelativePath(parked, file));
            try
            {
                if (File.Exists(target))
                {
                    kept++;
                    Log.Write($"parked {Path.GetRelativePath(game, file)} stays, since another file took its place in Patch");
                    continue;
                }

                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Move(file, target);
                back++;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                kept++;
                Log.Write($"parked {Path.GetRelativePath(game, file)} could not come back: {ex.Message}");
            }
        }

        if (kept == 0)
        {
            Tidy(Path.Combine(game, FolderName));
        }

        Log.Write($"put back {back} mod file(s) an older release left parked{(kept > 0 ? $", {kept} stay in {FolderName}" : string.Empty)}");
        return back;
    }

    /// <summary>
    /// Removes the journal and every empty folder of the parked mods.
    /// </summary>
    /// <param name="folder">The parked mods' folder.</param>
    private static void Tidy(string folder)
    {
        try
        {
            File.Delete(Path.Combine(folder, JournalName));
            foreach (string empty in Directory.EnumerateDirectories(folder, "*", SearchOption.AllDirectories).OrderByDescending(path => path.Length).ToList())
            {
                if (!Directory.EnumerateFileSystemEntries(empty).Any())
                {
                    Directory.Delete(empty);
                }
            }

            if (!Directory.EnumerateFileSystemEntries(folder).Any())
            {
                Directory.Delete(folder);
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"the parked mods' folder could not be tidied: {ex.Message}");
        }
    }
}
