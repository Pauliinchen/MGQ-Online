//----------------------------------------------------------------
//  CatchupRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Added the steps of the story in free order to the rules
//                            - Keyed a world chest the game shuts by a switch by that switch
//                            - Added the rewards a party member catches up with, every chest and the chest flags
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// A mark of the story: a key that holds once an event ran, a switch or self switch on, a variable
/// at <paramref name="AtLeast"/> or more.
/// </summary>
/// <param name="Key">The key.</param>
/// <param name="AtLeast">The least value of a variable, 0 for a switch or self switch.</param>
public readonly record struct StoryMark(StoryKey Key, long AtLeast = 0);

/// <summary>
/// Where a row's event stands in the story, as the relay's catch-up tables place it.
/// </summary>
/// <param name="Site">The event's site, such as <c>map:7:60:1</c> or <c>ce:322</c>.</param>
/// <param name="Part">The part, <see langword="null"/> for side content outside the story's order.</param>
/// <param name="Step">The step in the part, <see langword="null"/> where nothing tells it.</param>
/// <param name="Side">The side it asks for, <c>alice</c>, <c>ilias</c> or <see langword="null"/>.</param>
/// <param name="Marks">What holds in the story once its event ran.</param>
public sealed record StoryPlace(string Site, string? Part, long? Step, string? Side, IReadOnlyList<StoryMark> Marks);

/// <summary>
/// A part of the story: its id as the relay names it, its name, the marks that hold right before
/// its ending starts and its level gate.
/// </summary>
/// <param name="Id">The part.</param>
/// <param name="Name">Its name.</param>
/// <param name="Ending">The marks right before its ending.</param>
/// <param name="Gate">The level that moves a player on from it.</param>
public sealed record CatchupPart(string Id, string Name, IReadOnlyList<StoryMark> Ending, int Gate);

/// <summary>
/// A story join of a companion.
/// </summary>
/// <param name="Actor">The companion's main persona.</param>
/// <param name="Persona">The persona the event adds.</param>
/// <param name="Place">Where the join stands.</param>
/// <param name="Gate">The highest base level a player needs.</param>
/// <param name="Rule">The rule that gave the gate: <c>floor</c>, <c>start</c>, <c>cap</c> or <c>kept</c>.</param>
/// <param name="Index">The command's place in its list, which orders it against another row of the list: its ord in the events database.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupJoin(int Actor, int Persona, StoryPlace Place, int Gate, string Rule, int Index, bool Ran);

/// <summary>
/// A removal of a companion by the story.
/// </summary>
/// <param name="Actor">The companion's main persona.</param>
/// <param name="Persona">The persona the event removes.</param>
/// <param name="Place">Where the removal stands.</param>
/// <param name="First">Whether only a first playthrough takes them, for a removal that lasts.</param>
/// <param name="Index">The command's place in its list, which orders it against another row of the list: its ord in the events database.</param>
public sealed record CatchupRemoval(int Actor, int Persona, StoryPlace Place, bool First, int Index);

/// <summary>
/// A key item the story gives (above 0) or takes (below 0).
/// </summary>
/// <param name="Item">The item.</param>
/// <param name="Amount">How many, below 0 taken.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupKeyItem(int Item, int Amount, StoryPlace Place, bool Ran);

/// <summary>
/// A chest that holds key items, which opens once for the whole world.
/// </summary>
/// <param name="Key">The self switch that shuts it, or the switch of a chest the game shuts by a switch.</param>
/// <param name="Items">The items it holds.</param>
/// <param name="Part">The part, <see langword="null"/> for none.</param>
/// <param name="Step">The step, <see langword="null"/> for none.</param>
/// <param name="Flags">The chest flags it turns on for each player.</param>
public sealed record CatchupChest(StoryKey Key, IReadOnlyList<int> Items, string? Part, long? Step, IReadOnlyList<int> Flags);

/// <summary>
/// A skill Luka learns or an item the story and its side quests give.
/// </summary>
/// <param name="Kind"><c>skill</c>, <c>item</c>, <c>weapon</c> or <c>armor</c>.</param>
/// <param name="Id">The skill or item.</param>
/// <param name="Amount">How many, below 0 taken.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupReward(string Kind, int Id, int Amount, StoryPlace Place, bool Ran);

/// <summary>
/// A skill the story teaches a companion's persona.
/// </summary>
/// <param name="Actor">The persona.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupLesson(int Actor, int Skill, StoryPlace Place, bool Ran);

/// <summary>
/// A class or race the story gives a character at a level.
/// </summary>
/// <param name="Actor">The character.</param>
/// <param name="Class">The class or race.</param>
/// <param name="Level">The level.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupClassLevel(int Actor, int Class, int Level, StoryPlace Place, bool Ran);

/// <summary>
/// One call of the game's interpreter an actor change runs.
/// </summary>
/// <param name="Name">The call, such as <c>persona_change</c>.</param>
/// <param name="Numbers">Its whole numbers, the character's persona first.</param>
/// <param name="Once">Whether only a first playthrough runs it.</param>
public sealed record ActorCall(string Name, IReadOnlyList<long> Numbers, bool Once);

/// <summary>
/// What one story event changes of one character by the game's script calls, as the power-ups.
/// </summary>
/// <param name="Actor">The character's main persona.</param>
/// <param name="Calls">The calls in their order.</param>
/// <param name="Gate">The highest level they set, <see langword="null"/> for none.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupActorChange(int Actor, IReadOnlyList<ActorCall> Calls, int? Gate, StoryPlace Place, bool Ran);

