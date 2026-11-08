//----------------------------------------------------------------
//  WorldScreenModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Listed the details' captions by their column, so each column of captions keeps its own width
//                            - Opened the World panel into the list box with the world's facts alone, the Game data panel with its mods and game data settings alone
//                            - Listed every caption the details can show, so their column keeps one width for every world
//                            - Fitted the details into the worlds screen's fixed box: the type and the player's game in the panels' notes, the Frontline short, every player as a line
//                            - Joined a Raid World's Luka, Formation and Frontline into one Squad line
//                            - Matched the worlds against the list's search and filters
//      Paulinchen  2026-10-30: Told in the details that the game data is compared as the player enters, no longer at the title
//                            - Told a data scan of another format in the details
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// A player of a world, as the directory lists them.
/// </summary>
/// <param name="Id">The player's id.</param>
/// <param name="Name">The player's name.</param>
/// <param name="Online">Whether the player is in the world now.</param>
public sealed record ScreenMember(string Id, string Name, bool Online);

/// <summary>
/// The squad rules a Raid World sets.
/// </summary>
/// <param name="Luka">Whether Luka may leave a team.</param>
/// <param name="Formation">The Formation size.</param>
/// <param name="Front">The Frontline in regular fights.</param>
/// <param name="RaidFront">The Frontline in raids.</param>
public sealed record ScreenSquad(bool Luka, int Formation, int Front, int RaidFront);

/// <summary>
/// A world as the directory lists it, with what the world screen shows of it.
/// </summary>
/// <param name="Id">The world's id.</param>
/// <param name="Name">The world's name.</param>
/// <param name="Seats">How many players it seats at once.</param>
/// <param name="Online">How many are in it now.</param>
/// <param name="CreatorId">The creator's player id.</param>
/// <param name="CreatorName">The creator's name.</param>
/// <param name="Start">How far it is with its starting save: "none", "pending" or "ready".</param>
/// <param name="Hidden">Whether the list leaves it out for everyone but its players.</param>
/// <param name="Choose">Whether each new player chooses where to start.</param>
/// <param name="Open">Whether it has no password.</param>
/// <param name="Featured">Whether it is one of the relay's own worlds.</param>
/// <param name="Strict">Whether its creator asked to keep games with other data out, which no rule reads since a difference is only warned of.</param>
/// <param name="Mods">The mods it needs, as its creator wrote them.</param>
/// <param name="Type">Its type, "classic" or "raid".</param>
/// <param name="Share">How a Raid World shares companions: "off", "story" or "all".</param>
/// <param name="Difficulty">The difficulty a Raid World sets, <see langword="null"/> for none.</param>
/// <param name="OtherModsOff">Whether it turns off every mod it does not name.</param>
/// <param name="Squad">The squad rules a Raid World sets, <see langword="null"/> for none.</param>
/// <param name="RaidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
/// <param name="ModsUnread">Whether its mods are not read yet.</param>
/// <param name="Members">Everyone who ever joined it, in the order shown.</param>
public sealed record ScreenListed(
    string Id,
    string Name,
    int Seats,
    int Online,
    string CreatorId,
    string CreatorName,
    string Start,
    bool Hidden,
    bool Choose,
    bool Open,
    bool Featured,
    bool Strict,
    string Mods,
    string Type,
    string Share,
    int? Difficulty,
    bool OtherModsOff,
    ScreenSquad? Squad,
    bool RaidBosses,
    bool ModsUnread,
    IReadOnlyList<ScreenMember> Members)
{
    /// <summary>
    /// Gets a value indicating whether the world is a Raid World.
    /// </summary>
    public bool Raid => Type == WorldScreenModel.RaidType;
}

/// <summary>
/// A world's folder on this PC, as the world screen shows it.
/// </summary>
/// <param name="Played">The day it was last played (yyyy-MM-dd), <see langword="null"/> before.</param>
/// <param name="LatestSave">Whether it holds a save.</param>
/// <param name="Raid">Whether its world.ini keeps it as a Raid World.</param>
public sealed record ScreenLocal(string? Played, bool LatestSave, bool Raid);

