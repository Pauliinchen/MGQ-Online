//----------------------------------------------------------------
//  WorldEntering.Requests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the new world's type, sharing and player's choice from what its form sets for good
//      Paulinchen  2026-10-30: Made a new world without a data scan and without keeping differing games out, since its creator's game sets the scan as they enter
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Forms;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Squads;
using MGQOnline.Game.Worlds;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The directory requests a world screen form sends, built from the form's values the DLL holds,
/// and what each leads to once the relay answered.
/// </summary>
internal sealed partial class WorldEntering
{
    /// <summary>
    /// The form slot of a new world, as the scripts name it.
    /// </summary>
    private const string NewWorldSlot = "new_world";

    /// <summary>
    /// The form slot of a world's edit, as the scripts name it.
    /// </summary>
    private const string EditSlot = "edit_world";

    /// <summary>
    /// The form slot of a hidden world added by its id, as the scripts name it.
    /// </summary>
    private const string JoinSlot = "join_hidden";

    /// <summary>
    /// Gives the form open in a slot, <see langword="null"/> before <see cref="UseRequests"/>.
    /// </summary>
    private Func<string, Form?> _form = _ => null;

    /// <summary>
    /// Puts a text on the clipboard, answering whether it did.
    /// </summary>
    private Func<string, bool> _copy = _ => false;

    /// <summary>
    /// The new world being made, until the relay answered.
    /// </summary>
    private Creating? _creating;

    /// <summary>
    /// The hidden world being looked up by its id.
    /// </summary>
    private string? _adding;

    /// <summary>
    /// What the running edit sends along, kept for what the player is told afterwards.
    /// </summary>
    private WorldEdit? _edited;

    /// <summary>
    /// The mod settings the edit sends after the rest, <see langword="null"/> when it leaves them.
    /// </summary>
    private string? _editedSettings;

    /// <summary>
    /// The player being removed from the chosen world.
    /// </summary>
    private (string Id, string Name)? _target;

    /// <summary>
    /// Lets the requests read the screen's forms and reach the clipboard.
    /// </summary>
    /// <param name="form">Gives the form open in a slot.</param>
    /// <param name="copy">Puts a text on the clipboard, answering whether it did.</param>
    public void UseRequests(Func<string, Form?> form, Func<string, bool> copy)
    {
        _form = form;
        _copy = copy;
    }

    /// <summary>
    /// Runs a request command of the screen.
    /// </summary>
    /// <param name="command">The command: <c>create</c>, <c>edit</c>, <c>find</c>, <c>delete</c> or <c>ban</c>.</param>
    /// <param name="request">What it needs: the chosen world as <see cref="Take"/> reads it, a new world's <c>start</c> files ([name, path] each), the edit's <c>fresh</c> (whether the list was fetched since the screen opened), the ban's <c>target</c> and <c>target_name</c>.</param>
    /// <returns>Whether the command is a request's.</returns>
    private bool RunRequest(string command, RubyHash request)
    {
        switch (command)
        {
            case "create":
                Create(request);
                return true;
            case "edit":
                Take(request);
                Edit(request["fresh"].AsBool());
                return true;
            case "find":
                Find();
                return true;
            case "delete":
                Take(request);
                StartRequest("delete", () => _directory.Delete(_entry!.Id));
                return true;
            case "ban":
                Take(request);
                _target = (request["target"].AsText(), Text(request["target_name"]));
                StartRequest("ban", () => _directory.Ban(_entry!.Id, _target.Value.Id));
                return true;
            default:
                return RunSmallFlow(command, request);
        }
    }

    /// <summary>
    /// Runs one of the chosen world's small flows, which need no directory action.
    /// </summary>
    /// <param name="command">The command: <c>favourite</c>, <c>copy_id</c>, <c>forget</c> or <c>delete_saves</c>.</param>
    /// <param name="request">The chosen world as <see cref="Take"/> reads it.</param>
    /// <returns>Whether the command is a small flow's.</returns>
    private bool RunSmallFlow(string command, RubyHash request)
    {
        if (command is not ("favourite" or "copy_id" or "forget" or "delete_saves"))
        {
            return false;
        }

        Take(request);
        Entry entry = _entry!;
        switch (command)
        {
            case "favourite":
                Say(_lists.Favour(entry.Id, null) switch
                {
                    true => $"{entry.Name} is a favourite now.",
                    false => $"{entry.Name} is no longer a favourite.",
                    null => $"{entry.Name} could not be changed. Try again in a moment.",
                });
                break;
            case "copy_id":
                bool copied = _copy(entry.Id);
                Log(copied ? $"copied the id of {EntryText} to the clipboard" : $"the id of {EntryText} could not be put on the clipboard");
                if (copied)
                {
                    Say($"Copied the id of {entry.Name}. Share it{(_directory.Listed(entry.Id).World?.Open == true ? "" : " with the password")}.");
                }
                else
                {
                    Refuse("The id could not be put on the clipboard.");
                }

                break;
            case "forget":
                _lists.Remove(entry.Id);
                Say($"{entry.Name} was removed from your list.");
                _directory.Refresh(_lists.Added());
                break;
            case "delete_saves":
                bool deleted = entry.Folder != null && _worlds.Delete(entry.Folder);
                Say(deleted ? $"Your saves of {entry.Name} were deleted." : $"Your saves of {entry.Name} could not be deleted.");
                break;
        }

        _changes.Mark(WorldChanges.List | WorldChanges.Details);
        _steps.Add(new RubyArray { "back" });
        return true;
    }

