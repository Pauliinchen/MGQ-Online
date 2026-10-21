//----------------------------------------------------------------
//  RuntimeAction.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// An entry of an enemy's action list.
/// </summary>
/// <param name="Id">The item id, unique within its boss.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Rating">The rating from 1 to 10; the roll weight is rating × 1024.</param>
/// <param name="Condition">When it may be used.</param>
/// <param name="Scheduled">Whether it is kept out of the roll; its lowered schedule rule is then its only cast.</param>
/// <param name="FollowUp">The skill cast right behind it, or null for none.</param>
public sealed record RuntimeAction(string Id, SkillRef Skill, int Rating, ActionCondition Condition, bool Scheduled, FollowUpSpec? FollowUp = null);

/// <summary>
/// A skill cast right behind an action.
/// </summary>
/// <param name="Skill">The skill.</param>
/// <param name="Side">Which half it is cast on, relative to its parent.</param>
public sealed record FollowUpSpec(SkillRef Skill, FollowUpSide Side);

/// <summary>
/// When an action may be used, by the game's condition types; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(AlwaysActionCondition), "always")]
[JsonDerivedType(typeof(TurnActionCondition), "turn")]
[JsonDerivedType(typeof(HpActionCondition), "hp")]
[JsonDerivedType(typeof(MpActionCondition), "mp")]
[JsonDerivedType(typeof(StateActionCondition), "state")]
[JsonDerivedType(typeof(PartyLevelActionCondition), "partyLevel")]
[JsonDerivedType(typeof(SwitchActionCondition), "switch")]
public abstract record ActionCondition;

/// <summary>
/// Always (the game's type 0).
/// </summary>
public sealed record AlwaysActionCondition : ActionCondition;

/// <summary>
/// On turn A + B·X (the game's type 1); B 0 means turn A alone.
/// </summary>
/// <param name="A">The first turn.</param>
/// <param name="B">The turns between two more.</param>
public sealed record TurnActionCondition(int A, int B) : ActionCondition;

/// <summary>
/// While the user's HP lies between two percents (the game's type 2).
/// </summary>
/// <param name="Min">The lowest percent, 0 to 100.</param>
/// <param name="Max">The highest percent, 0 to 100.</param>
public sealed record HpActionCondition(int Min, int Max) : ActionCondition;

/// <summary>
/// While the user's MP lies between two percents (the game's type 3).
/// </summary>
/// <param name="Min">The lowest percent, 0 to 100.</param>
/// <param name="Max">The highest percent, 0 to 100.</param>
public sealed record MpActionCondition(int Min, int Max) : ActionCondition;

/// <summary>
/// While the user holds a state (the game's type 4).
/// </summary>
/// <param name="State">The state.</param>
public sealed record StateActionCondition(int State) : ActionCondition;

/// <summary>
/// While the party's highest level is at least a level (the game's type 5).
/// </summary>
/// <param name="Level">The level.</param>
public sealed record PartyLevelActionCondition(int Level) : ActionCondition;

/// <summary>
/// While a switch is on (the game's type 6).
/// </summary>
/// <param name="Switch">The switch id.</param>
public sealed record SwitchActionCondition(int Switch) : ActionCondition;
