//----------------------------------------------------------------
//  ParkingSession.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// How parking a world's scripts and starting the game again for it went.
/// </summary>
internal enum JoinResult
{
    /// <summary>
    /// The game closes now and starts again into the world.
    /// </summary>
    Restarting,

    /// <summary>
    /// The game could not start again; the scripts came back.
    /// </summary>
    Failed,

    /// <summary>
    /// The scripts could not be moved; those moved came back.
    /// </summary>
    NotParked,

    /// <summary>
    /// Another game of this folder holds the parked scripts.
    /// </summary>
    Held,
}

/// <summary>
/// How starting the game again for a world's downloaded mods went.
/// </summary>
internal enum ModsRestart
{
    /// <summary>
    /// The world's lock must open first, since a password does not survive the restart.
    /// </summary>
    Unlock,

    /// <summary>
    /// The game closes now and starts again into the world.
    /// </summary>
    Restarting,

    /// <summary>
    /// The game could not start again; the player starts it by hand.
    /// </summary>
    ByHand,

    /// <summary>
    /// The other mods could not be turned off, kept off or turned back on, so the game stays open.
    /// </summary>
    NotKept,
}

/// <summary>
/// What the open world's directory tells the parked mods: how its list stands and a world in it.
/// </summary>
internal interface IParkingDirectory
{
    /// <summary>
    /// Tells whether the list is being fetched.
    /// </summary>
    bool Listing { get; }

    /// <summary>
    /// Fetches the list and the catalog again, unless they are being fetched.
    /// </summary>
    void Refresh();

    /// <summary>
    /// Reads whether a world turns other mods off and its mods from the list.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <returns>Both; <see langword="null"/> when the list did not arrive or lacks the world or its mods.</returns>
    (bool OtherModsOff, string Mods)? RuleOf(string world);
}

/// <summary>
/// Turning other mods off in one game session: which scripts a world parks and when, the start after
/// a restart, the way back to the title screen, saving while mods are off, and a world that turns
/// other mods off now. <see cref="ModParking"/> moves the files; the scripts show the boxes.
/// </summary>
internal sealed class ParkingSession
{
    /// <summary>
    /// The setting in Player.ini that names the world the next start enters again.
    /// </summary>
    public const string RejoinSetting = "rejoin";

    /// <summary>
    /// The setting in Player.ini that tells the start after the last restart to turn the mods back on.
    /// </summary>
    /// <remarks>
    /// A restore that keeps failing would otherwise restart the game over and over.
    /// </remarks>
    public const string RestartedSetting = "mods_back_restart";

    /// <summary>
    /// Frames the open world waits for the list it asked for to check its mods, ten seconds.
    /// </summary>
    public const int RecheckFrames = 600;

    /// <summary>
    /// Frames between two looks at whether that list arrived, a quarter of a second.
    /// </summary>
    public const int RecheckStep = 15;

    /// <summary>
    /// What recover answers when the parked scripts stay parked for the world the start enters again.
    /// </summary>
    private const int RecoverKept = 2;

    /// <summary>
    /// What recover answers when the scripts a closed game left parked came back.
    /// </summary>
    private const int RecoverRestored = 1;

    /// <summary>
    /// What recover and restore answer when a script could not be moved.
    /// </summary>
    private const int MoveFailed = -1;

    /// <summary>
    /// The parking of the game folder, which moves the files.
    /// </summary>
    private readonly ModParking _parking;

    /// <summary>
    /// The Player.ini the world to enter again is kept in.
    /// </summary>
    private readonly PlayerIni _player;

    /// <summary>
    /// Gives the keys of the personal mods, <see langword="null"/> while the catalog is unknown.
    /// </summary>
    private readonly Func<IReadOnlyCollection<string>?> _personal;

    /// <summary>
    /// Starts the game again with the mods parked, the world and whether it enters it: whether the
    /// watchdog waits for this game to close.
    /// </summary>
    private readonly Func<string, bool, bool> _restartParked;

    /// <summary>
    /// Starts the game again: whether the helper waits for this game to close.
    /// </summary>
    private readonly Func<bool> _restartGame;

