//----------------------------------------------------------------
//  FileHash.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace MGQOnline.Updates;

/// <summary>
/// SHA-256 of files and the staged download of a release file.
/// </summary>
public static class FileHash
{
    /// <summary>
    /// The size of the buffer a download is copied through.
    /// </summary>
    private const int CopyBufferSize = 81920;

    /// <summary>
    /// Computes a file's SHA-256.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>The SHA-256 as 64 lowercase hex digits.</returns>
    public static string Sha256Of(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexStringLower(SHA256.HashData(stream));
    }

    /// <summary>
    /// Computes the running program's SHA-256.
    /// </summary>
    /// <returns>The SHA-256, or null when the program's file cannot be read.</returns>
    public static string? Sha256OfRunningProgram()
    {
        try
        {
            return Environment.ProcessPath is { } path ? Sha256Of(path) : null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>
    /// Writes a download to a file and keeps it only when its length and SHA-256 are the expected ones.
    /// </summary>
    /// <param name="source">The download.</param>
    /// <param name="path">The file to write, like <c>RaidDesigner.exe.new</c>; an earlier one is replaced.</param>
    /// <param name="expected">The file as the verified manifest lists it.</param>
    /// <param name="cancellationToken">Stops the download.</param>
    /// <returns>A task that ends once the file is written and checked.</returns>
    /// <exception cref="UpdateRefusedException">The download has another length or SHA-256; the file is deleted.</exception>
    public static async Task SaveCheckedAsync(Stream source, string path, ManifestFile expected, CancellationToken cancellationToken)
    {
        var kept = false;

        try
        {
            using (var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
            await using (var target = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                var buffer = new byte[CopyBufferSize];
                long length = 0;
                int read;

                while ((read = await source.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
                {
                    length += read;

                    if (length > expected.Size)
                    {
                        throw new UpdateRefusedException($"The download of {expected.Name} is longer than the manifest says.");
                    }

                    hash.AppendData(buffer, 0, read);
                    await target.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
                }

                if (length != expected.Size)
                {
                    throw new UpdateRefusedException($"The download of {expected.Name} is shorter than the manifest says.");
                }

                if (!string.Equals(Convert.ToHexStringLower(hash.GetHashAndReset()), expected.Sha256, StringComparison.OrdinalIgnoreCase))
                {
                    throw new UpdateRefusedException($"The download of {expected.Name} has another SHA-256 than the manifest says.");
                }
            }

            kept = true;
        }
        finally
        {
            if (!kept)
            {
                DeleteQuietly(path);
            }
        }
    }

    /// <summary>
    /// Deletes a refused download without hiding the reason it was refused.
    /// </summary>
    /// <param name="path">The file.</param>
    private static void DeleteQuietly(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
        }
    }
}
