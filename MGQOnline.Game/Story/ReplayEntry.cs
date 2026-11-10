//----------------------------------------------------------------
//  ReplayEntry.cs
//
//  Changelog:
//      Paulinchen  2026-11-10: Named the entry derived for a page apart from deriving it
//      Paulinchen  2026-11-05: Wrote an entry's keys, start values, site and inputs' places as plain values, and read the texts of a save's entry once
//                            - Read the story markers from StoryIds
//                            - Noted whether a run gave or used up a found item
//                            - Named a battle's drops as a site, and carried the found items they gave
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
/// Where a run started, named as the tracks and the save's log name a site: a map event's page,
/// <c>map:&lt;map&gt;:&lt;event&gt;:&lt;page from 1&gt;</c>, an autorun or parallel common event,
/// <c>ce:&lt;id&gt;</c>, or a battle's drops, <c>game:drop</c>.
/// </summary>
/// <param name="MapId">The page's map, 0 for a common event.</param>
/// <param name="EventId">The page's event, 0 for a common event.</param>
/// <param name="PageNo">The page's place from 0, 0 for a common event.</param>
/// <param name="CommonId">The common event, 0 for a page.</param>
public readonly record struct ReplaySite(int MapId, int EventId, int PageNo, int CommonId)
{
    /// <summary>
    /// The site of a battle's drops, which no event gives.
    /// </summary>
    public static readonly ReplaySite Drop = default;

    /// <summary>
    /// The text of <see cref="Drop"/>.
    /// </summary>
    private const string DropText = "game:drop";

    /// <summary>
    /// Gets whether the site is a common event's.
    /// </summary>
    public bool IsCommon => CommonId > 0;

    /// <summary>
    /// Gets whether the site is a battle's drops.
    /// </summary>
    public bool IsDrop => MapId == 0 && CommonId == 0;

    /// <summary>
    /// Makes a page's site.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="pageNo">The page's place from 0.</param>
    /// <returns>The site.</returns>
    public static ReplaySite Page(int map, int eventId, int pageNo) => new(map, eventId, pageNo, 0);

    /// <summary>
    /// Reads a site as the tracks and the save's log name it.
    /// </summary>
    /// <param name="text">The site, such as "map:215:27:1", "ce:129" or "game:drop".</param>
    /// <returns>The site.</returns>
    /// <exception cref="RubyValueException">The text names no page, no common event and no battle's drops.</exception>
    public static ReplaySite Parse(string text)
    {
        if (text == DropText)
        {
            return Drop;
        }

        string[] parts = (text ?? string.Empty).Split(':');
        if (parts.Length == 2 && parts[0] == "ce" && Positive(parts[1], out int common))
        {
            return new ReplaySite(0, 0, 0, common);
        }

        if (parts.Length == 4 && parts[0] == "map" && Positive(parts[1], out int map) && Positive(parts[2], out int eventId) && Positive(parts[3], out int page))
        {
            return Page(map, eventId, page - 1);
        }

        throw new RubyValueException($"{text} names no page, no common event and no battle's drops.");
    }

    /// <summary>
    /// Reads a site as the scripts hand it over, or its text as a save of an earlier release keeps it.
    /// </summary>
    /// <param name="value">The site, see <see cref="StoryPlain"/>, or its text.</param>
    /// <returns>The site.</returns>
    /// <exception cref="RubyValueException">The value names no page, no common event and no battle's drops.</exception>
    public static ReplaySite Of(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return Parse(value is RubyString ? value.AsText() : StoryPlain.SiteText(value));
    }

    /// <summary>
    /// Writes the site as the scripts take it.
    /// </summary>
    /// <returns>["map", map, event, page from 1], ["ce", id] or ["game", "drop"].</returns>
    public RubyArray Plain() => IsCommon ? ["ce", CommonId] : IsDrop ? ["game", "drop"] : ["map", MapId, EventId, PageNo + 1];

    /// <summary>
    /// Writes the site as the tracks and the save's log name it.
    /// </summary>
    /// <returns>Such as "map:215:27:1", "ce:129" or "game:drop".</returns>
    public override string ToString() => IsCommon
        ? string.Create(CultureInfo.InvariantCulture, $"ce:{CommonId}")
        : IsDrop ? DropText : string.Create(CultureInfo.InvariantCulture, $"map:{MapId}:{EventId}:{PageNo + 1}");

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
    public static readonly IReadOnlyList<int> MarkerVariables = StoryIds.Markers;

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
/// <param name="At">The command's site and place, as the save's log names it, such as "map:1994:42:1@12".</param>
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
    /// Gets whether the run gave or used up a found item, a key item or an item unlocking a job or
    /// a race, which reaches every player even from a run that changed no shared key.
    /// </summary>
    public bool Found { get; init; }

    /// <summary>
    /// Gets the found items a battle's drops gave the opener, each with how many, in their order;
    /// empty for a run of an event.
    /// </summary>
    public IReadOnlyList<KeyValuePair<int, int>> Drops { get; init; } = [];

    /// <summary>
    /// Names the entry derived for a page.
    /// </summary>
    /// <param name="site">The page.</param>
    /// <returns>The id, such as "derived:map:112:7:1".</returns>
    public static string DerivedId(ReplaySite site) => $"{DerivedStream}:{site}";

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
        return new ReplayEntry(DerivedId(site), site, DerivedStream, start.Count > 0 ? StoryScope.World : StoryScope.Party, null, keys, null, start, [], true);
    }

    /// <summary>
    /// Reads an entry as the scripts and the save hold it, see <see cref="Write"/>, or as a save of
    /// an earlier release holds it, its keys and start values as texts by name, its site and its
    /// inputs' places as texts.
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
        return new ReplayEntry(id, ReplaySite.Of(entry["site"]), entry["stream"].AsText(), scope,
            entry["opener"].IsNil ? null : entry["opener"].AsText(), KeysOf(entry["keys"]), PlaceOf(entry["place"]), KeysOf(entry["start"]),
            InputsOf(entry["inputs"]), entry["derived"] is RubyBool { Flag: true })
        {
            Number = entry["n"].IsNil ? null : entry["n"].AsLong(),
            Found = entry["found"] is RubyBool { Flag: true },
            Drops = DropsOf(entry["drops"]),
        };
    }

    /// <summary>
    /// Writes the entry as the scripts and the save hold it.
    /// </summary>
    /// <returns>{"id", "site" (see <see cref="StoryPlain"/>), "stream", "scope" ("party" or "world"), "opener" (nil for none), "keys" (the rows of each key's value before, see <see cref="StoryPlain"/>), "place" ([markers] or nil), "start" (the rows of the start values), "inputs" ([[at, occurrence, kind, value], ...]), "derived", "found" for a found item's run, "drops" ([[item, count], ...]) for a battle's drops, and "n" for an entry of a track}.</returns>
    public RubyHash Write()
    {
        RubyHash written = Fields();
        if (Found)
        {
            written.Add("found", true);
        }

        if (Drops.Count > 0)
        {
            written.Add("drops", new RubyArray(Drops.Select(drop => (RubyValue)new RubyArray { drop.Key, drop.Value })));
        }

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
        { "site", Site.Plain() },
        { "stream", Stream },
        { "scope", Scope == StoryScope.Party ? "party" : "world" },
        { "opener", Opener },
        { "keys", StoryPlain.Rows(Keys) },
        { "place", PlaceText(Place) },
        { "start", StoryPlain.Rows(Start) },
        { "inputs", InputsArray(Inputs) },
        { "derived", Derived },
    };

    /// <summary>
    /// Reads the found items a battle's drops gave.
    /// </summary>
    /// <param name="value">[[item, count], ...], nil for none.</param>
    /// <returns>Each item with how many, in their order.</returns>
    /// <exception cref="RubyValueException">A drop is no such pair.</exception>
    public static IReadOnlyList<KeyValuePair<int, int>> DropsOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value.IsNil ? [] : [.. value.AsArray().Select(drop => drop.AsArray() is { Count: 2 } pair
            ? new KeyValuePair<int, int>(pair[0].AsInt(), pair[1].AsInt())
            : throw new RubyValueException("A drop is [item, count]."))];
    }

    /// <summary>
    /// Writes inputs as an entry holds them.
    /// </summary>
    /// <param name="inputs">The inputs, in their order.</param>
    /// <returns>[[at, occurrence, kind, value], ...], each at a command's place (see <see cref="StoryPlain"/>), or its text where it names none.</returns>
    public static RubyArray InputsArray(IEnumerable<ReplayInput> inputs) =>
        new(inputs.Select(input => (RubyValue)new RubyArray { StoryPlain.PlaceOf(input.At) is RubyArray at ? at : input.At, input.Occurrence, input.Kind, input.Value }));

    /// <summary>
    /// Reads inputs.
    /// </summary>
    /// <param name="value">[[at, occurrence, kind, value], ...], each at a command's place or its text; nil for none.</param>
    /// <returns>The inputs, in their order.</returns>
    /// <exception cref="RubyValueException">An input is no such four.</exception>
    public static IReadOnlyList<ReplayInput> InputsOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value.IsNil ? [] : [.. value.AsArray().Select(input => input.AsArray() is { Count: 4 } fields
            ? new ReplayInput(fields[0] is RubyString ? fields[0].AsText() : StoryPlain.PlaceText(fields[0]), fields[1].AsInt(), fields[2].AsText(), fields[3].AsLong())
            : throw new RubyValueException("An input is [at, occurrence, kind, value]."))];
    }

    /// <summary>
    /// Reads keys and their values: rows as the scripts hand them over, or the texts by name a save's
    /// log keeps, which a save of an earlier release keeps its entries' keys in too.
    /// </summary>
    /// <param name="value">[[kind, key, value], ...] (see <see cref="StoryPlain"/>) or {name => text}; nil for none.</param>
    /// <returns>The keys, with their values as the tracks write them.</returns>
    /// <exception cref="RubyValueException">A key is none the tracks name.</exception>
    public static Dictionary<StoryKey, string> KeysOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        if (value is not RubyHash named)
        {
            return StoryPlain.TextsOf(value);
        }

        var keys = new Dictionary<StoryKey, string>();
        foreach ((RubyValue name, RubyValue text) in named)
        {
            keys[StoryKey.TryParse(name.AsText(), out StoryKey key) ? key : throw new RubyValueException($"{name.AsText()} is no story key.")] = text.AsText();
        }

        return keys;
    }

    /// <summary>
    /// Writes keys and their values in the order of their names, as a save's log keeps them.
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
