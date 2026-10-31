//----------------------------------------------------------------
//  SharedSettingsSyncTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered the settings the relay tells every player, the creator's game included
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the shared mod settings as the scripts call them: the creator's options sent after the
/// relay's were read, merged with a change on the relay, the settings the relay tells, and the notices.
/// </summary>
public sealed class SharedSettingsSyncTests
{
    /// <summary>
    /// The settings a world of Level Cap shares with its option on.
    /// </summary>
    private const string On = "@shared=o:1;mod_level_cap=i:1";

    /// <summary>
    /// The same with the option off.
    /// </summary>
    private const string Off = "@shared=o:1;mod_level_cap=i:0";

    /// <summary>
    /// The directory the settings go through.
    /// </summary>
    private readonly FakeDirectory _directory = new();

    /// <summary>
    /// The shared settings under test.
    /// </summary>
    private readonly SharedSettingsSync _sync;

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// The frame of the next tick.
    /// </summary>
    private long _frame = 1;

    /// <summary>
    /// Creates the shared settings over a directory whose action and readings the tests end.
    /// </summary>
    public SharedSettingsSyncTests()
    {
        _sync = new SharedSettingsSync(_directory, new DirectoryTickets(() => _directory.Action.State, () => _directory.Action = ("idle", null, null)), new TopicCaller.NoLog(), () => { });
        _topics = new TopicCaller(_sync.Register);
        Call(SharedSettingsSync.GroupsTopic, new RubyArray([new RubyArray(["Level Cap", new RubyArray([new RubyArray(["mod_level_cap", "Level Cap", new RubyArray([new RubyArray(["i:1", "On"]), new RubyArray(["i:0", "Off"])])])])])]));
    }

    /// <summary>
    /// Asserts that the creator's load reads the relay's settings before it sends, sends nothing while
    /// they are as wanted, and once the relay took changed options tells the creator, leaving the
    /// other players to the relay.
    /// </summary>
    [Fact]
    public void Load_ReadsTheRelayFirstThenSendsTheCreatorsOptions()
    {
        Enter("creator", On);
        RubyArray steps = Steps(Call(SharedSettingsSync.LoadedTopic, Load(Off)));

        Assert.Equal("w1", _directory.Read);
        Assert.Null(_directory.Sent);
        Assert.Contains(steps, step => Kind(step) == "notify");

        _directory.Done(On);
        Tick();
        Assert.Equal(Off, _directory.Sent);

        _directory.Action = ("done", "settings", null);
        steps = Tick();
        Assert.Equal(["row"], steps.Select(Kind).Where(kind => kind != "notify"));
        Assert.Equal(Off, Call(SharedSettingsSync.StepTopic)!.AsHash()["world"].AsHash()["text"].AsText());
    }

    /// <summary>
    /// Asserts that an option the creator changes joins what someone else changed on the relay, which
    /// their game takes and applies too.
    /// </summary>
    [Fact]
    public void Options_JoinWhatChangedOnTheRelay()
    {
        Enter("creator", "@shared=o:1;mod_level_cap=i:1;mod_rate=i:1");
        Call(SharedSettingsSync.LoadedTopic, Load("@shared=o:1;mod_level_cap=i:1;mod_rate=i:1", ("mod_level_cap", "mod_level_cap=i:1"), ("mod_rate", "mod_rate=i:1")));
        _directory.Done("@shared=o:1;mod_level_cap=i:1;mod_rate=i:1");
        Tick();
        _directory.Read = null;

        RubyHash want = Load("", ("mod_level_cap", "mod_level_cap=i:0"), ("mod_rate", "mod_rate=i:1"));
        want.Add("reason", "options");
        Call(SharedSettingsSync.WantTopic, want);
        _directory.Done("@shared=o:1;mod_level_cap=i:1;mod_rate=i:5");
        RubyArray steps = Tick();

        Assert.Equal("@shared=o:1;mod_rate=i:5;mod_level_cap=i:0", _directory.Sent);
        Assert.Contains(steps, step => Kind(step) == "apply" && step.AsArray()[1].AsText() == "@shared=o:1;mod_rate=i:5;mod_level_cap=i:0");
    }

