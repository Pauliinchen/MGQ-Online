//----------------------------------------------------------------
//  StoryTable.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Carried the game work keys of the list
//      Paulinchen  2026-10-28: Carried the catch-up tables the mapping came with
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Story;

/// <summary>
/// Steps of a variable that stay each player's own while they stand in one of the places, and that
/// the world keeps as <paramref name="SharedAs"/> (the story mapping's <c>localSteps</c>).
/// </summary>
/// <param name="Variable">The variable.</param>
/// <param name="Steps">The steps.</param>
/// <param name="SharedAs">The step the world keeps for them.</param>
/// <param name="Places">Where they stay the player's own: each map and the x its part starts at.</param>
public sealed record LocalSteps(int Variable, IReadOnlyList<long> Steps, long SharedAs, IReadOnlyList<(int Map, int FromX)> Places);

/// <summary>
/// How every key of the story is shared, as the scripts look it up for each write: one
/// <see cref="StoryClass"/> per switch and per variable, the self switch rules by the most fitting
/// row, and the events whose self switches are shared.
/// </summary>
public sealed class StoryTable
{
    /// <summary>
    /// What an event's place in <see cref="Index"/> is made of: map * EventSpan + event.
    /// </summary>
    public const long EventSpan = 1_000_000;

    /// <summary>
    /// Initializes a table.
    /// </summary>
    /// <param name="rev">The revision it was read at, 0 for a table of the game's own.</param>
    /// <param name="switches">The class of each switch by id.</param>
    /// <param name="variables">The class of each variable by id.</param>
    /// <param name="selfRules">The self switch rules by key: <c>ss&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;</c>, with <c>*</c> for every event or letter, or <c>ce&lt;id&gt;.&lt;letter&gt;</c> for the self switches a common event writes.</param>
    /// <param name="index">The events whose self switches are shared without a rule, see <see cref="EventSpan"/>.</param>
    /// <param name="localSteps">The steps that stay each player's own in places.</param>
    /// <param name="gates">Each part's level gate by its id.</param>
    /// <param name="selfDefault">The class of a self switch no rule and no indexed event names.</param>
    /// <param name="catchup">The catch-up's tables the mapping came with, <see langword="null"/> for none.</param>
    /// <param name="work">The switches and variables the game uses as working values, <see langword="null"/> for none.</param>
    public StoryTable(long rev, byte[] switches, byte[] variables, IReadOnlyDictionary<string, StoryClass> selfRules, IReadOnlySet<long> index,
        IReadOnlyList<LocalSteps> localSteps, IReadOnlyDictionary<string, int> gates, StoryClass selfDefault = StoryClass.Personal, CatchupTables? catchup = null,
        IReadOnlySet<StoryKey>? work = null)
    {
        Work = work ?? new HashSet<StoryKey>();
        SelfDefault = selfDefault;
        Rev = rev;
        Switches = switches;
        Variables = variables;
        SelfRules = selfRules;
        Index = index;
        LocalSteps = localSteps;
        Gates = gates;
        Catchup = catchup ?? CatchupTables.Empty;
    }

    /// <summary>
    /// Gets the revision the table was read at.
    /// </summary>
    public long Rev { get; }

    /// <summary>
    /// Gets the catch-up's tables the mapping came with, empty for a table of the game's own.
    /// </summary>
    public CatchupTables Catchup { get; }

    /// <summary>
    /// Gets the switches and variables the game uses as working values (the <c>work</c> option of a
    /// personal row), each player's own by their class.
    /// </summary>
    public IReadOnlySet<StoryKey> Work { get; }

    /// <summary>
    /// Gets the class of each switch by id; an id past the end is each player's own.
    /// </summary>
    public byte[] Switches { get; }

    /// <summary>
    /// Gets the class of each variable by id; an id past the end is each player's own.
    /// </summary>
    public byte[] Variables { get; }

    /// <summary>
    /// Gets the self switch rules by key.
    /// </summary>
    public IReadOnlyDictionary<string, StoryClass> SelfRules { get; }

    /// <summary>
    /// Gets the events whose self switches are shared without a rule.
    /// </summary>
    public IReadOnlySet<long> Index { get; }

    /// <summary>
    /// Gets the steps that stay each player's own in places.
    /// </summary>
    public IReadOnlyList<LocalSteps> LocalSteps { get; }

    /// <summary>
    /// Gets each part's level gate by its id.
    /// </summary>
    public IReadOnlyDictionary<string, int> Gates { get; }

    /// <summary>
    /// Gets the class of a self switch no rule and no indexed event names: each player's own by the
    /// story mapping, shared in a Classic party.
    /// </summary>
    public StoryClass SelfDefault { get; }

    /// <summary>
    /// Finds how a key is shared, as the relay's <c>TrackRules.kindOf</c> does: a switch or variable
    /// by its own class, a self switch by the most fitting rule (its own, its event's, the common
    /// event's that wrote it, its map's letter's, its map's), else shared when the index names its
    /// event, else <see cref="SelfDefault"/>; a frozen fight is the whole world's.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="site">Where the write came from, which a common event's rule reads; <see langword="null"/> for none.</param>
    /// <returns>The class.</returns>
    public StoryClass ClassOf(StoryKey key, string? site = null)
    {
        switch (key.Kind)
        {
            case StoryKeyKind.Freeze:
                return StoryClass.Kept | StoryClass.WholeWorld;
            case StoryKeyKind.Switch:
                return key.Id < Switches.Length ? (StoryClass)Switches[key.Id] : StoryClass.Personal;
            case StoryKeyKind.Variable:
                return key.Id < Variables.Length ? (StoryClass)Variables[key.Id] : StoryClass.Personal;
        }

        string? common = site is not null && site.StartsWith("ce:", StringComparison.Ordinal) ? site[3..] : null;
        string map = key.Id.ToString(CultureInfo.InvariantCulture);
        string eventId = key.Event.ToString(CultureInfo.InvariantCulture);
        string[] named = common is null
            ? [$"ss{map}.{eventId}.{key.Letter}", $"ss{map}.{eventId}.*", $"ss{map}.*.{key.Letter}", $"ss{map}.*.*"]
            : [$"ss{map}.{eventId}.{key.Letter}", $"ss{map}.{eventId}.*", $"ce{common}.{key.Letter}", $"ce{common}.*", $"ss{map}.*.{key.Letter}", $"ss{map}.*.*"];
        foreach (string name in named)
        {
            if (SelfRules.TryGetValue(name, out StoryClass found))
            {
                return found;
            }
        }

        return Index.Contains((key.Id * EventSpan) + key.Event) ? StoryClass.Kept : SelfDefault;
    }
}
