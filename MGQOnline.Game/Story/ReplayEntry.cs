//----------------------------------------------------------------
//  ReplayEntry.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the number its track keeps an entry under
//                            - Wrote inputs apart from their entry
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// Where a run started, named as story_keys.rbx names a write's site: a map event's page,
/// <c>map:&lt;map&gt;:&lt;event&gt;:&lt;page from 1&gt;</c>, or an autorun or parallel common event,
/// <c>ce:&lt;id&gt;</c>.
/// </summary>
/// <param name="MapId">The page's map, 0 for a common event.</param>
/// <param name="EventId">The page's event, 0 for a common event.</param>
/// <param name="PageNo">The page's place from 0, 0 for a common event.</param>
/// <param name="CommonId">The common event, 0 for a page.</param>
public readonly record struct ReplaySite(int MapId, int EventId, int PageNo, int CommonId)
{
    /// <summary>
    /// Gets whether the site is a common event's.
    /// </summary>
    public bool IsCommon => CommonId > 0;

    /// <summary>
    /// Makes a page's site.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="pageNo">The page's place from 0.</param>
    /// <returns>The site.</returns>
    public static ReplaySite Page(int map, int eventId, int pageNo) => new(map, eventId, pageNo, 0);

    /// <summary>
    /// Reads a site as the scripts name it.
    /// </summary>
    /// <param name="text">The site, such as "map:215:27:1" or "ce:129".</param>
    /// <returns>The site.</returns>
    /// <exception cref="RubyValueException">The text names no page and no common event.</exception>
    public static ReplaySite Parse(string text)
    {
        string[] parts = (text ?? string.Empty).Split(':');
        if (parts.Length == 2 && parts[0] == "ce" && Positive(parts[1], out int common))
        {
            return new ReplaySite(0, 0, 0, common);
        }

        if (parts.Length == 4 && parts[0] == "map" && Positive(parts[1], out int map) && Positive(parts[2], out int eventId) && Positive(parts[3], out int page))
        {
            return Page(map, eventId, page - 1);
        }

        throw new RubyValueException($"{text} names no page and no common event.");
    }

    /// <summary>
    /// Writes the site as the scripts name it.
    /// </summary>
    /// <returns>Such as "map:215:27:1" or "ce:129".</returns>
    public override string ToString() => IsCommon
        ? string.Create(CultureInfo.InvariantCulture, $"ce:{CommonId}")
        : string.Create(CultureInfo.InvariantCulture, $"map:{MapId}:{EventId}:{PageNo + 1}");

    /// <summary>
    /// Reads a whole number above 0.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <param name="number">Receives the number.</param>
    /// <returns>Whether the text is one.</returns>
    private static bool Positive(string text, out int number) =>
        int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out number) && number > 0;
}

/// <summary>
/// How far a story is: the story markers (<c>STORY_MARKERS</c> in coop_story.rbx), the main story's
/// progress and the three routes'.
/// </summary>
/// <param name="Markers">The values, one per marker.</param>
public sealed record RunPlace(IReadOnlyList<long> Markers)
{
    /// <summary>
    /// The variables of the story markers.
    /// </summary>
    public static readonly IReadOnlyList<int> MarkerVariables = [1001, 1141, 1142, 1143];

    /// <summary>
    /// Tells whether the place lies behind another: none of its markers higher, one lower, as
    /// coop_story.rbx <c>behind?</c> orders stories.
    /// </summary>
    /// <param name="other">The other place.</param>
    /// <returns>Whether it does.</returns>
    public bool Behind(RunPlace other)
    {
        ArgumentNullException.ThrowIfNull(other);
        bool lower = false;
        for (int index = 0; index < MarkerVariables.Count; index++)
        {
            long own = Marker(index);
            long theirs = other.Marker(index);
            if (own > theirs)
            {
                return false;
            }

            lower |= own < theirs;
        }

        return lower;
    }

    /// <summary>
    /// Makes the place with one marker lowered to a value, or the place itself when it is not higher.
    /// </summary>
    /// <param name="index">The marker's place among <see cref="MarkerVariables"/>.</param>
    /// <param name="value">The value.</param>
    /// <returns>The place.</returns>
    public RunPlace Lowered(int index, long value)
    {
        if (Marker(index) <= value)
        {
            return this;
        }

        long[] markers = [.. Enumerable.Range(0, MarkerVariables.Count).Select(Marker)];
        markers[index] = value;
        return new RunPlace(markers);
    }

