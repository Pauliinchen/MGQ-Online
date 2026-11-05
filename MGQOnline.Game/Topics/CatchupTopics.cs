//----------------------------------------------------------------
//  CatchupTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Dropped the topic of the items a Classic party found, which the story replay hands over
//                            - Registered the topic of a Classic member's catch-up by the frozen rows
//                            - Registered the topic of the Medal King's gift in a Classic world
//      Paulinchen  2026-11-01: Registered the topic of the items a Classic party found
//                            - Registered the topic of which companions of the Alice and Ilias choice may join a player
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a Raid World's catch-up (world_catchup.rbx), decided by
/// <see cref="CatchupEngine"/> over the catch-up's tables of the story mapping the DLL holds, one
/// engine and its save's notes per context.
/// </summary>
public static class CatchupTopics
{
    /// <summary>
    /// Lists what the snapshot reads, see <see cref="CatchupEngine.Keys"/>: nothing in; nil before
    /// the story mapping came.
    /// </summary>
    public const string KeysTopic = "catchup.keys";

    /// <summary>
    /// One look at the player's story, see <see cref="CatchupEngine.Check"/>.
    /// </summary>
    public const string CheckTopic = "catchup.check";

    /// <summary>
    /// A note of the world's story for the save's notes, see <see cref="CatchupEngine.Note"/>.
    /// </summary>
    public const string NoteTopic = "catchup.note";

    /// <summary>
    /// Whether a companion the player's own event hands out waits for the join's gate, see
    /// <see cref="CatchupEngine.HoldJoin"/>.
    /// </summary>
    public const string HoldTopic = "catchup.hold_join";

    /// <summary>
    /// What the catch-up hands out by level, see <see cref="CatchupEngine.Unlocks"/>.
    /// </summary>
    public const string UnlocksTopic = "catchup.unlocks";

    /// <summary>
    /// Which companions of the Alice and Ilias choice may join a player, in either world type, see
    /// <see cref="CompanionScope.Answer"/>: every companion while the story mapping has not come.
    /// </summary>
    public const string ScopeTopic = "catchup.scope";

    /// <summary>
    /// What a Classic party's member who starts keeping the leader's story catches up with, see
    /// <see cref="ClassicCatchup.Answer"/>: nothing while the story mapping has not come.
    /// </summary>
    public const string ClassicTopic = "catchup.classic";

    /// <summary>
    /// The Medal King's gifts a Classic world's player is owed, see <see cref="MedalKingGift.Answer"/>:
    /// nothing while the story mapping has not come.
    /// </summary>
    public const string MedalKingTopic = "catchup.medal_king";

    /// <summary>
    /// Registers the topics on a context, with an engine of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="tables">Reads the catch-up's tables of the story mapping held, <see langword="null"/> before it came.</param>
    /// <returns>The engine, for tests.</returns>
    public static CatchupEngine Register(BridgeContext context, Func<CatchupTables?> tables)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(tables);
        CatchupEngine engine = new();
        context.Register(KeysTopic, (_, _) => tables() is { } held ? CatchupEngine.Keys(held) : null);
        context.Register(CheckTopic, (_, request) => engine.Check(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(NoteTopic, (_, request) => engine.Note(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(HoldTopic, (_, request) => engine.HoldJoin(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(UnlocksTopic, (_, request) => engine.Unlocks(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(ScopeTopic, (_, request) => (tables() ?? CatchupTables.Empty).Scope.Answer(request.AsHash()));
        context.Register(ClassicTopic, (_, request) => ClassicCatchup.Answer(tables() ?? CatchupTables.Empty, request.AsHash()));
        context.Register(MedalKingTopic, (_, request) => MedalKingGift.Answer(tables() ?? CatchupTables.Empty, request.AsHash()));
        return engine;
    }
}
