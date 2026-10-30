//----------------------------------------------------------------
//  LocalWorldTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Stopped handing the world screen this game's data, which entering compares once the world's mods loaded
//      Paulinchen  2026-10-23: Dropped the topics of deleting, adding, removing and favouring worlds, which the screen steps do in the DLL
//                            - Handed the world screen the worlds, the lists and the game data the topics keep, which makes the entries itself
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQOnline.Game.Worlds;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the worlds on this PC and of the player's lists of worlds: the folders and
/// their world.ini, the world screen's entries, the favourites and the hidden worlds added, a
/// Discord invite into a world, and the game data compared with a world creator's.
/// </summary>
/// <remarks>
/// A world goes to the scripts as <see cref="WorldOf"/> describes it; the scripts keep the open
/// world's fields themselves, since some are read every frame and on the battle server.
/// </remarks>
internal static class LocalWorldTopics
{
    /// <summary>
    /// What the topics keep, which the world screen reads too.
    /// </summary>
    /// <param name="Worlds">The worlds on this PC.</param>
    /// <param name="Lists">The player's lists of worlds.</param>
    internal sealed record Kept(LocalWorlds Worlds, WorldLists Lists);

    /// <summary>
    /// Lists the worlds on this PC: nothing in; an Array of worlds out.
    /// </summary>
    public const string Local = "worlds.local";

    /// <summary>
    /// Makes a world's folder or finds the one there is and describes the world in it: <c>code</c>,
    /// <c>name</c>, <c>world</c> (the directory's id), and <c>type</c>, <c>share</c>, <c>difficulty</c>,
    /// <c>squad</c> and <c>raid_bosses</c>, each nil to keep what world.ini says, in; the world out, nil
    /// when it could not be made, read or written.
    /// </summary>
    public const string Found = "worlds.found";

    /// <summary>
    /// Describes a world on this PC anew as the directory says it and writes its world.ini at once:
    /// <c>id</c> (the folder's), <c>name</c>, <c>world</c>, <c>seats</c> and the fields of
    /// <see cref="Found"/> in; the world out, nil when there is none or it could not be written.
    /// </summary>
    public const string Describe = "worlds.describe";

    /// <summary>
    /// Changes a world on this PC and writes its world.ini: <c>id</c> and any of <c>difficulty</c>,
    /// <c>squad</c>, <c>raid_bosses</c> and <c>played</c> (true: played now) in; <c>world</c> and
    /// <c>written</c> out, nil when there is none.
    /// </summary>
    public const string Update = "worlds.update";

    /// <summary>
    /// Finds a world's latest save, an autosave included: the folder's id in; [the save's index as
    /// DataManager takes it (an Integer, or an autosave's two digits as a String), its path relative to
    /// the game folder] out, nil without any.
    /// </summary>
    public const string LatestSave = "worlds.latest_save";

    /// <summary>
    /// Lists the hidden worlds added: nothing in; their directory ids, the one added last at the end, out.
    /// </summary>
    public const string Added = "worlds.added";

    /// <summary>
    /// Takes an invite the player accepted in Discord: <c>code</c> (its join secret) and <c>open</c>
    /// (the directory id of the world open now, nil for none) in; <c>world</c> (its directory id) and
    /// <c>taken</c> (false for the world open already) out, nil when it is no world code.
    /// </summary>
    public const string Invite = "worlds.invite";

    /// <summary>
    /// Takes the invite taken last, once: nothing in; [directory id, world code] out, nil without one.
    /// </summary>
    public const string InviteTake = "worlds.invite_take";

    /// <summary>
    /// Keeps this game's data fingerprint, which the scripts make once a session: the fingerprint in; nothing out.
    /// </summary>
    public const string GameData = "worlds.game_data";

    /// <summary>
    /// Compares this game's data with a world creator's, see <see cref="GameDataCompare.Differing"/>:
    /// the creator's fingerprint in; the parts that differ out, nil when they cannot be compared.
    /// </summary>
    public const string DataDiffering = "worlds.data_differing";

    /// <summary>
    /// Names parts of the game data in a sentence, see <see cref="GameDataCompare.Text"/>: <c>parts</c>
    /// and <c>named</c> in; the text out.
    /// </summary>
    public const string DataText = "worlds.data_text";

