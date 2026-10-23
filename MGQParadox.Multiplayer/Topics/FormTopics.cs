//----------------------------------------------------------------
//  FormTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Handed out the open forms for the world screen's requests
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Forms;
using MGQOnline.Game.Squads;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the world screen's forms (<see cref="WorldForms"/>): the DLL holds each open
/// form's fields and values, the scripts draw what a view tells and hand over what the player does.
/// </summary>
/// <remarks>
/// A view is <c>title</c>, <c>page</c>, <c>fields</c> (each shown field: <c>key</c>, <c>kind</c>, <c>label</c>, <c>row</c>,
/// <c>side</c>, <c>max_chars</c>, <c>allowed</c>, <c>optional</c>, <c>group</c>, <c>lines</c>, <c>hint</c>, <c>choices</c>,
/// <c>label_width</c>, <c>enabled</c>), <c>values</c>, <c>derived</c> (what the values add up to, see <see cref="WorldFormValues"/>) and
/// <c>sends_on_enter</c> (whether Enter in its text box sends it, see <see cref="WorldForms.SendsOnEnter"/>);
/// it comes only with an action that may change what shows, never per frame.
/// </remarks>
internal sealed class FormTopics
{
    /// <summary>
    /// Opens a form in a slot, replacing the one there: <c>form</c> (the slot, such as "new_world"), <c>kind</c> (see
    /// <see cref="WorldForms"/>) and what that form opens with (<c>name</c>, <c>discord</c>, <c>world</c>, <c>own</c>) in;
    /// the view of its main page out.
    /// </summary>
    public const string Open = "form.open";

    /// <summary>
    /// Hands out a view: <c>form</c> and <c>page</c> in; the view out, nil for a slot without a form.
    /// </summary>
    public const string View = "form.view";

    /// <summary>
    /// Sets what a field holds, such as a text typed or a save picked: <c>form</c>, <c>key</c> and <c>value</c> in;
    /// nothing out, since no rule of the shown fields reads a typed text.
    /// </summary>
    public const string Set = "form.set";

    /// <summary>
    /// Turns a switch: <c>form</c>, <c>page</c>, <c>key</c> and <c>step</c> (1 or -1) in; the page's view out.
    /// </summary>
    public const string Turn = "form.turn";

    /// <summary>
    /// Ticks or unticks a checkbox: <c>form</c>, <c>page</c> and <c>key</c> in; the page's view out.
    /// </summary>
    public const string Tick = "form.tick";

    /// <summary>
    /// Checks a text box's text, on Enter or from the text screen: <c>form</c>, <c>page</c>, <c>key</c>, <c>text</c> and
    /// <c>facts</c> (those that hold now, such as "discord", nil to keep them) in;
    /// [tidied text, why it is refused or nil] out.
    /// </summary>
    public const string Check = "form.check";

    /// <summary>
    /// Sends a page: <c>form</c>, <c>page</c> and <c>facts</c> in; <c>problem</c> ([key, why] of the first field that keeps it from
    /// being sent) out, or once nothing does, the page's view with its text boxes tidied.
    /// </summary>
    public const string Send = "form.send";

    /// <summary>
    /// Forgets a slot's form: <c>form</c> in; nothing out.
    /// </summary>
    public const string Close = "form.close";

    /// <summary>
    /// What a world's settings may be, as the DLL's rules tell them.
    /// </summary>
    internal static readonly WorldFormRules Rules = RulesOfDll();

    /// <summary>
    /// The open forms by slot.
    /// </summary>
    private readonly Dictionary<string, Form> _forms = new(StringComparer.Ordinal);

    /// <summary>
    /// Registers the topics on a context, each context with its own open forms.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The topics, which hand out the open forms.</returns>
    public static FormTopics Register(BridgeContext context)
    {
        FormTopics topics = new();
        context.Register(Open, (_, request) => topics.OpenForm(request.AsHash()));
        context.Register(View, (_, request) => topics.ViewOf(request.AsHash()));
        context.Register(Set, (_, request) => topics.SetValue(request.AsHash()));
        context.Register(Turn, (_, request) => topics.TurnSwitch(request.AsHash()));
        context.Register(Tick, (_, request) => topics.TickBox(request.AsHash()));
        context.Register(Check, (_, request) => topics.CheckText(request.AsHash()));
        context.Register(Send, (_, request) => topics.SendPage(request.AsHash()));
        context.Register(Close, (_, request) =>
        {
            topics._forms.Remove(SlotOf(request.AsHash()));
            return null;
        });
        return topics;
    }

    /// <summary>
    /// Gives the form open in a slot.
    /// </summary>
    /// <param name="slot">The slot, as the scripts name it.</param>
    /// <returns>The form, <see langword="null"/> when none is open there.</returns>
    public Form? FormIn(string slot) => _forms.GetValueOrDefault(slot);

