//----------------------------------------------------------------
//  IGameDataFiles.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.IO;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// Where the game's data files come from, by their paths in the game folder such as
/// "Data/Map001.rvdata2".
/// </summary>
public interface IGameDataFiles
{
    /// <summary>
    /// Tells whether a file is there.
    /// </summary>
    /// <param name="path">The file's path in the game folder.</param>
    /// <returns>Whether it is.</returns>
    bool Exists(string path);

    /// <summary>
    /// Reads a file whole.
    /// </summary>
    /// <param name="path">The file's path in the game folder.</param>
    /// <returns>Its bytes.</returns>
    /// <exception cref="FileNotFoundException">The file is not there.</exception>
    byte[] Read(string path);
}