/// <summary>
/// A world as the world screen lists it.
/// </summary>
/// <param name="Id">The directory's id, <see langword="null"/> for a folder whose world.ini names none.</param>
/// <param name="Name">The world's name.</param>
/// <param name="Listed">The world in the directory, <see langword="null"/> while the list lacks it.</param>
/// <param name="Local">Its folder on this PC, <see langword="null"/> before the player entered it.</param>
/// <param name="Favourite">Whether the player marked it as a favourite.</param>
/// <param name="Gone">Whether the directory no longer has it.</param>
public sealed record ScreenEntry(string? Id, string Name, ScreenListed? Listed, ScreenLocal? Local, bool Favourite, bool Gone)
{
    /// <summary>
    /// Gets a value indicating whether the world is a Raid World, by the list or else by world.ini.
    /// </summary>
    public bool Raid => Listed?.Raid ?? Local?.Raid ?? false;

    /// <summary>
    /// Gets a value indicating whether the directory lists the world as featured.
    /// </summary>
    public bool Featured => Listed?.Featured == true;
}

/// <summary>
/// A required mod this game has in another version or lacks, as the mods check tells it.
/// </summary>
/// <param name="Name">The mod's name.</param>
/// <param name="Yours">This game's version, or "not installed".</param>
/// <param name="Text">The check's line, "name: ...".</param>
public sealed record ScreenModRow(string Name, string Yours, string Text);

/// <summary>
/// The rules of a world's settings the details name.
/// </summary>
/// <param name="DifficultyName">Names a difficulty, <see langword="null"/> for an unknown one.</param>
/// <param name="FormationName">Names a Formation size.</param>
/// <param name="DefaultSquad">The squad rules of a Raid World that names none.</param>
public sealed record ScreenRules(Func<int, string?> DifficultyName, Func<int, string> FormationName, ScreenSquad DefaultSquad);

/// <summary>
/// What the details of one world read beyond the world: the player, the game and the mods.
/// </summary>
/// <param name="Me">The player's id.</param>
/// <param name="Admin">Whether the player is one of the relay's admins.</param>
/// <param name="Installed">Tells whether a mod's script is installed.</param>
/// <param name="Rows">The required mods this game has in another version or lacks.</param>
/// <param name="SettingsText">The details' line of the shared mod settings.</param>
/// <param name="SettingsShared">Whether the world shares its creator's mod settings.</param>
/// <param name="TurnedOff">The player's mods the world turns off with their scripts counted; <see langword="null"/> while unknown.</param>
/// <param name="Added">The hidden worlds the player added by their ids.</param>
public sealed record ScreenFacts(
    string Me,
    bool Admin,
    Func<string, bool> Installed,
    IReadOnlyList<ScreenModRow> Rows,
    string SettingsText,
    bool SettingsShared,
    IReadOnlyList<(string Name, int Scripts)>? TurnedOff,
    IReadOnlyCollection<string> Added);

/// <summary>
/// A value of the details on a darker box.
/// </summary>
/// <param name="Label">What it is called, <see langword="null"/> for a box across the cell.</param>
/// <param name="Text">The value, uncut.</param>
/// <param name="Color">"normal", "good", "warn", "gold", "raid" or "bad".</param>
/// <param name="Target">What the cell opens, <see langword="null"/> for nothing.</param>
/// <param name="Chips">Values shown in a box each instead of the text, <see langword="null"/> for the text.</param>
/// <param name="ChipColors">The colour of chips drawn in another than the cell's, by their text, in order.</param>
public sealed record ScreenCell(string? Label, string Text, string Color, string? Target = null, IReadOnlyList<string>? Chips = null, IReadOnlyList<KeyValuePair<string, string>>? ChipColors = null);

/// <summary>
/// A group of the details' rows under a heading.
/// </summary>
/// <param name="Title">The heading.</param>
/// <param name="Note">What the heading says at its right, <see langword="null"/> for nothing.</param>
/// <param name="Rows">The rows, one cell across the panel or two side by side, a missing one <see langword="null"/>.</param>
/// <param name="Target">What the whole panel opens, <see langword="null"/> for nothing.</param>
/// <param name="Lines">Whether its rows are lines of one cell each that show as many as the room holds, beside the description.</param>
public sealed record ScreenPanel(string Title, string? Note, IReadOnlyList<IReadOnlyList<ScreenCell?>> Rows, string? Target = null, bool Lines = false);