    /// <summary>
    /// Writes a form's page as the scripts draw it.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="page">The page.</param>
    /// <returns>The view.</returns>
    internal static RubyHash ViewOf(Form form, string page)
    {
        RubyHash values = new();
        foreach ((string key, object? value) in form.Values)
        {
            values[key] = ValueOf(value);
        }

        return new RubyHash
        {
            { "title", form.Pages[page].Title },
            { "page", page },
            { "fields", new RubyArray(form.Fields(page).Select(field => (RubyValue)FieldOf(form, field))) },
            { "values", values },
            { "derived", DerivedOf(WorldForms.ValuesOf(form, Rules, page)) },
            { "sends_on_enter", WorldForms.SendsOnEnter(form, page) },
        };
    }

    /// <summary>
    /// Answers <see cref="Open"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The view of the main page.</returns>
    /// <exception cref="BridgeRequestException">The kind is no form's.</exception>
    private RubyHash OpenForm(RubyHash request)
    {
        string kind = request["kind"].AsText();
        Form form = kind switch
        {
            WorldForms.Create => WorldForms.OpenCreate(Rules),
            WorldForms.Edit => WorldForms.OpenEdit(Rules, WorldOf(request["world"].AsHash()), Flag(request, "own")),
            WorldForms.Rename => WorldForms.OpenRename(request["name"].AsText(), Flag(request, "discord")),
            WorldForms.Password => WorldForms.OpenPassword(request["name"].AsText()),
            WorldForms.Join => WorldForms.OpenJoin(),
            _ => throw new BridgeRequestException($"There is no form {kind}."),
        };
        _forms[SlotOf(request)] = form;
        return ViewOf(form, Form.MainPage);
    }

    /// <summary>
    /// Answers <see cref="View"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The view, <see langword="null"/> for a slot without a form.</returns>
    private RubyHash? ViewOf(RubyHash request) =>
        _forms.TryGetValue(SlotOf(request), out Form? form) ? ViewOf(form, PageOf(form, request)) : null;

    /// <summary>
    /// Answers <see cref="Set"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>Nothing.</returns>
    private RubyValue? SetValue(RubyHash request)
    {
        FormOf(request).Set(request["key"].AsText(), PlainOf(request["value"]));
        return null;
    }

    /// <summary>
    /// Answers <see cref="Turn"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The page's view.</returns>
    private RubyHash TurnSwitch(RubyHash request)
    {
        Form form = FormOf(request);
        string page = PageOf(form, request);
        form.Turn(FieldOf(form, page, request), request["step"].AsInt());
        return ViewOf(form, page);
    }

    /// <summary>
    /// Answers <see cref="Tick"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The page's view.</returns>
    private RubyHash TickBox(RubyHash request)
    {
        Form form = FormOf(request);
        string page = PageOf(form, request);
        form.Tick(FieldOf(form, page, request).Key);
        return ViewOf(form, page);
    }

    /// <summary>
    /// Answers <see cref="Check"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The tidied text and why it is refused.</returns>
    private RubyArray CheckText(RubyHash request)
    {
        Form form = FormOf(request);
        (string text, string? reason) = form.Check(FieldOf(form, PageOf(form, request), request), request["text"].AsText());
        return new RubyArray([text, reason]);
    }

    /// <summary>
    /// Answers <see cref="Send"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The problem, or the tidied view.</returns>
    private RubyHash SendPage(RubyHash request)
    {
        Form form = FormOf(request);
        string page = PageOf(form, request);
        if (form.Problem(page) is { } problem)
        {
            return new RubyHash { { "problem", new RubyArray([problem.Field.Key, problem.Reason]) } };
        }

        form.Tidy(page);
        return ViewOf(form, page);
    }

    /// <summary>
    /// Finds the form a request names, and takes the facts it names as those that hold now.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The form.</returns>
    /// <exception cref="BridgeRequestException">The slot holds none.</exception>
    private Form FormOf(RubyHash request)
    {
        Form form = _forms.TryGetValue(SlotOf(request), out Form? found) ? found : throw new BridgeRequestException($"No form is open in {SlotOf(request)}.");
        if (!request["facts"].IsNil)
        {
            form.Know(request["facts"].AsArray().Select(fact => fact.AsText()));
        }

        return form;
    }

    /// <summary>
    /// Reads the slot a request names.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The slot.</returns>
    private static string SlotOf(RubyHash request) => request["form"].AsText();

    /// <summary>
    /// Reads the page a request names.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="request">The request.</param>
    /// <returns>The page, the main one when it names none.</returns>
    /// <exception cref="BridgeRequestException">The form has no such page.</exception>
    private static string PageOf(Form form, RubyHash request)
    {
        string page = request["page"].IsNil ? Form.MainPage : request["page"].AsText();
        return form.Pages.ContainsKey(page) ? page : throw new BridgeRequestException($"The form {form.Kind} has no page {page}.");
    }

    /// <summary>
    /// Finds the shown field a request names.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="page">The page.</param>
    /// <param name="request">The request.</param>
    /// <returns>The field.</returns>
    /// <exception cref="BridgeRequestException">The page shows no such field.</exception>
    private static FormField FieldOf(Form form, string page, RubyHash request)
    {
        string key = request["key"].AsText();
        return form.Field(page, key) ?? throw new BridgeRequestException($"The form {form.Kind} shows no field {key}.");
    }

