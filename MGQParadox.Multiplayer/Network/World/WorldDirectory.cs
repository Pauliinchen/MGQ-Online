//----------------------------------------------------------------
//  WorldDirectory.cs
//
//  Changelog:
//      Paulinchen  2026-10-01: Stopped offering admin deletes after the list failed to load
//      Paulinchen  2026-09-30: Told the game script whether the player is one of the relay's admins
//                            - Made a world with a starting save, fetched it for new players, and listed which worlds have one
//                            - Made hidden worlds, listed them for their players, and opened a world by its id alone
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The world directory as the game script uses it: the list of worlds, fetched again whenever asked,
/// and one action at a time, making, opening, deleting or clearing a player out of a world, or
/// fetching its starting save. Both run on threads of their own, and the game script reads how
/// they stand.
/// </summary>
internal sealed class WorldDirectory
{
    /// <summary>
    /// What the game script reads as the state of the list or of the action.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// Why the list or the action failed.
    /// </summary>
    private const string ErrorHeader = "error";

    /// <summary>
    /// Whether the list was made for one of the relay's admins, who sees every world and may delete any.
    /// </summary>
    private const string AdminHeader = "admin";

    /// <summary>
    /// Which action ran.
    /// </summary>
    private const string KindHeader = "kind";

    /// <summary>
    /// The world code an action that made or opened a world ended with.
    /// </summary>
    private const string CodeHeader = "code";

    /// <summary>
    /// The id of the world an action made or opened, as the list names it.
    /// </summary>
    private const string WorldHeader = "world";

    /// <summary>
    /// The name of the world an action opened.
    /// </summary>
    private const string NameHeader = "name";

    /// <summary>
    /// How far the world an action opened is with its starting save.
    /// </summary>
    private const string StartHeader = "start";

    /// <summary>
    /// Why an action failed when the game script has not said who plays.
    /// </summary>
    private const string NoPlayer = "The game has not said who plays yet.";

    /// <summary>
    /// Why an action failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The list as the game script reads it, <see langword="null"/> before the first one arrived.
    /// </summary>
    private string? _list;

    /// <summary>
    /// Whether the last fetched list was made for one of the relay's admins; false after a failed fetch.
    /// </summary>
    private bool _admin;

    /// <summary>
    /// Whether a list is being fetched.
    /// </summary>
    private bool _listing;

    /// <summary>
    /// Why the last list could not be fetched.
    /// </summary>
    private string? _listError;

    /// <summary>
    /// Counts the actions, so a thread of an earlier one changes nothing.
    /// </summary>
    private int _actionGeneration;

    /// <summary>
    /// The running or last action: its kind, and "busy", "done" or "failed".
    /// </summary>
    private (string Kind, string State)? _action;

    /// <summary>
    /// What the last action ended with.
    /// </summary>
    private ActionResult? _actionResult;

    /// <summary>
    /// Why the last action failed.
    /// </summary>
    private string? _actionError;

    /// <summary>
    /// The game's world directory, which the game script uses.
    /// </summary>
    public static WorldDirectory Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// How often a new world's password is hashed; tests make it cheap.
    /// </summary>
    public int Iterations { get; init; } = WorldLock.DefaultIterations;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = () => Player.Key is { } key && Player.Name is { } name ? (key, name) : null;

    /// <summary>
    /// Fetches the list again, unless it is being fetched already.
    /// </summary>
    public void Refresh()
    {
        lock (_gate)
        {
            if (_listing)
            {
                return;
            }

            _listing = true;
        }

        StartThread("MultiplayerDirectoryList", () =>
        {
            WorldListing? listing = null;
            string? error = null;

            try
            {
                listing = Client().List(Playing()?.Key);
            }
            catch (Exception ex)
            {
                error = ReasonFor(ex);
                Log.Write($"world list failed: {ex.GetBaseException().Message}");
            }

            lock (_gate)
            {
                _listing = false;
                _listError = error;
                _admin = listing?.Admin == true;

                if (listing != null)
                {
                    _list = ListText(listing.Worlds);
                }
            }
        });
    }

    /// <summary>
    /// Describes the list for the game script.
    /// </summary>
    /// <returns><c>state</c> ("loading", "ready" or "failed"), <c>error</c> and <c>admin</c> (1 for an admin), then one line per world and player: <c>world</c>, id, seats, players online, creator's id, when last active, creator's name, name, starting save ("none", "pending" or "ready"), 1 when hidden; <c>member</c>, id, 1 when online, name; each separated by tabs.</returns>
    public string DescribeList()
    {
        lock (_gate)
        {
            var state = _listing ? "loading" : _listError != null ? "failed" : _list != null ? "ready" : "idle";
            return new Message([new(StateHeader, state), new(ErrorHeader, _listError), new(AdminHeader, _admin ? "1" : null)], _list ?? string.Empty).Encode();
        }
    }

