//----------------------------------------------------------------
//  ChatLine.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Chat;

/// <summary>
/// A line of the chat log.
/// </summary>
/// <param name="Name">The sender's name, <see langword="null"/> for a line of the game's own.</param>
/// <param name="Text">The line.</param>
/// <param name="Who">Whose it is, which colors the name: "me", "member" (of the player's party),
/// "other", "admin" (said through the relay), "system", "notice" (the relay's own) or "help".</param>
/// <param name="Channel">Its chat, one of <see cref="ChatModel.Channels"/>, "help" for a line of the
/// help tab, <see langword="null"/> for a line of the game's own or the relay's notice.</param>
/// <param name="To">Whom the player whispered it to, <see langword="null"/> for any other line.</param>
/// <param name="Id">The sender's player id, for their menu; <see langword="null"/> for the player's
/// own lines, an admin's and the game's.</param>
public sealed record ChatLine(string? Name, string Text, string Who, string? Channel, string? To = null, string? Id = null)
{
    /// <summary>
    /// Gets or sets the frames it still shows while the chat box is closed.
    /// </summary>
    public int Left { get; set; }

    /// <summary>
    /// Gets the tag before the sender's name: the admin's, whom the player whispered to, or the chat's.
    /// </summary>
    public string Tag => Who == "admin" ? ChatModel.AdminTag : To is not null ? $"[To {To}] " : Channel switch
    {
        ChatModel.Map => "[Map] ",
        ChatModel.Party => "[Party] ",
        ChatModel.Whisper => "[Whisper] ",
        _ => string.Empty,
    };

    /// <summary>
    /// Gets what comes before the line itself: the tag and the sender's name, "* " for a line of the
    /// game's own, none for the help's and the relay's notices.
    /// </summary>
    public string Head => Who switch
    {
        "system" => "* ",
        "help" or "notice" => string.Empty,
        _ => $"{Tag}{Name}: ",
    };

    /// <summary>
    /// Reports whether a tab of the log shows the line. The game's own lines show in every tab.
    /// </summary>
    /// <param name="tab">The tab.</param>
    /// <returns>Whether it does.</returns>
    public bool ShownIn(string tab) => tab == ChatModel.All || Channel is null || Channel == tab;

    /// <summary>
    /// Writes the whole line, as the log shows it.
    /// </summary>
    /// <returns>The line.</returns>
    public override string ToString() => Head + Text;
}
