//----------------------------------------------------------------
//  StoryIds.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Held the transfer map, the warp ban and the story ids of the catch-up rules
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Story;

/// <summary>
/// The one table of the story's ids: the variables and switches the story's progress, sides and
/// routes are told by, the steps of the main story's progress the parts and the Great Decision lie
/// at, the common events, maps and places of the routes' rules and the catch-up's rules, the
/// variables the game uses as a place and the warp ban. The scripts read it through the bridge topic <c>story.ids</c>, the relay through
/// Relay/core/story_ids.json, which the generator's <c>story-ids</c> command writes from
/// <see cref="Entries"/>.
/// </summary>
public static class StoryIds
{
    /// <summary>
    /// The variable of the main story's progress.
    /// </summary>
    public const int MainProgress = 1001;

    /// <summary>
    /// The variable that picks where a game over returns the player.
    /// </summary>
    public const int GameOverReturn = 1002;

    /// <summary>
    /// The variable of the playthrough's count, 0 on the first.
    /// </summary>
    public const int Playthrough = 912;

    /// <summary>
    /// The variable of the Great Decision's own progress.
    /// </summary>
    public const int DecisionProgress = 1140;

    /// <summary>
    /// The first switch of the story's band, which brings companions.
    /// </summary>
    public const int FirstStorySwitch = 1001;

    /// <summary>
    /// The last switch of the story's band.
    /// </summary>
    public const int LastStorySwitch = 2000;

    /// <summary>
    /// The main story's progress the choice of a side in Iliasville leaves.
    /// </summary>
    public const int SideStep = 7;

    /// <summary>
    /// The main story's progress from which Part 2 runs, set by Tartarus Escape.
    /// </summary>
    public const int PartTwo = 19;

    /// <summary>
    /// The main story's progress <see cref="OrbEvent"/> sets once the player holds every orb of Part 2.
    /// </summary>
    public const int OrbsGathered = 32;

    /// <summary>
    /// The main story's progress from which Part 3 runs, set by the Middle Chapter's epilogue.
    /// </summary>
    public const int PartThree = 34;

    /// <summary>
    /// The main story's progress right before the Great Decision, which a return from a route sets.
    /// </summary>
    public const int BeforeDecision = 39;

    /// <summary>
    /// The main story's progress the Great Decision sets, which every event that takes a route sets too.
    /// </summary>
    public const int GreatDecision = 40;

    /// <summary>
    /// The Chaos route's progress from the Pocket Castle's revival on, whose regions the world plays in
    /// an order of its own.
    /// </summary>
    public const int ChaosFreeOrder = 21;

    /// <summary>
    /// The common event that moves the story on once the player holds every orb of Part 2.
    /// </summary>
    public const int OrbEvent = 330;

    /// <summary>
    /// The common event of the Great Decision.
    /// </summary>
    public const int DecisionEvent = 380;

    /// <summary>
    /// The game's own reset of the Final Chapter, the shared half of a return to the Great Decision.
    /// </summary>
    public const int FinalResetEvent = 154;

    /// <summary>
    /// The Reaper's reset menu after a route's credits.
    /// </summary>
    public const int ResetEvent = 265;

    /// <summary>
    /// The Reaper's offer in Hades to reset time, which calls <see cref="ResetEvent"/>.
    /// </summary>
    public const int ReaperEvent = 149;

    /// <summary>
    /// The variable the game's transfer script reads the next transfer's map from, as the game's own
    /// returns use it.
    /// </summary>
    public const int TransferMap = 57;

    /// <summary>
    /// The switch that bans warping and the Pocket Castle ("Warp OFF Switch"), which a world keeps off.
    /// </summary>
    public const int WarpBan = 100;

    /// <summary>
    /// The switches of the side the player took along in Iliasville: Alice's, then Ilias's.
    /// </summary>
    public static readonly IReadOnlyList<int> SideSwitches = [4, 5];

    /// <summary>
    /// The routes as the relay names them, in the order of the Great Decision's outcomes.
    /// </summary>
    public static readonly IReadOnlyList<string> Routes = ["ad", "mr", "chaos"];

    /// <summary>
    /// The variables of the routes' progress, in the order of <see cref="Routes"/>.
    /// </summary>
    public static readonly IReadOnlyList<int> RouteVariables = [1141, 1142, 1143];

