//----------------------------------------------------------------
//  CompanionScope.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Told the replay whether a page is where the player takes a side along
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// Which players a companion of the Alice and Ilias choice may join: a choice companion is one with
/// a lasting join that asks for the side the player took along in Iliasville, and joins only a
/// player one of whose lasting joins fits, by that side or by a route they played. Every path that
/// hands out a companion asks it, in Raid and Classic worlds alike.
/// </summary>
/// <remarks>
/// A join on a route asks for a side only where the game reads switches 4 and 5 before the route
/// sets them anew, as the Great Decision does.
/// </remarks>
public sealed class CompanionScope
{
    /// <summary>
    /// The lasting joins of each choice companion, by the companion's main persona.
    /// </summary>
    private readonly Dictionary<int, List<CatchupJoin>> _joins = [];

    /// <summary>
    /// The events where the player takes a side along, by their site without the page.
    /// </summary>
    private readonly HashSet<string> _pickSites;

    /// <summary>
    /// Initializes the scope of the tables' companions.
    /// </summary>
    /// <param name="tables">The tables.</param>
    internal CompanionScope(CatchupTables tables)
    {
        IReadOnlyList<CatchupJoin> lasting = tables.Index.StoryJoins;
        foreach (int actor in lasting.Where(join => join.Place.Side is not null).Select(join => join.Actor).Distinct())
        {
            _joins[actor] = [.. lasting.Where(join => join.Actor == actor)];
        }

        _pickSites = new HashSet<string>(tables.SideEvents.Where(side => side.Choice).Select(side => side.Site), StringComparer.Ordinal);
    }

    /// <summary>
    /// Gets the choice companions.
    /// </summary>
    public IEnumerable<int> Companions => _joins.Keys;

    /// <summary>
    /// Reports whether a companion belongs to the Alice and Ilias choice.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <returns>Whether they do.</returns>
    public bool IsChoiceCompanion(int actor) => _joins.ContainsKey(actor);

    /// <summary>
    /// Reports whether a companion may join a player: no choice companion, or one of their lasting
    /// joins fits the player's pick or a route the player played.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <param name="pick">The side the player took along in Iliasville, <see langword="null"/> before they picked.</param>
    /// <param name="routes">The routes the player played.</param>
    /// <param name="held">The side the switches of the story played hold, which a route's join is judged by while the pick is unknown; <see langword="null"/> for none.</param>
    /// <returns>Whether they may.</returns>
    public bool Allows(int actor, string? pick, IReadOnlyCollection<string> routes, string? held = null)
    {
        ArgumentNullException.ThrowIfNull(routes);
        return !_joins.TryGetValue(actor, out List<CatchupJoin>? joins) || joins.Any(join => Fits(join.Place, SideFor(join.Place, pick, held), routes));
    }

    /// <summary>
    /// Reports whether the game's own join of a companion may go ahead in the event that runs: no
    /// lasting join of a choice companion stands there, or one there asks for no side, for the
    /// player's pick, or for the side the player takes along right there.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <param name="site">The page or common event that runs, such as "map:6:30:2"; <see langword="null"/> for none.</param>
    /// <param name="pick">The side the player took along in Iliasville, <see langword="null"/> before they picked.</param>
    /// <param name="held">The side the switches of the story played hold, which a route's join is judged by while the pick is unknown; <see langword="null"/> for none.</param>
    /// <returns>Whether it may.</returns>
    public bool AllowsAt(int actor, string? site, string? pick, string? held = null)
    {
        if (site is null || !_joins.TryGetValue(actor, out List<CatchupJoin>? joins))
        {
            return true;
        }

        CatchupJoin[] here = [.. joins.Where(join => join.Place.Site == site)];
        return here.Length == 0 || here.Any(join => join.Place.Side is null || join.Place.Side == SideFor(join.Place, pick, held) || (pick is null && IsPickSite(site)));
    }

    /// <summary>
    /// Picks the side a join is judged by: the player's pick; while it is unknown, for a join on a
    /// route, the side the switches of the story played hold, which the game's own event reads there.
    /// </summary>
    /// <param name="place">The join's place.</param>
    /// <param name="pick">The side the player took along in Iliasville, <see langword="null"/> before they picked.</param>
    /// <param name="held">The side the switches of the story played hold, <see langword="null"/> for none.</param>
    /// <returns>The side, <see langword="null"/> for none.</returns>
    private static string? SideFor(StoryPlace place, string? pick, string? held) =>
        pick ?? (place.Part is { } part && StoryParts.Routes.Contains(part) ? held : null);

    /// <summary>
    /// Answers which of some companions may join a player: at an event that runs, whether its own
    /// join may go ahead (<see cref="AllowsAt"/>); else whether the player may have them at all
    /// (<see cref="Allows"/>).
    /// </summary>
    /// <param name="request">"actors" (main personas), "site" (the page or common event that runs, nil for none), "pick" ("alice", "ilias" or nil), "routes" (the routes the player played) and "held" (the side the switches of the story played hold, "alice", "ilias" or nil; optional).</param>
    /// <returns>"allowed", the companions that may join.</returns>
    public RubyHash Answer(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        string? pick = request["pick"] is RubyString { Text.Length: > 0 } side ? side.Text : null;
        string? held = request["held"] is RubyString { Text.Length: > 0 } switches ? switches.Text : null;
        string? site = request["site"] is RubyString running ? running.Text : null;
        HashSet<string> routes = request["routes"] is RubyArray played ? [.. played.Select(route => route.AsText())] : [];
        IEnumerable<int> allowed = request["actors"].AsArray().Select(actor => actor.AsInt())
            .Where(actor => site is null ? Allows(actor, pick, routes, held) : AllowsAt(actor, site, pick, held));
        return new RubyHash { { "allowed", new RubyArray(allowed.Select(actor => (RubyValue)actor)) } };
    }

    /// <summary>
    /// Reports whether a join's place fits a player: its side, if any, is their pick, and a route's is
    /// one they played.
    /// </summary>
    /// <param name="place">The join's place.</param>
    /// <param name="pick">The side the player took along in Iliasville, <see langword="null"/> before they picked.</param>
    /// <param name="routes">The routes the player played.</param>
    /// <returns>Whether it does.</returns>
    public static bool Fits(StoryPlace place, string? pick, IReadOnlyCollection<string> routes)
    {
        ArgumentNullException.ThrowIfNull(place);
        ArgumentNullException.ThrowIfNull(routes);
        if (place.Side is { } side && side != pick)
        {
            return false;
        }

        return place.Part is not { } part || !StoryParts.Routes.Contains(part) || routes.Contains(part);
    }

    /// <summary>
    /// Reports whether a page or common event is where the player takes a side along.
    /// </summary>
    /// <param name="site">The page, such as "map:6:30:2".</param>
    /// <returns>Whether it is.</returns>
    public bool IsPickSite(string site)
    {
        int page = site.LastIndexOf(':');
        return _pickSites.Contains(site) || (page > 0 && _pickSites.Contains(site[..page]));
    }
}
