//----------------------------------------------------------------
//  WorldEntering.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Waited for the list while it is not fetched yet as well as while it is being fetched
//      Paulinchen  2026-10-23: Sent the world screen's requests and took this game's data from the DLL's copy
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Worlds;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// What the world screen's steps need of the world directory, apart from it so the tests can stand
/// in for the relay.
/// </summary>
internal interface IEnteringDirectory
{
    /// <summary>
    /// Finds a world in the list as it stands.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <returns>How the list stands, and the world, <see langword="null"/> when the list lacks it.</returns>
    (string State, ListedWorld? World) Listed(string id);

    /// <summary>
    /// Opens a world, whose mods the list then carries.
    /// </summary>
    /// <param name="id">The world's id.</param>
    void Open(string id);

    /// <summary>
    /// Starts reading a world's mods.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <returns>Whether the action started.</returns>
    bool Read(string id);

    /// <summary>
    /// Starts opening a world's lock with its password.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <param name="password">The password, empty for a world without one.</param>
    /// <returns>Whether the action started.</returns>
    bool Unlock(string id, string password);

    /// <summary>
    /// Starts opening a world's lock with a world code, a Discord invite's.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <returns>Whether the action started.</returns>
    bool UnlockWithCode(string code);

    /// <summary>
    /// Starts fetching a world's starting save into its folder.
    /// </summary>
    /// <param name="code">The world's code.</param>
    /// <param name="folder">The folder of its saves, from the game folder.</param>
    /// <returns>Whether the action started.</returns>
    bool FetchStart(string code, string folder);

    /// <summary>
    /// Starts making a world take this game's data.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <param name="data">This game's data fingerprint.</param>
    /// <returns>Whether the action started.</returns>
    bool SetData(string id, string data);

    /// <summary>
    /// Tells how the running or last action stands.
    /// </summary>
    /// <returns>Its state ("idle", "busy", "done" or "failed") and, once it failed, why.</returns>
    (string State, string? Error) Action();

    /// <summary>
    /// Tells what the last action that succeeded handed back.
    /// </summary>
    /// <returns>The code, the world's id, name, starting save state and choice; <see langword="null"/> for none.</returns>
    (string Code, string? World, string? Name, string? Start, bool Choose)? Result();

    /// <summary>
    /// Forgets the last action, so the next one may start.
    /// </summary>
    void Clear();

    /// <summary>
    /// Fetches the list again, with the hidden worlds the player added.
    /// </summary>
    /// <param name="added">The ids of those worlds.</param>
    void Refresh(IReadOnlyList<string> added);

    /// <summary>
    /// Makes a world, see <see cref="WorldDirectory.Create"/>.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="password">Its password, empty for none.</param>
    /// <param name="seats">Its seats.</param>
    /// <param name="hidden">Whether the directory hides it.</param>
    /// <param name="choose">Whether new players choose where to start.</param>
    /// <param name="start">Its starting save's files.</param>
    /// <param name="about">What it is about.</param>
    /// <param name="type">Its type.</param>
    /// <param name="share">How a Raid World shares companions.</param>
    /// <param name="difficulty">A Raid World's difficulty.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <param name="squad">A Raid World's squad rules as text.</param>
    /// <param name="raidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
    /// <returns>Whether the action started.</returns>
    bool Create(string name, string password, int seats, bool hidden, bool choose, IReadOnlyList<(string Name, string Path)> start, WorldAbout about, string type, string share, int? difficulty, bool otherModsOff, string? squad, bool? raidBosses);

    /// <summary>
    /// Changes a world, see <see cref="WorldDirectory.Edit"/>.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="seats">Its seats.</param>
    /// <param name="description">Its description.</param>
    /// <param name="mods">Its mods.</param>
    /// <param name="modHashes">Its creator's mod hashes, <see langword="null"/> to leave them.</param>
    /// <param name="difficulty">Its new difficulty, <see langword="null"/> to leave it.</param>
    /// <param name="otherModsOff">Whether it now turns other mods off, <see langword="null"/> to leave it.</param>
    /// <param name="squad">Its new squad rules as text, <see langword="null"/> to leave them.</param>
    /// <param name="raidBosses">Whether its story bosses now fight as raid bosses, <see langword="null"/> to leave it.</param>
    /// <returns>Whether the action started.</returns>
    bool Edit(string id, int seats, string description, string mods, string? modHashes, int? difficulty, bool? otherModsOff, string? squad, bool? raidBosses);

    /// <summary>
    /// Replaces a world's mod settings.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="settings">The settings.</param>
    /// <returns>Whether the action started.</returns>
    bool SetSettings(string id, string settings);

    /// <summary>
    /// Looks a hidden world up by its id.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>Whether the action started.</returns>
    bool Find(string id);

    /// <summary>
    /// Deletes a world for everyone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>Whether the action started.</returns>
    bool Delete(string id);

    /// <summary>
    /// Removes a player from a world.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="target">The player.</param>
    /// <returns>Whether the action started.</returns>
    bool Ban(string id, string target);
}

/// <summary>
/// The world screen's way into a world as steps the scripts play: whether the world takes players
/// now, its required mods, its other mods turned off, its game data, its password, where a new
/// player starts, the starting save, the restart for mods, a Discord invite and the entry after a
/// restart. The scripts hand over the player's choices and what their effects did, and keep the
/// windows, the forms, the saves and the scenes.
/// </summary>
/// <remarks>
/// It builds on the topics of the areas it asks in-process (mods.check, mods.install, parking.*,
/// worlds.invite_take), so their texts and rules stay in one place.
/// </remarks>
internal sealed partial class WorldEntering
{
    /// <summary>
    /// Enters a world: the entry (<c>id</c>, <c>folder</c>, <c>name</c>, <c>gone</c>), <c>me</c> and
    /// <c>data</c> (this game's fingerprint) in; <c>steps</c> out.
    /// </summary>
    public const string EnterTopic = "screen.enter";

    /// <summary>
    /// Takes the player's answer or what a step's effect did: <c>answer</c> and, as it needs,
    /// <c>text</c>, <c>index</c>, <c>ok</c>, <c>placed</c> in; <c>steps</c> out.
    /// </summary>
    public const string AnswerTopic = "screen.answer";

