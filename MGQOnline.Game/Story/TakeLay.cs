//----------------------------------------------------------------
//  TakeLay.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Story;

/// <summary>
/// What laying a take over the player's story comes to.
/// </summary>
/// <param name="Writes">The writes that change the player's story, in the order the game makes them.</param>
/// <param name="Freezes">The frozen fights the take brought, each by its key, the last value of a troop winning.</param>
/// <param name="Requests">The player's own values the take would have lowered, asked of the relay again.</param>
public sealed record LaidTake(IReadOnlyList<KeyValuePair<StoryKey, string>> Writes, IReadOnlyList<KeyValuePair<StoryKey, string>> Freezes, IReadOnlyList<StoryWrite> Requests);

/// <summary>
/// Lays a take of the relay over the player's story (<see cref="StoryTake"/>): a whole track over
/// every key the mapping keeps, then the track's chest flags, then the keys pushed or answered since.
/// Each value is compared with the one written before it, so a local step reads the step the track
/// just wrote.
/// </summary>
public sealed class TakeLay
{
    /// <summary>
    /// The site the requests of the player's kept values name.
    /// </summary>
    private const string GameSite = "game";

    /// <summary>
    /// A variable's value before the game wrote it.
    /// </summary>
    private const string NoNumber = "n0";

    /// <summary>
    /// The class of a key the whole world keeps going only up.
    /// </summary>
    private const StoryClass WholeOneWay = StoryClass.OneWay | StoryClass.WholeWorld;

    /// <summary>
    /// The story mapping's table.
    /// </summary>
    private readonly StoryTable table;

    /// <summary>
    /// The player's story as the lay leaves it: a key missing at its default, a value no story
    /// carries as <see langword="null"/>.
    /// </summary>
    private readonly Dictionary<StoryKey, string?> story;

    /// <summary>
    /// The values the frozen raid boss fights hold their keys at, which win over the relay's.
    /// </summary>
    private readonly IReadOnlyDictionary<StoryKey, string> frozen;

    /// <summary>
    /// The map the player stands on.
    /// </summary>
    private readonly int map;

    /// <summary>
    /// The player's x on the map, <see langword="null"/> without a player on it.
    /// </summary>
    private readonly int? x;

    /// <summary>
    /// The switches the game turns on for good and never off.
    /// </summary>
    private readonly IReadOnlySet<int> unlocks;

    /// <summary>
    /// The writes so far.
    /// </summary>
    private readonly List<KeyValuePair<StoryKey, string>> writes = [];

    /// <summary>
    /// The frozen fights so far, by troop.
    /// </summary>
    private readonly Dictionary<StoryKey, string> freezes = [];

    /// <summary>
    /// The requests so far.
    /// </summary>
    private readonly List<StoryWrite> requests = [];

    /// <summary>
    /// Initializes a lay over the player's story.
    /// </summary>
    /// <param name="table">The story mapping's table.</param>
    /// <param name="story">The player's story, see <see cref="Lay"/>.</param>
    /// <param name="frozen">The frozen fights' held values.</param>
    /// <param name="map">The map the player stands on.</param>
    /// <param name="x">The player's x.</param>
    /// <param name="unlocks">The switches the game turns on for good.</param>
    private TakeLay(StoryTable table, IReadOnlyDictionary<StoryKey, string?> story, IReadOnlyDictionary<StoryKey, string> frozen, int map, int? x, IReadOnlySet<int> unlocks)
    {
        this.table = table;
        this.story = new Dictionary<StoryKey, string?>(story);
        this.frozen = frozen;
        this.map = map;
        this.x = x;
        this.unlocks = unlocks;
    }

    /// <summary>
    /// Lays a take over the player's story. A whole track writes every key the mapping keeps, one it
    /// never wrote at its default, but not the keys the player's own unanswered requests wrote; then
    /// the player's chest flags and the keys after it. A key a frozen fight holds takes its held value; a
    /// local step the player plays where it stays theirs, a value below the player's own of a key
    /// the whole world keeps going only up, such as affection, and an unlock the player holds, such
    /// as the second accessory slot, stay the player's, the latter two asked of the relay again.
    /// </summary>
    /// <param name="take">The take.</param>
    /// <param name="table">The story mapping's table.</param>
    /// <param name="story">The player's values of every key the take covers as the game reads them,
    /// a key missing at its default (off, or 0), a value no story carries as <see langword="null"/>.</param>
    /// <param name="frozen">The values the frozen raid boss fights hold their keys at.</param>
    /// <param name="map">The map the player stands on.</param>
    /// <param name="x">The player's x on it, <see langword="null"/> without a player.</param>
    /// <param name="unlocks">The switches the game turns on for good and never off.</param>
    /// <returns>The writes, the frozen fights and the requests.</returns>
    public static LaidTake Lay(StoryTake take, StoryTable table, IReadOnlyDictionary<StoryKey, string?> story, IReadOnlyDictionary<StoryKey, string> frozen,
        int map, int? x, IReadOnlySet<int> unlocks)
    {
        ArgumentNullException.ThrowIfNull(take);
        ArgumentNullException.ThrowIfNull(table);
        ArgumentNullException.ThrowIfNull(story);
        ArgumentNullException.ThrowIfNull(frozen);
        ArgumentNullException.ThrowIfNull(unlocks);
        var lay = new TakeLay(table, story, frozen, map, x, unlocks);
        if (take.State is { } state)
        {
            lay.Track(state);
        }

        lay.PutAll(take.Keys);
        return new LaidTake(lay.writes, [.. lay.freezes], lay.requests);
    }