/// <summary>
/// A world as the list draws it.
/// </summary>
/// <param name="Text">The name, a favourite's after "* ".</param>
/// <param name="Count">The players online of the seats, such as "2/4"; <see langword="null"/> while the list lacks the world.</param>
/// <param name="Color">"raid", "featured", "favourite" or "normal".</param>
/// <param name="Dim">Whether it is drawn pale, as a world the directory no longer has.</param>
public sealed record ScreenRow(string Text, string? Count, string Color, bool Dim);

/// <summary>
/// One of the choices of a world.
/// </summary>
/// <param name="Label">What it says.</param>
/// <param name="Symbol">Its handler's name.</param>
/// <param name="Enabled">Whether it can be chosen.</param>
public sealed record ScreenAction(string Label, string Symbol, bool Enabled = true);

/// <summary>
/// The search and the filters over the world list.
/// </summary>
/// <param name="Search">The text a world's name must hold, any case; empty for every name.</param>
/// <param name="Type">"all", "raid" or "classic".</param>
/// <param name="Online">Whether only worlds with someone online show.</param>
public sealed record ScreenFilter(string Search, string Type, bool Online)
{
    /// <summary>
    /// Gets the filter that shows every world.
    /// </summary>
    public static ScreenFilter None { get; } = new(string.Empty, WorldScreenModel.AllTypes, false);

    /// <summary>
    /// Gets a value indicating whether the search or a filter hides any world.
    /// </summary>
    public bool Active => Search.Trim().Length > 0 || Type != WorldScreenModel.AllTypes || Online;
}

/// <summary>
/// A line of the list box: a heading, or an item with its colour and what the box says of it.
/// </summary>
/// <param name="Kind">"head" or "item".</param>
/// <param name="Text">What it says.</param>
/// <param name="Color">An item's colour: "good", "grey", "gold", "warn", "bad", or "plain" or "normal" for the plain text colour.</param>
/// <param name="Note">What the box says of an item, <see langword="null"/> for nothing.</param>
public sealed record BoxLine(string Kind, string Text, string? Color = null, string? Note = null);

/// <summary>
/// What the world screen shows of a world and why: its row, its details, its choices and the lines
/// of the list box, as world_screen.rbx showed them.
/// </summary>
public static class WorldScreenModel
{
    /// <summary>
    /// The type of a Raid World, as the directory names it.
    /// </summary>
    public const string RaidType = "raid";

    /// <summary>
    /// The type filter that shows Classic worlds only.
    /// </summary>
    public const string ClassicType = "classic";

    /// <summary>
    /// The type filter that shows every world.
    /// </summary>
    public const string AllTypes = "all";

    /// <summary>
    /// What the list says while the search and the filters hide every world.
    /// </summary>
    public const string NoMatch = "No world matches the search and filters.";

    /// <summary>
    /// What the screen says while nothing else happened.
    /// </summary>
    public const string Hint = "Up and down pick the worlds or the commands, confirm moves into them. Right arrow on a world: its details.";

    /// <summary>
    /// What follows the name of a world just created or added, once the cursor is on it.
    /// </summary>
    public const string EnterHint = "Confirm to enter it.";

    /// <summary>
    /// What the mods check says of a required mod this game lacks.
    /// </summary>
    private const string NotInstalled = "not installed";

    /// <summary>
    /// What the World panel opens: the list box with the world's facts in full.
    /// </summary>
    public const string WorldTarget = "world";

    /// <summary>
    /// What the Game data panel opens: the list box with the world's mods and game data settings in full.
    /// </summary>
    public const string DataTarget = "data";

    /// <summary>
    /// What the details and the list box say of a world's mods while they are read.
    /// </summary>
    private const string ReadingText = "Reading . . .";

    /// <summary>
    /// The details' caption of a world no longer in the list.
    /// </summary>
    private const string StatusCaption = "Status";

    /// <summary>
    /// The details' caption of who made the world.
    /// </summary>
    private const string CreatorCaption = "Creator";

    /// <summary>
    /// The details' caption of the players online.
    /// </summary>
    private const string PlayersCaption = "Players";

    /// <summary>
    /// The details' caption of whether the world needs a password.
    /// </summary>
    private const string PasswordCaption = "Password";

