//----------------------------------------------------------------
//  CoopOffer.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Carried the message a step takes and left the waiting invite to the matchmaking
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Coop;

/// <summary>
/// An invite to another battle that waits for the player to be free, as the matchmaking reads it
/// when the player hosts a battle in a Raid World.
/// </summary>
/// <param name="Seat">Its host's seat.</param>
/// <param name="Hot">Whether it is to a battle that runs already.</param>
/// <param name="Expired">Whether it waited too long.</param>
/// <param name="Rival">Whether it comes from a rival, whose battle the player's yields to.</param>
public sealed record WaitingInvite(int Seat, bool Hot, bool Expired, bool Rival);

/// <summary>
/// What the game tells of a battle it just set up, or of a battle the player hosts after all.
/// </summary>
/// <param name="Troop">The troop.</param>
/// <param name="Escape">Whether the party may escape.</param>
/// <param name="Lose">Whether losing goes on without a game over.</param>
/// <param name="Encounter">Whether the battle is a random encounter.</param>
/// <param name="Encountering">Whether the game's random encounter set it up just now, which may hold it.</param>
/// <param name="Joining">Whether the player joins another battle with it.</param>
/// <param name="AskedHot">Whether the player asked a running battle to take it in, which did not.</param>
/// <param name="Side">Whether it is a side battle against a raid boss, fought as the player's own.</param>
/// <param name="PoolsWon">Whether it fights a raid boss whose pools are all empty already.</param>
/// <param name="Boss">Whether it is a boss battle.</param>
/// <param name="Rates">The enemies' rates the player's game fights with, as an invite carries them.</param>
/// <param name="InviteFields">The fields the raid bosses add to its invite, in order.</param>
/// <param name="Viewers">The seats of the players reading the story the player tells on the map.</param>
/// <param name="Leading">The member and battle id of a battle the player leads for that member, <see langword="null"/> for none.</param>
/// <param name="StaysOut">The seats of the party members who said no to starting a battle with the player.</param>
public sealed record CoopOffer(
    int Troop,
    bool Escape,
    bool Lose,
    bool Encounter,
    bool Encountering,
    bool Joining,
    bool AskedHot,
    bool Side,
    bool PoolsWon,
    bool Boss,
    string Rates,
    IReadOnlyList<KeyValuePair<string, string>> InviteFields,
    IReadOnlyList<int> Viewers,
    (int Seat, string BattleId)? Leading,
    IReadOnlyList<int> StaysOut);

/// <summary>
/// What the scripts do after the matchmaking decided: a step only the game can take.
/// </summary>
/// <param name="Kind">What: "join" (the battle becomes live with <see cref="Role"/>, <see cref="BattleId"/>,
/// <see cref="Seats"/> and <see cref="Label"/>, the multiplayer rules on), "fight_alone" (a Raid World's
/// battle nobody joined goes on as the player's own), "ask_hot" (ask a running battle to take the
/// encounter in), "start_held" (start the held encounter of <see cref="Troop"/>), "held", "accept" (join
/// the invite in <see cref="Fields"/> of the host at <see cref="Seat"/>, <see cref="Label"/> "story" for
/// the battle of the story that calls the player), "lead" (lead the request in <see cref="Fields"/>),
/// "follow" and "yield" (become the guest of the battle in <see cref="Fields"/>, whose host is at
/// <see cref="Seat"/> and named <see cref="Label"/>), "call_off_own", "miss" or "break_off" (with
/// what the player is told or why, in <see cref="Label"/>).</param>
/// <param name="Role">The live battle's role.</param>
/// <param name="BattleId">The battle's id.</param>
/// <param name="Seats">The other games' seats.</param>
/// <param name="Label">Who the waits name.</param>
/// <param name="Seat">A player's seat.</param>
/// <param name="Troop">The troop.</param>
/// <param name="Escape">Whether the party may escape.</param>
/// <param name="Lose">Whether losing goes on without a game over.</param>
/// <param name="Fields">The message of another game the step takes, such as an invite.</param>
public sealed record CoopAction(
    string Kind,
    string? Role = null,
    string? BattleId = null,
    IReadOnlyList<int>? Seats = null,
    string? Label = null,
    int? Seat = null,
    int? Troop = null,
    bool Escape = false,
    bool Lose = false,
    MGQOnline.Game.World.WorldFields? Fields = null);
