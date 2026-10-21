//----------------------------------------------------------------
//  UpdateRefusedException.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Updates;

/// <summary>
/// Thrown when a release, its manifest, its signature or a downloaded file is not trusted, or when
/// the exe swap cannot be done; nothing is installed then.
/// </summary>
public sealed class UpdateRefusedException : Exception
{
    /// <summary>
    /// Creates the exception with the reason for the refusal.
    /// </summary>
    /// <param name="message">Why the update was refused.</param>
    public UpdateRefusedException(string message)
        : base(message)
    {
    }

    /// <summary>
    /// Creates the exception with the reason for the refusal and the error behind it.
    /// </summary>
    /// <param name="message">Why the update was refused.</param>
    /// <param name="innerException">The error that caused the refusal.</param>
    public UpdateRefusedException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