    /// <summary>
    /// The world directory the open world is checked against again.
    /// </summary>
    private readonly IParkingDirectory _directory;

    /// <summary>
    /// The parked scripts read last, which stand in while the journal cannot be read.
    /// </summary>
    private ModParking.ParkedState? _lastParked;

    /// <summary>
    /// The keys of the scripts parked as this session started, before it moved any.
    /// </summary>
    private List<string>? _startParked;

    /// <summary>
    /// The failures logged once a session.
    /// </summary>
    private readonly HashSet<string> _logged = new(StringComparer.Ordinal);

    /// <summary>
    /// Whether the parked scripts are this session's: it parked them, or its start kept them.
    /// </summary>
    private bool _owned;

    /// <summary>
    /// The world this start entered again with its mods parked, until it is entered or given up.
    /// </summary>
    private string? _hold;

    /// <summary>
    /// Whether the start's recovery left the parked scripts parked.
    /// </summary>
    private bool _keptAtStart;

    /// <summary>
    /// The title screens this session started.
    /// </summary>
    private int _titleStarts;

    /// <summary>
    /// Whether the start's recovery ran.
    /// </summary>
    private bool _started;

    /// <summary>
    /// The open world's check against a list fetched for it, <see langword="null"/> while none waits.
    /// </summary>
    private Recheck? _recheck;

    /// <summary>
    /// What a player in a world that now turns their mods off is told, until the scripts take it.
    /// </summary>
    private string? _kick;

    /// <summary>
    /// Creates the session.
    /// </summary>
    /// <param name="parking">The parking of the game folder.</param>
    /// <param name="player">The Player.ini of the game.</param>
    /// <param name="personal">Gives the keys of the personal mods, <see langword="null"/> while the catalog is unknown.</param>
    /// <param name="restartParked">Starts the game again with the mods parked: the world, whether it enters it; whether the watchdog waits.</param>
    /// <param name="restartGame">Starts the game again: whether the helper waits.</param>
    /// <param name="directory">The world directory.</param>
    public ParkingSession(ModParking parking, PlayerIni player, Func<IReadOnlyCollection<string>?> personal, Func<string, bool, bool> restartParked, Func<bool> restartGame, IParkingDirectory directory)
    {
        _parking = parking;
        _player = player;
        _personal = personal;
        _restartParked = restartParked;
        _restartGame = restartGame;
        _directory = directory;
    }

    /// <summary>
    /// Gets whether the game started again to enter a world with its mods parked and has not entered
    /// it yet.
    /// </summary>
    public bool Holding => _hold != null;

    /// <summary>
    /// Gets what the title screen says before it starts the game again, <see langword="null"/> while it
    /// is not about to.
    /// </summary>
    public string? Due { get; private set; }

    /// <summary>
    /// Gets what the title screen tells the player until they close it, <see langword="null"/> for nothing.
    /// </summary>
    public string? Notice { get; private set; }

    /// <summary>
    /// Gets whether scripts were moved since the scripts last asked, so they read the Patch folder anew.
    /// </summary>
    public bool Moved { get; private set; }

    /// <summary>
    /// Gets whether saving outside a world is off: while this session runs without some of the player's
    /// mods, as it started with them parked, or while mods are parked.
    /// </summary>
    /// <remarks>
    /// A save made without a mod loses what the mod keeps in it, and a session goes on without the mods
    /// after a restore failed.
    /// </remarks>
    public bool SavingOff => _startParked is { Count: > 0 } || ParkedNow().Files.Count > 0;

    /// <summary>
    /// Takes whether scripts were moved since the last look.
    /// </summary>
    /// <returns>Whether they were.</returns>
    public bool TakeMoved()
    {
        bool moved = Moved;
        Moved = false;
        return moved;
    }

    /// <summary>
    /// Reads what the game knows of its scripts.
    /// </summary>
    /// <returns>The facts.</returns>
    public ParkingFacts Facts()
    {
        ModParking.ScriptList? listed = _parking.Listed();
        if (listed == null)
        {
            LogOnce("scripts", "the scripts of the Patch folder could not be listed");
        }

        ModParking.ParkedState parked = ParkedNow();
        List<string>? scripts = listed == null ? null : ParkingRules.Distinct(listed.Patch.Concat(listed.Parked)).ToList();
        return new ParkingFacts(scripts, listed?.Elsewhere, _personal(), parked.World, parked.Files, MovedHere());
    }

