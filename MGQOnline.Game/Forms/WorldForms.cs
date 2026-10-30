//----------------------------------------------------------------
//  WorldForms.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Dropped Allow data mismatch and Update current data scan, since the game data is compared only as the player enters
//      Paulinchen  2026-10-23: Told whether Enter sends a form
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Forms;

/// <summary>
/// The squad rules of a Raid World, as the forms pick them.
/// </summary>
/// <param name="Luka">Whether Luka may leave the team.</param>
/// <param name="Formation">The team size, 0 for the game's own.</param>
/// <param name="Front">The Frontline's places in regular fights.</param>
/// <param name="RaidFront">The Frontline's places in raids.</param>
public sealed record WorldSquad(bool Luka, int Formation, int Front, int RaidFront);

/// <summary>
/// What a world's settings may be, as the DLL's rules tell them (seats, difficulties, squad rules).
/// </summary>
/// <param name="MinSeats">The fewest seats.</param>
/// <param name="MaxSeats">The most seats.</param>
/// <param name="DefaultSeats">The seats of a new world.</param>
/// <param name="Difficulties">Each difficulty's value and name, in the order the forms offer them.</param>
/// <param name="DefaultDifficulty">The difficulty a new world offers first.</param>
/// <param name="Formations">Each Formation size and its name, in the order the forms offer them.</param>
/// <param name="Fronts">The Frontline's places, in the order the forms offer them.</param>
/// <param name="DefaultSquad">The squad rules of a world that names none.</param>
public sealed record WorldFormRules(
    int MinSeats,
    int MaxSeats,
    int DefaultSeats,
    IReadOnlyList<(int Value, string Name)> Difficulties,
    int DefaultDifficulty,
    IReadOnlyList<(int Size, string Name)> Formations,
    IReadOnlyList<int> Fronts,
    WorldSquad DefaultSquad);

/// <summary>
/// A world as the edit form opens on it.
/// </summary>
/// <param name="Name">Its name.</param>
/// <param name="Seats">Its seats.</param>
/// <param name="Mods">Its mods as written.</param>
/// <param name="Description">Its description.</param>
/// <param name="Shared">Whether it shares its creator's mod settings.</param>
/// <param name="Difficulty">Its difficulty, <see langword="null"/> for a Raid World that sets none.</param>
/// <param name="Raid">Whether it is a Raid World.</param>
/// <param name="OtherModsOff">Whether it turns other mods off.</param>
/// <param name="RaidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
/// <param name="Squad">Its squad rules, <see langword="null"/> for none.</param>
public sealed record EditedWorld(string Name, int Seats, string Mods, string Description, bool Shared, int? Difficulty, bool Raid, bool OtherModsOff, bool RaidBosses, WorldSquad? Squad);

/// <summary>
/// What a world form's values add up to, as the requests to the directory take them.
/// </summary>
/// <param name="Type">"classic" or "raid".</param>
/// <param name="Share">How a Raid World shares companions: "off", "story" or "all"; "off" for a Classic world.</param>
/// <param name="Difficulty">The difficulty, <see langword="null"/> for <see cref="WorldForms.PerPlayer"/>.</param>
/// <param name="Squad">The squad rules.</param>
/// <param name="FromSave">Whether new players start from one of the creator's saves.</param>
/// <param name="Choose">Whether each new player of a Classic world chooses where to start.</param>
/// <param name="RaidBosses">Whether a Classic world's story bosses fight as raid bosses.</param>
/// <param name="OtherModsOff">Whether the world turns off every mod it does not name.</param>
public sealed record WorldFormValues(string Type, string Share, int? Difficulty, WorldSquad Squad, bool FromSave, bool Choose, bool RaidBosses, bool OtherModsOff);

/// <summary>
/// The forms of the world screen: a new world, an edit, the player's name, a world's password, a
/// hidden world's id, and a Raid World's squad rules as a page of the first two.
/// </summary>
public static class WorldForms
{
    /// <summary>The form of a new world.</summary>
    public const string Create = "create";

