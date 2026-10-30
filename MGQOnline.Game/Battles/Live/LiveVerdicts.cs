//----------------------------------------------------------------
//  LiveVerdicts.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// How a live battle ends, as battles_sync_live.rbx decided it: early, as the host's battle ended,
/// or once the other side is gone. The scripts call the game's ending and show the message.
/// </summary>
public static class LiveVerdicts
{
    /// <summary>
    /// The ending of a battle the other side forfeited, and the message that tells it.
    /// </summary>
    public const string Forfeit = "forfeit";

    /// <summary>
    /// The ending of a battle either game broke off, and the message that tells it.
    /// </summary>
    public const string Broken = "broken";

    /// <summary>
    /// The ending of a battle whose other side is gone.
    /// </summary>
    public const string Gone = "gone";

    /// <summary>
    /// The game's victory.
    /// </summary>
    public const string Victory = "process_victory";

    /// <summary>
    /// The game's defeat.
    /// </summary>
    public const string Defeat = "process_defeat";

    /// <summary>
    /// The game's abort, an ending without a winner.
    /// </summary>
    public const string Abort = "process_abort";

    /// <summary>
    /// Why a live battle ends early, by the reason, for the log.
    /// </summary>
    private static readonly Dictionary<string, string> EndReasons = new(StringComparer.Ordinal)
    {
        ["left"] = "this player left it",
        [Forfeit] = "the other side forfeited",
        [Broken] = "it broke off",
        [Gone] = "the other side is gone",
        ["won"] = "its enemies fell while it waited for commands",
    };

    /// <summary>
    /// Tells why a live battle ends early, for the log.
    /// </summary>
    /// <param name="reason">The reason, such as "forfeit".</param>
    /// <returns>Why, the reason itself for one the battle does not know.</returns>
    public static string ReasonText(string reason) => EndReasons.TryGetValue(reason, out string? text) ? text : reason;

    /// <summary>
    /// Ends a battle before its course did.
    /// </summary>
    /// <param name="reason">"left" when this player left, "won" when the enemies fell during the
    /// host's wait for commands, or an ending of <see cref="LiveSession.Tick"/>.</param>
    /// <param name="sideForfeits">Whether a forfeit is this game's side's, on the host's side of a team duel.</param>
    /// <param name="player">Who the waits name.</param>
    /// <returns>The ending: "win" or "forfeit" for the scripts' own steps, "gone" for
    /// <see cref="FriendGone"/>, else the game's ending with its message.</returns>
    public static LiveEnd EndEarly(string reason, bool sideForfeits, string player) => reason switch
    {
        "won" => new LiveEnd("win"),
        "left" => new LiveEnd("forfeit"),
        Forfeit => new LiveEnd(sideForfeits ? Defeat : Victory, Message: $"{player} forfeited."),
        Broken => new LiveEnd(Abort, Message: "The battle broke off."),
        _ => new LiveEnd(Gone),
    };

    /// <summary>
    /// Ends the guest's battle the way the host's ended: as it ended on the host's side, else seen
    /// from the other side.
    /// </summary>
    /// <param name="result">How the host's battle ended, such as "process_victory".</param>
    /// <param name="sameSide">Whether this game fought on the host's side.</param>
    /// <param name="player">Who the waits name.</param>
    /// <returns>The line logged and the ending: on the host's side another ending tries the battle's
    /// take over first, see <see cref="LiveEnd.Otherwise"/>.</returns>
    public static (string Log, LiveEnd End) GuestEnd(string result, bool sameSide, string player)
    {
        ArgumentNullException.ThrowIfNull(result);
        string log = $"the host's battle ended ({result}), this game fought {(sameSide ? "on the host's side" : "against the host")}";
        LiveEnd end = (sameSide, result) switch
        {
            (true, Victory or Defeat) => new LiveEnd(result),
            (true, _) => new LiveEnd("take_over", Otherwise: new LiveEnd(Abort, "the host left the team duel: it ends without a winner", $"{player} left the duel.")),
            (false, Victory) => new LiveEnd(Defeat),
            (false, Defeat) => new LiveEnd(Victory),
            _ => new LiveEnd(Victory, $"{player} gave up or left: this game wins", $"{player} forfeited."),
        };
        return (log, end);
    }

    /// <summary>
    /// Ends the battle once the other side is gone: a co-op host plays on alone, a guest takes the
    /// battle over when its mode can; otherwise a team duel's host wins and a guest on its side
    /// ends without a winner, and any other game wins.
    /// </summary>
    /// <param name="session">The session, which plays on alone as a co-op host.</param>
    /// <param name="sameSide">Whether this game fights on the host's side.</param>
    /// <returns>"solo", or the take over with the ending otherwise.</returns>
    public static LiveEnd FriendGone(LiveSession session, bool sameSide)
    {
        ArgumentNullException.ThrowIfNull(session);
        if (session.IsHost && session.Coop)
        {
            session.PlaySolo();
            return new LiveEnd("solo");
        }

        string player = session.Player;
        LiveEnd otherwise = session.TeamDuel && (session.IsHost || sameSide)
            ? session.IsHost
                ? new LiveEnd(Victory, "everyone on the other side left: the host's side wins", "Everyone on the other side left.")
                : new LiveEnd(Abort, "the host left the team duel: it ends without a winner", $"{player} left the duel.")
            : new LiveEnd(Victory, $"{player} left: this game wins", $"{player} left the battle.");
        return new LiveEnd("take_over", Otherwise: otherwise);
    }

    /// <summary>
    /// Reads seats joined by commas, as the script's split(",").map(&amp;:to_i) read them.
    /// </summary>
    /// <param name="text">The seats.</param>
    /// <returns>The seats, 0 for a part that is no number.</returns>
    public static List<int> SeatsOf(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        List<string> parts = text.Split(',').ToList();
        while (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        return parts.Select(part => (int)BigInteger.Clamp(RubyNumbers.ToI(Encoding.UTF8.GetBytes(part)), int.MinValue, int.MaxValue)).ToList();
    }
}