    /// <summary>
    /// Tells what has to change before the game may enter a world, see <see cref="ParkingRules.Change"/>.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <param name="mods">Its mods as its creator wrote them.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>The change.</returns>
    public ParkingChange Change(string world, string? mods, bool otherModsOff)
    {
        ParkingFacts facts = Facts();
        ParkingChange change = ParkingRules.Change(facts, world, mods, otherModsOff);
        if (change.Kind == ParkingKind.None && otherModsOff && ParkingRules.Plan(facts, mods, otherModsOff) == null)
        {
            LogOnce("catalog", $"the catalog is unknown, so the mods parked for world {Log.Short(world)} stay as they are");
        }

        return change;
    }

    /// <summary>
    /// Tells whether this session runs with a world's other mods turned off, as the start after the
    /// parking restart does.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>Whether it does.</returns>
    public bool ParkedFor(string world, bool otherModsOff)
    {
        ModParking.ParkedState parked = ParkedNow();
        return otherModsOff && parked.Files.Count > 0 && parked.World == world && !MovedHere();
    }

    /// <summary>
    /// Has the journal name the world the game is about to enter, or start again into, when the mods
    /// parked for another world are exactly those this one turns off.
    /// </summary>
    /// <remarks>
    /// The start after a restart keeps the mods parked only for the world the journal names.
    /// </remarks>
    /// <param name="world">The world's id.</param>
    /// <param name="mods">Its mods.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>Whether the journal names the world now.</returns>
    public bool Claim(string world, string? mods, bool otherModsOff)
    {
        ModParking.ParkedState parked = ParkedNow();
        if (parked.Files.Count == 0)
        {
            return false;
        }

        if (parked.World == world)
        {
            return true;
        }

        IReadOnlyList<string>? plan = ParkingRules.Plan(Facts(), mods, otherModsOff);
        if (plan == null || !ParkingRules.SameScripts(plan, parked.Files))
        {
            return false;
        }

        Write($"the mods parked for world {Log.Short(parked.World)} are those world {Log.Short(world)} turns off, parking them for it");
        return Park(plan, world) && ParkedNow().World == world;
    }

    /// <summary>
    /// Parks a world's scripts and starts the game again to enter it, which Player.ini's rejoin tells
    /// the next start; puts them back when the game cannot start again.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <param name="plan">The scripts to park, none to put every parked one back.</param>
    /// <returns>How it went.</returns>
    public JoinResult Join(string world, IReadOnlyList<string> plan)
    {
        if (plan.Count == 0)
        {
            int count = Restore(false);
            return count == ModParking.HeldElsewhere ? JoinResult.Held : count < 0 ? JoinResult.NotParked : Rejoin(world) ? JoinResult.Restarting : JoinResult.Failed;
        }

        if (!Park(plan, world))
        {
            // A park that moved only some would leave a journal that every later start acts on.
            if (ParkedNow().Files.Count > 0)
            {
                Restore(false);
            }

            return JoinResult.NotParked;
        }

        if (RejoinParked(world))
        {
            return JoinResult.Restarting;
        }

        Restore(false);
        return JoinResult.Failed;
    }

