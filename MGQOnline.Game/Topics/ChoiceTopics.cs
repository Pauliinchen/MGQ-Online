//----------------------------------------------------------------
//  ChoiceTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Answered a choice's own keys without the Navy's self switches, which the reviewed key list keeps
//      Paulinchen  2026-11-01: Dropped the steps on a question, which the framework's list and number field take
//                            - Handed a question's key line as entries
//                            - Told the scripts the companions an outcome sends away
//      Paulinchen  2026-10-31: Added the questions a replay asks on the decision screen
//                            - Read where the stream that hands the player runs began
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the story's choices (<see cref="StoryChoices"/>), which both hosts answer
/// through <see cref="SharedTopics"/>, since coop_choices.rbx loads on the battle server too.
/// Every request that reads a story carries its values as <c>values</c>: <c>s</c> (the switches
/// of <see cref="ChoiceTable.ReadSwitches"/> that are on), <c>v</c> ([id, value] of each of
/// <see cref="ChoiceTable.ReadVariables"/>) and <c>roster</c> (the companions of
/// <see cref="ChoiceTable.ReadRoster"/> in the roster); one that reads the game beside carries
/// <c>raid</c>, <c>ends</c> ([ed1, ed2]), <c>raid_route</c> and <c>world_routes</c> too. One that
/// lists or applies choices carries <c>start</c>, where the stream that hands the player runs began
/// ([markers], nil for none), since the replay asks every choice whose run a stream hands over.
/// </summary>
public static class ChoiceTopics
{
    /// <summary>
    /// Lists the choices a catch-up carries the player past: <c>from</c>, <c>to</c>, <c>values</c>
    /// and <c>start</c> in; the keys out, in story order.
    /// </summary>
    public const string Passed = "choices.passed";

    /// <summary>
    /// Lists the choices a story passing on asks the player's own outcome of: <c>from</c>, <c>to</c>,
    /// <c>changed</c> (the ids that changed besides), <c>raid</c>, <c>values</c>, <c>waiting</c>
    /// (the keys asked already) and <c>start</c> in; the keys to ask out.
    /// </summary>
    public const string Prompts = "choices.prompts";

    /// <summary>
    /// Lists the choices a later build added that a Raid World's story is past without the save's
    /// own outcome: <c>progress</c>, <c>raid</c>, <c>values</c>, <c>waiting</c> and <c>start</c> in;
    /// the keys out.
    /// </summary>
    public const string Missed = "choices.missed";

    /// <summary>
    /// Lists the outcomes the screen offers for a choice: the game and <c>key</c> in; <c>labels</c>
    /// and <c>outcomes</c> (each label's place in the choice's outcomes) out.
    /// </summary>
    public const string Offered = "choices.offered";

    /// <summary>
    /// Reports whether both endings are cleared, which the third way of the Great Decision asks: the
    /// game in; true or false out.
    /// </summary>
    public const string Endings = "choices.endings";

    /// <summary>
    /// Writes the line of what an outcome brings: the game, <c>key</c>, <c>index</c>,
    /// <c>answers</c> (key to outcome), <c>route</c> (the leader's, or nil) and <c>leader</c> (the
    /// leader's name) in; the line out.
    /// </summary>
    public const string Note = "choices.note";

    /// <summary>
    /// Finds what an outcome sets, brings and sends away: the game, <c>start</c>, <c>key</c>, <c>index</c> and
    /// <c>answers</c> in; for the side <c>side</c> ("alice" or "ilias"), else <c>title</c>, <c>label</c>,
    /// <c>switches</c> ([id, on]), <c>variables</c> and <c>least</c> ([id, value]),
    /// <c>self_switches</c> ([map, event, letter]), <c>joins</c>, <c>leaves</c> and <c>ship</c> ([map, x, y] or nil) out.
    /// </summary>
    public const string Outcome = "choices.outcome";

