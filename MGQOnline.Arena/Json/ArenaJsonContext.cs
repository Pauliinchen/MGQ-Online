//----------------------------------------------------------------
//  ArenaJsonContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Added the battle plan and dropped the mark gifts
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Json;

/// <summary>
/// The source-generated JSON contract of the runtime model and the battle events: camelCase, enums as
/// lowerCamel strings, nulls left out, unknown members refused.
/// </summary>
/// <remarks>Polymorphic types may carry their <c>type</c> anywhere in an object, because canonical JSON
/// sorts the keys.</remarks>
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    AllowOutOfOrderMetadataProperties = true,
    RespectNullableAnnotations = true,
    RespectRequiredConstructorParameters = true,
    NumberHandling = JsonNumberHandling.Strict)]
[JsonSerializable(typeof(RuntimeDesign))]
[JsonSerializable(typeof(RuntimeSource))]
[JsonSerializable(typeof(GameRules))]
[JsonSerializable(typeof(RuntimeCatalog))]
[JsonSerializable(typeof(RuntimeTier))]
[JsonSerializable(typeof(RuntimeBoss))]
[JsonSerializable(typeof(RuntimeCustomSkill))]
[JsonSerializable(typeof(RuntimeSkill))]
[JsonSerializable(typeof(RuntimeAction))]
[JsonSerializable(typeof(RuntimePlan))]
[JsonSerializable(typeof(RuntimeStage))]
[JsonSerializable(typeof(RuntimeState))]
[JsonSerializable(typeof(RuntimeMap))]
[JsonSerializable(typeof(RuntimeTileset))]
[JsonSerializable(typeof(RuleSpec))]
[JsonSerializable(typeof(TriggerSpec))]
[JsonSerializable(typeof(ConditionSpec))]
[JsonSerializable(typeof(EffectSpec))]
[JsonSerializable(typeof(ActionCondition))]
[JsonSerializable(typeof(FormulaSpec))]
[JsonSerializable(typeof(SkillRef))]
[JsonSerializable(typeof(BattleEvent))]
[JsonSerializable(typeof(IReadOnlyList<BattleEvent>))]
public sealed partial class ArenaJsonContext : JsonSerializerContext
{
}