    /// <summary>
    /// Follows the running action, once the <see cref="WorldChanges.Screen"/> bit came: nothing in;
    /// <c>steps</c> out, none while it runs.
    /// </summary>
    public const string StepTopic = "screen.step";

    /// <summary>
    /// Runs a command of the screen: <c>do</c> (open, look, update_data, read_for_edit, close) and
    /// what it needs in; <c>steps</c> and <c>waiting</c> (whether the screen waits for the list to
    /// enter a world) out.
    /// </summary>
    public const string DoTopic = "screen.do";

    /// <summary>
    /// The folder the worlds' folders are in, from the game folder, as the scripts name them.
    /// </summary>
    private const string WorldsFolder = LocalWorldTopics.WorldsFolder;

    /// <summary>
    /// What a request that could not start says.
    /// </summary>
    private const string NotStartedText = "The request could not be started. Try again in a moment.";

    /// <summary>
    /// The context, whose topics of other areas the steps ask.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// The world directory.
    /// </summary>
    private readonly IEnteringDirectory _directory;

    /// <summary>
    /// The worlds on this PC.
    /// </summary>
    private readonly LocalWorlds _worlds;

    /// <summary>
    /// The player's lists of worlds.
    /// </summary>
    private readonly WorldLists _lists;

    /// <summary>
    /// Shares who plays with the worlds before a starting save is fetched.
    /// </summary>
    private readonly Func<bool> _share;

    /// <summary>
    /// Tells whether the parking holds the mods turned off for the world the game started again for.
    /// </summary>
    private readonly Func<bool> _holding;

    /// <summary>
    /// Tells whose answer the directory's action is.
    /// </summary>
    private readonly DirectoryTickets _tickets;

    /// <summary>
    /// The changes the scripts are told of.
    /// </summary>
    private readonly WorldChanges _changes;

    /// <summary>
    /// The codes of Discord invites by world, which open a world instead of its password.
    /// </summary>
    private readonly Dictionary<string, string> _inviteCodes = new(StringComparer.Ordinal);

    /// <summary>
    /// The steps of the answer being built.
    /// </summary>
    private RubyArray _steps = [];

    /// <summary>
    /// The world being entered.
    /// </summary>
    private Entry? _entry;

    /// <summary>
    /// The player's id in the worlds.
    /// </summary>
    private string _me = "";


    /// <summary>
    /// The world a Discord invite names, entered once the list holds it.
    /// </summary>
    private string? _invited;

    /// <summary>
    /// Whether the list was fetched once more for the invited world.
    /// </summary>
    private bool _inviteRetried;

    /// <summary>
    /// The world the game started again to enter, entered once the list holds it.
    /// </summary>
    private string? _rejoin;

    /// <summary>
    /// Whether the entry is the one the game started again for, whose end without entering puts the mods back.
    /// </summary>
    private bool _rejoinEntering;

    /// <summary>
    /// Whether the player said to enter although the game data differs.
    /// </summary>
    private bool _dataAccepted;

    /// <summary>
    /// Whether the world took this game's data, which the list holds the old scan of until fetched again.
    /// </summary>
    private bool _dataTaken;

    /// <summary>
    /// Whether the world is entered once it took this game's data.
    /// </summary>
    private bool _enterAfterData;

    /// <summary>
    /// What the question being asked is about, such as "mods".
    /// </summary>
    private string? _confirming;

    /// <summary>
    /// The scripts parking turns off for the world, none to put the parked ones back.
    /// </summary>
    private IReadOnlyList<string> _parkPlan = [];

    /// <summary>
    /// The question that asks to turn the mods off and start again.
    /// </summary>
    private string _parkQuestion = "";

    /// <summary>
    /// What follows once the world's lock was opened before parking: "ask" asks to turn the mods off,
    /// "mods" turns them off with the restart for the downloads; <see langword="null"/> enters.
    /// </summary>
    private string? _parkAfterUnlock;

    /// <summary>
    /// What waits for the world's mods to be read: "enter" or "edit".
    /// </summary>
    private string? _afterRead;

    /// <summary>
    /// The running action's kind, <see langword="null"/> while none of these steps runs.
    /// </summary>
    private string? _busy;

    /// <summary>
    /// Whether the scripts were told that the running action ended.
    /// </summary>
    private bool _toldEnded;

    /// <summary>
    /// The ticket of the running action.
    /// </summary>
    private int? _ticket;

    /// <summary>
    /// The folder of the world whose start is chosen or fetched.
    /// </summary>
    private string? _starting;

    /// <summary>
    /// How far the world whose start is chosen is with its starting save.
    /// </summary>
    private string? _startingFrom;

    /// <summary>
    /// Whether the list had arrived as the world began to open, which its settings take.
    /// </summary>
    private bool _fresh;

    /// <summary>
    /// What the screen said last, the reason a give-up tells.
    /// </summary>
    private string? _said;

    /// <summary>
    /// Creates the steps.
    /// </summary>
    /// <param name="context">The context, whose topics of other areas the steps ask.</param>
    /// <param name="directory">The world directory.</param>
    /// <param name="worlds">The worlds on this PC.</param>
    /// <param name="lists">The player's lists of worlds.</param>
    /// <param name="share">Shares who plays with the worlds.</param>
    /// <param name="holding">Tells whether the parking holds the mods turned off for a rejoin.</param>
    /// <param name="tickets">Tells whose answer the directory's action is.</param>
    /// <param name="changes">The changes the scripts are told of.</param>
    public WorldEntering(BridgeContext context, IEnteringDirectory directory, LocalWorlds worlds, WorldLists lists, Func<bool> share, Func<bool> holding, DirectoryTickets tickets, WorldChanges changes)
    {
        _context = context;
        _directory = directory;
        _worlds = worlds;
        _lists = lists;
        _share = share;
        _holding = holding;
        _tickets = tickets;
        _changes = changes;
    }