    /// <summary>
    /// Lays a whole track: the kept switches, the kept variables, the kept self switches the player
    /// or the track has, its frozen fights, then the player's chest flags.
    /// </summary>
    /// <param name="state">The track.</param>
    private void Track(TrackState state)
    {
        Dictionary<StoryKey, string> keys = [];
        foreach ((string name, string text) in state.Keys)
        {
            if (StoryKey.TryParse(name, out StoryKey key))
            {
                keys[key] = text;
            }
        }

        var held = new HashSet<StoryKey>();
        foreach (string name in state.Held)
        {
            if (StoryKey.TryParse(name, out StoryKey key))
            {
                held.Add(key);
            }
        }

        void PutKept(StoryKey key)
        {
            if (!held.Contains(key))
            {
                Put(key, keys.GetValueOrDefault(key) ?? DefaultOf(key));
            }
        }

        for (int id = 0; id < table.Switches.Length; id++)
        {
            if (((StoryClass)table.Switches[id] & StoryClass.Kept) != 0)
            {
                PutKept(StoryKey.Switch(id));
            }
        }

        for (int id = 0; id < table.Variables.Length; id++)
        {
            if (((StoryClass)table.Variables[id] & StoryClass.Kept) != 0)
            {
                PutKept(StoryKey.Variable(id));
            }
        }

        List<StoryKey> selves = [.. story.Keys.Concat(keys.Keys).Where(key => key.Kind == StoryKeyKind.SelfSwitch).Distinct()];
        foreach (StoryKey key in selves.Where(key => (table.ClassOf(key) & StoryClass.Kept) != 0))
        {
            PutKept(key);
        }

        foreach ((StoryKey key, string text) in keys.Where(pair => pair.Key.Kind == StoryKeyKind.Freeze))
        {
            freezes[key] = text;
        }

        PutAll(state.Chests);
    }

    /// <summary>
    /// Lays keys named as the tracks name them, in their order.
    /// </summary>
    /// <param name="texts">Each key's name with its value.</param>
    private void PutAll(IEnumerable<KeyValuePair<string, string>> texts)
    {
        foreach ((string name, string text) in texts)
        {
            if (StoryKey.TryParse(name, out StoryKey key))
            {
                Put(key, text);
            }
        }
    }

    /// <summary>
    /// Lays one key, see <see cref="Lay"/>.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="text">The relay's value.</param>
    private void Put(StoryKey key, string text)
    {
        if (key.Kind == StoryKeyKind.Freeze)
        {
            freezes[key] = text;
            return;
        }

        text = frozen.GetValueOrDefault(key) ?? text;
        if (key.Kind == StoryKeyKind.Variable && (LocalStep(key) || KeptHigher(key, text)))
        {
            return;
        }

        if (key.Kind == StoryKeyKind.Switch && KeptUnlock(key, text))
        {
            return;
        }

        if (Now(key) == text)
        {
            return;
        }

        story[key] = text;
        writes.Add(new KeyValuePair<StoryKey, string>(key, text));
    }

    /// <summary>
    /// Reports whether a variable's step stays the player's own where they stand, as the Queen's
    /// Cup's tournament steps where it plays (the story mapping's local steps).
    /// </summary>
    /// <param name="key">The variable.</param>
    /// <returns>Whether it does.</returns>
    private bool LocalStep(StoryKey key)
    {
        if (x is not { } at || table.LocalSteps.FirstOrDefault(steps => steps.Variable == key.Id) is not { } local)
        {
            return false;
        }

        return local.Steps.Contains(Whole(Now(key)) ?? 0) && local.Places.Any(place => place.Map == map && at >= place.FromX);
    }

    /// <summary>
    /// Reports whether a variable the whole world keeps going only up holds a higher value in the
    /// player's story than the relay handed, which stays and is asked of the relay again: the relay
    /// keeps the highest.
    /// </summary>
    /// <param name="key">The variable.</param>
    /// <param name="text">The relay's value.</param>
    /// <returns>Whether it does.</returns>
    private bool KeptHigher(StoryKey key, string text)
    {
        string? now = Now(key);
        if ((table.ClassOf(key) & WholeOneWay) != WholeOneWay || Whole(now) is not { } own || Whole(text) is not { } value || own <= value)
        {
            return false;
        }

        requests.Add(new StoryWrite(key.ToString(), now!, GameSite));
        return true;
    }

    /// <summary>
    /// Reports whether a switch the game turns on for good is on in the player's story while the
    /// relay handed it off, which stays and goes to the relay: an earlier build kept it each player's
    /// own and never wrote it for the world.
    /// </summary>
    /// <param name="key">The switch.</param>
    /// <param name="text">The relay's value.</param>
    /// <returns>Whether it is.</returns>
    private bool KeptUnlock(StoryKey key, string text)
    {
        if (text != StoryPlain.OffText || !unlocks.Contains(key.Id) || Now(key) != StoryPlain.OnText)
        {
            return false;
        }

        requests.Add(new StoryWrite(key.ToString(), StoryPlain.OnText, GameSite));
        return true;
    }

    /// <summary>
    /// Reads a key's value in the player's story as the lay leaves it.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>The value, <see langword="null"/> for one no story carries.</returns>
    private string? Now(StoryKey key) => story.TryGetValue(key, out string? text) ? text : DefaultOf(key);

    /// <summary>
    /// Tells a key's value before the game wrote it.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Off, or 0 for a variable.</returns>
    private static string DefaultOf(StoryKey key) => key.Kind == StoryKeyKind.Variable ? NoNumber : StoryPlain.OffText;

    /// <summary>
    /// Reads a variable's value as a whole number.
    /// </summary>
    /// <param name="text">The value as the tracks keep it.</param>
    /// <returns>The number, <see langword="null"/> for any other value.</returns>
    private static long? Whole(string? text) =>
        text is ['n', .. var digits] && long.TryParse(digits, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long number) ? number : null;
}