    /// <summary>
    /// Starts the game again once a world's mods are installed, turning other mods off first for a
    /// world that turns them off, so one restart does both, or keeping those parked for it through the
    /// watchdog's restart.
    /// </summary>
    /// <remarks>
    /// A plain restart would leave parked mods to the watchdog, which puts them back while the next
    /// start loads, so while mods stay parked without a restart that keeps them, the game stays open.
    /// </remarks>
    /// <param name="world">The world's id.</param>
    /// <param name="rule">Whether the world turns other mods off and its mods; <see langword="null"/> when the list lacks it.</param>
    /// <param name="unlocked">Whether this PC holds the world's code, or it has no password.</param>
    /// <returns>How it went, and the change it made for the world (<see langword="null"/> without a rule).</returns>
    public (ModsRestart Result, ParkingChange? Change) RestartForMods(string world, (bool OtherModsOff, string Mods)? rule, bool unlocked)
    {
        ParkingChange? change = rule is { } known ? Change(world, known.Mods, known.OtherModsOff) : null;
        bool planned = change?.Kind == ParkingKind.Plan;
        if (planned && change!.Plan.Count > 0 && !unlocked)
        {
            return (ModsRestart.Unlock, change);
        }

        bool claimed = !planned && change?.Kind != ParkingKind.Elsewhere && rule is { } claimable && Claim(world, claimable.Mods, claimable.OtherModsOff);
        JoinResult? result = planned ? Join(world, change!.Plan)
            : claimed ? (RejoinParked(world) ? JoinResult.Restarting : JoinResult.Failed)
            : ParkedNow().Files.Count > 0 ? null
            : Rejoin(world) ? JoinResult.Restarting : JoinResult.Failed;
        if (result == JoinResult.NotParked && ParkedNow().Files.Count > 0)
        {
            result = null;
        }

        if (result is JoinResult.NotParked or JoinResult.Held)
        {
            Write($"other mods could not be {(planned && change!.Plan.Count == 0 ? "turned back on" : "turned off")} for world {Log.Short(world)}, starting again for the downloaded mods alone");
            result = Rejoin(world) ? JoinResult.Restarting : JoinResult.Failed;
        }

        return result switch
        {
            null => (ModsRestart.NotKept, change),
            JoinResult.Restarting => (ModsRestart.Restarting, change),
            _ => (ModsRestart.ByHand, change),
        };
    }

    /// <summary>
    /// Starts the game again to enter a world once it is back, which Player.ini's rejoin tells the next
    /// start.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <returns>Whether the game closes now; else the rejoin is forgotten.</returns>
    public bool Rejoin(string world)
    {
        Store(RejoinSetting, world);
        if (_restartGame())
        {
            Write($"starting the game again, to enter world {Log.Short(world)} once it is back");
            return true;
        }

        Store(RejoinSetting, null);
        Write($"the game could not start itself again, so world {Log.Short(world)} is not entered on its own");
        return false;
    }

    /// <summary>
    /// Takes the world the game should enter again after a restart, once.
    /// </summary>
    /// <returns>The world's id, <see langword="null"/> when there is none.</returns>
    public string? TakeRejoin()
    {
        string world = Setting(RejoinSetting);
        if (world.Length == 0)
        {
            return null;
        }

        Store(RejoinSetting, null);
        return world;
    }

    /// <summary>
    /// Puts back what a game that closed while mods were parked left parked, once a session as the
    /// first title screen starts, and counts the title screens.
    /// </summary>
    /// <remarks>
    /// The scripts of this session were read as the game started, so mods put back load only after one
    /// more start, which the title screen then makes, once.
    /// </remarks>
    public void TitleStarted()
    {
        Startup();
        _titleStarts++;
    }

    /// <summary>
    /// Puts the parked mods back as the game returned to the title screen, unless this is the first
    /// title screen of a start whose recovery kept them parked.
    /// </summary>
    /// <remarks>
    /// Mods this session neither parked nor kept parked are another game's, which is told only as the
    /// player leaves a world.
    /// </remarks>
    /// <param name="leftWorld">Whether the game left a world for the title screen.</param>
    public void TitleLeft(bool leftWorld)
    {
        _recheck = null;
        if (Due != null || (_keptAtStart && _titleStarts <= 1))
        {
            return;
        }

        _hold = null;
        if (ParkedNow().Files.Count == 0)
        {
            return;
        }

        if (!_owned && !leftWorld)
        {
            Write("the parked mods are not this session's, leaving them as the title screen starts");
            return;
        }

        LeaveParked(ParkingTexts.Leave);
    }

    /// <summary>
    /// Notes that a world was entered, which ends the hold, and has the world checked against a list
    /// fetched now.
    /// </summary>
    /// <remarks>
    /// The list the world was entered from may be older than a change the relay told the world's room
    /// before this game joined it.
    /// </remarks>
    /// <param name="world">The world's id in the directory, <see langword="null"/> for none.</param>
    /// <param name="name">The world's name.</param>
    public void Entered(string? world, string name)
    {
        if (_hold != null)
        {
            Write("entered the world the mods were parked for");
        }

        _hold = null;
        CheckAgain(world, null, name);
    }

