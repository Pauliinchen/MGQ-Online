//----------------------------------------------------------------
//  SharedSettingsSync.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Took the creator's options and the Mod Config groups as values, and handed the settings to apply as values
//      Paulinchen  2026-11-01: Dropped the topic that marks settings shared, which no script calls
//      Paulinchen  2026-10-31: Took the world's settings from the relay, which tells every player, instead of the creator's game telling each
//      Paulinchen  2026-10-23: Handed the world screen the details line of the shared settings
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// What the shared settings need of the world directory: sending a world's settings as its one
/// action, and reading the one world's settings on the relay as they stand.
/// </summary>
internal interface ISettingsDirectory
{
    /// <summary>
    /// Starts sending a world's settings as the directory's action.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="settings">The settings.</param>
    /// <returns>Whether it started.</returns>
    bool SetSettings(string id, string settings);

    /// <summary>
    /// Tells how the running or last action stands.
    /// </summary>
    /// <returns>Its state ("idle", "busy", "done" or "failed"), its kind and why it failed.</returns>
    (string State, string? Kind, string? Error) ActionNow();

    /// <summary>
    /// Forgets the last action's answer.
    /// </summary>
    void ClearAction();

    /// <summary>
    /// Starts reading a world's settings on the relay.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>Whether it started; false while a reading runs.</returns>
    bool ReadSettings(string id);

    /// <summary>
    /// Tells how the reading of a world's settings stands.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>"busy", "done" with the settings, or "failed" (also for a reading of another world).</returns>
    (string State, string? Settings) SettingsRead(string id);
}

/// <summary>
/// The shared mod settings of the world being entered or played in: which settings hold, sending
/// the creator's to the relay after reading the relay's and merging what changed there, taking the
/// settings the relay tells every player, and the notices. The scripts hand the creator's options
/// and apply what this decides, through steps (see <see cref="StepTopic"/>), since only the running
/// game can read and write Mod Config.
/// </summary>
internal sealed class SharedSettingsSync
{
    /// <summary>
    /// Notes the world being entered: <c>world</c> ({<c>id</c>, <c>name</c>, <c>creator_id</c>,
    /// <c>creator_name</c>, <c>mods</c>, <c>settings</c>}, nil when the list lacks it), <c>me</c>, <c>fresh</c>
    /// (whether the list was fetched since the world screen opened) and <c>options</c> (see <see cref="GroupsTopic"/>) in.
    /// </summary>
    public const string EnterTopic = "settings.enter";

    /// <summary>
    /// Forgets the world and the settings on their way, whose answer the directory then drops.
    /// </summary>
    public const string ForgetTopic = "settings.forget";

    /// <summary>
    /// Takes this game's Mod Config groups: [[group, [[key, short name, [[value, name], ...]], ...]], ...], each value as <see cref="SharedSettings.ValueOf"/> reads it.
    /// </summary>
    public const string GroupsTopic = "settings.options";

    /// <summary>
    /// Notes that a save of the world was loaded or started: <c>applied</c> (the option keys the scripts
    /// set), <c>options</c> ([key, value] of the creator's options of the world's mods, see <see cref="SharedSettings.ValueOf"/>) and <c>known</c>
    /// (every option key of this game's Mod Config) in.
    /// </summary>
    public const string LoadedTopic = "settings.loaded";

    /// <summary>
    /// Makes the creator's options the world's settings: <c>reason</c> ("options" as the options
    /// screen closes, "switch" for the row of Shared Mod Settings), <c>on</c> (the switch's value),
    /// <c>options</c> and <c>known</c> in.
    /// </summary>
    public const string WantTopic = "settings.want";

    /// <summary>
    /// Hands out the steps waiting for the scripts.
    /// </summary>
    public const string StepTopic = "settings.step";

    /// <summary>
    /// Takes the options the scripts set for an <c>apply_live</c> step: <c>keys</c> in.
    /// </summary>
    public const string AppliedTopic = "settings.applied";

    /// <summary>
    /// Takes the world's settings the relay told: <c>by</c> ("creator" or "admin" for a change, empty
    /// as the game enters the world) and <c>text</c> in.
    /// </summary>
    public const string LiveTopic = "settings.live";

    /// <summary>
    /// Takes the mods the relay tells the open world names now: the mods as written in.
    /// </summary>
    public const string ModsTopic = "settings.mods";

    /// <summary>
    /// Reads a world's settings as they stand: <c>id</c>, <c>settings</c> (the list's) and <c>fresh</c> in; the settings out.
    /// </summary>
    public const string OfTopic = "settings.of";

    /// <summary>
    /// Notes the settings the relay took from this game for a world: <c>id</c> and <c>text</c> in.
    /// </summary>
    public const string ConfirmedTopic = "settings.confirmed";