    /// <summary>
    /// The details' caption of whether the world is public or hidden.
    /// </summary>
    private const string ListedCaption = "Listed";

    /// <summary>
    /// The details' caption of how a player starts.
    /// </summary>
    private const string StartCaption = "Start";

    /// <summary>
    /// The details' caption of a Raid World's difficulty.
    /// </summary>
    private const string DifficultyCaption = "Difficulty";

    /// <summary>
    /// The details' caption of how a Raid World shares companions.
    /// </summary>
    private const string SharingCaption = "Sharing";

    /// <summary>
    /// The details' caption of a Raid World's squad rules.
    /// </summary>
    private const string SquadCaption = "Squad";

    /// <summary>
    /// The details' caption of a Classic world's raid bosses.
    /// </summary>
    private const string RaidBossesCaption = "Raid Bosses";

    /// <summary>
    /// The details' caption of the mods the world needs.
    /// </summary>
    private const string ModsCaption = "Mods";

    /// <summary>
    /// Every caption the details can show, by the column of a row it stands in, whose widest sets
    /// that column's caption width for every world.
    /// </summary>
    public static IReadOnlyList<IReadOnlyList<string>> DetailCaptions { get; } =
    [
        [StatusCaption, CreatorCaption, PasswordCaption, StartCaption, SharingCaption, RaidBossesCaption, ModsCaption],
        [PlayersCaption, ListedCaption, DifficultyCaption, SquadCaption],
    ];

    /// <summary>
    /// What the screen says while an action runs, by the action's kind.
    /// </summary>
    public static IReadOnlyList<KeyValuePair<string, string>> BusyTexts { get; } =
    [
        new("create", "Creating the world . . ."),
        new("unlock", "Opening the world . . ."),
        new("delete", "Deleting the world . . ."),
        new("ban", "Removing the player . . ."),
        new("edit", "Saving the changes . . ."),
        new("find", "Looking for the world . . ."),
        new("start", "Fetching the starting save . . ."),
        new("mods", "Downloading the mods . . ."),
        new("settings", "Saving the mod settings . . ."),
        new("read", "Reading the world's mods . . ."),
    ];

    /// <summary>
    /// What the details call each way a Raid World shares companions, short enough for half a row.
    /// </summary>
    private static readonly Dictionary<string, string> SharingTexts = new(StringComparer.Ordinal) { ["off"] = "None", ["story"] = "Story", ["all"] = "Story, recruits" };

    /// <summary>
    /// Writes a world's row of the list.
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <returns>The row.</returns>
    public static ScreenRow RowOf(ScreenEntry entry) => new(
        entry.Favourite ? "* " + entry.Name : entry.Name,
        entry.Listed is { } listed ? $"{listed.Online}/{listed.Seats}" : null,
        entry.Raid ? "raid" : entry.Featured ? "featured" : entry.Favourite ? "favourite" : "normal",
        entry.Gone);

    /// <summary>
    /// Tells whether a world shows under the search and the filters: its name holds the search in any
    /// case, its type is the one asked for, and someone is online in it where that is asked for.
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <param name="filter">The search and the filters.</param>
    /// <returns>Whether it shows.</returns>
    public static bool Shows(ScreenEntry entry, ScreenFilter filter)
    {
        string search = filter.Search.Trim();
        bool named = search.Length == 0 || entry.Name.Contains(search, StringComparison.OrdinalIgnoreCase);
        bool typed = filter.Type switch
        {
            RaidType => entry.Raid,
            ClassicType => !entry.Raid,
            _ => true,
        };
        return named && typed && (!filter.Online || entry.Listed?.Online > 0);
    }

    /// <summary>
    /// Tells what the list says in place of its rows.
    /// </summary>
    /// <param name="total">How many worlds the list holds.</param>
    /// <param name="shown">How many of them show.</param>
    /// <param name="filter">The search and the filters.</param>
    /// <returns><see cref="NoMatch"/> while they hide every world, else <see langword="null"/>.</returns>
    public static string? EmptyText(int total, int shown, ScreenFilter filter) => total > 0 && shown == 0 && filter.Active ? NoMatch : null;