    /// <summary>
    /// Puts the parked mods back once the start that entered a world again ended without entering it,
    /// and has the title screen start the game again.
    /// </summary>
    /// <param name="reason">Why the world was not entered, <see langword="null"/> for none.</param>
    public void GiveUp(string? reason)
    {
        Write($"the world {Log.Short(_hold ?? string.Empty)} the mods were parked for was not entered: {reason ?? "no reason given"}");
        _hold = null;
        LeaveParked(Joined(reason?.Trim(), ParkingTexts.Leave));
    }

    /// <summary>
    /// Starts the game again for the mods put back, once the title screen told why, or tells the player
    /// to when it cannot.
    /// </summary>
    /// <returns>Whether the game closes now.</returns>
    public bool RestartNow()
    {
        Due = null;
        Store(RestartedSetting, "1");
        if (_restartGame())
        {
            Write("closing the game to start it again with the mods back");
            return true;
        }

        Store(RestartedSetting, null);
        Write("the game cannot start itself again, the player starts it again for the mods");
        Notice = ParkingTexts.RestartByHand;
        return false;
    }

    /// <summary>
    /// Closes the notice the title screen shows.
    /// </summary>
    public void CloseNotice()
    {
        Write($"the player closed the notice: {Notice}");
        Notice = null;
    }

    /// <summary>
    /// Has the title screen tell something until the player closes it, such as why the world was left.
    /// </summary>
    /// <param name="text">What it says.</param>
    public void Tell(string text) => Notice = text;

    /// <summary>
    /// Puts the parked mods back once the updater started, which waits for this game to close and then
    /// starts it again itself.
    /// </summary>
    public void UpdateStarted()
    {
        if (ParkedNow().Files.Count > 0)
        {
            Restore(false);
        }
    }

    /// <summary>
    /// Takes the relay's word that the open world's creator or an admin changed whether it turns other
    /// mods off, or its mods: a game that now runs mods it turns off is told to leave.
    /// </summary>
    /// <param name="value">"1" when it turns other mods off, "0" when not.</param>
    /// <param name="mods">Its mods.</param>
    /// <param name="open">Whether the world is open.</param>
    /// <param name="world">Its id in the directory, <see langword="null"/> for none.</param>
    /// <param name="name">Its name.</param>
    /// <returns>Whether the word was taken, and what the player is told before leaving, <see langword="null"/> to stay.</returns>
    public (bool Taken, string? Kick) Rule(string value, string mods, bool open, string? world, string name)
    {
        if (value is not ("0" or "1"))
        {
            Write($"ignored the relay's mods rule \"{value}\"");
            return (false, null);
        }

        if (!open)
        {
            return (true, null);
        }

        // The relay's word is newer than any list asked for before it.
        _recheck = null;
        return (true, CheckRule(value == "1", mods, "the relay's word", world, name, false));
    }

    /// <summary>
    /// Takes what a player in a world that now turns their mods off is told, found by a check against a
    /// fetched list.
    /// </summary>
    /// <returns>The text, <see langword="null"/> for none.</returns>
    public string? TakeKick()
    {
        string? kick = _kick;
        _kick = null;
        return kick;
    }

    /// <summary>
    /// Follows the open world's check: asks for the list once none is being fetched, and checks the
    /// world once it arrived, or gives up on one that never arrives. Runs once a frame.
    /// </summary>
    /// <returns>Whether a check found the player must leave.</returns>
    public bool Frame()
    {
        if (_recheck == null || ++_recheck.Frames % RecheckStep != 0)
        {
            return false;
        }

        bool listing = _directory.Listing;
        if (!_recheck.Asked)
        {
            if (!listing)
            {
                _recheck.Asked = true;
                _recheck.Frames = 0;
                _directory.Refresh();
            }

            return false;
        }

        if (listing)
        {
            if (_recheck.Frames >= RecheckFrames)
            {
                Write("the list asked for to check the world's mods never arrived, staying in the world");
                _recheck = null;
            }

            return false;
        }

        Recheck check = _recheck;
        _recheck = null;
        if ((check.Rule ?? _directory.RuleOf(check.World)) is not { } rule)
        {
            Write("the list did not arrive or lacks the world or its mods, so its mods are not checked again");
            return false;
        }

        _kick = CheckRule(rule.OtherModsOff, rule.Mods, check.Rule != null ? "the relay's word, checked again" : "the list after entering", check.World, check.Name, true);
        return _kick != null;
    }