/// <summary>
/// A setting of a player's own value by a story event: a variable, a switch, or whether random
/// encounters are on.
/// </summary>
/// <param name="Kind"><c>variable</c>, <c>switch</c> or <c>encounters</c>.</param>
/// <param name="Id">The variable or switch, 0 for the encounters.</param>
/// <param name="On">What a switch or the encounters are set to.</param>
/// <param name="Number">What a variable is set to.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupSetting(string Kind, int Id, bool On, long Number, StoryPlace Place, bool Ran);

/// <summary>
/// An event placed in the story that puts a vehicle on a map.
/// </summary>
/// <param name="Vehicle"><c>boat</c>, <c>ship</c> or <c>airship</c>.</param>
/// <param name="Place">Where the row stands.</param>
/// <param name="Ran">Whether the marks show that the event ran.</param>
public sealed record CatchupVehicle(string Vehicle, StoryPlace Place, bool Ran);

/// <summary>
/// A Makina, the level a player reaches it at and the easiest place that gives it.
/// </summary>
/// <param name="Item">The item.</param>
/// <param name="Level">The level.</param>
/// <param name="Site">The place's site.</param>
public sealed record CatchupMakina(int Item, int Level, string Site);

/// <summary>
/// The least a variable holds once a companion is in the roster, which their own join stands for.
/// </summary>
/// <param name="Actor">The companion's main persona.</param>
/// <param name="Variable">The variable.</param>
/// <param name="AtLeast">The least value.</param>
public sealed record CompanionValue(int Actor, int Variable, long AtLeast);

/// <summary>
/// What a switch adds to a count.
/// </summary>
/// <param name="Switch">The switch.</param>
/// <param name="Weight">What it adds while on.</param>
public sealed record CountWeight(int Switch, int Weight);

/// <summary>
/// A variable that counts switches.
/// </summary>
/// <param name="Variable">The variable.</param>
/// <param name="Weights">What each switch adds.</param>
/// <param name="DoneSwitch">The switch that sets the last value, <see langword="null"/> for none.</param>
/// <param name="DoneValue">The last value, <see langword="null"/> for none.</param>
/// <param name="SinceVariable">The variable that must be at <paramref name="SinceAtLeast"/> or more before the count counts at all, <see langword="null"/> for none.</param>
/// <param name="SinceAtLeast">The least value of <paramref name="SinceVariable"/>.</param>
public sealed record CatchupCount(int Variable, IReadOnlyList<CountWeight> Weights, int? DoneSwitch, long? DoneValue, int? SinceVariable, long SinceAtLeast);

/// <summary>
/// A reward of the game's events a party member catches up with in a Classic world.
/// </summary>
/// <param name="Kind">"skill", "companion", "item", "weapon" or "armor".</param>
/// <param name="Id">The skill, companion or item.</param>
/// <param name="Most">How many of an item the events that move the story on give at most, <see langword="null"/> for a skill or companion.</param>
/// <param name="Sided">Whether it comes only with the events where the sides differ before the Great Decision.</param>
/// <param name="Route">Whether the Final Chapter's events give a sided one too.</param>
/// <param name="Final">Whether only the Final Chapter's events give it, along one route.</param>
public sealed record EventReward(string Kind, int Id, int? Most, bool Sided, bool Route, bool Final);

/// <summary>
/// What one side of a side event gives.
/// </summary>
/// <param name="Skills">The skills.</param>
/// <param name="Companions">The companions.</param>
public sealed record SideRewards(IReadOnlyList<int> Skills, IReadOnlyList<int> Companions);

/// <summary>
/// An event that gives each side other skills or companions before the Great Decision.
/// </summary>
/// <param name="Site">The event.</param>
/// <param name="Alice">What Alice's side gets.</param>
/// <param name="Ilias">What Ilias's side gets.</param>
/// <param name="Choice">Whether the event is where the player chooses a side.</param>
/// <param name="Marks">What each of its pages leaves in the story once it ran.</param>
public sealed record SideEvent(string Site, SideRewards Alice, SideRewards Ilias, bool Choice, IReadOnlyList<IReadOnlyList<StoryMark>> Marks);

/// <summary>
/// The rules of the catch-up that were constants of world_catchup.rbx, each <see langword="null"/>
/// or empty while its row is missing.
/// </summary>
/// <param name="LastingCompanions">The companions none of whose joins is temporary.</param>
/// <param name="Orbs">Part 2's orbs, all of which <paramref name="OrbEvent"/> asks for.</param>
/// <param name="OrbEvent">The common event that moves the story on once the player holds every orb.</param>
/// <param name="OrbsGathered">The main story's step that event sets.</param>
/// <param name="SideStep">The main story's step the choice of a side leaves.</param>
/// <param name="AliceCompanion">The companion Alice's side brings along.</param>
/// <param name="IliasCompanion">The companion Ilias's side brings along.</param>
/// <param name="FreeOrder">The steps of a part whose regions the world plays in an order of its own, which the rows cannot tell.</param>
public sealed record CatchupRules(IReadOnlyList<int> LastingCompanions, IReadOnlyList<int> Orbs, int? OrbEvent, long? OrbsGathered, long? SideStep, int? AliceCompanion, int? IliasCompanion, IReadOnlyList<PartStep> FreeOrder)
{
    /// <summary>
    /// The rules while no row came.
    /// </summary>
    public static readonly CatchupRules Empty = new([], [], null, null, null, null, null, []);
}

/// <summary>
/// A step of a part of the story.
/// </summary>
/// <param name="Part">The part.</param>
/// <param name="Step">The step in it.</param>
public readonly record struct PartStep(string Part, long Step);
