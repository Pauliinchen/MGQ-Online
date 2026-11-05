//----------------------------------------------------------------
//  FlowGuard.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Flow;

/// <summary>
/// How the mod interrupts the game's flow, which decides what the guard puts back.
/// </summary>
public enum FlowCut
{
    /// <summary>The mod ends an event of the player's own before its end, the player staying where they are.</summary>
    Cut,

    /// <summary>The mod keeps an event from starting, as a story event another player's game runs.</summary>
    Skip,

    /// <summary>The mod moves the player away from their place or their own scene, as a teleport to the leader.</summary>
    Leave,

    /// <summary>A scene of another player's game the player watched on their screen ends for them.</summary>
    Watched,

    /// <summary>The mod keeps the player from a move an event started, as into an area the world has not opened.</summary>
    Refused,

    /// <summary>The player stands free with nothing of the game's flow under way that would put back what is left, as after a duel put the game back from its snapshot.</summary>
    Free,
}

/// <summary>
/// What a watched scene of another player's game shows on the player's screen.
/// </summary>
/// <param name="Screen">Whether it changed the screen: its tint, fades, flashes or shakes.</param>
/// <param name="Hidden">Whether it hid or showed the player's character.</param>
/// <param name="Route">Whether the player's character still walks a route it gave.</param>
/// <param name="Pictures">The pictures it showed.</param>
public sealed record FlowWatch(bool Screen, bool Hidden, bool Route, IReadOnlySet<int> Pictures)
{
    /// <summary>
    /// Gets what no watched scene shows.
    /// </summary>
    public static FlowWatch None { get; } = new(false, false, false, new HashSet<int>());
}

/// <summary>
/// What the guard is asked to put back after.
/// </summary>
/// <param name="Cut">How the mod interrupted the flow.</param>
/// <param name="Before">The state the interrupted part began from: the cut event's start, the start of the player's own scene they leave, or the screen before a watched scene reached it; <see langword="null"/> for none known.</param>
/// <param name="Now">The state now.</param>
/// <param name="Owned">The pictures the cut event showed.</param>
/// <param name="Rest">What the commands the interrupted event would still run leave.</param>
/// <param name="Whole">For a leave, whether the player leaves every scene of their own, a temporary party it began with too, as when the world's story returns them to a point where none plays.</param>
/// <param name="Elsewhere">For a leave, whether the player goes to another map, out of the place they stood in.</param>
/// <param name="Watch">What a watched scene shows on the player's screen: for <see cref="FlowCut.Watched"/> the one that ended, else one that still plays, whose own changes stay.</param>
public sealed record FlowAsk(
    FlowCut Cut, FlowState? Before, FlowState Now, IReadOnlySet<int> Owned, FlowRest Rest, bool Whole, bool Elsewhere, FlowWatch Watch);

/// <summary>
/// What the guard puts back of the game's flow. Each part that is <see langword="null"/>, empty or
/// <see langword="false"/> stays as it is.
/// </summary>
/// <param name="Erase">The pictures to erase.</param>
/// <param name="FadeIn">Whether the screen fades in.</param>
/// <param name="Tone">The tint the screen changes to.</param>
/// <param name="Hidden">Whether the player's character is hidden.</param>
/// <param name="Followers">Whether the followers show.</param>
/// <param name="ReleaseParty">Whether the story's temporary party ends.</param>
/// <param name="Music">The music that plays again.</param>
/// <param name="Lift">The bans to lift, see <see cref="FlowBans"/>.</param>
/// <param name="EndRoute">Whether the forced move route of the player's character ends.</param>
/// <param name="ClearEffects">Whether the screen's flash and shake end.</param>
public sealed record FlowPlan(
    IReadOnlyList<int> Erase, bool FadeIn, FlowTone? Tone, bool? Hidden, bool? Followers, bool ReleaseParty, FlowMusic? Music,
    IReadOnlyList<string> Lift, bool EndRoute, bool ClearEffects)
{
    /// <summary>
    /// Frames a fade or a tint the guard starts takes, half a second, as the game's own fades.
    /// </summary>
    public const int Frames = 30;

    /// <summary>
    /// Gets the plan that puts nothing back.
    /// </summary>
    public static FlowPlan Nothing { get; } = new([], false, null, null, null, false, null, [], false, false);
}

