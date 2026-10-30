//----------------------------------------------------------------
//  WorldEnteringTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Checked the game data once the world's mods loaded, warned of or taken as the creator's, in place of the question and the refusal on entering
//                            - Checked that a world that turns other mods off waits for the catalog, without the parking
//                            - Checked the install of a world's mods through the scripts, without a restart
//                            - Checked that a restart for a mod that runs waits for the world's lock
//                            - Checked that a data scan of another format waits for its creator
//      Paulinchen  2026-10-28: Checked that the steps wait for a list not fetched yet
//      Paulinchen  2026-10-23: Covered the world screen's requests
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Forms;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the world screen's steps into a world as the scripts call them, over a directory and a
/// mods check that stand in for theirs.
/// </summary>
public sealed class WorldEnteringTests : IDisposable
{
    /// <summary>
    /// A world code whose folder the worlds on this PC make.
    /// </summary>
    private const string Code = "mgqmp2;abcdefghjkmnpqrs;r1;8";

    /// <summary>
    /// The player's id.
    /// </summary>
    private const string Me = "me";

    /// <summary>
    /// This game's data fingerprint.
    /// </summary>
    private const string Data = "1:00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000";

    /// <summary>
    /// A creator's data fingerprint that differs from this game's in its maps.
    /// </summary>
    private const string OtherData = "1:00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.11111111";

    /// <summary>
    /// A creator's data fingerprint that another version of the mod made.
    /// </summary>
    private const string OtherFormatData = "0:00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000.00000000";

    /// <summary>
    /// The mod folder under test.
    /// </summary>
    private readonly TempFolder _mod = new();

    /// <summary>
    /// The directory the steps reach.
    /// </summary>
    private readonly FakeDirectory _directory = new();

    /// <summary>
    /// The answers of the other areas' topics the steps ask, by topic.
    /// </summary>
    private readonly Dictionary<string, Func<RubyValue, RubyValue?>> _areas = new(StringComparer.Ordinal);

    /// <summary>
    /// The requests the steps asked the other areas' topics, as [topic, request].
    /// </summary>
    private readonly List<(string Topic, RubyValue Request)> _asked = [];

    /// <summary>
    /// The worlds on this PC.
    /// </summary>
    private readonly LocalWorlds _worlds;

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// The world screen's open forms by slot.
    /// </summary>
    private readonly Dictionary<string, Form> _forms = new(StringComparer.Ordinal);

    /// <summary>
    /// The player's lists of worlds.
    /// </summary>
    private readonly WorldLists _lists;

    /// <summary>
    /// The texts put on the clipboard.
    /// </summary>
    private readonly List<string> _copied = [];

    /// <summary>
    /// Creates the steps over empty folders and areas that let everything in.
    /// </summary>
    public WorldEnteringTests()
    {
        _worlds = new LocalWorlds(Path.Combine(_mod.Path, "Worlds"), "Worlds", () => 1_000);
        PlayerIni player = new(Path.Combine(_mod.Path, PlayerIni.FileName));
        WorldLists lists = new(player, _mod.Path, () => 0);
        _lists = lists;
        Area("mods.check", _ => new RubyHash { { "known", true }, { "rows", new RubyArray() }, { "summary", RubyNil.Value } });
        Area("mods.forget", _ => null);
        Area("worlds.invite_take", _ => null);
        Area("mods.creator_hashes", _ => "Mod=abc");
        Area("settings.of", request => request.AsHash()["settings"]);
        Area("settings.confirmed", _ => null);
        _topics = new TopicCaller(context =>
        {
            foreach (string topic in _areas.Keys)
            {
                context.Register(topic, (_, request) =>
                {
                    _asked.Add((topic, request));
                    return _areas[topic](request);
                });
            }

            WorldEntering entering = new(context, _directory, _worlds, lists, () => true, new DirectoryTickets(() => "idle", () => { }), new WorldChanges(context));
            entering.UseRequests(slot => _forms.GetValueOrDefault(slot), text =>
            {
                _copied.Add(text);
                return true;
            });
            entering.Register();
        });
        _topics.Call(WorldEntering.DoTopic, new RubyHash { { "do", "open" }, { "me", Me }, { "rejoin", RubyNil.Value } });
    }

