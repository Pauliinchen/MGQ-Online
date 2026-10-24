//----------------------------------------------------------------
//  SkillEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Dropped how long a mark lasts
//      Paulinchen  2026-10-23: Added the manual target mode
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// How a boss skill reaches the party on the grid.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<SkillKind>))]
public enum SkillKind
{
    /// <summary>
    /// A shape of cells around an anchor; everyone inside is hit.
    /// </summary>
    Area,

    /// <summary>
    /// One character, optionally shared with or splashing onto characters nearby.
    /// </summary>
    Single,

    /// <summary>
    /// Nothing on the grid: the skill acts on the boss's side.
    /// </summary>
    Support,

    /// <summary>
    /// Nothing on the grid: the skill hurts nobody of the party.
    /// </summary>
    None,
}

/// <summary>
/// The form of a shape of cells.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<ShapeType>))]
public enum ShapeType
{
    /// <summary>
    /// A square of size by size cells around the anchor.
    /// </summary>
    Square,

    /// <summary>
    /// A rectangle of width by height cells around the anchor.
    /// </summary>
    Rectangle,

    /// <summary>
    /// The cells within a Manhattan radius of the anchor.
    /// </summary>
    Diamond,

    /// <summary>
    /// A plus shape through the anchor.
    /// </summary>
    Cross,

    /// <summary>
    /// Both diagonals through the anchor.
    /// </summary>
    XCross,

    /// <summary>
    /// A line through the anchor in one direction.
    /// </summary>
    Line,

    /// <summary>
    /// The whole row or rows of the anchor.
    /// </summary>
    Row,

    /// <summary>
    /// The whole column or columns of the anchor.
    /// </summary>
    Column,

    /// <summary>
    /// A hollow ring around the anchor.
    /// </summary>
    Ring,

    /// <summary>
    /// Painted cells relative to the anchor.
    /// </summary>
    Custom,

    /// <summary>
    /// Every cell of the grid.
    /// </summary>
    WholeGrid,

    /// <summary>
    /// The targeting zone itself, narrowed by its half; used for half-field casts.
    /// </summary>
    Zone,
}

/// <summary>
/// What happens to a shape that sticks out of the grid.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<ShapeFit>))]
public enum ShapeFit
{
    /// <summary>
    /// The cells outside the grid are dropped.
    /// </summary>
    Clip,

    /// <summary>
    /// The shape moves inside the grid; it is cut only where it is larger than the grid.
    /// </summary>
    Shift,
}

/// <summary>
/// The direction of a line shape.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<LineDirection>))]
public enum LineDirection
{
    /// <summary>
    /// Top to bottom.
    /// </summary>
    Vertical,

    /// <summary>
    /// Left to right.
    /// </summary>
    Horizontal,

    /// <summary>
    /// Top left to bottom right.
    /// </summary>
    DiagonalDown,

    /// <summary>
    /// Bottom left to top right.
    /// </summary>
    DiagonalUp,
}

/// <summary>
/// How steps between two cells are counted.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<DistanceMetric>))]
public enum DistanceMetric
{
    /// <summary>
    /// The larger of the column and row steps; rings are squares.
    /// </summary>
    Chebyshev,

    /// <summary>
    /// The column steps plus the row steps; rings are diamonds.
    /// </summary>
    Manhattan,
}

/// <summary>
/// How a skill finds the cell it is aimed at.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<TargetMode>))]
public enum TargetMode
{
    /// <summary>
    /// The game's target roulette by target rate over the living units in the zone that pass the skill's filter.
    /// </summary>
    RandomCharacter,

    /// <summary>
    /// Any cell of the zone, which may be empty.
    /// </summary>
    RandomCell,

    /// <summary>
    /// The character a pick chooses.
    /// </summary>
    PickedCharacter,

    /// <summary>
    /// The zone cell whose shape hits the most characters.
    /// </summary>
    MostHit,

    /// <summary>
    /// The cell the design sets for each pulse, moved by its random offset.
    /// </summary>
    Manual,
}

/// <summary>
/// Which character the picked character mode chooses.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<TargetPick>))]
public enum TargetPick
{
    /// <summary>
    /// The fewest HP.
    /// </summary>
    LowestHp,

    /// <summary>
    /// The most HP.
    /// </summary>
    HighestHp,

    /// <summary>
    /// The lowest share of the maximum HP.
    /// </summary>
    LowestHpRate,

    /// <summary>
    /// The highest attack.
    /// </summary>
    HighestAtk,