    /// <summary>The form that changes a world.</summary>
    public const string Edit = "edit";

    /// <summary>The form of the name the others see.</summary>
    public const string Rename = "rename";

    /// <summary>The form of a world's password, which enters it.</summary>
    public const string Password = "password";

    /// <summary>The form that adds a hidden world by its id.</summary>
    public const string Join = "join";

    /// <summary>The page of a Raid World's squad rules.</summary>
    public const string LimitsPage = "limits";

    /// <summary>The fact that Discord told the player's name, so the name form may stay empty.</summary>
    public const string DiscordFact = "discord";

    /// <summary>A Classic world, where each party plays its own story.</summary>
    public const string Classic = "classic";

    /// <summary>A Raid World, where the whole world plays one story.</summary>
    public const string Raid = "raid";

    /// <summary>The edit form's first outcome of the difficulty for a Raid World that sets none.</summary>
    public const string PerPlayer = "Per player";

    /// <summary>The longest name.</summary>
    public const int MaxNameChars = 16;

    /// <summary>The longest password.</summary>
    public const int MaxPasswordChars = 20;

    /// <summary>The longest description.</summary>
    public const int MaxDescriptionChars = 1000;

    /// <summary>The lines of the description a form shows at once.</summary>
    public const int DescriptionLines = 4;

    /// <summary>The lines of the description a Raid World's form shows at once, whose shared save takes a row of its own.</summary>
    public const int RaidDescriptionLines = 2;

    /// <summary>Width of the world type's label, so the switch fits half a row.</summary>
    public const int TypeLabelWidth = 70;

    /// <summary>Width of a Save label that shares its row, so the save's name fits half a row.</summary>
    public const int SaveLabelWidth = 40;

    /// <summary>Width of the squad rules' switch labels, so Original fits half a row.</summary>
    public const int SquadLabelWidth = 80;

    /// <summary>What the lines at the top say on Shared Mod Settings.</summary>
    public const string SharedHint = "Ticked: every player plays with your mod options here. Unticked: each keeps their own.";

    /// <summary>What the lines at the top say on Turn off other mods.</summary>
    public const string OtherModsHint = "Ticked: mods the world does not name are off in it. Personal mods stay on.";

    /// <summary>What the lines at the top say on Turn off other mods in the edit form.</summary>
    public const string EditOtherModsHint = "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again.";

    /// <summary>What the lines at the top say on the world type.</summary>
    public const string TypeHint = "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created.";

    /// <summary>What the lines at the top say on Sharing companions.</summary>
    public const string SharingHint = "Raid only: companions everyone gets on reaching their level. Fixed once created.";

    /// <summary>What the lines at the top say on Raid Bosses.</summary>
    public const string RaidBossesHint = "Classic only: story bosses fight as raid bosses of their tier, far stronger. Changeable later.";

    /// <summary>What the lines at the top say on Raid Bosses in the edit form.</summary>
    public const string EditRaidBossesHint = "Story bosses fight as raid bosses of their tier, far stronger, from each player's next boss fight.";

    /// <summary>What the lines at the top say on the difficulty.</summary>
    public const string DifficultyHint = "Every player of the world plays on it. You can change it later in the edit form.";

    /// <summary>What the lines at the top say on the difficulty in a Raid World's edit form.</summary>
    public const string EditDifficultyHint = "Every player of the world plays on it, those in it now at once.";

    /// <summary>What the button that opens the squad rules says.</summary>
    public const string LimitsLabel = "Set formation limits";

    /// <summary>What the lines at the top say on the button of the squad rules.</summary>
    public const string LimitsHint = "Luka, the team size and the Frontlines every player keeps. Changeable later too.";

    /// <summary>What the lines at the top say on the button that leaves the squad rules.</summary>
    public const string DoneHint = "Back to the world's form. Cancel goes back too, keeping the limits.";

