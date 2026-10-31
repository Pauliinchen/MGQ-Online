//----------------------------------------------------------------
//  PageMatch.cs
//
//  Changelog:
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

namespace MGQOnline.Game.Story;

/// <summary>
/// The values a replay reads to pick its page: those of <see cref="IPageState"/>, and the party's
/// items and members a page's conditions check.
/// </summary>
public interface IReplayState : IPageState
{
    /// <summary>
    /// Tells whether the party holds an item.
    /// </summary>
    /// <param name="item">The item.</param>
    /// <returns>Whether it does.</returns>
    bool HasItem(int item);

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

        PageRow? shown = PagesOf(site).Where(page => Holds(page, state)).Select(page => (PageRow?)page).LastOrDefault();
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
    /// Tells whether a choice a run's player answered is the receiver's to answer (rule 4, answer 11):
    /// its answers do different things to the receiver's own things, the keys a player keeps and
    /// what they hold.
    /// </summary>
    /// <param name="run">Where the run started, whose event a self switch the choice writes is of.</param>
    /// <param name="at">The choice's command, as the run's inputs name it: such as "map:1:9:1@0" or "ce:20@3".</param>
    /// <param name="own">Tells whether a player keeps a key: a player's or a party's key, by the live scopes.</param>
    /// <returns>Whether it is; false for a command that is no choice the database holds.</returns>
    public bool IsReceivers(ReplaySite run, string at, Func<StoryKey, bool> own)
    {
        ArgumentNullException.ThrowIfNull(at);
        ArgumentNullException.ThrowIfNull(own);
        int mark = at.LastIndexOf('@');
        if (mark < 0 || !int.TryParse(at.AsSpan(mark + 1), NumberStyles.None, CultureInfo.InvariantCulture, out int idx)
            || !TryParseSite(at[..mark], out ReplaySite site) || ListOf(site) is not { } listId)
        {
            return false;
        }

        List<HashSet<string>> effects = [.. store.ChoiceBranches(listId, idx).Select(branch => EffectOf(branch, run, own))];
        return effects.Skip(1).Any(effect => !effect.SetEquals(effects[0]));
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
    /// Tells whether a page's conditions hold, as <c>Game_Event#conditions_met?</c> checks them.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="state">The values.</param>
    /// <returns>Whether they do.</returns>
    private static bool Holds(PageRow page, IReplayState state) =>
        (page.CondSwitch1 is not { } first || state.Switch(first))
        && (page.CondSwitch2 is not { } second || state.Switch(second))
        && (page.CondVariable is not { } variable || state.Variable(variable) >= page.CondValue)
        && (page.CondSelfSwitch is not { } letter || state.SelfSwitch(page.MapId, page.EventId, letter))
        && (page.CondItem is not { } item || state.HasItem(item))
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
    /// it writes with its value, and what it does to what a player holds.
    /// </summary>
    /// <param name="branch">The branch.</param>
    /// <param name="run">Where the run started.</param>
    /// <param name="own">Tells whether a player keeps a key.</param>
    /// <returns>Its effects, as texts to compare.</returns>
    private HashSet<string> EffectOf(ChoiceBranchRow branch, ReplaySite run, Func<StoryKey, bool> own)
    {
        HashSet<string> effect = [.. WrittenOf(branch.ListId, (branch.FirstIdx, branch.LastIdx), run.MapId, run.EventId).Where(write => own(write.Key)).Select(write => $"{write.Key}={write.Value}")];
        if (branch.Holdings.Length > 0)
        {
            effect.Add($"holdings {branch.Holdings}");
        }

        return effect;
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