    /// <summary>
    /// Describes the search and the filters for the log.
    /// </summary>
    /// <param name="filter">The search and the filters.</param>
    /// <returns>Such as "search \"sun\", Raid Worlds, someone online", or "no search or filter".</returns>
    public static string FilterText(ScreenFilter filter)
    {
        List<string> parts = [];
        if (filter.Search.Trim().Length > 0)
        {
            parts.Add($"search \"{filter.Search.Trim()}\"");
        }

        if (filter.Type is RaidType or ClassicType)
        {
            parts.Add(filter.Type == RaidType ? "Raid Worlds" : "Classic worlds");
        }

        if (filter.Online)
        {
            parts.Add("someone online");
        }

        return parts.Count == 0 ? "no search or filter" : string.Join(", ", parts);
    }

    /// <summary>
    /// Names the colour of a world's name above its details.
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <returns>"raid", "featured" or "system".</returns>
    public static string TitleColor(ScreenEntry entry) => entry.Raid ? "raid" : entry.Featured ? "featured" : "system";

    /// <summary>
    /// Tells when the player last played a world.
    /// </summary>
    /// <param name="local">The world's folder, <see langword="null"/> before the player entered it.</param>
    /// <returns>The text.</returns>
    public static string PlayedText(ScreenLocal? local) =>
        local == null ? "not entered yet" : local.Played is { } day ? "last played " + day : "entered, not played yet";

    /// <summary>
    /// Tells the list's state in the lines at the top.
    /// </summary>
    /// <param name="state">"idle", "loading", "ready" or "failed".</param>
    /// <param name="error">Why it failed.</param>
    /// <returns>The line, <see langword="null"/> for none.</returns>
    public static string? ListText(string state, string? error) => state switch
    {
        "loading" => "The list is being fetched . . .",
        "failed" => "The list could not be fetched: " + error,
        _ => null,
    };

    /// <summary>
    /// Lists what the details' panels say about a world.
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <param name="rules">The rules the details name.</param>
    /// <returns>The panels, from the top.</returns>
    public static IReadOnlyList<ScreenPanel> Panels(ScreenEntry entry, ScreenFacts facts, ScreenRules rules)
    {
        if (entry.Listed is not { } listed)
        {
            return [new ScreenPanel("World", null, [[new ScreenCell(StatusCaption, entry.Gone ? "Only on this PC: deleted, or you were removed" : "Not in the list right now", "normal")]])];
        }

        return [WorldPanel(entry, listed, facts.Me, rules), DataPanel(listed, facts), PlayersPanel(listed, facts.Me)];
    }

    /// <summary>
    /// Lists what can be done with a world.
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>The choices, Back last.</returns>
    public static IReadOnlyList<ScreenAction> Actions(ScreenEntry entry, ScreenFacts facts)
    {
        ScreenListed? listed = entry.Listed;
        bool creator = listed != null && listed.CreatorId == facts.Me;
        List<ScreenAction> actions = [];
        if (listed != null || entry.Local != null)
        {
            actions.Add(new("Enter the world", "enter"));
        }

        if (entry.Id != null)
        {
            actions.Add(new(entry.Favourite ? "No longer a favourite" : "Mark as a favourite", "favourite"));
        }

        if (creator && listed!.Hidden)
        {
            actions.Add(new("Copy the world id", "copy_id"));
        }

        if (entry.Local == null && entry.Id != null && facts.Added.Contains(entry.Id))
        {
            actions.Add(new("Remove from my list", "forget"));
        }

        if (listed != null && (creator || facts.Admin))
        {
            actions.Add(new("Edit the world", "edit_world"));
        }

        if (creator)
        {
            actions.Add(new("Remove a player", "ban", listed!.Members.Count > 1));
        }

        if (creator || (listed != null && facts.Admin))
        {
            actions.Add(new("Delete the world for everyone", "delete_world"));
        }

        if (entry.Local?.LatestSave == true)
        {
            actions.Add(new("Copy my latest save to my game", "export_save"));
        }

        if (entry.Local != null)
        {
            actions.Add(new("Delete my saves of it", "delete_saves"));
        }

        actions.Add(new("Back", "cancel"));
        return actions;
    }