    /// <summary>What the lines at the top say on Luka Replaceable.</summary>
    public const string LukaHint = "Ticked: players may take Luka out of their team. Unticked: he always stays in it.";

    /// <summary>What the lines at the top say on the Formation size.</summary>
    public const string FormationHint = "The team size every player keeps. Its last place sits out, except with Original, the game's own.";

    /// <summary>What the lines at the top say on the Frontline in regular fights.</summary>
    public const string FrontHint = "In front in regular fights, the rest on the Backline. With more players, each one's first fights.";

    /// <summary>What the lines at the top say on the Frontline in raids.</summary>
    public const string RaidFrontHint = "In front in raid boss fights, the rest on the Backline. With more players, each one's first fights.";

    /// <summary>What the lines at the top say on a Raid World's Shared save.</summary>
    public const string RaidSaveHint = "New players start from one of your saves, the world's story from its point. Fixed once created.";

    /// <summary>What the lines at the top say on a world's mods.</summary>
    private const string ModsHint = "The mods of the world: listed, required to enter or essential. Enter picks them.";

    /// <summary>What the lines at the top say on a world's description.</summary>
    private const string DescriptionHint = "Shown in the world's details. Optional.";

    /// <summary>What the lines at the top say on a starting save.</summary>
    private const string SaveHint = "The save every new player starts from.";

    /// <summary>The panel of a world's own settings.</summary>
    private const string WorldGroup = "World";

    /// <summary>The panel of a world's mods and data.</summary>
    private const string DataGroup = "Game data";

    /// <summary>The panel of a world's description.</summary>
    private const string DescriptionGroup = "Description";

    /// <summary>The panel of the squad rules.</summary>
    private const string TeamGroup = "Team";

    /// <summary>The world types, in the order the type switch offers them.</summary>
    private static readonly string[] Types = [Classic, Raid];

    /// <summary>How a Raid World shares companions, in the order its switch offers them.</summary>
    private static readonly string[] Sharing = ["off", "story", "all"];

    /// <summary>What the forms call each way of sharing companions.</summary>
    private static readonly string[] SharingNames = ["Off", "Story companions", "Story + battle recruits"];

    /// <summary>Holds while the type switch picks a Raid World.</summary>
    private static readonly FormRule IsRaid = FormRule.Choice("type", 1);

    /// <summary>Holds while the type switch picks a Classic world.</summary>
    private static readonly FormRule IsClassic = FormRule.Not(IsRaid);

