//----------------------------------------------------------------
//  PageMatch.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Picked a replay's page without reading what the receiver holds, as the opener's game picked it
//      Paulinchen  2026-11-11: Found a choice by its code and its number among its list's commands of that code, in a list of any shape
//                            - Named an input of an earlier release's entry by its command's code and number
//      Paulinchen  2026-11-05: Told whether a run's page calls a common event
//      Paulinchen  2026-11-01: Left what a choice's answers take out of whether the choice is the receiver's, since a replay takes nothing
//                            - Told whether an extended choice is the receiver's too, each answer by all the branches it runs
//                            - Found a choice by its place among the kept commands while the player's list has the database's shape, and followed its answers' jumps
//      Paulinchen  2026-10-31: Told whether a run's page gives and whether a choice is the receiver's
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Story;

/// <summary>
/// The values a replay reads to pick its page: those of <see cref="IPageState"/>, and the party's
/// members a page's conditions check.
/// </summary>
public interface IReplayState : IPageState
{
    /// <summary>
    /// Tells whether an actor is in the party.
    /// </summary>
    /// <param name="actor">The actor.</param>
    /// <returns>Whether they are.</returns>
    bool InParty(int actor);
}

/// <summary>
/// What a receiver's game does with a run handed to it, by the page it shows.
/// </summary>
public enum PickResult
{
    /// <summary>The run's page shows, so it is replayed.</summary>
    Replay,

    /// <summary>Another page of the event shows that writes a key of the run's step, so that page is replayed.</summary>
    Sibling,

    /// <summary>Another page shows that writes no key of the step, so the run waits.</summary>
    OtherPage,

    /// <summary>No page shows, or the common event's switch is off, so the run waits.</summary>
    NoPage,
}

/// <summary>
/// The page a receiver's game picked for a run.
/// </summary>
/// <param name="Result">What it does.</param>
/// <param name="PageNo">The page shown, from 0; 0 for a common event or none.</param>
public readonly record struct PagePick(PickResult Result, int PageNo)
{
    /// <summary>
    /// Gets whether the run is replayed now.
    /// </summary>
    public bool Replays => Result is PickResult.Replay or PickResult.Sibling;
}

/// <summary>
/// Picks the page a receiver's game plays for a run handed to it, as the game picks one, from the
/// events database's pages ("Issue 73 chest effects.md", rule 2), and names the keys whose start
/// values the run carries.
/// </summary>
/// <param name="store">The events database.</param>
public sealed class PageMatch(EventStore store)
{
    /// <summary>
    /// The letters of an event's self switches.
    /// </summary>
    private static readonly string[] Letters = ["A", "B", "C", "D"];

    /// <summary>
    /// The operation of a command that changes gold, items, weapons or armors that takes them away.
    /// </summary>
    private const string DecreaseOperation = "1";

    /// <summary>
    /// Picks the page: the last page of the run's event whose conditions hold, replayed when it is
    /// the run's page or writes a key of the run's step. A common event runs while its switch is on.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="state">The values the replay reads: the run's start values of world and work keys, the receiver's own otherwise.</param>
    /// <param name="stepKeys">The keys of the run's step.</param>
    /// <returns>The pick.</returns>
    public PagePick Pick(ReplaySite site, IReplayState state, IEnumerable<StoryKey> stepKeys)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(stepKeys);
        if (site.IsCommon)
        {
            return store.Common(site.CommonId) is { } common && (common.Trigger == 0 || common.SwitchId == 0 || state.Switch(common.SwitchId))
                ? new PagePick(PickResult.Replay, 0)
                : new PagePick(PickResult.NoPage, 0);
        }

        PageRow? shown = PagesOf(site).Where(page => Holds(page, site, state)).Select(page => (PageRow?)page).LastOrDefault();
        if (shown is not { } page)
        {
            return new PagePick(PickResult.NoPage, 0);
        }

        if (page.PageNo == site.PageNo)
        {
            return new PagePick(PickResult.Replay, page.PageNo);
        }

