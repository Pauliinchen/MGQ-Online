//----------------------------------------------------------------
//  ICoopHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Coop;

/// <summary>
/// What the co-op battles' matchmaking tells the scripts outside their answers: the notification
/// box's messages.
/// </summary>
public interface ICoopHost
{
    /// <summary>
    /// Shows a message in the notification box, in place of the one of the same key.
    /// </summary>
    /// <param name="key">The message's key, such as "hold" or "soon".</param>
    /// <param name="seat">The seat the key names, <see langword="null"/> for a key of none.</param>
    /// <param name="text">The message.</param>
    /// <param name="frames">How long it shows.</param>
    void Notice(string key, int? seat, string text, int frames);

    /// <summary>
    /// Takes a message of the notification box away.
    /// </summary>
    /// <param name="key">The message's key.</param>
    /// <param name="seat">The seat the key names, <see langword="null"/> for a key of none.</param>
    /// <param name="reason">Why, for the log, <see langword="null"/> for the box's own.</param>
    void DropNotice(string key, int? seat, string? reason);
}