    /// <summary>
    /// Opens the form of a new world, empty but for the defaults.
    /// </summary>
    /// <param name="rules">What a world's settings may be.</param>
    /// <returns>The form.</returns>
    public static Form OpenCreate(WorldFormRules rules)
    {
        FormRule fromSave = FormRule.Ticked("from_save");
        FormField[] fields =
        [
            new("name", FieldKind.Text, "Name", 0, "The name everyone sees in the list.") { MaxChars = MaxNameChars, Group = WorldGroup, EmptyText = "The world needs a name." },
            new("password", FieldKind.Password, "Password", 1, "Typed once to enter the world. Left empty, anyone may enter.") { MaxChars = MaxPasswordChars, Side = FieldSide.Left, Group = WorldGroup },
            Seats(rules, 1, FieldSide.Right),
            new("hidden", FieldKind.Check, "Hidden", 2, "Only its players see it in the list. Others add it with its id.") { Side = FieldSide.Left, Group = WorldGroup },
            new("type", FieldKind.Switch, "World type", 2, TypeHint) { Side = FieldSide.Right, Group = WorldGroup, Choices = ["Classic", "Raid"], LabelWidth = TypeLabelWidth },
            new("share", FieldKind.Switch, "Sharing companions", 3, SharingHint) { Group = WorldGroup, Choices = SharingNames, Shows = IsRaid },
            new("from_save", FieldKind.Check, "Shared save", 3, "Classic only: new players start from one of your saves. Fixed once created.") { Side = FieldSide.Left, Group = WorldGroup, Shows = IsClassic },
            new("choose", FieldKind.Check, "Player's choice", 3, "Classic only: new players pick their start, the opening or a save. Fixed once created.") { Side = FieldSide.Right, Group = WorldGroup, Shows = IsClassic },
            new("save", FieldKind.Save, "Save", 4, SaveHint) { Side = FieldSide.Left, Group = WorldGroup, LabelWidth = SaveLabelWidth, Needs = fromSave, Shows = IsClassic },
            new("raid_bosses", FieldKind.Check, "Raid Bosses", 4, RaidBossesHint) { Side = FieldSide.Right, Group = WorldGroup, Shows = IsClassic },
            new("from_save", FieldKind.Check, "Shared save", 4, RaidSaveHint) { Side = FieldSide.Left, Group = WorldGroup, Shows = IsRaid },
            new("difficulty", FieldKind.Switch, "Difficulty", 4, DifficultyHint) { Side = FieldSide.Right, Group = WorldGroup, Choices = DifficultyNames(rules), LabelWidth = TypeLabelWidth, Shows = IsRaid },
            new("save", FieldKind.Save, "Save", 5, SaveHint) { Side = FieldSide.Left, Group = WorldGroup, LabelWidth = SaveLabelWidth, Needs = fromSave, Shows = IsRaid },
            LimitsButton(5, FieldSide.Right) with { Shows = IsRaid },
            new("mods", FieldKind.Mods, "Mods", 6, ModsHint) { Group = DataGroup },
            new("shared", FieldKind.Check, "Shared Mod Settings", 7, SharedHint) { Group = DataGroup },
            new("other_mods_off", FieldKind.Check, "Turn off other mods", 8, OtherModsHint) { Group = DataGroup, Follows = IsRaid },
            Description(9, DescriptionLines) with { Shows = IsClassic },
            Description(9, RaidDescriptionLines) with { Shows = IsRaid },
            new("confirm", FieldKind.Button, "Create the world", 10, "Creates the world. You enter it from the list."),
        ];
        Dictionary<string, object?> values = new(StringComparer.Ordinal)
        {
            ["name"] = "", ["password"] = "", ["seats"] = rules.DefaultSeats.ToString(CultureInfo.InvariantCulture), ["hidden"] = false, ["type"] = 0, ["share"] = 0,
            ["from_save"] = false, ["save"] = null, ["choose"] = false, ["description"] = "", ["mods"] = "", ["shared"] = false,
            ["difficulty"] = IndexOf(rules.Difficulties.Select(difficulty => difficulty.Value), rules.DefaultDifficulty) is var index and >= 0 ? index : null, ["other_mods_off"] = false, ["raid_bosses"] = false,
        };
        AddSquad(values, rules, rules.DefaultSquad);
        return new Form(Create, PagesOf(rules, "Create a new world", fields), values);
    }