        HashSet<StoryKey> writes = WritesOf(page.ListId, site.MapId, site.EventId);
        return new PagePick(stepKeys.Any(writes.Contains) ? PickResult.Sibling : PickResult.OtherPage, page.PageNo);
    }

    /// <summary>
    /// Finds the page that closes a chest: for its self switch, the first page of its event that
    /// turns that letter on; for a switch, the first map page that turns the switch on.
    /// </summary>
    /// <param name="key">The chest's key.</param>
    /// <returns>The page, <see langword="null"/> when no page closes it.</returns>
    public ReplaySite? ChestPage(StoryKey key)
    {
        if (key.Kind == StoryKeyKind.SelfSwitch)
        {
            return PagesOf(ReplaySite.Page(key.Id, key.Event, 0)).Where(page => store.RowsOf(page.ListId).SelfSwitches.Any(write => write.Letter == key.Letter && write.TurnsOn))
                .Select(page => (ReplaySite?)ReplaySite.Page(page.MapId, page.EventId, page.PageNo)).FirstOrDefault();
        }

        if (key.Kind != StoryKeyKind.Switch)
        {
            return null;
        }

        return store.ListsTouching([key.Id], [])
            .Where(list => list is { MapId: > 0, EventId: > 0, PageNo: not null }
                && store.RowsOf(list.ListId).Writes.Any(write => write.Kind == KeyKind.Switch && write.TurnsOn && write.FromId <= key.Id && write.ToId >= key.Id))
            .Select(list => (ReplaySite?)ReplaySite.Page(list.MapId!.Value, list.EventId!.Value, list.PageNo!.Value)).FirstOrDefault();
    }

    /// <summary>
    /// Names the keys that close a page: the self switches of its event it turns on.
    /// </summary>
    /// <param name="site">The page.</param>
    /// <returns>The self switches, each once; none for a common event or a page the database lacks.</returns>
    public IReadOnlyList<StoryKey> ClosingKeys(ReplaySite site) =>
        site.IsCommon || store.Page(site.MapId, site.EventId, site.PageNo) is not { } page
            ? []
            : [.. store.RowsOf(page.ListId).SelfSwitches.Where(write => write.TurnsOn).Select(write => StoryKey.SelfSwitch(site.MapId, site.EventId, write.Letter)).Distinct()];

    /// <summary>
    /// Tells whether a run's page gives ("Issue 73 chest effects.md", "Gives"): it, or a common event
    /// it calls, adds to what a player holds, or writes a key a player keeps.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="own">Tells whether a player keeps a key: a player's or a party's key, by the live scopes.</param>
    /// <returns>Whether it gives; false for a site the database lacks.</returns>
    public bool Gives(ReplaySite site, Func<StoryKey, bool> own)
    {
        ArgumentNullException.ThrowIfNull(own);
        return ListOf(site) is { } listId && (store.Gives(listId) || WritesOf(listId, site.MapId, site.EventId).Any(own));
    }

    /// <summary>
    /// Tells whether a run's page, or a common event it calls, calls a common event.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="commonId">The common event.</param>
    /// <returns>Whether it does; false for a site the database lacks.</returns>
    public bool Calls(ReplaySite site, int commonId) =>
        (site.IsCommon && site.CommonId == commonId) || (ListOf(site) is { } listId && CallsFrom(listId, commonId, []));

    /// <summary>
    /// Tells whether a choice a run's player answered is the receiver's to answer (rule 4, answer 11):
    /// its answers do different things to the receiver's own things, the keys a player keeps and
    /// what they hold, where an answer that jumps to a label does what follows the label too. What
    /// an answer takes does not count, since a replay takes nothing. An extended choice's answer does
    /// what each branch it runs does.
    /// </summary>
    /// <param name="run">Where the run started, whose event a self switch the choice writes is of.</param>
    /// <param name="at">The choice's command, as the run's inputs name it: such as "map:1:9:1@102:0" or "ce:20@355:3".</param>
    /// <param name="own">Tells whether a player keeps a key: a player's or a party's key, by the live scopes.</param>
    /// <returns>Whether it is; false for a command <see cref="ChoiceOf"/> finds no choice at.</returns>
    public bool IsReceivers(ReplaySite run, string at, Func<StoryKey, bool> own)
    {
        ArgumentNullException.ThrowIfNull(own);
        if (ChoiceOf(at) is not { } choice)
        {
            return false;
        }

        List<HashSet<string>> effects = [.. store.ChoiceBranches(choice.ListId, choice.Idx).GroupBy(branch => branch.Branch)
            .Select(answer => answer.SelectMany(branch => EffectOf(branch, run, own)).ToHashSet())];
        return effects.Skip(1).Any(effect => !effect.SetEquals(effects[0]));
    }

    /// <summary>
    /// Finds the choice an input names in the events database: the Show Choices command or the
    /// script command of an extended choice of the input's code and number in its list.
    /// </summary>
    /// <remarks>
    /// The database holds the untranslated game's lists, whose texts, branches and scripts a
    /// translation changes; a choice keeps its number among its list's choices through that.
    /// </remarks>
    /// <param name="at">The input's command, such as "map:6:30:2@102:1", see <see cref="StoryPlain.PlaceText(string, int, long)"/>.</param>
    /// <returns>The list and the command's place in it; <see langword="null"/> when the database lacks the list or neither command stands there.</returns>
    public (int ListId, int Idx)? ChoiceOf(string at)
    {
        ArgumentNullException.ThrowIfNull(at);
        if (!StoryPlain.TryParsePlace(at, out string text, out int code, out long number) || code is not (EventCodes.ShowChoices or EventCodes.Script)
            || !TryParseSite(text, out ReplaySite site) || ListOf(site) is not { } listId)
        {
            return null;
        }

        return CommandOf(store.Commands(listId), code, number) is { } choice ? (listId, choice.Idx) : null;
    }

    /// <summary>
    /// Finds a list's command of a code by its number among the list's commands of that code.
    /// </summary>
    /// <param name="commands">The list's commands in their order.</param>
    /// <param name="code">The code.</param>
    /// <param name="number">The number, from 0.</param>
    /// <returns>The command, <see langword="null"/> when the list has fewer of that code.</returns>
    internal static CommandRow? CommandOf(IReadOnlyList<CommandRow> commands, int code, long number)
    {
        ArgumentNullException.ThrowIfNull(commands);
        long seen = 0;
        foreach (CommandRow command in commands)
        {
            if (command.Code == code && seen++ == number)
            {
                return command;
            }
        }

        return null;
    }

    /// <summary>
    /// Counts a list's commands of a command's code before it, its number as the inputs name it.
    /// </summary>
    /// <param name="commands">The list's commands in their order.</param>
    /// <param name="index">The command's place among them.</param>
    /// <returns>The number, from 0.</returns>
    internal static int NumberOf(IReadOnlyList<CommandRow> commands, int index)
    {
        ArgumentNullException.ThrowIfNull(commands);
        int code = commands[index].Code;
        int number = 0;
        for (int before = 0; before < index; before++)
        {
            number += commands[before].Code == code ? 1 : 0;
        }

        return number;
    }

    /// <summary>
    /// Names an input of an entry of an earlier release as the inputs name it now: the database's
    /// command at the input's place among its list's kept commands, by its code and number. A number
    /// or item input an earlier release named by the text before it goes by the text's first Input
    /// Number or Select Key Item after it.
    /// </summary>
    /// <param name="at">The input's place as the earlier release named it, such as "map:215:23:1@4".</param>
    /// <param name="kind">What the input read, such as "choice" or "number".</param>
    /// <returns>The place, such as "map:215:23:1@102:0"; <see langword="null"/> when the database lacks the list or the command.</returns>
    public string? RenamedEarlierInput(string at, string kind)
    {
        ArgumentNullException.ThrowIfNull(at);
        if (!StoryPlain.TryParseEarlierPlace(at, out string text, out int ord) || !TryParseSite(text, out ReplaySite site) || ListOf(site) is not { } listId)
        {
            return null;
        }

        IReadOnlyList<CommandRow> commands = store.Commands(listId);
        int index = IndexOf(commands, 0, command => command.Ord == ord);
        if (index >= 0 && commands[index].Code == EventCodes.ShowText && kind is "number" or "item")
        {
            int input = kind == "number" ? EventCodes.InputNumber : EventCodes.SelectKeyItem;
            index = IndexOf(commands, index + 1, command => command.Code == input);
        }

        return index < 0 ? null : StoryPlain.PlaceText(text, commands[index].Code, NumberOf(commands, index));
    }

    /// <summary>
    /// Names the keys any page of the run's event can read, of those a run carries: every page's
    /// conditions, the switches and variables its list and the common events it calls read, and
    /// the event's self switches, which its branches may test.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="carried">Tells whether a run carries a key's start value: world and work keys.</param>
    /// <returns>The keys, each once.</returns>
    public IReadOnlyList<StoryKey> ReadKeys(ReplaySite site, Func<StoryKey, bool> carried)
    {
        ArgumentNullException.ThrowIfNull(carried);
        var keys = new HashSet<StoryKey>();
        var seen = new HashSet<int>();
        if (site.IsCommon)
        {
            if (store.Common(site.CommonId) is { } common)
            {
                if (common.SwitchId > 0)
                {
                    keys.Add(StoryKey.Switch(common.SwitchId));
                }

                AddReads(keys, common.ListId, seen);
            }
        }
        else
        {
            foreach (PageRow page in PagesOf(site))
            {
                AddConditions(keys, page);
                AddReads(keys, page.ListId, seen);
            }

            keys.UnionWith(Letters.Select(letter => StoryKey.SelfSwitch(site.MapId, site.EventId, letter)));
        }

        return [.. keys.Where(carried)];
    }

    /// <summary>
    /// Tells whether a page's conditions hold for a replay, as <c>Game_Event#conditions_met?</c>
    /// checks them, but an item the page needs counts as held up to the run's page and as not held
    /// after it.
    /// </summary>
    /// <remarks>
    /// A replay never waits on what the receiver holds (user decision 2026-11-12), and the opener's
    /// game passed over each later page, so a later page that needs the item a run's page gives, the
    /// game's "already got it" page, never takes the place of that run.
    /// </remarks>
    /// <param name="page">The page.</param>
    /// <param name="site">Where the run started.</param>
    /// <param name="state">The values.</param>
    /// <returns>Whether they do.</returns>
    private static bool Holds(PageRow page, ReplaySite site, IReplayState state) =>
        (page.CondSwitch1 is not { } first || state.Switch(first))
        && (page.CondSwitch2 is not { } second || state.Switch(second))
        && (page.CondVariable is not { } variable || state.Variable(variable) >= page.CondValue)
        && (page.CondSelfSwitch is not { } letter || state.SelfSwitch(page.MapId, page.EventId, letter))
        && (page.CondItem is null || page.PageNo <= site.PageNo)
        && (page.CondActor is not { } actor || state.InParty(actor));

    /// <summary>
    /// Adds the keys a page's conditions check.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <param name="page">The page.</param>
    private static void AddConditions(HashSet<StoryKey> keys, PageRow page)
    {
        foreach (int id in new[] { page.CondSwitch1, page.CondSwitch2 }.OfType<int>())
        {
            keys.Add(StoryKey.Switch(id));
        }

        if (page.CondVariable is { } variable)
        {
            keys.Add(StoryKey.Variable(variable));
        }
    }

    /// <summary>
    /// Lists the pages of the site's event, in their order.
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>The pages.</returns>
    private IEnumerable<PageRow> PagesOf(ReplaySite site) => store.Pages(site.MapId).Where(page => page.EventId == site.EventId);

    /// <summary>
    /// Adds the switches and variables a list reads, and those of the common events it calls.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <param name="listId">The list.</param>
    /// <param name="seen">The lists walked already.</param>
    private void AddReads(HashSet<StoryKey> keys, int listId, HashSet<int> seen)
    {
        if (!seen.Add(listId))
        {
            return;
        }

        ListRowSet rows = store.RowsOf(listId);
        foreach (ListReadRow read in rows.Reads)
        {
            keys.Add(read.Kind == KeyKind.Switch ? StoryKey.Switch(read.Id) : StoryKey.Variable(read.Id));
        }

        foreach (ListCallRow call in rows.Calls)
        {
            if (store.Common(call.CommonId) is { } common)
            {
                AddReads(keys, common.ListId, seen);
            }
        }
    }

    /// <summary>
    /// Tells whether a list, or a common event it calls, calls a common event.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="commonId">The common event.</param>
    /// <param name="seen">The lists walked already.</param>
    /// <returns>Whether it does.</returns>
    private bool CallsFrom(int listId, int commonId, HashSet<int> seen) =>
        seen.Add(listId) && store.RowsOf(listId).Calls.Any(call => call.CommonId == commonId || (store.Common(call.CommonId) is { } common && CallsFrom(common.ListId, commonId, seen)));

    /// <summary>
    /// Finds the keys a page writes, through the common events it calls, whose self switches are
    /// the page's event's.
    /// </summary>
    /// <param name="listId">The page's list.</param>
    /// <param name="map">The page's map.</param>
    /// <param name="eventId">The page's event.</param>
    /// <returns>The keys, ranges written out.</returns>
    private HashSet<StoryKey> WritesOf(int listId, int map, int eventId) => [.. WrittenOf(listId, null, map, eventId).Select(write => write.Key)];

    /// <summary>
    /// Lists the keys the commands of a list write with the value each writes, through the common
    /// events they call, whose self switches are the run's event's.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="range">The places of the first and last command, <see langword="null"/> for the whole list.</param>
    /// <param name="map">The run's map.</param>
    /// <param name="eventId">The run's event.</param>
    /// <returns>Each key written with its value: "1" or "0" for a switch, a variable's constant or "?" for another operation.</returns>
    private IEnumerable<(StoryKey Key, string Value)> WrittenOf(int listId, (int First, int Last)? range, int map, int eventId)
    {
        var lists = new Queue<(int ListId, (int First, int Last)? Range)>([(listId, range)]);
        var seen = new HashSet<int> { listId };
        while (lists.TryDequeue(out (int ListId, (int First, int Last)? Range) next))
        {
            ListRowSet rows = store.RowsOf(next.ListId);
            foreach (ListWriteRow write in rows.Writes.Where(write => Within(next.Range, write.Idx)))
            {
                string value = write.Kind == KeyKind.Switch ? (write.TurnsOn ? "1" : "0") : write.Value?.ToString(CultureInfo.InvariantCulture) ?? "?";
                for (int id = write.FromId; id <= write.ToId && id <= StoryKey.MaxId; id++)
                {
                    yield return (write.Kind == KeyKind.Switch ? StoryKey.Switch(id) : StoryKey.Variable(id), value);
                }
            }

            foreach (ListSelfSwitchRow selfSwitch in rows.SelfSwitches.Where(selfSwitch => Within(next.Range, selfSwitch.Idx)))
            {
                yield return (StoryKey.SelfSwitch(map, eventId, selfSwitch.Letter), selfSwitch.TurnsOn ? "1" : "0");
            }

            foreach (ListCallRow call in rows.Calls.Where(call => Within(next.Range, call.Idx)))
            {
                if (store.Common(call.CommonId) is { } common && seen.Add(common.ListId))
                {
                    lists.Enqueue((common.ListId, null));
                }
            }
        }
    }

    /// <summary>
    /// Tells whether a command's place lies in a range of a list.
    /// </summary>
    /// <param name="range">The places of the first and last command, <see langword="null"/> for the whole list.</param>
    /// <param name="idx">The command's place.</param>
    /// <returns>Whether it does.</returns>
    private static bool Within((int First, int Last)? range, int idx) => range is not { } within || (idx >= within.First && idx <= within.Last);

    /// <summary>
    /// Writes what a choice's branch does to the receiver's own things: each key a player keeps that
    /// it writes with its value, and what it does to what a player holds; for a branch that jumps to
    /// a label, those of every command from the first such label on too.
    /// </summary>
    /// <param name="branch">The branch.</param>
    /// <param name="run">Where the run started.</param>
    /// <param name="own">Tells whether a player keeps a key.</param>
    /// <returns>Its effects, as texts to compare.</returns>
    private HashSet<string> EffectOf(ChoiceBranchRow branch, ReplaySite run, Func<StoryKey, bool> own)
    {
        HashSet<string> effect = [.. WrittenOwn(branch.ListId, (branch.FirstIdx, branch.LastIdx), run, own)];
        string holdings = string.Join(';', branch.Holdings.Split(';', StringSplitOptions.RemoveEmptyEntries).Where(part => !IsCost(part)));
        if (holdings.Length > 0)
        {
            effect.Add($"holdings {holdings}");
        }

        if (FirstLabel(branch.ListId, branch.FirstIdx, branch.LastIdx) is { } label)
        {
            effect.UnionWith(WrittenOwn(branch.ListId, (label, int.MaxValue), run, own));
            effect.UnionWith(AddingFrom(branch.ListId, label));
        }

        return effect;
    }

    /// <summary>
    /// Writes each key a player keeps that the commands of a range write, with its value.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="range">The places of the first and last command.</param>
    /// <param name="run">Where the run started.</param>
    /// <param name="own">Tells whether a player keeps a key.</param>
    /// <returns>The writes, as texts to compare.</returns>
    private IEnumerable<string> WrittenOwn(int listId, (int First, int Last) range, ReplaySite run, Func<StoryKey, bool> own) =>
        WrittenOf(listId, range, run.MapId, run.EventId).Where(write => own(write.Key)).Select(write => $"{write.Key}={write.Value}");

    /// <summary>
    /// Finds the first label the jumps of a range lead to, through the jumps that follow each label
    /// too.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="first">The place of the range's first command.</param>
    /// <param name="last">The place of its last command.</param>
    /// <returns>The label's place, <see langword="null"/> when the range jumps nowhere.</returns>
    private int? FirstLabel(int listId, int first, int last)
    {
        IReadOnlyList<CommandRow> commands = store.Commands(listId);
        int? found = null;
        (int First, int Last) range = (first, last);
        while (commands
            .Where(command => command.Code == EventCodes.JumpToLabel && command.P0 >= 0 && command.Idx >= range.First && command.Idx <= range.Last)
            .Select(jump => commands.FirstOrDefault(command => command.Ord == jump.P0))
            .Where(label => label.Code == EventCodes.Label && (found is null || label.Idx < found))
            .Select(label => (int?)label.Idx)
            .Min() is { } next)
        {
            found = next;
            range = (next, int.MaxValue);
        }

        return found;
    }

    /// <summary>
    /// Names what the commands from a place to the list's end add to what a player holds: each
    /// command that adds gold, an item, a weapon, an armor or a member, and each call of a common
    /// event that gives.
    /// </summary>
    /// <remarks>
    /// The database tells what scripts do to what a player holds only for a branch's own commands.
    /// </remarks>
    /// <param name="listId">The list.</param>
    /// <param name="from">The place.</param>
    /// <returns>Each one by its place, as a text to compare.</returns>
    private IEnumerable<string> AddingFrom(int listId, int from)
    {
        foreach (CommandRow command in store.Commands(listId).Where(command => command.Idx >= from))
        {
            bool adds = command.Code switch
            {
                EventCodes.ChangeGold => command.P0 == 0,
                EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors or EventCodes.ChangePartyMember => command.P1 == 0,
                EventCodes.CallCommonEvent => command.P0 is > 0 and <= int.MaxValue && store.Common((int)command.P0) is { } common && store.Gives(common.ListId),
                _ => false,
            };
            if (adds)
            {
                yield return string.Create(CultureInfo.InvariantCulture, $"adds@{command.Idx}");
            }
        }
    }

    /// <summary>
    /// Tells whether a command of a branch's holdings takes gold, an item, a weapon or an armor,
    /// which a replay never takes from the receiver.
    /// </summary>
    /// <param name="part">The command as its code and numbers, such as "128:1734:1:0:1:0".</param>
    /// <returns>Whether it does.</returns>
    private static bool IsCost(string part)
    {
        string[] numbers = part.Split(':');
        if (!int.TryParse(numbers[0], NumberStyles.None, CultureInfo.InvariantCulture, out int code))
        {
            return false;
        }

        int operation = code switch
        {
            EventCodes.ChangeGold => 1,
            EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors => 2,
            _ => 0,
        };
        return operation > 0 && numbers.Length > operation && numbers[operation] == DecreaseOperation;
    }

    /// <summary>
    /// Finds the list a site runs: a map page's or a common event's.
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>The list, <see langword="null"/> for a site the database lacks.</returns>
    private int? ListOf(ReplaySite site) => site.IsCommon
        ? store.Common(site.CommonId) is { } common ? common.ListId : null
        : store.Page(site.MapId, site.EventId, site.PageNo) is { } page ? page.ListId : null;

    /// <summary>
    /// Finds the first command from a place on that matches.
    /// </summary>
    /// <param name="commands">The list's commands in their order.</param>
    /// <param name="from">The place to start at.</param>
    /// <param name="match">Tells whether a command matches.</param>
    /// <returns>Its place, -1 for none.</returns>
    private static int IndexOf(IReadOnlyList<CommandRow> commands, int from, Func<CommandRow, bool> match)
    {
        for (int place = from; place < commands.Count; place++)
        {
            if (match(commands[place]))
            {
                return place;
            }
        }

        return -1;
    }

    /// <summary>
    /// Reads a site as the inputs name it.
    /// </summary>
    /// <param name="text">Such as "map:1:9:1" or "ce:20".</param>
    /// <param name="site">The site read.</param>
    /// <returns>Whether it names one.</returns>
    private static bool TryParseSite(string text, out ReplaySite site)
    {
        try
        {
            site = ReplaySite.Parse(text);
            return true;
        }
        catch (RubyValueException)
        {
            site = default;
            return false;
        }
    }
}