    /// <summary>
    /// Writes the list box's lines for the facts of a world's World panel, each in full, as
    /// "Caption: value".
    /// </summary>
    /// <param name="entry">The world.</param>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="me">The player's id.</param>
    /// <param name="rules">The rules the details name.</param>
    /// <returns>The lines.</returns>
    public static IReadOnlyList<BoxLine> WorldLines(ScreenEntry entry, ScreenListed listed, string me, ScreenRules rules) =>
        [.. WorldPanel(entry, listed, me, rules).Rows.SelectMany(row => row).OfType<ScreenCell>().Select(cell => new BoxLine("item", $"{cell.Label}: {cell.Text}", cell.Color))];

    /// <summary>
    /// Writes the list box's lines for a world's Game data panel in full: its mods as
    /// <see cref="ModLines"/> writes them, then its shared mod settings and whether it turns other
    /// mods off.
    /// </summary>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>The lines.</returns>
    public static IReadOnlyList<BoxLine> DataLines(ScreenListed listed, ScreenFacts facts) => listed.ModsUnread
        ? [new("head", ModsCaption), new("item", ReadingText, "plain")]
        : [.. ModLines(listed, facts), new("head", "Settings"), new("item", facts.SettingsText, facts.SettingsShared ? "gold" : "plain"),
           new("item", OtherModsText(listed, facts), listed.OtherModsOff ? "warn" : "plain")];

    /// <summary>
    /// Writes the list box's lines for a world's players: those online, then the others.
    /// </summary>
    /// <param name="members">Everyone who ever joined.</param>
    /// <param name="me">The player's id.</param>
    /// <returns>The lines.</returns>
    public static IReadOnlyList<BoxLine> PlayerLines(IReadOnlyList<ScreenMember> members, string me)
    {
        List<BoxLine> lines = [];
        foreach ((string heading, bool online, string color) in new[] { ("Online", true, "good"), ("Offline", false, "grey") })
        {
            List<ScreenMember> group = [.. members.Where(member => member.Online == online)];
            if (group.Count == 0)
            {
                continue;
            }

            lines.Add(new("head", $"{heading} ({group.Count})"));
            lines.AddRange(group.Select(member => new BoxLine("item", NameOf(member, me), color, heading.ToLowerInvariant())));
        }

        return lines;
    }

    /// <summary>
    /// Writes the list box's lines for the mods a world needs, each marked as <see cref="ModMarks"/>
    /// says, and the player's mods it turns off.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>The lines.</returns>
    public static IReadOnlyList<BoxLine> ModLines(ScreenListed listed, ScreenFacts facts)
    {
        IReadOnlyList<string> mods = ModsText.Names(listed.Mods);
        List<KeyValuePair<string, (string Color, string Note)>> marks = ModMarks(listed.Mods, facts);
        List<BoxLine> lines = [new("head", $"Mods ({mods.Count})")];
        foreach (string mod in mods)
        {
            int at = marks.FindIndex(mark => mark.Key == mod);
            lines.Add(at < 0 ? new BoxLine("item", mod, "plain") : new BoxLine("item", mod, marks[at].Value.Color, marks[at].Value.Note));
        }

        IReadOnlyList<(string Name, int Scripts)>? off = listed.OtherModsOff ? facts.TurnedOff : null;
        if (off == null || off.Count == 0)
        {
            return lines;
        }

        lines.Add(new("head", $"Your mods turned off here ({off.Count})"));
        lines.AddRange(off.Select(mod => new BoxLine("item", mod.Name, "grey", "yours, turned off here")));
        return lines;
    }

    /// <summary>
    /// Tells how a world's marked mods are marked: a required one good while this game has it in the
    /// world's version, gold in another and bad while it lacks it; an essential one gold, since the
    /// game data is compared only as the player enters.
    /// </summary>
    /// <remarks>
    /// A mod marked twice keeps its first place with its last mark, as a Ruby Hash did.
    /// </remarks>
    /// <param name="text">The mods as written.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>Each marked mod's colour and note, by name, in order.</returns>
    public static List<KeyValuePair<string, (string Color, string Note)>> ModMarks(string text, ScreenFacts facts)
    {
        List<KeyValuePair<string, (string Color, string Note)>> marks = [];
        void Mark(string mod, (string Color, string Note) mark)
        {
            int at = marks.FindIndex(entry => entry.Key == mod);
            if (at < 0)
            {
                marks.Add(new(mod, mark));
            }
            else
            {
                marks[at] = new(mod, mark);
            }
        }

        foreach (string mod in ModsText.Required(text))
        {
            ScreenModRow? row = facts.Rows.FirstOrDefault(candidate => candidate.Name == mod);
            Mark(mod, row != null && row.Yours != NotInstalled ? ("gold", "required, " + WithoutName(row.Text))
                : facts.Installed(mod) ? ("good", "required, installed") : ("bad", "required, missing"));
        }

        foreach (string mod in ModsText.Essential(text))
        {
            Mark(mod, ("gold", "essential, checked as you enter"));
        }

        return marks;
    }