    /// <summary>
    /// Checks the open world's rule against the mods this game runs. While the catalog or the scripts
    /// are unknown, the game stays and the world is checked again with a list fetched for it.
    /// </summary>
    /// <param name="otherModsOff">Whether the world turns other mods off.</param>
    /// <param name="mods">Its mods.</param>
    /// <param name="source">Where the rule comes from, for the log.</param>
    /// <param name="world">Its id in the directory, to check it again.</param>
    /// <param name="name">Its name.</param>
    /// <param name="again">Whether this is the check again, which never asks for another.</param>
    /// <returns>What the player is told before leaving, <see langword="null"/> to stay.</returns>
    private string? CheckRule(bool otherModsOff, string mods, string source, string? world, string name, bool again)
    {
        if (!otherModsOff)
        {
            Write($"{source}: the world allows other mods, with mods \"{mods}\"");
            return null;
        }

        ParkingFacts facts = Facts();
        IReadOnlyList<string>? plan = ParkingRules.TurnedOff(facts.Scripts, mods, facts.Personal);
        if (plan == null)
        {
            Write($"{source}: the world turns other mods off, with mods \"{mods}\", but the catalog or the scripts are unknown: {(again ? "staying in the world" : "staying in the world until the list and catalog fetched for it arrive")}");
            if (!again)
            {
                CheckAgain(world, (otherModsOff, mods), name);
            }

            return null;
        }

        // Scripts behind a link to another drive are never parked, so they count as on.
        HashSet<string> parked = facts.Parked.Select(ParkingRules.PathKey).ToHashSet(StringComparer.Ordinal);
        List<string> loaded = plan.Concat(ParkingRules.TurnedOff(facts.Elsewhere, mods, facts.Personal) ?? []).Where(path => !parked.Contains(ParkingRules.PathKey(path))).ToList();
        if (loaded.Count == 0)
        {
            Write($"{source}: the world turns other mods off, with mods \"{mods}\": none of this game's are on");
            return null;
        }

        Write($"{source}: the world turns other mods off, with mods \"{mods}\": {string.Join(", ", loaded.Select(Path.GetFileNameWithoutExtension))} are on, leaving for the title screen");
        return ParkingTexts.NowOff(name.Length > 0 ? name : "The world");
    }

    /// <summary>
    /// Has the open world checked again once a list fetched from now arrived.
    /// </summary>
    /// <param name="world">The world's id in the directory; <see langword="null"/> checks nothing.</param>
    /// <param name="rule">Whether the world turns other mods off and its mods, as the relay told them; <see langword="null"/> to take both from the list.</param>
    /// <param name="name">The world's name.</param>
    private void CheckAgain(string? world, (bool OtherModsOff, string Mods)? rule, string name) =>
        _recheck = world != null ? new Recheck(world, rule, name) : null;

    /// <summary>
    /// Runs the start's recovery once a session: mods parked for the world this start enters again
    /// stay parked, others come back.
    /// </summary>
    private void Startup()
    {
        if (_started)
        {
            return;
        }

        _started = true;
        NoteStart();
        string rejoin = Setting(RejoinSetting);
        int answer = _parking.Recover(rejoin);
        bool restarted = Setting(RestartedSetting) == "1";
        if (restarted)
        {
            Store(RestartedSetting, null);
        }

        _keptAtStart = answer is RecoverKept or MoveFailed or ModParking.HeldElsewhere;
        _owned = answer is RecoverKept or MoveFailed;
        Moved |= answer is RecoverRestored;
        switch (answer)
        {
            case RecoverKept:
                _hold = rejoin;
                Write($"the mods stay parked for world {Log.Short(rejoin)}, which this start enters again");
                break;
            case ModParking.HeldElsewhere:
                Write("another game of this folder holds the parked mods, leaving them to it");
                break;
            case RecoverRestored when restarted:
                Write("put mods back that were parked again after the last restart for them, not restarting again");
                Notice = WithConflicts(ParkingTexts.RestartByHand);
                break;
            case RecoverRestored:
                Write("put back the mods a game that closed left parked, restarting so they load");
                RestartToTitle(WithConflicts(ParkingTexts.Recovered));
                break;
            case MoveFailed:
                Write("putting back the mods a game that closed left parked failed");
                Notice = WithConflicts(ParkingTexts.NotBack);
                break;
        }
    }

