//----------------------------------------------------------------
//  GameFolderFiles.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.IO;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The data files of a game folder as the game reads them: from Game.rgss3a when the folder has
/// one and it holds the file, else from the loose files.
/// </summary>
public sealed class GameFolderFiles : IGameDataFiles
{
    /// <summary>
    /// The archive the untranslated game keeps its data in; a translation renames it.
    /// </summary>
    public const string ArchiveName = "Game.rgss3a";

    /// <summary>
    /// The game folder.
    /// </summary>
    private readonly string _folder;

    /// <summary>
    /// The folder's archive, <see langword="null"/> without one.
    /// </summary>
    private readonly Rgss3aArchive? _archive;

    /// <summary>
    /// Opens a game folder, and its archive when it has one.
    /// </summary>
    /// <param name="folder">The folder that holds Game.exe, or the battle server's game folder.</param>
    /// <exception cref="InvalidDataException">The folder's archive is damaged.</exception>
    public GameFolderFiles(string folder)
    {
        _folder = folder;
        string archive = Path.Combine(folder, ArchiveName);
        _archive = File.Exists(archive) ? Rgss3aArchive.Open(archive) : null;
    }

    /// <inheritdoc />
    public bool Exists(string path) => (_archive?.Contains(path) ?? false) || File.Exists(Loose(path));

    /// <inheritdoc />
    public byte[] Read(string path) =>
        _archive is not null && _archive.Contains(path) ? _archive.Read(path) : File.ReadAllBytes(Loose(path));

    /// <summary>
    /// Finds a loose file.
    /// </summary>
    /// <param name="path">The file's path in the game folder.</param>
    /// <returns>Its path on disk.</returns>
    private string Loose(string path) => Path.Combine(_folder, path.Replace('\\', '/').TrimStart('/'));
}