    /// <summary>
    /// Registers the topics and the step that tells the scripts once a running action ended.
    /// </summary>
    public void Register()
    {
        _context.Register(EnterTopic, (_, request) => Answered(() => Enter(request.AsHash())));
        _context.Register(AnswerTopic, (_, request) => Answered(() => Answer(request.AsHash())));
        _context.Register(StepTopic, (_, _) => Answered(Step));
        _context.Register(DoTopic, (_, request) => Do(request.AsHash()));
        _context.EveryFrame(_ =>
        {
            if (_busy != null && !_toldEnded && _directory.Action().State != "busy")
            {
                _toldEnded = true;
                _changes.Mark(WorldChanges.Screen);
            }
        });
    }

    /// <summary>
    /// Runs a command of the screen.
    /// </summary>
    /// <param name="request">The command and what it needs.</param>
    /// <returns>The steps and <c>waiting</c>, whether the screen waits for the list to enter a world.</returns>
    private RubyHash Do(RubyHash request)
    {
        string command = request["do"].AsText();
        if (command == "open")
        {
            return Opened(request);
        }

        RubyHash reply = Answered(() =>
        {
            switch (command)
            {
                case "look":
                    Look(request);
                    break;
                case "update_data":
                    Take(request);
                    if (request["ask"].AsBool())
                    {
                        AskDataUpdate();
                    }
                    else
                    {
                        UpdateData(false);
                    }

                    break;
                case "read_for_edit":
                    Take(request);
                    ReadMods("edit");
                    break;
                case "close":
                    Close();
                    break;
                default:
                    if (!RunRequest(command, request))
                    {
                        throw new BridgeRequestException($"There is no command {command}.");
                    }

                    break;
            }
        });
        reply["waiting"] = Waiting;
        return reply;
    }

    /// <summary>
    /// Runs something and answers the steps it made.
    /// </summary>
    /// <param name="run">What runs.</param>
    /// <returns><c>steps</c>.</returns>
    private RubyHash Answered(Action run)
    {
        _steps = [];
        run();
        return new RubyHash { { "steps", _steps } };
    }

    /// <summary>
    /// Opens the screen: takes the world the game started again for and a Discord invite.
    /// </summary>
    /// <param name="request"><c>rejoin</c> and <c>me</c>.</param>
    /// <returns><c>steps</c> (none) and <c>waiting</c>, whether the screen waits for the list to enter a world.</returns>
    private RubyHash Opened(RubyHash request)
    {
        _me = Text(request["me"]);
        if (!request["rejoin"].IsNil)
        {
            _rejoin = request["rejoin"].AsText();
        }

        if (_context.Ask("worlds.invite_take") is RubyArray { Count: 2 } invite)
        {
            string id = invite[0].AsText();
            _inviteCodes[id] = invite[1].AsText();
            _invited = id;
            _inviteRetried = false;
            _lists.Add(id);
            _changes.Mark(WorldChanges.List);
            Log($"took the invite into world {Short(id)}, entered once the list holds it");
        }

        return new RubyHash { { "steps", new RubyArray() }, { "waiting", Waiting } };
    }

    /// <summary>
    /// Enters the world the game started again for or a Discord invite names, once the list holds it.
    /// </summary>
    /// <param name="request"><c>state</c> (the list's), <c>idle</c> (whether the screen waits for the player), <c>named</c> and <c>entries</c> ([id, folder, name, gone] each).</param>
    private void Look(RubyHash request)
    {
        string state = request["state"].AsText();
        if ((state != "ready" && state != "failed") || !request["idle"].AsBool())
        {
            return;
        }

        Dictionary<string, RubyArray> entries = new(StringComparer.Ordinal);
        foreach (RubyValue row in request["entries"].AsArray())
        {
            RubyArray entry = row.AsArray();
            if (!entry[0].IsNil)
            {
                entries.TryAdd(entry[0].AsText(), entry);
            }
        }

        if (_rejoin is { } rejoin)
        {
            _rejoin = null;
            if (!entries.TryGetValue(rejoin, out RubyArray? found) || state != "ready")
            {
                Log($"not entering world {Short(rejoin)} again after the restart: not in the list (list {state})");
                Say("The world you restarted for is not in the list right now.");
                if (_holding())
                {
                    GiveUp(_said);
                }

                return;
            }

            Log($"entering {Of(found)} again after the restart for its mods");
            _rejoinEntering = true;
            Begin(found);
            return;
        }

        if (_invited is not { } invited || !request["named"].AsBool())
        {
            return;
        }

        bool listed = entries.TryGetValue(invited, out RubyArray? entered);
        if (!listed && state == "ready" && !_inviteRetried)
        {
            _inviteRetried = true;
            Log($"the invited world {Short(invited)} is not in the list yet, fetching it once more");
            _directory.Refresh(_lists.Added());
            return;
        }

        _invited = null;
        if (!listed || state != "ready")
        {
            Log($"dropped the invite into world {Short(invited)}: not in the list (list {state})");
            Say("The world of your Discord invite is not in the list right now.");
            return;
        }

        Log($"entering {Of(entered!)} for the Discord invite");
        Begin(entered!);
    }

    /// <summary>
    /// Points the scripts at the entry the steps enter and starts entering it.
    /// </summary>
    /// <param name="row">The entry, [id, folder, name, gone].</param>
    private void Begin(RubyArray row)
    {
        _entry = new Entry(row[0].AsText(), row[1].IsNil ? null : row[1].AsText(), row[2].AsText(), row[3].AsBool());
        _steps.Add(new RubyArray { "entry", _entry.Id });
        _dataAccepted = false;
        _dataTaken = false;
        _parkAfterUnlock = null;
        Chain();
    }

    /// <summary>
    /// Enters the world the player chose.
    /// </summary>
    /// <param name="request">The entry, <c>me</c> and <c>data</c>.</param>
    private void Enter(RubyHash request)
    {
        Take(request);
        _rejoinEntering = false;
        _dataAccepted = false;
        _dataTaken = false;
        _parkAfterUnlock = null;
        Log($"enter {EntryText}");
        Chain();
    }

    /// <summary>
    /// Takes the entry a request names, with who plays.
    /// </summary>
    /// <param name="request"><c>id</c>, <c>folder</c>, <c>name</c>, <c>gone</c> and <c>me</c>.</param>
    private void Take(RubyHash request)
    {
        _entry = new Entry(Text(request["id"]), request["folder"].IsNil ? null : request["folder"].AsText(), Text(request["name"]), !request["gone"].IsNil && request["gone"].AsBool());
        _me = Text(request["me"]);
    }