    /// <summary>
    /// Puts the parked mods back, and has the title screen start the game again so they load, or tells
    /// the player when some could not come back or another game of this folder holds them; a notice
    /// waiting for the title screen goes first.
    /// </summary>
    /// <param name="text">What the title screen says.</param>
    private void LeaveParked(string text)
    {
        string? told = Notice;
        Notice = null;
        int count = Restore(true);
        if (count == ModParking.HeldElsewhere)
        {
            Notice = Joined(told, ParkingTexts.Held);
            return;
        }

        string said = Joined(told, WithConflicts(count >= 0 ? text : ParkingTexts.NotBack));
        if (count >= 0)
        {
            RestartToTitle(said);
        }
        else
        {
            Notice = said;
        }
    }

    /// <summary>
    /// Has the title screen tell why the game starts again, then start it again.
    /// </summary>
    /// <param name="text">What it says.</param>
    private void RestartToTitle(string text)
    {
        Due = text;
        Write($"the game starts again on the title screen: {text}");
    }

    /// <summary>
    /// Adds how many mods the last restore sent to the conflicts folder.
    /// </summary>
    /// <param name="text">What the title screen says.</param>
    /// <returns>The text, see <see cref="ParkingTexts.WithConflicts"/>.</returns>
    private string WithConflicts(string text)
    {
        int conflicts = ParkedNow().Conflicts;
        if (conflicts > 0)
        {
            Write($"{conflicts} parked script(s) went to the conflicts folder, another file having taken their place");
        }

        return ParkingTexts.WithConflicts(text, conflicts);
    }

    /// <summary>
    /// Has the parking park scripts, putting back those parked before that are not among them.
    /// </summary>
    /// <param name="plan">The scripts.</param>
    /// <param name="world">The world they are parked for.</param>
    /// <returns>Whether exactly these scripts are parked now.</returns>
    private bool Park(IReadOnlyList<string> plan, string world)
    {
        NoteStart();
        _owned = true;
        int answer = _parking.Park(plan, world);
        Moved = true;
        IReadOnlyList<string> parked = ParkedNow().Files;
        bool done = ParkingRules.SameScripts(parked, plan);
        Write(done ? $"parked {plan.Count} script(s) for world {Log.Short(world)} (answered {answer}): {Names(plan)}"
                   : $"parking {Names(plan)} for world {Log.Short(world)} failed (answered {answer}), parked now: {string.Join(", ", parked)}");
        return done;
    }

    /// <summary>
    /// Has the parking put every parked script back.
    /// </summary>
    /// <param name="afterTitle">Whether the game starts again on the title screen afterwards, for the log.</param>
    /// <returns>How many came back, -1 when one could not, <see cref="ModParking.HeldElsewhere"/> while another game holds them.</returns>
    private int Restore(bool afterTitle)
    {
        NoteStart();
        int count = _parking.Restore(afterTitle);
        Moved = true;
        Write(count == ModParking.HeldElsewhere ? "another game of this folder holds the parked mods, they stay parked until it closes"
            : count < 0 ? "putting the parked mods back failed for some, they stay parked" : $"put {count} parked script(s) back");
        return count;
    }

