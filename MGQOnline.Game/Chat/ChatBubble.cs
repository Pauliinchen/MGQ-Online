//----------------------------------------------------------------
//  ChatBubble.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Chat;

/// <summary>
/// A bubble above a sender's head: their last chat line, in its chat's color.
/// </summary>
/// <param name="Seat">The sender's seat, <see cref="ChatModel.OwnSeat"/> for the player.</param>
/// <param name="Text">The line.</param>
/// <param name="Channel">Its chat, one of <see cref="ChatModel.Channels"/>.</param>
public sealed record ChatBubble(int Seat, string Text, string Channel)
{
    /// <summary>
    /// Gets or sets the frames it still shows.
    /// </summary>
    public int Left { get; set; }
}