    /// <summary>
    /// Goes through what entering asks, in order: the world open now, its mods read, its required
    /// mods, its other mods turned off, its game data, then its folder, lock or password.
    /// </summary>
    private void Chain()
    {
        Entry entry = _entry!;
        (string state, ListedWorld? listed) = _directory.Listed(entry.Id);
        if (listed != null)
        {
            bool meOnline = listed.Members.Any(member => member.Id == _me && member.Online);
            if (EnterRules.OpenNow(entry.Name, listed.Start, listed.Online, listed.Seats, meOnline) is { } refused)
            {
                Log($"not entering {EntryText}: {(listed.Start == "pending" ? "its creator still sets up its starting save" : $"full ({listed.Online}/{listed.Seats} online)")}");
                Play(refused);
                return;
            }

            if (listed.ModsUnread)
            {
                ReadMods("enter");
                return;
            }

            // The world entered stays opened, so the list in the world carries its mods.
            _directory.Open(listed.Id);
            _fresh = state == "ready";
            if (!ModsAllow(listed) || !ParkingAllows(listed) || !DataAllows(listed))
            {
                return;
            }
        }

        if (entry.Folder != null && listed == null && (_worlds.LatestSave(entry.Folder) == null || !entry.Gone))
        {
            Log($"not entering {EntryText}: {(entry.Gone ? "no longer in the list" : "the list has not arrived")}");
            Refuse(entry.Gone ? $"{entry.Name} is no longer in the list: it was deleted, or you were removed." : $"{entry.Name} is not in the list right now. Try again once the list has loaded.");
            Back();
        }
        else if (entry.Folder != null)
        {
            Log($"entering {EntryText} from its folder {entry.Folder}{(listed == null ? " (deleted from the list, saves kept)" : "")}");
            if (listed != null)
            {
                _worlds.Describe(entry.Folder, AboutOf(listed, listed.Seats));
                _changes.Mark(WorldChanges.List);
            }

            EnterFolder(entry.Folder, listed?.Start, listed?.Choose);
        }
        else if (listed?.Open == true)
        {
            Log($"opening {EntryText}, which has no password");
            StartAction("unlock", () => _directory.Unlock(entry.Id, ""));
        }
        else if (_inviteCodes.TryGetValue(entry.Id, out string? code))
        {
            Log($"opening {EntryText} with the Discord invite instead of its password");
            StartAction("unlock", () => _directory.UnlockWithCode(code));
        }
        else
        {
            AskPassword();
        }
    }

    /// <summary>
    /// Reads the world's mods, which the list leaves out until it is opened, before going on.
    /// </summary>
    /// <param name="after">What follows: "enter" or "edit".</param>
    private void ReadMods(string after)
    {
        Log($"reading the mods of {EntryText} before {(after == "enter" ? "entering" : "editing")} it");
        _afterRead = after;
        string id = _entry!.Id;
        StartAction("read", () => _directory.Read(id));
    }

    /// <summary>
    /// Goes on with what waited for the world's mods, once the list carries them.
    /// </summary>
    /// <param name="after">What waited: "enter" or "edit".</param>
    private void ModsRead(string? after)
    {
        ListedWorld? listed = _directory.Listed(_entry!.Id).World;
        if (listed == null || listed.ModsUnread)
        {
            Log($"the mods of {EntryText} were read, yet the list {(listed != null ? "still lacks them" : "lacks the world")}");
            Refuse($"The mods of {_entry.Name} could not be read. Try again in a moment.");
            Back();
            return;
        }

        _steps.Add(new RubyArray { "read" });
        if (after == "edit")
        {
            _steps.Add(new RubyArray { "edit" });
            return;
        }

        Chain();
    }

    /// <summary>
    /// Decides whether this game may enter as far as the world's required mods go, and offers the
    /// download of what the catalog has.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <returns>Whether entering goes on now.</returns>
    private bool ModsAllow(ListedWorld listed)
    {
        RubyHash check = _context.Ask("mods.check", new RubyHash { { "mods", listed.About.Mods }, { "hashes", listed.About.ModHashes }, { "world", _entry!.Name } })!.AsHash();
        RubyArray rows = check["rows"].AsArray();
        if (rows.Count == 0)
        {
            return true;
        }

        List<RubyHash> unavailable = [.. rows.Select(row => row.AsHash()).Where(row => !row["downloadable"].AsBool())];
        RubyHash? change = unavailable.Count == 0 ? ParkingChange(listed, false) : null;
        string summary = Text(check["summary"]);
        string names = string.Join(", ", rows.Select(row => row.AsHash()["name"].AsText()));
        _confirming = "mods";
        if (unavailable.Count == rows.Count && rows.All(row => row.AsHash()["yours"].AsText() == "not installed"))
        {
            Log($"kept out of {EntryText}: required mods missing, none in the catalog");
            Refuse($"{_entry.Name} needs mods you do not have: {names}.");
            Back();
        }
        else if (change != null && change["kind"].AsText() == "elsewhere")
        {
            // The restart for the downloads would be wasted: the entry after it is refused for this.
            Log($"kept out of {EntryText} before downloading its mods: scripts it turns off lie behind a link to another drive");
            Refuse(Text(change["text"]));
            Back();
        }
        else if (unavailable.Count == 0)
        {
            Log($"offered to download {names} for {EntryText} and restart");
            Say(summary + (change == null ? "" : Text(change["also"])));
            Confirm("mods", ("Download and restart", "yes"), ("See the mods", "show_mods"), ("Back", EnterRules.Cancel));
        }
        else
        {
            Log($"kept out of {EntryText}: {string.Join(", ", unavailable.Select(row => row["name"].AsText()))} only from the author, no download offered");
            Buzz();
            Say(summary);
            Confirm("mods", ("See the mods", "show_mods"), ("Back", EnterRules.Cancel));
        }

        return false;
    }