/// <summary>
/// The one guard of the game's flow: for every place the mod cuts, skips, moves or ends a game event,
/// it finds what to put back so the player is left as the game's own flow would leave them, from
/// the state before the event, the state now and the commands the event would still run.
/// </summary>
/// <remarks>
/// The guard only lifts: it erases, fades in, shows and ends, and never starts a picture, a fade out,
/// a ban or a temporary party the rest of an event would start, since nothing of that event plays.
/// What a watched scene that still plays shows stays, since its own changes and its end put it back.
/// </remarks>
public static class FlowGuard
{
    /// <summary>
    /// Finds what to put back after the mod interrupted the game's flow.
    /// </summary>
    /// <param name="ask">What the guard is asked to put back after.</param>
    /// <returns>What to put back.</returns>
    public static FlowPlan Plan(FlowAsk ask)
    {
        ArgumentNullException.ThrowIfNull(ask);
        FlowPlan plan = ask.Cut switch
        {
            FlowCut.Skip => Skipped(ask.Now, ask.Rest),
            FlowCut.Refused or FlowCut.Free => FlowPlan.Nothing with { FadeIn = ask.Now.Dark },
            FlowCut.Cut => Ended(ask.Before ?? ask.Now, ask.Now, ask.Owned, ask.Rest),
            FlowCut.Leave => Left(ask.Before, ask.Now, ask.Whole, ask.Elsewhere),
            FlowCut.Watched => Unwatched(ask.Before ?? ask.Now, ask.Now, ask.Watch),
            _ => throw new ArgumentOutOfRangeException(nameof(ask), ask.Cut, "No such cut of the flow."),
        };
        return ask.Cut == FlowCut.Watched ? plan : Watching(plan, ask.Watch);
    }

    /// <summary>
    /// Tells whether the player's own scene still stands once none of its events runs: it left the
    /// player's character hidden, the followers hidden, a temporary party or a picture, each that was
    /// not so as it began, as an ending's walk or a scene the mod stopped does.
    /// </summary>
    /// <param name="start">The state the scene began from.</param>
    /// <param name="now">The state now.</param>
    /// <returns>Whether it stands.</returns>
    public static bool Stands(FlowState start, FlowState now)
    {
        ArgumentNullException.ThrowIfNull(start);
        ArgumentNullException.ThrowIfNull(now);
        return (now.TempParty && !start.TempParty) || (now.Hidden && !start.Hidden) || (!now.Followers && start.Followers)
            || now.Pictures.Any(number => !start.Pictures.Contains(number));
    }

    /// <summary>
    /// Leaves what a watched scene that still plays shows to it: its pictures, and the screen and the
    /// character it changed.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <param name="watch">What the scene shows.</param>
    /// <returns>The plan without them.</returns>
    private static FlowPlan Watching(FlowPlan plan, FlowWatch watch) => plan with
    {
        Erase = [.. plan.Erase.Where(number => !watch.Pictures.Contains(number))],
        FadeIn = plan.FadeIn && !watch.Screen,
        Tone = watch.Screen ? null : plan.Tone,
        Hidden = watch.Hidden ? null : plan.Hidden,
    };

    /// <summary>
    /// Finds what to put back for an event kept from starting: the pictures its commands leave erased
    /// and the bans they leave lifted, and a dark screen they fade in, as an arrival in the middle of
    /// another player's story, whose next event would have faded it in.
    /// </summary>
    /// <param name="now">The state now.</param>
    /// <param name="rest">What the event's commands leave.</param>
    /// <returns>The plan.</returns>
    private static FlowPlan Skipped(FlowState now, FlowRest rest) => FlowPlan.Nothing with
    {
        Erase = [.. now.Pictures.Where(rest.Erases).Order()],
        FadeIn = now.Dark && rest.FadesIn,
        Lift = Lifted(now, rest.Lifts),
    };

    /// <summary>
    /// Finds what to put back for an event the mod ends before its end: the pictures it showed and
    /// those its rest erases go; the light comes back; the tint, the character, the followers and the
    /// music go back as the event began unless its rest sets the tint, shows the character or the
    /// followers itself; a temporary party it started or its rest ends goes; and the bans its rest
    /// lifts are lifted.
    /// </summary>
    /// <param name="before">The state the event began from.</param>
    /// <param name="now">The state now.</param>
    /// <param name="owned">The pictures the event showed.</param>
    /// <param name="rest">What the event's commands from where it ends leave.</param>
    /// <returns>The plan.</returns>
    private static FlowPlan Ended(FlowState before, FlowState now, IReadOnlySet<int> owned, FlowRest rest) => new(
        Erase: [.. now.Pictures.Where(number => owned.Contains(number) || rest.Erases(number)).Order()],
        FadeIn: now.Dark,
        Tone: Changed(rest.Tone ?? before.Tone, now.Tone),
        Hidden: Changed(rest.Hidden == false ? false : before.Hidden, now.Hidden),
        Followers: Changed(rest.Followers == true ? true : before.Followers, now.Followers),
        ReleaseParty: now.TempParty && (rest.TempParty == false || !before.TempParty),
        Music: before.Music is { } music && music != now.Music ? music : null,
        Lift: Lifted(now, rest.Lifts),
        EndRoute: false,
        ClearEffects: false);