    /// <summary>
    /// Opens the form that changes a world, for its creator or an admin: what may change after it was made.
    /// </summary>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="world">The world, as the form opens on it.</param>
    /// <param name="own">Whether the player made the world, and so may choose whether it shares their mod settings.</param>
    /// <returns>The form, filled in as the world is.</returns>
    public static Form OpenEdit(WorldFormRules rules, EditedWorld world, bool own)
    {
        List<FormField> fields =
        [
            Seats(rules, 0, FieldSide.None),
            new("mods", FieldKind.Mods, "Mods", 2, ModsHint) { Group = DataGroup },
            new("other_mods_off", FieldKind.Check, "Turn off other mods", 5, EditOtherModsHint) { Group = DataGroup },
            Description(6, DescriptionLines),
            new("confirm", FieldKind.Button, "Save the changes", 7, "Changes the world for everyone."),
        ];
        if (own)
        {
            fields.InsertRange(2,
            [
                new("shared", FieldKind.Check, "Shared Mod Settings", 4, SharedHint) { Group = DataGroup },
            ]);
        }

        List<string> choices = world.Difficulty is null ? [PerPlayer, .. DifficultyNames(rules)] : [.. DifficultyNames(rules)];
        if (world.Raid)
        {
            fields.InsertRange(1,
            [
                new("difficulty", FieldKind.Switch, "Difficulty", 1, EditDifficultyHint) { Side = FieldSide.Left, Group = WorldGroup, Choices = choices, LabelWidth = TypeLabelWidth },
                LimitsButton(1, FieldSide.Right),
            ]);
        }
        else
        {
            fields.Insert(1, new("raid_bosses", FieldKind.Check, "Raid Bosses", 1, EditRaidBossesHint) { Group = WorldGroup });
        }

        string? difficultyName = rules.Difficulties.Where(difficulty => difficulty.Value == world.Difficulty).Select(difficulty => difficulty.Name).FirstOrDefault();
        int choice = choices.IndexOf(difficultyName ?? PerPlayer);
        Dictionary<string, object?> values = new(StringComparer.Ordinal)
        {
            ["seats"] = world.Seats.ToString(CultureInfo.InvariantCulture), ["mods"] = world.Mods, ["description"] = world.Description, ["shared"] = world.Shared,
            ["difficulty"] = choice < 0 ? null : choice, ["other_mods_off"] = world.OtherModsOff, ["raid_bosses"] = world.RaidBosses,
        };
        AddSquad(values, rules, world.Squad ?? rules.DefaultSquad);
        return new Form(Edit, PagesOf(rules, "Edit " + world.Name, fields), values);
    }

    /// <summary>
    /// Opens the form of the name the others see.
    /// </summary>
    /// <param name="name">The name as it is, empty for none.</param>
    /// <param name="discord">Whether Discord told the player's name, which the form may then leave empty.</param>
    /// <returns>The form, filled in with the name.</returns>
    public static Form OpenRename(string name, bool discord)
    {
        FormField[] fields =
        [
            new("name", FieldKind.Text, "Your name", 0, "The name the others see. Without one, your name on Discord.")
            {
                MaxChars = MaxNameChars, Group = "Player", EmptyOk = FormRule.Fact(DiscordFact), EmptyText = "Type a name: Discord has not told yours yet.",
            },
            new("confirm", FieldKind.Button, "Use this name", 1, "Keeps the name for every world."),
        ];
        return new Form(Rename, MainOnly("Your name", fields), [new("name", name)], discord ? [DiscordFact] : []);
    }

    /// <summary>
    /// Opens the form of a world's password, which enters it.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <returns>The form, empty.</returns>
    public static Form OpenPassword(string name)
    {
        FormField[] fields =
        [
            new("password", FieldKind.Password, "Password", 0, "The password the world's creator gave you.") { MaxChars = MaxPasswordChars, Group = WorldGroup },
            new("confirm", FieldKind.Button, "Enter the world", 1, "Opens the world with the password."),
        ];
        return new Form(Password, MainOnly("Enter " + name, fields), [new("password", "")]);
    }

    /// <summary>
    /// Opens the form that adds a hidden world to the list by its id.
    /// </summary>
    /// <returns>The form, empty.</returns>
    public static Form OpenJoin()
    {
        FormField[] fields =
        [
            new("id", FieldKind.Id, "World id", 0, "The id the world's creator copied for you. Ctrl+V pastes it.") { MaxChars = Form.IdLength, Allowed = FieldChars.Hex, Group = WorldGroup },
            new("confirm", FieldKind.Button, "Add the world", 1, "Adds the world to your list, where you enter it like any other."),
        ];
        return new Form(Join, MainOnly("Add a hidden world", fields), [new("id", "")]);
    }

    /// <summary>
    /// Tells whether Enter in a page's text box sends it: the name, the password and the id, as long
    /// as that box is the page's only one, so a form that gains another text box is sent from its
    /// button once both are filled in, never half filled in.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="page">The page.</param>
    /// <returns>Whether it does.</returns>
    public static bool SendsOnEnter(Form form, string page = Form.MainPage) =>
        form.Kind is Rename or Password or Join && form.Fields(page).Count(field => field.Typed) == 1;