    /// <summary>
    /// Writes a field as the scripts draw it.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="field">The field.</param>
    /// <returns>The field.</returns>
    private static RubyHash FieldOf(Form form, FormField field) => new()
    {
        { "key", field.Key },
        { "kind", field.Kind.ToString().ToLowerInvariant() },
        { "label", field.Label },
        { "row", field.Row },
        { "side", field.Side == FieldSide.None ? null : field.Side.ToString().ToLowerInvariant() },
        { "max_chars", field.MaxChars is { } most ? most : RubyNil.Value },
        { "allowed", field.Allowed == FieldChars.Any ? null : field.Allowed.ToString().ToLowerInvariant() },
        { "optional", field.Optional },
        { "group", field.Group },
        { "lines", field.Lines },
        { "hint", field.Hint },
        { "choices", new RubyArray(field.Choices.Select(choice => (RubyValue)choice)) },
        { "label_width", field.LabelWidth is { } width ? width : RubyNil.Value },
        { "enabled", form.IsEnabled(field) },
    };

    /// <summary>
    /// Writes what a form's values add up to.
    /// </summary>
    /// <param name="values">The sums.</param>
    /// <returns>The sums.</returns>
    private static RubyHash DerivedOf(WorldFormValues values) => new()
    {
        { "type", values.Type },
        { "share", values.Share },
        { "difficulty", values.Difficulty is { } difficulty ? difficulty : RubyNil.Value },
        { "from_save", values.FromSave },
        { "choose", values.Choose },
        { "raid_bosses", values.RaidBosses },
        { "other_mods_off", values.OtherModsOff },
        { "squad", new RubyHash { { "luka", values.Squad.Luka }, { "formation", values.Squad.Formation }, { "front", values.Squad.Front }, { "raid_front", values.Squad.RaidFront } } },
    };

    /// <summary>
    /// Writes a form's value as a plain value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value.</returns>
    private static RubyValue ValueOf(object? value) => value switch
    {
        string text => text,
        bool flag => flag,
        int number => number,
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Reads a plain value as a form's value.
    /// </summary>
    /// <param name="value">The plain value.</param>
    /// <returns>The value.</returns>
    /// <exception cref="BridgeRequestException">It is no text, flag, whole number or nil.</exception>
    private static object? PlainOf(RubyValue value) => value switch
    {
        RubyNil => null,
        RubyBool flag => flag.Flag,
        RubyInteger => value.AsInt(),
        RubyString => value.AsText(),
        _ => throw new BridgeRequestException("A form's value is a text, true, false, a whole number or nil."),
    };

    /// <summary>
    /// Reads a flag a request may leave out.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="key">The flag.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(RubyHash request, string key) => !request[key].IsNil && request[key].AsBool();

    /// <summary>
    /// Reads the world an edit opens on.
    /// </summary>
    /// <param name="world">The world: <c>name</c>, <c>seats</c>, <c>mods</c>, <c>description</c>, <c>shared</c>, <c>difficulty</c>,
    /// <c>raid</c>, <c>other_mods_off</c>, <c>raid_bosses</c> and <c>squad</c> (as <see cref="WorldTopics.SquadRead"/> answers it, nil for none).</param>
    /// <returns>The world.</returns>
    private static EditedWorld WorldOf(RubyHash world)
    {
        RubyValue squad = world["squad"];
        return new EditedWorld(
            world["name"].AsText(),
            world["seats"].AsInt(),
            world["mods"].IsNil ? "" : world["mods"].AsText(),
            world["description"].IsNil ? "" : world["description"].AsText(),
            Flag(world, "shared"),
            world["difficulty"].IsNil ? null : world["difficulty"].AsInt(),
            Flag(world, "raid"),
            Flag(world, "other_mods_off"),
            Flag(world, "raid_bosses"),
            squad.IsNil ? null : SquadOf(squad.AsHash()));
    }

    /// <summary>
    /// Reads squad rules.
    /// </summary>
    /// <param name="squad">The rules by their names.</param>
    /// <returns>The rules.</returns>
    private static WorldSquad SquadOf(RubyHash squad) =>
        new(squad["luka"].AsBool(), squad["formation"].AsInt(), squad["front"].AsInt(), squad["raid_front"].AsInt());

    /// <summary>
    /// Gathers what a world's settings may be from the DLL's owners of each rule.
    /// </summary>
    /// <returns>The rules.</returns>
    private static WorldFormRules RulesOfDll()
    {
        RaidSquad.TryParse(RaidSquad.Default, out bool luka, out int formation, out int front, out int raidFront);
        return new WorldFormRules(
            WorldCode.MinSeats,
            WorldCode.MaxSeats,
            WorldCode.DefaultSeats,
            [.. Enumerable.Range(WorldDifficulty.Min, WorldDifficulty.Max - WorldDifficulty.Min + 1).Select(value => (value, WorldDifficulty.Names[value - WorldDifficulty.Min]))],
            WorldDifficulty.Default,
            [.. RaidSquad.Formations.Select(size => (size, WorldTopics.FormationName(size)))],
            [.. RaidSquad.Fronts],
            new WorldSquad(luka, formation, front, raidFront));
    }
}