    /// <summary>
    /// Tells whether settings are shared: the settings in; true or false out.
    /// </summary>
    public const string SharedTopic = "settings.shared";

    /// <summary>
    /// Says what the details say about a world's settings: <c>settings</c>, <c>creator_id</c>,
    /// <c>creator_name</c> and <c>me</c> in; the text out.
    /// </summary>
    public const string DetailsTopic = "settings.details";

    /// <summary>
    /// The kind of directory action that sends the settings.
    /// </summary>
    public const string ShareAction = "settings";

    /// <summary>
    /// Frames before settings that could not be sent are tried again, two seconds.
    /// </summary>
    public const long RetryFrames = 120;

    /// <summary>
    /// Frames the relay may take to answer settings sent or the world's settings asked for, thirty seconds.
    /// </summary>
    public const long SendFrames = 1800;

    /// <summary>
    /// Frames a notice shows, ten seconds.
    /// </summary>
    public const long NoticeFrames = 600;

    /// <summary>
    /// Most lines a notice takes, which leaves room for two invites in the box's five rows.
    /// </summary>
    public const int NoticeLines = 3;

    /// <summary>
    /// Most characters of a notice's line.
    /// </summary>
    public const int NoticeLineChars = 46;

    /// <summary>
    /// The reason of a load.
    /// </summary>
    private const string LoadReason = "load";

    /// <summary>
    /// Who the relay names when an admin changed the settings.
    /// </summary>
    private const string AdminBy = "admin";

    /// <summary>
    /// The directory.
    /// </summary>
    private readonly ISettingsDirectory _directory;

    /// <summary>
    /// Whose answer the directory's action is.
    /// </summary>
    private readonly DirectoryTickets _tickets;

    /// <summary>
    /// Where the lines go.
    /// </summary>
    private readonly IBridgeLog _log;

    /// <summary>
    /// Marks that steps wait.
    /// </summary>
    private readonly Action _changed;

    /// <summary>
    /// The settings the relay took from this game last, by the world's id.
    /// </summary>
    private readonly Dictionary<string, string> _confirmed = new(StringComparer.Ordinal);

    /// <summary>
    /// The steps waiting for the scripts.
    /// </summary>
    private readonly List<RubyValue> _steps = [];

    /// <summary>
    /// The notices, naming options as this game's Mod Config groups them.
    /// </summary>
    private SettingNotices _notices = new([]);

    /// <summary>
    /// The world being entered or played in, <see langword="null"/> outside one.
    /// </summary>
    private World? _world;

    /// <summary>
    /// Whether a save of the world was loaded or started.
    /// </summary>
    private bool _loaded;

    /// <summary>
    /// Whether the player was told what the world shares during this stay.
    /// </summary>
    private bool _stayNoticed;

    /// <summary>
    /// The frame that notice was posted at.
    /// </summary>
    private long? _stayAt;

    /// <summary>
    /// The settings wanted last that are not on their way yet.
    /// </summary>
    private string? _wanted;

    /// <summary>
    /// What the creator's options started from, which tells what they changed.
    /// </summary>
    private string? _wantedBase;

    /// <summary>
    /// Why the settings are wanted: "switch", "load" or "options".
    /// </summary>
    private string _wantedReason = LoadReason;

    /// <summary>
    /// How many options did not fit into the settings wanted last.
    /// </summary>
    private int _leftOut;

    /// <summary>
    /// The settings on their way, <see langword="null"/> while none are.
    /// </summary>
    private Sending? _sending;

    /// <summary>
    /// The frame settings that could not be sent are tried again at.
    /// </summary>
    private long? _retryAt;

    /// <summary>
    /// Whether the creator was told that settings cannot be sent yet.
    /// </summary>
    private bool _notSentTold;

    /// <summary>
    /// Whether the relay's settings must be read before the next sending.
    /// </summary>
    private bool _needCheck;

    /// <summary>
    /// The frame the running reading of the relay's settings started at, <see langword="null"/> while none runs.
    /// </summary>
    private long? _checkSince;

    /// <summary>
    /// Whether a reading waits to start.
    /// </summary>
    private bool _checkWanted;

    /// <summary>
    /// The relay's settings as last read, <see langword="null"/> when unknown.
    /// </summary>
    private string? _relayText;

    /// <summary>
    /// The live settings the scripts are applying, for their notice once applied.
    /// </summary>
    private (string Before, string After, string Name)? _live;

    /// <summary>
    /// The game's frame, the clock of the timers.
    /// </summary>
    private long _frame;