    /// <summary>
    /// Tells what a world form's values add up to, as a page of it shows them.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="page">The page, whose difficulty switch names the difficulty picked.</param>
    /// <returns>The values.</returns>
    public static WorldFormValues ValuesOf(Form form, WorldFormRules rules, string page = Form.MainPage)
    {
        int typeIndex = form.ChoiceOf("type");
        string type = typeIndex is >= 0 and < 2 ? Types[typeIndex] : Classic;
        bool raid = type == Raid;
        int shareIndex = form.ChoiceOf("share");
        string share = raid && shareIndex is >= 0 and < 3 ? Sharing[shareIndex] : Sharing[0];
        return new WorldFormValues(type, share, DifficultyOf(form, rules, page), SquadOf(form, rules), form.IsTicked("from_save"), !raid && form.IsTicked("choose"),
            !raid && form.IsTicked("raid_bosses"), form.IsTicked("other_mods_off"));
    }

    /// <summary>
    /// Tells the difficulty a page's switch picks.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="page">The page.</param>
    /// <returns>The difficulty; <see langword="null"/> for <see cref="PerPlayer"/>; the default without a switch.</returns>
    private static int? DifficultyOf(Form form, WorldFormRules rules, string page)
    {
        FormField? field = form.Pages[page].Fields.FirstOrDefault(candidate => candidate.Key == "difficulty");
        int index = form.ChoiceOf("difficulty");
        string? name = field is not null && index >= 0 && index < field.Choices.Count ? field.Choices[index] : null;
        foreach ((int value, string difficulty) in rules.Difficulties)
        {
            if (difficulty == name)
            {
                return value;
            }
        }

        return name == PerPlayer ? null : rules.DefaultDifficulty;
    }

    /// <summary>
    /// Tells the squad rules a form picks.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="rules">What a world's settings may be.</param>
    /// <returns>The rules, the default's in place of an index out of range.</returns>
    private static WorldSquad SquadOf(Form form, WorldFormRules rules)
    {
        WorldSquad fallback = rules.DefaultSquad;
        return new WorldSquad(
            form.IsTicked("luka"),
            At(rules.Formations.Select(formation => formation.Size).ToList(), form.ChoiceOf("formation")) ?? fallback.Formation,
            At(rules.Fronts, form.ChoiceOf("front")) ?? fallback.Front,
            At(rules.Fronts, form.ChoiceOf("raid_front")) ?? fallback.RaidFront);
    }

    /// <summary>
    /// Makes the pages of a world form: its own and the squad rules', which share its values.
    /// </summary>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="title">The form's title.</param>
    /// <param name="fields">The form's fields.</param>
    /// <returns>The pages.</returns>
    private static Dictionary<string, FormPage> PagesOf(WorldFormRules rules, string title, IReadOnlyList<FormField> fields)
    {
        IReadOnlyList<string> fronts = rules.Fronts.Select(place => place.ToString(CultureInfo.InvariantCulture)).ToList();
        FormField[] limits =
        [
            new("luka", FieldKind.Check, "Luka Replaceable", 0, LukaHint) { Side = FieldSide.Left, Group = TeamGroup },
            new("formation", FieldKind.Switch, "Formation Size", 0, FormationHint) { Side = FieldSide.Right, Group = TeamGroup, Choices = rules.Formations.Select(formation => formation.Name).ToList(), LabelWidth = SquadLabelWidth },
            new("front", FieldKind.Switch, "Frontline", 1, FrontHint) { Side = FieldSide.Left, Group = TeamGroup, Choices = fronts, LabelWidth = SquadLabelWidth },
            new("raid_front", FieldKind.Switch, "Raid Frontline", 1, RaidFrontHint) { Side = FieldSide.Right, Group = TeamGroup, Choices = fronts, LabelWidth = SquadLabelWidth },
            new("done", FieldKind.Button, "Done", 2, DoneHint),
        ];
        return new Dictionary<string, FormPage>(StringComparer.Ordinal) { [Form.MainPage] = new FormPage(title, fields), [LimitsPage] = new FormPage("Formation limits", limits) };
    }