    /// <summary>
    /// The folder of the worlds on this PC, relative to the game folder, as the scripts name it.
    /// </summary>
    public const string WorldsFolder = "Patch/Multiplayer/Worlds";

    /// <summary>
    /// Registers the topics on a context, with the worlds and lists of the mod folder.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds share.</param>
    /// <returns>What the topics keep, for the world screen.</returns>
    public static Kept Register(BridgeContext context, WorldServices services)
    {
        LocalWorlds worlds = new(Path.Combine(ModFolder.Root, "Worlds"), WorldsFolder, () => DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        return Register(context, services, worlds, new WorldLists(services.Player, ModFolder.Root, () => context.Frame));
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="services">What the topics of worlds share.</param>
    /// <param name="worlds">The worlds on this PC.</param>
    /// <param name="lists">The player's lists of worlds.</param>
    /// <returns>What the topics keep, for the world screen.</returns>
    internal static Kept Register(BridgeContext context, WorldServices services, LocalWorlds worlds, WorldLists lists)
    {
        (string Id, string Code)? invite = null;
        string fingerprint = "";

        context.Register(Local, (_, _) => new RubyArray(worlds.All().Select(world => (RubyValue)WorldOf(world))));
        context.Register(Found, (_, request) => Changed(services, worlds.Found(request.AsHash()["code"].AsText(), AboutOf(request.AsHash(), null)) is { } world ? WorldOf(world) : null));
        context.Register(Describe, (_, request) => Changed(services, worlds.Describe(request.AsHash()["id"].AsText(), AboutOf(request.AsHash(), IntOf(request.AsHash()["seats"]))) is { } world ? WorldOf(world) : null));
        context.Register(Update, (_, request) => Changed(services, UpdateOf(request.AsHash(), worlds)));
        context.Register(LatestSave, (_, request) => worlds.LatestSave(request.AsText()) is { } latest ? new RubyArray([latest.Save.Slot is { } slot ? slot : latest.Save.AutoSlot, latest.Path]) : null);
        context.Register(Added, (_, _) => Texts(lists.Added()));
        context.Register(Invite, (_, request) =>
        {
            if (WorldCode.Parse(request.AsHash()["code"].AsText()) is not { } code)
            {
                return null;
            }

            string id = Relays.WorldRoomOf(code.Token);
            bool taken = request.AsHash()["open"].IsNil || request.AsHash()["open"].AsText() != id;
            if (taken)
            {
                invite = (id, request.AsHash()["code"].AsText());
            }

            Log.Write(taken ? $"took an invite into world {id[..12]}" : $"ignored an invite into world {id[..12]}, which is open already");
            return new RubyHash { { "world", id }, { "taken", taken } };
        });
        context.Register(InviteTake, (_, _) =>
        {
            (string Id, string Code)? taken = invite;
            invite = null;
            return taken is { } pending ? new RubyArray([pending.Id, pending.Code]) : null;
        });
        context.Register(GameData, (_, request) =>
        {
            fingerprint = request.AsText();
            return null;
        });
        context.Register(DataDiffering, (_, request) => GameDataCompare.Differing(fingerprint, request.IsNil ? null : request.AsText()) is { } parts ? Texts(parts) : null);
        context.Register(DataText, (_, request) => GameDataCompare.Text([.. request.AsHash()["parts"].AsArray().Select(part => part.AsText())], request.AsHash()["named"].AsInt()));
        return new Kept(worlds, lists);
    }

    /// <summary>
    /// Describes a world on this PC for the scripts.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns><c>id</c> (the folder's), <c>name</c>, <c>code</c>, <c>world</c> (the directory's id or nil),
    /// <c>created</c>, <c>played</c> (seconds since 1970, nil before), <c>type</c>, <c>share</c>,
    /// <c>difficulty</c> (each nil when world.ini names none), <c>squad</c> (as <c>squad.read</c> answers
    /// it, nil for none), <c>raid_bosses</c> and <c>seats</c> (which the code tells, 0 for none).</returns>
    internal static RubyHash WorldOf(LocalWorld world) => new()
    {
        { "id", world.Id },
        { "name", world.Name },
        { "code", world.Code },
        { "world", world.DirectoryId },
        { "created", world.Created },
        { "played", world.PlayedAt is { } played ? played : RubyNil.Value },
        { "type", world.Type },
        { "share", world.Share },
        { "difficulty", world.Difficulty is { } difficulty ? difficulty : RubyNil.Value },
        { "squad", world.Squad is { } squad ? (RubyValue?)SquadTopics.ValueOf(squad) ?? RubyNil.Value : RubyNil.Value },
        { "raid_bosses", world.RaidBosses },
        { "seats", world.Seats },
    };

    /// <summary>
    /// Reads what the directory says of a world from a request.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="seats">The seats, <see langword="null"/> to keep what the code tells.</param>
    /// <returns>What it says.</returns>
    private static LocalWorldAbout AboutOf(RubyHash request, int? seats) => new(
        request["name"].IsNil ? "" : request["name"].AsText(),
        TextOf(request["world"]),
        seats,
        TextOf(request["type"]),
        TextOf(request["share"]),
        IntOf(request["difficulty"]),
        SquadOf(request["squad"]),
        request["raid_bosses"].IsNil ? null : request["raid_bosses"].AsBool());

    /// <summary>
    /// Answers <see cref="Update"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="worlds">The worlds on this PC.</param>
    /// <returns>The world and whether it was written, nil when there is none.</returns>
    private static RubyHash? UpdateOf(RubyHash request, LocalWorlds worlds)
    {
        string id = request["id"].AsText();
        int? difficulty = IntOf(request["difficulty"]);
        string? squad = SquadOf(request["squad"]);
        RubyValue raidBosses = request["raid_bosses"];
        bool played = !request["played"].IsNil && request["played"].AsBool();
        long? now = played ? worlds.Now() : null;
        (LocalWorld World, bool Written)? updated = worlds.Update(id, world => world with
        {
            Difficulty = difficulty ?? world.Difficulty,
            Squad = squad ?? world.Squad,
            RaidBosses = raidBosses.IsNil ? world.RaidBosses : raidBosses.AsBool(),
            PlayedAt = now ?? world.PlayedAt,
        });
        return updated is { } result ? new RubyHash { { "world", WorldOf(result.World) }, { "written", result.Written } } : null;
    }

    /// <summary>
    /// Answers a change of a list with whether Player.ini was written and how it stands.
    /// </summary>
    /// <param name="services">What the topics of worlds share.</param>
    /// <param name="written">Whether Player.ini was written.</param>
    /// <returns>The answer.</returns>
    private static RubyHash Written(WorldServices services, bool written) =>
        new() { { "written", written }, { "player", SettingsTopics.State(services.Player) } };

    /// <summary>
    /// Tells the scripts the worlds changed, and passes the answer on.
    /// </summary>
    /// <param name="services">What the topics of worlds share.</param>
    /// <param name="answer">The answer.</param>
    /// <returns>The answer.</returns>
    private static RubyValue? Changed(WorldServices services, RubyValue? answer)
    {
        services.Changes.Mark(WorldChanges.List);
        return answer;
    }

    /// <summary>
    /// Reads squad rules from a request as <c>squad.write</c> takes them.
    /// </summary>
    /// <param name="value">The rules, nil for none.</param>
    /// <returns>Their text, <see langword="null"/> for none or rules out of range.</returns>
    private static string? SquadOf(RubyValue value) => value.IsNil ? null : SquadTopics.TextOf(value.AsHash()) is { } text ? text.AsText() : null;

    /// <summary>
    /// Reads an optional text.
    /// </summary>
    /// <param name="value">The value, nil for none.</param>
    /// <returns>The text, <see langword="null"/> for none.</returns>
    private static string? TextOf(RubyValue value) => value.IsNil ? null : value.AsText();

    /// <summary>
    /// Reads an optional number.
    /// </summary>
    /// <param name="value">The value, nil for none.</param>
    /// <returns>The number, <see langword="null"/> for none.</returns>
    private static int? IntOf(RubyValue value) => value.IsNil ? null : value.AsInt();

    /// <summary>
    /// Writes texts as an Array.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The Array.</returns>
    private static RubyArray Texts(IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));
}