    /// <summary>
    /// Asserts that settings that cannot be sent tell the creator once and go out after the retry
    /// frames, and that an answer the relay never gives is named after the send frames.
    /// </summary>
    [Fact]
    public void Sending_RetriesAndGivesUp()
    {
        Enter("creator", On);
        Call(SharedSettingsSync.LoadedTopic, Load(Off));
        _directory.Refuse = true;
        _directory.Done(On);
        RubyArray steps = Tick();
        Assert.Contains(steps, step => Notice(step).StartsWith("The world's mod settings could not be sent yet."));
        Assert.DoesNotContain(Tick(), step => Kind(step) == "notify");

        _directory.Refuse = false;
        _frame += SharedSettingsSync.RetryFrames;
        Tick();
        Assert.Equal(Off, _directory.Sent);

        _frame += SharedSettingsSync.SendFrames + 1;
        Assert.Contains(Tick(), step => Notice(step) == "The world's mod settings could not be saved. Try again later.");
    }

    /// <summary>
    /// Asserts that another player takes the settings the relay tells once applied and is told what
    /// changed and who changed it, the creator or an admin, and that settings the game holds already
    /// change nothing.
    /// </summary>
    [Fact]
    public void Live_AppliesTheSettingsTheRelayTells()
    {
        Enter("me", On);
        Call(SharedSettingsSync.LoadedTopic, Load(""));
        Tick();

        Assert.Empty(Steps(Call(SharedSettingsSync.LiveTopic, Told("", On))));
        Assert.Equal(new RubyArray(["apply_live", Off]), Assert.Single(Steps(Call(SharedSettingsSync.LiveTopic, Told("creator", Off)))));

        _frame += SharedSettingsSync.NoticeFrames;
        Tick();
        RubyArray steps = Steps(Call(SharedSettingsSync.AppliedTopic, new RubyHash { { "keys", new RubyArray(["mod_level_cap"]) } }));
        Assert.Contains(steps, step => Notice(step) == "Creator changed the shared mod settings: Level Cap: On -> Off.");

        Call(SharedSettingsSync.LiveTopic, Told("admin", On));
        steps = Steps(Call(SharedSettingsSync.AppliedTopic, new RubyHash { { "keys", new RubyArray(["mod_level_cap"]) } }));
        Assert.Contains(steps, step => Notice(step) == "An admin changed the shared mod settings: Level Cap: Off -> On.");
    }

    /// <summary>
    /// Asserts that the creator's game takes an admin's change the relay tells as the world's, and
    /// takes the relay telling its own request on its way as nothing new.
    /// </summary>
    [Fact]
    public void Live_TheCreatorTakesAnAdminsChangeButNotItsOwnRequest()
    {
        Enter("creator", On);
        Call(SharedSettingsSync.LoadedTopic, Load(On, ("mod_level_cap", "mod_level_cap=i:1")));
        _directory.Done(On);
        Tick();

        RubyArray steps = Steps(Call(SharedSettingsSync.LiveTopic, Told("admin", Off)));
        Assert.Contains(steps, step => Kind(step) == "apply" && step.AsArray()[1].AsText() == Off);
        Assert.Contains(steps, step => Notice(step) == "An admin changed the shared mod settings: Level Cap: On -> Off.");

        RubyHash want = Load("", ("mod_level_cap", "mod_level_cap=i:1"));
        want.Add("reason", "options");
        Call(SharedSettingsSync.WantTopic, want);
        _directory.Done(Off);
        Tick();
        Assert.Equal(On, _directory.Sent);

        _directory.Read = null;
        Assert.Empty(Steps(Call(SharedSettingsSync.LiveTopic, Told("creator", On))));
        _directory.Action = ("done", "settings", null);
        Tick();
        Tick();
        Assert.Null(_directory.Read);
    }

    /// <summary>
    /// Asserts that a list from before the world screen opened gives way to the settings the relay
    /// took from this game last, and a fresh one counts.
    /// </summary>
    [Fact]
    public void Of_KeepsTheSettingsTheRelayTookOverAnOlderList()
    {
        Call(SharedSettingsSync.ConfirmedTopic, new RubyHash { { "id", "w1" }, { "text", Off } });

        Assert.Equal(Off, Call(SharedSettingsSync.OfTopic, new RubyHash { { "id", "w1" }, { "settings", On }, { "fresh", false } })!.AsText());
        Assert.Equal(On, Call(SharedSettingsSync.OfTopic, new RubyHash { { "id", "w1" }, { "settings", On }, { "fresh", true } })!.AsText());
    }