    /// <summary>
    /// Finds what to put back as the mod moves the player away: out of their own scene, every picture
    /// shown that was not as it began goes, the character and the followers show, and the temporary
    /// party it started, the tint and the music go back as it began; out of their place, onto another
    /// map, the followers show and the place's bans go, as walking out of it does; the light comes
    /// back either way.
    /// </summary>
    /// <remarks>
    /// The pictures go by the screen as the scene began, not by those its events showed, since a scene
    /// the mod stopped, as by a frozen fight's resume or a save loaded in its middle, showed its
    /// pictures before any of its events the guard saw.
    /// </remarks>
    /// <param name="before">The state the player's own scene began from, <see langword="null"/> while none is under way.</param>
    /// <param name="now">The state now.</param>
    /// <param name="whole">Whether every scene of the player's own goes, a temporary party it began with too.</param>
    /// <param name="elsewhere">Whether the player goes to another map.</param>
    /// <returns>The plan.</returns>
    private static FlowPlan Left(FlowState? before, FlowState now, bool whole, bool elsewhere)
    {
        bool scene = before is not null || whole;
        return new(
            Erase: before is null ? [] : [.. now.Pictures.Where(number => !before.Pictures.Contains(number)).Order()],
            FadeIn: now.Dark,
            Tone: before is null ? null : Changed(before.Tone, now.Tone),
            Hidden: scene ? Changed(false, now.Hidden) : null,
            Followers: scene || elsewhere ? Changed(true, now.Followers) : null,
            ReleaseParty: now.TempParty && (whole || (before is not null && !before.TempParty)),
            Music: before?.Music is { } music && music != now.Music ? music : null,
            Lift: elsewhere ? Lifted(now, FlowBans.OfPlace.Contains) : [],
            EndRoute: false,
            ClearEffects: false);
    }

    /// <summary>
    /// Finds what to put back once a watched scene ends for the player: its pictures go, its flash
    /// and shake end, a route it gave the player's character that still walks ends, and what it
    /// changed of the screen and the character goes back as before it reached them; on another map
    /// than the one it began on the tint goes and the character shows, since the scene's own may
    /// still play there in the teller's game, as an ending does.
    /// </summary>
    /// <param name="before">The state before the scene reached the player's screen.</param>
    /// <param name="now">The state now.</param>
    /// <param name="watch">What the scene showed on the player's screen.</param>
    /// <returns>The plan.</returns>
    private static FlowPlan Unwatched(FlowState before, FlowState now, FlowWatch watch)
    {
        bool here = before.Map == now.Map;
        return new(
            Erase: [.. now.Pictures.Where(watch.Pictures.Contains).Order()],
            FadeIn: watch.Screen && now.Dark,
            Tone: watch.Screen ? Changed(here ? before.Tone : FlowTone.None, now.Tone) : null,
            Hidden: watch.Hidden ? Changed(here && before.Hidden, now.Hidden) : null,
            Followers: null,
            ReleaseParty: false,
            Music: null,
            Lift: [],
            EndRoute: watch.Route && now.Route,
            ClearEffects: watch.Screen);
    }

    /// <summary>
    /// Lists the bans on now that a rule lifts, in their names' order.
    /// </summary>
    /// <param name="now">The state now.</param>
    /// <param name="lifts">Tells whether a ban is lifted.</param>
    /// <returns>The bans to lift.</returns>
    private static string[] Lifted(FlowState now, Func<string, bool> lifts) => [.. now.Bans.Where(lifts).Order(StringComparer.Ordinal)];

    /// <summary>
    /// Gives a tint to change to, unless the screen shows it already.
    /// </summary>
    /// <param name="wanted">The tint wanted.</param>
    /// <param name="now">The tint now.</param>
    /// <returns>The tint, <see langword="null"/> when it shows already.</returns>
    private static FlowTone? Changed(FlowTone wanted, FlowTone now) => wanted.Looks(now) ? null : wanted;

    /// <summary>
    /// Gives a setting to change to, unless it is so already.
    /// </summary>
    /// <param name="wanted">The setting wanted.</param>
    /// <param name="now">The setting now.</param>
    /// <returns>The setting, <see langword="null"/> when it is so already.</returns>
    private static bool? Changed(bool wanted, bool now) => wanted == now ? null : wanted;
}
