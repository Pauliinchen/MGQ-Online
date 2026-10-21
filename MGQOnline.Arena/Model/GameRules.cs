//----------------------------------------------------------------
//  GameRules.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The game rule of the arena, typed from the design's rules entity.
/// </summary>
/// <param name="Grid">The grid limits.</param>
/// <param name="Tiers">The game rule per tier, which tier entities override.</param>
/// <param name="Units">The party limits.</param>
/// <param name="Ap">The action point rules.</param>
/// <param name="Power">The area sizes by rank and power.</param>
/// <param name="Share">The game rule of shared single hits.</param>
/// <param name="Kinds">How skills map to kinds.</param>
/// <param name="CrowdControl">The crowd control rules.</param>
/// <param name="Debris">The debris rules.</param>
/// <param name="Presentation">The presentation defaults.</param>
/// <param name="Limits">The value limits.</param>
public sealed record GameRules(
    GridRules Grid,
    IReadOnlyDictionary<int, TierRule> Tiers,
    UnitRules Units,
    ApRules Ap,
    PowerRules Power,
    ShareRules Share,
    KindRules Kinds,
    CrowdControlRules CrowdControl,
    DebrisRules Debris,
    PresentationRules Presentation,
    LimitRules Limits);

/// <summary>
/// The grid limits.
/// </summary>
/// <param name="Min">The smallest grid.</param>
/// <param name="Max">The largest grid, from which the shape limits derive.</param>
/// <param name="NoTier">The grid of bosses without a tier.</param>
/// <param name="GrowRatio">How much the grid grows for a large party.</param>
public sealed record GridRules(GridSize Min, GridSize Max, GridSize NoTier, double GrowRatio);

/// <summary>
/// The game rule of one tier.
/// </summary>
/// <param name="Grid">The grid.</param>
/// <param name="Ap">The action points per turn.</param>
/// <param name="Stats">The stat factors.</param>
public sealed record TierRule(GridSize Grid, int Ap, StatFactors Stats);

/// <summary>
/// The party limits.
/// </summary>
/// <param name="Cap">The most units in a battle.</param>
public sealed record UnitRules(int Cap);

/// <summary>
/// The action point rules.
/// </summary>
/// <param name="NoTier">The points of bosses without a tier.</param>
/// <param name="Min">The fewest points per turn.</param>
/// <param name="Max">The most points per turn.</param>
/// <param name="Cost">The cost limits of a skill.</param>
/// <param name="ActionPlusFeature">The feature code whose values add points.</param>
/// <param name="ActionMinusFeature">The feature code whose values take points away.</param>
/// <param name="UseWeightPermille">What a use leaves of a skill's weight, in permille.</param>
/// <param name="BankTurns">How many turns' points a boss may bank.</param>
/// <param name="NormalAttackWeight">The roll weight of the normal attack, on the scale of rating × 1024.</param>
public sealed record ApRules(
    int NoTier,
    int Min,
    int Max,
    ApCostRules Cost,
    int ActionPlusFeature,
    int ActionMinusFeature,
    int UseWeightPermille,
    int BankTurns,
    int NormalAttackWeight);

/// <summary>
/// The cost limits of a skill.
/// </summary>
/// <param name="Default">The cost without a design.</param>
/// <param name="Min">The lowest cost.</param>
/// <param name="Max">The highest cost.</param>
public sealed record ApCostRules(int Default, int Min, int Max);

/// <summary>
/// The area sizes by rank and power.
/// </summary>
/// <param name="Ranks">The ranks from lowest to highest.</param>
/// <param name="RankSizes">The size per rank.</param>
/// <param name="PowerSizes">The sizes by least power, highest first.</param>
/// <param name="SmallSize">The size of a small skill.</param>
/// <param name="PowerlessSize">The size of a skill without power.</param>
/// <param name="WholeSize">The size that covers the whole grid.</param>
/// <param name="PowerPerFactor">The power one formula factor counts.</param>
public sealed record PowerRules(
    IReadOnlyList<string> Ranks,
    IReadOnlyDictionary<string, int> RankSizes,
    IReadOnlyList<PowerSize> PowerSizes,
    int SmallSize,
    int PowerlessSize,
    int WholeSize,
    int PowerPerFactor);