    /// <summary>
    /// Asserts that a world without a password is opened at once, and entered from the folder its lock
    /// made once the action ended.
    /// </summary>
    [Fact]
    public void Enter_OpensAWorldWithoutAPasswordAndStartsIt()
    {
        _directory.List(World("w1", open: true));

        Assert.Equal(["busy unlock"], Enter("w1"));
        Assert.Equal("unlock w1 ", _directory.Calls.Last());
        Assert.Empty(Step());

        _directory.Finish(Code, "none");
        string[] steps = Step();
        Assert.Equal(["idle", "leave_form", "start fresh"], steps);
        Assert.Single(_worlds.All());
    }

    /// <summary>
    /// Asserts that a world with a password asks for it, and that the password opens its lock.
    /// </summary>
    [Fact]
    public void Enter_AsksAPasswordThenOpensTheLockWithIt()
    {
        _directory.List(World("w1"));

        Assert.Equal(["password Plain"], Enter("w1"));
        Assert.Equal(["busy unlock"], Answer("password", new RubyHash { { "text", "secret" } }));
        Assert.Equal("unlock w1 secret", _directory.Calls.Last());
    }

    /// <summary>
    /// Asserts that a Discord invite's code opens the world instead of its password, and that a code
    /// that failed once is dropped, so the password is asked next.
    /// </summary>
    [Fact]
    public void Invite_OpensTheWorldOnceTheListHoldsItAndIsDroppedWhenItFails()
    {
        Area("worlds.invite_take", _ => new RubyArray(["w1", Code]));
        RubyHash opened = _topics.Call(WorldEntering.DoTopic, new RubyHash { { "do", "open" }, { "me", Me }, { "rejoin", RubyNil.Value } })!.AsHash();
        Assert.True(opened["waiting"].AsBool());

        Assert.Empty(Look("ready"));
        Assert.Equal("refresh", _directory.Calls.Last());

        _directory.List(World("w1"));
        Assert.Equal(["entry w1", "busy unlock"], Look("ready", ["w1", null, "Plain", false]));
        Assert.Equal($"unlock code {Code}", _directory.Calls.Last());

        _directory.Fail("Expired.");
        Assert.Equal(["idle", "buzz", "say Expired.", "back"], Step());
        Assert.Equal(["password Plain"], Enter("w1"));
    }

    /// <summary>
    /// Asserts that a full world keeps out players with saves of it too, and a world still being set
    /// up everyone.
    /// </summary>
    [Fact]
    public void Enter_RefusesAFullWorldAndOneStillBeingSetUp()
    {
        LocalWorld folder = Folder();
        _directory.List(World("w1", online: 4, seats: 4));
        Assert.Equal(["buzz", "say Plain is full right now.", "back"], Enter("w1", folder.Id));

        _directory.List(World("w1", start: "pending"));
        Assert.Equal(["buzz", "say Plain is still being set up by its creator. Try again in a moment.", "back"], Enter("w1"));
    }

    /// <summary>
    /// Asserts that a game whose data differs enters as any other, the world's type and its creator's
    /// old wish to keep such games out alike, since the data is compared only once its mods loaded.
    /// </summary>
    [Fact]
    public void Enter_LetsAGameWhoseDataDiffersIn()
    {
        _directory.List(World("w1", open: true, data: OtherData, strict: true));

        Assert.Equal(["busy unlock"], Enter("w1"));
    }

