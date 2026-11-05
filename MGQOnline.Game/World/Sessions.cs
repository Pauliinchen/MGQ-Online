//----------------------------------------------------------------
//  Sessions.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read a battle's players and state as its host tells them, without a reading for games that tell no state
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.World;

/// <summary>
/// The one owner of presence and battle sessions, which every join and invite asks: whom a dropped
/// connection keeps for the grace, whether another player is free or busy, and whether the battle a
/// host tells takes players in, is full, ends or is closed.
/// </summary>
/// <remarks>
/// The grace counts the frames <see cref="Tick"/> is called with, once a bridge frame, so a loaded
/// save never ends or stretches it.
/// </remarks>
public sealed class Sessions
{
    /// <summary>
    /// Frames a player whose connection dropped is kept, fifteen seconds, since the relay ends every
    /// connection after a while and the games connect again at once.
    /// </summary>
    public const int GraceFrames = 900;

    /// <summary>
    /// The state a host tells of a battle that takes players in.
    /// </summary>
    public const string Open = "open";

    /// <summary>
    /// The state a host tells of a battle that has as many players as a battle takes.
    /// </summary>
    public const string Full = "full";

    /// <summary>
    /// The state a host tells of a battle that ends.
    /// </summary>
    public const string Ending = "ending";

    /// <summary>
    /// The state a host tells of a battle that takes nobody in for another reason.
    /// </summary>
    public const string Closed = "closed";

    /// <summary>
    /// What another player does, by their state's scene, while they may be invited to a party
    /// member's battle.
    /// </summary>
    public static readonly IReadOnlyList<string> FreeScenes = ["map", "event", "away"];

    /// <summary>
    /// What another player in a Raid World does, by their state's scene, while they may be invited.
    /// </summary>
    public static readonly IReadOnlyList<string> RaidFreeScenes = ["map", "away"];

    /// <summary>
    /// What another player does, by their state's scene, while they fight a battle.
    /// </summary>
    public static readonly IReadOnlyList<string> BattleScenes = ["battle", "away"];

    /// <summary>
    /// The frames each player away is still kept for, by their key, in the order they went away.
    /// </summary>
    private readonly List<(string Key, int Left)> away = [];

    /// <summary>
    /// Gets a value indicating whether nobody is kept away.
    /// </summary>
    public bool NobodyAway => away.Count == 0;

    /// <summary>
    /// Starts the grace of a player whose connection dropped.
    /// </summary>
    /// <param name="key">The player, by their id.</param>
    /// <returns>Whether the grace started, false for a player already away.</returns>
    public bool Away(string key)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (IsAway(key))
        {
            return false;
        }