/// <summary>
/// The game rule of shared single hits.
/// </summary>
/// <param name="Range">How far sharers stand at most.</param>
/// <param name="Max">How many share at most.</param>
public sealed record ShareRules(int Range, int Max);

/// <summary>
/// How skills map to kinds.
/// </summary>
/// <param name="DamagingTypes">The damage types that deal damage.</param>
/// <param name="ExtensionKinds">What each target extension kind turns a skill into.</param>
/// <param name="PlusAttackKinds">The target extension kinds that add attacks.</param>
public sealed record KindRules(IReadOnlyList<int> DamagingTypes, IReadOnlyDictionary<int, ExtensionKind> ExtensionKinds, IReadOnlyList<int> PlusAttackKinds);

/// <summary>
/// The crowd control rules.
/// </summary>
/// <param name="HardCcRestriction">The restriction from which a state is hard crowd control.</param>
/// <param name="NeverHardCc">The states that never are.</param>
/// <param name="RedirectRestrictions">The restrictions that redirect actions.</param>
/// <param name="DisablesDefault">The entries a hard crowd control state disables without a design.</param>
/// <param name="DisablesMin">The fewest entries it disables.</param>
/// <param name="DisablesMax">The most entries it disables.</param>
/// <param name="MidTurnDisables">The entries a state added mid-turn disables.</param>
/// <param name="TurnsMin">The fewest turns a state's design may set.</param>
/// <param name="TurnsMax">The most turns a state's design may set.</param>
public sealed record CrowdControlRules(
    int HardCcRestriction,
    IReadOnlyList<int> NeverHardCc,
    IReadOnlyList<int> RedirectRestrictions,
    int DisablesDefault,
    int DisablesMin,
    int DisablesMax,
    int MidTurnDisables,
    int TurnsMin,
    int TurnsMax);

/// <summary>
/// The debris rules.
/// </summary>
/// <param name="FreeCellsPerCharacter">The free cells kept per character.</param>
/// <param name="FallbackFloor">The floor tile without one of the map's.</param>
/// <param name="FallbackDebris">The debris tile without one of the map's.</param>
/// <param name="Random">The random debris without a tier's.</param>
public sealed record DebrisRules(int FreeCellsPerCharacter, TileRef FallbackFloor, TileRef FallbackDebris, RandomDebris Random);

/// <summary>
/// The presentation defaults.
/// </summary>
/// <param name="RingDelay">The frames between two rings.</param>
/// <param name="PulseGap">The frames between two pulses.</param>
/// <param name="Animation">The animation defaults.</param>
/// <param name="Danger">The telegraph colours.</param>
public sealed record PresentationRules(int RingDelay, int PulseGap, AnimationRules Animation, DangerRules Danger);

/// <summary>
/// The animation defaults by skill kind.
/// </summary>
/// <param name="Area">The default of area skills.</param>
/// <param name="Single">The default of single hits.</param>
/// <param name="Opacity">The opacity in percent.</param>
/// <param name="Flash">The flash strength in percent.</param>
public sealed record AnimationRules(AnimationDefault Area, AnimationDefault Single, int Opacity, int Flash);

/// <summary>
/// Where and how a kind's animation plays by default.
/// </summary>
/// <param name="Placement">Where it plays.</param>
/// <param name="Screen">How a screen animation is sized.</param>
public sealed record AnimationDefault(AnimationPlacement Placement, AnimationScreen Screen);

/// <summary>
/// The telegraph colours.
/// </summary>
/// <param name="NoElement">The colour of skills without an element.</param>
/// <param name="Elements">The colour per element id.</param>
public sealed record DangerRules(ColorRgba NoElement, IReadOnlyDictionary<int, ColorRgba> Elements);

/// <summary>
/// The value limits.
/// </summary>
/// <param name="PercentMax">The highest percent a design may set.</param>
public sealed record LimitRules(int PercentMax);