    /// <summary>
    /// Asserts that the check once the world's mods loaded warns a game whose data differs, in plain
    /// words, and says nothing to one that matches or cannot be compared.
    /// </summary>
    [Fact]
    public void DataCheck_WarnsAGameWhoseDataDiffersAndNothingElse()
    {
        _directory.List(World("w1", data: OtherData, strict: true));
        Assert.Equal("Your game differs from the creator's of Plain. Some things may not work as in their game.", DataCheck("w1", Data)!.AsText());

        _directory.List(World("w1", data: Data));
        Assert.Null(DataCheck("w1", Data));
        _directory.List(World("w1", data: OtherFormatData));
        Assert.Null(DataCheck("w1", Data));
        _directory.List(World("w1", data: ""));
        Assert.Null(DataCheck("w1", Data));
        Assert.Null(DataCheck("w2", Data));
        Assert.DoesNotContain(_directory.Calls, call => call.StartsWith("data", StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts that the creator's game makes its data, measured once the world's mods loaded, the
    /// world's data scan while it differs, and is never warned.
    /// </summary>
    [Fact]
    public void DataCheck_MakesTheCreatorsDataTheWorldsScan()
    {
        _directory.List(World("w1", creator: Me, data: ""));

        Assert.Null(DataCheck("w1", OtherData));
        Assert.Equal($"data w1 {OtherData}", _directory.Calls.Last());

        _directory.Clear();
        _directory.Calls.Clear();
        _directory.List(World("w1", creator: Me, data: OtherData));
        Assert.Null(DataCheck("w1", OtherData));
        Assert.Empty(_directory.Calls);
    }

    /// <summary>
    /// Asserts that required mods the catalog has are offered for download, handed to the scripts to
    /// install on yes, and that entering goes on once they are installed, with what Patch held forgotten.
    /// </summary>
    [Fact]
    public void Enter_OffersTheDownloadAndGoesOnOnceTheScriptsInstalledTheMods()
    {
        bool installed = false;
        Area("mods.check", _ => new RubyHash
        {
            { "known", true },
            { "rows", installed ? new RubyArray() : new RubyArray([new RubyHash { { "name", "Level Cap" }, { "key", "levelcap" }, { "yours", "1.3.5" }, { "downloadable", true } }]) },
            { "summary", "Plain needs Level Cap. Download them?" },
        });
        _directory.List(World("w1", open: true, mods: "!Level Cap"));

        Assert.Equal(["say Plain needs Level Cap. Download them?", "confirm mods yes,show_mods,cancel"], Enter("w1"));
        RubyValue? install = _topics.Call(WorldEntering.AnswerTopic, new RubyHash { { "answer", "yes" } });
        Assert.Equal(new RubyArray([new RubyArray(["install", new RubyArray([new RubyArray(["Level Cap", "levelcap"])])])]), install!.AsHash()["steps"]);

        installed = true;
        Assert.Equal(["forget_installed", "busy unlock"], Answer("installed", new RubyHash { { "ok", true }, { "text", RubyNil.Value }, { "restart", false } }));
        Assert.Contains(_asked, asked => asked.Topic == "mods.forget");
    }

    /// <summary>
    /// Asserts that a mod installed that runs already starts the game again for the world, only once
    /// its lock is open and its folder keeps the world code, so the password is not asked again after
    /// the restart, and that an install that failed keeps the game out with its reason.
    /// </summary>
    [Fact]
    public void Enter_RestartsForAModThatRunsOnceTheLockIsOpenAndRefusesAFailedInstall()
    {
        bool installed = false;
        Area("mods.check", _ => new RubyHash
        {
            { "known", true },
            { "rows", installed ? new RubyArray() : new RubyArray([new RubyHash { { "name", "Level Cap" }, { "key", "levelcap" }, { "yours", "1.3.5" }, { "downloadable", true } }]) },
            { "summary", "Plain needs Level Cap. Download them?" },
        });
        _directory.List(World("w1", mods: "!Level Cap"));

        Enter("w1");
        Answer("yes");
        installed = true;
        Assert.Equal(["forget_installed", "password Plain"], Answer("installed", new RubyHash { { "ok", true }, { "restart", true } }));
        Assert.Equal(["busy unlock"], Answer("password", new RubyHash { { "text", "secret" } }));
        _directory.Finish(Code, "none");
        Assert.Equal(["idle", "leave_form", "restart"], Step());
        Assert.Single(_worlds.All());

        Assert.Equal(["restart"], Enter("w1", _worlds.All()[0].Id));

        installed = false;
        Enter("w1");
        Answer("yes");
        Assert.Equal(["buzz", "say Level Cap could not be installed.", "back"], Answer("installed", new RubyHash { { "ok", false }, { "text", "Level Cap could not be installed." } }));
    }

    /// <summary>
    /// Asserts that a required mod nobody can download keeps the game out, naming it.
    /// </summary>
    [Fact]
    public void Enter_KeepsOutAGameThatLacksARequiredModNoneCanDownload()
    {
        Area("mods.check", _ => new RubyHash
        {
            { "known", true },
            { "rows", new RubyArray([new RubyHash { { "name", "Mod C" }, { "yours", "not installed" }, { "downloadable", false } }]) },
            { "summary", "needs" },
        });
        _directory.List(World("w1", mods: "!Mod C"));

        Assert.Equal(["buzz", "say Plain needs mods you do not have: Mod C.", "back"], Enter("w1"));
    }

    /// <summary>
    /// Asserts that a world that turns other mods off keeps the game out while the catalog, which
    /// tells the personal mods its session keeps, is unknown, and lets it in once it is known.
    /// </summary>
    [Fact]
    public void Enter_WaitsForTheCatalogOfAWorldThatTurnsOtherModsOff()
    {
        bool known = false;
        Area("mods.check", _ => new RubyHash { { "known", known }, { "rows", new RubyArray() }, { "summary", RubyNil.Value } });
        _directory.List(World("w1", open: true, off: true));

        Assert.Equal(["buzz", "say The mod list has not loaded yet. Try again in a moment.", "back"], Enter("w1"));
        known = true;
        Assert.Equal(["busy unlock"], Enter("w1"));
    }

    /// <summary>
    /// Asserts that a world listed without its mods has them read first, and that entering goes on once
    /// the list carries them.
    /// </summary>
    [Fact]
    public void Enter_ReadsTheModsOfAWorldTheListLeftOutFirst()
    {
        _directory.List(World("w1", open: true) with { ModsUnread = true });

        Assert.Equal(["busy read"], Enter("w1"));
        _directory.List(World("w1", open: true));
        _directory.Finish(null, null);

        Assert.Equal(["idle", "read", "busy unlock"], Step());
    }

    /// <summary>
    /// Asserts that the world the game started again for is entered once the list holds it, not while
    /// the list is not fetched yet.
    /// </summary>
    [Fact]
    public void Rejoin_EntersOnceListed()
    {
        _topics.Call(WorldEntering.DoTopic, new RubyHash { { "do", "open" }, { "me", Me }, { "rejoin", "w1" } });
        Assert.Empty(Look("idle", ["w1", null, "Plain", false]));
        Assert.Empty(Look("loading", ["w1", null, "Plain", false]));

        _directory.List(World("w1"));
        Assert.Equal(["entry w1", "password Plain"], Look("ready", ["w1", null, "Plain", false]));
        Assert.Empty(Answer("password_back"));
    }

    /// <summary>
    /// Asserts that the world the game started again for after its lock was opened is entered from
    /// its folder, without the password.
    /// </summary>
    [Fact]
    public void Rejoin_EntersFromTheFolderTheLockMadeWithoutThePassword()
    {
        LocalWorld folder = Folder();
        _topics.Call(WorldEntering.DoTopic, new RubyHash { { "do", "open" }, { "me", Me }, { "rejoin", "w1" } });
        _directory.List(World("w1"));

        Assert.Equal(["entry w1", "start fresh"], Look("ready", ["w1", folder.Id, "Plain", false]));
    }

    /// <summary>
    /// Asserts that a rejoin whose world the list lacks says so.
    /// </summary>
    [Fact]
    public void Rejoin_SaysWhenTheListLacksTheWorld()
    {
        _topics.Call(WorldEntering.DoTopic, new RubyHash { { "do", "open" }, { "me", Me }, { "rejoin", "w1" } });

        Assert.Equal(["say The world you restarted for is not in the list right now."], Look("ready"));
    }

    /// <summary>
    /// Asserts that a new player of a world whose players choose is asked, that a save of their own
    /// goes over to be copied, and that a copy that failed is thrown away.
    /// </summary>
    [Fact]
    public void Start_AsksWhereThenCopiesTheOwnSaveAndThrowsAwayAFailedCopy()
    {
        LocalWorld folder = Folder();
        _directory.List(World("w1", choose: true));

        Assert.Equal(["say Where do you start in Plain? A save cannot be undone.", "choices from_beginning,from_own,cancel"], Enter("w1", folder.Id));
        Assert.Equal(["save_screen"], Answer("from_own"));
        Assert.Equal(["say Where do you start in Plain? A save cannot be undone.", "choices from_beginning,from_own,cancel"], Answer("own_save", new RubyHash { { "index", RubyNil.Value } }));
        Assert.Equal(["copy_own 2"], Answer("own_save", new RubyHash { { "index", 2 } }));
        Assert.Equal(["discard", "buzz", "say Your save could not be copied into Plain.", "back"], Answer("own_copied", new RubyHash { { "ok", false } }));
        Assert.Equal(["start placed"], Answer("own_copied", new RubyHash { { "ok", true } }));
    }

    /// <summary>
    /// Asserts that a creator's starting save is taken only after the warning, and fetched into the
    /// world's folder.
    /// </summary>
    [Fact]
    public void Start_WarnsBeforeTheCreatorsSaveAndFetchesItOnTake()
    {
        LocalWorld folder = Folder();
        _directory.List(World("w1", start: "ready"));

        Assert.Equal(["say This world starts from its creator's save. A save can run code on your PC; take it only from creators you trust.", "choices take_start,from_beginning,cancel"], Enter("w1", folder.Id));
        Assert.Equal(["busy start"], Answer("take_start"));
        Assert.Equal($"fetch {_worlds.Find(folder.Id)!.Code} Patch/Multiplayer/Worlds/{folder.Id}/Save", _directory.Calls.Last());
        _directory.Finish(null, null);
        Assert.Equal(["idle", "start placed"], Step());
        Assert.Equal(["discard", "buzz", "say It broke.", "back"], Answer("start_failed", new RubyHash { { "text", "It broke." }, { "placed", true } }));
    }

    /// <summary>
    /// Asserts that a new world is made from the form, kept as a favourite and pointed at, and that
    /// its starting save is copied in by the scripts first when it has one.
    /// </summary>
    [Fact]
    public void Create_MakesTheWorldFromTheFormAndCopiesItsStartingSaveFirst()
    {
        Form form = _forms["new_world"] = WorldForms.OpenCreate(FormTopics.Rules);
        form.Set("name", "Haven");
        form.Set("seats", "6");
        form.Set("mods", "!Mod");

        Assert.Equal(["busy create"], Do("create"));
        Assert.Equal("create Haven 6 classic/off d= s= b=False c=False Mod=abc loose data=[] []", _directory.Calls.Last());
        _directory.Finish(Code, "none");
        Assert.Equal(["idle", "fresh_form", "close_form", "select", "say Haven was created. Confirm to enter it.", "back"], Step());
        Assert.Equal(["w1"], _lists.Favourites());

        _forms["new_world"] = WorldForms.OpenCreate(FormTopics.Rules);
        _forms["new_world"].Set("name", "Second");
        _forms["new_world"].Set("seats", "4");
        Do("create", new RubyHash { { "start", new RubyArray([new RubyArray(["Save01.rvdata2", "Save/Save01.rvdata2"])]) } });
        _directory.Finish(Code, "pending");
        Assert.Equal(["idle", "place_start"], Step());
        Assert.Equal(["fresh_form", "close_form", "select", "say Second was created. Confirm to enter it.", "back"], Answer("placed", new RubyHash { { "ok", true } }));

        _forms["new_world"] = WorldForms.OpenCreate(FormTopics.Rules);
        _forms["new_world"].Set("name", "Raid");
        _forms["new_world"].Set("seats", "4");
        _forms["new_world"].Set("type", 1);
        _forms["new_world"].Set("choose", true);
        _forms["new_world"].Set("raid_bosses", true);
        _forms["new_world"].Set("shared", true);
        Do("create");
        Assert.Equal("create Raid 4 raid/off d=0 s=0 4 1 1 b= c=False Mod=abc loose data=[] [@shared=o:1]", _directory.Calls.Last());
    }

    /// <summary>
    /// Asserts that an edit sends only what the form changed, then the mod settings its creator shares,
    /// and tells what changed.
    /// </summary>
    [Fact]
    public void Edit_SendsWhatChangedThenTheSharedSettings()
    {
        _directory.List(World("w1", off: false, creator: Me));
        Form form = _forms["edit_world"] = EditForm();
        form.Set("seats", "8");
        form.Tick("other_mods_off");
        form.Tick("shared");

        Assert.Equal(["busy edit"], Do("edit", new RubyHash { { "id", "w1" }, { "name", "Plain" }, { "me", Me }, { "fresh", true } }));
        Assert.Equal("edit w1 8 hashes off=True", _directory.Calls.Last());
        _directory.Finish(null, null);
        Assert.Equal(["idle", "busy settings"], Step());
        _directory.Finish(null, null);
        Assert.Equal(["idle", "close_form", "say Plain was changed. Players in it with other mods enter again without them. Its players get your mod options once you play in it.", "back"], Step());
        Assert.Equal("w1", Requested("settings.confirmed")["id"].AsText());
    }

    /// <summary>
    /// Asserts that a hidden world found by its id joins the list and that a failed removal says why.
    /// </summary>
    [Fact]
    public void FindAndBan_AddTheWorldAndSayWhyARemovalFailed()
    {
        _forms["join_hidden"] = WorldForms.OpenJoin();
        _forms["join_hidden"].Set("id", "0123456789abcdef0123456789abcdef");

        Assert.Equal(["busy find"], Do("find"));
        _directory.Finish(Code, "none");
        Assert.Equal(["idle", "fresh_form", "close_form", "select", "say Plain was added to your list. Confirm to enter it.", "back"], Step());
        Assert.Equal(["0123456789abcdef0123456789abcdef"], _lists.Added());

        Do("ban", new RubyHash { { "id", "w1" }, { "name", "Plain" }, { "me", Me }, { "target", "p2" }, { "target_name", "Rose" } });
        Assert.Equal("ban w1 p2", _directory.Calls.Last());
        _directory.Fail("Only its creator may.");
        Assert.Equal(["idle", "buzz", "say Only its creator may.", "back"], Step());
    }

    /// <summary>
    /// Asserts that the small flows of a world do their part in the DLL and tell it, the list then
    /// asked again where it changes.
    /// </summary>
    [Fact]
    public void SmallFlows_TellWhatTheyDid()
    {
        RubyHash entry = new() { { "id", "w1" }, { "folder", RubyNil.Value }, { "name", "Plain" }, { "me", Me } };
        _directory.List(World("w1", open: true));

        Assert.Equal(["say Plain is a favourite now.", "back"], Do("favourite", entry));
        Assert.Equal(["say Plain is no longer a favourite.", "back"], Do("favourite", entry));
        Assert.Equal(["say Copied the id of Plain. Share it.", "back"], Do("copy_id", entry));
        Assert.Equal(["w1"], _copied);
        Assert.Equal(["say Plain was removed from your list.", "back"], Do("forget", entry));
        Assert.Equal("refresh", _directory.Calls.Last());

        LocalWorld folder = Folder();
        RubyHash saves = new() { { "id", "w1" }, { "folder", folder.Id }, { "name", "Plain" }, { "me", Me } };
        Assert.Equal(["say Your saves of Plain were deleted.", "back"], Do("delete_saves", saves));
        Assert.Empty(_worlds.All());
    }

    /// <inheritdoc />
    public void Dispose() => _mod.Dispose();

    /// <summary>
    /// Sets what another area's topic answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="answer">Its answer to a request.</param>
    private void Area(string topic, Func<RubyValue, RubyValue?> answer) => _areas[topic] = answer;

    /// <summary>
    /// Finds the last request the steps asked a topic of another area.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <returns>The request.</returns>
    private RubyHash Requested(string topic) => _asked.Last(asked => asked.Topic == topic).Request.AsHash();

    /// <summary>
    /// Makes this PC's folder of the world the tests enter.
    /// </summary>
    /// <returns>The folder's world.</returns>
    private LocalWorld Folder() => _worlds.Found(Code, new LocalWorldAbout("Plain", "w1", null, null, null, null, null, null))!;

    /// <summary>
    /// Enters a world.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <param name="folder">This PC's folder of it, <see langword="null"/> for none.</param>
    /// <returns>The steps.</returns>
    private string[] Enter(string id, string? folder = null) =>
        Steps(_topics.Call(WorldEntering.EnterTopic, new RubyHash { { "id", id }, { "folder", folder }, { "name", "Plain" }, { "gone", false }, { "me", Me } }));

    /// <summary>
    /// Answers the steps.
    /// </summary>
    /// <param name="answer">The answer.</param>
    /// <param name="request">What it needs.</param>
    /// <returns>The steps.</returns>
    private string[] Answer(string answer, RubyHash? request = null)
    {
        RubyHash sent = request ?? [];
        sent["answer"] = answer;
        return Steps(_topics.Call(WorldEntering.AnswerTopic, sent));
    }

    /// <summary>
    /// Checks this game's data once the world's mods loaded.
    /// </summary>
    /// <param name="world">The world's id.</param>
    /// <param name="data">This game's data fingerprint.</param>
    /// <returns>The warning, <see langword="null"/> for none.</returns>
    private RubyValue? DataCheck(string world, string data) => _topics.Call(WorldEntering.DataCheckTopic, new RubyHash { { "world", world }, { "data", data } });

    /// <summary>
    /// Follows the running action.
    /// </summary>
    /// <returns>The steps.</returns>
    private string[] Step() => Steps(_topics.Call(WorldEntering.StepTopic));

    /// <summary>
    /// Opens the edit of the world Plain, a Classic world of 4 seats its player made.
    /// </summary>
    /// <returns>The form.</returns>
    private static Form EditForm() => WorldForms.OpenEdit(FormTopics.Rules, new EditedWorld("Plain", 4, "", "", false, null, false, false, false, null), true);

    /// <summary>
    /// Runs a command of the screen and reads its steps.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="request">What it needs.</param>
    /// <returns>The steps, as <see cref="Steps"/> writes them.</returns>
    private string[] Do(string command, RubyHash? request = null)
    {
        RubyHash sent = request ?? [];
        sent["do"] = command;
        return Steps(_topics.Call(WorldEntering.DoTopic, sent));
    }

    /// <summary>
    /// Hands the steps the list while they wait to enter a world.
    /// </summary>
    /// <param name="state">How the list stands.</param>
    /// <param name="entries">Its entries, [id, folder, name, gone] each.</param>
    /// <returns>The steps.</returns>
    private string[] Look(string state, params RubyValue?[][] entries) =>
        Steps(_topics.Call(WorldEntering.DoTopic, new RubyHash
        {
            { "do", "look" },
            { "state", state },
            { "idle", true },
            { "named", true },
            { "entries", new RubyArray(entries.Select(entry => (RubyValue)new RubyArray(entry.Select(field => field ?? RubyNil.Value)))) },
        }));

    /// <summary>
    /// Writes steps as short lines: the kind, then what tells them apart.
    /// </summary>
    /// <param name="reply">The answer of a step topic.</param>
    /// <returns>One line per step.</returns>
    private static string[] Steps(RubyValue? reply) => [.. reply!.AsHash()["steps"].AsArray().Select(step =>
    {
        RubyArray parts = step.AsArray();
        string kind = parts[0].AsText();
        return kind switch
        {
            "say" or "password" or "busy" or "entry" => $"{kind} {parts[1].AsText()}",
            "confirm" => $"confirm {parts[1].AsText()} {string.Join(",", parts[2].AsArray().Select(choice => choice.AsArray()[1].AsText()))}",
            "choices" => $"choices {string.Join(",", parts[1].AsArray().Select(choice => choice.AsArray()[1].AsText()))}",
            "copy_own" => $"copy_own {parts[2].AsInt()}",
            "start" => parts[2].AsBool() ? "start placed" : "start fresh",
            _ => kind,
        };
    })];

    /// <summary>
    /// Describes a listed world as the relay lists it.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="open">Whether it has no password.</param>
    /// <param name="online">Its players online.</param>
    /// <param name="seats">Its seats.</param>
    /// <param name="start">How far it is with its starting save.</param>
    /// <param name="choose">Whether its new players choose where to start.</param>
    /// <param name="data">Its creator's game data.</param>
    /// <param name="strict">Whether only games with the same data may enter.</param>
    /// <param name="mods">Its mods as written.</param>
    /// <param name="off">Whether it turns other mods off.</param>
    /// <param name="creator">Its creator's id.</param>
    /// <returns>The world.</returns>
    private static ListedWorld World(string id, bool open = false, int online = 0, int seats = 4, string start = "none", bool choose = false, string data = Data, bool strict = false, string mods = "", bool off = false, string creator = "c") =>
        new(id, "Plain", seats, creator, "C", online, 0, start, false, choose, open, false, new WorldAbout("", mods, data, strict), [], WorldType.Classic, "off", OtherModsOff: off);

    /// <summary>
    /// The world directory as the steps reach it: a list the test sets and actions that end when the
    /// test says so.
    /// </summary>
    private sealed class FakeDirectory : IEnteringDirectory
    {
        /// <summary>
        /// The worlds listed by id.
        /// </summary>
        private readonly Dictionary<string, ListedWorld> _listed = new(StringComparer.Ordinal);

        /// <summary>
        /// The running or last action's state.
        /// </summary>
        private string _state = "idle";

        /// <summary>
        /// Why the last action failed.
        /// </summary>
        private string? _error;

        /// <summary>
        /// What the last action handed back.
        /// </summary>
        private (string Code, string? World, string? Name, string? Start, bool Choose)? _result;

        /// <summary>
        /// Gets each call the steps made, as a short line.
        /// </summary>
        public List<string> Calls { get; } = [];

        /// <summary>
        /// Lists a world.
        /// </summary>
        /// <param name="world">The world.</param>
        public void List(ListedWorld world) => _listed[world.Id] = world;

        /// <summary>
        /// Ends the running action as done.
        /// </summary>
        /// <param name="code">The world code it handed back, <see langword="null"/> for none.</param>
        /// <param name="start">The starting save's state it handed back.</param>
        public void Finish(string? code, string? start)
        {
            _state = "done";
            _result = code == null ? null : (code, "w1", "Plain", start, false);
        }

        /// <summary>
        /// Ends the running action as failed.
        /// </summary>
        /// <param name="error">Why.</param>
        public void Fail(string error)
        {
            _state = "failed";
            _error = error;
        }

        /// <inheritdoc />
        public (string State, ListedWorld? World) Listed(string id) => ("ready", _listed.GetValueOrDefault(id));

        /// <inheritdoc />
        public void Open(string id) => Calls.Add($"open {id}");

        /// <inheritdoc />
        public bool Read(string id) => Started($"read {id}");

        /// <inheritdoc />
        public bool Unlock(string id, string password) => Started($"unlock {id} {password}");

        /// <inheritdoc />
        public bool UnlockWithCode(string code) => Started($"unlock code {code}");

        /// <inheritdoc />
        public bool FetchStart(string code, string folder) => Started($"fetch {code} {folder}");

        /// <inheritdoc />
        public bool SetData(string id, string data) => Started($"data {id} {data}");

        /// <inheritdoc />
        public (string State, string? Error) Action() => (_state, _state == "failed" ? _error : null);

        /// <inheritdoc />
        public (string Code, string? World, string? Name, string? Start, bool Choose)? Result() => _state == "done" ? _result : null;

        /// <inheritdoc />
        public void Clear()
        {
            _state = "idle";
            _result = null;
        }

        /// <inheritdoc />
        public void Refresh(IReadOnlyList<string> added) => Calls.Add("refresh");

        /// <inheritdoc />
        public bool Create(string name, string password, int seats, bool hidden, bool choose, IReadOnlyList<(string Name, string Path)> start, WorldAbout about, string type, string share, int? difficulty, bool otherModsOff, string? squad, bool? raidBosses) =>
            Started($"create {name} {seats} {type}/{share} d={difficulty} s={squad} b={raidBosses} c={choose} {about.ModHashes} {(about.Strict ? "strict" : "loose")} data=[{about.Data}] [{about.Settings}]");

        /// <inheritdoc />
        public bool Edit(string id, int seats, string description, string mods, string? modHashes, int? difficulty, bool? otherModsOff, string? squad, bool? raidBosses) =>
            Started($"edit {id} {seats} {(modHashes == null ? "" : "hashes")} off={otherModsOff}");

        /// <inheritdoc />
        public bool SetSettings(string id, string settings) => Started($"settings {id} {settings}");

        /// <inheritdoc />
        public bool Find(string id) => Started($"find {id}");

        /// <inheritdoc />
        public bool Delete(string id) => Started($"delete {id}");

        /// <inheritdoc />
        public bool Ban(string id, string target) => Started($"ban {id} {target}");

        /// <summary>
        /// Starts an action.
        /// </summary>
        /// <param name="call">The call, as a short line.</param>
        /// <returns>true, since it started.</returns>
        private bool Started(string call)
        {
            Calls.Add(call);
            _state = "busy";
            return true;
        }
    }
}