    /// <summary>
    /// Decides whether this game may enter as far as other mods go: a world that turns them off is
    /// entered only with them turned off, which takes a restart, so the player is asked first. A
    /// world this PC never entered has its lock opened first, so the start after the restart enters
    /// it without its password.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <returns>Whether entering goes on now.</returns>
    private bool ParkingAllows(ListedWorld listed)
    {
        RubyHash change = ParkingChange(listed, true);
        string kind = change["kind"].AsText();
        if (kind == "none")
        {
            return true;
        }

        if (kind != "plan")
        {
            Log($"kept out of {EntryText}: it turns other mods off, and the parked mods cannot follow ({kind})");
            Refuse(Text(change["text"]));
            Back();
            return false;
        }

        _parkPlan = [.. change["plan"].AsArray().Select(path => path.AsText())];
        _parkQuestion = Text(change["text"]);
        if (_parkPlan.Count > 0 && _entry!.Folder == null && !listed.Open)
        {
            UnlockFirst("ask");
            return false;
        }

        AskParking();
        return false;
    }

    /// <summary>
    /// Asks the parking what entering a world needs.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <param name="claim">Whether scripts parked for another world that this one turns off too are parked for this one.</param>
    /// <returns>The parking's answer: <c>kind</c>, <c>plan</c>, <c>text</c> and <c>also</c>.</returns>
    private RubyHash ParkingChange(ListedWorld listed, bool claim) =>
        _context.Ask("parking.change", new RubyHash { { "world", listed.Id }, { "mods", listed.About.Mods }, { "off", listed.OtherModsOff }, { "name", _entry!.Name }, { "claim", claim } })!.AsHash();

    /// <summary>
    /// Opens the lock of a world this PC never entered before its mods are turned off.
    /// </summary>
    /// <param name="after">"ask" asks to turn the mods off then, "mods" turns them off with the restart for the downloads.</param>
    private void UnlockFirst(string after)
    {
        _parkAfterUnlock = after;
        string id = _entry!.Id;
        bool invited = _inviteCodes.TryGetValue(id, out string? code);
        Log($"opening the lock of {EntryText} {(invited ? "with the Discord invite" : "with its password")} before turning other mods off");
        if (invited)
        {
            StartAction("unlock", () => _directory.UnlockWithCode(code!));
        }
        else
        {
            AskPassword();
        }
    }

    /// <summary>
    /// Asks whether to turn the other mods off, or the parked ones back on, start again and enter.
    /// </summary>
    private void AskParking()
    {
        Log(_parkPlan.Count == 0 ? $"{EntryText} allows the mods turned off for another world: asking to put them back and start again to enter it" : $"asking to turn off {string.Join(", ", _parkPlan)} for {EntryText}");
        Say(_parkQuestion);
        List<(string, string)> offered = [("Restart and join", "yes")];
        if (_parkPlan.Count > 0)
        {
            offered.Add(("See the mods", "show_mods"));
        }

        offered.Add(("Back", EnterRules.Cancel));
        Confirm("parking", [.. offered]);
    }

    /// <summary>
    /// Turns the other mods off and starts the game again, which then enters the world.
    /// </summary>
    private void ParkAndJoin()
    {
        RubyArray plan = new(_parkPlan.Select(path => (RubyValue)path));
        RubyHash joined = _context.Ask("parking.join", new RubyHash { { "world", _entry!.Id }, { "name", _entry.Name }, { "plan", plan } })!.AsHash();
        if (joined["result"].AsText() == "restarting")
        {
            Log($"closing the game to start it again with other mods turned off for {EntryText}");
            _steps.Add(new RubyArray { "exit" });
            return;
        }

        Refuse(Text(joined["text"]));
        Back();
    }

    /// <summary>
    /// Decides whether this game may enter as far as its data goes.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <returns>Whether entering goes on now.</returns>
    private bool DataAllows(ListedWorld listed)
    {
        IReadOnlyList<string>? differing = GameDataCompare.Differing(Data, _dataTaken ? Data : listed.About.Data);
        bool accepted = _dataAccepted;
        _dataAccepted = false;
        bool own = listed.CreatorId == _me;
        bool parked = false;
        string ownData = "";
        if (own && differing is { Count: > 0 })
        {
            RubyHash told = _context.Ask("parking.parked_for", new RubyHash { { "world", listed.Id }, { "mods", listed.About.Mods }, { "off", listed.OtherModsOff }, { "name", _entry!.Name } })!.AsHash();
            parked = told["parked"].AsBool();
            ownData = Text(told["text"]);
        }

        (bool allowed, IReadOnlyList<EnterDone> did) = EnterRules.Data(_entry!.Name, differing, listed.About.Strict, listed.About.Mods, own, parked, accepted, ownData);
        Log(differing == null || differing.Count == 0
            ? $"data check of {_entry.Name}: {(differing == null ? "cannot compare (unknown or other format), let in" : "matches")}"
            : $"data check of {_entry.Name}: differs in {string.Join(", ", differing)}; {(allowed ? "player entered anyway" : listed.About.Strict ? "strict" : "asking the player")}");
        Play(did);
        return allowed;
    }

    /// <summary>
    /// Opens the form that asks for the world's password.
    /// </summary>
    private void AskPassword()
    {
        Log($"asking for the password of {EntryText}");
        _steps.Add(new RubyArray { "password", _entry!.Name });
    }

    /// <summary>
    /// Asks the creator whether the world takes their game's data as it is now.
    /// </summary>
    private void AskDataUpdate()
    {
        if (Data.Length == 0)
        {
            Log($"not asking to update the data of {EntryText}: this game's data could not be read");
            Refuse("Your game data could not be read.");
            Back();
            return;
        }

        Say($"Take your game's data as that of {_entry!.Name}? Games that differ from yours are then warned or kept out.");
        Confirm("update_data", ("Update it", "yes"), ("Back", EnterRules.Cancel));
    }

    /// <summary>
    /// Makes the world take this game's data, then enters it when the entry asked for it.
    /// </summary>
    /// <param name="enter">Whether the world is entered afterwards.</param>
    private void UpdateData(bool enter)
    {
        _enterAfterData = enter;
        if (Data.Length == 0)
        {
            _enterAfterData = false;
            Log($"not updating the data of {EntryText}: this game's data could not be read");
            Refuse("Your game data could not be read.");
            Back();
            return;
        }

        string id = _entry!.Id;
        string data = Data;
        StartAction("data", () => _directory.SetData(id, data));
    }