    /// <summary>
    /// Lists the keys that are the player's own as choices' outcomes: <c>raid</c> and <c>own</c>
    /// (the member's own story's values, nil while they play their own) in; <c>s</c> and <c>v</c>
    /// out.
    /// </summary>
    public const string Personal = "choices.personal";

    /// <summary>
    /// Tells why the catch-up leaves out a reward: <c>kind</c> and <c>id</c> in; the reason or nil out.
    /// </summary>
    public const string Skip = "choices.skip";

    /// <summary>
    /// Tells why a leader may not offer a member to sync their story: <c>name</c>, <c>theirs</c>
    /// (their progress, or nil), <c>own</c> and <c>follows</c> in; the reason or nil out.
    /// </summary>
    public const string OfferRefusal = "choices.offer_refusal";

    /// <summary>
    /// Lists the leader's offers that ran out: <c>now</c> and <c>since</c> ([member, frame] each) in;
    /// the members out.
    /// </summary>
    public const string Lapsed = "choices.lapsed";

    /// <summary>
    /// Hands out what the scripts read of the table: nothing in; <c>branches</c> ([key, title,
    /// point, hint] each), <c>reads</c> (<c>s</c>, <c>v</c>, <c>roster</c>), <c>great_decision</c>,
    /// <c>routes</c>, <c>chaos_start</c>, <c>decision</c> (each outcome's <c>side</c>, <c>return</c>
    /// and <c>map</c>, empty for the third way) and <c>offer_frames</c> out.
    /// </summary>
    public const string Table = "choices.table";

