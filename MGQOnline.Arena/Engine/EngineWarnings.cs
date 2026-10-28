//----------------------------------------------------------------
//  EngineWarnings.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Added the warning of a stage the battle plan lacks
//      Paulinchen  2026-10-23: Added the warning of an enemy the reserve lacks
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Events;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The warning codes the engine logs besides <see cref="WarningEvent.RuleLoop"/>.
/// </summary>
public static class EngineWarnings
{
    /// <summary>
    /// The code of an effect whose receiver the event does not name, such as a trigger unit at a turn start.
    /// </summary>
    public const string NoTarget = "ruleNoTarget";

    /// <summary>
    /// The code of a join or a transform into an enemy slot the boss lacks; nothing changes.
    /// </summary>
    public const string UnknownEnemy = "unknownEnemy";

    /// <summary>
    /// The code of a go to stage effect whose stage the battle plan lacks; the stage stays.
    /// </summary>
    public const string UnknownStage = "unknownStage";
}