    /// <summary>
    /// Creates the shared settings.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <param name="tickets">Whose answer the directory's action is.</param>
    /// <param name="log">Where the lines go.</param>
    /// <param name="changed">Marks that steps wait.</param>
    public SharedSettingsSync(ISettingsDirectory directory, DirectoryTickets tickets, IBridgeLog log, Action changed)
    {
        _directory = directory;
        _tickets = tickets;
        _log = log;
        _changed = changed;
    }

    /// <summary>
    /// Registers the shared settings of the game's own directory on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds and mods share.</param>
    /// <returns>The sync, whose details line the world screen reads too.</returns>
    public static SharedSettingsSync Register(BridgeContext context, WorldServices services)
    {
        SharedSettingsSync sync = new(new DirectorySettings(services), services.Tickets, context.Log, () => services.Changes.Mark(WorldChanges.Settings));
        sync.Register(context);
        return sync;
    }

    /// <summary>
    /// Registers the topics on a context and follows the settings at each of its drains.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public void Register(BridgeContext context)
    {
        context.EveryFrame(drained => Tick(drained.Frame));
        context.Register(EnterTopic, (_, request) => Reply(() => Enter(request.AsHash())));
        context.Register(ForgetTopic, (_, _) => Reply(Forget));
        context.Register(GroupsTopic, (_, request) => Reply(() => TakeOptions(request)));
        context.Register(LoadedTopic, (_, request) => Reply(() => Loaded(request.AsHash())));
        context.Register(WantTopic, (_, request) => Reply(() => Want(request.AsHash())));
        context.Register(StepTopic, (_, _) => Reply(() => { }));
        context.Register(AppliedTopic, (_, request) => Reply(() => Applied(Keys(request.AsHash()["keys"]))));
        context.Register(LiveTopic, (_, request) => Reply(() => Live(request.AsHash())));
        context.Register(ModsTopic, (_, request) => Reply(() => TakeMods(Text(request))));
        context.Register(OfTopic, (_, request) => SettingsOf(request.AsHash()));
        context.Register(ConfirmedTopic, (_, request) =>
        {
            _confirmed[request.AsHash()["id"].AsText()] = Text(request.AsHash()["text"]);
            return null;
        });
        context.Register(SharedTopic, (_, request) => SharedSettings.IsShared(Text(request)));
        context.Register(DetailsTopic, (_, request) => Details(request.AsHash()));
    }

    /// <summary>
    /// Follows the settings on their way and the reading of the relay's; called at each drain.
    /// </summary>
    /// <param name="frame">The game's frame.</param>
    internal void Tick(long frame)
    {
        _frame = frame;
        if (_sending != null)
        {
            FollowSend();
        }

        if (_checkSince != null)
        {
            FollowCheck();
        }

        if (_checkWanted && _checkSince == null && _sending == null)
        {
            CheckRelay();
        }

        if (_wanted != null && _sending == null)
        {
            Pump();
        }
    }

    /// <summary>
    /// Runs a change and answers the world as it stands with the steps that wait.
    /// </summary>
    /// <param name="change">The change.</param>
    /// <returns>{<c>world</c>, <c>steps</c>}.</returns>
    private RubyHash Reply(Action change)
    {
        change();
        RubyArray steps = new(_steps.ToArray());
        _steps.Clear();
        return new RubyHash { { "world", WorldValue() }, { "steps", steps } };
    }

    /// <summary>
    /// Describes the world for the scripts.
    /// </summary>
    /// <returns>Its id, name, creator, mods, the values its settings set (<see cref="SharedSettings.PlainValues"/>), whether it is the player's own and whether the settings it will have are shared; nil outside a world.</returns>
    private RubyValue WorldValue() => _world is not { } world ? RubyNil.Value : new RubyHash
    {
        { "id", world.Id },
        { "name", world.Name },
        { "creator_id", world.CreatorId },
        { "creator_name", world.CreatorName },
        { "mods", world.Mods },
        { "values", SharedSettings.PlainValues(world.Text) },
        { "own", world.Own },
        { "shared", SharedSettings.IsShared(world.Text) },
        { "latest_shared", SharedSettings.IsShared(LatestText()) },
    };