    /// <summary>
    /// The highest magic attack.
    /// </summary>
    HighestMat,

    /// <summary>
    /// The first living character of the party order.
    /// </summary>
    Leader,

    /// <summary>
    /// The character on the smallest row, closest to the boss.
    /// </summary>
    Nearest,

    /// <summary>
    /// The character on the largest row, farthest from the boss.
    /// </summary>
    Farthest,
}

/// <summary>
/// One half of the grid's columns.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<GridHalf>))]
public enum GridHalf
{
    /// <summary>
    /// The left floor(cols / 2) columns.
    /// </summary>
    Left,

    /// <summary>
    /// The right floor(cols / 2) columns.
    /// </summary>
    Right,
}

/// <summary>
/// How a zone with a half chooses the half of each cast.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<SideChoice>))]
public enum SideChoice
{
    /// <summary>
    /// Always the zone's half.
    /// </summary>
    Fixed,

    /// <summary>
    /// A random half per cast.
    /// </summary>
    Random,

    /// <summary>
    /// The other half than the last cast, starting at the zone's half.
    /// </summary>
    Alternate,
}

/// <summary>
/// How a skill's damage is shared among everyone it hits.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<SpreadMode>))]
public enum SpreadMode
{
    /// <summary>
    /// Everyone takes the full hit after falloff.
    /// </summary>
    None,

    /// <summary>
    /// The total is one hit, divided by the characters hit.
    /// </summary>
    Even,

    /// <summary>
    /// The arena's area rule: each takes the hit divided by max(min(n, 2), n / 4).
    /// </summary>
    GameDivisor,

    /// <summary>
    /// The anchor's character and its nearest sharers each take the hit divided by their number.
    /// </summary>
    ShareGroup,

    /// <summary>
    /// The total is one hit, shared by ring weights from the centre.
    /// </summary>
    Weighted,

    /// <summary>
    /// The main target keeps a fixed share of the hit and the others in the splash area share the rest.
    /// </summary>
    Splash,
}

/// <summary>
/// Who of the characters a hit reaches gets the skill's states and other effects.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<StateLanding>))]
public enum StateLanding
{
    /// <summary>
    /// Everyone the hit reaches.
    /// </summary>
    EveryoneHit,

    /// <summary>
    /// Only the main target, the character on the aimed cell.
    /// </summary>
    MainTarget,
}

/// <summary>
/// Where a cell animation plays.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CellAnimationPlace>))]
public enum CellAnimationPlace
{
    /// <summary>
    /// On every cell the wave reaches, as it reaches it.
    /// </summary>
    EachCell,

    /// <summary>
    /// Only on the point of impact, once per pulse.
    /// </summary>
    CentreOnly,
}

/// <summary>
/// Where a skill's battle animation plays.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<AnimationPlacement>))]
public enum AnimationPlacement
{
    /// <summary>
    /// On every character hit.
    /// </summary>
    PerCharacter,

    /// <summary>
    /// Once per wave at the impact cell.
    /// </summary>
    OncePerWave,

    /// <summary>
    /// Once per wave at the area's centre.
    /// </summary>
    OncePerWaveAtCentre,
}

/// <summary>
/// How a screen animation is sized.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<AnimationScreen>))]
public enum AnimationScreen
{
    /// <summary>
    /// Scaled to the area's bounding box.
    /// </summary>
    FitArea,

    /// <summary>
    /// Over the whole screen.
    /// </summary>
    FullScreen,

    /// <summary>
    /// Not played.
    /// </summary>
    Off,
}

/// <summary>
/// Where a skill leaves its debris.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<DebrisPlace>))]
public enum DebrisPlace
{
    /// <summary>
    /// On every cell the skill hit.
    /// </summary>
    HitCells,

    /// <summary>
    /// On the impact cell only.
    /// </summary>
    ImpactCell,

    /// <summary>
    /// On random cells of the area, as many as the count.
    /// </summary>
    RandomInArea,

    /// <summary>
    /// On the area's edge cells.
    /// </summary>
    AreaEdge,
}

/// <summary>
/// What debris looks like.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<DebrisLookKind>))]
public enum DebrisLookKind
{
    /// <summary>
    /// The map's own debris tile.
    /// </summary>
    MapDefault,

    /// <summary>
    /// A tile of a sheet.
    /// </summary>
    Tile,

    /// <summary>
    /// A picture.
    /// </summary>
    Picture,
}
