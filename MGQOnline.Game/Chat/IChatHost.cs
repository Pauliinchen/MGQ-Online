//----------------------------------------------------------------
//  IChatHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Chat;

/// <summary>
/// What the chat reaches outside itself: the log, the game's sounds, the notification box and the
/// world connection.
/// </summary>
public interface IChatHost
{
    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line, starting with what wrote it.</param>
    void Log(string line);

    /// <summary>
    /// Plays one of the game's sounds.
    /// </summary>
    /// <param name="name">Its name after <c>Sound.play_</c>, such as "cursor".</param>
    void Sound(string name);

    /// <summary>
    /// Shows a notice of the relay's own in the notification box.
    /// </summary>
    /// <param name="text">The notice.</param>
    void Announce(string text);

    /// <summary>
    /// Sends a line of a chat: the global chat's mirrored to the relay first, which turns down lines
    /// that come too fast.
    /// </summary>
    /// <param name="channel">The chat: "global", "map", "party" or "whisper".</param>
    /// <param name="text">The line.</param>
    /// <param name="seat">The whisper's seat, <see langword="null"/> for the other chats.</param>
    /// <param name="map">The player's map, which the map chat names.</param>
    /// <returns>Whether it went out, and for the global chat what the relay's mirror did: 0 not
    /// mirrored, 1 mirrored, 2 too fast.</returns>
    (bool Sent, int Said) Send(string channel, string text, int? seat, long map);
}