    /// <summary>
    /// The switches that tell a route was cleared, in the order of <see cref="Routes"/>.
    /// </summary>
    public static readonly IReadOnlyList<int> ClearSwitches = [7096, 7097, 7039];

    /// <summary>
    /// The story markers, whose values tell how far a story is: the main story's progress, then the
    /// routes'.
    /// </summary>
    public static readonly IReadOnlyList<int> Markers = [MainProgress, .. RouteVariables];

    /// <summary>
    /// The switches of the Monster Lord's Castle's bosses, which end Part 3 with the main story's progress.
    /// </summary>
    public static readonly IReadOnlyList<int> CastleBosses = [2485, 2486, 2487];

    /// <summary>
    /// The variables of the areas' progress that move the story on besides the markers.
    /// </summary>
    public static readonly IReadOnlyList<int> AreaProgress = [1003, 1011, 1019, 1021, 1032, 1052, 1063, 1075, 1076, 1136, 1137, 1138, 1139];

    /// <summary>
    /// The game's returns to the Great Decision, with Alice's side and with Ilias's.
    /// </summary>
    public static readonly IReadOnlyList<int> ReturnEvents = [267, 268];

    /// <summary>
    /// The values of <see cref="GameOverReturn"/> past the Great Decision, by the side the route takes.
    /// </summary>
    public static readonly IReadOnlyList<int> ReturnPoints = [111, 112];

    /// <summary>
    /// The maps the Great Decision's two first outcomes go on to, by outcome.
    /// </summary>
    public static readonly IReadOnlyList<int> DecisionMaps = [430, 431];

    /// <summary>
    /// Where a return to the Great Decision takes the player: map, x and y.
    /// </summary>
    public static readonly IReadOnlyList<int> DecisionPlace = [407, 25, 25];

    /// <summary>
    /// Where the Great Decision's third way takes the player: map, x, y and direction.
    /// </summary>
    public static readonly IReadOnlyList<int> ChaosStart = [437, 12, 12, 0];

    /// <summary>
    /// The variables the game uses as a place, which stay each player's own: those a command reads
    /// as a place or writes a character's position or a map's id into, the next transfer's map the
    /// game's transfer script reads, and the game over's return point.
    /// </summary>
    /// <remarks>
    /// The mapping check (MappingCheckTests) derives the same list from the events database.
    /// </remarks>
    public static readonly IReadOnlyList<int> PlaceVariables = [11, 21, 22, 23, 28, 53, 54, TransferMap, GameOverReturn];

    /// <summary>
    /// Lists the table by the names the scripts and the relay read it by, in a fixed order: each
    /// value a whole number or a list of whole numbers or names.
    /// </summary>
    public static IReadOnlyList<KeyValuePair<string, object>> Entries { get; } =
    [
        new("main_progress", MainProgress),
        new("game_over_return", GameOverReturn),
        new("playthrough", Playthrough),
        new("decision_progress", DecisionProgress),
        new("story_switches", new[] { FirstStorySwitch, LastStorySwitch }),
        new("side_step", SideStep),
        new("part_two", PartTwo),
        new("orbs_gathered", OrbsGathered),
        new("part_three", PartThree),
        new("before_decision", BeforeDecision),
        new("great_decision", GreatDecision),
        new("chaos_free_order", ChaosFreeOrder),
        new("orb_event", OrbEvent),
        new("decision_event", DecisionEvent),
        new("final_reset_event", FinalResetEvent),
        new("reset_event", ResetEvent),
        new("reaper_event", ReaperEvent),
        new("side_switches", SideSwitches),
        new("routes", Routes),
        new("route_variables", RouteVariables),
        new("clear_switches", ClearSwitches),
        new("markers", Markers),
        new("castle_bosses", CastleBosses),
        new("area_progress", AreaProgress),
        new("return_events", ReturnEvents),
        new("return_points", ReturnPoints),
        new("decision_maps", DecisionMaps),
        new("decision_place", DecisionPlace),
        new("chaos_start", ChaosStart),
        new("place_variables", PlaceVariables),
        new("transfer_map", TransferMap),
        new("warp_ban", WarpBan),
    ];
}