    /// <summary>
    /// Takes what a step of a request's follow-up did.
    /// </summary>
    /// <param name="answer">The answer: <c>placed</c>, with <c>ok</c>, once the new world's starting save was copied.</param>
    /// <param name="request">The answer and what it carries.</param>
    /// <returns>Whether the answer is a request's.</returns>
    private bool RequestAnswered(string answer, RubyHash request)
    {
        if (answer != "placed" || _creating is not { World: { } world } creating)
        {
            return false;
        }

        if (request["ok"].AsBool())
        {
            Created(creating, world.Id);
        }
        else
        {
            Log($"the starting save could not be copied into {creating.Name}");
            Say($"Your save could not be copied into {creating.Name}.");
        }

        _creating = null;
        EndRequest(refresh: true);
        return true;
    }

    /// <summary>
    /// Acts once a request's action ended.
    /// </summary>
    /// <param name="kind">The action's kind.</param>
    /// <param name="state">How it ended: <c>done</c> or <c>failed</c>.</param>
    /// <param name="error">Why it failed.</param>
    /// <param name="result">What it handed back.</param>
    /// <returns>Whether the action was a request's.</returns>
    private bool RequestEnded(string kind, string state, string? error, (string Code, string? World, string? Name, string? Start, bool Choose)? result)
    {
        if (kind is not ("create" or "edit" or "settings" or "find" or "delete" or "ban"))
        {
            return false;
        }

        if (state == "failed")
        {
            string subject = kind switch
            {
                "create" => _creating?.Name ?? "a new world",
                "find" => $"world {Short(_adding ?? "")}",
                _ => EntryText,
            };
            Log($"{kind} of {subject} failed: {error}");
            Refuse(kind == "settings" ? WorldRequests.SettingsFailedText(_entry!.Name) : error ?? "");
            _creating = null;
            EndRequest(refresh: kind == "settings");
            return true;
        }

        switch (kind)
        {
            case "create":
                CreateEnded(result);
                return true;
            case "find":
                Log($"found the hidden world {result?.Name} ({Short(_adding!)})");
                _lists.Add(_adding!);
                _steps.Add(new RubyArray { "fresh_form", JoinSlot });
                _steps.Add(new RubyArray { "close_form" });
                _steps.Add(new RubyArray { "select", _adding });
                Say($"{result?.Name} was added to your list. {WorldScreenModel.EnterHint}");
                break;
            case "edit":
                Log($"changed {EntryText}");
                if (_editedSettings is { } settings)
                {
                    string id = _entry!.Id;
                    StartRequest("settings", () => _directory.SetSettings(id, settings));
                    return true;
                }

                _steps.Add(new RubyArray { "close_form" });
                Say($"{_entry!.Name} was changed.{ChangedText()}");
                break;
            case "settings":
                bool shared = SharedSettings.IsShared(_editedSettings);
                Log($"changed {EntryText} and its mod settings: {(shared ? "shared" : "each player's own")}");
                _context.Ask(SharedSettingsSync.ConfirmedTopic, new RubyHash { { "id", _entry!.Id }, { "text", _editedSettings } });
                _steps.Add(new RubyArray { "close_form" });
                Say($"{_entry.Name} was changed.{ChangedText()} {WorldRequests.SharedText(shared)}");
                break;
            case "delete":
                Log($"deleted {EntryText} for everyone");
                Say($"{_entry!.Name} was deleted for everyone.");
                break;
            case "ban":
                Log($"removed {_target?.Name} ({Short(_target?.Id ?? "")}) from {EntryText}");
                Say($"{_target?.Name} was removed from {_entry!.Name}.");
                break;
        }

        EndRequest(refresh: true);
        return true;
    }

    /// <summary>
    /// Makes the world the new world's form describes, without a data scan: its creator's game sets
    /// it once the world's mods loaded as they enter, which the title cannot measure.
    /// </summary>
    /// <param name="request">The starting save's files, [name, path] each, none for a world without one.</param>
    private void Create(RubyHash request)
    {
        Form form = FormIn(NewWorldSlot);
        WorldFormValues values = WorldForms.ValuesOf(form, FormTopics.Rules);
        WorldSetup setup = values.Setup ?? throw new BridgeRequestException("The new world's form sets no world type.");
        string name = form.TextOf("name");
        List<(string Name, string Path)> files = request["start"].IsNil ? [] : [.. request["start"].AsArray().Select(file => (file.AsArray()[0].AsText(), file.AsArray()[1].AsText()))];
        bool raid = setup.Type == WorldType.Raid;
        string mods = form.TextOf("mods");
        string? squad = raid ? SquadText(values.Squad) : null;
        int? difficulty = raid ? values.Difficulty ?? WorldDifficulty.Default : null;
        _creating = new Creating(name, setup.Type, setup.Share, difficulty, squad, !raid && values.RaidBosses, files, null);
        WorldAbout about = new(form.TextOf("description"), mods, "", false, CreatorHashes(mods), form.IsTicked("shared") ? SharedSettings.WithMarker("") : "");
        int seats = SeatsOf(form);
        StartRequest("create", () => _directory.Create(name, form.TextOf("password"), seats, form.IsTicked("hidden"), setup.Choose, files, about, setup.Type, setup.Share, difficulty, values.OtherModsOff, squad, raid ? null : values.RaidBosses));
    }

    /// <summary>
    /// Makes the new world's folder once the relay made it, then copies its starting save in, which
    /// the scripts do.
    /// </summary>
    /// <param name="result">What the relay handed back.</param>
    private void CreateEnded((string Code, string? World, string? Name, string? Start, bool Choose)? result)
    {
        Creating creating = _creating!;
        string id = result?.World ?? "";
        Log($"created {creating.Name} ({Short(id)})");
        LocalWorld? world = result is { } made ? _worlds.Found(made.Code, new LocalWorldAbout(creating.Name, id, null, creating.Type, creating.Share, creating.Difficulty, creating.Squad, creating.RaidBosses)) : null;
        if (world == null)
        {
            Log($"the folder of {creating.Name} could not be made");
            Say(WorldRequests.NoFolderText);
            _creating = null;
            EndRequest(refresh: true);
            return;
        }

        if (creating.Files.Count > 0)
        {
            _creating = creating with { World = new LocalWorldRef(id) };
            _steps.Add(new RubyArray { "place_start", LocalWorldTopics.WorldOf(world), new RubyArray(creating.Files.Select(file => (RubyValue)new RubyArray { file.Name, file.Path })) });
            return;
        }

        Created(creating, id);
        _creating = null;
        EndRequest(refresh: true);
    }

    /// <summary>
    /// Ends a new world's making once its folder holds what it needs: a favourite, with a fresh form,
    /// and the cursor on it.
    /// </summary>
    /// <param name="creating">The new world.</param>
    /// <param name="id">Its directory id.</param>
    private void Created(Creating creating, string id)
    {
        _lists.Favour(id, true);
        // A fresh form keeps the next world from starting as a copy of this one.
        _steps.Add(new RubyArray { "fresh_form", NewWorldSlot });
        _steps.Add(new RubyArray { "close_form" });
        _steps.Add(new RubyArray { "select", id });
        Say($"{creating.Name} was created. {WorldScreenModel.EnterHint}");
    }

    /// <summary>
    /// Changes the chosen world as the edit's form says: its creator's game sends the hashes of its
    /// required mods outside the catalog too, and its mod settings after the rest when Shared Mod
    /// Settings changed.
    /// </summary>
    /// <param name="fresh">Whether the list was fetched since the screen opened.</param>
    private void Edit(bool fresh)
    {
        ListedWorld listed = _directory.Listed(_entry!.Id).World ?? throw new BridgeRequestException($"The list holds no world {_entry.Id}.");
        Form form = FormIn(EditSlot);
        WorldFormValues values = WorldForms.ValuesOf(form, FormTopics.Rules);
        bool raid = listed.Type == WorldType.Raid;
        bool own = listed.CreatorId == _me;
        string mods = form.TextOf("mods");
        string settings = _context.Ask(SharedSettingsSync.OfTopic, new RubyHash { { "id", listed.Id }, { "settings", listed.About.Settings }, { "fresh", fresh } }) is RubyString text ? text.AsText() : listed.About.Settings;
        _editedSettings = WorldRequests.SharingOf(own, SharedSettings.IsShared(settings), form.IsTicked("shared")) switch
        {
            true => SharedSettings.WithMarker(settings),
            false => "",
            null => null,
        };
        WorldEdit before = new(listed.Difficulty, SquadOf(listed.Squad), listed.RaidBosses, listed.OtherModsOff);
        WorldEdit edit = WorldRequests.EditOf(raid, before, FormTopics.Rules.DefaultSquad, values);
        _edited = edit;
        string id = listed.Id;
        int seats = SeatsOf(form);
        string description = form.TextOf("description");
        string? hashes = own ? CreatorHashes(mods) : null;
        StartRequest("edit", () => _directory.Edit(id, seats, description, mods, hashes, edit.Difficulty, edit.OtherModsOff, edit.Squad is { } squad ? SquadText(squad) : null, edit.RaidBosses));
    }

    /// <summary>
    /// Looks up the hidden world the join form names by its id, to add it to the list.
    /// </summary>
    private void Find()
    {
        string id = FormIn(JoinSlot).TextOf("id");
        _adding = id;
        StartRequest("find", () => _directory.Find(id));
    }

    /// <summary>
    /// Starts a request's action, or tells why it could not start.
    /// </summary>
    /// <param name="kind">The action's kind.</param>
    /// <param name="start">Starts it.</param>
    private void StartRequest(string kind, Func<bool> start)
    {
        _share();
        if (start())
        {
            StartAction(kind, () => true);
            return;
        }

        Log($"the {kind} request could not be started");
        Refuse(kind == "settings" ? WorldRequests.SettingsFailedText(_entry!.Name) : WorldRequests.NotStartedText);
        _creating = null;
        // The world's other changes were saved, which the list should show.
        EndRequest(refresh: kind == "settings");
    }

    /// <summary>
    /// Ends a request: the list fetched again when asked, then back to the list.
    /// </summary>
    /// <param name="refresh">Whether the list is fetched again.</param>
    private void EndRequest(bool refresh)
    {
        if (refresh)
        {
            _directory.Refresh(_lists.Added());
        }

        _steps.Add(new RubyArray { "back" });
    }

    /// <summary>
    /// Tells what the running edit changed for the world's players.
    /// </summary>
    /// <returns>The sentences, each with a space in front.</returns>
    private string ChangedText() =>
        _edited == null ? "" : WorldRequests.ChangedText(_edited, value => WorldDifficulty.IsValid(value) ? WorldDifficulty.Names[value - WorldDifficulty.Min] : null, WorldTopics.FormationName);

    /// <summary>
    /// Gives the form open in a slot.
    /// </summary>
    /// <param name="slot">The slot.</param>
    /// <returns>The form.</returns>
    /// <exception cref="BridgeRequestException">No form is open there.</exception>
    private Form FormIn(string slot) => _form(slot) ?? throw new BridgeRequestException($"No form is open in {slot}.");

    /// <summary>
    /// Reads the seats a form names.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <returns>The seats, 0 for none, which the directory refuses.</returns>
    private static int SeatsOf(Form form) => int.TryParse(form.TextOf("seats"), System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out int seats) ? seats : 0;

    /// <summary>
    /// Writes squad rules as the directory takes them.
    /// </summary>
    /// <param name="squad">The rules.</param>
    /// <returns>Their text.</returns>
    private static string SquadText(WorldSquad squad) => RaidSquad.TextOf(squad.Luka, squad.Formation, squad.Front, squad.RaidFront);

    /// <summary>
    /// Reads squad rules as the list has them.
    /// </summary>
    /// <param name="text">The text, empty for none.</param>
    /// <returns>The rules, <see langword="null"/> for none.</returns>
    private static WorldSquad? SquadOf(string text) =>
        RaidSquad.TryParse(text, out bool luka, out int formation, out int front, out int raidFront) ? new WorldSquad(luka, formation, front, raidFront) : null;

    /// <summary>
    /// Writes the creator's hashes of a world's required mods outside the catalog.
    /// </summary>
    /// <param name="mods">The world's mods.</param>
    /// <returns>The hashes, empty for none.</returns>
    private string CreatorHashes(string mods) => _context.Ask("mods.creator_hashes", mods) is RubyString hashes ? hashes.AsText() : "";

    /// <summary>
    /// A new world being made.
    /// </summary>
    /// <param name="Name">Its name.</param>
    /// <param name="Type">Its type.</param>
    /// <param name="Share">How it shares companions.</param>
    /// <param name="Difficulty">A Raid World's difficulty.</param>
    /// <param name="Squad">A Raid World's squad rules as text.</param>
    /// <param name="RaidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
    /// <param name="Files">Its starting save's files.</param>
    /// <param name="World">Its folder once made, while the scripts copy the starting save in.</param>
    private sealed record Creating(string Name, string Type, string Share, int? Difficulty, string? Squad, bool RaidBosses, IReadOnlyList<(string Name, string Path)> Files, LocalWorldRef? World);

    /// <summary>
    /// A new world's directory id once its folder was made.
    /// </summary>
    /// <param name="Id">The id.</param>
    private sealed record LocalWorldRef(string Id);
}