        away.Add((key, GraceFrames));
        return true;
    }

    /// <summary>
    /// Takes back a player whose connection came back.
    /// </summary>
    /// <param name="key">The player.</param>
    /// <returns>The frames they were away, <see langword="null"/> for a player not kept away.</returns>
    public int? Back(string key)
    {
        int at = away.FindIndex(entry => entry.Key == key);
        if (at < 0)
        {
            return null;
        }

        int left = away[at].Left;
        away.RemoveAt(at);
        return GraceFrames - left;
    }

    /// <summary>
    /// Reports whether a player is kept away.
    /// </summary>
    /// <param name="key">The player.</param>
    /// <returns>Whether they are.</returns>
    public bool IsAway(string key) => away.Exists(entry => entry.Key == key);

    /// <summary>
    /// Counts a frame of the grace and forgets the players who stayed away for all of it.
    /// </summary>
    /// <returns>The players whose grace ran out, in the order they went away.</returns>
    public List<string> Tick()
    {
        var lapsed = new List<string>();
        for (int index = 0; index < away.Count; index++)
        {
            (string key, int left) = away[index];
            away[index] = (key, left - 1);
            if (left - 1 <= 0)
            {
                lapsed.Add(key);
            }
        }

        away.RemoveAll(entry => entry.Left <= 0);
        return lapsed;
    }

    /// <summary>
    /// Forgets a player, as once they left for good.
    /// </summary>
    /// <param name="key">The player.</param>
    public void Forget(string key) => away.RemoveAll(entry => entry.Key == key);

    /// <summary>
    /// Forgets every player away, as once the world closed.
    /// </summary>
    public void Clear() => away.Clear();

    /// <summary>
    /// Writes frames as the whole seconds the log reads.
    /// </summary>
    /// <param name="frames">The frames.</param>
    /// <returns>The seconds.</returns>
    public static string Seconds(long frames) => (frames / GameClock.FramesPerSecond).ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Reports whether another player fights a battle, as their state says: it names the battle and
    /// its scene is a battle's.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they do.</returns>
    public static bool Fights(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return !string.IsNullOrEmpty(peer.State["rb"]) && BattleScenes.Contains(peer.State["scene"]);
    }

    /// <summary>
    /// Reports whether another player in a Raid World may be invited: walking the map, or on it with
    /// their window in the background, and neither fighting a battle, trading nor about to teleport.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they may.</returns>
    public static bool RaidFree(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return RaidFreeScenes.Contains(peer.State["scene"]) && peer.State["busy"] != "1" && !Fights(peer);
    }

    /// <summary>
    /// Reports whether a party member may join a battle at once: on the map, in an event or with
    /// their window in the background.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>Whether they may.</returns>
    public static bool Free(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return FreeScenes.Contains(peer.State["scene"]);
    }

    /// <summary>
    /// Reports whether a party member is busy with something they come back from on their own, such
    /// as a menu, typing or a vehicle, but not a battle of their own.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>Whether they are.</returns>
    public static bool Busy(Peer peer) => !Free(peer) && peer.State["scene"] != "battle";

    /// <summary>
    /// Reports whether a party member is invited to a battle the player hosts in a Classic world: one
    /// free or busy, who keeps the invite until they are free; not one in a battle of their own, who
    /// may join late once it ended.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>Whether they are.</returns>
    public static bool Invited(Peer peer) => Free(peer) || Busy(peer);

    /// <summary>
    /// Reads the battle a host tells in their state: "rb", "rbn" (its players) and "rbs" (whether
    /// it takes players in).
    /// </summary>
    /// <param name="host">The battle's host.</param>
    /// <returns>The battle.</returns>
    public static BattleSession Battle(Peer host)
    {
        ArgumentNullException.ThrowIfNull(host);
        return new BattleSession(host.State.Text("rb"), (int)WorldFields.ToI(host.State["rbn"]), host.State.Text("rbs"));
    }

    /// <summary>
    /// Tells a player why a battle near them does not take them in.
    /// </summary>
    /// <param name="name">The battle's host.</param>
    /// <param name="state">The battle's state.</param>
    /// <returns>The message.</returns>
    public static string NotTakenText(string name, string state) => state switch
    {
        Full => $"{name}'s battle is full.",
        Ending => $"{name}'s battle is ending.",
        "gathering" => $"{name}'s battle is still gathering its players.",
        _ => $"{name}'s battle takes nobody in now.",
    };
}

/// <summary>
/// The battle a host tells in their state.
/// </summary>
/// <param name="Bid">The battle's id, empty outside a battle.</param>
/// <param name="Players">Its players, those taken in counted; 0 when the host hosts no battle or fights none alone.</param>
/// <param name="State">Whether it takes players in: <see cref="Sessions.Open"/>, <see cref="Sessions.Full"/>,
/// <see cref="Sessions.Ending"/>, "gathering", "pvp" or <see cref="Sessions.Closed"/>.</param>
public sealed record BattleSession(string Bid, int Players, string State)
{
    /// <summary>
    /// Gets a value indicating whether the battle takes players in.
    /// </summary>
    public bool Open => State == Sessions.Open && Players >= 1 && Players < Party.MaxPlayers;

    /// <summary>
    /// Gets a value indicating whether the battle has as many players as a battle takes, so a side
    /// battle may start beside it.
    /// </summary>
    public bool Full => State == Sessions.Full;

    /// <summary>
    /// Gets the players the battle still takes in, 0 while it takes nobody.
    /// </summary>
    public int Room => Open ? Party.MaxPlayers - Players : 0;
}
