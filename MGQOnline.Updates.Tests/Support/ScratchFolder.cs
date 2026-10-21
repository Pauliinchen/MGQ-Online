//----------------------------------------------------------------
//  ScratchFolder.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQOnline.Updates.Tests.Support;

/// <summary>
/// A new empty folder in the temp folder, deleted with everything in it when disposed.
/// </summary>
internal sealed class ScratchFolder : IDisposable
{
    /// <summary>
    /// Creates the folder.
    /// </summary>
    public ScratchFolder()
    {
        Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "mgq-updates-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path);
    }

    /// <summary>
    /// The folder's path.
    /// </summary>
    public string Path { get; }

    /// <summary>
    /// Names a file in the folder.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <returns>The file's path.</returns>
    public string File(string name) => System.IO.Path.Combine(Path, name);

    /// <summary>
    /// Writes a text file in the folder.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <param name="text">The file's text.</param>
    /// <returns>The file's path.</returns>
    public string Write(string name, string text)
    {
        var path = File(name);
        System.IO.File.WriteAllText(path, text);
        return path;
    }

    /// <inheritdoc />
    public void Dispose()
    {
        try
        {
            Directory.Delete(Path, recursive: true);
        }
        catch (IOException)
        {
        }
    }
}