    /// <summary>
    /// Reads a marker, 0 where the place holds none.
    /// </summary>
    /// <param name="index">The marker's place among <see cref="MarkerVariables"/>.</param>
    /// <returns>Its value.</returns>
    public long Marker(int index) => index < Markers.Count ? Markers[index] : 0;
}

/// <summary>
/// One input of the opener's run, which a replay answers with: a choice, number or item input's
/// answer, a random draw, a read of the player's position, the timer or a key, or a battle's outcome.
/// </summary>
/// <param name="At">The command's site and place, as the scripts name it.</param>
/// <param name="Occurrence">How often the command ran before in the run, from 0.</param>
/// <param name="Kind">What was read, such as "choice", "rand" or "battle".</param>
/// <param name="Value">The result.</param>
public sealed record ReplayInput(string At, int Occurrence, string Kind, long Value);

/// <summary>
/// One run handed over: the event itself, its player's inputs and the shared values it started
/// from, which each receiver's own game plays again ("Issue 73 chest effects.md", "Streams, logs and
/// catch-up").
/// </summary>
/// <param name="Id">The entry's id, unique among every game's entries.</param>
/// <param name="Site">Where the run started.</param>
/// <param name="Stream">The stream it goes in: a story's or a Classic party's, named by the scripts.</param>
/// <param name="Scope">Why it travels: <see cref="StoryScope.Party"/> for a party key it changed, <see cref="StoryScope.World"/> for a world key.</param>
/// <param name="Opener">The name of the player whose run it is, <see langword="null"/> for an entry with no opener run.</param>
/// <param name="Keys">The party and world keys the run changed, each with its value before the run.</param>
/// <param name="Place">How far the opener's story was at the run's start, <see langword="null"/> for none known.</param>
/// <param name="Start">The run's start values of every world and work key any page of its event can read.</param>
/// <param name="Inputs">The opener's inputs, in their order.</param>
/// <param name="Derived">Whether no opener run made it, so a battle in it counts as won.</param>
public sealed record ReplayEntry(
    string Id,
    ReplaySite Site,
    string Stream,
    StoryScope Scope,
    string? Opener,
    IReadOnlyDictionary<StoryKey, string> Keys,
    RunPlace? Place,
    IReadOnlyDictionary<StoryKey, string> Start,
    IReadOnlyList<ReplayInput> Inputs,
    bool Derived)
{
    /// <summary>
    /// The stream of the entries no opener run made, which the player's own history and the features
    /// with their own trigger hand them.
    /// </summary>
    public const string DerivedStream = "derived";

    /// <summary>
    /// Gets the number its track keeps it under, <see langword="null"/> for an entry of no track.
    /// </summary>
    public long? Number { get; init; }

    /// <summary>
    /// Makes the entry of a page the player's own history or a feature names, which has no opener
    /// run: it starts from the player's current values, with the keys that close the page read as
    /// off where a replay reads them at its start values, and its step is those keys.
    /// </summary>
    /// <param name="site">The page.</param>
    /// <param name="closes">The keys that close it.</param>
    /// <param name="inView">Tells whether a replay reads a key at its start value: a world or work key.</param>
    /// <returns>The entry, whose id names its site, so it is taken at most once.</returns>
    public static ReplayEntry Derive(ReplaySite site, IReadOnlyCollection<StoryKey> closes, Func<StoryKey, bool> inView)
    {
        ArgumentNullException.ThrowIfNull(closes);
        ArgumentNullException.ThrowIfNull(inView);
        var keys = closes.Distinct().ToDictionary(key => key, _ => "0");
        var start = keys.Keys.Where(inView).ToDictionary(key => key, _ => "0");
        return new ReplayEntry($"{DerivedStream}:{site}", site, DerivedStream, start.Count > 0 ? StoryScope.World : StoryScope.Party, null, keys, null, start, [], true);
    }

    /// <summary>
    /// Reads an entry as the scripts and the save hold it, see <see cref="Write"/>.
    /// </summary>
    /// <param name="value">The entry.</param>
    /// <returns>The entry.</returns>
    /// <exception cref="RubyValueException">A field is missing or of another kind.</exception>
    public static ReplayEntry Read(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        RubyHash entry = value.AsHash();
        string id = entry["id"].AsText();
        if (id.Length == 0)
        {
            throw new RubyValueException("An entry has no id.");
        }

        StoryScope scope = entry["scope"].AsText() switch
        {
            "party" => StoryScope.Party,
            "world" => StoryScope.World,
            string other => throw new RubyValueException($"An entry travels for no scope {other}."),
        };
        return new ReplayEntry(id, ReplaySite.Parse(entry["site"].AsText()), entry["stream"].AsText(), scope,
            entry["opener"].IsNil ? null : entry["opener"].AsText(), KeysOf(entry["keys"]), PlaceOf(entry["place"]), KeysOf(entry["start"]),
            InputsOf(entry["inputs"]), entry["derived"] is RubyBool { Flag: true })
        {
            Number = entry["n"].IsNil ? null : entry["n"].AsLong(),
        };
    }

    /// <summary>
    /// Writes the entry as the scripts and the save hold it.
    /// </summary>
    /// <returns>{"id", "site", "stream", "scope" ("party" or "world"), "opener" (nil for none), "keys" (key => value before), "place" ([markers] or nil), "start" (key => value), "inputs" ([[at, occurrence, kind, value], ...]), "derived", and "n" for an entry of a track}.</returns>
    public RubyHash Write()
    {
        RubyHash written = Fields();
        if (Number is { } number)
        {
            written.Add("n", number);
        }

        return written;
    }

    /// <summary>
    /// Writes the fields every entry has.
    /// </summary>
    /// <returns>The fields, see <see cref="Write"/>.</returns>
    private RubyHash Fields() => new()
    {
        { "id", Id },
        { "site", Site.ToString() },
        { "stream", Stream },
        { "scope", Scope == StoryScope.Party ? "party" : "world" },
        { "opener", Opener },
        { "keys", HashOf(Keys) },
        { "place", PlaceText(Place) },
        { "start", HashOf(Start) },
        { "inputs", InputsArray(Inputs) },
        { "derived", Derived },
    };

    /// <summary>
    /// Writes inputs as an entry holds them.
    /// </summary>
    /// <param name="inputs">The inputs, in their order.</param>
    /// <returns>[[at, occurrence, kind, value], ...].</returns>
    public static RubyArray InputsArray(IEnumerable<ReplayInput> inputs) =>
        new(inputs.Select(input => (RubyValue)new RubyArray { input.At, input.Occurrence, input.Kind, input.Value }));

    /// <summary>
    /// Reads inputs.
    /// </summary>
    /// <param name="value">[[at, occurrence, kind, value], ...], nil for none.</param>
    /// <returns>The inputs, in their order.</returns>
    /// <exception cref="RubyValueException">An input is no such four.</exception>
    public static IReadOnlyList<ReplayInput> InputsOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value.IsNil ? [] : [.. value.AsArray().Select(input => input.AsArray() is { Count: 4 } fields
            ? new ReplayInput(fields[0].AsText(), fields[1].AsInt(), fields[2].AsText(), fields[3].AsLong())
            : throw new RubyValueException("An input is [at, occurrence, kind, value]."))];
    }

    /// <summary>
    /// Reads keys and their values.
    /// </summary>
    /// <param name="value">{key => value}, nil for none.</param>
    /// <returns>The keys.</returns>
    /// <exception cref="RubyValueException">A key is none the tracks name.</exception>
    public static Dictionary<StoryKey, string> KeysOf(RubyValue value)
    {
        var keys = new Dictionary<StoryKey, string>();
        if (value.IsNil)
        {
            return keys;
        }

        foreach ((RubyValue name, RubyValue text) in value.AsHash())
        {
            keys[StoryKey.TryParse(name.AsText(), out StoryKey key) ? key : throw new RubyValueException($"{name.AsText()} is no story key.")] = text.AsText();
        }

        return keys;
    }

    /// <summary>
    /// Writes keys and their values in the order of their names.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <returns>{key => value}.</returns>
    public static RubyHash HashOf(IReadOnlyDictionary<StoryKey, string> keys)
    {
        var hash = new RubyHash();
        foreach ((string name, string text) in keys.Select(pair => (pair.Key.ToString(), pair.Value)).OrderBy(pair => pair.Item1, StringComparer.Ordinal))
        {
            hash.Add(name, text);
        }

        return hash;
    }

    /// <summary>
    /// Reads a place.
    /// </summary>
    /// <param name="value">[markers], nil for none.</param>
    /// <returns>The place, <see langword="null"/> for none.</returns>
    public static RunPlace? PlaceOf(RubyValue value) => value.IsNil ? null : new RunPlace([.. value.AsArray().Select(marker => marker.AsLong())]);

    /// <summary>
    /// Writes a place.
    /// </summary>
    /// <param name="place">The place, <see langword="null"/> for none.</param>
    /// <returns>[markers], nil for none.</returns>
    public static RubyValue PlaceText(RunPlace? place) => place is null ? RubyNil.Value : new RubyArray(place.Markers.Select(marker => (RubyValue)marker));
}