    /// <summary>
    /// Enters a world this PC has a folder of, first asking where to start or whether to take its
    /// starting save when it has no save of it yet.
    /// </summary>
    /// <param name="folder">The world's folder.</param>
    /// <param name="start">How far it is with its starting save, <see langword="null"/> when the list does not tell.</param>
    /// <param name="choose">Whether its new players choose where to start, <see langword="null"/> when the list does not tell.</param>
    private void EnterFolder(string folder, string? start, bool? choose)
    {
        LocalWorld? world = _worlds.Find(folder);
        bool newPlayer = _worlds.LatestSave(folder) == null;
        _starting = folder;
        _startingFrom = start;
        IReadOnlyList<EnterDone> did = EnterRules.StartOf(world?.Name ?? _entry!.Name, world?.Raid == true, choose, start, newPlayer, Own);
        Log(did[0].Kind switch
        {
            EnterRules.Fetch => $"first entry into own world {world?.Name} ({folder}): fetching its starting save",
            EnterRules.Start => newPlayer ? $"first entry into {world?.Name} ({folder}): starting at the beginning (start {start ?? "unknown"})" : $"entering {world?.Name} ({folder}) from its latest save here",
            _ => $"first entry into {world?.Name} ({folder}): asking where to start",
        });
        Play(did);
    }

    /// <summary>
    /// Takes the player's answer to a question, or what a step's effect did.
    /// </summary>
    /// <param name="request"><c>answer</c> and what it needs.</param>
    private void Answer(RubyHash request)
    {
        string answer = request["answer"].AsText();
        switch (answer)
        {
            case "yes":
                Confirmed();
                break;
            case "show_mods":
                // Seeing the mods ends the entry the game started again for: the player enters again from the list.
                _rejoinEntering = false;
                break;
            case EnterRules.Cancel:
            case "back":
                Log($"backed out for {EntryText}");
                Back();
                break;
            case "password":
                string id = _entry!.Id;
                string password = Text(request["text"]);
                StartAction("unlock", () => _directory.Unlock(id, password));
                break;
            case "password_back":
                if (_rejoinEntering && _holding())
                {
                    GiveUp(null);
                }

                break;
            case "from_creator":
                Log("start chosen: the creator's save");
                if (Own)
                {
                    Fetch();
                }
                else
                {
                    Play(EnterRules.Warning());
                }

                break;
            case "take_start":
                Log("start chosen: taking the creator's save after the warning");
                Fetch();
                break;
            case "from_beginning":
                Log("start chosen: the beginning");
                StartWorld(_starting!, false);
                break;
            case "from_own":
                Log("start chosen: one of the player's own saves, opening the save screen");
                _steps.Add(new RubyArray { "save_screen" });
                break;
            case "own_save":
                OwnSave(request["index"]);
                break;
            case "own_copied":
                OwnCopied(request["ok"].AsBool());
                break;
            case "start_failed":
                StartFailed(Text(request["text"]), request["placed"].AsBool());
                break;
            default:
                if (!RequestAnswered(answer, request))
                {
                    throw new BridgeRequestException($"There is no answer {answer}.");
                }

                break;
        }
    }

    /// <summary>
    /// Does what the player confirmed.
    /// </summary>
    private void Confirmed()
    {
        string? what = _confirming;
        _confirming = null;
        Log($"confirmed {what} for {EntryText}");
        switch (what)
        {
            case "mods":
                ListedWorld listed = _directory.Listed(_entry!.Id).World!;
                StartAction("mods", () => _context.Ask("mods.install", new RubyHash { { "mods", listed.About.Mods }, { "hashes", listed.About.ModHashes } }) is RubyBool { Flag: true });
                break;
            case "parking":
                ParkAndJoin();
                break;
            case "differing":
                _dataAccepted = true;
                Chain();
                break;
            case "own_data":
                UpdateData(true);
                break;
            case "update_data":
                UpdateData(false);
                break;
            default:
                throw new BridgeRequestException($"Nothing waits for a confirmation of {what}.");
        }
    }

    /// <summary>
    /// Takes the save the player picked to start the world from, or asks again when they picked none.
    /// </summary>
    /// <param name="index">The save's index, nil for none.</param>
    private void OwnSave(RubyValue index)
    {
        if (_starting == null || _worlds.Find(_starting) is not { } world)
        {
            return;
        }

        if (index.IsNil)
        {
            Log("left the save screen without a save, asking where to start again");
            Play(EnterRules.Where(world.Name, _startingFrom));
            return;
        }

        Log($"picked own save {index.AsInt() + 1} to start {world.Name} from");
        _steps.Add(new RubyArray { "copy_own", LocalWorldTopics.WorldOf(world), index });
    }

    /// <summary>
    /// Starts the world once the player's own save was copied into it, or says why not.
    /// </summary>
    /// <param name="ok">Whether the copy worked.</param>
    private void OwnCopied(bool ok)
    {
        if (ok)
        {
            StartWorld(_starting!, true);
            return;
        }

        LocalWorld? world = _worlds.Find(_starting!);
        Log($"the own save could not be copied into {world?.Name}");
        // A copy that failed halfway would otherwise be the world's first save.
        if (world != null)
        {
            _steps.Add(new RubyArray { "discard", LocalWorldTopics.WorldOf(world) });
        }

        Refuse($"Your save could not be copied into {world?.Name}.");
        Back();
    }

    /// <summary>
    /// Fetches the starting save of the world whose start is chosen, then starts it.
    /// </summary>
    private void Fetch()
    {
        if (_starting == null || _worlds.Find(_starting) is not { } world)
        {
            return;
        }

        _share();
        string folder = $"{WorldsFolder}/{world.Id}/{LocalWorlds.SaveFolder}";
        StartAction("start", () => _directory.FetchStart(world.Code, folder));
    }