    /// <summary>
    /// Enters world w1 of the creator "creator".
    /// </summary>
    /// <param name="me">The player's id.</param>
    /// <param name="settings">The list's settings.</param>
    private void Enter(string me, string settings) => Call(SharedSettingsSync.EnterTopic, new RubyHash
    {
        { "world", new RubyHash { { "id", "w1" }, { "name", "Modded" }, { "creator_id", "creator" }, { "creator_name", "Creator" }, { "mods", "!Level Cap" }, { "settings", settings } } },
        { "me", me },
        { "fresh", true },
    });

    /// <summary>
    /// Writes a load's request: the creator's options and every option key the game has.
    /// </summary>
    /// <param name="applied">The settings whose keys were applied.</param>
    /// <param name="pairs">The creator's options, Level Cap off when none are given.</param>
    /// <returns>The request.</returns>
    private static RubyHash Load(string applied, params (string Key, string Pair)[] pairs)
    {
        (string Key, string Pair)[] mine = pairs.Length > 0 ? pairs : [("mod_level_cap", "mod_level_cap=i:0")];
        return new RubyHash
        {
            { "applied", new RubyArray(applied.Length == 0 ? [] : ["mod_level_cap"]) },
            { "pairs", new RubyArray(mine.Select(pair => (RubyValue)new RubyArray([pair.Key, pair.Pair]))) },
            { "known", new RubyArray(mine.Select(pair => (RubyValue)pair.Key)) },
        };
    }

    /// <summary>
    /// Writes what the relay tells of the world's settings.
    /// </summary>
    /// <param name="by">Who changed them, empty as the game enters.</param>
    /// <param name="settings">The settings.</param>
    /// <returns>The request.</returns>
    private static RubyHash Told(string by, string settings) => new() { { "by", by }, { "text", settings } };

    /// <summary>
    /// Runs a tick and takes its steps.
    /// </summary>
    /// <returns>The steps.</returns>
    private RubyArray Tick()
    {
        _sync.Tick(_frame++);
        return Steps(Call(SharedSettingsSync.StepTopic));
    }

    /// <summary>
    /// Calls a topic.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The reply.</returns>
    private RubyValue? Call(string topic, RubyValue? request = null) => _topics.Call(topic, request);

    /// <summary>
    /// Takes the steps of a reply.
    /// </summary>
    /// <param name="reply">The reply.</param>
    /// <returns>The steps.</returns>
    private static RubyArray Steps(RubyValue? reply) => reply!.AsHash()["steps"].AsArray();

    /// <summary>
    /// Names a step's kind.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <returns>Its kind.</returns>
    private static string Kind(RubyValue step) => step.AsArray()[0].AsText();

    /// <summary>
    /// Joins a notify step's lines.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <returns>The notice, empty for another step.</returns>
    private static string Notice(RubyValue step) => Kind(step) == "notify" ? string.Join(" ", step.AsArray()[1].AsArray().Select(line => line.AsText())) : "";

    /// <summary>
    /// A directory whose action and readings the tests end.
    /// </summary>
    private sealed class FakeDirectory : ISettingsDirectory
    {
        /// <summary>
        /// Gets or sets the action as it stands.
        /// </summary>
        public (string State, string? Kind, string? Error) Action { get; set; } = ("idle", null, null);

        /// <summary>
        /// Gets the settings sent last.
        /// </summary>
        public string? Sent { get; private set; }

        /// <summary>
        /// Gets or sets the world read last, <see langword="null"/> once a test forgot it.
        /// </summary>
        public string? Read { get; set; }

        /// <summary>
        /// Gets or sets whether sending is refused.
        /// </summary>
        public bool Refuse { get; set; }

        /// <summary>
        /// The reading's state and settings.
        /// </summary>
        private (string State, string? Settings) _reading = ("failed", null);

        /// <summary>
        /// Ends the reading with the relay's settings.
        /// </summary>
        /// <param name="settings">The settings.</param>
        public void Done(string settings) => _reading = ("done", settings);

        /// <inheritdoc />
        public bool SetSettings(string id, string settings)
        {
            if (Refuse || Action.State == "busy")
            {
                return false;
            }

            Sent = settings;
            Action = ("busy", "settings", null);
            return true;
        }

        /// <inheritdoc />
        public (string State, string? Kind, string? Error) ActionNow() => Action;

        /// <inheritdoc />
        public void ClearAction() => Action = ("idle", null, null);

        /// <inheritdoc />
        public bool ReadSettings(string id)
        {
            Read = id;
            _reading = ("busy", null);
            return true;
        }

        /// <inheritdoc />
        public (string State, string? Settings) SettingsRead(string id) => _reading;
    }
}
