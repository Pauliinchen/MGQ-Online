//----------------------------------------------------------------
//  BattlerKind.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// What the factory builds, see <see cref="BattlerSetup"/>.
/// </summary>
public enum BattlerKind
{
    /// <summary>
    /// Another player's character in a co-op battle's party.
    /// </summary>
    Ally,

    /// <summary>
    /// An enemy of the troop.
    /// </summary>
    Enemy,

    /// <summary>
    /// The other side's character outside its Frontline in a PvP battle with the Backline.
    /// </summary>
    Reserve,
}