    /// <summary>
    /// Makes a world: a new token, locked with the password, and the world in the directory, with
    /// the starting save new players get, if there is one.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="password">The password others enter it with.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="hidden">Whether the list leaves it out for everyone but its players.</param>
    /// <param name="start">The starting save's files, each named as new players get it and where it is read from; empty for none.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Create(string name, string password, int seats, bool hidden, IReadOnlyList<(string Name, string Path)> start) => Start("create", () =>
    {
        var (key, playerName) = Me();
        var token = JoinCode.NewToken();
        var id = Relays.WorldRoomOf(token);
        var worldLock = WorldLock.Close(token, password, Iterations);
        // Sealed before the world exists, so a save that cannot be read leaves no world behind.
        var box = start.Count > 0 ? SealStart(token, start) : null;
        var client = Client();

        client.Create(id, name, seats, key, playerName, WorldKeys.AuthHashOf(WorldKeys.AuthKeyOf(token)), worldLock, box != null, hidden);
        Log.Write($"made world {id}{(hidden ? ", hidden" : string.Empty)}");

        if (box != null)
        {
            UploadStart(client, id, key, box);
        }

        return new ActionResult(new WorldCode(token, Relays.Current, seats).ToText());
    });

    /// <summary>
    /// Fetches a world's starting save and writes its files into a folder.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <param name="folder">The folder, relative to the game's folder or full.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool FetchStart(string code, string folder) => Start("start", () =>
    {
        var world = WorldCode.Parse(code) ?? throw new ActionException("The world code is damaged.");
        var id = Relays.WorldRoomOf(world.Token);
        var box = Client().GetStart(id, Me().Key, WorldKeys.AuthKeyOf(world.Token));

        try
        {
            var names = StartingSave.Open(world.Token, box, ModFolder.GamePathOf(folder));
            Log.Write($"fetched the starting save of world {id}: {string.Join(", ", names)}");
        }
        catch (InvalidDataException ex)
        {
            throw new ActionException(ex.Message);
        }
        catch (IOException ex)
        {
            throw new ActionException($"The starting save could not be written: {ex.Message}");
        }

        return null;
    });

    /// <summary>
    /// Zips and encrypts the starting save's files.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="files">The files, each named as new players get it and where it is read from.</param>
    /// <returns>The starting save as the relay keeps it.</returns>
    private static byte[] SealStart(string token, IReadOnlyList<(string Name, string Path)> files)
    {
        try
        {
            return StartingSave.Seal(token, files.Select(file => (file.Name, ModFolder.GamePathOf(file.Path))).ToList());
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException)
        {
            throw new ActionException($"The save could not be read: {ex.Message}");
        }
    }

    /// <summary>
    /// Uploads a new world's starting save, deleting the world again when that fails, since nobody could ever enter it.
    /// </summary>
    /// <param name="client">The directory's client.</param>
    /// <param name="id">The world.</param>
    /// <param name="key">The creator's key.</param>
    /// <param name="box">The starting save.</param>
    private static void UploadStart(DirectoryClient client, string id, string key, byte[] box)
    {
        try
        {
            client.PutStart(id, key, box);
            Log.Write($"uploaded the starting save of world {id}, {box.Length} bytes");
        }
        catch (DirectoryException ex)
        {
            try
            {
                client.Delete(id, key);
            }
            catch (DirectoryException deleteFailed)
            {
                Log.Write($"could not delete world {id} after its starting save failed: {deleteFailed.Message}");
            }

            throw new ActionException(ex.Status == null ? Unreachable : $"The starting save could not be uploaded: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens a world's lock with its password, which gives its world code, its name and how far it
    /// is with its starting save, so a hidden world is entered by its id alone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="password">The password.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Unlock(string id, string password) => Start("unlock", () =>
    {
        var world = Client().Lock(id);
        var token = world.Lock.Open(password);

        if (token == null)
        {
            throw new ActionException("The password is wrong.");
        }

        if (Relays.WorldRoomOf(token) != id)
        {
            throw new ActionException("The world's lock is damaged.");
        }

        return new ActionResult(new WorldCode(token, Relays.Current, world.Seats).ToText(), world.Name, world.Start);
    });

    /// <summary>
    /// Deletes a world for everyone, which only its creator or one of the relay's admins may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Delete(string id) => Start("delete", () =>
    {
        Client().Delete(id, Me().Key);
        return null;
    });

    /// <summary>
    /// Removes a player from a world and keeps them out, which only its creator may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="target">The player's id.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Ban(string id, string target) => Start("ban", () =>
    {
        Client().Ban(id, Me().Key, target);
        return null;
    });

    /// <summary>
    /// Describes the running or last action for the game script.
    /// </summary>
    /// <returns><c>state</c> ("idle", "busy", "done" or "failed"), and whichever of <c>kind</c>, <c>code</c>, <c>world</c>, <c>name</c>, <c>start</c> and <c>error</c> apply.</returns>
    public string DescribeAction()
    {
        lock (_gate)
        {
            var result = _action?.State == "done" ? _actionResult : null;
            var headers = new KeyValuePair<string, string?>[]
            {
                new(StateHeader, _action?.State ?? "idle"),
                new(KindHeader, _action?.Kind),
                new(CodeHeader, result?.Code),
                new(WorldHeader, WorldCode.Parse(result?.Code) is { } world ? Relays.WorldRoomOf(world.Token) : null),
                new(NameHeader, result?.Name is { } name ? OnOneField(name) : null),
                new(StartHeader, result?.Start),
                new(ErrorHeader, _action?.State == "failed" ? _actionError : null),
            };

            return new Message(headers).Encode();
        }
    }

    /// <summary>
    /// Forgets the last action once the game script took its result, so the next one may start.
    /// </summary>
    public void ClearAction()
    {
        lock (_gate)
        {
            if (_action?.State != "busy")
            {
                _action = null;
                _actionResult = null;
                _actionError = null;
            }
        }
    }

    /// <summary>
    /// Runs an action on a thread of its own, unless one runs already.
    /// </summary>
    /// <param name="kind">The action's kind.</param>
    /// <param name="work">The action, which returns the world it made or opened, or <see langword="null"/>.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    private bool Start(string kind, Func<ActionResult?> work)
    {
        int generation;

        lock (_gate)
        {
            if (_action?.State == "busy")
            {
                return false;
            }

            generation = ++_actionGeneration;
            _action = (kind, "busy");
            _actionResult = null;
            _actionError = null;
        }

        StartThread($"MultiplayerDirectory{kind}", () =>
        {
            ActionResult? result = null;
            string? error = null;

            try
            {
                result = work();
            }
            catch (Exception ex)
            {
                error = ReasonFor(ex);
                Log.Write($"world {kind} failed: {ex.GetBaseException().Message}");
            }

            lock (_gate)
            {
                if (generation == _actionGeneration)
                {
                    _action = (kind, error == null ? "done" : "failed");
                    _actionResult = result;
                    _actionError = error;
                }
            }
        });

        return true;
    }

    /// <summary>
    /// Makes a client for the relay this version keeps its worlds at.
    /// </summary>
    /// <returns>The client.</returns>
    private DirectoryClient Client() =>
        new(RelayAddress(Relays.Current) ?? throw new ActionException($"Relay {Relays.Current} is unknown."));

    /// <summary>
    /// Reads who plays, which every action that changes the directory needs.
    /// </summary>
    /// <returns>The player's key and name.</returns>
    private (string Key, string Name) Me() => Playing() ?? throw new ActionException(NoPlayer);

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        ActionException action => action.Message,
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Status: HttpStatusCode.NotFound } => "The world no longer exists.",
        DirectoryException { Status: HttpStatusCode.Forbidden } => "Only the world's creator may do this.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } => "You have made as many worlds as you may. Delete one first.",
        DirectoryException { Status: HttpStatusCode.RequestEntityTooLarge } => "The save is too large to share.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// Writes the list as the game script reads it.
    /// </summary>
    /// <param name="worlds">The worlds.</param>
    /// <returns>The lines.</returns>
    private static string ListText(IEnumerable<ListedWorld> worlds)
    {
        var text = new StringBuilder();

        foreach (var world in worlds)
        {
            text.Append("world\t").Append(world.Id).Append('\t').Append(world.Seats.ToString(CultureInfo.InvariantCulture))
                .Append('\t').Append(world.Online.ToString(CultureInfo.InvariantCulture)).Append('\t').Append(world.CreatorId)
                .Append('\t').Append(world.Active.ToString(CultureInfo.InvariantCulture)).Append('\t').Append(OnOneField(world.CreatorName))
                .Append('\t').Append(OnOneField(world.Name)).Append('\t').Append(OnOneField(world.Start)).Append('\t').Append(world.Hidden ? '1' : '0').Append('\n');

            foreach (var member in world.Members.OrderByDescending(member => member.Online).ThenBy(member => member.Name, StringComparer.OrdinalIgnoreCase))
            {
                text.Append("member\t").Append(member.Id).Append('\t').Append(member.Online ? '1' : '0').Append('\t').Append(OnOneField(member.Name)).Append('\n');
            }
        }

        return text.ToString();
    }

    /// <summary>
    /// Keeps a name inside its field.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name without tabs and line breaks.</returns>
    private static string OnOneField(string name) => name.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();

    /// <summary>
    /// The world an action made or opened.
    /// </summary>
    /// <param name="Code">The world code.</param>
    /// <param name="Name">The world's name, when the action learned it from the directory.</param>
    /// <param name="Start">How far the world is with its starting save, when the action learned it from the directory.</param>
    private sealed record ActionResult(string Code, string? Name = null, string? Start = null);

    /// <summary>
    /// An action that failed for a reason the player is told as it is.
    /// </summary>
    /// <param name="reason">The reason.</param>
    private sealed class ActionException(string reason) : Exception(reason);
}