    /// <summary>
    /// Opens a question a replay asks, see <see cref="ChoiceInputs"/>: <c>kind</c> ("choice",
    /// "number", "item" or "present"), <c>opener</c> (nil for the player's own history),
    /// <c>companion</c> (a present's) and <c>spec</c> in. The spec holds per kind <c>labels</c> and
    /// <c>cancel</c> (a choice's), <c>digits</c> and <c>value</c> (a number's), <c>items</c> ([id,
    /// name, count, description] each, an item's and a present's), <c>result</c> (a present's, empty
    /// for the first) and <c>index</c> (the row a list starts on). The question out: <c>kind</c>,
    /// <c>title</c>, <c>keys</c> ([key, text] each, the key "cancel" for the game's cancel button),
    /// <c>hint</c>, <c>rows</c> ([answer, name, count or nil, hint, cancel] each), <c>digits</c>,
    /// <c>value</c>, <c>index</c> and <c>cancel</c> (what cancel answers, nil to answer later).
    /// </summary>
    public const string InputOpen = "choices.input_open";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Passed, (_, request) => PassedOf(request.AsHash()));
        context.Register(Prompts, (_, request) => PromptsOf(request.AsHash()));
        context.Register(Missed, (_, request) => MissedOf(request.AsHash()));
        context.Register(Offered, (_, request) => OfferedOf(request.AsHash()));
        context.Register(Endings, (_, request) => StoryChoices.BothEndings(ContextOf(request.AsHash())));
        context.Register(Note, (_, request) => NoteOf(request.AsHash()));
        context.Register(Outcome, (_, request) => OutcomeOf(request.AsHash()));
        context.Register(Personal, (_, request) => PersonalOf(request.AsHash()));
        context.Register(Skip, (_, request) => SkipOf(request.AsHash()));
        context.Register(OfferRefusal, (_, request) => OfferRefusalOf(request.AsHash()));
        context.Register(Lapsed, (_, request) => LapsedOf(request.AsHash()));
        context.Register(Table, (_, _) => TableOf());
        context.Register(InputOpen, (_, request) => InputText(InputOf(request.AsHash())));
    }

    /// <summary>
    /// Answers <see cref="InputOpen"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The question.</returns>
    /// <exception cref="BridgeRequestException">The kind names no input.</exception>
    private static ChoiceInput InputOf(RubyHash request)
    {
        RubyHash spec = request["spec"].AsHash();
        string? opener = request["opener"].IsNil ? null : request["opener"].AsText();
        int index = spec["index"].AsInt();
        return request["kind"].AsText() switch
        {
            "choice" => ChoiceInputs.Choice(opener, TextsOf(spec["labels"]), spec["cancel"].IsNil ? null : spec["cancel"].AsInt(), index),
            "number" => ChoiceInputs.Number(opener, spec["digits"].AsInt(), spec["value"].AsLong()),
            "item" => ChoiceInputs.Item(opener, ItemsOf(spec["items"]), index),
            "present" => ChoiceInputs.Present(request["companion"].AsText(), ItemsOf(spec["items"]), spec["result"].AsText(), index),
            string kind => throw new BridgeRequestException($"{kind} is no input a replay asks."),
        };
    }

    /// <summary>
    /// Reads the items of a question.
    /// </summary>
    /// <param name="list">[id, name, count, description] each.</param>
    /// <returns>The items.</returns>
    private static List<ChoiceInputItem> ItemsOf(RubyValue list) =>
        [.. list.AsArray().Select(item => item.AsArray()).Select(item => new ChoiceInputItem(item[0].AsInt(), item[1].AsText(), item[2].AsInt(), item[3].AsText()))];

    /// <summary>
    /// Writes a question as the scripts hold it.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <returns>The question.</returns>
    private static RubyHash InputText(ChoiceInput input)
    {
        var rows = new RubyArray(input.Rows.Select(row =>
            (RubyValue)new RubyArray { row.Answer, row.Name, row.Count is { } count ? count : RubyNil.Value, row.Hint, row.Cancel }));
        return new RubyHash
        {
            { "kind", input.Kind.ToString().ToLowerInvariant() },
            { "title", input.Title },
            { "keys", new RubyArray(input.Keys.Select(key => (RubyValue)new RubyArray { key.Key, key.Text })) },
            { "hint", input.Hint },
            { "rows", rows },
            { "digits", input.Digits },
            { "value", input.Value },
            { "index", input.Index },
            { "cancel", input.CancelAnswer is { } cancel ? cancel : RubyNil.Value },
        };
    }

    /// <summary>
    /// Answers <see cref="Passed"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The keys.</returns>
    private static RubyArray PassedOf(RubyHash request) =>
        Texts(StoryChoices.Passed(request["from"].AsInt(), request["to"].AsInt(), ValuesOf(request["values"].AsHash()), ReplayEntry.PlaceOf(request["start"])));

    /// <summary>
    /// Answers <see cref="Prompts"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The keys to ask.</returns>
    private static RubyArray PromptsOf(RubyHash request) =>
        Texts(StoryChoices.Prompts(request["from"].AsInt(), request["to"].AsInt(), Ints(request["changed"]).ToHashSet(), request["raid"].AsBool(),
            ValuesOf(request["values"].AsHash()), TextsOf(request["waiting"]).ToHashSet(StringComparer.Ordinal), ReplayEntry.PlaceOf(request["start"])));

    /// <summary>
    /// Answers <see cref="Missed"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The keys to ask.</returns>
    private static RubyArray MissedOf(RubyHash request) =>
        Texts(StoryChoices.Missed(request["progress"].AsInt(), request["raid"].AsBool(), ValuesOf(request["values"].AsHash()), TextsOf(request["waiting"]).ToHashSet(StringComparer.Ordinal),
            ReplayEntry.PlaceOf(request["start"])));

    /// <summary>
    /// Answers <see cref="Offered"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The labels and the outcomes.</returns>
    private static RubyHash OfferedOf(RubyHash request)
    {
        (IReadOnlyList<string> labels, IReadOnlyList<int> outcomes) = StoryChoices.Offered(KeyOf(request), ContextOf(request));
        return new RubyHash { { "labels", Texts(labels) }, { "outcomes", new RubyArray(outcomes.Select(index => (RubyValue)index)) } };
    }

    /// <summary>
    /// Answers <see cref="Note"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The line.</returns>
    private static RubyValue NoteOf(RubyHash request) =>
        StoryChoices.Note(KeyOf(request), request["index"].AsInt(), AnswersOf(request["answers"]), request["route"].IsNil ? null : request["route"].AsInt(),
            request["leader"].AsText(), ContextOf(request));

    /// <summary>
    /// Answers <see cref="Outcome"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The writes, or the side chosen.</returns>
    private static RubyHash OutcomeOf(RubyHash request)
    {
        string key = KeyOf(request);
        int index = request["index"].AsInt();
        if (key == ChoiceTable.Side)
        {
            return new RubyHash { { "side", index == 0 ? "alice" : "ilias" } };
        }

        ChoiceWrites writes = StoryChoices.Outcome(key, index, AnswersOf(request["answers"]), ContextOf(request));
        return new RubyHash
        {
            { "title", writes.Title },
            { "label", writes.Label },
            { "switches", new RubyArray(writes.Switches.Select(pair => (RubyValue)new RubyArray { pair.Key, pair.Value })) },
            { "variables", Pairs(writes.Variables) },
            { "least", Pairs(writes.Least) },
            { "self_switches", SelfSwitches(writes.SelfSwitches) },
            { "joins", new RubyArray(writes.Joins.Select(id => (RubyValue)id)) },
            { "leaves", new RubyArray(writes.Leaves.Select(id => (RubyValue)id)) },
            { "ship", writes.Ship is { } ship ? new RubyArray { ship.Map, ship.X, ship.Y } : RubyNil.Value },
        };
    }

    /// <summary>
    /// Answers <see cref="Personal"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The keys.</returns>
    private static RubyHash PersonalOf(RubyHash request)
    {
        PersonalChoiceKeys keys = StoryChoices.Personal(request["raid"].AsBool(), request["own"].IsNil ? null : ValuesOf(request["own"].AsHash()));
        return new RubyHash
        {
            { "s", new RubyArray(keys.Switches.Select(id => (RubyValue)id)) },
            { "v", new RubyArray(keys.Variables.Select(id => (RubyValue)id)) },
        };
    }

    /// <summary>
    /// Answers <see cref="Skip"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The reason, nil to give the reward.</returns>
    private static RubyValue SkipOf(RubyHash request) =>
        request["id"] is RubyInteger id && StoryChoices.SkipReason(request["kind"].AsText(), id.Value >= int.MinValue && id.Value <= int.MaxValue ? (int)id.Value : -1) is { } reason
            ? reason
            : RubyNil.Value;

    /// <summary>
    /// Answers <see cref="OfferRefusal"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The reason, nil when an offer is possible.</returns>
    private static RubyValue OfferRefusalOf(RubyHash request) =>
        StoryChoices.OfferRefusal(request["name"].AsText(), request["theirs"].IsNil ? null : Ints(request["theirs"]), Ints(request["own"]), request["follows"].AsBool()) is { } reason
            ? reason
            : RubyNil.Value;

    /// <summary>
    /// Answers <see cref="Lapsed"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The members whose offers ran out.</returns>
    private static RubyArray LapsedOf(RubyHash request)
    {
        List<KeyValuePair<string, long>> offers = [.. request["since"].AsArray().Select(entry => new KeyValuePair<string, long>(entry.AsArray()[0].AsText(), entry.AsArray()[1].AsLong()))];
        return Texts(StoryChoices.Lapsed(request["now"].AsLong(), offers));
    }

    /// <summary>
    /// Answers <see cref="Table"/>.
    /// </summary>
    /// <returns>What the scripts read of the table.</returns>
    private static RubyHash TableOf()
    {
        var branches = new RubyArray(ChoiceTable.Branches.Select(branch => (RubyValue)new RubyArray { branch.Key, branch.Title, branch.Point, branch.Hint }));
        var decision = new RubyArray(ChoiceTable.Branch(ChoiceTable.Decision)!.Outcomes.Select(outcome => outcome.Decision is { Return: { } back, Side: { } side, Map: { } map }
            ? (RubyValue)new RubyHash { { "side", side }, { "return", back }, { "map", map } }
            : new RubyHash()));
        return new RubyHash
        {
            { "branches", branches },
            { "reads", new RubyHash { { "s", Ints(ChoiceTable.ReadSwitches) }, { "v", Ints(ChoiceTable.ReadVariables) }, { "roster", Ints(ChoiceTable.ReadRoster) } } },
            { "great_decision", ChoiceTable.GreatDecision },
            { "routes", Ints(ChoiceTable.Routes) },
            { "chaos_start", Ints(ChoiceTable.ChaosStart) },
            { "decision", decision },
            { "offer_frames", ChoiceTable.OfferFrames },
        };
    }

    /// <summary>
    /// Reads a request's choice.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The key.</returns>
    /// <exception cref="BridgeRequestException">The key names no choice.</exception>
    private static string KeyOf(RubyHash request)
    {
        string key = request["key"].AsText();
        return ChoiceTable.Branch(key) is null ? throw new BridgeRequestException($"{key} is no choice of the story.") : key;
    }

    /// <summary>
    /// Reads the game a request carries.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The game.</returns>
    private static ChoiceContext ContextOf(RubyHash request)
    {
        RubyArray ends = request["ends"].AsArray();
        return new ChoiceContext(request["raid"].AsBool(), ValuesOf(request["values"].AsHash()), ends[0].AsBool(), ends[1].AsBool(),
            request["raid_route"].IsNil ? null : request["raid_route"].AsInt(), request["world_routes"].IsNil ? null : Ints(request["world_routes"]), ReplayEntry.PlaceOf(request["start"]));
    }

    /// <summary>
    /// Reads a story's values as a request carries them.
    /// </summary>
    /// <param name="values">The values: <c>s</c>, <c>v</c> and <c>roster</c>.</param>
    /// <returns>The values.</returns>
    private static ChoiceValues ValuesOf(RubyHash values)
    {
        var variables = new Dictionary<int, int>();
        foreach (RubyValue pair in values["v"].AsArray())
        {
            RubyArray entry = pair.AsArray();
            variables[entry[0].AsInt()] = entry[1].AsInt();
        }

        return new ChoiceValues(Ints(values["s"]).ToHashSet(), variables, Ints(values["roster"]).ToHashSet());
    }

    /// <summary>
    /// Reads the answers given so far.
    /// </summary>
    /// <param name="answers">The answers, each choice's outcome.</param>
    /// <returns>The answers.</returns>
    private static Dictionary<string, int> AnswersOf(RubyValue answers)
    {
        var read = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (KeyValuePair<RubyValue, RubyValue> pair in answers.AsHash())
        {
            read[pair.Key.AsText()] = pair.Value.AsInt();
        }

        return read;
    }

    /// <summary>
    /// Reads a list of whole numbers.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The numbers.</returns>
    private static List<int> Ints(RubyValue list) => [.. list.AsArray().Select(item => item.AsInt())];

    /// <summary>
    /// Writes a list of whole numbers.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>The list.</returns>
    private static RubyArray Ints(IEnumerable<int> numbers) => new(numbers.Select(number => (RubyValue)number));

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The texts.</returns>
    private static List<string> TextsOf(RubyValue list) => [.. list.AsArray().Select(item => item.AsText())];

    /// <summary>
    /// Writes a list of texts.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The list.</returns>
    private static RubyArray Texts(IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));

    /// <summary>
    /// Writes [id, value] pairs.
    /// </summary>
    /// <param name="pairs">The pairs.</param>
    /// <returns>The list.</returns>
    private static RubyArray Pairs(IEnumerable<KeyValuePair<int, int>> pairs) => new(pairs.Select(pair => (RubyValue)new RubyArray { pair.Key, pair.Value }));

    /// <summary>
    /// Writes self switches as [map, event, letter].
    /// </summary>
    /// <param name="keys">The self switches.</param>
    /// <returns>The list.</returns>
    private static RubyArray SelfSwitches(IEnumerable<SelfSwitchKey> keys) => new(keys.Select(key => (RubyValue)new RubyArray { key.Map, key.Event, key.Letter }));
}
