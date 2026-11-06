//----------------------------------------------------------------
//  WorldEntering.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Asked for a world's differing mods through the Mod Framework's dialog of the mods it needs, which installs them and starts the game again where it must
//      Paulinchen  2026-11-01: Had the scripts note a world started from another player's starting save, whose side is not the player's
//      Paulinchen  2026-10-30: Compared this game's data with a world's once the world's mods loaded, warning of a difference instead of asking or keeping the game out
//                            - Entered a world that turns other mods off without parking them, which the Mod Framework's session leaves out
//                            - Had the scripts install a world's mods through the Mod Framework and entered without a restart
//                            - Started the game again for a mod that runs only once the world's lock is open
//                            - Had the creator update a data scan of another format before entering
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
using MGQOnline.Game.Mods;
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
/// now, its required mods, which the Mod Framework's dialog makes ready, the catalog its other mods
/// turned off need, its password, where a new player starts, the starting save, a Discord invite
/// and the entry after a restart; and the check of this game's data once the world's mods loaded. The scripts hand over
/// the player's choices and what their effects did, and keep the windows, the forms, the saves and
/// the scenes.
/// </summary>
/// <remarks>
/// It builds on the topics of the areas it asks in-process (mods.check, mods.forget,
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
    /// Runs a command of the screen: <c>do</c> (open, look, read_for_edit, close) and
    /// what it needs in; <c>steps</c> and <c>waiting</c> (whether the screen waits for the list to
    /// enter a world) out.
    /// </summary>
    public const string DoTopic = "screen.do";

    /// <summary>
    /// Compares this game's data, measured once the world's mods loaded, with the world's data scan:
    /// <c>world</c> (its directory id) and <c>data</c> (this game's fingerprint) in; the warning the
    /// player reads out, nil for none. The creator's game makes its data the world's instead.
    /// </summary>
    public const string DataCheckTopic = "worlds.data_check";

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
    /// What the question being asked is about, such as "mods".
    /// </summary>
    private string? _confirming;

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
    /// Creates the steps.
    /// </summary>
    /// <param name="context">The context, whose topics of other areas the steps ask.</param>
    /// <param name="directory">The world directory.</param>
    /// <param name="worlds">The worlds on this PC.</param>
    /// <param name="lists">The player's lists of worlds.</param>
    /// <param name="share">Shares who plays with the worlds.</param>
    /// <param name="tickets">Tells whose answer the directory's action is.</param>
    /// <param name="changes">The changes the scripts are told of.</param>
    public WorldEntering(BridgeContext context, IEnteringDirectory directory, LocalWorlds worlds, WorldLists lists, Func<bool> share, DirectoryTickets tickets, WorldChanges changes)
    {
        _context = context;
        _directory = directory;
        _worlds = worlds;
        _lists = lists;
        _share = share;
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
        _context.Register(DataCheckTopic, (_, request) => DataChecked(request.AsHash()));
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
                return;
            }

            Log($"entering {Of(found)} again after the restart for its mods");
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
        Chain();
    }

    /// <summary>
    /// Enters the world the player chose.
    /// </summary>
    /// <param name="request">The entry, <c>me</c> and <c>data</c>.</param>
    private void Enter(RubyHash request)
    {
        Take(request);
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
    /// mods, the catalog its other mods turned off need, then its folder, lock or password.
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
            if (!ModsAllow(listed) || !CatalogAllows(listed))
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
    /// Decides whether this game may enter as far as the world's required mods go: while any differs,
    /// the scripts open the Mod Framework's dialog of the mods the world needs, which installs, updates
    /// or turns them on, names those only their authors have, and answers <c>mods_ready</c> or
    /// <c>back</c>, or starts the game again into the world.
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

        RubyArray needed = new(rows.Select(row => row.AsHash()).Select(row => (RubyValue)new RubyHash
        {
            { "name", row["name"] },
            { "version", row["worlds"] },
            { "differs", row["yours"].AsText() == ModCheck.Differs },
        }));
        Log($"{EntryText} needs mods that differ here: {string.Join(", ", rows.Select(row => row.AsHash()["text"].AsText()))}; asking through the Mod Framework");
        _steps.Add(new RubyArray { "needed_mods", _entry.Name, needed });
        return false;
    }

    /// <summary>
    /// Decides whether this game may enter as far as other mods go: a world that turns them off needs
    /// the catalog, which tells the personal mods its session keeps besides those it names.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <returns>Whether entering goes on now.</returns>
    private bool CatalogAllows(ListedWorld listed)
    {
        if (!listed.OtherModsOff || _context.Ask("mods.check", new RubyHash { { "mods", listed.About.Mods }, { "hashes", listed.About.ModHashes }, { "world", RubyNil.Value } })!.AsHash()["known"].AsBool())
        {
            return true;
        }

        Log($"kept out of {EntryText}: it turns other mods off, and the catalog that tells the personal mods is unknown");
        Refuse(SessionMods.Catalog);
        Back();
        return false;
    }

    /// <summary>
    /// Compares this game's data, measured once the world's mods loaded, with the world's data scan,
    /// whatever the world's type: a game that differs is warned and plays on, and the creator's game
    /// makes its data the world's.
    /// </summary>
    /// <param name="request"><c>world</c> and <c>data</c>.</param>
    /// <returns>The warning, nil for none.</returns>
    private RubyValue? DataChecked(RubyHash request)
    {
        string id = Text(request["world"]);
        string data = Text(request["data"]);
        ListedWorld? listed = _directory.Listed(id).World;
        if (listed == null || data.Length == 0)
        {
            Log($"data check of world {Short(id)}: {(listed == null ? "the list lacks it" : "this game's data could not be read")}, not compared");
            return null;
        }

        string? scan = listed.About.Data;
        if (_me.Length > 0 && listed.CreatorId == _me)
        {
            TakeData(listed, data, scan);
            return null;
        }

        IReadOnlyList<string>? differing = GameDataCompare.Differing(data, scan);
        Log(differing == null ? $"data check of {listed.Name}: not compared, {(GameDataCompare.OtherFormat(data, scan) ? "its scan has another format" : "it has no scan")} until its creator enters"
            : differing.Count == 0 ? $"data check of {listed.Name}: matches"
            : $"data check of {listed.Name}: differs in {string.Join(", ", differing)}, the player is warned");
        return EnterRules.DataWarning(listed.Name, differing) is { } warning ? warning : null;
    }

    /// <summary>
    /// Makes the creator's game data the world's data scan while it differs, without waiting for the
    /// answer, which nobody takes.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <param name="data">The creator's game data.</param>
    /// <param name="scan">The world's data scan.</param>
    private void TakeData(ListedWorld listed, string data, string? scan)
    {
        if (data == scan)
        {
            Log($"data check of {listed.Name}: the creator's game matches the world's scan");
            return;
        }

        if (!_tickets.Free() || !_directory.SetData(listed.Id, data))
        {
            Log($"data check of {listed.Name}: the world's scan could not be replaced with the creator's game data now, it is tried again on the next entry");
            return;
        }

        _tickets.Release(_tickets.Claim());
        Log($"data check of {listed.Name}: the creator's game data becomes the world's scan{(string.IsNullOrEmpty(scan) ? ", which it had none of" : "")}");
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
            case "mods_ready":
                ModsReady();
                break;
            case "mods_restarting":
                Log($"the game starts again to enter {EntryText} with its mods loaded anew");
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
            default:
                throw new BridgeRequestException($"Nothing waits for a confirmation of {what}.");
        }
    }

    /// <summary>
    /// Goes on once the Mod Framework made the world's mods ready, which load as the player enters
    /// it, with what Patch held forgotten.
    /// </summary>
    private void ModsReady()
    {
        Log($"the mods of {EntryText} are ready, entering it");
        _context.Ask(ModCheckTopics.ForgetTopic);
        _steps.Add(new RubyArray { "forget_installed" });
        Chain();
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
    /// <param name="othersSave">Whether the save placed is another player's starting save, which the scripts note first.</param>
    private void StartWorld(string folder, bool placed, bool othersSave = false)
    {
        if (_worlds.Find(folder) is not { } world)
        {
            Log($"entering {EntryText}: its folder {folder} could not be read");
            Refuse("The world's saves could not be read.");
            Back();
            return;
        }

        bool listed = _directory.Listed(_entry!.Id).World != null;
        if (othersSave)
        {
            _steps.Add(new RubyArray { "other_start", LocalWorldTopics.WorldOf(world) });
        }

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
                Log($"fetched the starting save of {EntryText}{(Own ? "" : ", another player's")}");
                StartWorld(_starting!, true, !Own);
                return;
            case "read":
                ModsRead(afterRead);
                return;
        }

        _directory.Refresh(_lists.Added());
        Back();
    }

    /// <summary>
    /// Enters the world whose lock was opened.
    /// </summary>
    /// <param name="result">What the action handed back.</param>
    /// <returns>Whether it went on.</returns>
    private bool EnterOpened((string Code, string? World, string? Name, string? Start, bool Choose)? result)
    {
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
        EnterFolder(world.Id, listed?.Start, listed?.Choose);
        return true;
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
    /// Goes back to the list.
    /// </summary>
    private void Back() => _steps.Add(new RubyArray { "back" });

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