    /// <summary>
    /// Tells who made a world, how full it is, how it is entered and where its players start, and
    /// for a Raid World its sharing, difficulty and squad rules, its type in the note.
    /// </summary>
    /// <remarks>
    /// The details have a fixed box, so a Raid World's facts go two to a row, its squad rules in one
    /// cell, and a Classic world gets a raid bosses row only while they are on.
    /// </remarks>
    /// <param name="entry">The world.</param>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="me">The player's id.</param>
    /// <param name="rules">The rules the details name.</param>
    /// <returns>The panel.</returns>
    private static ScreenPanel WorldPanel(ScreenEntry entry, ScreenListed listed, string me, ScreenRules rules)
    {
        List<IReadOnlyList<ScreenCell?>> rows =
        [
            [new ScreenCell(CreatorCaption, listed.CreatorId == me ? "You" : listed.CreatorName, "normal"), new ScreenCell(PlayersCaption, $"{listed.Online} / {listed.Seats} online", "normal")],
            [new ScreenCell(PasswordCaption, listed.Open ? "None" : entry.Local != null ? "Known" : "Needed", "normal"), new ScreenCell(ListedCaption, listed.Hidden ? "Hidden" : "Public", "normal")],
        ];
        if (listed.Raid)
        {
            string? difficulty = listed.Difficulty is { } value ? rules.DifficultyName(value) : null;
            rows.Add([new ScreenCell(StartCaption, RaidStartText(listed), "normal"), new ScreenCell(DifficultyCaption, difficulty ?? "Per player", "normal")]);
            ScreenSquad squad = listed.Squad ?? rules.DefaultSquad;
            rows.Add([new ScreenCell(SharingCaption, SharingTexts.GetValueOrDefault(listed.Share) ?? SharingTexts["off"], "normal"), new ScreenCell(SquadCaption, SquadText(squad, rules), "normal")]);
        }
        else
        {
            rows.Add([new ScreenCell(StartCaption, StartText(listed), "normal")]);
            if (listed.RaidBosses)
            {
                rows.Add([new ScreenCell(RaidBossesCaption, "On: story bosses of their tier", "normal")]);
            }
        }

        string? note = (listed.Raid, listed.Featured) switch
        {
            (true, true) => "Raid World, featured",
            (true, false) => "Raid World",
            (false, true) => "featured",
            _ => null,
        };
        return new ScreenPanel("World", note, rows, WorldTarget);
    }

    /// <summary>
    /// Sums up a Raid World's squad rules in one short line for half a row of the details.
    /// </summary>
    /// <param name="squad">The squad rules.</param>
    /// <param name="rules">The rules the details name.</param>
    /// <returns>Such as "4, front 1, Luka fixed" or "6, front 3, raids 4, Luka optional"; the raids' frontline only where it differs.</returns>
    private static string SquadText(ScreenSquad squad, ScreenRules rules)
    {
        string raids = squad.RaidFront == squad.Front ? "" : $", raids {squad.RaidFront}";
        return $"{rules.FormationName(squad.Formation)}, front {squad.Front}{raids}, Luka {(squad.Luka ? "optional" : "fixed")}";
    }