    /// <summary>
    /// Has the scripts start a world from its latest save, or at the beginning without one.
    /// </summary>
    /// <param name="folder">The world's folder.</param>
    /// <param name="placed">Whether its save was just placed there, which the scripts check first.</param>
    private void StartWorld(string folder, bool placed)
    {
        if (_worlds.Find(folder) is not { } world)
        {
            Log($"entering {EntryText}: its folder {folder} could not be read");
            Refuse("The world's saves could not be read.");
            Back();
            return;
        }

        bool listed = _directory.Listed(_entry!.Id).World != null;
        _steps.Add(new RubyArray { "start", LocalWorldTopics.WorldOf(world), placed, listed, _fresh });
    }

    /// <summary>
    /// Says why a world could not be started, throwing away a save just placed, so the next entry
    /// starts anew instead of failing again.
    /// </summary>
    /// <param name="error">Why.</param>
    /// <param name="placed">Whether its save was just placed there.</param>
    private void StartFailed(string error, bool placed)
    {
        Log($"could not enter {EntryText}: {error}");
        if (placed && _starting != null && _worlds.Find(_starting) is { } world)
        {
            _steps.Add(new RubyArray { "discard", LocalWorldTopics.WorldOf(world) });
        }

        Refuse(error);
        Back();
    }

    /// <summary>
    /// Starts a directory action and holds the input while it runs.
    /// </summary>
    /// <param name="kind">The action's kind.</param>
    /// <param name="start">Starts it.</param>
    private void StartAction(string kind, Func<bool> start)
    {
        if (!start())
        {
            _enterAfterData = false;
            _afterRead = null;
            Log($"the {kind} request could not be started");
            Refuse(NotStartedText);
            Back();
            return;
        }

        _busy = kind;
        _toldEnded = false;
        _ticket = _tickets.Claim();
        _steps.Add(new RubyArray { "busy", kind });
    }