    /// <summary>
    /// Notes the world being entered, whose settings apply once its game is loaded or started.
    /// </summary>
    /// <remarks>
    /// A list from before the world screen opened may predate settings this game saved since, which
    /// would otherwise go back to every player the creator meets.
    /// </remarks>
    /// <param name="request">The world, the player's id, whether the list is fresh and the options.</param>
    private void Enter(RubyHash request)
    {
        Forget();
        if (request.TryGetValue("options", out RubyValue? options) && !options.IsNil)
        {
            TakeOptions(options);
        }

        if (request["world"].IsNil)
        {
            Log("entering a world the list lacks: no mod settings apply");
            return;
        }

        RubyHash listed = request["world"].AsHash();
        string id = listed["id"].AsText();
        string me = Text(request["me"]);
        bool fresh = request["fresh"].AsBool();
        string creatorId = Text(listed["creator_id"]);
        string text = SettingsOf(id, Text(listed["settings"]), fresh);
        if (fresh)
        {
            _confirmed.Remove(id);
        }

        _world = new World(id, Text(listed["name"]), creatorId, PlayerIni.Cleaned(Text(listed["creator_name"]), "A friend"), Text(listed["mods"]), me.Length > 0 && creatorId == me) { Text = text };
        int count = SharedSettings.Values(text).Count;
        Log($"entering {(_world.Own ? "the player's own world" : "a world")} {Short(id)}: {(SharedSettings.IsShared(text) ? $"it shares {count} mod setting(s)" : "each player keeps their own mod settings")}");
    }

    /// <summary>
    /// Forgets the world and what is on its way.
    /// </summary>
    private void Forget()
    {
        if (_world != null)
        {
            Log($"forgot the mod settings of world {Short(_world.Id)}");
        }

        if (_sending != null)
        {
            _tickets.Release(_sending.Ticket);
        }

        _world = null;
        _loaded = false;
        _stayNoticed = false;
        _stayAt = null;
        _wanted = null;
        _wantedBase = null;
        _sending = null;
        _notSentTold = false;
        _live = null;
        ForgetCheck();
    }

    /// <summary>
    /// Takes this game's Mod Config groups.
    /// </summary>
    /// <param name="options">The groups.</param>
    private void TakeOptions(RubyValue options) =>
        _notices = new SettingNotices([.. options.AsArray().Select(group => new SettingGroup(
            group.AsArray()[0].AsText(),
            [.. group.AsArray()[1].AsArray().Select(option => new SettingOption(
                option.AsArray()[0].AsText(),
                option.AsArray()[1].AsText(),
                [.. option.AsArray()[2].AsArray().Select(name => (Value: SharedSettings.ValueOf(name.AsArray()[0]), Name: name.AsArray()[1].AsText())).Where(name => name.Value is not null).Select(name => new KeyValuePair<string, string>(SharedSettings.Encode(name.Value!.Value), name.Name))]))]))]);

    /// <summary>
    /// Takes a loaded or started save of the world: the creator's options become the world's while
    /// it shares them, and the player is told once per stay what the world sets.
    /// </summary>
    /// <param name="request">The options applied, the creator's options and the known keys.</param>
    private void Loaded(RubyHash request)
    {
        if (_world == null)
        {
            return;
        }

        _loaded = true;
        Row();
        if (!SharedSettings.IsShared(_world.Text))
        {
            Log($"world {Short(_world.Id)} does not share mod settings: every player keeps their own");
            return;
        }

        // The creator's notice names what sync makes the world's settings, and what did not fit.
        Sync(LoadReason, request);
        NoticeStay(Keys(request["applied"]));
    }

    /// <summary>
    /// Takes the creator's options as the options screen closes or the row of Shared Mod Settings changes.
    /// </summary>
    /// <param name="request">The reason, the switch's value, the creator's options and the known keys.</param>
    private void Want(RubyHash request)
    {
        string reason = request["reason"].AsText();
        if (reason != SharedSettings.SwitchReason)
        {
            Sync(reason, request);
            return;
        }

        if (_world is not { Own: true } world)
        {
            Log("Shared Mod Settings not changed: the player is not in a world they created");
            Row();
            return;
        }

        bool on = request["on"].AsBool();
        (string text, List<string> leftOut) = on ? SharedSettings.Build(SharedSettings.PairsOf(request["options"]), Keys(request["known"]), LatestText()) : ("", []);
        _leftOut = leftOut.Count;
        Log($"the creator turned Shared Mod Settings {(on ? "on" : "off")} in world {Short(world.Id)}");
        Request(text, reason);
        Row();
    }

    /// <summary>
    /// Makes the creator's options of the world's mods its settings while it shares them, when they differ.
    /// </summary>
    /// <param name="reason">"load" or "options".</param>
    /// <param name="request">The creator's options and the known keys.</param>
    private void Sync(string reason, RubyHash request)
    {
        if (_world is not { Own: true } || !SharedSettings.IsShared(LatestText()))
        {
            return;
        }

        (string text, List<string> leftOut) = SharedSettings.Build(SharedSettings.PairsOf(request["options"]), Keys(request["known"]), LatestText());
        if (leftOut.Count > 0)
        {
            Log($"left out {leftOut.Count} mod setting(s) past {SharedSettings.MaxChars} characters: {string.Join(", ", leftOut)}");
        }

        _leftOut = leftOut.Count;
        Request(text, reason);
    }

    /// <summary>
    /// Tells the settings the world has once every request on its way arrived.
    /// </summary>
    /// <returns>The settings.</returns>
    private string LatestText() =>
        _wanted ?? (_sending != null && _sending.Id == _world?.Id ? _sending.Text : null) ?? _world?.Text ?? "";

    /// <summary>
    /// Asks the relay to take settings as the world's, once the request on its way arrived and the
    /// relay's settings were read, which someone else may have changed since.
    /// </summary>
    /// <param name="text">The settings.</param>
    /// <param name="reason">Why.</param>
    private void Request(string text, string reason)
    {
        if (_wanted == null)
        {
            _wantedBase = LatestText();
        }

        _wanted = text;
        _wantedReason = reason;
        _retryAt = null;
        _needCheck = true;
        Pump();
    }

    /// <summary>
    /// Sends the settings wanted last, unless a request is on its way or the world has them already;
    /// first reads the relay's settings and takes in what changed there.
    /// </summary>
    private void Pump()
    {
        if (_sending != null || _wanted == null || _world == null)
        {
            return;
        }

        if (_needCheck || _checkSince != null)
        {
            CheckRelay();
            return;
        }

        if (_relayText != null && _relayText != _world.Text)
        {
            MergeRelay();
        }

        if (_wanted == _world.Text)
        {
            Log("the world's mod settings are as wanted already, nothing sent");
            _wanted = null;
            return;
        }

        if (_retryAt != null && _frame < _retryAt)
        {
            return;
        }

        // A request now would drop the answer of another one nobody took yet.
        if (!_tickets.Free() || !_directory.SetSettings(_world.Id, _wanted))
        {
            _retryAt = _frame + RetryFrames;
            Log("the world's mod settings could not be sent, trying again in a moment");
            if (!_notSentTold)
            {
                Notify(SettingNotices.NotSentText);
            }

            _notSentTold = true;
            return;
        }

        _notSentTold = false;
        _sending = new Sending(_world.Id, _wanted, _world.Text, _wantedReason, _leftOut, _frame, _tickets.Claim());
        _wanted = null;
        _wantedBase = null;
    }

    /// <summary>
    /// Takes the relay's answer to the settings on their way, or sends them again when another
    /// request took the place of their answer.
    /// </summary>
    private void FollowSend()
    {
        Sending sending = _sending!;
        if (!_tickets.Mine(sending.Ticket))
        {
            Resend();
            return;
        }

        var (state, kind, error) = _directory.ActionNow();
        if (state == "busy" || kind != ShareAction)
        {
            if (_frame - sending.Since <= SendFrames)
            {
                return;
            }

            Log("the relay never answered the world's mod settings, giving up");
            _tickets.Release(sending.Ticket);
            _sending = null;
            Notify(SettingNotices.FailedText);
            Row();
            return;
        }

        _directory.ClearAction();
        _sending = null;
        if (state != "done")
        {
            Log($"the relay did not take the world's mod settings: {error}");
            Notify(SettingNotices.FailedText);
        }
        else
        {
            _confirmed[sending.Id] = sending.Text;
            if (_world != null && _world.Id == sending.Id)
            {
                _world.Text = sending.Text;
                _relayText = sending.Text;
                TellCreator(sending);
            }
            else
            {
                Log($"the relay took the mod settings of world {Short(sending.Id)}, which is no longer open");
            }
        }

        Row();
        Pump();
    }

    /// <summary>
    /// Puts the settings on their way back as wanted, unless newer ones wait.
    /// </summary>
    private void Resend()
    {
        Sending sent = _sending!;
        _sending = null;
        Log("the answer to the world's mod settings gave way to another directory request, sending them again");
        if (_wanted == null)
        {
            _wanted = sent.Text;
            _wantedReason = sent.Reason;
            _leftOut = sent.LeftOut;
        }

        _wantedBase = sent.Before;
        _needCheck = true;
    }

    /// <summary>
    /// Takes in settings someone else gave the world on the relay: they become the world's, and the
    /// settings wanted keep only what the creator changed.
    /// </summary>
    private void MergeRelay()
    {
        string theirs = _relayText!;
        Adopt(theirs);
        string merged = SharedSettings.Merged(_wantedBase ?? "", _wanted!, theirs, _wantedReason);
        Log($"kept what the creator changed over the relay's settings: {(merged.Length == 0 ? "none" : merged)}");
        _wanted = merged;
        _wantedBase = theirs;
        ApplyIfLoaded(merged);
        Row();
    }

    /// <summary>
    /// Takes the relay's settings this game did not know of as the world's, and tells the creator what changed.
    /// </summary>
    /// <param name="text">The relay's settings.</param>
    private void Adopt(string text)
    {
        World world = _world!;
        string before = world.Text;
        world.Text = text;
        _confirmed[world.Id] = text;
        Log($"the relay holds other mod settings of the world than this game knew, which count: {(text.Length == 0 ? "none" : text)}");
        if (_notices.RelayChange(before, text) is { } message)
        {
            Notify(message);
        }
    }

    /// <summary>
    /// Starts reading the world's settings on the relay, once no request of this is on its way.
    /// </summary>
    private void CheckRelay()
    {
        _checkWanted = true;
        if (_checkSince != null || _sending != null)
        {
            return;
        }

        if (_world is not { Own: true } world)
        {
            _checkWanted = false;
            _needCheck = false;
            return;
        }

        if (!_directory.ReadSettings(world.Id))
        {
            return;
        }

        _checkWanted = false;
        _checkSince = _frame;
        Log("asking the relay for the world's mod settings as they stand");
        FollowCheck();
    }

    /// <summary>
    /// Takes the world's settings read from the relay once they came, or gives up on them.
    /// </summary>
    private void FollowCheck()
    {
        var (state, settings) = _directory.SettingsRead(_world!.Id);
        if (state == "busy")
        {
            if (_frame - _checkSince!.Value <= SendFrames)
            {
                return;
            }

            Log("the relay never told the world's mod settings, so they are unknown");
            CompleteCheck(null);
            return;
        }

        if (state != "done")
        {
            Log("the world could not be read, so its mod settings on the relay are unknown");
        }

        CompleteCheck(state == "done" ? settings ?? "" : null);
    }

    /// <summary>
    /// Notes the relay's settings, takes them as the world's when someone else changed them while
    /// nothing waits to be sent, and sends what waits.
    /// </summary>
    /// <param name="text">The relay's settings, <see langword="null"/> when unknown.</param>
    private void CompleteCheck(string? text)
    {
        _checkSince = null;
        _needCheck = false;
        _relayText = text;
        if (text != null && text != _world!.Text && _wanted == null)
        {
            TakeRelay(text);
        }

        Pump();
    }

    /// <summary>
    /// Takes settings someone else gave the world on the relay as the world's, which the creator's
    /// options get; the relay tells every other player.
    /// </summary>
    /// <param name="text">The relay's settings.</param>
    private void TakeRelay(string text)
    {
        Adopt(text);
        ApplyIfLoaded(text);
        Row();
    }

    /// <summary>
    /// Forgets the reading of the relay's settings.
    /// </summary>
    private void ForgetCheck()
    {
        _checkSince = null;
        _checkWanted = false;
        _needCheck = false;
        _relayText = null;
    }

    /// <summary>
    /// Tells the creator what the players got from the settings the relay took.
    /// </summary>
    /// <param name="sent">The request.</param>
    private void TellCreator(Sending sent)
    {
        bool was = SharedSettings.IsShared(sent.Before);
        bool now = SharedSettings.IsShared(sent.Text);
        // The notice of the stay that a load starts named what did not fit already.
        bool told = sent.Reason == LoadReason && StayRecent();
        string? leftOut = now && sent.LeftOut > 0 && !told ? SettingNotices.Format(SettingNotices.LeftOutText, sent.LeftOut.ToString(CultureInfo.InvariantCulture)) : null;
        string? text = null;
        if (was != now)
        {
            text = now ? _notices.CreatorOn(_notices.KnownKeys(SharedSettings.Values(sent.Text).Select(value => value.Key))) : SettingNotices.CreatorOffText;
        }
        else if (now && sent.Reason != LoadReason && _notices.Changes(sent.Before, sent.Text) is { } changes)
        {
            text = SettingNotices.Format(SettingNotices.CreatorChangeText, changes);
        }

        Log($"the relay took the world's mod settings ({sent.Reason}): {(sent.Text.Length == 0 ? "none, each player keeps their own" : sent.Text)}");
        string message = string.Join(" ", new[] { leftOut, text }.OfType<string>());
        if (message.Length > 0)
        {
            Notify(message);
        }
    }

    /// <summary>
    /// Takes the world's settings the relay told, as the game enters the world and once its creator
    /// or an admin changed them: they apply at once while a save of the world is loaded, and
    /// otherwise once one is.
    /// </summary>
    /// <param name="request">Who changed them and the settings.</param>
    private void Live(RubyHash request)
    {
        if (_world is not { } world)
        {
            return;
        }

        string text = Text(request["text"]);
        if (text == world.Text)
        {
            return;
        }

        if (world.Own)
        {
            CreatorTold(text);
            return;
        }

        string name = Text(request["by"]) == AdminBy ? SettingNotices.AdminName : world.CreatorName;
        string before = world.Text;
        world.Text = text;
        Log($"the relay told the world's mod settings, {(Text(request["by"]).Length == 0 ? "newer than the list" : $"changed by {name}")}: {(text.Length == 0 ? "none" : text)}");
        if (!_loaded)
        {
            Log("they apply once a save of the world is loaded");
            return;
        }

        if (SharedSettings.IsShared(text))
        {
            _live = (before, text, name);
            Step("apply_live", SharedSettings.PlainValues(text));
            return;
        }

        if (SharedSettings.IsShared(before))
        {
            Step("unlock");
            Notify(SettingNotices.Format(SettingNotices.NoLongerText, name));
        }

        Row();
    }

    /// <summary>
    /// Takes the settings the relay told the creator's game: those of a request on its way are its
    /// answer, others someone else gave the world, which become the world's once nothing waits to
    /// be sent, and are read anew from the relay once the request on its way was answered.
    /// </summary>
    /// <param name="text">The settings.</param>
    private void CreatorTold(string text)
    {
        if (_sending is { } sending)
        {
            _checkWanted |= sending.Text != text;
            return;
        }

        _relayText = text;
        if (_wanted == null)
        {
            TakeRelay(text);
        }
    }

    /// <summary>
    /// Tells the player what the creator's live settings set for them, once the scripts applied them.
    /// </summary>
    /// <param name="applied">The options the scripts set.</param>
    private void Applied(List<string> applied)
    {
        if (_live is not { } live)
        {
            return;
        }

        var (before, after, name) = live;
        _live = null;
        List<string> keys = _notices.KnownKeys(applied);
        if (SharedSettings.IsShared(before) && StayRecent())
        {
            // Settings that arrive right after the load are only newer than the player's list, not a
            // change, so the notice of the stay names them anew.
            Notify(_notices.Stay(keys, name));
        }
        else if (SharedSettings.IsShared(before))
        {
            if (_notices.Changes(before, after) is { } changes)
            {
                Notify(SettingNotices.Format(SettingNotices.ChangedText, name, changes));
            }
        }
        else
        {
            _stayNoticed = true;
            Notify(keys.Count == 0 ? SettingNotices.Format(SettingNotices.NowSharedEmptyText, name) : SettingNotices.Format(SettingNotices.NowSharedText, name, _notices.OptionsText(keys)));
        }

        Row();
    }

    /// <summary>
    /// Takes the mods the relay tells the open world names now.
    /// </summary>
    /// <param name="mods">The mods as written.</param>
    private void TakeMods(string mods)
    {
        if (_world == null)
        {
            return;
        }

        if (_world.Mods != mods)
        {
            Log($"the world's mods are \"{mods}\" now");
        }

        _world = _world with { Mods = mods };
    }

    /// <summary>
    /// Answers <see cref="OfTopic"/>.
    /// </summary>
    /// <param name="request">The world, the list's settings and whether the list is fresh.</param>
    /// <returns>The settings.</returns>
    private RubyValue SettingsOf(RubyHash request) => SettingsOf(request["id"].AsText(), Text(request["settings"]), request["fresh"].AsBool());

    /// <summary>
    /// Reads a world's settings as they stand: the list's, or those the relay took from this game
    /// last when the list may be older than them.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="listed">The list's settings.</param>
    /// <param name="fresh">Whether the list was fetched since the world screen opened.</param>
    /// <returns>The settings.</returns>
    private string SettingsOf(string id, string listed, bool fresh)
    {
        if (fresh || !_confirmed.TryGetValue(id, out string? confirmed) || confirmed == listed)
        {
            return listed;
        }

        Log($"the list of world {Short(id)} may be older than the mod settings the relay took from this game last, which count");
        return confirmed;
    }

    /// <summary>
    /// Answers <see cref="DetailsTopic"/>.
    /// </summary>
    /// <param name="request">The world's settings, creator and the player's id.</param>
    /// <returns>The text.</returns>
    private RubyValue Details(RubyHash request) => DetailsText(Text(request["settings"]), Text(request["creator_id"]), Text(request["creator_name"]), Text(request["me"]));

    /// <summary>
    /// Writes the details' line of a world's shared mod settings.
    /// </summary>
    /// <param name="settings">The world's settings as listed.</param>
    /// <param name="creatorId">The creator's id.</param>
    /// <param name="creatorName">The creator's name.</param>
    /// <param name="me">The player's id.</param>
    /// <returns>The line.</returns>
    public string DetailsText(string settings, string creatorId, string creatorName, string me)
    {
        string who = creatorId == me ? "you" : PlayerIni.Cleaned(creatorName, "A friend");
        return _notices.Details(settings, who);
    }

    /// <summary>
    /// Tells the player once per stay in a world that shares its settings what that means for them.
    /// </summary>
    /// <param name="applied">The options the world set.</param>
    private void NoticeStay(List<string> applied)
    {
        if (_stayNoticed)
        {
            return;
        }

        _stayNoticed = true;
        _stayAt = _frame;
        World world = _world!;
        Notify(world.Own ? _notices.CreatorStay(LatestText(), _leftOut) : _notices.Stay(_notices.KnownKeys(applied), world.CreatorName));
    }

    /// <summary>
    /// Tells whether the notice of the stay may still show.
    /// </summary>
    /// <returns>Whether it was posted less than <see cref="NoticeFrames"/> ago.</returns>
    private bool StayRecent() => _stayAt != null && _frame - _stayAt < NoticeFrames;

    /// <summary>
    /// Has the scripts write settings into the options, or lift the locks for settings not shared,
    /// while a save of the world is loaded.
    /// </summary>
    /// <param name="text">The settings.</param>
    private void ApplyIfLoaded(string text)
    {
        if (_loaded)
        {
            if (SharedSettings.IsShared(text))
            {
                Step("apply", SharedSettings.PlainValues(text));
            }
            else
            {
                Step("unlock");
            }
        }
    }

    /// <summary>
    /// Has the scripts show in the row whether the world shares its settings, or will once the request on its way arrived.
    /// </summary>
    private void Row() => Step("row", SharedSettings.IsShared(LatestText()));

    /// <summary>
    /// Has the scripts show a message in the notification box, broken into lines that fit it.
    /// </summary>
    /// <param name="text">The message.</param>
    private void Notify(string text)
    {
        Log($"told the player: {text}");
        Step("notify", new RubyArray(SharedSettings.NoticeLines(text, NoticeLines, NoticeLineChars).Select(line => (RubyValue)line)));
    }

    /// <summary>
    /// Queues a step for the scripts.
    /// </summary>
    /// <param name="kind">What the scripts do.</param>
    /// <param name="values">Its values.</param>
    private void Step(string kind, params RubyValue[] values)
    {
        _steps.Add(new RubyArray([kind, .. values]));
        _changed();
    }

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => _log.Write($"world mods: {line}");

    /// <summary>
    /// Shortens a world's id for the log.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first eight characters.</returns>
    private static string Short(string id) => id.Length > 8 ? id[..8] : id;

    /// <summary>
    /// Reads option keys.
    /// </summary>
    /// <param name="value">An Array of keys, or nil.</param>
    /// <returns>The keys.</returns>
    private static List<string> Keys(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(key => key.AsText())];

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, empty for nil.</returns>
    private static string Text(RubyValue value) => value.IsNil ? "" : value.AsText();

    /// <summary>
    /// The world being entered or played in.
    /// </summary>
    /// <param name="Id">Its id.</param>
    /// <param name="Name">Its name.</param>
    /// <param name="CreatorId">Its creator's id.</param>
    /// <param name="CreatorName">Its creator's name, cleaned.</param>
    /// <param name="Mods">Its mods as written.</param>
    /// <param name="Own">Whether the player created it.</param>
    internal sealed record World(string Id, string Name, string CreatorId, string CreatorName, string Mods, bool Own)
    {
        /// <summary>
        /// Gets or sets its settings as they stand.
        /// </summary>
        public string Text { get; set; } = "";
    }

    /// <summary>
    /// Settings on their way to the relay.
    /// </summary>
    /// <param name="Id">The world.</param>
    /// <param name="Text">The settings.</param>
    /// <param name="Before">The world's settings before.</param>
    /// <param name="Reason">Why they were sent.</param>
    /// <param name="LeftOut">How many options did not fit.</param>
    /// <param name="Since">The frame they were sent at.</param>
    /// <param name="Ticket">The directory action's ticket.</param>
    private sealed record Sending(string Id, string Text, string Before, string Reason, int LeftOut, long Since, int Ticket);

    /// <summary>
    /// The game's own world directory as the shared settings need it.
    /// </summary>
    /// <param name="services">What the topics of worlds and mods share.</param>
    private sealed class DirectorySettings(WorldServices services) : ISettingsDirectory
    {
        /// <inheritdoc />
        public bool SetSettings(string id, string settings)
        {
            services.Player.Share();
            return services.Directory().SetSettings(id, settings);
        }

        /// <inheritdoc />
        public (string State, string? Kind, string? Error) ActionNow() => services.Directory().ActionNow();

        /// <inheritdoc />
        public void ClearAction() => services.Directory().ClearAction();

        /// <inheritdoc />
        public bool ReadSettings(string id)
        {
            services.Player.Share();
            return services.Directory().ReadSettings(id);
        }

        /// <inheritdoc />
        public (string State, string? Settings) SettingsRead(string id) => services.Directory().SettingsRead(id);
    }
}