    /// <summary>
    /// Tells the mods a world needs, its mod settings and whether it turns other mods off, its note
    /// that the player's game data is compared with its creator's as they enter.
    /// </summary>
    /// <remarks>
    /// The title has loaded none of the world's mods, so a comparison there would name the entries
    /// they add as differences.
    /// </remarks>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>The panel.</returns>
    private static ScreenPanel DataPanel(ScreenListed listed, ScreenFacts facts)
    {
        IReadOnlyList<string> mods = ModsText.Names(listed.Mods);
        string note = listed.CreatorId == facts.Me ? "becomes the world's as you enter" : "compared with the creator's as you enter";
        if (listed.ModsUnread)
        {
            return new ScreenPanel("Game data", note, [[new ScreenCell(ModsCaption, ReadingText, "normal")]], DataTarget);
        }

        List<KeyValuePair<string, string>> colors = [.. ModMarks(listed.Mods, facts).Select(mark => new KeyValuePair<string, string>(mark.Key, mark.Value.Color))];
        ScreenCell modsCell = mods.Count == 0
            ? new ScreenCell(ModsCaption, "No mod named", "normal", null, null, colors)
            : new ScreenCell(ModsCaption, string.Join(", ", mods), "normal", "mods", mods, colors);
        ScreenCell settings = new(null, facts.SettingsText, facts.SettingsShared ? "gold" : "normal");
        ScreenCell otherMods = new(null, OtherModsText(listed, facts), listed.OtherModsOff ? "warn" : "normal");
        return new ScreenPanel("Game data", note, [[modsCell], [settings], [otherMods]], DataTarget);
    }

    /// <summary>
    /// Tells whether a world turns other mods off, and how many of the player's.
    /// </summary>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="facts">What the details read beyond the world.</param>
    /// <returns>Such as "Other mods: turned off (2 of yours)" or "Other mods: allowed".</returns>
    private static string OtherModsText(ScreenListed listed, ScreenFacts facts) =>
        !listed.OtherModsOff ? "Other mods: allowed"
            : facts.TurnedOff == null || facts.TurnedOff.Count == 0 ? "Other mods: turned off"
            : $"Other mods: turned off ({facts.TurnedOff.Count} of yours)";

    /// <summary>
    /// Names every player of a world, those online first as listed, one to a line.
    /// </summary>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="me">The player's id.</param>
    /// <returns>The panel.</returns>
    private static ScreenPanel PlayersPanel(ScreenListed listed, string me)
    {
        IReadOnlyList<ScreenMember> members = listed.Members;
        List<IReadOnlyList<ScreenCell?>> rows = [.. members.Select(member => (IReadOnlyList<ScreenCell?>)[new ScreenCell(null, NameOf(member, me), member.Online ? "good" : "normal")])];
        return new ScreenPanel("Players", $"{members.Count} joined", rows, "players", Lines: true);
    }

    /// <summary>
    /// Tells where a Raid World's new players start: at the beginning, or from the creator's save.
    /// </summary>
    /// <param name="listed">The Raid World.</param>
    /// <returns>The text.</returns>
    private static string RaidStartText(ScreenListed listed) =>
        listed.Start == "pending" ? StartText(listed) : listed.Start == "ready" ? "The creator's save" : "The beginning";

    /// <summary>
    /// Tells where a world's new players start.
    /// </summary>
    /// <param name="listed">The world.</param>
    /// <returns>The text.</returns>
    private static string StartText(ScreenListed listed) => (listed.Start, listed.Choose) switch
    {
        ("pending", _) => "Its creator is still setting it up",
        ("ready", true) => "Your choice: beginning, own or creator's save",
        (_, true) => "Your choice: beginning or own save",
        ("ready", false) => "The creator's save",
        _ => "The beginning",
    };

    /// <summary>
    /// Names a player, the player themselves marked.
    /// </summary>
    /// <param name="member">The player.</param>
    /// <param name="me">The player's own id.</param>
    /// <returns>The name.</returns>
    private static string NameOf(ScreenMember member, string me) => member.Id == me ? member.Name + " (you)" : member.Name;

    /// <summary>
    /// Takes the mod's name off a line of the mods check.
    /// </summary>
    /// <param name="text">The line, "name: ...".</param>
    /// <returns>What follows the first ": " after the name; the line itself without one.</returns>
    private static string WithoutName(string text)
    {
        int colon = text.IndexOf(':', StringComparison.Ordinal);
        return colon >= 0 && colon + 1 < text.Length && text[colon + 1] == ' ' ? text[(colon + 2)..] : text;
    }
}