    /// <summary>
    /// Acts once the running action ended.
    /// </summary>
    private void Step()
    {
        if (_busy == null)
        {
            return;
        }

        (string state, string? error) = _directory.Action();
        if (state == "busy")
        {
            return;
        }

        string kind = _busy;
        _busy = null;
        bool enterAfterData = _enterAfterData;
        _enterAfterData = false;
        string? afterRead = _afterRead;
        _afterRead = null;
        var result = _directory.Result();
        _directory.Clear();
        _steps.Add(new RubyArray { "idle" });
        if (RequestEnded(kind, state, error, result))
        {
            return;
        }

        if (state == "failed")
        {
            Log($"{kind} of {EntryText} failed: {error}");
            // An invite's code that failed once is no better than none, so the password is asked next.
            if (kind == "unlock" && _entry != null && _inviteCodes.Remove(_entry.Id))
            {
                Log($"dropped the invite of {EntryText}: its password is asked next");
            }

            Refuse(error ?? "");
            Back();
            return;
        }

        switch (kind)
        {
            case "unlock":
                Log($"opened the lock of {EntryText}: start {result?.Start}, {(result?.Choose == true ? "player's choice" : "no choice")}");
                _steps.Add(new RubyArray { "leave_form" });
                if (EnterOpened(result))
                {
                    return;
                }

                break;
            case "start":
                Log($"fetched the starting save of {EntryText}");
                StartWorld(_starting!, true);
                return;
            case "read":
                ModsRead(afterRead);
                return;
            case "mods":
                Log($"installed the mods for {EntryText}");
                RestartForMods();
                return;
            case "data":
                Log($"the data of {EntryText} is this game's now");
                Say($"The data scan of {_entry!.Name} was updated to your game.");
                if (enterAfterData && _directory.Listed(_entry.Id).World != null)
                {
                    // The list holds the old scan until it is fetched again.
                    _dataTaken = true;
                    Chain();
                    return;
                }

                break;
        }

        _directory.Refresh(_lists.Added());
        Back();
    }

    /// <summary>
    /// Enters the world whose lock was opened, or asks to turn the mods off, or turns them off with the
    /// restart for the downloads, when the lock was opened for that.
    /// </summary>
    /// <param name="result">What the action handed back.</param>
    /// <returns>Whether it went on.</returns>
    private bool EnterOpened((string Code, string? World, string? Name, string? Start, bool Choose)? result)
    {
        string? park = _parkAfterUnlock;
        _parkAfterUnlock = null;
        if (result?.Start == "pending")
        {
            Log($"not entering {EntryText}: its creator still sets up its starting save");
            Buzz();
            Say($"{_entry!.Name} is still being set up by its creator. Try again in a moment.");
            return false;
        }

        ListedWorld? listed = _directory.Listed(_entry!.Id).World;
        LocalWorld? world = result is { } done ? _worlds.Found(done.Code, AboutOf(listed, null, done.World)) : null;
        if (world == null)
        {
            Log($"not entering {EntryText}: its folder could not be made");
            Say(WorldRequests.NoFolderText);
            return false;
        }

        _changes.Mark(WorldChanges.List);
        if (park != null)
        {
            _entry = _entry with { Folder = world.Id };
            if (park == "mods")
            {
                RestartForMods();
            }
            else
            {
                AskParking();
            }

            return true;
        }

        EnterFolder(world.Id, listed?.Start, listed?.Choose);
        return true;
    }

    /// <summary>
    /// Starts the game again once the world's mods are installed, turning other mods off in the same
    /// restart for a world that turns them off; a world this PC never entered has its lock opened first.
    /// </summary>
    private void RestartForMods()
    {
        _steps.Add(new RubyArray { "forget_installed" });
        Entry entry = _entry!;
        ListedWorld? listed = _directory.Listed(entry.Id).World;
        RubyHash request = new()
        {
            { "world", entry.Id },
            { "name", entry.Name },
            { "unlocked", entry.Folder != null || listed?.Open == true },
            { "mods", listed?.About.Mods },
            { "off", listed == null ? RubyNil.Value : listed.OtherModsOff },
        };
        RubyHash restarted = _context.Ask("parking.restart_for_mods", request)!.AsHash();
        switch (restarted["result"].AsText())
        {
            case "unlock":
                UnlockFirst("mods");
                break;
            case "restarting":
                Log($"closing the game to start it again for the mods of {EntryText}");
                _steps.Add(new RubyArray { "exit" });
                break;
            case "by_hand":
                Log($"the game could not start itself again, the player restarts it for {EntryText}");
                Say(Text(restarted["text"]));
                Back();
                break;
            default:
                Log($"installed the mods of {EntryText}, but other mods could not be turned off, kept off or turned back on: staying on the world screen");
                Refuse(Text(restarted["text"]));
                Back();
                break;
        }
    }

    /// <summary>
    /// Gives up the running action's answer as the screen closes.
    /// </summary>
    private void Close()
    {
        if (_busy != null)
        {
            _tickets.Release(_ticket);
            _busy = null;
        }
    }

    /// <summary>
    /// Goes back to the list, or, once the entry the game started again for ended without entering
    /// the world, puts the mods turned off for it back.
    /// </summary>
    private void Back()
    {
        if (_rejoinEntering && _holding())
        {
            GiveUp(_said);
            return;
        }

        _steps.Add(new RubyArray { "back" });
    }

    /// <summary>
    /// Ends the entry the game started again for: the scripts put the mods back and leave the screen.
    /// </summary>
    /// <param name="reason">What the screen said last; a question the player backed out of tells none.</param>
    private void GiveUp(string? reason)
    {
        Log("the entry the mods were turned off for ended without entering the world");
        _rejoinEntering = false;
        _steps.Add(new RubyArray { "give_up", reason == null || reason.EndsWith('?') ? null : reason });
    }

    /// <summary>
    /// Adds what the rules decided as steps.
    /// </summary>
    /// <param name="did">What the rules decided.</param>
    private void Play(IReadOnlyList<EnterDone> did)
    {
        foreach (EnterDone done in did)
        {
            switch (done.Kind)
            {
                case EnterRules.Say:
                    Say(done.Text!);
                    break;
                case EnterRules.Buzz:
                    Buzz();
                    break;
                case EnterRules.Back:
                    Back();
                    break;
                case EnterRules.Confirm:
                    Say(done.Text!);
                    Confirm(done.What!, (done.Yes!, "yes"), ("Back", EnterRules.Cancel));
                    break;
                case EnterRules.Choices:
                    _steps.Add(new RubyArray { "choices", Offered(done.Offered!) });
                    break;
                case EnterRules.Fetch:
                    Fetch();
                    break;
                case EnterRules.Start:
                    StartWorld(_starting!, false);
                    break;
            }
        }
    }

    /// <summary>
    /// Says a text in the screen's lines.
    /// </summary>
    /// <param name="text">The text.</param>
    private void Say(string text)
    {
        _said = text;
        _steps.Add(new RubyArray { "say", text });
    }

    /// <summary>
    /// Plays the buzzer.
    /// </summary>
    private void Buzz() => _steps.Add(new RubyArray { "buzz" });

    /// <summary>
    /// Refuses with the buzzer and a text.
    /// </summary>
    /// <param name="text">Why.</param>
    private void Refuse(string text)
    {
        Buzz();
        Say(text);
    }

    /// <summary>
    /// Asks the question said last, with its commands.
    /// </summary>
    /// <param name="what">What it is about.</param>
    /// <param name="offered">Each command's label and answer.</param>
    private void Confirm(string what, params (string Label, string Answer)[] offered)
    {
        _confirming = what;
        _steps.Add(new RubyArray { "confirm", what, Offered(offered) });
    }

    /// <summary>
    /// Writes commands as the scripts' windows take them.
    /// </summary>
    /// <param name="offered">Each command's label and answer.</param>
    /// <returns>[label, answer] each.</returns>
    private static RubyArray Offered(IEnumerable<(string Label, string Answer)> offered) =>
        new(offered.Select(choice => (RubyValue)new RubyArray { choice.Label, choice.Answer }));

    /// <summary>
    /// Writes what the directory says of a world as its folder keeps it.
    /// </summary>
    /// <param name="listed">The world, <see langword="null"/> when the list lacks it.</param>
    /// <param name="seats">Its seats to keep in its code, <see langword="null"/> to leave them.</param>
    /// <param name="id">Its id, when the list lacks it.</param>
    /// <returns>What its world.ini keeps.</returns>
    private LocalWorldAbout AboutOf(ListedWorld? listed, int? seats, string? id = null) => new(
        _entry!.Name,
        listed?.Id ?? id,
        seats,
        listed?.Type,
        listed?.Share,
        listed?.Difficulty,
        listed is { Squad.Length: > 0 } ? listed.Squad : null,
        listed?.RaidBosses);

    /// <summary>
    /// Gets whether the screen waits for the list to enter the world the game started again for or a Discord invite names.
    /// </summary>
    /// <summary>
    /// Gets this game's data fingerprint, empty before the scripts handed it.
    /// </summary>
    private string Data => _fingerprint();

    private bool Waiting => _rejoin != null || _invited != null;

    /// <summary>
    /// Gets whether the player made the world being entered.
    /// </summary>
    private bool Own => _entry != null && _me.Length > 0 && _directory.Listed(_entry.Id).World?.CreatorId == _me;

    /// <summary>
    /// Gets the world being entered, named for the log.
    /// </summary>
    private string EntryText => _entry == null ? "no world" : $"{_entry.Name} ({Short(_entry.Id)})";

    /// <summary>
    /// Names an entry of the list for the log.
    /// </summary>
    /// <param name="row">[id, folder, name, gone].</param>
    /// <returns>Its name and its id's start.</returns>
    private static string Of(RubyArray row) => $"{row[2].AsText()} ({Short(row[0].AsText())})";

    /// <summary>
    /// Shortens an id for the log.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first 12 characters.</returns>
    private static string Short(string id) => id.Length > 12 ? id[..12] : id;

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, empty for nil.</returns>
    private static string Text(RubyValue value) => value.IsNil ? "" : value.AsText();

    /// <summary>
    /// Writes a line of the world screen to the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => _context.Log.Write($"world screen: {line}");

    /// <summary>
    /// The world being entered as the list showed it.
    /// </summary>
    /// <param name="Id">The world's id.</param>
    /// <param name="Folder">This PC's folder of it, <see langword="null"/> before the player entered it.</param>
    /// <param name="Name">Its name.</param>
    /// <param name="Gone">Whether the list no longer has it.</param>
    private sealed record Entry(string Id, string? Folder, string Name, bool Gone);
}