    /// <summary>
    /// Starts the game again to enter a world with the mods parked for it, which Player.ini's rejoin
    /// tells the next start.
    /// </summary>
    /// <remarks>
    /// A plain restart would leave the journal to the watchdog that started this game, which puts the
    /// mods back as this game closes, while the next one starts.
    /// </remarks>
    /// <param name="world">The world the journal names.</param>
    /// <returns>Whether the game closes now; else the mods stay parked and the rejoin is forgotten.</returns>
    private bool RejoinParked(string world)
    {
        Store(RejoinSetting, world);
        if (_restartParked(world, true))
        {
            Write($"starting the game again with the mods parked, to enter world {Log.Short(world)}");
            return true;
        }

        Store(RejoinSetting, null);
        Write("the game could not start itself again with the mods parked");
        return false;
    }

    /// <summary>
    /// Reads the parked scripts; while the journal cannot be read, the ones read last stand in, since
    /// an unreadable journal does not mean that nothing is parked.
    /// </summary>
    /// <returns>The parked scripts.</returns>
    private ModParking.ParkedState ParkedNow()
    {
        try
        {
            return _lastParked = _parking.Parked();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            LogOnce("parked", $"the parked mods could not be read ({ex.Message}), keeping the state read last");
            return _lastParked ?? new ModParking.ParkedState(string.Empty, [], 0);
        }
    }

    /// <summary>
    /// Notes which scripts were parked as this session started, before it moves any.
    /// </summary>
    private void NoteStart() => _startParked ??= Keys(ParkedNow().Files);

    /// <summary>
    /// Tells whether this session moved scripts in or out of the Patch folder, which load only at the
    /// next start.
    /// </summary>
    /// <returns>Whether it did.</returns>
    private bool MovedHere() => _startParked != null && !Keys(ParkedNow().Files).SequenceEqual(_startParked, StringComparer.Ordinal);

    /// <summary>
    /// Reads a setting of Player.ini.
    /// </summary>
    /// <param name="key">The setting.</param>
    /// <returns>Its value, empty when it is missing.</returns>
    private string Setting(string key) => _player.Settings.FirstOrDefault(setting => setting.Key == key).Value ?? string.Empty;

    /// <summary>
    /// Keeps or removes a setting of Player.ini.
    /// </summary>
    /// <param name="key">The setting.</param>
    /// <param name="value">Its value, <see langword="null"/> to remove it.</param>
    private void Store(string key, string? value) => _player.Change([new(key, value)]);

    /// <summary>
    /// Logs a line.
    /// </summary>
    /// <param name="line">The line.</param>
    private static void Write(string line) => Log.Write("mod parking: " + line);

    /// <summary>
    /// Logs a line once a session.
    /// </summary>
    /// <param name="key">What it is about.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (_logged.Add(key))
        {
            Write(line);
        }
    }

    /// <summary>
    /// Turns scripts into what a set of them is compared by.
    /// </summary>
    /// <param name="paths">The scripts.</param>
    /// <returns>Their keys, sorted.</returns>
    private static List<string> Keys(IEnumerable<string> paths) => paths.Select(ParkingRules.PathKey).Order(StringComparer.Ordinal).ToList();

    /// <summary>
    /// Names scripts as the player knows them, for the log.
    /// </summary>
    /// <param name="paths">The scripts.</param>
    /// <returns>Their file names without ".rb".</returns>
    private static string Names(IEnumerable<string> paths) => string.Join(", ", paths.Select(Path.GetFileNameWithoutExtension));

    /// <summary>
    /// Joins the parts of a text that say something.
    /// </summary>
    /// <param name="first">The first part, <see langword="null"/> or empty for none.</param>
    /// <param name="second">The second part.</param>
    /// <returns>The parts separated by a space.</returns>
    private static string Joined(string? first, string second) => string.IsNullOrEmpty(first) ? second : first + " " + second;

    /// <summary>
    /// The open world's check against a list fetched for it.
    /// </summary>
    /// <param name="World">The world's id in the directory.</param>
    /// <param name="Rule">The rule the relay told, <see langword="null"/> to take it from the list.</param>
    /// <param name="Name">The world's name.</param>
    private sealed record Recheck(string World, (bool OtherModsOff, string Mods)? Rule, string Name)
    {
        /// <summary>
        /// Gets or sets whether the list was asked for.
        /// </summary>
        public bool Asked { get; set; }

        /// <summary>
        /// Gets or sets the frames counted since the check started, or since the list was asked for.
        /// </summary>
        public int Frames { get; set; }
    }
}