    /// <summary>
    /// Makes the one page of a form without squad rules.
    /// </summary>
    /// <param name="title">The form's title.</param>
    /// <param name="fields">The form's fields.</param>
    /// <returns>The pages.</returns>
    private static Dictionary<string, FormPage> MainOnly(string title, IReadOnlyList<FormField> fields) =>
        new(StringComparer.Ordinal) { [Form.MainPage] = new FormPage(title, fields) };

    /// <summary>
    /// Makes the box of a world's seats.
    /// </summary>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="row">Its row.</param>
    /// <param name="side">Where it sits on the row.</param>
    /// <returns>The box.</returns>
    private static FormField Seats(WorldFormRules rules, int row, FieldSide side) =>
        new("seats", FieldKind.Number, "Max Players", row, string.Create(CultureInfo.InvariantCulture, $"Players in the world at once, {rules.MinSeats} to {rules.MaxSeats}."))
        {
            MaxChars = rules.MaxSeats.ToString(CultureInfo.InvariantCulture).Length, Allowed = FieldChars.Digits, Side = side, Group = WorldGroup, Min = rules.MinSeats, Max = rules.MaxSeats,
        };

    /// <summary>
    /// Makes the box of a world's description.
    /// </summary>
    /// <param name="row">Its row.</param>
    /// <param name="lines">The lines it shows at once.</param>
    /// <returns>The box.</returns>
    private static FormField Description(int row, int lines) =>
        new("description", FieldKind.Area, "What the world is about", row, DescriptionHint) { MaxChars = MaxDescriptionChars, Optional = true, Lines = lines, Group = DescriptionGroup };

    /// <summary>
    /// Makes the button that opens the page of a Raid World's squad rules.
    /// </summary>
    /// <param name="row">Its row.</param>
    /// <param name="side">Where it sits on the row.</param>
    /// <returns>The button.</returns>
    private static FormField LimitsButton(int row, FieldSide side) =>
        new("limits", FieldKind.Button, LimitsLabel, row, LimitsHint) { Side = side, Group = WorldGroup };

    /// <summary>
    /// Lists the difficulties' names.
    /// </summary>
    /// <param name="rules">What a world's settings may be.</param>
    /// <returns>The names.</returns>
    private static List<string> DifficultyNames(WorldFormRules rules) => rules.Difficulties.Select(difficulty => difficulty.Name).ToList();

    /// <summary>
    /// Adds what the squad rules' fields hold at first for squad rules.
    /// </summary>
    /// <param name="values">The form's values.</param>
    /// <param name="rules">What a world's settings may be.</param>
    /// <param name="squad">The squad rules.</param>
    private static void AddSquad(Dictionary<string, object?> values, WorldFormRules rules, WorldSquad squad)
    {
        values["luka"] = squad.Luka;
        values["formation"] = Math.Max(IndexOf(rules.Formations.Select(formation => formation.Size), squad.Formation), 0);
        values["front"] = Math.Max(IndexOf(rules.Fronts, squad.Front), 0);
        values["raid_front"] = Math.Max(IndexOf(rules.Fronts, squad.RaidFront), 0);
    }

    /// <summary>
    /// Finds a value's index.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <param name="value">The value.</param>
    /// <returns>Its first index, -1 for none.</returns>
    private static int IndexOf(IEnumerable<int> values, int value) => values.ToList().IndexOf(value);

    /// <summary>
    /// Reads a list at an index.
    /// </summary>
    /// <param name="values">The list.</param>
    /// <param name="index">The index.</param>
    /// <returns>The value, <see langword="null"/> out of range.</returns>
    private static int? At(IReadOnlyList<int> values, int index) => index >= 0 && index < values.Count ? values[index] : null;
}
